# xcheck

**Cross-check your technical questions & designs against multiple local AI agents — in parallel, blind, and you decide.**

**把你的技术问题或方案，并行喂给本地多个异构 AI agent，盲评交叉验证，最后你来拍板。**

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

xcheck is a set of global [Claude Code](https://code.claude.com/) skills. You hand it a bug / error / "why doesn't this work", or a design / proposal / code change, and it:

0. **(Only if your input isn't self-contained)** solidifies context — for a reference-like input ("review the design we just discussed") it distills a **neutral, self-contained proposal** plus a **verbatim list of facts you stated**, and shows you both for approval **before anything is fanned out**. Self-contained inputs (full stack trace / design doc / file path) skip this, but still get a silent zero-roundtrip pass that pulls directly-related user quotes from the recent chat into a separate context file.
1. **Detects** which local AI-agent CLIs you have installed (`claude`, `codex`, `opencode`, `pi`, `kimi`, …), then **smoke-tests** each candidate (≤60s: read a file and echo it back) — dead CLIs and agents that can't read files non-interactively are dropped **before** fan-out, not after.
2. **Fans them out in parallel**, each in its own isolated Claude subagent, so every agent reasons independently and can't see the others — **blind evaluation**. Agents read the proposal / problem from **content files**; the prompt itself is a ≤2KB instruction layer (never blows the Windows 32K command-line limit, file inputs cost zero tokens in your session).
3. **Collects only** — subagents are forbidden from judging or merging opinions; they faithfully condense each agent's raw output. Everything lands on disk under `.xcheck/<ts>/` (raw output, per-agent summaries, synthesis) as a full audit trail.
4. **Synthesizes** in the main session: what the agents **agree** on (strong signal), where they **diverge**, what only one claims (suspect).
5. **Triages** every feedback item into three verifiability tiers: ① directly verifiable, ② verifiable by a designed experiment, ③ suspect / reference-only.
6. **Hands it to you** — consensus ≠ correctness. It never auto-fixes, auto-merges, or "approves". Optionally, `/xcheck-close` then closes the loop: verify ①, run approved ② experiments, distill a must-fix list, write the revision as a **new** file (original untouched), and re-review (≤2 rounds).

The whole point is **heterogeneity**: if every "second opinion" comes from the same Claude you're already talking to, you learn nothing. xcheck insists on at least one non-`claude` agent (e.g. `codex`, `opencode`, `kimi`) so the opinions are genuinely independent.

## Commands

All five are **manual slash commands** (`disable-model-invocation: true`) — they never fire on their own.

| Command | What it does |
|---|---|
| `/xcheck <text>` | **Auto-routes** — reads your text, classifies it as a *problem* or a *proposal*, and dispatches to diag or review. Asks if it can't tell. |
| `/xcheck-diag <problem>` | **Parallel diagnosis** — feed an error / exception / "why is this broken"; get each agent's root cause + a consensus root cause. |
| `/xcheck-review <proposal>` | **Cross review** — feed a design / change / file path; get each agent's `AGREE` / `SUGGEST_CHANGES` / `DISAGREE`, a combined verdict, and every feedback item triaged into the three verifiability tiers. |
| `/xcheck-close [--agents a,b,c] [<ts>]` | **Close the loop** on a finished review: verify tier-① items read-only, run tier-② experiments after one approval, distill a must-fix list, write the revision as a new `<name>.rev<m>.md` (original untouched), optional re-review — hard cap 2 revision rounds. Progress in `CLOSE.md`, resumable. |
| `/xcheck-setup` | **Detect / verify / configure** — lists installed CLIs, "says hello" to each, and registers new agents. Subcommands: `add <name>`, `timeout [N \| <agent> N]`, `default [<n1>,<n2>,… \| --clear]`. |

All run commands (`/xcheck`, `/xcheck-diag`, `/xcheck-review`, `/xcheck-close`) accept an optional `--agents a,b,c` flag — a one-shot override of the agent set (a typo'd name aborts immediately). Priority: `--agents` > `default_agents` > interactive multi-select. The factory default set is `["codex", "kimi", "pi"]`; view / change / clear it with `/xcheck-setup default`.

## How it works

```
you: /xcheck-review "docs/auth-design.md"      (or /xcheck-diag "why is this broken")
        │
  [0]  intake ── ONLY if input isn't self-contained: distill a neutral self-contained
        │       proposal + verbatim user-fact list → you approve BOTH before fan-out.
        │       Self-contained input skips this, but still gets a silent pass that
        │       pulls related user quotes from recent chat → context.md.
        │
  [1]  detect ── lib/detect.sh (`which`) reads agents.toml → installed agents
        │
  [1.5] smoke ── per candidate, ≤60s: read .xcheck/smoke.txt and echo it back.
        │         Dead CLI (401/未登录/损坏) or can't read files non-interactively
        │         → dropped before fan-out.
        │
  [2]  select ── --agents flag > default_agents (factory: codex,kimi,pi) >
        │       interactive multi-select (reminds you: pick ≥1 non-claude)
        │
  [3]  fan out ── one cheap Claude subagent per agent, in parallel. Each launches
        │         its CLI in the background with full disk redirection and polls
        │         (total budget timeout_sec, factory 2700s; hang detection included).
        │         Instruction layer: prompt.txt (≤2KB, paths only). Content layer:
        │         proposal.md / input.md / context.md — agents read files themselves.
        │
  [4]  collect ── wait for all; mark timeouts/failures; <agent>.raw.out +
        │         <agent>.summary.md → .xcheck/<ts>/ (+ run.md for /xcheck-close)
        │
  [5]  synthesize (main session, strong model) → consensus / divergence / verdict
        │         → SUMMARY.md → "共识 ≠ 正确,你拍板" — YOU decide
        │
  [6]  triage ── every feedback item → ① directly verifiable ② experiment-verifiable
        │         (designed, never auto-run) ③ suspect / reference-only → SUMMARY.md
        │
 (opt)  /xcheck-close → verify ① (✅/❌/❓ with evidence) · run approved ② experiments
        (sandbox: temp files under .xcheck/<ts>/exp/, no business-code edits / no
        network) · must-fix list · revision as a NEW file · re-review ≤2 rounds
```

**Two iron rules** (break them and the skill is worthless):

1. **Subagents only carry, never judge.** A subagent is also Claude — if it editorializes, the heterogeneous opinions get homogenized and you lose the independent second opinion you came for. Synthesis happens only in the main session.
2. **Always ≥1 non-`claude` agent.** Otherwise Claude is reviewing itself.

## Requirements

- **[Claude Code](https://code.claude.com/)** — xcheck is a set of Claude Code skills; the orchestration (subagents, `AskUserQuestion`) runs inside it.
- **One or more local AI-agent CLIs on your `PATH`.** Out of the box it knows:
  - [`claude`](https://docs.claude.com/en/docs/claude-code) — `claude -p`
  - [`codex`](https://github.com/openai/codex) — `codex exec --skip-git-repo-check -` (reads prompt from stdin; the flag keeps it usable outside git repos, where review targets often live)
  - [`opencode`](https://opencode.ai/) — `opencode run` (timeout-guarded)
  - [`pi`](https://github.com/earendil-works/pi-mono) — `pi -p` (non-interactive print mode)
  - [`kimi`](https://github.com/MoonshotAI/kimi-code) — `kimi -p` (Kimi Code CLI, non-interactive print mode)
  - Add more (gemini-cli, qwen, aider, …) via `/xcheck-setup add <name>`.
- For xcheck to be **meaningful**, at least one must be non-`claude`.
- A bash shell. Developed/tested on **Windows + Git Bash**; `detect.sh` is bash, so macOS/Linux should work too.

Timeouts: every agent runs under a **total execution budget** (factory `2700`s, per-agent overridable) honored by a background-launch + polling carrier — a long review is never killed mid-flight by a foreground tool limit, and output is always on disk. View / change via `/xcheck-setup timeout`.

## Install

Copy the skill folders into your global skills directory:

```bash
# from the repo root
cp -r xcheck xcheck-diag xcheck-review xcheck-close xcheck-setup ~/.claude/skills/
```

Then in Claude Code, make sure each installed agent CLI is logged in, and run `/xcheck-setup` once to verify everything talks.

> The shared logic lives in `xcheck/lib/` and `xcheck/prompts/`; the other four folders are thin shells that reference it.

## File layout

```
xcheck/
├── SKILL.md                     # /xcheck — auto-router entry
├── agents.toml                  # agent → non-interactive command map + defaults (timeout, default_agents)
├── lib/
│   ├── flow.md                  # shared flow: step-0 intake + detect → smoke → select → fan-out → collect → synthesize → triage
│   ├── context-intake.md        # step-0 context intake / proposal solidification
│   ├── close-flow.md            # /xcheck-close close-loop (C0–C5)
│   ├── detect.sh                # detection: `which` over agents.toml
│   ├── subagent-carrier.md      # the "carry, don't judge" subagent instructions (background launch + polling)
│   └── extractor-carrier.md     # the fact-extraction subagent instructions
└── prompts/
    ├── diag.md  review.md               # instruction templates fed to each external agent ({{PROPOSAL_PATH}} / {{INPUT_PATH}} / {{CONTEXT_PATH}})
    ├── synthesize-diag.md  synthesize-review.md   # main-session synthesis
    └── triage.md                        # three-tier feedback triage
xcheck-diag/SKILL.md             # thin shell → flow.md + diag.md
xcheck-review/SKILL.md           # thin shell → flow.md + review.md
xcheck-close/SKILL.md            # thin shell → close-flow.md
xcheck-setup/SKILL.md            # detect / verify / add / timeout / default
```

## Philosophy / guardrails

- **Blind evaluation** — each agent runs in its own process, in parallel, and never sees the others' output. Prevents groupthink.
- **Subagents never judge** — they only carry and condense.
- **Human in the loop** — output is always "suggestions"; it never edits code, merges, or approves for you. Close-loop experiments only run after your explicit approval, in a sandbox (temp files only, no business-code edits, no network).
- **Cheap carriers, strong synthesizer** — subagents use haiku/sonnet; the main session uses the strong model for synthesis.
- **Everything on disk** — every run leaves a full audit trail under `.xcheck/<ts>/` (prompt, content snapshots, raw outputs, summaries, SUMMARY/CLOSE); the directory is gitignored.

## License

[MIT](LICENSE) © 2026 allanpk716

---

## 中文文档

`xcheck` 是一组全局 [Claude Code](https://code.claude.com/) skill。你给它一个 bug / 报错 / "为什么这个不工作"，或一个方案 / 设计 / 代码改动，它会：

0. **（仅当输入不自包含时）摄入固化**——比如"评审刚才讨论的方案"，会把讨论固化成**中性、自包含的 proposal**，另附**你原话陈述的事实清单**，两者都经你过目后才往下走；自包含输入（完整报错栈 / 设计文档 / 文件路径）跳过此步，但主会话仍会静默扫一遍最近对话，把直接相关的你的原话摘进单独的 context 文件。
1. **检测**你本机装了哪些 AI agent CLI（`claude`、`codex`、`opencode`、`pi`、`kimi`……），并逐家**冒烟预检**（≤60 秒：读一个文件并原样回出来）——欠费 / 未登录 / 非交互模式读不了文件的家，在 fan-out **之前**就被拦下。
2. **并行派发**，每个 agent 包在独立的 Claude subagent 里独立推理，彼此看不见——**盲评**。agent 自己读**内容文件**（proposal / 问题全文）；prompt 本体只是 ≤2KB 的指令层（既不会撞 Windows 32K 命令行上限，文件输入也不过主会话的 token）。
3. **只搬运**——subagent 不许评判、不许合并观点，只忠实精简各家的原始输出。全部产物落盘 `.xcheck/<ts>/`（原始输出、各家结论、汇总），全程留底可审计。
4. **主会话汇总**：各家**共识**（强信号）、**分歧**、只一家说的（存疑）。
5. **反馈分级**：每条反馈按可验证性归三类——① 可直接证实、② 可设计实验验证、③ 存疑仅参考。
6. **交你拍板**——共识 ≠ 正确。绝不自动改代码 / 自动合并 / 自动"通过"。可选 `/xcheck-close` 闭环：证实 ①、执行批准后的 ② 实验、汇成必改清单、把修订写成**新文件**（原稿不动）、复审（≤2 轮）。

核心是**异构**：如果每个"第二意见"都来自你正在聊的同一个 Claude，你什么也得不到。xcheck 强制至少选一个**非 claude** 的 agent（如 `codex`、`opencode`、`kimi`），让意见真正独立。

### 五个命令（都是手动 slash 命令，不会自动触发）

| 命令 | 作用 |
|---|---|
| `/xcheck <文字>` | **自动路由**——读你的文字，判成"问题"还是"方案"，转派 diag 或 review；判不了就反问。 |
| `/xcheck-diag <问题>` | **并行诊断**——喂一个报错/异常/"为什么不工作"；得各家根因 + 共识根因。 |
| `/xcheck-review <方案>` | **交叉评审**——喂一个设计/改动/文件路径；得各家 `AGREE` / `SUGGEST_CHANGES` / `DISAGREE` + 综合裁决，且每条反馈归入三类可验证性分级。 |
| `/xcheck-close [--agents a,b,c] [<ts>]` | **评审闭环**——对已跑完分级的评审：只读查证第一类、批准后执行第二类实验、汇成必改清单、修订写成新文件 `<原名>.rev<m>.md`（原稿不动）、可选复审（硬上限 2 轮）。过程写 `CLOSE.md`，可断点续跑。 |
| `/xcheck-setup` | **检测 / 验证 / 配置**——列出已装 CLI、逐个验证、登记新 agent。子命令：`add <name>`、`timeout [N \| <agent> N]`、`default [<n1>,<n2>,… \| --clear]`。 |

所有运行命令（`/xcheck`、`/xcheck-diag`、`/xcheck-review`、`/xcheck-close`）都支持可选 `--agents a,b,c` 参数——本次运行临时换 agent 集（名字笔误立即报错停住）。优先级：`--agents` > `default_agents` 默认集 > 每次弹窗多选。出厂默认集为 `["codex", "kimi", "pi"]`，用 `/xcheck-setup default` 查看 / 设置 / 清空。

### 工作原理

```
你: /xcheck-review "docs/auth-design.md"      （或 /xcheck-diag "为什么这个坏了"）
        │
  [0]  摄入 ── 仅输入不自包含时:固化中性自包含 proposal + 用户原话事实清单,
        │      两者经你过目后才 fan-out。自包含输入跳过,但仍静默扫最近对话,
        │      相关用户原话 → context.md。
        │
  [1]  检测 ── lib/detect.sh(`which`)读 agents.toml → 已装 agent 列表
        │
  [1.5] 冒烟 ── 每家候选 ≤60s:读 .xcheck/smoke.txt 并原样回内容。
        │      CLI 欠费/未登录/损坏、非交互读不了文件 → fan-out 前剔除。
        │
  [2]  选集 ── --agents 参数 > default_agents 默认集(出厂:codex,kimi,pi) >
        │      弹窗多选(提醒:至少选一个非 claude)
        │
  [3]  派发 ── 每家一个便宜 Claude subagent,一条消息并行。CLI 后台启动 +
        │      全程落盘轮询(总时限 timeout_sec,出厂 2700s,含挂起检测)。
        │      指令层:prompt.txt(≤2KB,只含路径)。内容层:proposal.md /
        │      input.md / context.md——评审 agent 自己读文件。
        │
  [4]  收齐 ── 等全部返回;标注超时/失败;<agent>.raw.out + <agent>.summary.md
        │      落盘 .xcheck/<ts>/(另写 run.md 供 /xcheck-close 定位)
        │
  [5]  汇总(主会话,强模型)→ 共识 / 分歧 / 存疑 → SUMMARY.md
        │      → "共识 ≠ 正确,你拍板" —— 你决定
        │
  [6]  分级 ── 每条反馈归:① 可直接证实 ② 可设计实验验证(只设计,绝不自动跑)
        │      ③ 存疑仅参考 → 追加进 SUMMARY.md
        │
 (可选)  /xcheck-close → 查证 ①(✅/❌/❓ 带证据)· 执行批准后的 ② 实验
        (沙箱:临时文件落 .xcheck/<ts>/exp/,禁改业务代码/禁联网)· 必改清单 ·
        修订写新文件 · 复审 ≤2 轮
```

### 两条铁律（违反则 skill 价值归零）

1. **subagent 只搬运、不评判。** subagent 也是 Claude——它一掺意见就把异构意见同质化，你丢掉要的独立第二意见。综合判断只在主会话做。
2. **至少选一个非 claude。** 否则就是 Claude 自己审自己。

### 环境要求

- **[Claude Code](https://code.claude.com/)**——xcheck 是它的 skill，编排（subagent、`AskUserQuestion`）在它里面跑。
- **一个或多个本机 AI agent CLI（在 `PATH` 上）。** 开箱认识：`claude`（`claude -p`）、`codex`（`codex exec --skip-git-repo-check -` 走 stdin；该 flag 让它在 git 仓库外也能跑——评审对象常在仓库外）、`opencode`（`opencode run`，强制 timeout）、`pi`（`pi -p`，非交互 print 模式）、`kimi`（`kimi -p`，Kimi Code CLI，非交互 print 模式）。想加别的（gemini-cli、qwen、aider……）用 `/xcheck-setup add <name>`。
- 要有意义，**至少一个非 claude**。
- bash 环境。在 **Windows + Git Bash** 上开发/测试；`detect.sh` 是 bash，macOS/Linux 理论可用。

超时：每家 agent 都跑在**总执行时限**内（出厂 `2700`s，可按 agent 覆盖），由"后台启动 + 轮询"的搬运工兑现——长评审不会被前台工具上限掐断、输出永远在盘上。用 `/xcheck-setup timeout` 查改。

### 安装

```bash
# 仓库根目录下
cp -r xcheck xcheck-diag xcheck-review xcheck-close xcheck-setup ~/.claude/skills/
```

进 Claude Code 后，确保每个 agent CLI 已登录，跑一次 `/xcheck-setup` 验证都能通。

> 共享逻辑在 `xcheck/lib/` 和 `xcheck/prompts/`；其余四个目录是引用它的薄壳。

### 目录结构

```
xcheck/
├── SKILL.md                     # /xcheck —— 自动路由入口
├── agents.toml                  # agent → 非交互命令映射 + 默认项(timeout、default_agents)
├── lib/
│   ├── flow.md                  # 共享流程:第 0 步摄入 + 检测→冒烟→选集→派发→收齐→汇总→分级
│   ├── context-intake.md        # 第 0 步上下文摄入 / 方案固化
│   ├── close-flow.md            # /xcheck-close 闭环流程(C0~C5)
│   ├── detect.sh                # 检测:对 agents.toml 逐个 `which`
│   ├── subagent-carrier.md      # "只搬运不评判"的 subagent 指令(后台启动+轮询)
│   └── extractor-carrier.md     # 事实摘录 subagent 指令
└── prompts/
    ├── diag.md  review.md               # 喂给外部 agent 的指令模板({{PROPOSAL_PATH}}/{{INPUT_PATH}}/{{CONTEXT_PATH}})
    ├── synthesize-diag.md  synthesize-review.md   # 主会话汇总模板
    └── triage.md                        # 三类反馈分级模板
xcheck-diag/SKILL.md             # 薄壳 → flow.md + diag.md
xcheck-review/SKILL.md           # 薄壳 → flow.md + review.md
xcheck-close/SKILL.md            # 薄壳 → close-flow.md
xcheck-setup/SKILL.md            # 检测 / 验证 / add / timeout / default
```

### 命门

- **盲评**——各 agent 独立进程、并行、互不可见，防串通。
- **subagent 不评判**——只搬运精简。
- **人在环**——输出永远是"建议"，绝不替你改代码 / 合并 / 通过。闭环实验必须经你明确批准才执行，且只限沙箱（临时文件、禁改业务代码、禁联网）。
- **便宜搬运、强模型汇总**——subagent 用 haiku/sonnet，主会话汇总用强模型。
- **全程落盘**——每次运行在 `.xcheck/<ts>/` 留全量审计底（prompt、内容快照、原始输出、各家结论、SUMMARY/CLOSE）；该目录已 gitignore。

### 许可证

[MIT](LICENSE) © 2026 allanpk716
