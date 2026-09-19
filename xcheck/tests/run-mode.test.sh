#!/usr/bin/env bash
# 直接调用真实模式解析器;离线检查,不调用模型、不实施、不发布。
# bash xcheck/tests/run-mode.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$ROOT/xcheck/lib/run-mode.sh"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
SANDBOX="$TMP/project with spaces"
mkdir -p "$SANDBOX/.xcheck/existing" || exit 2
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }
[[ -f "$SCRIPT" ]] || { printf 'Missing production helper: %s\n' "$SCRIPT" >&2; exit 2; }

# 预期是固定模式矩阵,不是测试内重写解析器。
INTERACTIVE=$'interaction = interactive\ntarget = review\nnight_mode = 0'
AUTO_REVIEW=$'interaction = unattended\ntarget = review\nnight_mode = 0'
NIGHT=$'interaction = unattended\ntarget = implementation\nnight_mode = 1'
accepts() {
  local label="$1" expected="$2" status actual
  shift 2
  (cd "$SANDBOX" && bash "$SCRIPT" "$@") > "$TMP/stdout" 2> "$TMP/stderr"
  status=$?; actual="$(< "$TMP/stdout")"
  if [[ "$status" -eq 0 && "$actual" == "$expected" && ! -s "$TMP/stderr" ]]; then
    ok "$label"
  else
    bad "$label (exit=$status, stdout=$actual, stderr=$(< "$TMP/stderr"))"
  fi
}
rejects() {
  local label="$1" status
  shift
  (cd "$SANDBOX" && bash "$SCRIPT" "$@") > "$TMP/stdout" 2> "$TMP/stderr"
  status=$?
  if [[ "$status" -eq 2 && ! -s "$TMP/stdout" && -s "$TMP/stderr" ]]; then
    ok "$label"
  else
    bad "$label (exit=$status, stdout=$(< "$TMP/stdout"), stderr=$(< "$TMP/stderr"))"
  fi
}
# 只审计本测试工作区的路径和内容;不声称操作系统级副作用隔离。
snapshot() (
  cd "$SANDBOX" || exit 2
  shopt -s globstar dotglob nullglob
  for path in **; do
    if [[ -f "$path" ]]; then cksum -- "$path"
    elif [[ -d "$path" ]]; then printf 'directory: %s\n' "$path"
    else printf 'other: %s\n' "$path"; fi
  done
)
printf 'review_schema = 999\ninteraction = unattended\ntarget = implementation\nnight = on\n' > "$SANDBOX/.xcheck/existing/PROGRESS.md"
printf 'review_schema = 999\n- [ ] finish\n' > "$SANDBOX/.xcheck/existing/NIGHT.md"
printf 'Original proposal; do not edit.\n' > "$SANDBOX/proposal.md"
snapshot > "$TMP/before"

printf '== New run matrix ==\n'
accepts 'default new run remains interactive review' "$INTERACTIVE" default
accepts 'interactive new run is review only' "$INTERACTIVE" interactive
accepts 'auto-review is unattended review, not night implementation' "$AUTO_REVIEW" auto-review
accepts 'night is unattended implementation' "$NIGHT" night

printf '== Persisted authorization and legacy metadata ==\n'
accepts 'unflagged resume preserves interactive review' "$INTERACTIVE" default interactive review -
accepts 'unflagged resume preserves unattended review' "$AUTO_REVIEW" default unattended review -
accepts 'explicit auto-review matches unattended review' "$AUTO_REVIEW" auto-review unattended review -
accepts 'explicit night matches legacy night metadata' "$NIGHT" night - - on
accepts 'unflagged resume preserves implementation without legacy alias' "$NIGHT" default unattended implementation -
accepts 'explicit night matches persisted authorization and legacy alias' "$NIGHT" night unattended implementation on
accepts 'legacy absent pair and night map to interactive review' "$INTERACTIVE" default - - -
accepts 'legacy absent pair with night on maps to implementation' "$NIGHT" default - - on

printf '== Reject mismatched authorization in both directions ==\n'
rejects 'night cannot upgrade interactive review' night interactive review -
rejects 'night cannot upgrade unattended review' night unattended review -
rejects 'auto-review cannot relabel interactive review' auto-review interactive review -
rejects 'auto-review cannot downgrade implementation' auto-review unattended implementation on
rejects 'interactive cannot relabel unattended review' interactive unattended review -
rejects 'interactive cannot downgrade implementation' interactive unattended implementation -

printf '== Reject malformed metadata and requests ==\n'
rejects 'partial pair missing interaction is not legacy' default - review -
rejects 'partial pair missing target is not repaired by night on' default unattended - on
rejects 'interactive implementation is not a valid pair' default interactive implementation -
rejects 'unknown interaction is rejected' default automatic review -
rejects 'unknown target is rejected' default unattended deploy -
rejects 'legacy night on cannot coexist with review target' default unattended review on
rejects 'invalid legacy night value is rejected' default unattended review off
rejects 'conflicting request is not accepted as a combined mode' 'auto-review night'
rejects 'extra schema argument is outside the helper API' default unattended review - 999

printf '== Scope and no workspace writes ==\n'
# cwd中故意留未知schema。helper只解析传入字段,不能代替壳/flow的版本守卫。
accepts 'schema remains caller responsibility; helper does not scan cwd metadata' "$AUTO_REVIEW" default unattended review -
snapshot > "$TMP/after"
if cmp -s "$TMP/before" "$TMP/after"; then
  ok 'success and rejection leave sandbox paths and file contents unchanged'
else
  bad 'helper changed sandbox paths or file contents'
fi

printf '== Minimal production wiring (static only) ==\n'
skill="$(< "$ROOT/xcheck/SKILL.md")"
flow="$(< "$ROOT/xcheck/lib/flow.md")"
intake="$(< "$ROOT/xcheck/lib/context-intake.md")"
if [[ "$skill" == *'--auto-review'* && "$skill" == *'run-mode.sh'* && "$skill" == *'review_schema'* ]]; then
  ok 'entry wires auto-review to helper while retaining separate schema guard'
else
  bad 'entry lacks auto-review/helper/schema guard wiring'
fi
if [[ "$flow" == *'run-mode.sh'* && "$flow" == *'INTERACTION'* && "$flow" == *'TARGET'* && "$flow" == *'implementation'* ]]; then
  ok 'flow uses helper and separates interaction from implementation target'
else
  bad 'flow lacks helper or separate interaction/target wiring'
fi
if [[ "$intake" == *'interaction'* && "$intake" == *'target'* && "$intake" == *'INTERACTION'* ]]; then
  ok 'intake persists mode pair and uses interaction policy'
else
  bad 'intake lacks mode pair persistence or interaction policy'
fi
if [[ "$skill" == *'MODE_REQUEST'* && "$flow" == *'MODE_REQUEST'* && "$flow" != *'REQUEST_MODE'* ]]; then
  ok 'entry and recovery use the same request variable'
else
  bad 'request variable diverges between entry and recovery'
fi
printf 'Scope: real helper matrix, sandbox write check, static Markdown wiring; no CLI, semantic replay, schema validation, permissions, implementation or publishing tested.\n'
printf 'Result: %s pass, %s fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
