# xcheck 夜链 rev2 实施计划(自动优先 + Matt 管线 + 入口一问)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 夜链 rev2——入口一问(自动推进默认推荐/正常交互/--night 免问)+ 自动模式下游全换 Matt Pocock 管线(to-spec → to-tickets → 逐票 TDD 实施+双轴评审)+ 自动化优先级最高铁律。

**Architecture:** 纯 Markdown 指令改动,继续在 worktree 分支 `worktree-xcheck-night-chain` 上叠加(基线 3a83a4d)。第 11 步的 11.4-11.6 整体重写(去 superpowers 调用,内嵌逐票循环);NIGHT.md 阶段 `sdd` 改名 `impl` 并加票级台账;壳加入口一问;七处文档同步;CHANGELOG 0.17.0 条目改写(未发布,一个版本一个故事)。

**Tech Stack:** Claude Code skill 指令文档(Markdown);bash grep 结构自检;回归 xcheck/tests/run-agent.test.sh。

**Spec:** `docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`(rev1)+ `.rev2.md`(rev2 增量,权威)

## Global Constraints

- **工作目录**:一切编辑在 worktree `C:/WorkSpace/agent/xcheck/.claude/worktrees/xcheck-night-chain` 内,绝对路径;主 checkout 同名路径禁碰。
- **标点/行尾**:半角逗号 + 全角括号冒号,照抄现有文件风格;LF。
- **协议**:NIGHT.md 阶段枚举改为 `review / plan / impl / finish`(`plan`=to-spec+to-tickets,`sdd` 改名 `impl`);NIGHT 头部字段 `spec`(被评文档)改名 `object`,新增 `spec`(to-spec 产物)与 `tickets` 字段——注意改名歧义:原 `spec` 字段变 `object`,新 `spec` 字段是 to-spec 产物路径。PROGRESS/终态/评审段协议不变。
- **禁改文件**:run-agent.sh / detect.sh / agents.toml / prompts/* / carrier / context-intake / xcheck-setup。
- **词汇**:外部技能名精确 `to-spec`、`to-tickets`;`入口一问`、`逐票`、`frontier`、`双轴评审(Spec 符合 + Standards)`;flow.md 内 **不得残留** `writing-plans` / `subagent-driven-development` / 单词 `sdd`(grep = 0)。
- **不 push、不打 tag、不开 PR**;每任务一 commit,conventional 前缀 + 中文主题,尾注 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`。
- **向后兼容**:交互模式(入口选"正常交互"且非夜链)行为与 v0.16 完全一致。

---

### Task 1: flow.md 第 11 步下游换血 + NIGHT.md 格式 + 铁律/停点/边界同步

**Files:**
- Modify: `xcheck/lib/flow.md`

**Interfaces:**
- Consumes: rev1 已落的第 11 步(210-226 行)、NIGHT.md 格式段(277-296)、铁律 9(325 附近)、停点纪律(7 行附近)。
- Produces: 新 11.4(固化 spec)/11.5(拆票)/11.6(逐票实施)/11.7(终局收尾)文本;NIGHT 新格式(object/spec/tickets/impl 字段 + 票级台账);后续任务的文档同步全部引用这些名字。

- [ ] **Step 1: 第 11 步 blockquote 换血**

把:

```
> 夜链专属:把评审交付物接进下游"写实施计划 → 子代理执行"。非夜链(普通 /xcheck)永远不进这一步(唯一例外:壳弹窗确认"续跑夜链"时,壳已一并设 NIGHT_MODE = 1)。夜链安全栏(铁律 9)在本步全程生效。
```

替换为:

```
> 夜链专属:把评审交付物接进下游"固化 spec → 拆票 → 逐票实施"(Matt Pocock 主流程的 to-spec → to-tickets → implement 一段)。非夜链(普通 /xcheck)永远不进这一步(唯一例外:壳弹窗确认"续跑夜链"时,壳已一并设 NIGHT_MODE = 1)。夜链安全栏与自动化优先级(铁律 9)在本步全程生效。
```

- [ ] **Step 2: 第 1 条与第 3 条改口径(object)**

把第 1 条中 `勾 `review`,头部记评审终态与 spec 路径` 替换为 `勾 `review`,头部记评审终态与 object(被评文档)路径`。

把第 3 条整条:

```
3. **定 spec**:spec = 最新 `<原名>.rev<m>.md`(取最大 m)> PROGRESS `source` 的文件路径 > `<ts>/proposal.md`(inline / 讨论型固化稿)。文档文末已带评审附录(主交付物),spec 连附录一起交给下游。
```

替换为:

```
3. **定对象(object)**:object = 最新 `<原名>.rev<m>.md`(取最大 m)> PROGRESS `source` 的文件路径 > `<ts>/proposal.md`(inline / 讨论型固化稿)。文档文末已带评审附录(主交付物),object 连附录一起交给 to-spec。
```

- [ ] **Step 3: 11.4/11.5 整体替换(写计划 → 固化 spec + 拆票)**

把第 4 条与第 5 条两条整体(从 `4. **写计划**:推通知` 到第 5 条结尾 `完成:NIGHT 勾 `sdd`,头部记分支名与 worktree 路径。`)替换为:

```
4. **固化 spec(to-spec)**:推通知("评审终态:<人话一句>。开始固化实施 spec。")→ 调 Skill `to-spec`,输入 = 第 3 条的 object(连文末评审附录)+ 本链背景;夜链附加指令(随调用传入):
   - **不发布 issue tracker**(对外动作夜里禁):spec 落本地 `<cwd>/docs/superpowers/specs/<YYYYMMDD>-<主题>-spec.md` 并 commit;
   - to-spec 的 seam 确认关卡**自动过**:主会话裁定 seam 取舍(优先既有最高 seam,确需新 seam 从最高点提案),裁定记 NIGHT;
   - 评审附录的③存疑条目与②无定论条目写进 spec 的 Testing Decisions / Further Notes("开发时要盯",每条带触发点与命中动作"停下反馈,别默默绕过")。
   完成:NIGHT 头部 `spec` 字段填路径。
5. **拆票(to-tickets)**:仍属 `plan` 阶段 → 调 Skill `to-tickets`,输入 = spec 文件;夜链附加指令:
   - **本地模式**:票落 `<cwd>/.scratch/<feature-slug>/issues/NN-<slug>.md`(一票一文件:What to build / 验收标准 / Blocked by),**不上 tracker**;完成后 commit;
   - 拆票 quiz(粒度/阻塞边确认)**自动过**:主会话自查三条(每票端到端竖切可独立验收 · 粒度≈单个新鲜上下文 · 阻塞边=真实依赖),疑点裁定记 NIGHT;
   - 宽改动(wide refactor)按 to-tickets 原文的 expand–contract 例外排序,不硬切竖片。
   完成:NIGHT 头部 `tickets` 字段填目录,勾 `plan`(注记"spec + N 票")。
```

- [ ] **Step 4: 新 11.6 逐票实施 + 11.7 终局收尾**

在 Step 3 替换产物之后、原第 6 条"**终局收尾(finish)**"之前插入新第 6 条(逐票实施),并把原第 6 条改编号为 7 且更新【执行了什么】与裁定清单口径。具体:

原第 6 条开头 `6. **终局收尾(finish)**:` 改为 `7. **终局收尾(finish)**:`;其晨报行中 `【执行了什么】(计划 N 任务、分支名、worktree 路径、测试结果)` 替换为 `【执行了什么】(N 张票逐票状态、分支名、worktree 路径、spec 与票目录、测试结果)`;`外加 SDD ledger 全部 Ruling 清单与计划/产物路径` 替换为 `外加全部裁定清单(评审段裁定 + to-spec/to-tickets 自动关卡裁定 + 每票修复环停靠 + 终局裁定)与 spec/票目录/产物路径`。

在改号后的第 7 条之前插入:

```
6. **逐票实施(impl,worktree 内)**:推通知("spec 固化 + 拆票完成:N 张票。开始在隔离 worktree 逐票实施,不 push 不合并。")→:
   - **建 worktree**(git worktree,基于**当前本地 HEAD**——夜链不 push,origin 上没有 spec/票提交),分支名 `xcheck-night-<ts>`;此后一切实施只在此 worktree 内。
   - **frontier = blockers 全完成的票**,按编号序**严格串行**(绝不并行派两个实施者,防冲突)。每票循环:
     a. 记 BASE=当前 HEAD;派 fresh implementer subagent:brief = 票文件全文 + spec 路径 + 前票已定接口与裁定;要求 **TDD**(先写失败测试跑红 → 最小实现跑绿)→ 跑覆盖测试 → commit(一票可多 commit);模型:单文件机械票用便宜档,跨文件/含设计判断票用中档;回报四态(DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / Blocked)。
     b. 回报处理:DONE_WITH_CONCERNS 先读疑虑再定;NEEDS_CONTEXT 补上下文重派;Blocked 主会话裁定(拆小 / 换更强模型 / 跳过停靠记账),不硬闯。
     c. 派独立 reviewer subagent 做**双轴评审**(Spec 符合 = 票的验收标准逐条核;Standards = 代码质量),输入 = 票文件 + BASE..HEAD diff 打包文件。发现 Critical/Important → 修复环:R≤3 resume 原实施者,R4-5 换更强模型 fresh 重派,每轮修复后一次 scoped re-review(只核发现与修复 diff 新破损),**每票上限 5 轮**;cap 后逐条裁定(评审过严/可争议 → 停靠;真实但无下游依赖 → 停靠;真实且承重 → 最小修正+记账)。Minor 记 NIGHT 停靠清单,供终局裁量。
     d. 票完成:NIGHT 的票级台账追加一行(格式见文末),半夜崩了重敲续跑从第一张未 complete 的票起。
   - 全票完 → **终局全分支 code review**:派最强档 reviewer,输入 = merge-base..HEAD 全分支 diff 包 + 票清单 + 停靠 minor 清单;有发现 → **一轮 fix 派发**(全部发现一次派一个实施者)+ 一次 scoped re-review;残留逐条裁定停靠/记账,无第二波修复。
   完成:NIGHT 勾 `impl`,头部 `impl` 字段填分支名@worktree 路径。
```

- [ ] **Step 5: 通知纪律段节点改名**

把:

```
**通知纪律**:三个节点(写计划前 / 执行前 / 收尾)用 claude-notify(Pushover + Windows Toast);
```

替换为:

```
**通知纪律**:三个节点(固化 spec 前 / 逐票实施前 / 收尾)用 claude-notify(Pushover + Windows Toast);
```

- [ ] **Step 6: NIGHT.md 格式段整体替换**

把"## NIGHT.md 格式(夜链专用)"的代码块与恢复语义段(从 `# NIGHT · <ts>` 到 `不依赖会话记忆。`)整体替换为:

````
```markdown
# NIGHT · <ts>
night = on
review_ts = <ts>               # 评审环 ts(复审链取最新环)
终态 = 夜间收工                # 评审段终态(七值之一)
object = C:/…/xxx.rev1.md      # 第 11 步.3 定的被评文档绝对路径
spec = docs/superpowers/specs/<日期>-<主题>-spec.md   # to-spec 产物;未到填 -
tickets = .scratch/<slug>/issues/   # to-tickets 票目录;未到填 -
impl = <分支名>@<worktree 路径>  # 逐票实施;未到填 -
note = 未接下游(推倒重来)      # 可选注记

## 阶段(完成即打勾)
- [x] review                   # 评审段(含修订复审环)终态落定
- [ ] plan                     # to-spec 固化 + to-tickets 拆票完成
- [ ] impl                     # 逐票实施完(终局评审过)
- [ ] finish                   # 晨报落盘 + 通知 + 夜链结束

## 票级台账(impl 段逐票追加)
票 01: complete(commits a1b2c3d..d4e5f6a, review clean)
```

**恢复语义**:`finish` 未勾 = 夜链未完成(壳扫描接管,`--night` 自动续,不带 `--night` 弹窗确认)。分段定位:review 段靠 PROGRESS(评审段没跑完时 PROGRESS 终态空,先按恢复模式跑完评审);`plan` 未勾 = spec/票重做(半截文件直接覆盖);`impl` 段靠 NIGHT 票级台账续——worktree 与分支在则进入续跑,不在则按 `impl` 字段重建(分支已存在则直接挂上,连分支都没了则从 spec/票所在提交重开 worktree)。三段各有盘上锚点,不依赖会话记忆。
````

- [ ] **Step 7: 停点纪律段加入口一问口径**

把停点纪律段(第 7 行附近)中:

```
 night 模式(NIGHT_MODE = 1)下三处开口全部自动过,整链零开口:①壳自动续最新未完成链,不弹窗;②第 0 步自动采纳解析器最优推断(落 night-intake.md 留档,见第 0 步);③第 9 步停点按夜链决策表自动拍板(见第 9 步)。
```

替换为:

```
 night 模式(NIGHT_MODE = 1,来源:`--night` 或壳的入口一问选"自动推进")下三处开口全部自动过,其后零开口——自动化优先级最高,下游技能(to-spec/to-tickets/修复环)的确认关卡一律自动裁定记账(铁律 9):①壳自动续最新未完成链,不弹窗;②第 0 步自动采纳解析器最优推断(落 night-intake.md 留档,见第 0 步);③第 9 步停点按夜链决策表自动拍板(见第 9 步)。
```

- [ ] **Step 8: 铁律 9 扩自动化优先级**

把铁律 9:

```
9. **夜链安全栏(NIGHT_MODE = 1)**:第 11 步下游执行的一切代码改动只发生在 worktree;**不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区**;通知失败不阻塞,晨报(MORNING.md)兜底;夜间会话须用免弹窗权限模式跑(bypassPermissions 或预放行常用命令,否则子代理权限弹窗挂整夜)。
```

替换为:

```
9. **夜链安全栏与自动化优先级(NIGHT_MODE = 1)**:第 11 步下游执行的一切代码改动只发生在 worktree;**不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区**;通知失败不阻塞,晨报(MORNING.md)兜底;夜间会话须用免弹窗权限模式跑(bypassPermissions 或预放行常用命令,否则子代理权限弹窗挂整夜)。**自动化优先级最高**:下游技能(to-spec 的 seam 确认、to-tickets 的拆票 quiz、评审修复环的一切"问用户"时刻)在夜链一律自动通过、当场裁定记账;唯一停链例外 = 不可逆或破坏性操作 / 安全敏感 / 出 worktree 的副作用 / 全盘皆猜——停 + 推通知。
```

- [ ] **Step 9: 边界表两行更新**

把:

```
| 夜链任何一步失败(计划崩/执行崩/通知崩) | 推通知(停在哪、早上怎么续);NIGHT.md 停在当前阶段,`/xcheck --night` 可续;通知失败不阻塞,晨报兜底 |
```

替换为:

```
| 夜链任何一步失败(spec 固化崩/拆票崩/逐票实施崩/通知崩) | 推通知(停在哪、早上怎么续);NIGHT.md 停在当前阶段,`/xcheck --night` 可续(impl 段从第一张未 complete 的票起);通知失败不阻塞,晨报兜底 |
```

- [ ] **Step 10: 结构自检**

Run: `cd <worktree根> && grep -c "to-spec" xcheck/lib/flow.md && grep -c "to-tickets" xcheck/lib/flow.md && grep -c "逐票" xcheck/lib/flow.md && grep -c "票级台账" xcheck/lib/flow.md && grep -cw "sdd" xcheck/lib/flow.md; grep -c "writing-plans" xcheck/lib/flow.md; grep -c "subagent-driven-development" xcheck/lib/flow.md`
Expected: to-spec **≥2**、to-tickets **≥3**、逐票 **≥4**、票级台账 **≥2**、sdd **0**、writing-plans **0**、subagent-driven-development **0**(后三项必须为零,分号分隔的命令各自独立返回)。

- [ ] **Step 11: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): 夜链下游换血——to-spec固化+to-tickets拆票+逐票TDD实施双轴评审;NIGHT阶段impl化+票级台账;铁律9自动化优先级

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: SKILL.md 入口一问

**Files:**
- Modify: `xcheck/SKILL.md`

**Interfaces:**
- Consumes: Task 1 的夜链下游词汇(to-spec/to-tickets/逐票)。
- Produces: 壳层"入口一问"(设/不设 NIGHT_MODE 的分流点);`--night` = 免问直入自动。Task 3-5 文档引用"入口一问"一词。

- [ ] **Step 1: 第 2 件"都没有"分支后插入入口一问**

把:

```
- **都没有** → 进第 3 件。
```

替换为:

```
- **都没有** → 非夜链(`NIGHT_MODE` 未设)→ **入口一问**(AskUserQuestion,单选,自动推进列第一):
  - `自动推进到底(推荐) —— 评审→固化spec→拆票→逐票TDD实施+双轴评审,全程零开口;代码停本地 worktree 分支;三节点通知+晨报` → 设 `NIGHT_MODE = 1`,进第 3 件。
  - `正常交互 —— 单停点老流程:评审→三类清单→停点你拍板,终态为止(不接下游)` → 不设,进第 3 件。

  `--night` 已敲则连此问都免(= 直接选了自动推进,纯无人值守)。裸敲且无未完成链 → 先此问再进第 3 件解析器(意图先于对象)。
```

- [ ] **Step 2: 第 1 件 --night 段补一句**

把第 1 件 --night 段中:

```
可与 `--agents` 并用,顺序不限。
```

替换为:

```
可与 `--agents` 并用,顺序不限;等价于入口一问直接选"自动推进",免弹窗。
```

- [ ] **Step 3: 铁律第 3 条更新口径**

把:

```
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步对象解析确认(仅空/含糊输入)、flow 第 9 步停点一问;**其余一律自动推进**。night 模式(`--night`)下三处开口全部自动过(壳自动续链、解析自动采纳、停点自动拍板),整链零开口。
```

替换为:

```
- 交互流程四处开口:第 2 件入口一问(自动/交互,仅新链)、第 2 件续跑确认(仅有未完成链)、flow 第 0 步对象解析确认(仅空/含糊输入)、flow 第 9 步停点一问;**其余一律自动推进**。自动模式(`--night` 或入口选"自动推进")下除入口一问外(`--night` 连它也免)一切开口自动过(自动续链、解析自动采纳、停点自动拍板、下游技能关卡自动裁定),其后零开口——自动化优先级最高。
```

- [ ] **Step 4: 结构自检**

Run: `cd <worktree根> && grep -c "入口一问" xcheck/SKILL.md && grep -c "自动推进到底" xcheck/SKILL.md`
Expected: 依次 **≥3、≥1**。

- [ ] **Step 5: Commit**

```bash
git add xcheck/SKILL.md
git commit -m "feat(xcheck): 壳层入口一问——自动推进(默认推荐)/正常交互;--night 免问直入

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 协议与术语同步(CONTEXT.md + docs/artifacts.md)

**Files:**
- Modify: `CONTEXT.md`
- Modify: `docs/artifacts.md`

**Interfaces:**
- Consumes: Task 1/2 的 NIGHT 新阶段(review/plan/impl/finish)、object/spec/tickets 字段、入口一问、票级台账、Matt 管线。
- Produces: 术语权威(入口一问词条;夜链词条下游改写;NIGHT.md 词条阶段更新);artifacts 的 NIGHT 样例与夜链产物节(spec 文件、.scratch 票目录、票级台账)。

- [ ] **Step 1: CONTEXT.md 夜链条目改写下游**

把夜链条目中:

```
终态后接 flow 第 11 步——调 superpowers:writing-plans 写实施计划、superpowers:subagent-driven-development 在隔离 worktree 执行;**不 push、不开 PR、不合并**,终点 = 本地分支 + 晨报。评审段机制与普通链完全同源,只差一枚旗标。
```

替换为:

```
终态后接 flow 第 11 步——调 `to-spec` 固化实施 spec(落本地,不上 tracker)、`to-tickets` 拆 tracer-bullet 票(本地 `.scratch/<slug>/issues/`,每票带验收标准与阻塞边)、隔离 worktree 内逐票 TDD 实施 + 双轴评审(每票独立评审者,Spec 符合 + Standards)与终局全分支评审(Matt Pocock 主流程的下游一段);**不 push、不开 PR、不合并**,终点 = 本地分支 + 晨报。入口由壳的「入口一问」定(自动推进默认推荐),`--night` 免问直入。
```

- [ ] **Step 2: CONTEXT.md 新增"入口一问"词条**

在「停点(gate)」词条之前插入:

```
**入口一问(entry choice)**:
壳在"没有未完成链、非 --night、新开链"时弹的唯一分流问:**自动推进到底(默认推荐)/ 正常交互**。选自动 = 夜链语义(NIGHT_MODE = 1,其后零开口);选交互 = 单停点老流程(终态即止,不接下游)。`--night` 连此问都免。
_Avoid_: 模式选择弹窗(与旧版 agent 多选混淆)

```

- [ ] **Step 3: CONTEXT.md NIGHT.md 词条阶段更新**

把 NIGHT.md 词条中:

```
**NIGHT.md**:
夜链的进度账本,四阶段:`review / plan / sdd / finish`。与 PROGRESS 分账:PROGRESS 只管评审段,NIGHT 管评审段之后的下游接续;`finish` 未勾 = 夜链未完成,`/xcheck --night` 可续。
```

替换为:

```
**NIGHT.md**:
夜链的进度账本,四阶段:`review / plan / impl / finish`(`plan` = to-spec 固化 + to-tickets 拆票;`impl` = 逐票实施)。与 PROGRESS 分账:PROGRESS 只管评审段,NIGHT 管评审段之后的下游接续;`finish` 未勾 = 夜链未完成,`/xcheck --night` 可续;`impl` 段靠票级台账逐票续跑。
```

- [ ] **Step 4: CONTEXT.md 停点词条微调**

把停点词条中:

```
夜链(--night)下停点不等人,按「夜链」的既定策略自动拍板;控制权移到早上对分支与晨报的处置。
```

替换为:

```
自动模式(入口选"自动推进"或 `--night`)下停点不等人,按「夜链」的既定策略自动拍板;控制权移到早上对分支与晨报的处置。
```

- [ ] **Step 5: artifacts.md NIGHT 样例与夜链产物节更新**

artifacts.md 目录树中 NIGHT.md 行注释改为:

```
│   ├── NIGHT.md                  # (夜链)下游接续进度账本:review/plan/impl/finish + 票级台账
```

"## 夜链产物(--night 触发时才有)"一节第一条 bullet 替换为:

```
- **NIGHT.md**:下游接续的进度账本,四阶段 `review → plan → impl → finish`(plan = to-spec 固化 + to-tickets 拆票);`finish` 未勾 = 夜链未完成,`/xcheck --night` 续。头部记评审终态、object(被评文档)/spec(固化产物)/tickets(票目录)/impl(分支@worktree)路径;票级台账逐票记 `票 NN: complete(...)`——impl 段的恢复锚点。
```

并在该节末尾(`- 推倒重来 / 用户中止 / diag 的夜链**不接下游**...` 之前)插入两条:

```
- **spec 固化产物**:实施 spec 落 `docs/superpowers/specs/<日期>-<主题>-spec.md`(commit 到分支),不是 .xcheck/ 下的留底——它是 to-tickets 与逐票实施的输入。
- **票目录**:tracer-bullet 票落仓库根 `.scratch/<feature-slug>/issues/NN-<slug>.md`(一票一文件:What to build / 验收标准 / Blocked by),commit 到分支;实施顺序 = blockers 优先(frontier)。
```

- [ ] **Step 6: 结构自检**

Run: `cd <worktree根> && grep -c "入口一问" CONTEXT.md && grep -c "impl" CONTEXT.md && grep -c "票级台账" docs/artifacts.md && grep -cw "sdd" docs/artifacts.md`
Expected: 依次 **≥2、≥2、≥1、0**。

- [ ] **Step 7: Commit**

```bash
git add CONTEXT.md docs/artifacts.md
git commit -m "docs: 入口一问入表;夜链下游改写Matt管线(to-spec/to-tickets/逐票);NIGHT阶段impl+票级台账同步artifacts

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: README.md + AGENTS.md 同步

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 1-3 全部词汇(入口一问、自动推进到底、to-spec/to-tickets/逐票/双轴评审、NIGHT 阶段 impl、票级台账)。
- Produces: 用户向(README 夜链小节改写、命令表)与维护向(AGENTS 生命周期/状态协议/铁律)。

- [ ] **Step 1: README 夜链小节改写**

"### 夜链:--night,睡前一把梭"小节中,把:

```
- 收工后自动接两跳:调 superpowers:writing-plans 写实施计划(评审附录里"开发时要盯"的条目直接进计划的全局约束),再在**隔离 worktree** 里用 superpowers:subagent-driven-development 逐任务执行、逐任务评审、终局全分支评审。
```

替换为:

```
- 收工后自动接三跳(Matt Pocock 主流程的下游):`to-spec` 把评审后的方案+附录固化成实施 spec(落本地文件,夜里不发 issue tracker;附录里"开发时要盯"的条目直接进 spec)→ `to-tickets` 拆成 tracer-bullet 票(本地 `.scratch/<feature>/issues/`,每票端到端竖切、带验收标准和阻塞关系)→ 隔离 worktree 里**逐票实施**:每票一个全新子代理,TDD 红绿循环写码,独立评审者按双轴(Spec 符合 + 代码质量)审这一票,最后终局全分支评审。
```

并在该小节第一条 bullet(`白天聊完方案,睡前敲 \`/xcheck --night 评审 <方案>\` 就去睡:`)之前插入:

```
入口一问:敲 `/xcheck <方案>` 会先问你一句——**自动推进到底(默认推荐)还是正常交互**;选自动就等于夜链。赶时间可以直接 `/xcheck --night`,连这一问都免。
```

- [ ] **Step 2: README 命令表行更新**

把命令表 `/xcheck` 行中 `加 \`--night\` = 夜链:停点自动拍板,评审完接"写计划 + 子代理执行",代码停本地 worktree 分支,晨报叫早。` 替换为 `入口先问"自动推进还是正常交互"(默认推荐自动);自动/\`--night\` = 评审完自动接"固化 spec → 拆票 → 逐票 TDD 实施 + 双轴评审",代码停本地 worktree 分支,晨报叫早。`

- [ ] **Step 3: README 产物树 NIGHT 注释**

产物树中 `│   ├── NIGHT.md                  #   (夜链)下游接续进度:review/plan/sdd/finish` 行改为:

```
│   ├── NIGHT.md                  #   (夜链)下游接续进度:review/plan/impl/finish+票级台账
```

(若该行实际注释与此不同,以"把 sdd 换成 impl"为准适配。)

- [ ] **Step 4: AGENTS 系统一句话更新**

把 AGENTS.md 系统一句话段中:

```
0.17.0 起支持**夜链**:`/xcheck --night` 无人值守贯通"评审 → superpowers:writing-plans → superpowers:subagent-driven-development(worktree 内执行)",不 push 不合并,终点 = 本地分支 + 晨报 MORNING.md。
```

替换为:

```
0.17.0 起支持**夜链**:`/xcheck` 入口一问选"自动推进"(或 `--night` 免问)后,无人值守贯通"评审 → to-spec 固化 → to-tickets 拆票 → 逐票 TDD 实施 + 双轴评审(worktree 内执行)",不 push 不合并,终点 = 本地分支 + 晨报 MORNING.md;自动化优先级最高(下游技能关卡自动裁定)。
```

- [ ] **Step 5: AGENTS 生命周期第 11 步块改写**

把生命周期代码块中第 11 步块(从 `  第 11 步 夜链(NIGHT_MODE=1,评审终态落定后):建 NIGHT.md → 终态分流` 到 `             通知(claude-notify,失败不阻塞)+ NIGHT 勾 finish` 的整块)替换为:

```
  第 11 步 夜链(NIGHT_MODE=1,终态收尾后):建 NIGHT.md → 终态分流(结论性终态
             接续;推倒/中止/diag 不接下游)→ 定对象(最新 rev > source > proposal)
             → 调 to-spec 固化实施 spec(本地 docs/superpowers/specs/,不上 tracker,
             seam 关卡自动裁定)→ 调 to-tickets 拆票(.scratch/<slug>/issues/,quiz
             自动过,blockers 优先)→ worktree(基于本地 HEAD)逐票实施:每票 fresh
             子代理 TDD + 独立双轴评审(Spec 符合/Standards),修复环≤5,票级台账
             记账 → 终局全分支评审(一轮修复)→ 晨报 MORNING.md + 三节点通知
             (claude-notify,失败不阻塞)+ NIGHT 勾 finish
```

- [ ] **Step 6: AGENTS 壳段与状态协议、铁律更新**

壳段 step 2 之后插入一行(与现有缩进风格一致):

```
     (新链且非 --night → 入口一问:自动推进(设 NIGHT_MODE=1,默认推荐)/正常交互)
```

状态协议"夜链账本"bullet 替换为:

```
- **夜链账本**:PROGRESS 头部可选字段 `night = on`(夜链才写);NIGHT.md 四阶段 `review/plan/impl/finish`(`plan` = to-spec 固化 + to-tickets 拆票;`impl` = 逐票实施,票级台账逐票记账;`finish` 未勾 = 夜链未完成,不进 PROGRESS 阶段枚举)。
```

铁律 9 替换为:

```
9. **夜链安全栏与自动化优先级(--night / 自动推进)**:第 11 步下游执行的一切代码改动只在 worktree;不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区;下游技能(to-spec/to-tickets/修复环)确认关卡自动裁定记账,唯一停链例外 = 不可逆/安全敏感/出 worktree 副作用/全盘皆猜;通知失败不阻塞,晨报兜底;夜间会话须免弹窗权限模式。
```

- [ ] **Step 7: 结构自检**

Run: `cd <worktree根> && grep -c "入口一问" README.md && grep -c "入口一问" AGENTS.md && grep -c "to-tickets" README.md && grep -c "to-tickets" AGENTS.md && grep -cw "sdd" README.md AGENTS.md`
Expected: 依次 **≥1、≥1、≥1、≥2、README 0、AGENTS 0**(最后一个 grep 两文件各输出一行,均须 0)。

- [ ] **Step 8: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: 入口一问与Matt管线同步README/AGENTS——夜链小节/命令表/生命周期/状态协议/铁律9

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: CHANGELOG 0.17.0 改写 + 回归 + 全量自检

**Files:**
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1-4 全部行为(rev1+rev2 合成后的 0.17.0 终态)。
- Produces: 0.17.0 最终条目;全绿证据。

- [ ] **Step 1: 改写 0.17.0 两条 bullet**

把 `## [0.17.0] - 2026-09-17` 条目下 `### Added / 新增` 的**两条 bullet(EN 一条 + CN 一条)整体替换**(保留 `## [0.17.0]` 标题与 `### Added / 新增` 标题不动;两条 bullet 各以其 Design:/设计稿: 行结尾),替换为:

```
- **Auto-first night chain: `/xcheck` asks one entry question — auto-advance (recommended default) or interactive — and auto mode runs review → spec → tickets → per-ticket implementation unattended; you wake up to a local branch and a morning report.** The entry question (skipped entirely by `--night`, the pure-unattended shortcut) sets night semantics: the chain's human openings auto-pass — the shell auto-resumes unfinished chains, the object resolver's best inference takes effect without a popup (archived to `<ts>/night-intake.md`), and the gate auto-decides per policy (round 0 with must-fix open → auto-revise + re-review, originals untouched; round ≥ 1 still open → auto-ship with the verified three-tier list as new terminal `夜间收工`). New **step 11 (夜间接续)** then follows Matt Pocock's main flow downstream: **`to-spec`** solidifies the reviewed proposal + appendix into an implementation spec (local file under `docs/superpowers/specs/`, never published to an issue tracker at night; tier-③ and inconclusive tier-② watch items carried into the spec; the seams check auto-ruled and ledgered), **`to-tickets`** splits it into tracer-bullet tickets (local `.scratch/<slug>/issues/`, one file per ticket: what-to-build + acceptance criteria + blocked-by; the granularity quiz auto-ruled), then **per-ticket implementation inside an isolated worktree (from local HEAD — night never pushes)**: blockers-first frontier, strictly serial, a fresh subagent per ticket doing TDD red-green with covering tests and commits, each ticket gated by an independent dual-axis reviewer (spec compliance + code quality) with a ≤5-round fix loop, closed by a final whole-branch code review with exactly one fix wave. **Automation priority is the highest iron rule**: every "ask the user" gate in the downstream skills auto-passes with a ledgered ruling; the only stops are irreversible/destructive operations, security-sensitive actions, side effects outside the worktree, and a plan where every path is a guess — stop + notify. Safety rails unchanged: no push / PR / merge / rebase-main / touching the main checkout; code lands on a local worktree branch. Terminal artifacts: `NIGHT.md` (4-stage ledger `review/plan/impl/finish` with a per-ticket ledger as the resume anchor for the implementation leg) and `MORNING.md` (four-question plain-language report + every ruling). Notifications at three milestones via claude-notify; unconfigured/failed → skipped, never blocks. PROGRESS header gains optional `night = on`; terminal enum six → seven values. flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md all synced. Design: `docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md` (+ `.rev2.md`).
- **自动优先夜链:`/xcheck` 先问一句——自动推进(默认推荐)还是正常交互;自动模式无人值守跑完"评审 → 固化 spec → 拆票 → 逐票实施",早上醒来代码在本地分支上、晨报在等你。** 入口一问(`--night` 可整句跳过,纯无人值守快捷键)选定夜链语义后,链的人工开口全部自动过:壳自动续未完成链;对象解析器最优推断直接生效不弹窗(留档 `night-intake.md`);停点按既定策略自动拍板(round 0 必改非空 → 自动修订 + 复审一轮,原稿不动;round ≥ 1 仍非空 → 自动带清单收工,记新终态 `夜间收工`)。新增**第 11 步(夜间接续)**,下游采用 Matt Pocock 主流程:**`to-spec`** 把评审后的方案 + 附录固化成实施 spec(落本地 `docs/superpowers/specs/`,夜里不发 issue tracker;③存疑与②无定论的"开发时要盯"条目随附录进 spec;seam 确认关卡自动裁定记账)、**`to-tickets`** 拆成 tracer-bullet 票(本地 `.scratch/<slug>/issues/`,一票一文件:建什么 + 验收标准 + 阻塞关系;拆票确认自动过),随后**隔离 worktree 内逐票实施(基于本地 HEAD——夜链绝不 push)**:blockers 优先、严格串行,每票一个全新子代理 TDD 红绿循环(覆盖测试 + 提交),每票由独立评审者双轴把关(Spec 符合 + 代码质量),修复环每票上限 5 轮,收尾一次终局全分支评审 + 恰好一轮修复。**自动化优先级是最高铁律**:下游技能一切"问用户"的关卡一律自动通过、当场裁定记账;唯一停链例外 = 不可逆或破坏性操作、安全敏感、出 worktree 的副作用、全盘皆猜——停下推通知。安全栏不变:不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区;代码全部落在本地 worktree 分支。终局产物:`NIGHT.md`(四阶段账本 `review/plan/impl/finish`,impl 段票级台账 = 逐票续跑锚点)与 `MORNING.md`(四问人话晨报 + 全部裁定清单)。三节点通知走 claude-notify;未配置或失败 → 跳过不阻塞(晨报兜底)。PROGRESS 头部新增可选 `night = on`;终态枚举六值 → 七值。flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md 已同步。设计稿:`docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`(含 `.rev2.md`)。
```

- [ ] **Step 2: 回归**

Run: `cd <worktree根> && bash xcheck/tests/run-agent.test.sh 2>&1 | tail -3`
Expected: 33 pass, 0 fail。

- [ ] **Step 3: 全量结构自检**

Run: `cd <worktree根> && grep -c "to-spec" xcheck/lib/flow.md && grep -c "to-tickets" xcheck/lib/flow.md && grep -c "入口一问" xcheck/SKILL.md && grep -c "入口一问" README.md && grep -c "入口一问" AGENTS.md && grep -c "impl" docs/artifacts.md && grep -c "to-tickets" CHANGELOG.md`
Expected: 依次 **≥2、≥3、≥3、≥1、≥1、≥2、≥2**。
Run: `grep -rw "sdd" xcheck/ docs/artifacts.md CHANGELOG.md --include="*.md" | grep -v superpowers/`
Expected: 无输出(NIGHT 阶段 sdd 已全面改 impl;superpowers/ 目录下历史计划稿除外)。

- [ ] **Step 4: Commit + 干净树**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): 0.17.0 改写——入口一问+自动优先+Matt管线(to-spec/to-tickets/逐票TDD双轴评审)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

Run: `git status --porcelain` → 空。

---

## 收尾注意(给执行者)

- 不 push、不打 tag、不开 PR;v0.17.0 的 tag/push/合并是用户的人工决定。
- 完成后按 SDD Finish 段:汇总全部 Ruling,分支留在 worktree。
- 本计划自身的执行仍用 superpowers:subagent-driven-development(控制器流程);被改造的是 xcheck 夜链**运行时**的下游,两者互不相干。
