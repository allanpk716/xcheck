#!/usr/bin/env bash
# Mechanical night Git boundary (0.22 lean). Caller owns authorization and ledgers.
# start    <repo> <branch> <start_oid>   — create/take over the night branch in the current checkout
# snapshot <repo> <refname>              — gc-protected content snapshot of tracked dirty state
# publish  <repo> <branch> <remote_url>  — push the night branch to an explicit URL: no hooks, no prompts, no force
# Trust model (ADR 0004): stops LLM mistakes (TM-1) and reviewed-material injection (TM-2).
# Hostile ambient config (TM-3) is out of scope by decision.
set -uo pipefail
fail() { printf 'night-git: %s\n' "$*" >&2; exit 2; }
[[ $# -ge 3 ]] || fail 'expected command, repo and command arguments'
action="$1"; repo="$2"; shift 2
case "$action" in
  start)    [[ $# -eq 2 ]] || fail 'start requires branch and start_oid'; branch="$1"; baseline="$2";;
  snapshot) [[ $# -eq 1 ]] || fail 'snapshot requires refname'; branch="";;
  publish)  [[ $# -eq 2 ]] || fail 'publish requires branch and remote URL'; branch="$1"; url="$2";;
  *) fail 'unknown command';;
esac
# Ambient Git overrides could silently redirect writes to a different repository.
for key in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE; do
  [[ ! -v "$key" ]] || fail "unsupported ambient override: $key"
done
canonical_dir() { (cd -- "$1" && pwd -P); }
repo="$(canonical_dir "$repo")" || fail 'repository directory is missing'
[[ "$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)" == true ]] || fail 'expected a working repository, not a bare repository'
root="$(git -C "$repo" rev-parse --show-toplevel)" || fail 'cannot resolve repository root'
repo="$(canonical_dir "$root")" || fail 'cannot resolve repository root'
if [[ -n "$branch" ]]; then
  [[ "$branch" != -* && "$branch" != HEAD && "$branch" != refs/* ]] || fail 'expected a literal local branch name'
  git check-ref-format "refs/heads/$branch" >/dev/null 2>&1 || fail 'invalid branch name'
fi

if [[ "$action" == start ]]; then
  [[ "$baseline" =~ ^[0-9a-f]{40}$ || "$baseline" =~ ^[0-9a-f]{64}$ ]] || fail 'expected a full lowercase commit OID'
  ref="refs/heads/$branch"
  if git -C "$repo" show-ref --verify --quiet "$ref"; then
    if [[ "$(git -C "$repo" symbolic-ref -q HEAD)" == "$ref" ]]; then
      printf 'status=started\nmode=idempotent\n'
      exit 0
    fi
    if git -C "$repo" switch "$branch" >/dev/null 2>&1; then
      printf 'status=started\nmode=resumed\n'
      exit 0
    fi
    printf 'status=blocked\nreason=operator-changes-conflict\n'
    exit 1
  fi
  [[ "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" == "$baseline" ]] || fail 'HEAD moved since intake; night branch was never created; re-freeze the baseline or resolve manually'
  git -C "$repo" switch -c "$branch" >/dev/null 2>&1 || fail 'branch creation failed'
  printf 'status=started\nmode=created\n'
  exit 0
fi

if [[ "$action" == snapshot ]]; then
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'expected a simple ref name'
  # stash create captures tracked dirty state (index+worktree) without touching either;
  # untracked dirty content is NOT covered (recorded limitation, ADR 0005 appendix).
  oid="$(git -C "$repo" stash create 2>/dev/null)" || fail 'snapshot creation failed'
  if [[ -z "$oid" ]]; then
    printf 'snapshot=none\nreason=clean-tree\n'
    exit 0
  fi
  git -C "$repo" update-ref "refs/xcheck/$1" "$oid" || fail 'cannot protect snapshot ref'
  printf 'snapshot=%s\nref=refs/xcheck/%s\n' "$oid" "$1"
  exit 0
fi

# publish
[[ -n "$url" && "$url" != *$'\n'* && "$url" != *$'\r'* ]] || fail 'invalid remote URL'
ref="refs/heads/$branch"
git -C "$repo" show-ref --verify --quiet "$ref" || fail "night branch does not exist: $branch"
[[ "$(git -C "$repo" symbolic-ref -q HEAD)" == "$ref" ]] || fail 'publish requires the checkout to be on the night branch'
# Non-interactive surface (TM-1): no terminal prompts, no GUI helpers, no askpass;
# credential helpers stay enabled (GCM cached credentials are the legitimate HTTPS path).
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS= SSH_ASKPASS=
push_args=(push --no-verify --no-follow-tags --recurse-submodules=no -- "$url" "$ref:$ref")
if [[ "$url" == git@* || "$url" == ssh://* || "$url" == ssh://*:* ]]; then
  push_args=(-c core.sshCommand='ssh -o BatchMode=yes' "${push_args[@]}")
fi
# Transport diagnostics can echo credential-bearing URLs; expose only the outcome.
git -C "$repo" "${push_args[@]}" >/dev/null 2>&1 || { printf 'night-git: publication failed; local branch and commits retained\n' >&2; exit 1; }
printf 'status=published\n'
