# xcheck 单停点全自动链 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-09-16-xcheck-single-gate-autochain-design.md`(v0.12.0):命令面 5→2,`/xcheck` 一次触发自动推进到"已验证三分类清单",停点一问;进度只认盘(PROGRESS.md)。

**Architecture:** 全部改动落在仓库 `C:\WorkSpace\agent\xcheck`(`xcheck/` 经 junction = `~/.claude/skills/xcheck/`,改仓库文件即改 skill)。重写两个文件(`xcheck/SKILL.md` 入口壳、`xcheck/lib/flow.md` 自动链大脑——吸收并取代 close-flow.md)、重写一个模板(`prompts/synthesize-review.md` 紧凑头)、删除三个薄壳目录与 close-flow.md、一致性小修两处(setup 模式 D 文案、agents.toml 头注释)、重写 README、CHANGELOG 0.12.0、清理 3 个 junction。

**Tech Stack:** Claude Code skill(Markdown prompt 模板 + `$ARGUMENTS`);prose/prompt 工程,无单测——"测试"是行为验证(grep 结构检查 / 实跑检查 `.xcheck/` 产出)+ 既有 `tests/run-agent.test.sh`(run-agent.sh 未动,应全绿)。

**Spec:** `docs/superpowers/specs/2026-09-16-xcheck-single-gate-autochain-design.md`(决策依据,随计划一起读);决策记录 `docs/adr/0001-single-gate-autochain.md`;术语表 `CONTEXT.md`。

## Global Constraints

- **停点纪律**:全链只三处开口——壳的"续还是新开"(仅有未完成链)、第 0 步摄入确认(仅不自包含输入)、第 9 步停点一问;其余全自动。
- **进度只认盘**:阶段完成即勾 `PROGRESS.md`;终态非空 = 完成,永不续跑;旧版产物(run.md、无 PROGRESS.md)不算未完成。
- **事故护栏零改动**:agents.toml 配置逻辑、detect.sh、run-agent.sh、subagent-carrier.md、extractor-carrier.md、context-intake.md、prompts/{diag,review,triage,synthesize-diag}.md、tests/、xcheck-setup 主体。
- **实验三禁令**:禁改业务代码、禁联网、禁部署;临时文件一律 `.xcheck/<ts>/exp/`;单条超时 300s → 无定论。
- **修订只写新文件** `<原名>.rev<m>.md`(inline 时 `.xcheck/<ts>/proposal.rev<m>.md`),原稿永不动;硬上限 2 轮修订。
- **版本 0.12.0**;平台 Windows + Git Bash;LF 行尾(`.gitattributes` 强制);中文标点/emoji 原样。
- **不碰的未提交改动**:`xcheck/agents.toml` 与 `xcheck/lib/subagent-carrier.md` 工作区有用户未提交修改(codex 沙箱 flag、carrier 等待纪律)——agents.toml 只改头注释且**不 git add**;subagent-carrier.md 完全不动。

---

## File Map

仓库 `C:\WorkSpace\agent\xcheck` 下,路径相对仓库根。

| 文件 | 职责 | 本计划动作 |
|---|---|---|
| `xcheck/SKILL.md` | /xcheck 入口壳:--agents / 弹窗0 / 路由 / 转派 | **重写**(Task 1) |
| `xcheck/lib/flow.md` | 自动链编排大脑(恢复模式 + 0~10 步 + PROGRESS + 边界) | **重写**(Task 2) |
| `xcheck/prompts/synthesize-review.md` | review 汇总模板 | **重写**(Task 3):紧凑头 |
| `xcheck/lib/close-flow.md` | 旧闭环编排 | **删除**(Task 3) |
| `xcheck-diag/`、`xcheck-review/`、`xcheck-close/` | 三个薄壳 | **删除目录**(Task 4) |
| `xcheck-setup/SKILL.md` | 运维壳 | **微改**(Task 4):模式 D 旧话术 |
| `xcheck/agents.toml` | agent 注册表 | **仅改头注释**(Task 4,不 commit) |
| `README.md` | 项目文档 | **重写**(Task 5) |
| `CHANGELOG.md` | 版本日志 | **修改**(Task 6):0.12.0 |
| `~/.claude/skills/` junctions | 安装 | **删 3 个**(Task 7) |

---

## Task 1: 重写 `xcheck/SKILL.md`(入口壳)

**Files:**
- Modify(整体替换): `C:\WorkSpace\agent\xcheck\xcheck\SKILL.md`

**Interfaces:**
- Produces(供 flow.md 消费):`MODE`(diag|review)、`OVERRIDE_AGENTS`(可选,名字已校验)、`RESUME_TS`(可选,恢复模式)。
- Consumes:`<cwd>/.xcheck/*/PROGRESS.md`(未完成链检测:终态段为空)、`agents.toml` 的 `[agents.<name>]`(名字校验)。

- [ ] **Step 1: Write 全文替换 SKILL.md**

用 Write 工具写入以下全文:

````markdown
---
name: xcheck
description: 一次触发全自动异构评审 —— 并行盲评本地多个 AI agent、自动查证与实验、终点交付已验证三分类清单,停点一问。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--agents a,b,c] [<问题描述或方案>]
---

# /xcheck — 单停点全自动链入口

`$ARGUMENTS` 可空(裸敲 = 只查未完成链,没有就反问)。你(壳)只做四件事:**抠 --agents → 查未完成链 → 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(可选)+ 10 步」,你不重新实现它。

## 1. 抠 --agents(可选)

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。token 非空 → `OVERRIDE_AGENTS = <拆成的名字列表>`;名字不在 agents.toml 的 `[agents.<name>]` → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续。token 为空 → 当没敲。

## 2. 查未完成链(弹窗 0)

扫 `<cwd>/.xcheck/*/PROGRESS.md`:文件存在且其 `## 终态` 段**为空** = 该 ts 未完成。取 ts 字符串最大的一个(多个未完成:取最新,选项文本顺带列出其余)。

- **没有未完成** → 进第 3 件。
- **有** → AskUserQuestion(单选):
  - `续跑 <ts>(停于:<PROGRESS 第一个未勾阶段>)` → 设 `RESUME_TS = <ts>`,**跳过路由与摄入**,直接按第 4 件转派 flow.md 恢复模式。
  - `新开` → 剩余 `$ARGUMENTS` 非空 → 进第 3 件;为空 → 反问"要评审什么/诊断什么?"拿到内容再进第 3 件。

> 旧版产物(run.md、无 PROGRESS.md 的目录)**不算未完成**,静默忽略。

## 3. 路由(diag | review)

扫描剩余 `$ARGUMENTS`(及最近对话,若有)是否命中强信号关键词。**子串包含、大小写不敏感。**

**🩺 diag 强信号**(已发生的坏现象 / 根因):
- 中文:报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈
- 英文:error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE(及类似大写错误码)

**🔎 review 强信号**(待决策的方案 / 设计 / 改动):
- 中文:评审、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、PR、MR
- 英文:review、design、proposal、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback

**判定**(按顺序):
1. 只有 diag 命中 → **diag**;只有 review 命中 → **review**。
2. 双边命中或双边都无 → **AskUserQuestion 反问,不瞎猜**:选项 `诊断 —— 我有个报错/异常/不工作的现象,想定位根因` / `评审 —— 我有个方案/设计/改动,想听异构意见`。
3. **指代词例外**:单边强信号 + 指代词(刚才/那个/上面/之前/这个/这/那/this/that/above)→ 直接走该边("评审刚才的方案"不可能是诊断)。

## 4. 转派 flow.md

设 `MODE = diag | review`,连同 `OVERRIDE_AGENTS`(若有)、`RESUME_TS`(若有,仅第 2 件续跑时),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。diag 用 `prompts/diag.md` + `prompts/synthesize-diag.md`;review 用 `prompts/review.md` + `prompts/synthesize-review.md`。

## 铁律(全套,不打折扣)

- **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合只在主会话。
- **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步摄入确认(仅不自包含输入)、flow 第 9 步停点一问;**其余一律自动推进**。
- 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,原稿不动。
- **至少一个非 claude**;全 claude 只标注不拦。
- 派 subagent 用便宜模型,一条消息并行;成败看退出码,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 产物落 `.xcheck/<ts>/`(已 gitignore);终态收尾原样输出"**以上是建议,共识 ≠ 正确,最终你拍板。**"
````

- [ ] **Step 2: 验证**

Run:
```bash
grep -c '^## ' xcheck/SKILL.md && grep -n 'RESUME_TS\|PROGRESS\|指代词例外' xcheck/SKILL.md | head -10
```
Expected: 二级标题 5 个(1. 抠 --agents / 2. 查未完成链 / 3. 路由 / 4. 转派 / 铁律);RESUME_TS、PROGRESS、指代词例外均有命中。

- [ ] **Step 3: Commit**

```bash
git add xcheck/SKILL.md
git commit -m "feat(xcheck): rewrite entry shell — one-trigger auto-chain entry

壳收敛为四件事:抠 --agents(笔误报错)→ 查未完成链(弹窗0:自动发现、
人工确认续/新开)→ 路由(diag/review,指代词例外保留)→ 转派 flow.md
(MODE/OVERRIDE_AGENTS/RESUME_TS)。实现 spec 2026-09-16 §3。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 重写 `xcheck/lib/flow.md`(自动链大脑)

**Files:**
- Modify(整体替换): `C:\WorkSpace\agent\xcheck\xcheck\lib\flow.md`

**Interfaces:**
- Consumes(壳产出):`MODE` / `OVERRIDE_AGENTS` / `RESUME_TS`;`agents.toml`;`lib/{context-intake,detect.sh,run-agent.sh,subagent-carrier}.md|sh`;`prompts/{diag,review,synthesize-diag,synthesize-review,triage}.md`。
- Produces:`.xcheck/<ts>/PROGRESS.md`(12 行阶段清单 + 终态)、`SUMMARY.md`(紧凑头+三分类+验证结果+必改项)、`proposal.md`/`input.md`/`context.md`/`prompt.txt`/`<agent>.raw.out`/`<agent>.summary.md`/`exp/`;复审环的 `<原名>.rev<m>.md`。

- [ ] **Step 1: Write 全文替换 flow.md**

用 Write 工具写入以下全文:

````markdown
# xcheck 自动链执行流程(mode = diag | review)

主会话(你)执行一条**自动链**:第 0 步(可选摄入)+ 第 1~9 步;停点答"要"才有第 10 步(修订+复审)。壳(xcheck/SKILL.md)已设定:`MODE`(diag|review)、`OVERRIDE_AGENTS`(可选)、`RESUME_TS`(可选 = 恢复模式)。**严格按步骤走,不跳步。**

**进度只认盘(铁律)**:每阶段完成即在 `<cwd>/.xcheck/<ts>/PROGRESS.md` 打勾(格式见文末)。会话崩了/中断,用户重敲 `/xcheck`,壳检测未完成链、经用户确认后续跑——恢复与排障的唯一依据是这个文件,不依赖任何会话记忆。

**停点纪律(铁律)**:全链只有三处开口等用户——① 壳的"续旧的还是开新的"(仅当盘上有未完成链);② 第 0 步摄入确认(仅当输入不自包含);③ 第 9 步停点一问。**其余一切(检测/冒烟/派发/汇总/三分类/查证/实验)自动推进,不问、不停、不等批准。**

---

## 恢复模式(RESUME_TS 存在时,最优先)

1. 读 `<cwd>/.xcheck/<RESUME_TS>/PROGRESS.md`;读不到 → 报"PROGRESS.md 不存在,无法续跑",停。
2. 从头部读出 `mode` / `selected` / `source` / `round` / `prev`。
3. **当前 ts = RESUME_TS**(不新建目录)。阶段清单里已勾的跳过;从**第一个未勾阶段**起,按本文对应步骤整段重做。
4. 用户已答的决策**不跨恢复记忆**——停点(gate)未勾,恢复时重新问;摄入(intake)已勾,不再问。
5. 恢复不再弹"续还是新开"(壳已问过)。

## 第 0 步:摄入(可选)

`$ARGUMENTS` 是指代性/简短输入(如"评审刚才那个")、**不自包含**时,按 `~/.claude/skills/xcheck/lib/context-intake.md` 执行:切最近对话 → 派摘录 subagent(haiku)摘客观事实 → 用户逐条确认 → 确认后的事实清单落内容文件 `input.md`(diag)/ `proposal.md`(review)。

- **自包含输入**(完整报错栈/设计文档/文件路径)→ 跳过摄入直接用 `$ARGUMENTS`。但跳过 ≠ 不带背景:仍**零往返静默扫**最近对话,摘直接相关的用户原话落 `context.md`(`lib/context-intake.md` 第 0.6 步),对话里明说一句;没摘到就不建。
- 摄入若运行,已建 `<cwd>/.xcheck/<ts>/` → 后续**复用这个 ts**,不重复建。
- 完成后勾 PROGRESS:`intake`(跳过摄入也勾)。

## 第 1 步:检测 + 定选集 + 初始化 PROGRESS

1. 跑 `bash ~/.claude/skills/xcheck/lib/detect.sh`。stdout = 已装 agent(每行 `name \t installed_check \t installed`);stderr = 已登记未装。**已装 < 2** → 告诉用户太少(异构至少 2 家、≥1 非 claude),建议 `/xcheck-setup`,**停**。
2. **初始化 PROGRESS.md**(摄入没建目录时才建):`<cwd>/.xcheck/<YYYYMMDD-HHMMSS>/`(本地时间),写头部(格式见文末;`selected`/`source` 先留待定,本步与 3.1 步补写)。
3. **定候选集**(一条道,无弹窗):
   - `OVERRIDE_AGENTS` 非空(壳已校验名字)→ 候选 = 它。
   - 否则读 `~/.claude/skills/xcheck/agents.toml` 的 `[defaults].default_agents`:存在且非空 → 候选 = 它;坏名(不在 `[agents.*]`,toml 被手改坏)**防御剔除**后用剩余;剔除后空 → 报错停。
   - 都没有 → **报错停住**:"未设默认集也没敲 --agents。先跑 `/xcheck-setup default <a,b,c>` 设默认集,再 /xcheck。"**不弹多选。**
4. 取 `SELECTED = 候选 ∩ INSTALLED`:缺员 → 用交集,输出注明"默认集里 <缺的名> 当前未装/未登录,本轮用 <交集>";交集 < 2 家 → 停。
5. 同构(全 claude 或 <2 家)→ **不拦**,第 9 步 SUMMARY 顶部标注 "⚠️ 本次为同构,异构价值未体现"。
6. 候选集写进 PROGRESS 的 `selected`(冒烟后更新为幸存者),勾 `detect`。

## 第 2 步:冒烟预检(SELECTED 每家 ≤60s)

1. 备两个固定文件(一轮一次;第二条 printf 的 `<cwd>` 代入实际绝对路径、正斜杠):
```
mkdir -p <cwd>/.xcheck
printf '西瓜47' > <cwd>/.xcheck/smoke.txt
printf '读文件 <cwd>/.xcheck/smoke.txt(绝对路径、正斜杠),原样回复文件里的内容,不要加别的字。\n' > <cwd>/.xcheck/smoke-prompt.txt
```
2. 对 SELECTED 每家,主会话**前台**跑(阻塞 ≤~75s,远在前台 600s 上限内):
```
bash ~/.claude/skills/xcheck/lib/run-agent.sh <name> <cwd>/.xcheck/smoke-prompt.txt --timeout 60
```
3. 判定(产物落 `.xcheck/` 根):`.xcheck/<name>.exitcode` 为 **0** 且 `.xcheck/<name>.raw.stdout` 含 `西瓜47` → 可用(CLI 活性 ✓ + 读文件能力 ✓ + 传参机制 ✓)。**其它**(124 超时;65/66/67 脚本层故障;非零 CLI 码 = 401 欠费/未登录/损坏;exit 0 但没有 `西瓜47` = 非交互读不了文件)→ 剔除,告知用户"<name> 预检失败:<exitcode + run.log/stderr 末行>,本轮跳过",落 `<cwd>/.xcheck/<name>.failed.md`。
4. 剔除后 <2 家 → 按第 1 步同款话术停。**幸存者 = 最终 SELECTED**,更新 PROGRESS 的 `selected`,勾 `smoke`。

> 冒烟必须带读文件、必须走 run-agent.sh(与实跑同机制):第 3 步起方案全文靠 agent 自己读文件,读不了文件的家整轮只能产空评,必须在 fan-out 前拦下;预检与实跑同机制才闭合"预检绿 ≠ 实跑绿"盲区(2026-08-15 pi 401 实证)。

## 第 3 步:备料 + 并行派发

### 3.1 内容层落盘(两层分离,全文绝不进 prompt)

复用已有 ts 目录,以下文件全进 `.xcheck/<ts>/`(已 gitignore):

| 内容 | 文件 | 怎么落 |
|---|---|---|
| 方案全文(review) | `proposal.md` | `$ARGUMENTS` 是文件路径 → Bash `cp` 成快照(内容零 token 过主会话);贴文/摄入产物 → 主会话 Write 一次 |
| 问题全文(diag) | `input.md` | 同上 |
| 背景(可选,两 mode 共用) | `context.md` | 用户额外上下文/摄入事实清单/零往返摘录 → Write;没有不建 |

**source 判定**(写进 PROGRESS):输入是文件路径 → 记其绝对路径;贴文/固化文本 → `inline`。

> 落快照而非直读原文件:原文件可能评审中途被改,快照固定本轮对象、留审计底。
> 为什么拆两层:全文内联进 prompt,arg 模式撞 **Windows 32767 字符命令行上限**;全文 Read 进主会话再 Write 烧双倍 token。拆开后指令层恒 ≤2KB,文件输入不过主会话。

### 3.2 指令层落盘

- **diag** → 读 `~/.claude/skills/xcheck/prompts/diag.md`,`{{INPUT_PATH}}` 替换成 `input.md` 的**绝对路径**;有 `context.md` 就填 `{{CONTEXT_PATH}}`,没有把【上下文】块整块删掉。
- **review** → 读 `~/.claude/skills/xcheck/prompts/review.md`,`{{PROPOSAL_PATH}}` / `{{CONTEXT_PATH}}` 同规则。
- 填的路径一律**绝对路径 + 正斜杠**(`C:/...`),写到 `<cwd>/.xcheck/<ts>/prompt.txt`。

> **固化 proposal 的自代入陷阱**:proposal 正文别写会让被评 agent 自代入的背景(点名 agent、写"异构评审"等触发词),历史上下文用**中性陈述**("本方案曾有一个 X 缺陷,已通过 Y 解决"),否则被评 agent 可能把自己当成"该跑评审流程的人"(实测触发过权限弹窗失败)。

### 3.3 一条消息并发派 |SELECTED| 个 subagent

**在一条消息里**同时开出全部 Agent 工具调用并行跑(不要串行 await)。每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的**全文** + 末尾追加:

```
AGENT_NAME = <name>
PROMPT_FILE = <cwd>/.xcheck/<ts>/prompt.txt   # 绝对路径;正反斜杠皆可,run-agent.sh 自动转正斜杠
RESULT_SHAPE = <diag 结构(根因/证据/置信度/建议) | review 结构(裁决/逐条问题/理由)>
```

- subagent 用**便宜模型**(haiku/sonnet)——它只是搬运工。
- 搬运工第 1 步必须 `run_in_background: true` 后台启动 run-agent.sh,并**在本回合内立即阻塞等待**:前台直等会被 600s 上限掐断、结论永久丢失(2026-08-14 codex 事故);停回合"等通知再来"则搬运永不发生(2026-08-31 实证)。详见 carrier 文档。
- 全部派出后勾 `fanout`。

## 第 4 步:收齐落盘

等所有 subagent 完成(并行跑,等齐)。每个返回两段(`## <name> 原始输出` + `## <name> 结构化结论`)或超时/失败行,逐个拆开落盘 `.xcheck/<ts>/`:

- `<name>.raw.out` —— 原始 CLI 输出(原样,不洗 ANSI、不删 codex 噪声,留底核查)。
- `<name>.summary.md` —— 结构化结论。
- 失败/超时:另写 `<name>.failed.md` 记一行(原因 + 退出码 + stderr 摘要)。

**不要在这一步做综合判断**。完成后勾 `collect`。

## 第 5 步:汇总(主会话)

- **diag** → 读 `~/.claude/skills/xcheck/prompts/synthesize-diag.md`,`{{ALL_CONCLUSIONS}}` 替换成各家 `.summary.md` 内容拼接,按模板输出综合,写 `<cwd>/.xcheck/<ts>/SUMMARY.md`。
- **review** → 读 `~/.claude/skills/xcheck/prompts/synthesize-review.md`(紧凑头版),`{{ALL_REVIEWS}}` 同上,输出**紧凑头**(各家裁决一览一行 + 总判一两句 + 返回/失败/同构标注)写 SUMMARY.md。**共识/分歧长文不再输出**——逐条细节交给第 6 步三分类。

完成后勾 `synthesize`。

## 第 6 步:三分类

1. 读 `<ts>/` 下**所有** `.summary.md`(**只读 summary,不读 raw.out**);只有 failed/无 summary 的家跳过。
2. 每家"问题/建议"逐条拆出、标来源(如 `[codex] 这里用了 localStorage 存 token`);LGTM 家不贡献条目,不强行补条。
3. 读 `~/.claude/skills/xcheck/prompts/triage.md`,`{{ALL_FEEDBACK}}` = 拆条拼接,按模板把每条归三类(兜底:拿不准往更不可信兜,1↔2 归 2、2↔3 归 3、设计不出实验降 3)。
4. 分级结果**追加**写 SUMMARY.md(三个区块,空类留占位;三类全空输出一行"本轮无可分级反馈")。条目重复(两家说本质相同)各自保留、各标来源,不合并。
5. **分支**:
   - **diag 到此为止**:呈现 SUMMARY + 收尾句(第 9 步那句),PROGRESS 终态记 `完成(diag)`,链结束。
   - **review 且 ①+② 均空**:SUMMARY 补一行"无可验证问题,无需修订",终态记 `无需修订`,呈现 + 收尾句,链结束。
   - 否则勾 `triage`,进第 7 步。

## 第 7 步:查证①(自动,只读,不问)

对象:SUMMARY 第一类的**每条**。**你(主会话)逐条查**:只读该条"判据"直指的文件/配置/文档,**不展开探索**;条目 >10 可分批派 subagent(便宜模型,只回传证据原文,你裁决)。每条三值,附一行证据(文件:行号,或引文):

- **✅ 证实**(反馈属实)/ **❌ 证伪**(不成立,写明实际是什么)/ **❓ 查无实据**(判据指向处查不到)。

结果并入 SUMMARY ①区块:每条下追加一行 `判定:✅ 证实 —— 证据:src/foo.ts:42`。第一类为空 → SUMMARY 记"无",直接进第 8 步。完成后勾 `verify`。

## 第 8 步:实验②(自动,沙箱,不问)

对象:SUMMARY 第二类的每条(第 6 步已带【验证目的/方法/预期】)。逐条按其【方法】执行:

- **允许**:写临时验证文件(一律 `<cwd>/.xcheck/<ts>/exp/`,留底不删)+ 跑本地测试 / benchmark / 探测命令;单条**超时 300 秒**(Bash 工具 `timeout: 300000`),到点即判"无定论"。
- **禁止(铁律)**:改业务代码、联网外呼、部署。
- 每条三值:**成立 / 不成立 / 无定论**(执行失败/超时/环境不满足 → 无定论,记原因,**不阻塞其他条**)。

结果并入 SUMMARY ②区块:每条下追加一行 `结果:成立 —— exp/e1-x.js,输出摘要:…`。第二类为空 → SUMMARY 记"无"。完成后勾 `experiments`。

## 第 9 步:交付 + 停点

1. 组装**必改项** = ①✅ 证实 + ②实验成立的条目编号,追加 SUMMARY 末段:
   `## 必改项 = ①✅ + ②成立:#1、#3、#5`(空则写 `无`)。勾 `deliverable`。
2. **呈现 SUMMARY 全文**,并原样输出:

   > **以上是建议,共识 ≠ 正确,最终你拍板。**

3. **停点一问**:
   - 必改项为空 → **不问**,终态 `无需修订`,链结束。
   - 否则 AskUserQuestion(单问):"**要起草修订版并自动复审吗?**"
     - `要 —— 针对必改项写修订版(新文件,原稿不动),自动重跑一轮评审`
     - `不要 —— 到此结束` → 终态 `无需修订`,链结束。

## 第 10 步:修订 + 复审(停点答"要")

1. **主会话亲写**修订版(你持有全量证据:各家反馈 + 查证 + 实验结果,不 fan-out):
   - PROGRESS 的 `source` 是文件路径 → 原文件**同目录**写 `<原名>.rev<m>.md`(m = round + 1)。
   - `source = inline` → 写 `<cwd>/.xcheck/<ts>/proposal.rev<m>.md`。
   - **原稿一律不动**;diff(原稿 vs 修订版)写入对话呈现。原稿被手改过(diff 对不上)→ 提示用户,以**当前文件**为修订基线,rev 序号顺延。
   - 修订版正文遵守 3.1 自代入陷阱纪律(中性陈述,不点名 agent)。
2. **建复审环**:新 `<ts2>/` 目录 + 新 PROGRESS.md(`mode=review`、`prev=<当前ts>`、`round=m`、`source=<rev 文件绝对路径>`、`selected=<旧环 selected ∩ 当前 INSTALLED>`;`OVERRIDE_AGENTS` 若有则直接用它)。当前环勾 `gate`。
3. **自动复审**:当前 ts 切到 `<ts2>`,从第 1 步重跑到第 9 步——detect/冒烟照跑、PROGRESS 照勾(新环从空勾起)。复审环 selected 有 agent 已卸载 → 用交集 + 注明,不弹窗。
4. 新一轮到第 9 步:
   - ①+② 均空 → 终态 `收敛(m 轮修订)`,链结束。
   - 非空且 m < 2 → 同问(停点一问)再一轮。
   - **m = 2 仍非空** → 停,报告"**建议推倒重来**:两轮修订后仍存在 N 个可验证问题,疑方案根基缺陷",终态 `推倒重来`。

## 终态收尾(任一终态)

1. PROGRESS.md `## 终态` 段写终态值:`收敛(N 轮修订)` / `推倒重来` / `无需修订` / `用户中止` / `完成(diag)`。
2. 向用户呈现:终态、修订版路径(若有)、`.xcheck/<ts>/` 产物位置。

## PROGRESS.md 格式

```markdown
# PROGRESS · <ts>
mode = review                 # diag | review
selected = codex, kimi        # 冒烟后幸存的最终选集(冒烟前先记候选集)
source = C:/…/xxx.md          # 原方案绝对路径 | inline
round = 0                     # 修订轮次;复审环从 1 起
prev = -                      # 复审链上一环 ts;首轮 -

## 阶段(完成即打勾)
- [x] intake                  # 跳过摄入也算完成
- [x] detect                  # 含选集判定
- [x] smoke
- [x] fanout
- [x] collect
- [x] synthesize
- [x] triage
- [ ] verify
- [ ] experiments
- [ ] deliverable
- [ ] gate                    # 打勾时机:停点已答且(答"不要"链已终态 | 答"要"修订已落盘+复审环已建)

## 终态
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户中止 | 完成(diag))
```

**恢复语义**:终态非空 = 链完成,永不续跑;终态空 + 有未勾阶段 = 未完成,可从第一个未勾阶段续(壳检测、用户确认)。旧版产物(有 run.md 无 PROGRESS.md)不算未完成,静默忽略。

## 边界与异常

| 异常 | 处理 |
|---|---|
| 某家 subagent 超时/失败 | 照落 failed.md,链继续;SUMMARY 头部注明"本轮 <name> 未返回,综合基于其余 N 家" |
| 冒烟后 <2 家 | 停(第 1 步话术),不硬跑单家 |
| 实验失败/超时/环境不满足 | 该条"无定论",不阻塞其他条 |
| 停点处用户打断/不答 | PROGRESS 停在 gate(终态空)→ 下次重敲 /xcheck 弹窗 0 可续(重问) |
| 修订写一半崩 | 旧环 gate 未勾 → 恢复时重问停点;rev 文件已存在 → 提示用户续用或重写 |
| 全链中途崩 | 已勾阶段成果在盘;重敲 /xcheck → 续跑,不丢盲评结果 |
| 用户对话里要换 agent 集 | 未派发 → 回第 1 步重定;已派发 → 本轮照跑完,下轮用 `--agents` |
| 旧版 .xcheck 产物 | 无 PROGRESS.md → 静默忽略,不算未完成 |

## 铁律(全套,不打折扣)

1. **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合/查证/裁决只在主会话。
2. **进度只认盘**:阶段完成即勾 PROGRESS;恢复不依赖会话记忆。
3. **停点纪律**:除壳的续跑确认、第 0 步摄入确认、第 9 步停点一问外,全链不问、不停、不等批准。
4. 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,**原稿永不动**;绝不自动改代码/自动合并/自动"通过"。
5. **至少 1 个非 claude**;同构只标注不拦。
6. subagent 用便宜模型、一条消息并行派出;主会话用强模型做综合。
7. 成败看**退出码**(exitcode 文件),不看输出文本里有没有 "error";codex 的 MCP/banner/hook 噪声 ≠ 失败。
8. 产物全部落盘 `.xcheck/<ts>/`(已 gitignore,不 commit)。
````

- [ ] **Step 2: 验证**

Run:
```bash
grep -c '^## ' xcheck/lib/flow.md && grep -n 'PROGRESS\|恢复模式\|停点' xcheck/lib/flow.md | wc -l && grep -n 'run.md' xcheck/lib/flow.md
```
Expected: 二级标题 15 个(恢复模式/第 0~10 步/终态收尾/PROGRESS 格式/边界/铁律——按最终文件数,允许 ±1,人工核对顺序无缺);PROGRESS 相关命中 ≥15;`run.md` **仅出现在"旧版产物"语境**(不计 PROGRESS 格式段),不得再有"落 run.md"指令。

- [ ] **Step 3: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): rewrite flow.md — single-gate auto-chain brain

吸收 close-flow C0~C5 为第 7~10 步(查证①/实验②自动执行、停点一问、
修订+复审自动接续≤2轮);新增恢复模式与 PROGRESS.md(进度只认盘);
选集简化为 --agents > default_agents > 报错(删分支A多选+表单纪律);
汇总改紧凑头;run.md 废止。实现 spec 2026-09-16 §4~§7。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 重写 `prompts/synthesize-review.md` + 删 `lib/close-flow.md`

**Files:**
- Modify(整体替换): `C:\WorkSpace\agent\xcheck\xcheck\prompts\synthesize-review.md`
- Delete: `C:\WorkSpace\agent\xcheck\xcheck\lib\close-flow.md`

**Interfaces:**
- Produces:SUMMARY.md 的紧凑头(各家裁决一览 + 总判;后续三分类/验证结果接在其下)。

- [ ] **Step 1: Write 全文替换 synthesize-review.md**

````markdown
你是综合判断者。下面是 N 个**不同** AI agent 对同一个方案各自独立给出的评审(盲评,互不可见)。

【各家评审】
{{ALL_REVIEWS}}

请只输出**紧凑头**(总共 ≤6 行;后续流程会把三分类与验证结果接在下面,长篇分析不要):

1. **各家裁决一览** —— 一行:每家 AGREE / SUGGEST_CHANGES / DISAGREE(如 `codex=SUGGEST_CHANGES · kimi=AGREE`);有未返回/失败的家也在此行注明。
2. **总判** —— 一两句:方案方向是否成立、最要紧的信号是什么(如"两家焦点都集中在 X,疑点集中值得优先处理";或"意见分散,无共识焦点")。

重要提醒:**共识不等于正确**——多家都点头不代表对。保留分歧,最终由**用户拍板**;不要替用户做"通过/合并"的决定。
````

- [ ] **Step 2: 删除 close-flow.md**

Run:
```bash
git rm xcheck/lib/close-flow.md
```
Expected: `removed mode` 输出;`ls xcheck/lib/` 不再有 close-flow.md。

- [ ] **Step 3: 验证**

Run:
```bash
grep -rn 'close-flow' xcheck/ xcheck-setup/ || echo "NO-REF"
```
Expected: `NO-REF`(全仓库 skill 源无残留引用;docs/ 的历史 spec/plan 是文档,不算)。

- [ ] **Step 4: Commit**

```bash
git add xcheck/prompts/synthesize-review.md
git commit -m "feat(xcheck): compact synthesis header + drop close-flow.md

review 汇总从共识/分歧长文改为紧凑头(裁决一览+总判 ≤6 行),逐条细节
交给三分类环节;close-flow.md 编排并入 flow.md 第 7~10 步,文件删除。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 删三个薄壳目录 + 一致性小修

**Files:**
- Delete: `xcheck-diag/`(整目录)、`xcheck-review/`(整目录)、`xcheck-close/`(整目录)
- Modify: `xcheck-setup/SKILL.md`(模式 D 两处旧话术)
- Modify: `xcheck/agents.toml`(仅头注释;**不 git add**——该文件含用户未提交的 codex 沙箱修改)

- [ ] **Step 1: 删目录**

Run:
```bash
git rm -r xcheck-diag xcheck-review xcheck-close
```
Expected: 三个目录的 SKILL.md 均 removed;`ls` 确认仓库根只剩 `xcheck/` 与 `xcheck-setup/` 两个 skill 目录。

- [ ] **Step 2: Edit xcheck-setup/SKILL.md 模式 D 首段**

`old_string`(唯一):
```
设了默认集之后,`/xcheck`(及 diag/review)会**直接拿这组跑,跳过每次的勾选弹窗**;没设就回退到每次弹多选。详见 `~/.claude/skills/xcheck/lib/flow.md` 第 2 步。优先级:`--agents` 临时参数 > `default_agents` > 每次弹窗。
```

`new_string`:
```
设了默认集之后,`/xcheck` 会**直接拿这组跑**;没设则 `/xcheck` **报错停住**,提示先设默认集(不再有每次勾选弹窗)。详见 `~/.claude/skills/xcheck/lib/flow.md` 第 1 步。优先级:`--agents` 临时参数 > `default_agents` > 报错提示先设默认集。
```

- [ ] **Step 3: Edit xcheck-setup/SKILL.md 模式 D 无参视图话术**

`old_string`(唯一):
```
- **`/xcheck-setup default`**(无参)→ 读 `agents.toml` 的 `[defaults].default_agents`。有值就表格/列表呈现当前默认集;没设(字段缺失/空)就提示"未设默认,每次运行会弹多选"。
```

`new_string`:
```
- **`/xcheck-setup default`**(无参)→ 读 `agents.toml` 的 `[defaults].default_agents`。有值就表格/列表呈现当前默认集;没设(字段缺失/空)就提示"未设默认,`/xcheck` 会报错要求先设默认集"。
```

- [ ] **Step 4: Edit agents.toml 头注释(不 commit)**

`old_string`(唯一,文件头注释块内):
```
# 字段缺失/空 = 未设默认 → 每次运行弹多选(出厂默认)。
```

`new_string`:
```
# 字段缺失/空 = 未设默认 → /xcheck 报错停住,提示先设默认集(出厂默认)。
```

- [ ] **Step 5: 验证**

Run:
```bash
grep -rn '弹多选\|多选弹窗\|勾选弹窗' xcheck/ xcheck-setup/ | grep -v '不再有' | grep -v '报错要求' || echo "CLEAN"
ls
```
Expected: `CLEAN`(旧弹窗话术清零);仓库根无 xcheck-diag/xcheck-review/xcheck-close。

- [ ] **Step 6: Commit(setup 两个文件;agents.toml 不加)**

```bash
git add xcheck-setup/SKILL.md
git commit -m "refactor(xcheck): drop 3 thin shells; setup mode-D wording follows new selection rule

xcheck-diag/xcheck-review/xcheck-close 三壳删除(路由并入 /xcheck,闭环
并入 flow.md 第 7~10 步);xcheck-setup 模式 D 文案同步"未设默认→报错"。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 重写 `README.md`

**Files:**
- Modify(整体替换): `C:\WorkSpace\agent\xcheck\README.md`

- [ ] **Step 1: Write 全文替换 README.md**

````markdown
# xcheck

**One trigger → blind cross-review by multiple local AI agents → auto-verification → a verified three-tier issue list. You decide at the single gate.**

**一次触发 → 本地多个异构 AI agent 盲评交叉验证 → 自动查证与实验 → 已验证三分类清单。停点一问,你拍板。**

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

xcheck is a set of global [Claude Code](https://code.claude.com/) skills. You hand it a design / proposal / code change (or a bug), and it runs **one automatic chain**:

1. **(Only if your input isn't self-contained)** solidifies context — distills a neutral, self-contained proposal plus a verbatim list of facts you stated, shows you both for approval before anything is fanned out. Self-contained inputs skip this but still silently pull related user quotes into a context file.
2. **Detects** which local AI-agent CLIs you have (`claude`, `codex`, `opencode`, `pi`, `kimi`, …), then **smoke-tests** each candidate (≤60s: read a file and echo it back) — dead CLIs are dropped **before** fan-out.
3. **Fans them out in parallel**, each in its own isolated subagent — **blind evaluation**, agents can't see each other. Agents read the proposal from **content files**; the prompt itself is a ≤2KB instruction layer.
4. **Synthesizes a compact header** (per-agent verdicts + one-line overall) and **triages** every feedback item into three verifiability tiers: ① directly verifiable, ② experiment-verifiable, ③ suspect / reference-only.
5. **Auto-verifies, no questions asked**: tier-① items are checked read-only against your code (✅ / ❌ / ❓ with evidence); tier-② experiments run automatically in a sandbox (temp files under `.xcheck/<ts>/exp/`, no business-code edits, no network, no deploy; per-item 300s timeout).
6. **Single gate**: presents the **verified three-tier list** (must-fix = ① confirmed + ② held) and asks exactly one question — *"draft a revision and re-review?"* Yes → writes `<name>.rev1.md` (**original untouched**) and auto re-reviews (≤2 rounds, then "recommend starting over"). No → done.

**Progress lives on disk only** (`PROGRESS.md`, per-stage) — crash mid-chain, re-trigger `/xcheck`, confirm "resume", and it continues from the first unfinished stage. No session memory involved.

The whole point is **heterogeneity**: if every "second opinion" comes from the same Claude you're already talking to, you learn nothing. xcheck insists on at least one non-`claude` agent.

## Commands

Both are **manual slash commands** (`disable-model-invocation: true`).

| Command | What it does |
|---|---|
| `/xcheck [--agents a,b,c] <text>` | **The whole chain** — auto-routes problem vs proposal, blind fan-out, triage, verification, single gate. Bare `/xcheck` = resume check for an unfinished chain. |
| `/xcheck-setup` | Detect / verify / register agent CLIs. Subcommands: `add <name>`, `timeout [N \| <agent> N]`, `default [<n1>,<n2>,…]`. |

Agent selection: `--agents` flag > `default_agents` (set via `/xcheck-setup default`) > hard error telling you to set a default. No popups.

## How it works

```
/xcheck <text>
   │  unfinished chain on disk? → ask: resume (PROGRESS.md, stage-granular) or start new
   │  route: problem → diag · proposal → review · can't tell → ask
   │
   ├ diag ──→ smoke → fan-out → collect → synthesize + triage → present ("you decide") → done
   │
   └ review → intake (only if non-self-contained: distill + your approval)
        → smoke → fan-out (blind, parallel) → collect → compact header → triage
        → verify ① (read-only, auto) → experiments ② (sandbox, auto)
        ══ SINGLE GATE: verified three-tier list + one question ══
              │No                          │Yes
              ▼                            ▼
            done                write .rev1.md (original untouched) → auto re-review
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
│   ├── context-intake.md        # step-0 context intake / proposal solidification
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
- **Human at the single gate** — output is always "suggestions"; it never edits code, merges, or approves for you. Experiments stay sandboxed; revisions are always new files, originals untouched.
- **Progress on disk only** — every run leaves a full audit trail under `.xcheck/<ts>/` (prompt, content snapshots, raw outputs, summaries, PROGRESS, SUMMARY); resumable at stage granularity.
- **Cheap carriers, strong synthesizer** — subagents use haiku/sonnet; the main session uses the strong model.

## License

[MIT](LICENSE) © 2026 allanpk716

---

## 中文文档

`xcheck` 是一组全局 [Claude Code](https://code.claude.com/) skill。你给它一个方案/设计/代码改动(或一个 bug),它跑**一条自动链**:

1. **(仅当输入不自包含)**摄入固化——中性自包含 proposal + 你原话的事实清单,两者经你过目后才 fan-out;自包含输入跳过,但仍静默摘相关背景。
2. **检测**本机 AI agent CLI 并逐家**冒烟预检**(≤60s 读文件回显)——坏家在 fan-out 前剔除。
3. **并行派发**,每家一个隔离 subagent——**盲评**,互不可见;agent 自己读**内容文件**,prompt 只是 ≤2KB 指令层。
4. **紧凑头汇总**(各家裁决一行 + 总判一两句)+ **三分类**:①可直接证实 / ②可实验验证 / ③存疑仅参考。
5. **自动验证,不问**:①逐条只读查证(✅/❌/❓ 带证据);②沙箱实验自动跑(临时文件落 `exp/`、禁改业务代码/联网/部署、单条 300s 超时)。
6. **单停点**:呈现**已验证三分类清单**(必改 = ①✅ + ②成立),只问一句——"要起草修订版并自动复审吗?"要 → 写 `<原名>.rev1.md`(**原稿不动**)并自动复审(≤2 轮,超限报"推倒重来");不要 → 结束。

**进度只认盘**(`PROGRESS.md` 阶段粒度)——链中途崩了,重敲 `/xcheck` 确认"续跑",从第一个未完成阶段继续,不依赖任何会话记忆。

核心是**异构**:至少一个非 claude 的 agent,否则就是 Claude 自己审自己。

### 两个命令(手动 slash 命令)

| 命令 | 作用 |
|---|---|
| `/xcheck [--agents a,b,c] <文字>` | **整条链**——自动路由、盲评、三分类、验证、单停点。裸敲 = 查未完成链。 |
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
- **单停点人在环**——输出永远是"建议",绝不替你改代码/合并/通过;实验锁沙箱,修订永远写新文件。
- **进度只认盘**——`.xcheck/<ts>/` 全量留底,阶段粒度可续跑。
- **便宜搬运、强模型汇总**。

### 许可证

[MIT](LICENSE) © 2026 allanpk716
````

- [ ] **Step 2: 验证**

Run:
```bash
grep -c 'xcheck-close\|xcheck-diag\|xcheck-review' README.md || echo "NO-OLD-CMDS"
grep -n 'PROGRESS\|单停点\|SINGLE GATE' README.md | head -8
```
Expected: 旧命令名 0 命中(NO-OLD-CMDS,或仅出现在版本历史语境——本 README 无历史节,应为 0);PROGRESS/单停点/SINGLE GATE 均有命中。

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): sync 0.12.0 — single-gate auto-chain, 2 commands, PROGRESS-on-disk

命令表 5→2;流程图改为单停点自动链;文件树去掉三薄壳与 close-flow,
补 CONTEXT.md 与 ADR-0001。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: CHANGELOG 加 0.12.0

**Files:**
- Modify: `C:\WorkSpace\agent\xcheck\CHANGELOG.md`

- [ ] **Step 1: 在 `## [Unreleased]` 与 `## [0.11.0]` 之间插入**

`old_string`:
```
## [0.11.0] - 2026-08-25
```

`new_string`:
````markdown
## [0.12.0] - 2026-09-16

### Changed / 改进

- **Single-gate auto-chain — `/xcheck` is now one trigger, end to end.** The command surface shrinks 5 → 2 (`/xcheck`, `/xcheck-setup`): `/xcheck-diag` / `/xcheck-review` merged into `/xcheck`'s router, and `/xcheck-close`'s close-loop (C0–C5) is absorbed into the main flow as steps 7–10. A review now runs **automatically** from blind fan-out → triage → tier-① read-only verification (✅/❌/❓ with evidence) → tier-② sandbox experiments (all of them, no per-item approval; 300s per-item timeout → inconclusive) and stops exactly once: the **verified three-tier list** + one question — "draft a revision and re-review?" Yes → main session writes `<name>.rev<m>.md` (original untouched) and auto re-reviews (≤2 rounds, then "recommend starting over"). The old four close gates (experiment multiSelect, per-item adjudication, revision adoption, per-round re-review ask) are gone — human control moved from signing every step to deciding on the final result. Synthesis for review is now a compact header (verdicts + one-line overall) instead of the long consensus/divergence essay. Design: `docs/superpowers/specs/2026-09-16-xcheck-single-gate-autochain-design.md`, decision record: `docs/adr/0001-single-gate-autochain.md`, glossary: `CONTEXT.md`.
- **单停点全自动链——`/xcheck` 一次触发跑到底。** 命令面 5→2(/xcheck、/xcheck-setup):/xcheck-diag、/xcheck-review 并入 /xcheck 路由,/xcheck-close 的闭环(C0~C5)吸收为 flow 第 7~10 步。review 现在**全自动**推进:盲评 → 三分类 → ①类只读查证(✅/❌/❓ 带证据)→ ②类沙箱实验(全跑,不再逐条批准;单条 300s 超时判无定论),只在终点停一次:**已验证三分类清单** + 一问"要起草修订版并自动复审吗?"要 → 主会话写 `<原名>.rev<m>.md`(原稿不动)并自动复审(≤2 轮,超限报"推倒重来")。旧 close 四关卡(实验勾选/逐条拍板/采纳修订/每轮问复审)废除——人的控制权从"每步签字"移到"对最终结果拍板"。review 汇总改紧凑头(裁决一览+总判),不再输出共识/分歧长文。
- **Progress lives on disk only.** Every stage completion ticks `PROGRESS.md` (stage-granular, replaces `run.md`); terminal states: converged / start-over / no-fix-needed / user-aborted / diag-done. Crash mid-chain → re-trigger `/xcheck` → it detects the unfinished run, asks "resume or start new", and continues from the first unticked stage. Machine discovers, human decides. Old-format artifacts (run.md, no PROGRESS.md) are treated as finished and ignored.
- **进度只认盘。** 每阶段完成即勾 `PROGRESS.md`(阶段粒度,取代 run.md);终态:收敛/推倒重来/无需修订/用户中止/完成(diag)。链中途崩 → 重敲 /xcheck → 自动发现未完成链、人工确认"续还是新开"、从第一个未勾阶段续跑。机器发现、人决定。旧版产物(run.md、无 PROGRESS.md)视为已完成,忽略。
- **Selection simplification.** Agent selection is now `--agents` > `default_agents` > hard error telling you to set a default (`/xcheck-setup default`). The interactive multi-select UI and its form-discipline rules are deleted — rare paths error out loudly instead. Missing agents degrade to the intersection with a visible note, no popup.
- **选集简化。** 选集规则:`--agents` > `default_agents` > 报错提示先设默认集。交互式多选 UI 及其表单纪律删除——罕见路径大声报错。缺装降级为交集 + 注明,不弹窗。

### Removed / 移除

- `/xcheck-diag`, `/xcheck-review`, `/xcheck-close` skills and `xcheck/lib/close-flow.md`. diag mode itself is unchanged (ends at synthesis + triage; no verification chain, no gate question) — routed automatically by `/xcheck`.
- /xcheck-diag、/xcheck-review、/xcheck-close 三个 skill 与 `xcheck/lib/close-flow.md` 删除。diag 模式行为不变(止于汇总+三分类;无验证链、无停点问题),由 /xcheck 自动路由。

## [0.11.0] - 2026-08-25
````

- [ ] **Step 2: 验证 + Commit**

Run:
```bash
grep -n '0.12.0' CHANGELOG.md | head -3
```
Expected: 命中新条目。

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): 0.12.0 single-gate auto-chain

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 全量验证 + junction 清理

**Files:** 无仓库改动(junction 在 `~/.claude/skills/`,不入库)。

- [ ] **Step 1: 结构总检**

Run:
```bash
grep -rn 'close-flow\|xcheck-close\|xcheck-diag\|xcheck-review' xcheck/ xcheck-setup/ || echo "NO-REF"
bash xcheck/tests/run-agent.test.sh 2>&1 | tail -5
```
Expected: `NO-REF`(skill 源零残留引用);run-agent 测试全绿(33 断言)。

- [ ] **Step 2: flow.md 步骤完整性人工核对**

Read `xcheck/lib/flow.md`,核对二级标题顺序:恢复模式 → 第 0 步 → 第 1 步(检测+选集)→ 第 2 步(冒烟)→ 第 3 步(备料派发)→ 第 4 步(收齐)→ 第 5 步(汇总)→ 第 6 步(三分类)→ 第 7 步(查证①)→ 第 8 步(实验②)→ 第 9 步(交付+停点)→ 第 10 步(修订+复审)→ 终态收尾 → PROGRESS 格式 → 边界与异常 → 铁律。

- [ ] **Step 3: 删 3 个 junction**

Run:
```bash
cmd //c rmdir "C:\Users\allan716\.claude\skills\xcheck-diag" 2>/dev/null
cmd //c rmdir "C:\Users\allan716\.claude\skills\xcheck-review" 2>/dev/null
cmd //c rmdir "C:\Users\allan716\.claude\skills\xcheck-close" 2>/dev/null
ls ~/.claude/skills/ | grep xcheck
```
Expected: 只剩 `xcheck` 与 `xcheck-setup`(junction 删除用 `cmd /c rmdir`,PowerShell Remove-Item 对 junction 有 bug;目录本体在仓库里已由 git rm 删除)。

- [ ] **Step 4: 端到端行为验证(用户,开新会话)**

> 交互式 skill 无法由 subagent 替跑;由用户在**新会话**验证(Claude Code 可能缓存旧 skill 文件):
> 1. `/xcheck <设计文档路径>` → 全链自动推进,全程零中间交互,停点一问;答"要" → rev1 落盘、原稿不动、自动复审、收敛/推倒重来终态。
> 2. 中途 Ctrl 打断 → 重敲 `/xcheck` → 弹窗 0"续/新开" → 续跑跳过已完成阶段(PROGRESS 勾可查)。
> 3. 裸敲无未完成 → 反问内容;`/xcheck <报错栈>` → diag 止于三分类。
> 4. 临时清掉 default_agents → `/xcheck …` 报错提示 `/xcheck-setup default`。

---

## Self-Review

**1. Spec coverage:**

| Spec 要求 | 实现位置 |
|---|---|
| §3 入口四件(--agents/弹窗0/路由/转派 RESUME_TS) | Task 1 |
| §4 第 0~10 步全链 + 恢复模式 | Task 2 |
| §5 PROGRESS.md 格式 + 恢复语义 + 旧产物忽略 | Task 2(PROGRESS 格式节 + 边界表) |
| §6 SUMMARY 交付物形态(紧凑头+三分类+验证+必改) | Task 2(第 5/9 步)+ Task 3(模板) |
| §7 边界异常 8 项 | Task 2 边界表 |
| §8 改动清单 1~5 | Task 1/2/3/4;6 README;7 CHANGELOG+junction |
| run.md 废止 | Task 2(无落盘指令 + 验证 grep) |
| setup/agents.toml 旧话术一致性 | Task 4 Step 2~4 |
| 测试方式(静态/测试套件/端到端) | Task 7 |

无遗漏。

**2. Placeholder scan:** 无 TBD/TODO;四个全文重写文件(SKILL/flow/synthesize-review/README)完整嵌入;两处 Edit 含精确 old/new;CHANGELOG 全文嵌入。

**3. 一致性:** `MODE`/`OVERRIDE_AGENTS`/`RESUME_TS` 在 Task 1(壳设)与 Task 2(flow 消费)同名;PROGRESS 字段(mode/selected/source/round/prev)在 Task 2 第 1 步(写)、第 10 步(复审环写)、恢复模式(读)、格式节(定义)一致;阶段名(intake/detect/smoke/fanout/collect/synthesize/triage/verify/experiments/deliverable/gate)在格式节与各步"勾 X"一一对应;终态枚举五值在第 6/9/10 步与格式节一致;junction 删除命令与既有安装方式(memory:cmd /c rmdir)一致。

计划可执行。
