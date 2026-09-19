#!/usr/bin/env bash
# Mechanical night Git boundary. Caller owns authorization, snapshots and ledgers.
# prepare <repo> <branch> <worktree> <baselineOID>
# verify <repo> <branch> <worktree> <baselineOID> [completedOIDs...]
# publish <repo> <branch> <worktree> <baselineOID> <remoteName|-> <frozenRemoteURL|->
set -uo pipefail
fail() { printf 'night-git: %s\n' "$*" >&2; exit 2; }
[[ $# -ge 5 ]] || fail 'expected command, repo, branch, worktree and baselineOID'
action="$1"; repo="$2"; branch="$3"; worktree="$4"; baseline="$5"; shift 5
case "$action" in
  prepare) [[ $# -eq 0 ]] || fail 'prepare takes four arguments';;
  verify) ;;
  publish) [[ $# -eq 2 ]] || fail 'publish requires remote name and frozen URL';;
  *) fail 'unknown command';;
esac
# Ambient Git overrides could silently redirect writes to a different repository.
for key in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE; do
  [[ ! -v "$key" ]] || fail "unsupported ambient override: $key"
done
# Reachability is about the recorded commits, not local replacement objects.
export GIT_NO_REPLACE_OBJECTS=1
canonical_dir() { (cd -- "$1" && pwd -P); }
repo="$(canonical_dir "$repo")" || fail 'repository directory is missing'
[[ "$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)" == true ]] || fail 'expected a working repository, not a bare repository'
root="$(git -C "$repo" rev-parse --show-toplevel)" || fail 'cannot resolve repository root'
repo="$(canonical_dir "$root")" || fail 'cannot resolve repository root'
common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)" || fail 'cannot resolve common Git directory'
common="$(canonical_dir "$common")" || fail 'cannot resolve common Git directory'
[[ "$branch" != -* && "$branch" != HEAD && "$branch" != refs/* ]] || fail 'expected a literal local branch name'
git check-ref-format "refs/heads/$branch" >/dev/null 2>&1 || fail 'invalid branch name'
[[ "$worktree" != *$'\n'* && "$worktree" != *$'\r'* ]] || fail 'invalid worktree path'
if [[ -d "$worktree" ]]; then
  worktree="$(canonical_dir "$worktree")" || fail 'cannot resolve worktree path'
else
  parent="$(canonical_dir "$(dirname -- "$worktree")")" || fail 'worktree parent directory must already exist'
  leaf="$(basename -- "$worktree")"
  [[ "$leaf" != . && "$leaf" != .. ]] || fail 'invalid worktree path'
  worktree="$parent/$leaf"
fi
repo_boundary="$repo"; worktree_boundary="$worktree"
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*) repo_boundary="${repo_boundary,,}"; worktree_boundary="${worktree_boundary,,}";;
esac
[[ "$worktree_boundary" != "$repo_boundary" && "$worktree_boundary" != "$repo_boundary/"* && "$repo_boundary" != "$worktree_boundary/"* ]] || fail 'night worktree must be outside the original repository, not its ancestor'
full_commit() {
  local oid="$1" resolved
  [[ "$oid" =~ ^[0-9a-f]{40}$ || "$oid" =~ ^[0-9a-f]{64}$ ]] || fail 'expected a full lowercase commit OID'
  resolved="$(git -C "$repo" rev-parse --verify "$oid^{commit}" 2>/dev/null)" || fail "commit is missing: $oid"
  [[ "$resolved" == "$oid" ]] || fail 'OID must identify a commit, not a tag'
}
full_commit "$baseline"
ref="refs/heads/$branch"
verify_identity() {
  local wt_common wt_root current registered=0 field registered_path
  [[ -d "$worktree" ]] || fail 'recorded worktree is missing; stop for recovery'
  [[ -f "$worktree/.git" ]] || fail 'expected a linked worktree, not an ordinary directory or repository'
  wt_root="$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null)" || fail 'worktree is not valid'
  wt_root="$(canonical_dir "$wt_root")" || fail 'cannot resolve worktree root'
  [[ "$wt_root" == "$worktree" ]] || fail 'path is not the worktree root'
  wt_common="$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)" || fail 'cannot resolve worktree ownership'
  wt_common="$(canonical_dir "$wt_common")" || fail 'cannot resolve worktree ownership'
  [[ "$wt_common" == "$common" ]] || fail 'worktree belongs to another repository'
  current="$(git -C "$worktree" symbolic-ref -q HEAD)" || fail 'worktree HEAD is detached'
  [[ "$current" == "$ref" ]] || fail 'worktree is on the wrong branch'
  # Registration must agree as well as the .git backlink; no prune/repair here.
  while IFS= read -r -d '' field; do
    if [[ "$field" == 'worktree '* ]]; then
      registered_path="${field#worktree }"
      if [[ -d "$registered_path" ]]; then
        registered_path="$(canonical_dir "$registered_path")" || continue
        [[ "$registered_path" != "$worktree" ]] || registered=1
      fi
    fi
  done < <(git -C "$repo" worktree list --porcelain -z)
  [[ "$registered" -eq 1 ]] || fail 'worktree is not registered with this repository'
  git -C "$repo" merge-base --is-ancestor "$baseline" "$ref" || fail 'baseline is not reachable from night branch'
}
if [[ "$action" == prepare ]]; then
  if git -C "$repo" show-ref --verify --quiet "$ref"; then
    verify_identity
  else
    [[ ! -e "$worktree" && ! -L "$worktree" ]] || fail 'worktree destination already exists; refusing to overwrite'
    # A missing directory may still have a registered worktree. Git refuses that
    # collision itself; never force, prune or remove an existing registration.
    git -C "$repo" worktree add -b "$branch" -- "$worktree" "$baseline" >&2 || fail 'worktree creation failed; retain state for inspection'
    verify_identity
  fi
  printf 'status=prepared\n'
  exit 0
fi
verify_identity
if [[ "$action" == verify ]]; then
  for oid in "$@"; do
    full_commit "$oid"
    git -C "$repo" merge-base --is-ancestor "$oid" "$ref" || fail "completed commit is not reachable: $oid"
  done
  printf 'status=verified\n'
  exit 0
fi
remote="$1"; frozen_url="$2"
if [[ "$remote" == - && "$frozen_url" == - ]]; then
  printf 'status=skipped\nreason=no-remote\n'
  exit 0
fi
[[ "$remote" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$frozen_url" != - && -n "$frozen_url" && "$frozen_url" != *$'\r'* && "$frozen_url" != *$'\n'* ]] || fail 'invalid remote name or frozen URL pair'
fetch_url="$(git -C "$worktree" remote get-url --all "$remote" 2>/dev/null)" || fail 'recorded remote is missing'
push_url="$(git -C "$worktree" remote get-url --push --all "$remote" 2>/dev/null)" || fail 'cannot resolve push destination'
[[ "$fetch_url" == "$frozen_url" && "$push_url" == "$frozen_url" && "$frozen_url" != *$'\n'* ]] || fail 'remote URL changed or has multiple/different push destinations'
mirror="$(git -C "$worktree" config --bool --get "remote.$remote.mirror" 2>/dev/null)"
[[ -z "$mirror" || "$mirror" == false ]] || fail 'mirror remote is not an allowed publication target'
# An explicit non-force refspec overrides push.default/remote.push. Disable tag
# following and submodule pushes so this action publishes only the night branch.
# Git transport diagnostics can echo credential-bearing URLs; expose only the
# publication status, never raw transport stdout/stderr.
git -C "$worktree" -c push.followTags=false push --porcelain --no-follow-tags --recurse-submodules=no -- "$remote" "$ref:$ref" >/dev/null 2>&1 || { printf 'night-git: publication failed; local worktree and commits retained\n' >&2; exit 1; }
printf 'status=published\n'
