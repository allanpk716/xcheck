#!/usr/bin/env bash
# Resolve a requested mode against optional persisted metadata. No side effects.
# run-mode.sh <default|interactive|auto-review|night> [<interaction|-> <target|-> <night|->]
set -uo pipefail
fail() { printf 'run-mode: %s\n' "$*" >&2; exit 2; }
[[ $# -eq 1 || $# -eq 4 ]] || fail 'expected request, or request and three persisted fields'
request="$1"
case "$request" in default|interactive|auto-review|night) ;; *) fail 'invalid or conflicting request';; esac
interaction=interactive; target=review
if [[ $# -eq 4 ]]; then
  interaction="$2"; target="$3"; legacy="$4"
  [[ "$legacy" == '-' || "$legacy" == on ]] || fail 'invalid legacy night field'
  if [[ "$interaction" == '-' && "$target" == '-' ]]; then
    if [[ "$legacy" == on ]]; then interaction=unattended; target=implementation
    else interaction=interactive; target=review; fi
  elif [[ "$interaction" == '-' || "$target" == '-' ]]; then
    fail 'partial persisted mode'
  fi
  case "$interaction/$target" in
    interactive/review|unattended/review|unattended/implementation) ;;
    *) fail 'invalid persisted mode pair';;
  esac
  [[ "$legacy" != on || "$interaction/$target" == unattended/implementation ]] || fail 'legacy night conflicts with persisted mode'
  case "$request" in
    default) ;;
    interactive) [[ "$interaction/$target" == interactive/review ]] || fail 'request does not match persisted mode';;
    auto-review) [[ "$interaction/$target" == unattended/review ]] || fail 'request does not match persisted mode';;
    night) [[ "$interaction/$target" == unattended/implementation ]] || fail 'request does not match persisted mode';;
  esac
else
  case "$request" in
    default|interactive) ;;
    auto-review) interaction=unattended;;
    night) interaction=unattended; target=implementation;;
  esac
fi
printf 'interaction = %s\ntarget = %s\n' "$interaction" "$target"
if [[ "$target" == implementation ]]; then printf 'night_mode = 1\n'; else printf 'night_mode = 0\n'; fi
