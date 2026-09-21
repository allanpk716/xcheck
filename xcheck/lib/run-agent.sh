#!/usr/bin/env bash
# xcheck/lib/run-agent.sh — 全托管 agent 执行 supervisor。
#
# 诞生动因(2026-08-25):搬运工(subagent)手写 shell 传 prompt 是偶发故障源头 ——
# 命令由 LLM 按 Markdown 说明现场拼装,引号/路径形态/清残留全靠模型自觉,且故障
# 证据不落盘。本脚本把这条事故带(2026-08-14/15 两次实证)整体机械化。
#
# 用法:
#   bash run-agent.sh <agent> <prompt_file> [--timeout N] [agents.toml]
#     <agent>        登记表里 [agents.<name>] 的 key(模板或个人层任一)
#     <prompt_file>  指令层 prompt 文件(绝对路径;反斜杠自动转正斜杠)
#     --timeout N    覆盖 toml 超时(冒烟用短值);不传取 per-agent > [defaults]
#     [agents.toml]  可选;缺省读脚本同级 ../agents.toml(模板层,测试用)
#
# 配置两层(0.25,ADR 0010):模板 agents.toml + 个人层 ~/.claude/xcheck/personal.toml
#   (XCHECK_PERSONAL_TOML 可覆盖个人层路径;指到不存在的路径 = 强制关闭)。
#   同名字段个人层覆盖模板;个人层缺席 = 纯模板。
#
# 产物(全落在 prompt_file 同目录):
#   <agent>.raw.stdout / .raw.stderr  CLI 的 stdout / stderr
#   <agent>.exitcode                  终态退出码(见下)
#   <agent>.cmd.txt                   取证:实际执行的命令(%q 转义,可重放)
#   <agent>.run.log                   脚本层诊断:预检/击杀原因/耗时
#
# 铁律:只要 prompt 目录推得出来,脚本结束时 <agent>.exitcode **必定存在**
#       (连预检失败也写) —— 搬运工永远不会陷入"CODE 缺失傻等满超时"。
#
# exitcode 语义:0 成功;124 超时或挂起击杀;65 预检失败(prompt 缺失/为空/toml 缺);
#   66 agent 未登记或字段非法;67 CLI 不在 PATH;其余 = agent CLI 真实退出码。
# 脚本自身退出码:0 = 监护完成(终态已落盘,成败看 exitcode 文件);2 = 用法错。
#
# 内部节流参数(测试可环境覆盖):XCHECK_POLL_SEC(默认 15)、XCHECK_STALL_SEC(默认 600)。
#
# 设计约束:
# - run_cmd 按空格分词、token 内不含空格(agents.toml 登记约束,现有各家均满足);
# - CLI 作为**直接子进程**启动,不经 bash -lc 二层壳(消灭外层单引号炸弹);
# - 击杀走 msys /proc/<pid>/winpid + taskkill //F //T 杀进程树,非 Windows 回退 kill -9。

set -uo pipefail

POLL="${XCHECK_POLL_SEC:-15}"
STALL="${XCHECK_STALL_SEC:-600}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TOML="$SCRIPT_DIR/../agents.toml"

die_usage() {
  echo "usage: bash run-agent.sh <agent> <prompt_file> [--timeout N] [agents.toml]" >&2
  exit 2
}

[[ $# -ge 2 ]] || die_usage
AGENT="$1"; shift
PROMPT_RAW="$1"; shift
TIMEOUT_ARG=""
TOML="$DEFAULT_TOML"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) [[ $# -ge 2 ]] || die_usage; TIMEOUT_ARG="$2"; shift 2 ;;
    *)         TOML="$1"; shift ;;
  esac
done

# ---- 路径规范化:反斜杠 → 正斜杠(2026-08-15 实证:$(cat 反斜杠路径) 静默读空) ----
PROMPT="${PROMPT_RAW//\\//}"
DIR="${PROMPT%/*}"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "ERROR: prompt 目录不存在或推不出: $PROMPT" >&2
  exit 2
fi

OUT="$DIR/$AGENT.raw.stdout"
ERRF="$DIR/$AGENT.raw.stderr"
CODE="$DIR/$AGENT.exitcode"
CMDTXT="$DIR/$AGENT.cmd.txt"
RUNLOG="$DIR/$AGENT.run.log"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$RUNLOG"; }

finish() { # finish <exitcode> —— 终态唯一出口
  printf '%s\n' "$1" > "$CODE"
  log "final exitcode=$1"
  exit 0
}

# ---- 清残留(2026-08-15 实证:失败重跑复用同名文件,旧 exitcode 让本轮成败误判) ----
rm -f "$OUT" "$ERRF" "$CODE" "$CMDTXT" "$RUNLOG"
log "start agent=$AGENT prompt=$PROMPT poll=${POLL}s stall=${STALL}s"

# ---- 预检 ----
if [[ ! -f "$TOML" ]]; then
  log "预检失败: agents.toml 不存在: $TOML"
  echo "ERROR: agents.toml not found: $TOML" >&2
  finish 65
fi
if [[ ! -f "$PROMPT" ]]; then
  log "预检失败: prompt 文件不存在: $PROMPT"
  echo "ERROR: prompt file not found: $PROMPT" >&2
  finish 65
fi
PBYTES="$(wc -c < "$PROMPT" 2>/dev/null || echo 0)"
if [[ "${PBYTES:-0}" -eq 0 ]]; then
  log "预检失败: prompt 为空(0 字节) —— 严禁带空 prompt 去跑 CLI"
  echo "ERROR: prompt file empty (0 bytes): $PROMPT" >&2
  finish 65
fi
log "预检 ok: prompt ${PBYTES} bytes"

# ---- 解析配置两层:模板 agents.toml 先读、个人层 personal.toml 后读 ----
# 轻量 bash 解析;容忍 CRLF 与行内 # 注释。同名字段后读覆盖先读(个人层覆盖模板);
# 个人层还能登记模板没有的新 agent(run_cmd 等字段只设不覆盖模板缺席项)。
PERSONAL="${XCHECK_PERSONAL_TOML-$HOME/.claude/xcheck/personal.toml}"
[[ -n "$PERSONAL" && -f "$PERSONAL" ]] || PERSONAL=""

run_cmd=""; input_mode=""; agent_to=""; def_to=""
cur=""
parse_layer() {
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" =~ ^[[:space:]]*\[.*\] ]]; then
      cur="${line%%\]*}"; cur="${cur#\[}"
      continue
    fi
    [[ "$line" == *"="* ]] || continue
    key="${line%%=*}"; key="${key//[[:space:]]/}"
    val="${line#*=}"
    if [[ "$val" == *\"* ]]; then          # 带引号值:取到闭引号(容忍行内注释)
      val="${val#*\"}"; val="${val%%\"*}"
    else                                    # 裸值:截掉行内注释
      val="${val%%#*}"
      val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    fi
    case "$cur" in
      defaults)
        [[ "$key" == "timeout_sec" ]] && def_to="$val"
        ;;
      "agents.$AGENT")
        case "$key" in
          run_cmd)     run_cmd="$val" ;;
          input_mode)  input_mode="$val" ;;
          timeout_sec) agent_to="$val" ;;
        esac
        ;;
    esac
  done < "$1"
}
parse_layer "$TOML"
[[ -n "$PERSONAL" ]] && parse_layer "$PERSONAL"

if [[ -z "$run_cmd" ]]; then
  log "agent 未登记或 run_cmd 缺失: $AGENT (layers: $TOML${PERSONAL:+ + $PERSONAL})"
  echo "ERROR: agent '$AGENT' not registered (no run_cmd) in $TOML${PERSONAL:+ or $PERSONAL}" >&2
  finish 66
fi
if [[ "$input_mode" != "arg" && "$input_mode" != "stdin" ]]; then
  log "input_mode 非法: ${input_mode:-<空>}"
  echo "ERROR: bad input_mode '$input_mode' for $AGENT" >&2
  finish 66
fi

TIMEOUT="${TIMEOUT_ARG:-${agent_to:-$def_to}}"
TIMEOUT="${TIMEOUT:-2700}"
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -eq 0 ]]; then
  log "timeout 非正整数: $TIMEOUT"
  echo "ERROR: bad timeout '$TIMEOUT'" >&2
  finish 66
fi
log "config: run_cmd='$run_cmd' input_mode=$input_mode timeout=${TIMEOUT}s layers: template=$TOML personal=${PERSONAL:-none}"

# ---- CLI 可用性(消灭 command-not-found 静默态) ----
read -r -a CMDPARTS <<< "$run_cmd"
CLI_BIN="${CMDPARTS[0]}"
if ! command -v "$CLI_BIN" >/dev/null 2>&1; then
  log "CLI 不在 PATH: $CLI_BIN"
  echo "ERROR: '$CLI_BIN' not on PATH" >&2
  finish 67
fi

# ---- 构造 + 取证:启动**前**先落 cmd.txt(进程可能秒退,启动后补写就来不及) ----
# set -m:让后台 job 获得独立进程组(pgid = PID),击杀时可整组杀 —— 2026-08-25 实测
# taskkill //T 杀不到 msys 孙进程(cygwin fork 模拟导致 Windows 父子链断裂),
# 进程组语义完整,两层并用才兜得住「脚本型 CLI + msys 子孙」与「原生 CLI + 原生子孙」。
PID=""
set -m
if [[ "$input_mode" == "arg" ]]; then
  PTEXT="$(cat "$PROMPT")"
  printf 'cmd: %s\n' "$(printf '%q ' "${CMDPARTS[@]}")$(printf '%q' "$PTEXT")" > "$CMDTXT"
  "${CMDPARTS[@]}" "$PTEXT" > "$OUT" 2> "$ERRF" &
  PID=$!
else
  printf 'cmd: %s\n' "$(printf '%q ' "${CMDPARTS[@]}")< $PROMPT" > "$CMDTXT"
  "${CMDPARTS[@]}" < "$PROMPT" > "$OUT" 2> "$ERRF" &
  PID=$!
fi
set +m
printf 'meta: agent=%s mode=%s timeout=%ss pid=%s\n' "$AGENT" "$input_mode" "$TIMEOUT" "$PID" >> "$CMDTXT"
log "launched pid=$PID"
echo "[run-agent] $AGENT pid=$PID timeout=${TIMEOUT}s —— 监控中(poll=${POLL}s stall=${STALL}s)"

# ---- 击杀:进程组(msys 子孙)+ taskkill //T(原生子孙)+ 直接 kill,三层兜底 ----
kill_tree() {
  local p="$1" wp
  kill -9 -- "-$p" 2>/dev/null || true            # msys 进程组整组(脚本型 CLI 的子孙)
  wp="$(cat "/proc/$p/winpid" 2>/dev/null || true)"
  if [[ -n "$wp" ]] && command -v taskkill >/dev/null 2>&1; then
    taskkill //F //T //PID "$wp" >/dev/null 2>&1 || true   # 原生进程树(node 等的子进程)
  fi
  kill -9 "$p" 2>/dev/null || true
}

# ---- 监控循环:进程结束取真码;超时 / 输出零增长 → 杀树记 124 ----
START="$(date +%s)"
LAST_GROW="$START"
LAST_BYTES=0
RESULT=""
while kill -0 "$PID" 2>/dev/null; do
  sleep "$POLL"
  NOW="$(date +%s)"
  ELAPSED=$(( NOW - START ))
  if (( ELAPSED >= TIMEOUT )); then
    RESULT="timeout(${ELAPSED}s >= ${TIMEOUT}s)"
    break
  fi
  BYTES=$(( $(stat -c %s "$OUT" 2>/dev/null || echo 0) + $(stat -c %s "$ERRF" 2>/dev/null || echo 0) ))
  if (( BYTES > LAST_BYTES )); then
    LAST_BYTES=$BYTES; LAST_GROW=$NOW
  elif (( NOW - LAST_GROW >= STALL )); then
    RESULT="hang(输出 ${STALL}s 零增长,共 ${BYTES} 字节)"
    break
  fi
done

if [[ -n "$RESULT" ]]; then
  kill_tree "$PID"
  wait "$PID" 2>/dev/null
  log "killed: $RESULT"
  echo "[run-agent] $AGENT killed: $RESULT"
  finish 124
fi
wait "$PID"
RC=$?
log "exited rc=$RC"
finish "$RC"
