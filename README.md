# xcheck

**One trigger → blind cross-review by multiple local AI agents → auto-verification → a verified three-tier issue list. You decide at the single gate.**

**一次触发 → 本地多个异构 AI agent 盲评交叉验证 → 自动查证与实验 → 已验证三分类清单。停点一问,你拍板。**

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

xcheck is a set of global [Claude Code](https://code.claude.com/) skills. You hand it a design / proposal / code change (or a bug), and it runs **one automatic chain**:

1. **(Vague or empty input)** resolves the target for you — picks the spec/plan file you just wrote or discussed in this session (or distills the discussion into a proposal), infers review vs diagnose, and packs target + mode + your verbatim background facts into **one confirmation popup**. Self-contained inputs (a file path, a pasted doc, a full stack trace) skip straight through with a silent background pull.
2. **Detects** which local AI-agent CLIs you have (`claude`, `codex`, `opencode`, `pi`, `kimi`, …), then **smoke-tests** each candidate (≤60s: read a file and echo it back) — dead CLIs are dropped **before** fan-out.
3. **Fans them out in parallel**, each in its own isolated subagent — **blind evaluation**, agents can't see each other. Agents read the proposal from **content files**; the prompt itself is a ≤2KB instruction layer.
4. **Synthesizes a compact header** (per-agent verdicts + three-pattern overall: focused consensus / split / one-sided) and **triages** every feedback item into three verifiability tiers: ① directly verifiable, ② experiment-verifiable, ③ suspect / reference-only. During all of this the chat only gets one-line progress notes marked "no action needed from you".
5. **Auto-verifies, no questions asked**: tier-① items are checked read-only against your code (✅ / ❌ / ❓ with evidence); tier-② experiments run automatically in a sandbox (temp files under `.xcheck/<ts>/exp/`, no business-code edits, no network, no deploy; per-item 300s timeout).
6. **Single gate**: presents a **plain-language verdict** — *"your plan works, but N verified issues should be fixed first — your call"*, each must-fix with who raised it and the evidence, refuted items you can ignore, and **watch items** for development (each with a trigger and a stop-and-report action) — then asks exactly one question, *"fix these N issues and re-review?"* Yes → writes `<name>.rev1.md` (**original text untouched**) and auto re-reviews (≤2 rounds, then "recommend starting over"). No → done (`user-declined`). Either way a **review appendix** ("reference, execution governs") lands at the end of the reviewed doc; the machine-readable ledger (numbers, enums, tier symbols) stays in `.xcheck/<ts>/SUMMARY.md`.

**Progress lives on disk only** (`PROGRESS.md`, per-stage) — crash mid-chain, re-trigger `/xcheck`, confirm "resume", and it continues from the first unfinished stage. No session memory involved.

The whole point is **heterogeneity**: if every "second opinion" comes from the same Claude you're already talking to, you learn nothing. xcheck insists on at least one non-`claude` agent.

## Commands

Both are **manual slash commands** (`disable-model-invocation: true`).

| Command | What it does |
|---|---|
| `/xcheck [--agents a,b,c] <text>` | **The whole chain** — auto-routes problem vs proposal, blind fan-out, triage, verification, single gate. Bare `/xcheck` = resume check for an unfinished chain, else **resolve the target from this session's context** (one confirm popup). |
| `/xcheck-setup` | Detect / verify / register agent CLIs. Subcommands: `add <name>`, `timeout [N \| <agent> N]`, `default [<n1>,<n2>,…]`. |

Agent selection: `--agents` flag > `default_agents` (set via `/xcheck-setup default`) > hard error telling you to set a default. No popups.

## How it works

```
/xcheck <text>
   │  unfinished chain on disk? → ask: resume (PROGRESS.md, stage-granular) or start new
   │  self-contained input? → keyword route · vague/empty? → object resolver (file > discussion
   │  > diagnose), one confirm popup with target + mode + background
   │
   ├ diag ──→ smoke → fan-out → collect → synthesize + triage → present ("you decide") → done
   │
   └ review → resolve (vague) or silent background pull (self-contained)
              discussion-type: the solidified proposal lands as
              docs/superpowers/specs/<date>-<topic>-consensus.md — revisions go next to it
        → smoke → fan-out (blind, parallel) → collect → compact header → triage
        → verify ① (read-only, auto) → experiments ② (sandbox, auto)
        ══ SINGLE GATE: plain-language verdict + one question ("fix these N?") ══
              │No (→ user-declined)      │Yes
              ▼                          ▼
        review appendix (reference,   write .rev1.md (original text untouched)
        appended to reviewed doc)     → auto re-review
                                     ≤2 rounds → converged | "recommend starting over"
```

**Two iron rules** (break them and the skill is worthless):

1. **Subagents only carry, never judge.** Synthesis/verification happens only in the main session.
2. **Always ≥1 non-`claude` agent.** Otherwise Claude is reviewing itself.

## Requirements

- [Claude Code](https://code.claude.com/) — the orchestration runs inside it.
- One or more local AI-agent CLIs on your `PATH`. Out of the box it knows: `claude` (`claude -p`), `codex` (`codex exec --skip-git-repo-check -s danger-full-access -`, stdin), `opencode` (`opencode run`), `pi` (`pi -p`), `kimi` (`kimi -p`). Add more via `/xcheck-setup add <name>`.
- For xcheck to be meaningful, at least one must be non-`claude`.
- A bash shell. Developed/tested on Windows + Git Bash.

Timeouts: every agent runs under a total execution budget (factory `2700`s, per-agent overridable) enforced by `lib/run-agent.sh` (background supervisor + hang detection + tree-kill). View / change via `/xcheck-setup timeout`.

## Install

```bash
# from the repo root
cp -r xcheck xcheck-setup ~/.claude/skills/
```

Then in Claude Code, make sure each agent CLI is logged in, and run `/xcheck-setup` once to verify everything talks.

> The shared logic lives in `xcheck/lib/` and `xcheck/prompts/`; `xcheck-setup/` is a thin shell. On Windows you can junction instead of copying (junctions are live — editing the repo edits the skill).

## File layout

```
xcheck/
├── SKILL.md                     # /xcheck — entry: --agents / unfinished-chain check / routing
├── agents.toml                  # agent → non-interactive command map + defaults (timeout, default_agents)
├── lib/
│   ├── flow.md                  # the auto-chain brain: resume mode + steps 0-10 + PROGRESS + edges
│   ├── context-intake.md        # step-0 object resolver (file > discussion > diagnose) + context intake
│   ├── detect.sh                # detection: `which` over agents.toml
│   ├── run-agent.sh             # agent execution supervisor: build/precheck/forensics/timeout/hang/kill
│   ├── subagent-carrier.md      # the "carry, don't judge" subagent instructions
│   └── extractor-carrier.md     # the fact-extraction subagent instructions
├── prompts/
│   ├── diag.md  review.md               # instruction templates fed to each external agent
│   ├── synthesize-diag.md  synthesize-review.md   # synthesis (review = compact header)
│   └── triage.md                        # three-tier feedback triage
└── tests/run-agent.test.sh      # stub regression suite for run-agent.sh (33 assertions)
xcheck-setup/SKILL.md            # detect / verify / add / timeout / default
CONTEXT.md                       # glossary (canonical terms)
docs/adr/0001-single-gate-autochain.md   # why the single-gate redesign
```

## Philosophy / guardrails

- **Blind evaluation** — each agent runs in its own process, in parallel, never seeing the others.
- **Subagents never judge** — they only carry and condense.
- **Human at the single gate** — output is always "suggestions"; it never edits code, merges, or approves for you. Experiments stay sandboxed; revisions are always new files, original text untouched (the end-of-doc review appendix is the sole exception).
- **Chat speaks human, files keep the machine ledger** — the conversation and the review appendix talk about *your* plan in plain sentences; numbering, enums and tier symbols live only in `.xcheck/<ts>/SUMMARY.md`.
- **Progress on disk only** — every run leaves a full audit trail under `.xcheck/<ts>/` (prompt, content snapshots, raw outputs, summaries, PROGRESS, SUMMARY); resumable at stage granularity.
- **Cheap carriers, strong synthesizer** — subagents use haiku/sonnet; the main session uses the strong model.

## License

[MIT](LICENSE) © 2026 allanpk716

---

## 中文文档

`xcheck` 是一组全局 [Claude Code](https://code.claude.com/) skill。你给它一个方案/设计/代码改动(或一个 bug),它跑**一条自动链**:

1. **(输入含糊或为空)**对象解析——自动锁定本会话刚写/刚讨论的 spec、plan 或设计文档(纯讨论则固化成 proposal,**确认时落盘为 `docs/superpowers/specs/<日期>-<主题>-consensus.md`**,修订落它旁边),推断 review 还是 diag,把**对象+模式+你的背景原话打包成一个确认窗**过目;自包含输入(路径/贴文/完整报错)直接走,静默带背景。
2. **检测**本机 AI agent CLI 并逐家**冒烟预检**(≤60s 读文件回显)——坏家在 fan-out 前剔除。
3. **并行派发**,每家一个隔离 subagent——**盲评**,互不可见;agent 自己读**内容文件**,prompt 只是 ≤2KB 指令层。
4. **紧凑头汇总**(各家裁决一行 + 总判三定式:焦点共识/意见分裂/一边倒)+ **三分类**:①可直接证实 / ②可实验验证 / ③存疑仅参考。期间对话只有一行行标着"无需操作"的进度播报。
5. **自动验证,不问**:①逐条只读查证(✅/❌/❓ 带证据);②沙箱实验自动跑(临时文件落 `exp/`、禁改业务代码/联网/部署、单条 300s 超时)。
6. **单停点**:呈现**人话结论**——"方案能用,但有 N 个问题已经查实,建议改完再动手——改不改你定"(或"没发现能查实的问题,可以推进"),每条必改带谁提的+证据、证伪条目"查过不用理"、**开发时要盯**(③+②无定论,每条带触发点与"命中:停下反馈"),只问一句——"**要我把这 N 个问题改了、再自动评一轮吗?**"要 → 写 `<原名>.rev1.md`(**原稿正文不动**)并自动复审(≤2 轮,超限报"推倒重来");不要 → 终态 `用户不修`。无论哪条路,**评审附录**("评审参考,以实际执行为准")落被评文档文末;机器账(编号/enum/①②③)只在 `.xcheck/<ts>/SUMMARY.md`。

**进度只认盘**(`PROGRESS.md` 阶段粒度)——链中途崩了,重敲 `/xcheck` 确认"续跑",从第一个未完成阶段继续,不依赖任何会话记忆。

核心是**异构**:至少一个非 claude 的 agent,否则就是 Claude 自己审自己。

### 两个命令(手动 slash 命令)

| 命令 | 作用 |
|---|---|
| `/xcheck [--agents a,b,c] <文字>` | **整条链**——自动路由、盲评、三分类、验证、单停点。裸敲 = 查未完成链,否则**从本会话上下文解析评审对象**(一个确认窗)。 |
| `/xcheck-setup` | 检测/验证/登记 agent CLI。子命令:`add <name>`、`timeout [N \| <agent> N]`、`default [...]`。 |

选集:`--agents` 参数 > `default_agents` 默认集(用 `/xcheck-setup default` 设)> 报错提示先设默认集。无弹窗。

### 两条铁律(违反则 skill 价值归零)

1. **subagent 只搬运、不评判**;综合/查证/裁决只在主会话。
2. **至少一个非 claude**。

### 安装

```bash
cp -r xcheck xcheck-setup ~/.claude/skills/
```

进 Claude Code 后确保各 agent CLI 已登录,跑一次 `/xcheck-setup` 验证。开发机上可用 junction 代替拷贝(Windows 免提权,junction 是活的)。

### 命门

- **盲评**——独立进程、并行、互不可见。
- **subagent 不评判**——只搬运精简。
- **单停点人在环**——输出永远是"建议",绝不替你改代码/合并/通过;实验锁沙箱,修订永远写新文件,原稿正文永不动(唯一例外:终态在被评文档文末追加评审附录)。
- **对话说人话、文件留机器账**——对话和评审附录每句都在说你的方案;编号、enum、①②③只活在 `.xcheck/<ts>/SUMMARY.md`。
- **进度只认盘**——`.xcheck/<ts>/` 全量留底,阶段粒度可续跑。
- **便宜搬运、强模型汇总**。

### 许可证

[MIT](LICENSE) © 2026 allanpk716
