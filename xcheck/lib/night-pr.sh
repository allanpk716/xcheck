#!/usr/bin/env bash
# PR boundary only. Caller owns authorization, frozen targets and branch publication.
# <github|gitea|unsupported> <host/owner/repo> <base> <branch> <title> <body-file>
set -uo pipefail
fail() { printf 'night-pr: %s\n' "$*" >&2; exit 2; }
not_created() { printf 'status=not-created\nreason=%s\n' "$1"; exit "$2"; }
[[ $# -eq 6 ]] || fail 'expected platform, host/owner/repo, base, branch, title and body-file'
platform="$1"; repo="$2"; base="$3"; branch="$4"; title="$5"; body="$6"
case "$platform" in github|gitea|unsupported) ;; *) fail 'invalid platform';; esac
[[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || fail 'expected explicit host/owner/repo'
valid_branch() {
  local ref="$1" component
  [[ -n "$ref" && "$ref" != -* && "$ref" != HEAD && "$ref" != refs/* && "$ref" != @ ]] || return 1
  [[ "$ref" != /* && "$ref" != */ && "$ref" != *//* && "$ref" != *..* && "$ref" != *'@{'* && "$ref" != *. ]] || return 1
  [[ ! "$ref" =~ [[:cntrl:][:space:]~^:?*\[\\] ]] || return 1
  local -a components
  IFS=/ read -r -a components <<< "$ref"
  for component in "${components[@]}"; do
    [[ "$component" != .* && "$component" != *.lock ]] || return 1
  done
}
valid_branch "$base" || fail 'invalid base branch'
valid_branch "$branch" || fail 'invalid head branch'
[[ "$base" != "$branch" ]] || fail 'base and head must differ'
[[ -n "$title" ]] || fail 'title is required'
[[ "$body" != - && -f "$body" && -r "$body" ]] || fail 'body-file must be a readable file, not stdin'
[[ "$platform" == github ]] || not_created unsupported-platform 0
command -v gh >/dev/null 2>&1 || not_created missing-gh 0
# Query failures are not evidence of absence. Never fall through to create.
# gh pr list --head does not support owner:branch. Ignore forks with a same-name
# branch: the caller publishes this night branch only to the frozen repository.
url="$(gh pr list --repo "$repo" --base "$base" --head "$branch" --state open --json url,isCrossRepository --jq 'map(select(.isCrossRepository == false))[0].url // empty')" || not_created query-failed 1
valid_url() {
  local prefix="https://$repo/pull/"
  [[ "$1" == "$prefix"* && "${1#"$prefix"}" =~ ^[0-9]+$ ]]
}
if [[ -n "$url" ]]; then
  valid_url "$url" || not_created invalid-query-output 1
  printf 'status=existing\nurl=%s\n' "$url"
  exit 0
fi
# Equals-form keeps leading dashes in free text/paths from becoming CLI flags.
# The UTF-8 body stays in its file, never inline on the command line.
url="$(gh pr create --repo "$repo" --base "$base" --head "$branch" --title="$title" --body-file="$body")" || not_created create-failed 1
valid_url "$url" || not_created invalid-create-output 1
printf 'status=created\nurl=%s\n' "$url"
