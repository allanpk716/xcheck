# xcheck 夜链(night chain)设计稿 —— /xcheck --night 无人值守贯通"评审 → 计划 → 子代理执行"

- 日期: 2026-09-17
- 版本目标: v0.17.0
- 状态: 已与用户对齐核心决策(当日对话),spec 落盘后直接进实施(用户预授权:"同意,继续推进,明天起来看结果")
- 关联: [2026-09-16-single-gate-autochain](2026-09-16-xcheck-single-gate-autochain-design.md)(单停点自动链)、[2026-09-16-verdict-delivery](2026-09-16-xcheck-verdict-delivery-design.md)(结论人话交付)

## 0. 问题与目标

用户夜里聊完方案敲 `/xcheck`,评审本身已全自动,但:

1. 第 9 步停点一问没人答,链停在 gate,半夜挂机;
2. 终态后要人手动接 superpowers:writing-plans(写实施计划)和 superpowers:subagent-driven-development(子代理执行计划);
3. 早上醒来只看到一份评审清单,计划与代码一行没动。

目标:`/xcheck --night <方案>` 一次触发,夜里无人值守跑完 **评审(含一轮自动修订复审)→ 实施计划 → 子代理执行(worktree 隔离)**,早上起来代码已经提交在**本地分支**上,附晨报与推送通知。

## 1. 用户已拍板的决策

| # | 决策 | 内容 |
|---|---|---|
| D1 | 停点自动化 | round 0 必改非空 → **自动修订一轮再评**(第 10 步照走);round 1 仍必改非空 → **自动带清单进开发**,不再修。夜里绝不走到 m=2 三选。 |
| D2 | 夜里收尾 | 代码**停在本地 worktree 分支**:不 push、不开 PR、不合并。finishing-a-development-branch 的选项留到早上人工走。 |
| D3 | 入口形态 | `/xcheck` 加 `--night` 布尔旗标,不新建包装技能。 |

## 2. 范围

**改**: `xcheck/SKILL.md`、`xcheck/lib/flow.md`、`CHANGELOG.md`、`CONTEXT.md`、`README.md`、`AGENTS.md`、`docs/artifacts.md`。
**不动**: run-agent.sh / detect.sh / agents.toml / prompts/* / carrier 文档 / context-intake.md 本体(只在 flow.md 里给 night 分支规则)。
**下游依赖**(外部技能,本仓库不实现、只调用): `superpowers:writing-plans`、`superpowers:using-git-worktrees`、`superpowers:subagent-driven-development`、`superpowers:finishing-a-development-branch`。

## 3. 设计

### 3.1 入口:壳层改动(SKILL.md)

壳仍是四件事,夜链折进现有三件:

1. **抠旗标**(原"抠 --agents"):顺带抠 `--night`(布尔,无值 token;出现即从 `$ARGUMENTS` 删除并设 `NIGHT_MODE = 1`)。`--night --agents a,b,c` 可并用。
2. **查未完成链**(弹窗 0 扩容):未完成 = ①`PROGRESS.md` 终态空(照旧);②`NIGHT.md` 存在且其 `finish` 未勾(夜链未收尾)。取最大 ts。`NIGHT_MODE = 1` → **不弹窗,自动续最新未完成链**;否则弹窗选项加一项 `续跑夜链 <ts>(停于:NIGHT.md 第一个未勾阶段)`。
3. 路由:不变。night 模式下第 3 件 B 分支(空/含糊)照旧设 `MODE = auto`。
4. **转派**:传给 flow.md 的变量加 `NIGHT_MODE`(若有)。

`argument-hint` 更新为 `[--night] [--agents a,b,c] [<问题描述或方案>]`。

### 3.2 停点自动化:flow.md 第 0 / 9 / 10 步的 night 分支

**第 0 步(night = on 且 MODE = auto)**:解析器照跑,但**确认窗不弹**——采用阶梯最优推断,把"本应过目的解析结果"(对象+模式+背景原话;讨论型含固化稿全文)落 `<ts>/night-intake.md`,对话播报一行:"夜间模式:已按推断锁定评审对象(<一句话>),留档 <路径>,明早可改"。阶梯落到"反问"档(对话完全无线索)→ 停链 + 推送通知(夜里不能瞎猜对象)。

**第 9 步(night = on)**:停点一问**不问**,按 D1 自动决策:

| 局面 | 自动决策 | 终态 |
|---|---|---|
| 必改空,round 0 | (本来就不问) | `无需修订` |
| 必改空,round ≥ 1 | (本来就不问) | `收敛(m 轮修订)` |
| 必改非空,round 0 | 自动"修订再评" → 进第 10 步 | —(复审环继续) |
| 必改非空,round ≥ 1 | 自动"带清单进开发" | `夜间收工`(新终态,见 3.5) |
| 防御:必改非空且到 m=2(正常到不了) | 自动"按现状收工" | `夜间收工` |

每次自动决策在对话播报一行("夜间模式自动选了 X,因为 Y"),gate 勾选照常。

**第 10 步**:机制不变;复审环的新 PROGRESS 头部**继承 `night = on`**,新环第 9 步继续按上表自动决策。

**停点纪律铁律措辞更新**:全链开口从"三处"改为"非 night 三处 + night 模式下零开口(第 9 步自动按 D1 决策;第 0 步自动采纳解析结果)"。

### 3.3 第 11 步:夜间接续(flow.md 新增,night = on 且评审段终态落定后执行)

**第 11.0 步 · 建账**:复用评审 ts 目录,建 `NIGHT.md`(格式见 3.6),勾 `review`,记终态与 spec 路径。

**第 11.1 步 · 终态分流**:

| 评审终态 | 夜链动作 |
|---|---|
| `无需修订` / `收敛(*)` / `夜间收工` | 接续(进 11.2) |
| `推倒重来` / `用户中止` | **不接下游**:NIGHT 记终态(带"未接下游"注记),勾 finish,推通知("评审判定方向性错误/链被中止,没写代码,晨报 <路径>"),停 |
| diag 模式 / `完成(diag)` | 同上,不接下游(diag 结论不是实施 spec) |

**第 11.2 步 · 定 spec**:spec = 最新 `.rev<m>.md`(取最大 m)> `source` 文件路径 > `<ts>/proposal.md`(inline / 讨论型固化稿)。该文档文末已带评审附录(附录本来就是主交付物,spec 连附录一起交给下游)。

**第 11.3 步 · 写计划**:推送通知①("评审终态:<人话一句>。开始写实施计划。")→ 调 `superpowers:writing-plans`:
- spec = 11.2 定的文档路径;
- 额外要求写进计划:评审附录的 **③存疑条目 + ②无定论条目进入计划 Global Constraints 的"开发时要盯"小节**(每条带触发点 + 命中动作"停下反馈,别默默绕过");
- 计划落 `docs/superpowers/plans/YYYY-MM-DD-<主题>.md`;
- writing-plans 结尾的执行二选一**自动选 subagent-driven**,不问。
- 完成:NIGHT.md 勾 `plan`,记 plan 路径。

**第 11.4 步 · 子代理执行**:推送通知②("计划落盘:<路径>,N 个任务。开始在隔离 worktree 执行,不 push 不合并。")→ 先调 `superpowers:using-git-worktrees` 建 worktree(**必须基于当前本地 HEAD**,夜链不 push,origin 上没有 spec/plan 提交)→ 调 `superpowers:subagent-driven-development` 按计划逐任务执行。夜链给 SDD 的预授权边界(写进其上下文):
- 允许:worktree 内实施/测试/本地 commit/fix 环/终局全分支评审;
- 预先裁定:一切涉及 push、开 PR、合并、rebase 主分支的停点 → 一律选"保留分支,早上人工定";其余按 SDD 自己的"裁决不停等"纪律办,裁决记 ledger;
- 完成:NIGHT.md 勾 `sdd`,记 workspace 与分支名。

**第 11.5 步 · 终局收尾(finish)**:
- 写晨报 `<ts>/MORNING.md`:四问结构(【评了什么】【改了什么】【执行了什么】【早上要决定什么】)+ SDD ledger 全部 Ruling 清单 + 分支名 + worktree 路径 + 计划/spec/产物路径。晨报是夜链的人话总交付,自包含、不要求翻别的文件才能懂要决定什么。
- 推送通知③:"夜链完成:<一句话>。分支 <name> 待你处理,晨报 .xcheck/<ts>/MORNING.md。"失败变体同理(含停在哪一步、早上怎么续)。
- NIGHT.md 勾 `finish`。夜链结束。
- **早上人工走** `superpowers:finishing-a-development-branch`(合并/PR/保留,人拍板)。

### 3.4 通知

三个节点(11.3 前、11.4 前、11.5):用 claude-notify(Pushover + Windows Toast)。`PUSHOVER_TOKEN`/`PUSHOVER_USER` 未配或推送失败 → **跳过不阻塞**(晨报照写,MORNING.md 是兜底交付)。通知正文一句话人话,不带机器词。

### 3.5 状态协议变化

- **PROGRESS.md 头部新增字段 `night = on`**(仅夜链写;非夜链完全不变)。恢复模式照旧,night 字段随恢复继承。
- **终态枚举六值 → 七值**:新增 `夜间收工`(night=on 时自动带清单收工/按现状收工的终态;与 `用户不修` 区分——那是用户在场时的决定,这是夜间策略的自动决策,账要记实)。同步 AGENTS.md 状态协议、CONTEXT.md 终态词条、docs/artifacts.md。
- **NIGHT.md 阶段枚举(新)**:`review, plan, sdd, finish`(顺序固定);`finish` 未勾 = 夜链未完成。夜链阶段**不进** PROGRESS 的 11 值枚举——PROGRESS 只管评审段,两本账分开。

### 3.6 NIGHT.md 格式

```markdown
# NIGHT · <ts>
night = on
review_ts = <ts>               # 评审环 ts(复审链取最新环)
终态 = 夜间收工                # 评审段终态(七值之一)
spec = C:/…/xxx.rev1.md        # 11.2 定的 spec 绝对路径
plan = docs/superpowers/plans/2026-09-17-xxx.md   # 落盘后填,未到填 -
sdd = <分支名>@<worktree 路径> # 执行段,未到填 -
note = 未接下游(推倒重来)     # 可选注记

## 阶段(完成即打勾)
- [x] review
- [ ] plan
- [ ] sdd
- [ ] finish
```

**恢复语义**:finish 未勾 = 未完成。续跑定位:review 段靠 PROGRESS(已有);plan 段 = NIGHT `plan` 未勾(计划文件可能半截 → 重写覆盖);sdd 段 = SDD 自己的 ledger(已有);三段各有盘上锚点,不依赖会话记忆。

### 3.7 夜链安全栏(铁律)

1. **不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区**——一切代码改动只发生在 worktree。
2. 评审段原有铁律全部不变(实验禁改业务代码/禁联网/禁部署;修订只写新文件,原稿正文不动)。
3. 子代理执行段允许改代码,**仅限 worktree 内**;SDD 四停类问题(push/PR/合并类)一律预先裁定为"保留分支"。
4. 通知失败/未配置不阻塞夜链;晨报 MORNING.md 是兜底交付。
5. **操作前提**(写进 SKILL.md 提示):夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条 Bash 权限弹窗能挂一整夜。

### 3.8 边界与异常(补进 flow.md 边界表)

| 异常 | 处理 |
|---|---|
| 夜间解析器落到"反问"档(无线索) | 停链 + 推通知,不瞎猜对象 |
| writing-plans 中途崩 | NIGHT `plan` 未勾;早上 `/xcheck --night` 续:重写计划(覆盖半截文件) |
| SDD 中途崩 | ledger 在盘;`/xcheck --night` 续跑,SDD 自身恢复语义接管 |
| 夜链任何一步失败 | 推通知(停在哪、早上怎么续),NIGHT 停在当前阶段,不硬闯 |
| 早上裸敲 `/xcheck`(无 --night)遇未完成夜链 | 弹窗 0 多一项"续跑夜链";不自动续(人在场,要确认) |
| 夜链跑完,用户早上不满意 | 分支没合没推,`git worktree` 里直接弃或改;MORNING.md 有全部裁决可追责 |

## 4. 非目标

- 不做定时触发(cron);夜链是"聊完随手敲"的形态。
- 不做 diag → 实施的贯通(diag 结论不是实施 spec)。
- 不自动合并/push/开 PR(D2)。
- 不改 run-agent.sh / 冒烟 / 选集逻辑。
- 推倒重来后不自动重新设计方案——那是人的决定。

## 5. 测试与验收

- `bash xcheck/tests/run-agent.test.sh` 全绿(未动脚本,回归确认)。
- 结构自检(验收命令,进实施计划):
  - `grep -c "night" xcheck/SKILL.md` ≥ 3(旗标/扫描/转派)
  - `grep -c "第 11 步" xcheck/lib/flow.md` ≥ 1;`grep -c "夜间收工" xcheck/lib/flow.md` ≥ 2
  - `grep -c "夜间收工" AGENTS.md docs/artifacts.md CONTEXT.md` 各 ≥ 1
  - `grep -c "NIGHT.md" docs/artifacts.md` ≥ 1
- 文档五处同步齐(CHANGELOG 0.17.0 条目、CONTEXT 新词条、README 命令表与夜链小节、AGENTS 生命周期与状态协议、artifacts 新产物)。
- 版本 tag v0.17.0 与 push **留给早上人工**(夜链安全栏同样约束本次实施)。

## 6. 实施顺序(给 writing-plans 的输入)

1. flow.md:night 分支(第 0/9/10 步)+ 第 11 步 + PROGRESS night 字段 + 停点纪律措辞 + 边界表 + 铁律。
2. SKILL.md:旗标解析 + 未完成链扫描扩容 + 转派带 NIGHT_MODE + argument-hint + 权限提示。
3. 文档五处:CHANGELOG / CONTEXT / README / AGENTS / docs/artifacts.md。
4. 回归测试 + 结构自检 + 晨报(MORNING.md 由本次夜链的 11.5 步产出)。
