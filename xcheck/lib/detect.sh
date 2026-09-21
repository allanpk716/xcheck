#!/usr/bin/env bash
# xcheck/lib/detect.sh — list which registered agent CLIs are installed on PATH.
# Usage: bash detect.sh [path/to/agents.toml]
# 配置两层(0.25,ADR 0010):模板 agents.toml + 个人层 ~/.claude/xcheck/personal.toml
#   (XCHECK_PERSONAL_TOML 可覆盖个人层路径;指到不存在的路径 = 强制关闭)。
#   登记表 = 两层并集;同名 agent 个人层覆盖 installed_check(保序:沿用模板原位)。
# stdout: one line per INSTALLED agent:  "<name>\t<installed_check>\tinstalled"
# stderr: one line per MISSING agent:    "<name>\t<installed_check>\tmissing"

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOML="${1:-$SCRIPT_DIR/../agents.toml}"

if [[ ! -f "$TOML" ]]; then
  echo "ERROR: agents.toml not found at: $TOML" >&2
  exit 1
fi

PERSONAL="${XCHECK_PERSONAL_TOML-$HOME/.claude/xcheck/personal.toml}"
[[ -n "$PERSONAL" && -f "$PERSONAL" ]] || PERSONAL=""

# Collect (name, installed_check) pairs from [agents.<name>] blocks; dedupe by name.
NAMES=()
CHECKS=()
declare -A SEEN=()
collect() {
  local line val
  current=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"   # strip trailing CR -> CRLF-tolerant (git autocrlf on Windows)
    case "$line" in
      \[agents.*\])
        current="${line#\[agents.}"
        current="${current%\]}"
        ;;
      installed_check*)
        [[ -z "$current" ]] && continue
        val="${line#*=}"
        val="${val//\"/}"        # strip quotes
        val="${val#"${val%%[![:space:]]*}"}"   # trim leading whitespace
        val="${val%"${val##*[![:space:]]}"}"   # trim trailing whitespace
        if [[ -n "${SEEN[$current]:-}" ]]; then
          CHECKS["$(( SEEN[$current] ))"]="$val"   # 个人层同名重登记:覆盖 check,保原位
        else
          SEEN[$current]=${#NAMES[@]}
          NAMES+=("$current")
          CHECKS+=("$val")
        fi
        current=""
        ;;
    esac
  done < "$1"
}
collect "$TOML"
[[ -n "$PERSONAL" ]] && collect "$PERSONAL"

if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo "ERROR: no agents found in $TOML" >&2
  exit 1
fi

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  check="${CHECKS[$i]}"
  if command -v "$check" >/dev/null 2>&1; then
    printf '%s\t%s\tinstalled\n' "$name" "$check"
  else
    printf '%s\t%s\tmissing\n' "$name" "$check" >&2
  fi
done
