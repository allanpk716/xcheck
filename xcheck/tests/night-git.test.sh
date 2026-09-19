#!/usr/bin/env bash
# Real Git, temporary repositories and local bare remotes only. No model/PR calls.
# bash xcheck/tests/night-git.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../lib/night-git.sh"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_OPTIONAL_LOCKS=0 GIT_ALLOW_PROTOCOL=file
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }
accepts() {
  local label="$1" expected="$2" status actual
  shift 2
  bash "$SCRIPT" "$@" > "$TMP/stdout" 2> "$TMP/stderr"
  status=$?; actual="$(< "$TMP/stdout")"
  if [[ "$status" -eq 0 && "$actual" == "$expected" ]]; then ok "$label"
  else bad "$label (exit=$status stdout=$actual stderr=$(< "$TMP/stderr"))"; fi
}
rejects() {
  local label="$1" status
  shift
  bash "$SCRIPT" "$@" > "$TMP/stdout" 2> "$TMP/stderr"
  status=$?
  if [[ "$status" -ne 0 && ! -s "$TMP/stdout" && -s "$TMP/stderr" ]]; then ok "$label"
  else bad "$label (exit=$status stdout=$(< "$TMP/stdout") stderr=$(< "$TMP/stderr"))"; fi
}
repo="$TMP/original project"; wt="$TMP/night tree"; branch=xcheck-night-test
remote="$TMP/remote.git"
git init -q -b main "$repo" || exit 2
printf 'Committed proposal\n' > "$repo/proposal.md"
printf 'Original tracked file\n' > "$repo/tracked.txt"
git -C "$repo" add -- proposal.md tracked.txt
git -C "$repo" commit -qm baseline || exit 2
baseline="$(git -C "$repo" rev-parse HEAD)"
printf 'User staged change\n' >> "$repo/tracked.txt"
git -C "$repo" add -- tracked.txt
printf 'User unstaged change\n' >> "$repo/tracked.txt"
printf 'User uncommitted proposal\n' >> "$repo/proposal.md"
printf 'User untracked file\n' > "$repo/untracked.txt"
snapshot() {
  git -C "$repo" rev-parse HEAD
  git -C "$repo" symbolic-ref HEAD
  cksum "$repo/.git/index" "$repo/proposal.md" "$repo/tracked.txt" "$repo/untracked.txt"
  git -C "$repo" diff --binary
  git -C "$repo" diff --cached --binary
}
snapshot > "$TMP/before"
printf '== Prepare and identity ==\n'
accepts 'dirty source is allowed; create from explicit baseline' status=prepared prepare "$repo" "$branch" "$wt" "$baseline"
[[ -f "$wt/.git" ]] || { printf 'Cannot continue without prepared worktree.\n' >&2; exit 2; }
accepts 'matching prepare is idempotent' status=prepared prepare "$repo" "$branch" "$wt" "$baseline"
accepts 'verify exact registered worktree' status=verified verify "$repo" "$branch" "$wt" "$baseline"
rejects 'reject abbreviated baseline' verify "$repo" "$branch" "$wt" "${baseline:0:12}"
rejects 'reject expression instead of OID' verify "$repo" "$branch" "$wt" HEAD
rejects 'reject wrong branch' verify "$repo" wrong "$wt" "$baseline"
rejects 'reject original worktree as destination' prepare "$repo" main "$repo" "$baseline"
rejects 'reject worktree nested in original repository' prepare "$repo" nested "$repo/nested-worktree" "$baseline"
rejects 'reject worktree ancestor of original repository' prepare "$repo" ancestor "$TMP" "$baseline"
[[ ! -e "$repo/nested-worktree" ]] && ok 'nested worktree rejection creates no directory' || bad 'nested worktree path created'
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*)
    rejects 'Windows case variation cannot bypass repository boundary' prepare "${repo^^}" case-test "$repo/case-worktree" "$baseline";;
esac
rejects 'reject branch option injection' prepare "$repo" --bad "$TMP/injected" "$baseline"
mkdir "$TMP/occupied"
printf 'Do not overwrite\n' > "$TMP/occupied/file"
rejects 'reject occupied destination' prepare "$repo" other "$TMP/occupied" "$baseline"
[[ "$(< "$TMP/occupied/file")" == 'Do not overwrite' ]] && ok 'occupied destination preserved' || bad 'occupied destination overwritten'
git init -q -b main "$TMP/foreign"
git -C "$TMP/foreign" fetch -q "$repo" "$baseline" || exit 2
git -C "$TMP/foreign" worktree add -q -b "$branch" "$TMP/foreign worktree" "$baseline" || exit 2
rejects 'reject unrelated repository ownership with valid baseline' verify "$repo" "$branch" "$TMP/foreign worktree" "$baseline"
rejects 'reject ordinary repository rather than linked worktree' verify "$repo" "$branch" "$TMP/foreign" "$baseline"
mkdir "$wt/subdir"
rejects 'reject subdirectory rather than exact worktree' verify "$repo" "$branch" "$wt/subdir" "$baseline"
GIT_INDEX_FILE="$TMP/alternate-index" bash "$SCRIPT" verify "$repo" "$branch" "$wt" "$baseline" > "$TMP/stdout" 2> "$TMP/stderr"
[[ $? -ne 0 && ! -e "$TMP/alternate-index" ]] && ok 'ambient Git redirection is rejected' || bad 'ambient Git redirection allowed'

printf '== Snapshot and all artifacts on one branch ==\n'
# The caller copies only the specified current-byte input, not all dirty state.
mkdir -p "$wt/docs/specs" "$wt/.scratch/feature/issues" "$TMP/run"
cp "$repo/proposal.md" "$TMP/run/proposal.md"
cp "$TMP/run/proposal.md" "$wt/proposal.md"
printf 'Consensus\n' > "$wt/docs/specs/consensus.md"
printf 'Revision\n' > "$wt/docs/specs/proposal.rev1.md"
printf 'Review appendix\n' >> "$wt/proposal.md"
printf 'Specification\n' > "$wt/docs/specs/spec.md"
printf 'Ticket\n' > "$wt/.scratch/feature/issues/01.md"
printf '.scratch/*\n!.scratch/feature/\n' > "$wt/.gitignore"
printf 'Implementation\n' > "$wt/code.txt"
git -C "$wt" add -- proposal.md docs .scratch .gitignore code.txt
git -C "$wt" commit -qm 'night documents and implementation' || exit 2
completed="$(git -C "$wt" rev-parse HEAD)"
accepts 'completion commit is reachable' status=verified verify "$repo" "$branch" "$wt" "$baseline" "$completed"
accepts 'prepare does not reset an existing advanced branch' status=prepared prepare "$repo" "$branch" "$wt" "$baseline"
if [[ "$(< "$TMP/run/proposal.md")" == "$(< "$repo/proposal.md")" && "$(git -C "$wt" show HEAD:tracked.txt)" == 'Original tracked file' && ! -e "$wt/untracked.txt" ]]; then
  ok 'snapshot includes uncommitted input without copying unrelated dirty files'
else bad 'input snapshot or dirty-file isolation mismatch'; fi
changes="$(git -C "$wt" diff --name-only "$baseline" HEAD)"
if [[ "$changes" == *proposal.md* && "$changes" == *consensus.md* && "$changes" == *proposal.rev1.md* && "$changes" == *spec.md* && "$changes" == *.scratch/feature/issues/01.md* && "$changes" == *.gitignore* && "$changes" == *code.txt* ]]; then
  ok 'proposal appendix, consensus, revision, spec, ticket, ignore and code share branch diff'
else bad 'missing artifact in branch diff'; fi
orphan="$(printf 'unreachable\n' | git -C "$repo" commit-tree "$(git -C "$repo" rev-parse 'HEAD^{tree}')")"
rejects 'existing but unreachable completion is rejected' verify "$repo" "$branch" "$wt" "$baseline" "$orphan"
rejects 'unreachable baseline is rejected' verify "$repo" "$branch" "$wt" "$orphan"
blob="$(git -C "$repo" rev-parse HEAD:proposal.md)"
rejects 'blob is not a completion commit' verify "$repo" "$branch" "$wt" "$baseline" "$blob"
git -C "$wt" checkout -q --detach
rejects 'detached worktree is rejected' verify "$repo" "$branch" "$wt" "$baseline"
git -C "$wt" checkout -q "$branch"
mv "$wt" "$TMP/temporarily missing"
rejects 'missing worktree pauses verify' verify "$repo" "$branch" "$wt" "$baseline" "$completed"
rejects 'missing worktree is not recreated by prepare' prepare "$repo" "$branch" "$wt" "$baseline"
mv "$TMP/temporarily missing" "$wt"

printf '== Local-only publication ==\n'
accepts 'no remote is a successful unpublished state' $'status=skipped\nreason=no-remote' publish "$repo" "$branch" "$wt" "$baseline" - -
rejects 'partial remote fields rejected' publish "$repo" "$branch" "$wt" "$baseline" origin -
rejects 'carriage return in frozen URL rejected' publish "$repo" "$branch" "$wt" "$baseline" origin $'https://example.invalid/repo\r'
rejects 'newline in frozen URL rejected' publish "$repo" "$branch" "$wt" "$baseline" origin $'https://example.invalid/repo\n'
git -C "$repo" remote add credential-test 'https://test:sentinel-secret@example.invalid/repo'
rejects 'transport failure with credentials uses generic diagnostics' publish "$repo" "$branch" "$wt" "$baseline" credential-test 'https://test:sentinel-secret@example.invalid/repo'
[[ "$(< "$TMP/stderr")" != *sentinel-secret* ]] && ok 'transport diagnostics do not disclose URL password' || bad 'transport diagnostics exposed URL password'
git init -q --bare "$remote" || exit 2
git -C "$repo" remote add origin "$remote"
# Git Bash may store a native Windows path; freeze Git's actual URL spelling.
frozen_url="$(git -C "$repo" remote get-url origin)"
rejects 'changed frozen URL is rejected' publish "$repo" "$branch" "$wt" "$baseline" origin "$TMP/wrong.git"
git -C "$repo" config remote.origin.pushurl "$TMP/elsewhere.git"
rejects 'different push URL is rejected' publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
git -C "$repo" config --unset remote.origin.pushurl
git -C "$repo" config --add remote.origin.pushurl "$frozen_url"
git -C "$repo" config --add remote.origin.pushurl "$TMP/elsewhere.git"
rejects 'multiple push destinations are rejected' publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
git -C "$repo" config --unset-all remote.origin.pushurl
git -C "$repo" config remote.origin.mirror true
rejects 'mirror push remote is rejected' publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
git -C "$repo" config --unset remote.origin.mirror
git -C "$repo" config extensions.worktreeConfig true
git -C "$wt" config --worktree remote.origin.pushurl "$TMP/worktree-only.git"
rejects 'worktree-local remote override is rejected before pushing' publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
git -C "$wt" config --worktree --unset remote.origin.pushurl
# Hostile defaults cannot add another branch or auto-follow annotated tags.
git -C "$repo" config remote.origin.push refs/heads/main:refs/heads/main
git -C "$repo" config push.followTags true
git -C "$wt" tag -am 'tag must remain local' night-tag
accepts 'publish sends only the explicit night ref' status=published publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
accepts 'publication retry is idempotent' status=published publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
refs="$(git --git-dir="$remote" for-each-ref --format='%(refname)')"
[[ "$refs" == "refs/heads/$branch" ]] && ok 'original branch and tag never published' || bad "unexpected remote refs: $refs"
printf 'More work\n' >> "$wt/code.txt"
git -C "$wt" add -- code.txt
git -C "$wt" commit -qm 'local completion retained on rejection' || exit 2
local_tip="$(git -C "$wt" rev-parse HEAD)"
printf '#!/bin/sh\nexit 1\n' > "$remote/hooks/pre-receive"
chmod +x "$remote/hooks/pre-receive"
rejects 'push rejection returns failure' publish "$repo" "$branch" "$wt" "$baseline" origin "$frozen_url"
if [[ -d "$wt" && "$(git -C "$wt" rev-parse HEAD)" == "$local_tip" ]]; then ok 'push failure retains local worktree and commits'; else bad 'push failure lost local work'; fi
accepts 'implementation remains verifiable after publication failure' status=verified verify "$repo" "$branch" "$wt" "$baseline" "$local_tip"
snapshot > "$TMP/after"
if cmp -s "$TMP/before" "$TMP/after"; then ok 'original HEAD, branch, index and dirty files unchanged across all operations'; else bad 'original worktree changed'; fi
printf 'Scope: production Git helper, temporary repositories, local bare remote; caller flow, diag routing, PR tools, live services and model semantics not executed.\n'
printf 'Result: %s pass, %s fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
