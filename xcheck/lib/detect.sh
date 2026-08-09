#!/usr/bin/env bash
# xcheck/lib/detect.sh — list which registered agent CLIs are installed on PATH.
# Usage: bash detect.sh [path/to/agents.toml]
# stdout: one line per INSTALLED agent:  "<name>\t<installed_check>\tinstalled"
# stderr: one line per MISSING agent:    "<name>\t<installed_check>\tmissing"

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOML="${1:-$SCRIPT_DIR/../agents.toml}"

if [[ ! -f "$TOML" ]]; then
  echo "ERROR: agents.toml not found at: $TOML" >&2
  exit 1
fi

# Collect (name, installed_check) pairs from [agents.<name>] blocks.
NAMES=()
CHECKS=()
current=""
while IFS= read -r line || [[ -n "$line" ]]; do
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
      NAMES+=("$current")
      CHECKS+=("$val")
      current=""
      ;;
  esac
done < "$TOML"

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
