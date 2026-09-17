# xcheck 夜链(--night)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 /xcheck 加 `--night` 夜链:无人值守贯通"评审(自动停点决策)→ writing-plans 写计划 → subagent-driven-development 在 worktree 执行",终点 = 本地分支 + 晨报,不 push 不合并。

**Architecture:** 纯 Markdown 指令改动(无脚本代码)。flow.md 加 night 分支与新增第 11 步(夜间接续);SKILL.md 壳加旗标解析与夜链扫描;终态枚举扩为七值(新增 `夜间收工`);新增夜链账本 NIGHT.md(四阶段)与晨报 MORNING.md;五处文档按仓库同步义务对齐。下游两跳通过"调 Skill"指令实现,不在本仓库实现下游技能本体。

**Tech Stack:** Claude Code skill 指令文档(Markdown);bash grep 做结构自检;xcheck/tests/run-agent.test.sh 做回归。

**Spec:** `docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`

## Global Constraints

- **语言与标点**:仓库文档中文为主,术语保留英文原名;标点用全角(`，`是半角逗号禁用——本仓库惯例是 `,` 半角逗号 + 全角括号()`与冒号`:`,照抄现有文件风格,别自创新格式)。
- **行尾 LF**(`.gitattributes` 锁定);不许引入 CRLF。
- **禁改文件**:`xcheck/lib/run-agent.sh`、`xcheck/lib/detect.sh`、`xcheck/agents.toml`、`xcheck/prompts/*`、`xcheck/lib/subagent-carrier.md`、`xcheck/lib/extractor-carrier.md`、`xcheck/lib/context-intake.md`、`xcheck-setup/SKILL.md`。
- **协议同步**:flow.md 步骤编号扩为 0~11;PROGRESS 阶段枚举 11 值**不变**;终态枚举六值 → **七值**(新增 `夜间收工`)。改协议必须同步 SKILL.md / AGENTS.md / docs/artifacts.md / CONTEXT.md / README.md。
- **夜链安全栏同样约束本次实施**:只 commit 到本地分支;**不 push、不打 tag、不开 PR**(v0.17.0 tag 与 push 留给用户早上人工)。
- **提交体例**:每任务一个 commit,conventional 前缀 + 中文主题;提交信息末尾加 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`。
- **向后兼容**:旧 `.xcheck/` 产物(无 PROGRESS.md / 无 NIGHT.md)继续静默忽略;非夜链(`--night` 未敲)行为与 v0.16.0 完全一致。

---

### Task 1: flow.md 评审段 night 化(第 0/9/10 步 + 停点纪律 + PROGRESS 字段 + 边界 + 铁律)

**Files:**
- Modify: `xcheck/lib/flow.md`

**Interfaces:**
- Consumes: 无(首个任务)。
- Produces: 夜链词汇表——`NIGHT_MODE`(壳传入的变量)、PROGRESS 头部字段 `night = on`、终态值 `夜间收工`、留档文件 `night-intake.md`。后续任务引用这些名字,一字不差。

**背景(给零上下文的实施者)**:flow.md 是 /xcheck 技能的编排大脑,主会话模型照它执行。当前它假设用户在场(第 0 步解析确认窗、第 9 步停点一问)。本任务给"用户不在场"的夜链模式加分支规则,但**不动步骤 1~8 的任何机制**。

- [ ] **Step 1: 改头部段——声明 NIGHT_MODE 变量与第 11 步存在**

用 Edit 把 flow.md 第 3 行:

```
主会话(你)执行一条**自动链**:第 0 步(可选摄入)+ 第 1~9 步;停点答"要"才有第 10 步(修订+复审)。壳(xcheck/SKILL.md)已设定:`MODE`(diag | review | auto——auto = 空或含糊输入,由第 0 步解析器落定)、`OVERRIDE_AGENTS`(可选)、`RESUME_TS`(可选 = 恢复模式)。**严格按步骤走,不跳步。**
```

替换为:

```
主会话(你)执行一条**自动链**:第 0 步(可选摄入)+ 第 1~9 步;停点答"要"才有第 10 步(修订+复审);夜链(NIGHT_MODE = 1)评审终态落定后接第 11 步(夜间接续)。壳(xcheck/SKILL.md)已设定:`MODE`(diag | review | auto——auto = 空或含糊输入,由第 0 步解析器落定)、`OVERRIDE_AGENTS`(可选)、`RESUME_TS`(可选 = 恢复模式)、`NIGHT_MODE`(可选 = 1,夜链:第 0 步不弹确认、第 9 步停点自动决策、评审终态后接第 11 步下游实施)。**严格按步骤走,不跳步。**
```

- [ ] **Step 2: 停点纪律段加 night 例外**

在停点纪律段(以"**停点纪律(铁律)**:全链只有三处开口等用户"开头、以"**其余一切(检测/冒烟/派发/汇总/三分类/查证/实验)自动推进,不问、不停、不等批准。**"结尾)的结尾句后追加一句:

```
 night 模式(NIGHT_MODE = 1)下三处开口全部自动过,整链零开口:①壳自动续最新未完成链,不弹窗;②第 0 步自动采纳解析器最优推断(落 night-intake.md 留档,见第 0 步);③第 9 步停点按夜链决策表自动拍板(见第 9 步)。
```

- [ ] **Step 3: 恢复模式加第 6 条(夜链补记)**

在"## 恢复模式"清单第 5 条("5. 恢复不再弹"续还是新开"(壳已问过)。")之后追加:

```
6. `NIGHT_MODE = 1` 而本环 PROGRESS 头部没有 `night = on` → 补记 `night = on`:用户敲 `--night` 续跑 = 本环起按夜链规则走(第 9 步自动决策、终态后接第 11 步)。
```

- [ ] **Step 4: 第 0 步加 night 分支(确认窗不弹)**

在"## 第 0 步"下第一个 bullet(以"- **MODE = auto**(壳没定:输入为空或含糊)→ 按 `~/.claude/skills/xcheck/lib/context-intake.md` 第 0.0 步**对象解析器**执行"开头)与第二个 bullet(以"- **MODE 已定**(自包含输入)"开头)之间插入:

```
- **NIGHT_MODE = 1**(夜链,确认窗不弹):解析器照跑,但**不弹确认窗**——采用阶梯最优推断直接落定;把"本应过目的解析结果"(对象+模式+背景原话;讨论型含固化稿全文)落 `<ts>/night-intake.md`,对话播报一行"夜间模式:已按推断锁定评审对象(<一句话>),留档 .xcheck/<ts>/night-intake.md,明早可改"。阶梯落到"反问"档(对话完全无线索)→ **停链 + 推通知**("夜间解析不出评审对象,链没跑,明早补一句对象描述再敲 /xcheck --night"),夜里绝不瞎猜对象。
```

- [ ] **Step 5: 第 9 步加第 4 点(night 自动决策表)**

在"## 第 9 步:交付 + 停点"的第 3 点全部子 bullet(以"- **round = 2 且必改非空** → **不自动判推倒**"开头的块是第 3 点最后一个子块)之后、第 10 步标题之前插入:

```
4. **night 模式(NIGHT_MODE = 1)自动决策,不问**——第 3 点的 AskUserQuestion 全部不弹,按下表自动拍板,每次播报一行("夜间模式自动选了 X:<一句人话理由>"),gate 勾选照常:
   - 必改空 → 与第 3 点"不问"分支一致(终态 无需修订 / 收敛(m 轮修订))。
   - 必改非空且 round 0 → 自动选**修订再评**,进第 10 步(夜里时间便宜,已查实的真问题先修掉;修订只写新文件,原稿不动)。
   - 必改非空且 round ≥ 1 → 自动选**带清单进开发**,终态记 `夜间收工`(不记"用户不修"——用户没在场,账要记实;语义同:带着已验证清单交下游)。
   - 防御:必改非空且走到 m=2 局面(正常到不了,round 1 就自动收工)→ 自动选**按现状收工**,终态 `夜间收工`。
```

- [ ] **Step 6: 第 10 步第 2 条加夜链继承**

把第 10 步第 2 条:

```
2. **建复审环**:新 `<ts2>/` 目录 + 新 PROGRESS.md(`mode=review`、`prev=<当前ts>`、`round=m`、`source=<rev 文件绝对路径>`、`selected=<旧环 selected ∩ 当前 INSTALLED>`;`OVERRIDE_AGENTS` 若有则直接用它)。当前环勾 `gate`。
```

替换为:

```
2. **建复审环**:新 `<ts2>/` 目录 + 新 PROGRESS.md(`mode=review`、`prev=<当前ts>`、`round=m`、`source=<rev 文件绝对路径>`、`selected=<旧环 selected ∩ 当前 INSTALLED>`;`OVERRIDE_AGENTS` 若有则直接用它;当前环是夜链(NIGHT_MODE = 1)则新环头部继承 `night = on`)。当前环勾 `gate`。
```

- [ ] **Step 7: 终态收尾终态值表加"夜间收工"**

把终态收尾第 2 条中的:

```
`收敛(N 轮修订)` / `推倒重来`(**仅当用户在 m=2 三选停点确认**) / `无需修订`(round 0 的 ①+②真空/必改空) / `用户不修`(必改非空,停点答"不要"或 m=2 答"按现状收工") / `用户中止` / `完成(diag)`
```

替换为:

```
`收敛(N 轮修订)` / `推倒重来`(**仅当用户在 m=2 三选停点确认**) / `无需修订`(round 0 的 ①+②真空/必改空) / `用户不修`(必改非空,停点答"不要"或 m=2 答"按现状收工") / `夜间收工`(夜链自动决策的带清单/按现状收工,round ≥ 1 必改非空或防御性 m=2;语义同用户不修,但用户没在场) / `用户中止` / `完成(diag)`
```

- [ ] **Step 8: PROGRESS.md 格式段加 night 字段与终态值**

在"## PROGRESS.md 格式"代码块中 `smoke_cfg = <sha256>` 行之后加一行(保持注释对齐风格):

```
night = on                  # 仅夜链(--night)写;非夜链无此行(0.17.0)
```

并把同一代码块末尾的:

```
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户不修 | 用户中止 | 完成(diag))
```

替换为:

```
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户不修 | 夜间收工 | 用户中止 | 完成(diag))
```

- [ ] **Step 9: 恢复语义段加夜链例外**

把:

```
**恢复语义**:终态非空 = 链完成,永不续跑;终态空 + 有未勾阶段 = 未完成,可从第一个未勾阶段续(壳检测、用户确认)。旧版产物(有 run.md 无 PROGRESS.md)不算未完成,静默忽略。
```

替换为:

```
**恢复语义**:终态非空 = 评审段完成(夜链例外:PROGRESS 终态非空但 `<ts>/NIGHT.md` 的 `finish` 未勾 = **夜链未完成**,壳的夜链扫描接管,评审段不重跑、直接按第 11 步续);终态空 + 有未勾阶段 = 未完成,可从第一个未勾阶段续(壳检测、用户确认)。旧版产物(有 run.md 无 PROGRESS.md,或无 NIGHT.md)不算未完成,静默忽略。
```

- [ ] **Step 10: 边界与异常表加三行**

在"## 边界与异常"表格末尾("| 旧版 .xcheck 产物 | 无 PROGRESS.md → 静默忽略,不算未完成 |"之后)追加:

```
| 夜间解析不出对象(阶梯落"反问"档) | 停链 + 推通知;夜里绝不瞎猜对象 |
| 夜链任何一步失败(计划崩/执行崩/通知崩) | 推通知(停在哪、早上怎么续);NIGHT.md 停在当前阶段,`/xcheck --night` 可续;通知失败不阻塞,晨报兜底 |
| 早上裸敲 /xcheck(无 --night)遇未完成夜链 | 弹窗 0 多一项"续跑夜链";不自动续(人在场,要确认) |
```

- [ ] **Step 11: 铁律加第 9 条(夜链安全栏)**

在"## 铁律(全套,不打折扣)"清单第 8 条("8. 产物全部落盘 `.xcheck/<ts>/`(已 gitignore,不 commit)。")之后追加:

```
9. **夜链安全栏(NIGHT_MODE = 1)**:第 11 步下游执行的一切代码改动只发生在 worktree;**不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区**;通知失败不阻塞,晨报(MORNING.md)兜底;夜间会话须用免弹窗权限模式跑(bypassPermissions 或预放行常用命令,否则子代理权限弹窗挂整夜)。
```

- [ ] **Step 12: 结构自检**

Run: `cd <repo根> && grep -c "NIGHT_MODE" xcheck/lib/flow.md && grep -c "夜间收工" xcheck/lib/flow.md && grep -c "night-intake" xcheck/lib/flow.md && grep -c "night = on" xcheck/lib/flow.md`
Expected: 依次 **≥ 6、≥ 4、≥ 1、≥ 2**(Task 2 会再加)。
Run: `grep -n "推倒重来" xcheck/lib/flow.md | head -5`
Expected: 第 9/10 步的推倒语义原样未被改动(只是被 night 表引用)。

- [ ] **Step 13: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): 夜链评审段——第0/9/10步night分支、夜间收工终态、PROGRESS night字段

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: flow.md 第 11 步(夜间接续)+ NIGHT.md 格式

**Files:**
- Modify: `xcheck/lib/flow.md`

**Interfaces:**
- Consumes: Task 1 的 `NIGHT_MODE`、`夜间收工` 终态、`night = on` 字段。
- Produces: `## 第 11 步:夜间接续` 段(下游两跳的调用规则:writing-plans → worktree → subagent-driven-development → MORNING.md);`## NIGHT.md 格式(夜链专用)` 段(四阶段 `review/plan/sdd/finish`、`finish` 未勾 = 夜链未完成)。Task 3 的壳扫描、Task 4/5/6 的文档同步全部引用这两个段名与阶段枚举。

**背景**:第 11 步是夜链独有的下游接续段,插在第 10 步与"## 终态收尾"之间;NIGHT.md 格式段插在 PROGRESS.md 格式段(含其后的恢复语义段)与"## 边界与异常"之间。

- [ ] **Step 1: 插入第 11 步整段**

在"## 终态收尾(任一终态)"标题**之前**插入:

````
## 第 11 步:夜间接续(NIGHT_MODE = 1 且评审段终态落定后)

> 夜链专属:把评审交付物接进下游"写实施计划 → 子代理执行"。非夜链(普通 /xcheck)永远不进这一步。夜链安全栏(铁律 9)在本步全程生效。

1. **建账**:复用评审 ts 目录(复审链取最新环的 ts),建 `<cwd>/.xcheck/<ts>/NIGHT.md`(格式见文末),勾 `review`,头部记评审终态与 spec 路径。
2. **终态分流**:
   - 终态为 `无需修订` / `收敛(*)` / `夜间收工` → 接续(下一条)。
   - 终态为 `推倒重来` / `用户中止` / `完成(diag)` → **不接下游**:NIGHT 记终态与 `note = 未接下游(<原因>)`,直接勾 `finish`,推通知("评审判定方向性错误/链被中止,没写代码,明细在 .xcheck/<ts>/SUMMARY.md"),夜链结束。推倒重来是人的决定,夜里绝不自动重新设计。
3. **定 spec**:spec = 最新 `<原名>.rev<m>.md`(取最大 m)> PROGRESS `source` 的文件路径 > `<ts>/proposal.md`(inline / 讨论型固化稿)。文档文末已带评审附录(主交付物),spec 连附录一起交给下游。
4. **写计划**:推通知("评审终态:<人话一句>。开始写实施计划。")→ 调 Skill `superpowers:writing-plans`,spec = 上一步定的路径;额外要求(随调用传入):评审附录里的③存疑条目与②无定论条目要进计划的 Global Constraints"开发时要盯"小节,每条带触发点与命中动作("停下反馈,别默默绕过");计划落 `docs/superpowers/plans/`;结尾的执行二选一**自动选子代理驱动**,不问。完成:NIGHT 勾 `plan`,头部记 plan 路径。
5. **子代理执行**:推通知("计划落盘:<路径>,N 个任务。开始在隔离 worktree 执行,不 push 不合并。")→ 先调 Skill `superpowers:using-git-worktrees` 建 worktree(**基于当前本地 HEAD**,不是 origin——夜链不 push,origin 上没有 spec/plan 提交)→ 再调 Skill `superpowers:subagent-driven-development` 按计划逐任务执行。夜链预授权边界(写进给 SDD 的上下文):worktree 内实施/测试/本地 commit/fix 环/终局全分支评审全部允许;凡涉及 push、开 PR、合并、rebase 主分支的一律**预先裁定"保留分支,早上人工定"**;其余按 SDD 自己的"裁决不停等"纪律办,每条裁决记其 ledger。完成:NIGHT 勾 `sdd`,头部记分支名与 worktree 路径。
6. **终局收尾(finish)**:
   - 写晨报 `<cwd>/.xcheck/<ts>/MORNING.md`:四问结构——【评了什么】【改了什么】(评审段修订了几版、消化多少条)【执行了什么】(计划 N 任务、分支名、worktree 路径、测试结果)【早上要决定什么】(合并/PR/保留分支,含建议)——外加 SDD ledger 全部 Ruling 清单与计划/产物路径;自包含,不翻任何文件就能懂要决定什么。
   - 推通知:"夜链完成:<一句话>。分支 <name> 待你处理,晨报 .xcheck/<ts>/MORNING.md。"(任一步失败变体:停在哪一步、早上敲 `/xcheck --night` 怎么续。)
   - NIGHT 勾 `finish`,夜链结束。合并/PR/保留由用户早上人工走 `superpowers:finishing-a-development-branch`。

**通知纪律**:三个节点(写计划前 / 执行前 / 收尾)用 claude-notify(Pushover + Windows Toast);`PUSHOVER_TOKEN` / `PUSHOVER_USER` 未配置或推送失败 → **跳过不阻塞**(晨报是兜底交付)。通知正文一句话人话,不带机器词。
````

- [ ] **Step 2: 插入 NIGHT.md 格式段**

在"## PROGRESS.md 格式"段的恢复语义段(以"**恢复语义**:终态非空 = 评审段完成"开头,Task 1 改过)之后、"## 边界与异常"之前插入:

````
## NIGHT.md 格式(夜链专用)

```markdown
# NIGHT · <ts>
night = on
review_ts = <ts>               # 评审环 ts(复审链取最新环)
终态 = 夜间收工                # 评审段终态(七值之一)
spec = C:/…/xxx.rev1.md        # 第 11 步.3 定的 spec 绝对路径
plan = docs/superpowers/plans/<日期>-<主题>.md   # 写计划后填;未到填 -
sdd = <分支名>@<worktree 路径>  # 执行段;未到填 -
note = 未接下游(推倒重来)      # 可选注记

## 阶段(完成即打勾)
- [x] review                   # 评审段(含修订复审环)终态落定
- [ ] plan                     # 实施计划落盘
- [ ] sdd                      # 子代理执行完(终局评审过)
- [ ] finish                   # 晨报落盘 + 通知 + 夜链结束
```

**恢复语义**:`finish` 未勾 = 夜链未完成(壳扫描接管,`--night` 自动续,不带 `--night` 弹窗确认)。分段定位:review 段靠 PROGRESS(评审段没跑完时 PROGRESS 终态空,先按恢复模式跑完评审);`plan` 未勾 = 计划重写(半截文件直接覆盖);`sdd` 段靠 SDD 自己的 ledger 续。三段各有盘上锚点,不依赖会话记忆。
````

- [ ] **Step 3: 结构自检**

Run: `cd <repo根> && grep -c "第 11 步" xcheck/lib/flow.md && grep -c "writing-plans" xcheck/lib/flow.md && grep -c "subagent-driven-development" xcheck/lib/flow.md && grep -c "MORNING" xcheck/lib/flow.md && grep -c "NIGHT.md 格式" xcheck/lib/flow.md`
Expected: 依次 **≥ 2、= 1、≥ 1、≥ 2、= 1**。
Run: `grep -n "## 第 11 步" -A2 xcheck/lib/flow.md && grep -n "## 终态收尾" xcheck/lib/flow.md`
Expected: 第 11 步段在终态收尾段之前(行号更小)。

- [ ] **Step 4: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): 夜链第11步——终态分流→writing-plans→worktree内子代理执行→晨报;NIGHT.md格式

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: SKILL.md 壳层(--night 旗标 + 夜链扫描 + 转派)

**Files:**
- Modify: `xcheck/SKILL.md`

**Interfaces:**
- Consumes: Task 1/2 的 flow.md 语义(NIGHT_MODE 变量、NIGHT.md 四阶段、`finish` 勾选判定)。
- Produces: 壳层变量 `NIGHT_MODE = 1`(传给 flow.md);argument-hint 的新形态 `[--night] [--agents a,b,c] [<问题描述或方案>]`。Task 5/6 的文档同步引用此形态。

**背景**:SKILL.md 是 /xcheck 的入口壳,自述"只做四件事:抠 --agents → 查未完成链 → 路由 → 转派"。本任务把 --night 折进第 1/2/4 件事,不加第五件。

- [ ] **Step 1: frontmatter 的 argument-hint**

把:

```
argument-hint: [--agents a,b,c] [<问题描述或方案>]
```

替换为:

```
argument-hint: [--night] [--agents a,b,c] [<问题描述或方案>]
```

- [ ] **Step 2: 四件事描述**

把:

```
`$ARGUMENTS` 可空(裸敲 = 只查未完成链,没有就反问)。你(壳)只做四件事:**抠 --agents → 查未完成链 → 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(可选)+ 10 步」,你不重新实现它。
```

替换为:

```
`$ARGUMENTS` 可空(裸敲 = 只查未完成链,没有就反问)。你(壳)只做四件事:**抠旗标(--night / --agents)→ 查未完成链 → 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(可选)+ 11 步」(第 11 步 = 夜链专属),你不重新实现它。
```

- [ ] **Step 3: 第 1 节改为抠旗标**

把标题:

```
## 1. 抠 --agents(可选)
```

替换为:

```
## 1. 抠旗标(--night / --agents,可选)
```

并在该节开头(原"若 `$ARGUMENTS` 含 `--agents`"段之前)插入:

```
若 `$ARGUMENTS` 含独立 token `--night`(布尔,无值):把它从 `$ARGUMENTS` 删除,设 `NIGHT_MODE = 1`(夜链:整链无人值守,第 0 步确认与第 9 步停点自动拍板,评审终态后接 flow 第 11 步"写计划 → 子代理执行";细节全在 flow.md)。可与 `--agents` 并用,顺序不限。**夜链操作前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条 Bash 权限弹窗能挂整夜。
```

- [ ] **Step 4: 第 2 节扫描扩容(评审段 + 夜链)**

把第 2 节从:

```
扫 `<cwd>/.xcheck/*/PROGRESS.md`:文件存在且其 `## 终态` 段**为空** = 该 ts 未完成。取 ts 字符串最大的一个(多个未完成:取最新,选项文本顺带列出其余)。

- **没有未完成** → 进第 3 件。
- **有** → AskUserQuestion(单选):
```

替换为:

```
扫 `<cwd>/.xcheck/*/PROGRESS.md`:文件存在且其 `## 终态` 段**为空** = 该 ts 评审段未完成;再扫 `<cwd>/.xcheck/*/NIGHT.md`:文件存在且其 `## 阶段` 里 `finish` **未勾** = 该 ts 夜链未完成。取 ts 字符串最大的一个(多个未完成:取最新,选项文本顺带列出其余)。

- **都没有** → 进第 3 件。
- **有且 `NIGHT_MODE = 1`** → **不弹窗,自动续**最新未完成链:评审段未完成 → 设 `RESUME_TS = <ts>`,跳过路由与摄入,按第 4 件转派 flow.md 恢复模式;评审段已终态而夜链未完 → 直接按第 4 件转派 flow.md 第 11 步续(NIGHT.md 定位从哪个阶段续)。
- **有且无 NIGHT_MODE** → AskUserQuestion(单选):
```

并把该弹窗选项行:

```
  - `续跑 <ts>(停于:<PROGRESS 第一个未勾阶段>)` → 设 `RESUME_TS = <ts>`,**跳过路由与摄入**,直接按第 4 件转派 flow.md 恢复模式。
```

替换为:

```
  - `续跑 <ts>(停于:<PROGRESS 第一个未勾阶段 / NIGHT 第一个未勾阶段>)` → 设 `RESUME_TS = <ts>`,**跳过路由与摄入**,直接按第 4 件转派 flow.md(评审段未完走恢复模式;评审段已终态走第 11 步)。
```

- [ ] **Step 5: 第 4 节转派带 NIGHT_MODE**

把:

```
设 `MODE = diag | review | auto`(auto = 空或含糊输入,由 flow 第 0 步解析器落定),连同 `OVERRIDE_AGENTS`(若有)、`RESUME_TS`(若有,仅第 2 件续跑时),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。
```

替换为:

```
设 `MODE = diag | review | auto`(auto = 空或含糊输入,由 flow 第 0 步解析器落定),连同 `OVERRIDE_AGENTS`(若有)、`RESUME_TS`(若有,仅第 2 件续跑时)、`NIGHT_MODE`(若有,= 1 时 flow 按夜链规则跑),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。
```

- [ ] **Step 6: 铁律第 3 条加 night 句**

把:

```
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步对象解析确认(仅空/含糊输入)、flow 第 9 步停点一问;**其余一律自动推进**。
```

替换为:

```
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步对象解析确认(仅空/含糊输入)、flow 第 9 步停点一问;**其余一律自动推进**。night 模式(`--night`)下三处开口全部自动过(壳自动续链、解析自动采纳、停点自动拍板),整链零开口。
```

- [ ] **Step 7: 结构自检**

Run: `cd <repo根> && grep -ci "night" xcheck/SKILL.md && grep -c "NIGHT_MODE" xcheck/SKILL.md && grep -c "finish" xcheck/SKILL.md`
Expected: 依次 **≥ 8、≥ 3、≥ 1**。
Run: `grep -n "argument-hint" xcheck/SKILL.md`
Expected: `[--night] [--agents a,b,c] [<问题描述或方案>]`。

- [ ] **Step 8: Commit**

```bash
git add xcheck/SKILL.md
git commit -m "feat(xcheck): 壳层支持--night——旗标解析、未完成链扫描扩夜链(NIGHT.md finish)、转派带NIGHT_MODE

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 协议与术语同步(CONTEXT.md + docs/artifacts.md)

**Files:**
- Modify: `CONTEXT.md`
- Modify: `docs/artifacts.md`

**Interfaces:**
- Consumes: Task 1/2 的终态七值、NIGHT.md 四阶段、night-intake.md、MORNING.md。
- Produces: 术语权威定义——`夜链(night chain)`、`NIGHT.md`、`夜间收工(night-shipped)`、`晨报(MORNING.md)`;artifacts.md 的夜链产物解读(宿主 agent 怎么读 NIGHT/MORNING)。Task 5/6 引用这些词条名。

- [ ] **Step 1: CONTEXT.md 终态词条改七值**

把:

```
**终态(terminal state)**:
自动链的六种合法结束:收敛 / 推倒重来 / 无需修订 / 用户不修 / 用户中止 / 完成(diag)。无需修订 = round 0 必改项空(含 ①+② 真空,或剩余条目全被证伪/实验不成立);用户不修 = 必改项非空但用户选择**带着三类清单进开发**(0.15.0 起为一等公民出口,不是失败);推倒重来 = 仅用户在 m=2 三选停点确认(0.15.0 起不再自动判定)。未达终态的目录视为"未完成",可续跑。
```

替换为:

```
**终态(terminal state)**:
自动链的七种合法结束:收敛 / 推倒重来 / 无需修订 / 用户不修 / 夜间收工 / 用户中止 / 完成(diag)。无需修订 = round 0 必改项空(含 ①+② 真空,或剩余条目全被证伪/实验不成立);用户不修 = 必改项非空但用户选择**带着三类清单进开发**(0.15.0 起为一等公民出口,不是失败);夜间收工 = 夜链的自动等价决策(见「夜链」);推倒重来 = 仅用户在 m=2 三选停点确认(0.15.0 起不再自动判定)。未达终态的目录视为"未完成",可续跑。
```

- [ ] **Step 2: CONTEXT.md 停点词条加夜链注**

把:

```
**停点(gate)**:
自动链上**唯一**等人拍板的时刻——呈现已验证三分类清单,用户决策。人的控制权在结果上,不在过程里。
```

替换为:

```
**停点(gate)**:
自动链上**唯一**等人拍板的时刻——呈现已验证三分类清单,用户决策。人的控制权在结果上,不在过程里。夜链(--night)下停点不等人,按「夜链」的既定策略自动拍板;控制权移到早上对分支与晨报的处置。
```

- [ ] **Step 3: CONTEXT.md 加四个新词条**

在终态词条之后、"### 流程各步"标题之前插入:

```
**夜链(night chain)**:
`/xcheck --night` 触发的无人值守形态:第 9 步停点按既定策略自动拍板(round 0 必改非空 → 自动修订再评一轮;round ≥ 1 仍非空 → 自动带清单收工),终态后接 flow 第 11 步——调 superpowers:writing-plans 写实施计划、superpowers:subagent-driven-development 在隔离 worktree 执行;**不 push、不开 PR、不合并**,终点 = 本地分支 + 晨报。评审段机制与普通链完全同源,只差一枚旗标。
_Avoid_: 全自动模式(和「自动链」混淆)、无人值守模式(没说清接到哪一步)

**NIGHT.md**:
夜链的进度账本,四阶段:`review / plan / sdd / finish`。与 PROGRESS 分账:PROGRESS 只管评审段,NIGHT 管评审段之后的下游接续;`finish` 未勾 = 夜链未完成,`/xcheck --night` 可续。
_Avoid_: 夜链 PROGRESS(不是同一个文件)

**夜间收工(night-shipped)**:
夜链专属终态:必改非空时夜间策略自动选"带清单进开发"(或防御性"按现状收工")。语义同用户不修(带着已验证清单交下游),但记账区分——用户没在场,是策略的决策,不是用户的决定。
_Avoid_: 记成 用户不修(人不在场)

**晨报(MORNING.md)**:
夜链终局收尾产出的人话总交付:四问(评了什么/改了什么/执行了什么/早上要决定什么)+ 子代理执行的全部裁决清单 + 分支与产物路径。自包含,不翻文件就能决策。
_Avoid_: 夜链 SUMMARY(MORNING 是给人看的,机器账在 SUMMARY/ledger)
```

- [ ] **Step 4: artifacts.md 一眼判断加夜链行**

在"## 一眼判断"第二个 bullet("- `## 终态` 段**为空**且有未勾选阶段 → 链未完成(中断/崩溃)。**让用户重新敲 `/xcheck`**,skill 自己会发现并弹"续跑/新开";你不要手工替它续。")之后插入:

```
- `<ts>/NIGHT.md` 存在且其 `finish` 未勾 → 这是一条**夜链**且未收尾(评审段可能已终态);让用户重敲 `/xcheck --night` 续跑(自动,不弹窗),同样不要手工代跑。
```

- [ ] **Step 5: artifacts.md 目录树加三个夜链产物**

在目录总览代码块中 `│   ├── proposal.rev<m>.md` 行之前插入:

```
│   ├── night-intake.md           # (夜链)第 0 步解析推断留档(夜里不弹窗的"过目"替代)
│   ├── NIGHT.md                  # (夜链)下游接续进度账本:review/plan/sdd/finish
│   ├── MORNING.md                # (夜链)晨报:四问人话总交付 + 执行裁决清单(收尾才有)
```

- [ ] **Step 6: artifacts.md PROGRESS 样例加 night 行、终态表加一行**

在 PROGRESS.md 代码块 `smoke_cfg = <sha256>` 行后加:

```
night = on                  # (夜链才有)夜间模式:停点自动决策、终态后接第 11 步;非夜链无此行
```

把"- **终态六值**怎么读:"替换为"- **终态七值**怎么读:",并在其表格 `| 用户不修 | ... |` 行后插入:

```
| `夜间收工` | 夜链自动决策的带清单/按现状收工(语义同`用户不修`,但用户没在场——策略拍的板;代码在 worktree 分支,见 NIGHT.md) |
```

- [ ] **Step 7: artifacts.md 加"夜链产物"一节**

在"## 评审附录(在被评文档里,不在 .xcheck/)"一节之后、"## 你可以做的"之前插入:

```
## 夜链产物(--night 触发时才有)

- **NIGHT.md**:下游接续的进度账本,四阶段 `review → plan → sdd → finish`;`finish` 未勾 = 夜链未完成,`/xcheck --night` 续。头部记评审终态、spec/plan 路径、分支名。
- **night-intake.md**:夜间第 0 步解析器的推断留档(对象+模式+背景原话)——夜里不弹确认窗,推断直接生效,此文件就是"本应过目"的替代,用户早上可查。
- **MORNING.md**:晨报,人话总交付:【评了什么】【改了什么】【执行了什么】【早上要决定什么】+ 子代理执行期间的全部裁决(Ruling)+ 分支名/worktree 路径/计划与产物路径。
- **代码不在 .xcheck/**:夜链子代理执行的代码改动在 **worktree 分支**上(NIGHT.md `sdd` 行记了分支名与路径);.xcheck/ 只有账,没有代码。
- 推倒重来 / 用户中止 / diag 的夜链**不接下游**(没有 plan/sdd 两步),NIGHT.md 的 note 会注明原因。
```

- [ ] **Step 8: 结构自检**

Run: `cd <repo根> && grep -c "夜链" CONTEXT.md && grep -c "夜间收工" CONTEXT.md && grep -c "夜链" docs/artifacts.md && grep -c "MORNING" docs/artifacts.md`
Expected: 依次 **≥ 5、≥ 2、≥ 5、≥ 2**。
Run: `grep -c "终态七值" docs/artifacts.md`
Expected: **1**。

- [ ] **Step 9: Commit**

```bash
git add CONTEXT.md docs/artifacts.md
git commit -m "docs: 夜链术语入表(夜链/NIGHT.md/夜间收工/晨报)、终态七值;artifacts补夜链产物解读

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: README.md 用户向同步

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 1~4 的全部行为定义;命令形态 `[--night] [--agents a,b,c] [<文字>]`(Task 3)。
- Produces: 用户可感知的夜链说明(新小节"夜链:--night,睡前一把梭"、命令表、产物图、已知边界、续跑说明)。

- [ ] **Step 1: 快速开始示例加夜链一行**

在快速开始代码块:

```
/xcheck 评审 docs/superpowers/specs/2026-09-16-foo-design.md
/xcheck 帮我看看这个方案行不行:<贴方案全文>
/xcheck 为什么这个服务一起动就崩:<完整报错栈>
/xcheck            ← 裸敲:续跑未完成的链,或从刚才的对话里猜你要评什么
```

的裸敲行**之前**插入:

```
/xcheck --night 评审 docs/superpowers/specs/2026-09-16-foo-design.md
                   ← 夜链:评审完自动写实施计划+子代理执行,早上看本地分支和晨报
```

- [ ] **Step 2: 新小节"夜链:--night,睡前一把梭"**

在"### 修订与复审"小节末段("链走到结论性终态时……是动作,不是参考。")之后、"### 中断了怎么办"之前插入:

```
### 夜链:--night,睡前一把梭

白天聊完方案,睡前敲 `/xcheck --night 评审 <方案>` 就去睡:

- 评审段照常全自动;**停点不等你**——round 0 查出必改就自动修订(原稿不动)并复审一轮;round 1 仍有必改就自动"带清单收工",终态记 `夜间收工`。
- 收工后自动接两跳:调 superpowers:writing-plans 写实施计划(评审附录里"开发时要盯"的条目直接进计划的全局约束),再在**隔离 worktree** 里用 superpowers:subagent-driven-development 逐任务执行、逐任务评审、终局全分支评审。
- **安全栏**:不 push、不开 PR、不合并、不动你的主工作区;代码全部留在本地 worktree 分支。方案被判"推倒重来"或链被中止 → 不写一行代码,通知你早上处理。
- 早上看两样:推送通知(claude-notify,三节点:评审终态 / 计划落盘 / 执行完成)+ 晨报 `.xcheck/<ts>/MORNING.md`(评了什么 / 改了什么 / 执行了什么 / 要决定什么 + 子代理的全部裁决)。合不合并、要不要 PR,你人工走 finishing-a-development-branch。
- 夜里崩了:重敲 `/xcheck --night` 自动续(评审靠 PROGRESS、计划靠 NIGHT.md、执行靠执行侧自己的账本,全在盘上)。
- **前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条权限弹窗能挂整夜。
```

- [ ] **Step 3: 命令表加 --night**

把:

```
| `/xcheck [--agents a,b,c] [<文字>]` | 整条自动链:路由 → 盲评 → 三分类 → 验证 → 停点。裸敲 = 查未完成链,没有就从会话上下文解析评审对象(一个确认窗)。 |
```

替换为:

```
| `/xcheck [--night] [--agents a,b,c] [<文字>]` | 整条自动链:路由 → 盲评 → 三分类 → 验证 → 停点。裸敲 = 查未完成链,没有就从会话上下文解析评审对象(一个确认窗)。加 `--night` = 夜链:停点自动拍板,评审完接"写计划 + 子代理执行",代码停本地 worktree 分支,晨报叫早。 |
```

- [ ] **Step 4: 中断了怎么办加夜链句**

在"### 中断了怎么办"段末("——盲评结果不会白跑,不依赖任何会话记忆。")后追加:

```
夜链(`--night`)中断同理:重敲 `/xcheck --night` **自动**续(不弹窗)——评审段靠 PROGRESS、计划段靠 NIGHT.md、执行段靠执行侧账本,三段各有盘上锚点。
```

- [ ] **Step 5: 产物树加三个夜链文件**

在"## 产物落在哪"目录树的 `│   └── SUMMARY.md` 行**之前**(`└──` 会变成 `├──`,同步把原 SUMMARY 行的 `└──` 改为 `├──` 并让 exp/ 行保持原样——以实际树形为准,保持注释列对齐)插入:

```
│   ├── NIGHT.md                  #   (夜链)下游接续进度:review/plan/sdd/finish
│   ├── night-intake.md           #   (夜链)第 0 步解析留档(夜里不弹窗的过目替代)
│   ├── MORNING.md                #   (夜链)晨报:四问总交付 + 执行裁决清单(收尾才有)
```

(若原树 `SUMMARY.md` 是 ts 目录最后一项且用 `└──`,把 NIGHT 三行插在它前面并用 `├──`,SUMMARY 保持 `└──`。)

- [ ] **Step 6: 已知边界加夜链条目**

在"## 已知边界"列表末尾("- 在 **Windows + Git Bash** 上开发与实测;其它 bash 环境理论可用,未系统验证。"之前)插入:

```
- **夜链不 push 不合并**:`--night` 的代码改动停在本地 worktree 分支,合并 / PR 是早上的手工决定;评审判"推倒重来"、链被中止或 diag 模式不接下游(不写代码)。
```

- [ ] **Step 7: 仓库结构树同步**

把仓库结构树中:

```
│   ├── flow.md                     # 自动链大脑:恢复模式 + 第 0~10 步 + 铁律
```

替换为:

```
│   ├── flow.md                     # 自动链大脑:恢复模式 + 第 0~11 步(第 11 步=夜链接续)+ 铁律
```

- [ ] **Step 8: 结构自检**

Run: `cd <repo根> && grep -ci "night" README.md && grep -c "夜间收工" README.md && grep -c "MORNING" README.md && grep -c "第 0~11 步" README.md`
Expected: 依次 **≥ 6、≥ 1、≥ 2、= 1**。

- [ ] **Step 9: Commit**

```bash
git add README.md
git commit -m "docs(readme): 夜链小节+命令表+产物图+边界+续跑说明

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: AGENTS.md 维护向同步

**Files:**
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 1~4 的协议(步骤 0~11、终态七值、NIGHT.md、night 字段、壳四件事新形态)。
- Produces: 维护导览的精确生命周期(壳 4 步 + flow 0~11)、状态协议七值、铁律 9。

- [ ] **Step 1: 系统一句话加夜链**

在"## 系统一句话"段末("……agent 执行是机械化的(`run-agent.sh`)。")后追加:

```
0.17.0 起支持**夜链**:`/xcheck --night` 无人值守贯通"评审 → superpowers:writing-plans → superpowers:subagent-driven-development(worktree 内执行)",不 push 不合并,终点 = 本地分支 + 晨报 MORNING.md。
```

- [ ] **Step 2: 生命周期壳段改旗标与扫描**

把:

```
壳 xcheck/SKILL.md(只做 4 件事)
  1. 抠 --agents(单 token 纯逗号串;名字不在 agents.toml → 报错停)
  2. 查未完成链(<cwd>/.xcheck/*/PROGRESS.md 存在且 ## 终态 为空;取最大 ts)
     → 弹窗 0:续跑(设 RESUME_TS,跳过路由与摄入)/ 新开
```

替换为:

```
壳 xcheck/SKILL.md(只做 4 件事)
  1. 抠旗标(--night 布尔 → NIGHT_MODE=1;--agents 单 token 纯逗号串,
     名字不在 agents.toml → 报错停)
  2. 查未完成链(PROGRESS.md ## 终态 为空 = 评审段未完;NIGHT.md finish
     未勾 = 夜链未完;取最大 ts)→ 弹窗 0:续跑/新开;NIGHT_MODE=1 →
     不弹窗自动续(评审段未完走恢复模式;已终态走第 11 步)
```

- [ ] **Step 3: 生命周期加第 11 步**

在生命周期代码块"  终态收尾  先写评审附录(review + 结论性终态 + source 是文件 → 被评文档文末,
             按 ts 幂等重写),再写 PROGRESS 终态"两行**之后**、代码块结束之前插入:

```
  第 11 步 夜链(NIGHT_MODE=1,评审终态落定后):建 NIGHT.md → 终态分流(无需修订/
             收敛/夜间收工接续;推倒重来/用户中止/完成(diag)不接下游)→ 定 spec
             (最新 rev > source 路径 > proposal.md)→ 调 superpowers:writing-plans
             (③存疑+②无定论进计划 Global Constraints"开发时要盯")→ worktree
             (基于本地 HEAD)调 superpowers:subagent-driven-development 执行
             (不 push/PR/合并,预授权边界=保留分支)→ 晨报 MORNING.md + 三节点
             通知(claude-notify,失败不阻塞)+ NIGHT 勾 finish
```

- [ ] **Step 4: 开口纪律加 night**

把:

```
**开口纪律**:全链只有三处等用户 —— 壳的续跑确认、第 0 步对象解析确认(仅含糊输入)、第 9 步停点一问。其余一律自动推进。
```

替换为:

```
**开口纪律**:全链只有三处等用户 —— 壳的续跑确认、第 0 步对象解析确认(仅含糊输入)、第 9 步停点一问。其余一律自动推进。night 模式(`--night`)下三处开口全部自动过(自动续链/自动采纳解析/停点自动拍板),整链零开口。
```

- [ ] **Step 5: 模块地图两行更新**

把:

```
| `xcheck/SKILL.md` | 入口壳:参数抠取、未完成链检查、MODE 词表路由、转派 | 壳不实现链逻辑;词表只在此文件,改词表要同步 README 输入形态描述 |
```

替换为:

```
| `xcheck/SKILL.md` | 入口壳:旗标抠取(--night/--agents)、未完成链检查(含夜链)、MODE 词表路由、转派 | 壳不实现链逻辑;词表只在此文件,改词表要同步 README 输入形态描述 |
```

把模块地图中 flow.md 行的"**步骤编号(0~10)与 PROGRESS 阶段枚举是跨文件协议**"改为"**步骤编号(0~11)与 PROGRESS 阶段枚举是跨文件协议**"。

- [ ] **Step 6: 状态协议改七值 + night 字段**

把:

```
- **终态六值**:`收敛(N 轮修订)` / `推倒重来`(**仅用户在 m=2 三选停点确认**)/ `无需修订`(仅 round 0 且必改项空:①+② 真空,或剩余全被证伪/实验不成立)/ `用户不修`(必改非空,用户选择带三类清单进开发)/ `用户中止` / `完成(diag)`。
```

替换为:

```
- **终态七值**:`收敛(N 轮修订)` / `推倒重来`(**仅用户在 m=2 三选停点确认**)/ `无需修订`(仅 round 0 且必改项空:①+② 真空,或剩余全被证伪/实验不成立)/ `用户不修`(必改非空,用户选择带三类清单进开发)/ `夜间收工`(夜链自动决策的带清单/按现状收工,用户未在场)/ `用户中止` / `完成(diag)`。
- **夜链账本**:PROGRESS 头部可选字段 `night = on`(夜链才写);NIGHT.md 四阶段 `review/plan/sdd/finish`(`finish` 未勾 = 夜链未完成,不进 PROGRESS 阶段枚举)。
```

- [ ] **Step 7: 铁律加第 9 条**

在"## 铁律"清单第 8 条("8. **搬运工必须后台启动 run-agent.sh 并在回合内阻塞等待**……")之后追加:

```
9. **夜链安全栏(--night)**:第 11 步下游执行的一切代码改动只在 worktree;不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区;通知失败不阻塞,晨报兜底;夜间会话须免弹窗权限模式。
```

- [ ] **Step 8: 改链结构段同步编号**

把"**改链结构**"段中"flow.md 步骤编号、PROGRESS 阶段枚举、终态枚举三者是协议,一动全动"后面的括号内容里若出现"0~10"字样改为"0~11"(以实际文本为准;该段当前写的是"flow.md 步骤编号、PROGRESS 阶段枚举、终态枚举三者是协议,一动全动(SKILL.md、carrier、setup、AGENTS.md、docs/artifacts.md、CONTEXT.md)"——无需改;检查确认即可,若无需改动则跳过本步并在报告注明)。

- [ ] **Step 9: 结构自检**

Run: `cd <repo根> && grep -c "夜间收工" AGENTS.md && grep -ci "night" AGENTS.md && grep -c "第 11 步" AGENTS.md && grep -c "终态七值" AGENTS.md`
Expected: 依次 **≥ 1、≥ 4、≥ 1、= 1**。
Run: `grep -n "0~10" AGENTS.md`
Expected: 无输出(全部已是 0~11)。

- [ ] **Step 10: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): 生命周期加第11步与夜链扫描、终态七值、铁律9夜链安全栏

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: CHANGELOG 0.17.0 + 回归测试 + 全量结构自检

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1~6 的全部改动(作为变更描述对象)。
- Produces: 版本条目 0.17.0;全绿证据(测试 + spec §5 结构自检)。

- [ ] **Step 1: 写 0.17.0 条目**

在"## [0.16.0] - 2026-09-17"标题**之前**插入:

```
## [0.17.0] - 2026-09-17

### Added / 新增

- **Night chain: `/xcheck --night` runs review → plan → subagent execution unattended; you wake up to a local branch and a morning report.** The chain's three human openings (shell resume confirm, step-0 resolver confirm, step-9 gate) all auto-pass under `--night`: the shell auto-resumes the newest unfinished chain; the object resolver's best inference takes effect without a popup (archived to `<ts>/night-intake.md` — the "would-have-shown-you" substitute); the gate auto-decides per policy — round 0 with must-fix open → auto-revise + re-review (originals untouched), round ≥ 1 still open → auto-ship with the verified three-tier list, recorded as new terminal `夜间收工` (semantics of 用户不修, but honestly booked: the policy decided, not the user). New **step 11 (夜间接续)**: terminal gating (无需修订/收敛/夜间收工 proceed; 推倒重来/用户中止/完成(diag) stop without writing code), spec = latest `.rev<m>.md` > source path > `proposal.md`; invokes `superpowers:writing-plans` (tier-③ + inconclusive tier-② items enter the plan's Global Constraints "开发时要盯" section with trigger + stop-and-report action), then `superpowers:using-git-worktrees` (**from local HEAD** — night never pushes) and `superpowers:subagent-driven-development` with pre-authorized boundaries: everything inside the worktree allowed; push/PR/merge/rebase-main pre-ruled to "keep the branch, human decides in the morning". Terminal artifacts: `NIGHT.md` (4-stage ledger: review/plan/sdd/finish; finish unticked = night chain unfinished, `/xcheck --night` resumes automatically) and `MORNING.md` (four-question plain-language morning report + every SDD ruling + branch/worktree/plan paths). Notifications at three milestones via claude-notify; unconfigured/failed → skipped, never blocks (MORNING.md is the fallback). Operational note baked into SKILL.md: night sessions must run in a no-popup permission mode, or one subagent Bash prompt hangs the whole night. PROGRESS header gains optional `night = on`; terminal enum six → seven values. flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md all synced. Design: `docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`.
- **夜链:`/xcheck --night` 无人值守贯通"评审 → 写计划 → 子代理执行";早上醒来,代码在本地分支上,晨报在等你。** 链的三处人工开口(壳续跑确认、第 0 步解析确认、第 9 步停点)在 `--night` 下全部自动过:壳自动续最新未完成链;对象解析器最优推断直接生效不弹窗(留档 `<ts>/night-intake.md`,即"本应过目"的替代);停点按既定策略自动拍板——round 0 必改非空 → 自动修订 + 复审一轮(原稿不动),round ≥ 1 仍非空 → 自动带清单收工,记新终态 `夜间收工`(语义同用户不修,但账记实:是策略拍的板,不是用户)。新增**第 11 步(夜间接续)**:终态分流(无需修订/收敛/夜间收工接续;推倒重来/用户中止/完成(diag)不接下游、不写一行代码),spec = 最新 `.rev<m>.md` > source 路径 > `proposal.md`;调 `superpowers:writing-plans`(③存疑 + ②无定论条目进计划 Global Constraints"开发时要盯"小节,带触发点与"停下反馈"动作),再 `superpowers:using-git-worktrees`(**基于本地 HEAD**——夜链绝不 push)与 `superpowers:subagent-driven-development`,预授权边界:worktree 内全允许;push/PR/合并/rebase 主分支一律预先裁定"保留分支,早上人工定"。终局产物:`NIGHT.md`(四阶段账本:review/plan/sdd/finish;finish 未勾 = 夜链未完成,`/xcheck --night` 自动续)与 `MORNING.md`(四问人话晨报 + SDD 全部裁决 + 分支/worktree/计划路径)。三节点通知走 claude-notify;未配置/失败 → 跳过不阻塞(晨报兜底)。操作前提写进 SKILL.md:夜间会话须免弹窗权限模式,否则一条子代理权限弹窗挂整夜。PROGRESS 头部新增可选 `night = on`;终态枚举六值 → 七值。flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md 已同步。设计稿:`docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`。
```

- [ ] **Step 2: 回归测试**

Run: `cd <repo根> && bash xcheck/tests/run-agent.test.sh 2>&1 | tail -5`
Expected: 全部断言通过(33/33;本次未动脚本,预期不变绿即回归)。

- [ ] **Step 3: spec §5 结构自检(全量)**

Run: `cd <repo根> && grep -ci "night" xcheck/SKILL.md && grep -c "第 11 步" xcheck/lib/flow.md && grep -c "夜间收工" xcheck/lib/flow.md && grep -c "夜间收工" AGENTS.md && grep -c "夜间收工" docs/artifacts.md && grep -c "夜间收工" CONTEXT.md && grep -c "NIGHT.md" docs/artifacts.md && grep -c "0.17.0" CHANGELOG.md`
Expected: 依次 **≥ 8、≥ 2、≥ 5、≥ 1、≥ 1、≥ 2、≥ 3、≥ 1**。

- [ ] **Step 4: 工作区干净检查**

Run: `cd <repo根> && git status --porcelain`
Expected: 空(Task 1~7 的改动全部已提交)。

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): 0.17.0 夜链——--night 无人值守贯通评审→计划→子代理执行

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 收尾注意(给执行者)

- **不 push、不打 tag、不开 PR**——夜链安全栏约束本次实施本身;v0.17.0 的 tag 与 push 是用户早上的手工决定。
- 完成后按 subagent-driven-development 的 Finish 段走:汇总全部 Ruling,分支留在 worktree。
