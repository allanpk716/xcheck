#!/usr/bin/env bash
# xcheck/tests/run-agent.test.sh — run-agent.sh 的 stub 回归测试。
# 零依赖(只要 bash + coreutils);stub CLI 模拟四类行为:正常/慢/冻结/失败。
# 跑法: bash xcheck/tests/run-agent.test.sh   (总耗时 ~15s)
# 覆盖:arg/stdin 两模式、超时击杀、--timeout 覆盖、挂起击杀、失败退出码、
#       未知 agent、空 prompt、缺 prompt、反斜杠路径、带空格目录、特殊字符
#       prompt(引号/$/反引号)、CLI 不在 PATH、残留清理、(msys)进程树击杀、
#       两层配置合并(0.25,ADR 0010:个人层 defaults/per-agent/新登记/run_cmd 覆盖)。

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$HERE/../lib/run-agent.sh"
TMP="$(mktemp -d)"
STUBS="$TMP/stubs"
mkdir -p "$STUBS" "$TMP/sp ace"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS: $*"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $*"; }
assert_eq() {  # <desc> <got> <want>
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 — got '$2' want '$3'"; fi
}
assert_contains() {  # <desc> <file> <literal>
  if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1 — '$2' 缺内容: $3"; fi
}

# ---- stub CLIs ----
printf '#!/usr/bin/env bash\nprintf "ARGS:%%s\\n" "$*"\n'        > "$STUBS/stub-ok"
printf '#!/usr/bin/env bash\nprintf "STDIN:%%s\\n" "$(cat)"\n'    > "$STUBS/stub-cat"
printf '#!/usr/bin/env bash\nsleep 300\n'                        > "$STUBS/stub-slow"
printf '#!/usr/bin/env bash\necho freeze-started\nsleep 300\n'   > "$STUBS/stub-freeze"
printf '#!/usr/bin/env bash\necho boom-stderr >&2\nexit 7\n'     > "$STUBS/stub-fail"
printf '#!/usr/bin/env bash\nsleep 300 &\necho $! > "%s/tree-child.pid"\nsleep 300\n' "$TMP" > "$STUBS/stub-tree"
chmod +x "$STUBS"/*

# ---- 测试专用 agents.toml ----
cat > "$TMP/test-agents.toml" <<'EOF'
[defaults]
timeout_sec = 30

[agents.stubok]
installed_check = "stub-ok"
run_cmd = "stub-ok -p"
input_mode = "arg"

[agents.stubcat]
installed_check = "stub-cat"
run_cmd = "stub-cat exec -"   # reads prompt from stdin
input_mode = "stdin"

[agents.stubslow]
installed_check = "stub-slow"
run_cmd = "stub-slow"
input_mode = "arg"
timeout_sec = 4

[agents.stubfreeze]
installed_check = "stub-freeze"
run_cmd = "stub-freeze"
input_mode = "arg"

[agents.stubfail]
installed_check = "stub-fail"
run_cmd = "stub-fail"
input_mode = "arg"

[agents.stubnosuch]
installed_check = "no-such-cli-xyz"
run_cmd = "no-such-cli-xyz -p"
input_mode = "arg"

[agents.stubtree]
installed_check = "stub-tree"
run_cmd = "stub-tree"
input_mode = "arg"
EOF

# ---- prompt 文件(特殊字符齐活) ----
cat > "$TMP/sp ace/prompt-special.txt" <<'EOF'
line1 "dq" 'sq' $HOME `bt` \back
中文 西瓜47
EOF
: > "$TMP/empty.txt"

TOML="$TMP/test-agents.toml"
# 个人层隔离(0.25,ADR 0010):全局指到不存在路径 = 强制关闭,防止本机真实个人层
# 泄漏进 fixture;两层合并用例(14~17)按需覆盖为受控 fixture。
export XCHECK_PERSONAL_TOML="$TMP/personal-absent.toml"
D="$TMP/sp ace"                       # 产物目录(带空格,顺带验证路径引用)
code() { cat "$D/$1.exitcode" 2>/dev/null; }

echo "== 1. arg 模式正常 =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubok "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "脚本退出码" "$SC" "0"
assert_eq "exitcode 文件" "$(code stubok)" "0"
assert_contains "stdout 收到全文" "$D/stubok.raw.stdout" '中文 西瓜47'
assert_contains "引号/字符原样" "$D/stubok.raw.stdout" "'sq'"
assert_contains "未被 shell 展开" "$D/stubok.raw.stdout" '$HOME'
assert_contains "取证 cmd.txt" "$D/stubok.cmd.txt" 'stub-ok'
assert_contains "run.log 存在" "$D/stubok.run.log" 'final exitcode=0'

echo "== 2. stdin 模式正常 =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubcat "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "exitcode 文件" "$(code stubcat)" "0"
assert_contains "stdin 收到全文" "$D/stubcat.raw.stdout" 'STDIN:'
assert_contains "stdin 中文" "$D/stubcat.raw.stdout" '西瓜47'

echo "== 3. per-agent timeout_sec=4 击杀 =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubslow "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "脚本退出码" "$SC" "0"
assert_eq "超时记 124" "$(code stubslow)" "124"
assert_contains "run.log 记超时" "$D/stubslow.run.log" 'timeout('

echo "== 4. --timeout 覆盖 toml =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubslow "$D/prompt-special.txt" --timeout 2 "$TOML"; SC=$?
assert_eq "override 记 124" "$(code stubslow)" "124"
assert_contains "用的是覆盖值" "$D/stubslow.run.log" '>= 2s'

echo "== 5. 挂起击杀(输出零增长) =="
XCHECK_STALL_SEC=3 XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubfreeze "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "挂起记 124" "$(code stubfreeze)" "124"
assert_contains "部分输出保留" "$D/stubfreeze.raw.stdout" 'freeze-started'
assert_contains "run.log 记挂起" "$D/stubfreeze.run.log" 'hang('

echo "== 6. 非零退出 + 残留清理 =="
printf '99\n' > "$D/stubfail.exitcode"   # 预埋 stale exitcode
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubfail "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "真退出码透传" "$(code stubfail)" "7"
assert_contains "stderr 落盘" "$D/stubfail.raw.stderr" 'boom-stderr'
assert_contains "旧 99 已被清" "$D/stubfail.run.log" 'final exitcode=7'

echo "== 7. 未知 agent =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" ghostagent "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "记 66" "$(code ghostagent)" "66"
assert_contains "run.log 记原因" "$D/ghostagent.run.log" '未登记'

echo "== 8. 空 prompt(产物落 prompt 所在目录 = TMP) =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubok "$TMP/empty.txt" "$TOML"; SC=$?
assert_eq "记 65" "$(cat "$TMP/stubok.exitcode" 2>/dev/null)" "65"
assert_contains "run.log 记预检" "$TMP/stubok.run.log" '预检失败'

echo "== 9. prompt 文件不存在(但目录在) =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubok "$D/nope.txt" "$TOML"; SC=$?
assert_eq "记 65" "$(code stubok)" "65"

echo "== 10. 反斜杠路径自动转正 =="
BS="${D//\//\\}\\prompt-special.txt"
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubok "$BS" "$TOML"; SC=$?
assert_eq "反斜杠也能跑" "$(code stubok)" "0"
assert_contains "内容完整" "$D/stubok.raw.stdout" '西瓜47'

echo "== 11. CLI 不在 PATH =="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubnosuch "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "记 67" "$(code stubnosuch)" "67"
assert_contains "run.log 记原因" "$D/stubnosuch.run.log" '不在 PATH'

echo "== 12. 用法错(缺参,无产物) =="
bash "$RUNNER" only-one-arg >/dev/null 2>&1; SC=$?
assert_eq "退出码 2" "$SC" "2"

if [[ -f /proc/self/winpid ]]; then
  echo "== 13. 进程树击杀(msys) =="
  XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubtree "$D/prompt-special.txt" --timeout 3 "$TOML"; SC=$?
  assert_eq "树根记 124" "$(code stubtree)" "124"
  sleep 1
  CHILD="$(cat "$TMP/tree-child.pid" 2>/dev/null || true)"
  if [[ -n "$CHILD" ]] && ! kill -0 "$CHILD" 2>/dev/null; then
    ok "子进程一并被杀"
  else
    bad "子进程仍存活(pid=$CHILD) —— taskkill //T 未生效"
  fi
else
  echo "== 13. 进程树击杀:非 msys,跳过 =="
fi

echo "== 14. 两层合并:个人层 [defaults].timeout_sec 覆盖模板 =="
cat > "$TMP/personal.toml" <<'EOF'
[defaults]
timeout_sec = 2
EOF
XCHECK_POLL_SEC=1 XCHECK_PERSONAL_TOML="$TMP/personal.toml" PATH="$STUBS:$PATH" bash "$RUNNER" stubfreeze "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "个人层默认超时生效记 124" "$(code stubfreeze)" "124"
assert_contains "用的是个人层值" "$D/stubfreeze.run.log" '>= 2s'
assert_contains "run.log 记两层来源" "$D/stubfreeze.run.log" 'personal='
rm -f "$TMP/personal.toml"

echo "== 15. 个人层 per-agent timeout_sec 覆盖模板(4s→2s)=="
cat > "$TMP/personal.toml" <<'EOF'
[agents.stubslow]
timeout_sec = 2
EOF
XCHECK_POLL_SEC=1 XCHECK_PERSONAL_TOML="$TMP/personal.toml" PATH="$STUBS:$PATH" bash "$RUNNER" stubslow "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "覆盖后仍记 124" "$(code stubslow)" "124"
assert_contains "个人层 2s 覆盖模板 4s" "$D/stubslow.run.log" '>= 2s'
rm -f "$TMP/personal.toml"

echo "== 16. 个人层登记模板没有的新 agent =="
cat > "$TMP/personal.toml" <<'EOF'
[agents.stubextra]
installed_check = "stub-ok"
run_cmd = "stub-ok -p"
input_mode = "arg"
EOF
XCHECK_POLL_SEC=1 XCHECK_PERSONAL_TOML="$TMP/personal.toml" PATH="$STUBS:$PATH" bash "$RUNNER" stubextra "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "个人层新 agent 跑通" "$(code stubextra)" "0"
assert_contains "走的是个人层 run_cmd" "$D/stubextra.raw.stdout" 'ARGS:'
rm -f "$TMP/personal.toml"

echo "== 17. 个人层覆盖 run_cmd/input_mode(同名字段后读覆盖)=="
cat > "$TMP/personal.toml" <<'EOF'
[agents.stubcat]
run_cmd = "stub-ok -p"
input_mode = "arg"
EOF
XCHECK_POLL_SEC=1 XCHECK_PERSONAL_TOML="$TMP/personal.toml" PATH="$STUBS:$PATH" bash "$RUNNER" stubcat "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "覆盖后跑通" "$(code stubcat)" "0"
assert_contains "改走 arg 模式" "$D/stubcat.raw.stdout" 'ARGS:'
if grep -qF 'STDIN:' "$D/stubcat.raw.stdout" 2>/dev/null; then bad "仍是 stdin 模式 —— 个人层未覆盖 input_mode"; else ok "input_mode 已被个人层覆盖"; fi
rm -f "$TMP/personal.toml"

echo "== 18. 个人层缺席 = 纯模板(layers 记 none)=="
XCHECK_POLL_SEC=1 PATH="$STUBS:$PATH" bash "$RUNNER" stubok "$D/prompt-special.txt" "$TOML"; SC=$?
assert_eq "无个人层照常" "$(code stubok)" "0"
assert_contains "layers 记 personal=none" "$D/stubok.run.log" 'personal=none'

echo
echo "结果: $PASS pass, $FAIL fail"
[[ $FAIL -eq 0 ]]
