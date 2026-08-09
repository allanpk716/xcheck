# xcheck

**Cross-check your technical questions & designs against multiple local AI agents — in parallel, blind, and you decide.**

**把你的技术问题或方案，并行喂给本地多个异构 AI agent，盲评交叉验证，最后你来拍板。**

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

xcheck is a set of global [Claude Code](https://code.claude.com/) skills. You hand it a bug / error / "why doesn't this work", or a design / proposal / code change, and it:

1. **Detects** which local AI-agent CLIs you have installed (`claude`, `codex`, `opencode`, …) and lets you pick a few.
2. **Fans them out in parallel**, each in its own isolated Claude subagent, so every agent reasons independently and can't see the others — **blind evaluation**.
3. **Collects only** — subagents are forbidden from judging or merging opinions; they faithfully condense each agent's raw output.
4. **Synthesizes** in the main session: what the agents **agree** on (strong signal), where they **diverge**, what only one claims (suspect).
5. **Hands it to you** — consensus ≠ correctness. It never auto-fixes, auto-merges, or "approves". You make the call.

The whole point is **heterogeneity**: if every "second opinion" comes from the same Claude you're already talking to, you learn nothing. xcheck insists on at least one non-`claude` agent (e.g. `codex`, `opencode`) so the opinions are genuinely independent.

## Commands

All four are **manual slash commands** (`disable-model-invocation: true`) — they never fire on their own.

| Command | What it does |
|---|---|
| `/xcheck <text>` | **Auto-routes** — reads your text, classifies it as a *problem* or a *proposal*, and dispatches to diag or review. Asks if it can't tell. |
| `/xcheck-diag <problem>` | **Parallel diagnosis** — feed an error / exception / "why is this broken"; get each agent's root cause + a consensus root cause. |
| `/xcheck-review <proposal>` | **Cross review** — feed a design / change / file path; get each agent's `AGREE` / `SUGGEST_CHANGES` / `DISAGREE` + a combined verdict suggestion. |
| `/xcheck-setup` | **Detect / verify / register** — lists installed CLIs, "says hello" to each to confirm the non-interactive command actually runs, and registers new agents into `agents.toml`. |

## How it works

```
you: /xcheck-diag "my login state via localStorage gets wiped on refresh"
        │
  [1] detect   ── lib/detect.sh (`which`) reads agents.toml → list installed agents
        │
  [2] you pick ── AskUserQuestion (reminds you: pick ≥1 non-claude)
        │
  [3] fan out  ── one Claude subagent per agent, in parallel (cheap model: haiku/sonnet)
        │              subagent: Bash → claude -p / codex exec - / opencode run
        │              reads output → faithfully condenses (NEVER judges)
        │
  [4] collect  ── wait for all; mark timeouts/failures; raw output + summary → .xcheck/<ts>/
        │
  [5] synthesize (main session, strong model) → consensus / divergence / verdict → YOU decide
```

**Two iron rules** (break them and the skill is worthless):

1. **Subagents only carry, never judge.** A subagent is also Claude — if it editorializes, the heterogeneous opinions get homogenized and you lose the independent second opinion you came for. Synthesis happens only in the main session.
2. **Always ≥1 non-`claude` agent.** Otherwise Claude is reviewing itself.

## Requirements

- **[Claude Code](https://code.claude.com/)** — xcheck is a set of Claude Code skills; the orchestration (subagents, `AskUserQuestion`) runs inside it.
- **One or more local AI-agent CLIs on your `PATH`.** Out of the box it knows:
  - [`claude`](https://docs.claude.com/en/docs/claude-code) — `claude -p`
  - [`codex`](https://github.com/openai/codex) — `codex exec -` (reads prompt from stdin)
  - [`opencode`](https://opencode.ai/) — `opencode run` (timeout-guarded)
  - Add more (gemini-cli, qwen, aider, …) via `/xcheck-setup add <name>`.
- For xcheck to be **meaningful**, at least one must be non-`claude`.
- A bash shell. Developed/tested on **Windows + Git Bash**; `detect.sh` is bash, so macOS/Linux should work too.

## Install

Copy the skill folders into your global skills directory:

```bash
# from the repo root
cp -r xcheck xcheck-diag xcheck-review xcheck-setup ~/.claude/skills/
```

Then in Claude Code, make sure each installed agent CLI is logged in, and run `/xcheck-setup` once to verify everything talks.

> The shared logic lives in `xcheck/lib/` and `xcheck/prompts/`; the other three folders are thin shells that reference it.

## File layout

```
xcheck/
├── SKILL.md                 # /xcheck  — auto-router entry
├── agents.toml              # agent → non-interactive command map (extensible)
├── lib/
│   ├── flow.md              # shared 5-step flow (the three run commands call this)
│   ├── detect.sh            # detection: `which` over agents.toml
│   └── subagent-carrier.md  # the "carry, don't judge" subagent instructions
└── prompts/
    ├── diag.md  review.md                 # fed to each external agent
    └── synthesize-diag.md  synthesize-review.md   # main-session synthesis
xcheck-diag/SKILL.md         # thin shell → flow.md + diag.md
xcheck-review/SKILL.md       # thin shell → flow.md + review.md
xcheck-setup/SKILL.md        # detect / verify / register
```

## Philosophy / guardrails

- **Blind evaluation** — each agent runs in its own process, in parallel, and never sees the others' output. Prevents groupthink.
- **Subagents never judge** — they only carry and condense.
- **Human in the loop** — output is always "suggestions"; it never edits code, merges, or approves for you.
- **Cheap carriers, strong synthesizer** — subagents use haiku/sonnet; the main session uses the strong model for synthesis.

## License

[MIT](LICENSE) © 2026 allanpk716

---

## 中文文档

`xcheck` 是一组全局 [Claude Code](https://code.claude.com/) skill。你给它一个 bug / 报错 / "为什么这个不工作"，或一个方案 / 设计 / 代码改动，它会：

1. **检测**你本机装了哪些 AI agent CLI（`claude`、`codex`、`opencode`……）让你多选几个。
2. **并行派发**，每个 agent 包在独立的 Claude subagent 里独立推理，彼此看不见——**盲评**。
3. **只搬运**——subagent 不许评判、不许合并观点，只忠实精简各家的原始输出。
4. **主会话汇总**：各家**共识**（强信号）、**分歧**、只一家说的（存疑）。
5. **交你拍板**——共识 ≠ 正确。绝不自动改代码 / 自动合并 / 自动"通过"。

核心是**异构**：如果每个"第二意见"都来自你正在聊的同一个 Claude，你什么也得不到。xcheck 强制至少选一个**非 claude** 的 agent（如 `codex`、`opencode`），让意见真正独立。

### 四个命令（都是手动 slash 命令，不会自动触发）

| 命令 | 作用 |
|---|---|
| `/xcheck <文字>` | **自动路由**——读你的文字，判成"问题"还是"方案"，转派 diag 或 review；判不了就反问。 |
| `/xcheck-diag <问题>` | **并行诊断**——喂一个报错/异常/"为什么不工作"；得各家根因 + 共识根因。 |
| `/xcheck-review <方案>` | **交叉评审**——喂一个设计/改动/文件路径；得各家 `AGREE` / `SUGGEST_CHANGES` / `DISAGREE` + 综合裁决建议。 |
| `/xcheck-setup` | **检测 / 验证 / 登记**——列出已装 CLI、逐个"说 hello"验证非交互命令能跑通、往 `agents.toml` 登记新 agent。 |

### 两条铁律（违反则 skill 价值归零）

1. **subagent 只搬运、不评判。** subagent 也是 Claude——它一掺意见就把异构意见同质化，你丢掉要的独立第二意见。综合判断只在主会话做。
2. **至少选一个非 claude。** 否则就是 Claude 自己审自己。

### 环境要求

- **[Claude Code](https://code.claude.com/)**——xcheck 是它的 skill，编排（subagent、`AskUserQuestion`）在它里面跑。
- **一个或多个本机 AI agent CLI（在 `PATH` 上）。** 开箱认识：`claude`（`claude -p`）、`codex`（`codex exec -` 走 stdin）、`opencode`（`opencode run`，强制 timeout）。想加别的（gemini-cli、qwen、aider……）用 `/xcheck-setup add <name>`。
- 要有意义，**至少一个非 claude**。
- bash 环境。在 **Windows + Git Bash** 上开发/测试；`detect.sh` 是 bash，macOS/Linux 理论可用。

### 安装

```bash
# 仓库根目录下
cp -r xcheck xcheck-diag xcheck-review xcheck-setup ~/.claude/skills/
```

进 Claude Code 后，确保每个 agent CLI 已登录，跑一次 `/xcheck-setup` 验证都能通。

### 命门

- **盲评**——各 agent 独立进程、并行、互不可见，防串通。
- **subagent 不评判**——只搬运精简。
- **人在环**——输出永远是"建议"，绝不替你改代码 / 合并 / 通过。
- **便宜搬运、强模型汇总**——subagent 用 haiku/sonnet，主会话汇总用强模型。

### 许可证

[MIT](LICENSE) © 2026 allanpk716
