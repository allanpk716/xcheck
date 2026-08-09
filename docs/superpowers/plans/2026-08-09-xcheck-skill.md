# xcheck Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a global Claude Code skill set (`/xcheck`, `/xcheck-diag`, `/xcheck-review`, `/xcheck-setup`) that runs a technical question/proposal through several heterogeneous local AI agent CLIs in parallel, collects each independent opinion via isolated subagents (carry-only, no judging), and has the main session synthesize consensus/divergence/verdict for the user to decide.

**Architecture:** Four skills under `~/.claude/skills/`. `xcheck/` holds all shared resources (`agents.toml`, `lib/`, `prompts/`); `xcheck-diag/`, `xcheck-review/`, `xcheck-setup/` are thin SKILL.md shells that reference shared files. The main Claude session orchestrates: detect installed CLIs → user multi-selects agents → dispatch one subagent (cheap tier) per selected agent, each subagent shells out to its CLI's non-interactive command and faithfully returns that agent's conclusion → main session synthesizes. Heterogeneity is enforced by reminding the user to pick ≥1 non-Claude agent.

**Tech Stack:** Claude Code skills (SKILL.md + YAML frontmatter, `disable-model-invocation: true`, `$ARGUMENTS`); Bash (Git Bash / MSYS on Windows); TOML config; Markdown prompt templates. External CLIs: `claude -p`, `codex exec`, `opencode run`.

## Global Constraints

(From the approved spec — every task implicitly includes these.)

- **Platform:** Windows + Git Bash (MSYS). Use MSYS `timeout`; mind quote-escaping and path formats (`/c/` vs `C:\`).
- **Installed CLIs (verified 2026-08-09):** `claude` 2.1.202, `codex` 0.141.0, `opencode` 1.17.12. Detection must be **dynamic** (`which`/`command -v`), never hardcoded.
- **Skills install location:** `~/.claude/skills/` (global, all projects). Deliverable files go here, NOT in the project repo.
- **Verification model (adapted — this is a skill/prose project, not a unit-tested codebase):** There is no pytest suite. Each task's "test cycle" is a **behavioral verification** — invoke the command (or run the script) and observe the output matches the stated expectation. Where a script exists (`detect.sh`), it has a concrete run-and-check. A newly created skill may require a Claude Code restart (or `/reload`) to be registered before it can be invoked.
- **Version control:** `./xcheck` is not a git repo by default. The design + plan live here; the skill sources live in `~/.claude/skills/`. Per-task "commits" are therefore **behavioral checkpoints** (verify & record), not git commits. Optional: `git init` the project dir and keep a versioned mirror copy of the skill sources under `./xcheck\skill-src\` if history is desired.
- **Iron rules (命门) — every run command must enforce:**
  1. Heterogeneity: prompt the user to pick ≥1 non-Claude agent (warn if all-Claude, but allow).
  2. Subagents are **carriers only**: they faithfully excerpt one agent's conclusion; they never judge, merge, or add their own opinion.
  3. Blind review: each agent runs in its own process, mutually invisible, dispatched in parallel.
  4. OpenCode can hang on input → force `timeout`.
  5. Human-in-the-loop: the skill only ever advises; it never auto-edits code, merges, or approves.

---

## File Map

All paths under `~/.claude/skills/` unless noted. "Responsibility" notes are from the spec's decomposition.

| File | Responsibility | Created in |
|---|---|---|
| `xcheck/agents.toml` | agent → non-interactive command mapping (extensible) | Task 2 |
| `xcheck/lib/detect.sh` | list which registered CLIs are on PATH | Task 2 |
| `xcheck/lib/subagent-carrier.md` | the "carrier-only" instruction template each subagent gets | Task 4 |
| `xcheck/lib/flow.md` | the shared 5-step orchestration procedure (mode = diag\|review) | Task 4 |
| `xcheck/prompts/diag.md` | diag prompt fed to every external agent | Task 4 |
| `xcheck/prompts/synthesize-diag.md` | main-session diag synthesis instruction | Task 4 |
| `xcheck/prompts/review.md` | review prompt fed to every external agent | Task 5 |
| `xcheck/prompts/synthesize-review.md` | main-session review synthesis instruction | Task 5 |
| `xcheck-diag/SKILL.md` | `/xcheck-diag` entry (thin shell → flow.md, diag mode) | Task 4 |
| `xcheck-review/SKILL.md` | `/xcheck-review` entry (thin shell → flow.md, review mode) | Task 5 |
| `xcheck-setup/SKILL.md` | `/xcheck-setup` entry (detect + verify + register) | Task 3 |
| `xcheck/SKILL.md` | `/xcheck` auto-router entry | Task 6 |

---

## Task 1: Lock down each CLI's non-interactive invocation

**Goal:** Empirically confirm the exact non-interactive command + input feeding (arg vs stdin) for `claude`, `codex`, `opencode`. This de-risks every later task and finalizes `input_mode` values used in `agents.toml` (Task 2).

**Files:** None created. Findings are recorded in this plan's notes (and fed into Task 2).

**Produces:** Confirmed `run_cmd` + `input_mode` per CLI:
- Expected: `claude` → arg (`claude -p "<prompt>"`)
- Expected: `codex` → stdin (`codex exec -` reading stdin)
- Expected: `opencode` → arg (`opencode run "<prompt>"`); also test `--format json` and decide whether to keep it.

- [ ] **Step 1: Smoke-test `claude` (arg mode)**

Run:
```bash
timeout 90 claude -p "Reply with exactly this sentence and nothing else: hello-from-claude"
```
Expected: output contains `hello-from-claude`. Record: claude arg mode works (Y/N), observed output.

- [ ] **Step 2: Smoke-test `codex` (stdin mode)**

Run:
```bash
echo "Reply with exactly this sentence and nothing else: hello-from-codex" | timeout 90 codex exec -
```
Expected: output contains `hello-from-codex`. Record: codex stdin mode works (Y/N).

- [ ] **Step 3: Smoke-test `opencode` (arg, default format)**

Run:
```bash
timeout 90 opencode run "Reply with exactly this sentence and nothing else: hello-from-opencode"
```
Expected: output contains `hello-from-opencode`. Record: opencode arg mode works (Y/N). Note whether it returned cleanly within timeout (the known hang risk).

- [ ] **Step 4: Smoke-test `opencode` (`--format json`)**

Run:
```bash
timeout 90 opencode run --format json "Reply with exactly this sentence and nothing else: hello-from-opencode"
```
Expected: JSON event stream containing the reply text. Decide: is the JSON output usable by a Claude subagent (which can read JSON and extract the final assistant message)? Record decision: **keep `--format json`** (more robust) or **drop it, use default formatted text** (simpler for a Claude reader). If json is unusable/empty/hangs, choose default text.

- [ ] **Step 5: Verify a multi-line prompt feeds correctly (the escaping stress test)**

Create a temp file with quotes/special chars and feed it via the chosen mode for each CLI:
```bash
cat > /tmp/xcheck-smoke.txt <<'EOF'
A prompt with "double quotes", 'single quotes', $variables, and
multiple lines.
Reply with exactly: ok-multi-line.
EOF
# codex (stdin):
timeout 90 codex exec - < /tmp/xcheck-smoke.txt
# claude (arg):
timeout 90 claude -p "$(cat /tmp/xcheck-smoke.txt)"
# opencode (arg):
timeout 90 opencode run "$(cat /tmp/xcheck-smoke.txt)"
```
Expected: each returns `ok-multi-line`. This confirms feeding from a temp file works (the mechanism the subagent carrier uses). Record final `input_mode` per CLI.

- [ ] **Step 6: Checkpoint**

Record confirmed values (e.g. in a scratch note). These feed Task 2's `agents.toml`. No git (not a repo). If any CLI fails here, stop and resolve before proceeding — the whole skill depends on these calls working.

---

## Task 2: Create `agents.toml` + `lib/detect.sh`

**Goal:** The config table and the detection script — shared infrastructure for all four commands.

**Files:**
- Create: `~/.claude/skills/xcheck/agents.toml`
- Create: `~/.claude/skills/xcheck/lib/detect.sh`

**Consumes:** Task 1's confirmed `run_cmd` + `input_mode` per CLI.

**Produces:**
- `agents.toml` schema: `[agents.<name>]` blocks with `installed_check`, `run_cmd`, `input_mode`, `needs_timeout`, optional `timeout_sec`, optional `format_json`.
- `detect.sh` prints installed agents to stdout (`<name>\t<check>\tinstalled`), missing to stderr.

- [ ] **Step 1: Create `agents.toml`**

Write `~/.claude/skills/xcheck/agents.toml`:

```toml
# xcheck agent registry — how to call each local AI agent CLI non-interactively.
# To add a new agent you installed: add a [agents.<name>] block and run /xcheck-setup.

[agents.claude]
installed_check = "claude"
run_cmd         = "claude -p"
input_mode      = "arg"            # prompt passed as one quoted arg
needs_timeout   = false

[agents.codex]
installed_check = "codex"
run_cmd         = "codex exec -"   # reads prompt from stdin
input_mode      = "stdin"
needs_timeout   = false

[agents.opencode]
installed_check = "opencode"
run_cmd         = "opencode run"   # NOTE: if Task 1 chose --format json, append it here
input_mode      = "arg"
needs_timeout   = true             # known to hang on input occasionally -> force timeout
timeout_sec     = 480
```

(Adjust the `opencode` `run_cmd` to include `--format json` only if Task 1 Step 4 decided to keep it.)

- [ ] **Step 2: Create `lib/detect.sh`**

Write `~/.claude/skills/xcheck/lib/detect.sh`:

```bash
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
```

- [ ] **Step 3: Make it executable and run it**

Run:
```bash
chmod +x ~/.claude/skills/xcheck/lib/detect.sh
bash ~/.claude/skills/xcheck/lib/detect.sh
```
Expected (on this machine, all three installed): three stdout lines:
```
claude<tab>claude<tab>installed
codex<tab>codex<tab>installed
opencode<tab>opencode<tab>installed
```
(stderr empty.)

- [ ] **Step 4: Verify the "missing" path (optional but quick)**

Temporarily add a fake agent to confirm missing detection, then remove it:
```bash
# append a fake block
printf '\n[agents.fake]\ninstalled_check = "definitely-not-a-real-cli-xyz"\nrun_cmd = "fake"\ninput_mode = "arg"\n' >> ~/.claude/skills/xcheck/agents.toml
bash ~/.claude/skills/xcheck/lib/detect.sh
# expect a stderr line: definitely-not-a-real-cli-xyz ... missing
# then remove the fake block (edit the file back to the Step 1 content)
```
Expected: the fake agent appears on stderr as `missing`. Restore `agents.toml` to the Step 1 content afterward.

- [ ] **Step 5: Checkpoint**

detect.sh works and lists the three installed agents. Proceed.

---

## Task 3: Create the `/xcheck-setup` skill

**Goal:** A standalone command that (a) detects installed CLIs, (b) runs a tiny "say hello" test against each to confirm the non-interactive command actually works, and (c) can register a new agent. This is the verification/register home referenced by the run commands.

**Files:**
- Create: `~/.claude/skills/xcheck-setup/SKILL.md`

**Consumes:** `~/.claude/skills/xcheck/lib/detect.sh`, `~/.claude/skills/xcheck/agents.toml` (from Task 2).

**Produces:** `/xcheck-setup` invocable as a slash command.

- [ ] **Step 1: Create `xcheck-setup/SKILL.md`**

Write `~/.claude/skills/xcheck-setup/SKILL.md`:

```markdown
---
name: xcheck-setup
description: 检测本地已装的 AI agent CLI、逐个验证非交互命令能跑通、登记新 agent。手动调用 /xcheck-setup。
disable-model-invocation: true
argument-hint: [add <name>]
---

# /xcheck-setup — 检测 / 验证 / 登记 xcheck 的 agent

args = "$ARGUMENTS"。分两种模式:

## 模式 A:无参数 → 检测 + 验证(默认)

1. 跑检测:`bash ~/.claude/skills/xcheck/lib/detect.sh`
   - stdout 里的 agent = 已安装。stderr 里的 = 已登记但没装。
2. 对每个**已安装**的 agent,读 `~/.claude/skills/xcheck/agents.toml` 拿到它的 `run_cmd` / `input_mode` / `needs_timeout` / `timeout_sec`(默认 480)。
3. 逐个**验证**:给该 agent 喂一句极小 prompt(用 Bash 调它的非交互命令):
   - 写一个临时文件 `/tmp/xcheck-verify-<agent>.txt`,内容:`Reply with exactly: hello-from-<agent>`
   - stdin 模式:`timeout <sec> bash -c '<run_cmd> < /tmp/xcheck-verify-<agent>.txt'`
   - arg 模式:`timeout <sec> <run_cmd> "$(cat /tmp/xcheck-verify-<agent>.txt)"`
   - 每个独立跑,互不影响。
4. 汇报每个 agent 的结果:✅ 能跑通(贴一句它的输出)/ ⏱️ 超时 / ❌ 命令错(贴 stderr 摘要)/ 🔑 可能未登录。
5. 给一句总结:哪些可用、哪些要修。提醒:要让 xcheck 有意义,至少需要 1 个非 claude(codex / opencode)可用。

## 模式 B:`add <name>` → 登记新 agent

用户要登记一个 SKILL.md 表里没有的新 CLI(例如 gemini-cli):
1. 先确认它装了:`command -v <name>`。
2. 跑 `<name> --help` **核实**它的非交互命令长啥样(别凭记忆)。
3. 引导用户提供:`installed_check`、`run_cmd`、`input_mode`(arg/stdin)、是否需要 timeout。
4. 把新 `[agents.<name>]` 块追加写进 `~/.claude/skills/xcheck/agents.toml`。
5. 立刻按模式 A 验证这个新 agent 能跑通。
```

- [ ] **Step 2: Restart Claude Code (or `/reload`) so the new skill registers**

Newly added skills are picked up at session start. Restart Claude Code (or run `/reload` if the version supports it) so `/xcheck-setup` appears.

- [ ] **Step 3: Verify — invoke `/xcheck-setup`**

In Claude Code, type:
```
/xcheck-setup
```
Expected behavior: it runs `detect.sh`, then for each of claude/codex/opencode runs the hello-verify, and reports a per-agent ✅/⏱️/❌/🔑 line plus a summary. All three should be ✅ on this machine (Task 1 already confirmed they work).

- [ ] **Step 4: Checkpoint**

`/xcheck-setup` works end-to-end. Proceed.

---

## Task 4: Create the `/xcheck-diag` skill (full: parallel subagents + multiselect + timeout)

**Goal:** The first run command. Builds the shared orchestration (`flow.md`), the diag prompt + synthesis, the subagent carrier instruction, and the `/xcheck-diag` entry. Verified by a real 2-agent parallel diagnosis.

**Files:**
- Create: `~/.claude/skills/xcheck/lib/subagent-carrier.md`
- Create: `~/.claude/skills/xcheck/lib/flow.md`
- Create: `~/.claude/skills/xcheck/prompts/diag.md`
- Create: `~/.claude/skills/xcheck/prompts/synthesize-diag.md`
- Create: `~/.claude/skills/xcheck-diag/SKILL.md`

**Consumes:** `agents.toml`, `lib/detect.sh` (Task 2). `$ARGUMENTS` = the user's technical question.

**Produces:**
- `lib/flow.md` — the shared 5-step procedure (also used by `/xcheck-review` in Task 5 and `/xcheck` in Task 6).
- `lib/subagent-carrier.md` — the carrier instruction template (reused by all run commands).
- `/xcheck-diag` invocable.

- [ ] **Step 1: Create `lib/subagent-carrier.md`**

Write `~/.claude/skills/xcheck/lib/subagent-carrier.md`:

```markdown
# subagent 搬运工指令(主会话每派一个外部 agent 就套用一次)

你是**搬运工,不是评审员**。你的任务:把**一个**外部 AI agent 的结论忠实带回。**严禁**掺入你自己的判断、合并观点、补充意见、或和别的 agent 比较。综合判断由主会话做,不是你。

主会话会填入以下参数:
- AGENT_NAME = <agent 名>
- CLI_CMD = <该 agent 的 run_cmd,来自 agents.toml>
- INPUT_MODE = <arg | stdin>
- PROMPT_FILE = <prompt 文件的绝对路径>
- TIMEOUT = <秒;来自 agents.toml 的 timeout_sec,默认 480>
- RESULT_SHAPE = <见下,由 mode 决定>

执行步骤:
1. 按 INPUT_MODE 跑 CLI_CMD,把 PROMPT_FILE 的内容喂进去:
   - stdin:`timeout <TIMEOUT> bash -lc '<CLI_CMD> < "<PROMPT_FILE>"'`
   - arg:`timeout <TIMEOUT> bash -lc '<CLI_CMD> "$(cat "<PROMPT_FILE>")"'`
2. 等它完成。
   - 超时(timeout 非零退出):只返回字符串:`<AGENT_NAME> 超时未返回(TIMEOUT 秒)`。
   - 其它非零退出:只返回:`<AGENT_NAME> 失败:<stderr 末尾几行摘要>`。
3. 成功则读 CLI 的**全部 stdout**(opencode 若是 JSON 事件流,提取最终 assistant 消息文本)。
4. 把该 agent 的核心结论**原样摘录**,格式化成 RESULT_SHAPE:
   - diag 模式 → 根因 / 证据(代码·日志·推理)/ 置信度(高·中·低)/ 建议的验证或修复方向
   - review 模式 → 裁决(AGREE | SUGGEST_CHANGES | DISAGREE)/ 逐条问题(带位置+严重度)/ 理由
5. 在你的最终回复里给两段:
   - `## <AGENT_NAME> 原始输出` — CLI stdout 全文(opencode json 则附最终消息文本)
   - `## <AGENT_NAME> 结构化结论` — 上面格式化后的 RESULT_SHAPE
6. 再次:只返回**这一个 agent** 的内容。不评判、不合并、不补刀。
```

- [ ] **Step 2: Create `prompts/diag.md`**

Write `~/.claude/skills/xcheck/prompts/diag.md`:

```markdown
你是独立诊断专家。下面是一个技术问题,请**独立**定位根因,不要假设别人会帮你或和你讨论。

【问题】
{{USER_INPUT}}

【上下文 / 复现】
{{CONTEXT}}   # 没有就留空

请给出:
1. 最可能的根因
2. 支撑证据(代码 / 日志 / 推理)
3. 置信度(高 / 中 / 低)
4. 建议的验证或修复方向

要求:直接给结论,简洁。不要寒暄。
```

(`{{USER_INPUT}}` / `{{CONTEXT}}` are slots the main session fills before writing the prompt file.)

- [ ] **Step 3: Create `prompts/synthesize-diag.md`**

Write `~/.claude/skills/xcheck/prompts/synthesize-diag.md`:

```markdown
你是综合判断者。下面是 N 个**不同** AI agent 对同一个问题各自独立给出的诊断。它们互不可见(盲评)。

【各家结论】
{{ALL_CONCLUSIONS}}

请输出:
1. **共识根因** —— 多家都指向的(强信号),列出是哪几家一致
2. **分歧** —— 谁和谁不一样,各自的主张
3. **存疑** —— 只有一家说的(弱信号,可能对可能错)
4. **综合判断建议** —— 你倾向哪个根因、为什么、建议下一步怎么验证

重要提醒:**共识不等于正确** —— 多家都点头不代表对,它们可能一起错。保留分歧,最终由**用户拍板**。不要替用户做"通过/不通过"的决定。
```

- [ ] **Step 4: Create `lib/flow.md`**

Write `~/.claude/skills/xcheck/lib/flow.md`:

```markdown
# xcheck 共用执行流程(mode = diag | review)

主会话(你)按这 5 步执行。`$ARGUMENTS` 是用户输入的内容。mode 由调用你的入口 skill 指定(diag / review)。

## 第 1 步:自动检测可用 agent
跑:`bash ~/.claude/skills/xcheck/lib/detect.sh`
- stdout = 已安装可选的 agent(name \t check \t installed)。
- 若已装 < 2 个:告诉用户装的太少(异构至少要 2 个、且至少 1 个非 claude),建议先 `/xcheck-setup` 核实,然后停,不继续。

## 第 2 步:让用户多选(AskUserQuestion,multiSelect: true)
把已装的 agent 列成选项让用户挑。问题里**必须**包含这句提醒:
"⚠️ 至少选一个非 claude(如 codex / opencode),否则全是 Claude 同构,等于自己审自己。"
- 若用户选的全是 claude 系:再用 AskUserQuestion 确认一次"确定只要 claude 同构吗?(不推荐)",仍坚持就继续但在最终汇总里标注"本次为同构,异构价值未体现"。
- 记 SELECTED = 选中的 agent 名列表。

## 第 3 步:准备 prompt + 并行派 subagent
1. 套 prompt 模板:
   - mode=diag → 读 `~/.claude/skills/xcheck/prompts/diag.md`,把 `{{USER_INPUT}}` 替换成 `$ARGUMENTS`,`{{CONTEXT}}` 替换成用户额外给的上下文(没有则删掉该行)。
   - mode=review → 读 `prompts/review.md`,把 `{{PROPOSAL}}` 替换成 `$ARGUMENTS`(若是文件路径,先 Read 出全文再填)。
2. 生成时间戳目录 `.xcheck/<YYYYMMDD-HHMMSS>/`(当前 cwd)。把最终 prompt 写到 `.xcheck/<ts>/prompt.txt`(用绝对路径)。
3. 读 `agents.toml`,拿到 SELECTED 里每个 agent 的 run_cmd / input_mode / needs_timeout / timeout_sec。
4. **一条消息里并发**开 |SELECTED| 个 Agent 工具(subagent)。每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的内容,填入该 agent 的参数(AGENT_NAME / CLI_CMD / INPUT_MODE / PROMPT_FILE / TIMEOUT / RESULT_SHAPE)。**subagent 模型用便宜档(haiku 或 sonnet)。**
   - RESULT_SHAPE:diag 模式告诉 subagent 按 diag 结构;review 模式按 review 结构。
   - 并发参考 superpowers `dispatching-parallel-agents`。

## 第 4 步:收齐
等所有 subagent 完成。每个返回两段(原始输出 + 结构化结论),或"超时/失败"。
把每个 agent 的内容落盘:
- `.xcheck/<ts>/<agent>.raw.out` — 原始 CLI 输出
- `.xcheck/<ts>/<agent>.summary.md` — 结构化结论
失败的 agent 也记一份 `.xcheck/<ts>/<agent>.failed.md`。

## 第 5 步:主会话汇总(你做综合判断)
把所有 subagent 带回的结构化结论拼起来,套进汇总指令:
- mode=diag → `~/.claude/skills/xcheck/prompts/synthesize-diag.md`
- mode=review → `prompts/synthesize-review.md`
输出:共识 / 分歧 / 存疑(或各家裁决)/ 综合建议。写到 `.xcheck/<ts>/SUMMARY.md`。
呈现给用户,并明确收尾:"**以上是建议,共识 ≠ 正确,最终你拍板。**" 绝不自动改代码 / 合并 / 通过。
```

- [ ] **Step 5: Create `xcheck-diag/SKILL.md`**

Write `~/.claude/skills/xcheck-diag/SKILL.md`:

```markdown
---
name: xcheck-diag
description: 并行诊断 —— 把一个技术问题(报错/异常/失败/为什么不工作)并行喂给本地多个异构 AI agent CLI,各家独立定位根因,主会话汇总共识/分歧/存疑。手动调用 /xcheck-diag。
disable-model-invocation: true
argument-hint: <技术问题>
---

# /xcheck-diag — 并行诊断

`$ARGUMENTS` 是用户要诊断的技术问题。执行:

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中 5 步执行**,本次 **mode = diag**。
2. 诊断外部 prompt:`~/.claude/skills/xcheck/prompts/diag.md`。
3. 主会话汇总:`~/.claude/skills/xcheck/prompts/synthesize-diag.md`。

铁律(见 flow.md 与 agents.toml):subagent 只搬运不评判;至少选一个非 claude;opencode 加 timeout;结果落盘 `.xcheck/<时间戳>/`;最后交用户拍板,不自动改代码。
```

- [ ] **Step 6: Restart Claude Code so `/xcheck-diag` registers**

- [ ] **Step 7: Verify — run a real 2-agent parallel diagnosis**

Pick a small, real technical problem (e.g. a past error or a tiny known bug). In Claude Code:
```
/xcheck-diag <a short real error description>
```
Expected behavior:
1. It runs `detect.sh`, lists installed agents.
2. AskUserQuestion multi-select appears with the heterogeneity reminder. Select **codex + opencode** (two non-Claude agents — proves parallel + heterogeneity).
3. Two subagents dispatch in parallel (one `codex exec`, one `opencode run`), each returns that agent's structured root-cause + raw output.
4. Main session synthesizes consensus/divergence/uncertain + writes `.xcheck/<ts>/SUMMARY.md`.
5. Ends with the human-decides disclaimer. No code is auto-edited.
Verify the files landed under `.xcheck/<ts>/` (prompt.txt, codex.*, opencode.*, SUMMARY.md).

- [ ] **Step 8: Verify timeout tolerance (opencode)**

Re-run with opencode selected. If opencode happens to be slow/hang, confirm the skill reports "opencode 超时未返回" and continues to synthesize the others rather than hanging. (If opencode returns fine, this is a no-op confirmation.)

- [ ] **Step 9: Checkpoint**

`/xcheck-diag` works end-to-end with parallel subagents, multiselect, heterogeneity reminder, and timeout tolerance. Proceed.

---

## Task 5: Create the `/xcheck-review` skill

**Goal:** The cross-review command. Reuses `flow.md` + `subagent-carrier.md` from Task 4; adds the review prompt + review synthesis + the `/xcheck-review` entry.

**Files:**
- Create: `~/.claude/skills/xcheck/prompts/review.md`
- Create: `~/.claude/skills/xcheck/prompts/synthesize-review.md`
- Create: `~/.claude/skills/xcheck-review/SKILL.md`

**Consumes:** `lib/flow.md`, `lib/subagent-carrier.md`, `agents.toml`, `lib/detect.sh` (from Tasks 2 & 4). `$ARGUMENTS` = the proposal (text or file path).

**Produces:** `/xcheck-review` invocable.

- [ ] **Step 1: Create `prompts/review.md`**

Write `~/.claude/skills/xcheck/prompts/review.md`:

```markdown
你是独立评审员。下面是一个方案,请**独立**评审,不要假设别人会帮你看或和你讨论。

【方案】
{{PROPOSAL}}

请严格按以下结构返回:
- **裁决**:AGREE / SUGGEST_CHANGES / DISAGREE(三选一,只选一个)
- **问题清单**(逐条,每条带:位置 / 严重度 高·中·低 / 是 bug·风险·还是遗漏)
- **理由**:为什么是这个裁决

要求:直接给结论,简洁。不要寒暄。没有问题的部分不用夸。
```

- [ ] **Step 2: Create `prompts/synthesize-review.md`**

Write `~/.claude/skills/xcheck/prompts/synthesize-review.md`:

```markdown
你是综合判断者。下面是 N 个**不同** AI agent 对同一个方案各自独立给出的评审。它们互不可见(盲评)。

【各家评审】
{{ALL_REVIEWS}}

请输出:
1. **各家裁决一览** —— 谁 AGREE / SUGGEST_CHANGES / DISAGREE
2. **共识问题** —— 多家都指出的(优先修),列出是哪几家
3. **单家提出的问题** —— 只有一家说的(存疑,可能对可能错)
4. **综合裁决建议** —— 你建议 AGREE / SUGGEST_CHANGES / DISAGREE,及最该先改的几条

重要提醒:**共识不等于正确** —— 多家都点头不代表对。保留分歧,最终由**用户拍板**。不要替用户做"通过/合并"的决定。
```

- [ ] **Step 3: Create `xcheck-review/SKILL.md`**

Write `~/.claude/skills/xcheck-review/SKILL.md`:

```markdown
---
name: xcheck-review
description: 交叉评审 —— 把一个方案/设计/code change(文本或文件路径)喂给本地多个异构 AI agent CLI 各自评审,主会话汇总各家裁决/共识问题/综合建议。手动调用 /xcheck-review。
disable-model-invocation: true
argument-hint: <方案 文本或文件路径>
---

# /xcheck-review — 交叉评审

`$ARGUMENTS` 是用户要评审的方案(文本,或文件路径)。执行:

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中 5 步执行**,本次 **mode = review**。
2. 若 `$ARGUMENTS` 是文件路径,先用 Read 读出全文作为方案内容。
3. 评审外部 prompt:`~/.claude/skills/xcheck/prompts/review.md`。
4. 主会话汇总:`~/.claude/skills/xcheck/prompts/synthesize-review.md`。

铁律同 /xcheck-diag:subagent 只搬运不评判;至少选一个非 claude;opencode 加 timeout;结果落盘;最后交用户拍板,不自动通过/合并。
```

- [ ] **Step 4: Restart Claude Code so `/xcheck-review` registers**

- [ ] **Step 5: Verify — run a real cross-review**

In Claude Code, prepare a tiny ~5-line proposal (e.g. a small function with a subtle bug), then:
```
/xcheck-review <the 5-line proposal>
```
Expected: detect → multiselect (pick codex + opencode) → parallel subagents each return AGREE/SUGGEST_CHANGES/DISAGREE + issue list → main session synthesizes per-agent verdicts + consensus issues + recommendation → writes SUMMARY.md → ends with human-decides disclaimer.

- [ ] **Step 6: Checkpoint**

`/xcheck-review` works end-to-end. Proceed.

---

## Task 6: Create the `/xcheck` auto-router

**Goal:** A single entry that reads the user's vague description and routes to diag or review by keyword; asks if it can't tell.

**Files:**
- Create: `~/.claude/skills/xcheck/SKILL.md`

**Consumes:** the diag/review flows (Tasks 4 & 5).

**Produces:** `/xcheck` invocable.

- [ ] **Step 1: Create `xcheck/SKILL.md`**

Write `~/.claude/skills/xcheck/SKILL.md`:

```markdown
---
name: xcheck
description: 自动判断 —— 把一段模糊描述路由到并行诊断(/xcheck-diag)或交叉评审(/xcheck-review);判断不了就反问。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: <问题描述或方案>
---

# /xcheck — 自动路由

`$ARGUMENTS` 是用户给的一段描述。你**先判断**它更像"技术问题"还是"方案评审":

**命中诊断关键词**(报错 / 失败 / 为什么不 / 不工作 / 定位 / bug / 异常 / crash / error / stack / 根因)→ 走 **diag**:按 `~/.claude/skills/xcheck/lib/flow.md` 的 5 步执行,mode = diag,用 `prompts/diag.md` + `prompts/synthesize-diag.md`。

**命中评审关键词**(方案 / 评审 / 设计 / 行不行 / 评估 / review / 这样写对吗 / 改进 / PR)→ 走 **review**:按 flow.md 5 步执行,mode = review,用 `prompts/review.md` + `prompts/synthesize-review.md`。

**判断不了** → 用 AskUserQuestion 反问用户:"你这是要【诊断一个问题】还是【评审一个方案】?"(两选项 + 让用户补充)。**不要瞎猜。** 用户选完再走对应流程。

其余铁律同 diag/review:subagent 只搬运不评判、至少一个非 claude、opencode timeout、落盘、人拍板。
```

- [ ] **Step 2: Restart Claude Code so `/xcheck` registers**

- [ ] **Step 3: Verify — diag routing**

```
/xcheck 运行 npm install 一直报 ERESOLVE 错,定位一下
```
Expected: routes to diag (keyword "报…错" / "定位"), runs the diag flow.

- [ ] **Step 4: Verify — review routing**

```
/xcheck 评审一下这个方案:用 localStorage 存登录态,每次请求带在 header 里
```
Expected: routes to review (keyword "评审" / "方案"), runs the review flow.

- [ ] **Step 5: Verify — ambiguous → asks**

```
/xcheck 这个 React 组件
```
Expected: AskUserQuestion asks diag-or-review; does not guess.

- [ ] **Step 6: Checkpoint**

`/xcheck` routes correctly and asks when ambiguous. Proceed.

---

## Task 7: End-to-end acceptance against the spec's §10 checklist

**Goal:** Confirm every acceptance criterion from the approved design is met with real examples.

**Files:** None (verification only; uses `.xcheck/<ts>/` artifacts as evidence).

- [ ] **Step 1: Verify `/xcheck-setup`**

Run `/xcheck-setup`. Confirm: detects 3 CLIs, each shows ✅ (or an honest ⏱️/❌), and the `add` path is documented. ✔ criterion 1.

- [ ] **Step 2: Verify `/xcheck-diag`**

Run `/xcheck-diag` on a real small bug. Confirm: detect → multiselect → parallel → "共识/分歧/存疑" synthesis. ✔ criterion 2.

- [ ] **Step 3: Verify `/xcheck-review`**

Run `/xcheck-review` on a 5-line proposal. Confirm: per-agent verdicts + "共识问题/综合建议". ✔ criterion 3.

- [ ] **Step 4: Verify `/xcheck` routing**

Run the three cases from Task 6 Steps 3–5. ✔ criterion 4.

- [ ] **Step 5: Verify heterogeneity reminder**

During any run's multiselect, confirm the "至少选一个非 claude" reminder is present; and that an all-Claude selection triggers the confirmation + "同构" warning in the summary. ✔ criterion 5.

- [ ] **Step 6: Verify subagent isolation (context protection)**

During a 3-agent run, confirm the main session only ingests each subagent's condensed return — the raw CLI outputs go to `.xcheck/<ts>/*.raw.out`, not dumped into the main context. ✔ criterion 6.

- [ ] **Step 7: Verify "carrier-only" fidelity**

Inspect a subagent's return for a run: confirm it is that agent's conclusion (root-cause / verdict), not Claude's own synthesis or a merge of multiple agents. ✔ criterion 7.

- [ ] **Step 8: Verify opencode timeout tolerance**

Confirm a slow/hanging opencode yields "超时未返回" and the run continues. ✔ criterion 8.

- [ ] **Step 9: Verify human-in-the-loop + artifacts**

Confirm every run ends with the "you decide" disclaimer, writes `.xcheck/<ts>/SUMMARY.md`, and never auto-edits code / merges / approves. ✔ criterion 9.

- [ ] **Step 10: Final checkpoint — update memory**

Write a project memory noting the skill is built and lives at `~/.claude/skills/xcheck*/`, with the one-line usage. Update `MEMORY.md`. Done.

---

## Self-Review (run after writing — fixes applied inline)

1. **Spec coverage:** Every §10 acceptance criterion maps to Task 7 steps. §3 four-command structure → Tasks 3,4,5,6. §5 5-step flow → Task 4 flow.md. §6 subagent model → Task 4 carrier + flow. §7 technical spec (agents.toml/detect/timeout/output/prompts) → Tasks 2 & 4. §8 命门 → Global Constraints + embedded in each SKILL.md. §9 dev order → task order. ✔ No spec requirement lacks a task.
2. **Placeholder scan:** No TBD/TODO/"add error handling"/"similar to Task N". Every file's full content is inlined. The two parameterized templates (`{{USER_INPUT}}` etc., and the carrier's `<AGENT_NAME>` slots) are explicitly named slot-fill conventions, not placeholders. ✔
3. **Type/name consistency:** `agents.toml` keys (`run_cmd`, `input_mode`, `needs_timeout`, `timeout_sec`) are referenced identically in detect.sh, flow.md, subagent-carrier.md, and xcheck-setup. `RESULT_SHAPE` (diag|review) is consistent across carrier and flow. Prompt slot names (`{{USER_INPUT}}`, `{{CONTEXT}}`, `{{PROPOSAL}}`, `{{ALL_CONCLUSIONS}}`, `{{ALL_REVIEWS}}`) are used consistently. `.xcheck/<ts>/` artifact naming is consistent. ✔
4. **Adaptation note (not a gap):** TDD/commit framing is adapted to behavioral verification + checkpoints because this is a skill/prose project with no code unit tests and no git repo; stated explicitly in Global Constraints. `input_mode` final values are confirmed empirically in Task 1 (expected values written into Task 2, adjustable per Task 1 findings).
