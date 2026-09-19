#!/usr/bin/env bash
# Invariant tests for the 0.22 lean night-git boundary. Real Git, temporary
# repositories and local bare remotes only. No model/PR calls.
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
  else bad "$label (exit=$status, stdout=[$actual], stderr=[$(tail -1 "$TMP/stderr")])"; fi
}
rejects() {
  local label="$1" status
  shift 1
  bash "$SCRIPT" "$@" > "$TMP/stdout" 2> "$TMP/stderr"
  status=$?
  if [[ "$status" -ne 0 ]]; then ok "$label"; else bad "$label (unexpected exit 0: $(< "$TMP/stdout"))"; fi
}
new_repo() { git init -q -b main "$1"; }
commit_file() { printf '%s\n' "$3" > "$1/$2"; git -C "$1" add "$2"; git -C "$1" commit -q -m "$4"; }
murl() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

# --- start -------------------------------------------------------------------
R="$TMP/host"; new_repo "$R"; commit_file "$R" a.txt base c1
BASE="$(git -C "$R" rev-parse HEAD)"
ORIG_REF="$(git -C "$R" rev-parse refs/heads/main)"
printf 'user-dirty\n' > "$R/dirty.txt"

accepts 'start creates the night branch from the frozen baseline' \
  'status=started
mode=created' start "$R" xcheck-night-t1 "$BASE"
[[ "$(git -C "$R" symbolic-ref --short HEAD)" == xcheck-night-t1 ]] && ok 'checkout is on the night branch' || bad 'checkout is on the night branch'
[[ "$(git -C "$R" rev-parse refs/heads/main)" == "$ORIG_REF" ]] && ok 'original branch ref untouched' || bad 'original branch ref untouched'
[[ -f "$R/dirty.txt" && "$(cat "$R/dirty.txt")" == user-dirty ]] && ok 'operator uncommitted files survive branch creation' || bad 'operator uncommitted files survive branch creation'

accepts 'start is idempotent when already on the night branch' \
  'status=started
mode=idempotent' start "$R" xcheck-night-t1 "$BASE"

git -C "$R" switch -q main
accepts 'start resumes by switching back to the existing night branch' \
  'status=started
mode=resumed' start "$R" xcheck-night-t1 "$BASE"

# blocked: night branch content diverges from an operator's dirty edit
commit_file "$R" a.txt night-change c2            # commit lands on the night branch (HEAD is on it)
git -C "$R" switch -q main                         # clean switch: a.txt reverts to base
printf 'conflict\n' > "$R/a.txt"                   # operator dirty edit colliding with night content
bash "$SCRIPT" start "$R" xcheck-night-t1 "$BASE" > "$TMP/stdout" 2> "$TMP/stderr"
if [[ $? -eq 1 && "$(cat "$TMP/stdout")" == 'status=blocked
reason=operator-changes-conflict' ]]; then ok 'switch refusal is reported as blocked, exit 1'
else bad 'switch refusal is reported as blocked, exit 1 (stdout=[$(cat "$TMP/stdout")])'; fi
[[ "$(cat "$R/a.txt")" == conflict ]] && ok 'operator conflict content untouched' || bad 'operator conflict content untouched'
git -C "$R" checkout -q -- a.txt

# fresh-start guard: HEAD moved since the frozen baseline
R2="$TMP/host2"; new_repo "$R2"; commit_file "$R2" a.txt one c1
B2="$(git -C "$R2" rev-parse HEAD)"
commit_file "$R2" b.txt two c2
rejects 'fresh start refuses a moved HEAD against the frozen baseline' start "$R2" night-x "$B2"

# --- snapshot ------------------------------------------------------------------
printf 'wip\n' >> "$R2/a.txt"
bash "$SCRIPT" snapshot "$R2" dirty-t1 > "$TMP/stdout" 2> "$TMP/stderr" || bad 'snapshot runs on a dirty tree'
SNAP="$(sed -n 's/^snapshot=//p' "$TMP/stdout")"
if [[ "$SNAP" =~ ^[0-9a-f]{40,}$ ]]; then ok 'snapshot emits a commit OID'
else bad "snapshot emits a commit OID (got [$SNAP])"; SNAP=""; fi
[[ "$(cat "$R2/a.txt")" == *wip ]] && ok 'snapshot leaves the worktree untouched' || bad 'snapshot leaves the worktree untouched'
git -C "$R2" show --quiet --format=%H "$SNAP" >/dev/null 2>&1 && ok 'snapshot content is recoverable' || bad 'snapshot content is recoverable'
git -C "$R2" reflog expire --expire=now --all >/dev/null 2>&1; git -C "$R2" gc -q --prune=now 2>/dev/null
git -C "$R2" show-ref --verify --quiet "refs/xcheck/dirty-t1" && ok 'snapshot ref survives aggressive gc' || bad 'snapshot ref survives aggressive gc'

R3="$TMP/host3"; new_repo "$R3"; commit_file "$R3" a.txt base c1
accepts 'clean tree snapshots as none' 'snapshot=none
reason=clean-tree' snapshot "$R3" dirty-t2

# --- publish -------------------------------------------------------------------
P="$TMP/pub"; new_repo "$P"; commit_file "$P" a.txt base c1
PB="$(git -C "$P" rev-parse HEAD)"
git -C "$P" tag v9
EVIL="$TMP/evil.git"; REM="$TMP/remote.git"
git clone -q --bare "$P" "$EVIL"
git clone -q --bare "$P" "$REM"
EVIL_BEFORE="$(git -C "$EVIL" for-each-ref --format='%(refname)' | sort)"
mkdir -p "$P/.git/hooks"
printf '#!/usr/bin/env bash\ngit push %s HEAD:refs/heads/smuggled\n' "$(murl "$EVIL")" > "$P/.git/hooks/pre-push"
chmod +x "$P/.git/hooks/pre-push"

accepts 'publish pushes the night branch to the explicit URL' 'status=published' publish "$P" main "$(murl "$REM")"
[[ "$(git -C "$REM" rev-parse refs/heads/main)" == "$PB" ]] && ok 'remote night ref matches local' || bad 'remote night ref matches local'
[[ "$(git -C "$EVIL" for-each-ref --format='%(refname)' | sort)" == "$EVIL_BEFORE" ]] \
  && ok 'pre-push hook smuggling is blocked by --no-verify (evil remote unchanged)' \
  || bad 'pre-push hook smuggling is blocked by --no-verify (evil remote got refs)'
[[ ! -e "$REM/refs/tags/v9" ]] && ok 'tags are never published' || bad 'tags are never published'

# non-fast-forward: remote night-nf diverges; publish must fail without forcing
git -C "$P" switch -q -c night-nf
printf 'advance\n' > "$P/a.txt"; git -C "$P" add a.txt; git -C "$P" commit -q -m advance
TREE="$(git -C "$REM" rev-parse 'refs/heads/main^{tree}')"
DIV="$(git -C "$REM" commit-tree "$TREE" -p "$(git -C "$REM" rev-parse refs/heads/main)" -m diverged)"
git -C "$REM" update-ref refs/heads/night-nf "$DIV"
bash "$SCRIPT" publish "$P" night-nf "$(murl "$REM")" > "$TMP/stdout" 2> "$TMP/stderr"
if [[ $? -eq 1 ]]; then ok 'publish fails on a diverged remote without forcing'
else bad 'publish fails on a diverged remote without forcing (exit 0)'; fi
[[ "$(git -C "$REM" rev-parse refs/heads/night-nf)" == "$DIV" ]] && ok 'diverged remote ref is never overwritten' || bad 'diverged remote ref is never overwritten'

# unreachable remote fails fast (bounded), local work retained
timeout 30 bash "$SCRIPT" publish "$P" night-nf "https://example.invalid/x.git" > "$TMP/stdout" 2> "$TMP/stderr"
if [[ $? -eq 1 ]]; then ok 'unreachable remote fails fast without hanging'
else bad 'unreachable remote fails fast without hanging'; fi
git -C "$P" show-ref --verify --quiet refs/heads/night-nf && ok 'local branch retained after publication failure' || bad 'local branch retained after publication failure'

# argument validation
rejects 'branch names with leading dash are rejected' publish "$P" -x "https://example.invalid/x.git"
rejects 'empty remote URL is rejected' publish "$P" night-nf ""
rejects 'publishing a missing branch is rejected' publish "$P" no-such-branch "https://example.invalid/x.git"
rejects 'abbreviated baseline OIDs are rejected' start "$P" night-abc 1234abc

printf '\nResult: %d pass, %d fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
