# CLI Smoke Findings — `/xcheck` Task 1

Empirically confirmed non-interactive invocations for the three local AI agent
CLIs that `/xcheck` will shell out to. These values feed Task 2's `agents.toml`
verbatim.

**Environment**
- Platform: Windows 10 + Git Bash (MSYS), GNU coreutils `timeout` 8.32.
- Versions tested: `claude` 2.1.202, `codex` 0.141.0, `opencode` 1.17.12.
- Each command below was run with a 90s wall-clock timeout; every call returned
  well under that — **no CLI hung**.
- All three CLIs were already authenticated — no auth walls encountered.

## Decisions (the table Task 2 copies verbatim)

| CLI       | `input_mode` | `run_cmd` (template)                         | Reply text location in output                     |
|-----------|--------------|----------------------------------------------|---------------------------------------------------|
| claude    | `arg`        | `claude -p {prompt}`                         | Whole stdout (claude prints only the reply)       |
| codex     | `stdin`      | `codex exec -`                               | Last line of stdout (after a `codex` role banner) |
| opencode  | `arg`        | `opencode run {prompt}`                      | Last non-empty stdout line (after a small banner) |

`{prompt}` is substituted as a single shell-quoted argv element for `arg` CLIs.
For `stdin`, the prompt bytes are piped to `codex exec -`'s stdin (no argv
prompt). Template substitution + stdin piping will be implemented by the Task 2
carrier; the values above are the locked contract.

## `--format json` decision for opencode: **DROP — use default formatted text**

Tested both. `opencode run --format json "<prompt>"` *does* work: it emits an
NDJSON event stream where the reply sits in the `text` field of the
`{"type":"text", ...}` event. However:

- Default formatted text is clean and short (3 lines: a banner
  `> build · glm-5.2`, then the reply).
- A downstream Claude reader handles prose fine — no need to make it parse a
  JSON event stream and filter `step_start` / `step_finish` / `text` events.
- Per the task brief's default lean ("if unsure, choose default formatted
  text"), we drop `--format json`.

Decision: **`run_cmd = opencode run {prompt}`** (no `--format` flag).

## Evidence — the exact commands that returned the marker

### claude (arg) — marker `hello-from-claude` and `ok-multi-line`

```bash
$ timeout 90 claude -p "Reply with exactly this sentence and nothing else: hello-from-claude"
hello-from-claude
# exit 0

$ timeout 90 claude -p "$(cat /tmp/xcheck-smoke.txt)"   # multi-line stress
ok-multi-line
# exit 0
```

Multi-line file contained `"double quotes"`, `'single quotes'`, `$variables`,
and a newline; claude received it intact and replied `ok-multi-line`. Stdout is
just the reply — no banner, no noise.

### codex (stdin) — marker `hello-from-codex` and `ok-multi-line.`

```bash
$ echo "Reply with exactly this sentence and nothing else: hello-from-codex" \
    | timeout 90 codex exec -
# (banner + hooks + a few non-fatal MCP transport errors — see Quirks)
# final line of stdout:
hello-from-codex
# exit 0

$ timeout 90 codex exec - < /tmp/xcheck-smoke.txt        # multi-line stress
# final line of stdout:
ok-multi-line.
# exit 0
```

Codex prints a startup banner (`OpenAI Codex v0.141.0`, workdir, model,
approval, sandbox, session id), echoes the user prompt, emits hook lifecycle
lines (`hook: SessionStart`, `hook: UserPromptSubmit`, `hook: Stop`), then
prints the reply after a `codex` role label, then a `tokens used` summary. The
**reply is the last non-empty line before `hook: Stop`** — and conveniently also
re-echoed as the very last line. Multi-line + special chars survived intact.

### opencode (arg, default format) — marker `hello-from-opencode` and `ok-multi-line`

```bash
$ timeout 90 opencode run "Reply with exactly this sentence and nothing else: hello-from-opencode"

> build · glm-5.2

hello-from-opencode
# exit 0

$ timeout 90 opencode run "$(cat /tmp/xcheck-smoke.txt)"  # multi-line stress

> build · glm-5.2

ok-multi-line
# exit 0
```

Stdout has ANSI escapes and a one-line profile banner (`> build · glm-5.2`),
then a blank line, then the reply as the final non-empty line. Returned cleanly
within timeout on every run — **no hang observed**.

For completeness, `--format json` produced usable NDJSON (reply in the
`text`-typed event's `part.text`), but we drop it per the decision above:

```json
{"type":"text","timestamp":1786247246328,"sessionID":"ses_...","part":{"id":"prt_...","messageID":"msg_...","type":"text","text":"hello-from-opencode","time":{"start":1786247246316,"end":1786247246321}}}
```

## Quirks the carrier (Task 2) must handle

1. **codex noise + MCP errors.** Codex emits a multi-line banner, hook
   lifecycle lines, and (in this environment) repeated non-fatal
   `rmcp::transport::worker: worker quit with fatal: ... 127.0.0.1:12358/va/mcp`
   errors from an unreachable Vibearound MCP server. **These do not fail the
   run** (exit is still 0 and the reply is printed). The parser should not
   treat them as failure. Concretely: extract the reply as the **last
   non-empty stdout line**, or — more robustly — the line immediately before
   `hook: Stop`.
2. **opencode banner + ANSI.** Output starts with ANSI color escapes and a
   `> build · glm-5.2` profile banner, then the reply. Stripping ANSI is
   recommended but not strictly required (a Claude reader tolerates it). Reply
   is the final non-empty stdout line.
3. **No hang risk observed** for any CLI at 90s timeout; all runs returned in
   single-digit seconds.
4. **Auth** was preconfigured for all three CLIs — no login flow needed. If a
   future environment lacks auth, the CLI will surface a login message on
   stdout/stderr; treat that as "needs auth" and report (do not auto-login).

## Final `input_mode` for `agents.toml`

```toml
# claude
input_mode = "arg"      # run_cmd: claude -p {prompt}

# codex
input_mode = "stdin"    # run_cmd: codex exec -   (prompt piped to stdin)

# opencode
input_mode = "arg"      # run_cmd: opencode run {prompt}   (no --format flag)
```
