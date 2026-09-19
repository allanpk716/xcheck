#!/usr/bin/env bash
# Offline PATH stub only. Never invokes a real PR tool or service.
# bash xcheck/tests/night-pr.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../lib/night-pr.sh"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/empty" "$TMP/unrelated cwd"
BASH_BIN="$BASH"
export PR_TEST_LOG="$TMP" PR_TEST_MODE=existing
{
  printf '#!%s\n' "$BASH_BIN"
  printf '%s\n' 'set -uo pipefail
[[ "$1" == pr ]] || exit 90
printf "%s\n" "$2" >> "$PR_TEST_LOG/calls"
printf "%s\0" "$@" > "$PR_TEST_LOG/$2.argv"
case "$2" in
  list)
    [[ "$PR_TEST_MODE" != query-failed ]] || exit 21
    if [[ "$PR_TEST_MODE" == existing ]]; then
      printf "https://forge.example/explicit-owner/explicit-repo/pull/7\n"
    elif [[ "$PR_TEST_MODE" == invalid-query ]]; then
      printf "not-a-url\n"
    elif [[ "$PR_TEST_MODE" == wrong-host-query ]]; then
      printf "https://wrong.example/explicit-owner/explicit-repo/pull/7\n"
    elif [[ "$PR_TEST_MODE" == wrong-repo-query ]]; then
      printf "https://forge.example/other-owner/other-repo/pull/7\n"
    fi
    ;;
  create)
    [[ "$PR_TEST_MODE" != create-failed ]] || exit 22
    for arg in "$@"; do
      if [[ "$arg" == --body-file=* ]]; then
        body="${arg#--body-file=}"
        printf "%s" "$(< "$body")" > "$PR_TEST_LOG/body-read"
      fi
    done
    if [[ "$PR_TEST_MODE" == invalid-create ]]; then printf "\n"; exit 0; fi
    if [[ "$PR_TEST_MODE" == wrong-host-create ]]; then
      printf "https://wrong.example/explicit-owner/explicit-repo/pull/8\n"; exit 0
    fi
    if [[ "$PR_TEST_MODE" == wrong-repo-create ]]; then
      printf "https://forge.example/other-owner/other-repo/pull/8\n"; exit 0
    fi
    printf "https://forge.example/explicit-owner/explicit-repo/pull/8\n"
    ;;
  *) exit 91;;
esac'
} > "$TMP/bin/gh"
chmod +x "$TMP/bin/gh"
printf '中文正文，不应内联到 argv\n第二行\n' > "$TMP/body file.md"
printf '前导减号文件\n' > "$TMP/unrelated cwd/-body.md"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }
repo=forge.example/explicit-owner/explicit-repo
base=release/frozen; branch=xcheck/night-frozen; title='--中文标题'; body="$TMP/body file.md"
run() {
  local path="$1"
  shift
  : > "$TMP/calls"
  (cd "$TMP/unrelated cwd" && PATH="$path" "$BASH_BIN" "$SCRIPT" "$@") > "$TMP/stdout" 2> "$TMP/stderr"
  STATUS=$?; OUTPUT="$(< "$TMP/stdout")"; CALLS="$(< "$TMP/calls")"
}
expect() {
  local label="$1" status="$2" output="$3" calls="$4"
  if [[ "$STATUS" -eq "$status" && "$OUTPUT" == "$output" && "$CALLS" == "$calls" ]]; then ok "$label"
  else bad "$label (exit=$STATUS stdout=$OUTPUT calls=$CALLS stderr=$(< "$TMP/stderr"))"; fi
}
argv_is() {
  local action="$1"; shift
  local -a actual expected=("$@")
  mapfile -d '' -t actual < "$TMP/$action.argv"
  [[ "${#actual[@]}" -eq "${#expected[@]}" ]] || { bad "$action argument count"; return; }
  local i
  for ((i=0; i<${#expected[@]}; i++)); do
    [[ "${actual[i]}" == "${expected[i]}" ]] || { bad "$action argv[$i]: ${actual[i]}"; return; }
  done
  ok "$action exact argv explicitly pins repo, base and head"
}
printf '== Existing and creation ==\n'
run "$TMP/bin" github "$repo" "$base" "$branch" "$title" "$body"
expect 'existing open PR reused without create' 0 $'status=existing\nurl=https://forge.example/explicit-owner/explicit-repo/pull/7' list
argv_is list pr list --repo "$repo" --base "$base" --head "$branch" --state open --json url,isCrossRepository --jq 'map(select(.isCrossRepository == false))[0].url // empty'
PR_TEST_MODE=create
run "$TMP/bin" github "$repo" "$base" "$branch" "$title" "$body"
expect 'absent PR creates once from unrelated cwd' 0 $'status=created\nurl=https://forge.example/explicit-owner/explicit-repo/pull/8' $'list\ncreate'
argv_is create pr create --repo "$repo" --base "$base" --head "$branch" --title="$title" --body-file="$body"
[[ "$(< "$TMP/body-read")" == "$(< "$body")" ]] && ok 'Chinese body read unchanged from file' || bad 'body changed'
run "$TMP/bin" github "$repo" "$base" "$branch" "$title" -body.md
expect 'leading-dash body path is a value, not an option' 0 $'status=created\nurl=https://forge.example/explicit-owner/explicit-repo/pull/8' $'list\ncreate'
argv_is create pr create --repo "$repo" --base "$base" --head "$branch" --title="$title" --body-file=-body.md
PR_TEST_MODE=existing
run "$TMP/bin" github "$repo" "$base" "$branch" "$title" "$body"
expect 'retry reuses existing PR without another create' 0 $'status=existing\nurl=https://forge.example/explicit-owner/explicit-repo/pull/7' list
printf '== Failure and unsupported tools ==\n'
for mode in query-failed create-failed invalid-query invalid-create wrong-host-query wrong-repo-query wrong-host-create wrong-repo-create; do
  PR_TEST_MODE="$mode"
  case "$mode" in
    query-failed) reason=query-failed; calls=list;;
    create-failed) reason=create-failed; calls=$'list\ncreate';;
    invalid-query|wrong-host-query|wrong-repo-query) reason=invalid-query-output; calls=list;;
    invalid-create|wrong-host-create|wrong-repo-create) reason=invalid-create-output; calls=$'list\ncreate';;
  esac
  run "$TMP/bin" github "$repo" "$base" "$branch" "$title" "$body"
  expect "$mode fails closed" 1 "$(printf 'status=not-created\nreason=%s' "$reason")" "$calls"
done
run "$TMP/empty" github "$repo" "$base" "$branch" "$title" "$body"
expect 'missing gh never installs or creates' 0 $'status=not-created\nreason=missing-gh' ''
for platform in gitea unsupported; do
  run "$TMP/bin" "$platform" "$repo" "$base" "$branch" "$title" "$body"
  expect "$platform explicitly unsupported without a tool call" 0 $'status=not-created\nreason=unsupported-platform' ''
done
printf '== Input validation ==\n'
rejects() {
  local label="$1"; shift
  run "$TMP/bin" "$@"
  expect "$label" 2 '' ''
  [[ -s "$TMP/stderr" ]] || bad "$label lacks diagnostic"
}
rejects 'missing body' github "$repo" "$base" "$branch" "$title" "$TMP/missing.md"
rejects 'directory is not a body file' github "$repo" "$base" "$branch" "$title" "$TMP"
rejects 'missing argument' github "$repo" "$base" "$branch" "$title"
rejects 'unknown platform' typo "$repo" "$base" "$branch" "$title" "$body"
rejects 'repo without explicit host' github owner/repo "$base" "$branch" "$title" "$body"
rejects 'repo option injection' github --repo "$base" "$branch" "$title" "$body"
rejects 'empty title' github "$repo" "$base" "$branch" '' "$body"
rejects 'identical base and head' github "$repo" "$base" "$base" "$title" "$body"
for invalid in '' --flag HEAD refs/heads/main 'has space' 'has..dots' 'has~tilde' 'has^caret' 'has:colon' 'has?question' 'has*star' 'has[bracket' 'has\slash' 'has@{reflog' 'a//b' '/start' 'end/' '.hidden' 'a/.hidden' 'a.lock/b' 'end.' $'line\nbreak' $'carriage\rreturn'; do
  rejects "invalid base [$invalid]" github "$repo" "$invalid" "$branch" "$title" "$body"
  rejects "invalid head [$invalid]" github "$repo" "$base" "$invalid" "$title" "$body"
done
printf 'Scope: production PR helper, isolated PATH stub and exact argv; no real gh/tea, network, push or merge executed.\n'
printf 'Result: %s pass, %s fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
