# .xcheck/ 产物解读 —— 给 AI agent 的使用向说明

你在某个项目里遇到了 `.xcheck/` 目录,说明这个项目用过 **xcheck**(Claude Code 的异构盲评 skill,仓库见其 [README](../README.md))。本文告诉你:目录里每个文件是什么、怎么判断一条评审链跑到哪了、你能替用户做什么、什么绝对不能做。术语权威定义见 xcheck 仓库 [CONTEXT.md](../CONTEXT.md)。

---

## 一眼判断

读**时间戳最大的目录**下的 `PROGRESS.md`:

- `## 终态` 段**有值** → 这条链已结束。**review 链**的结论在 `<ts>/SUMMARY.md` 置顶的「结论区」;**diag 链**的 SUMMARY 是综合诊断长文(共识根因/分歧/存疑/建议),没有结论区。
- `## 终态` 段**为空**且有未勾选阶段 → 链未完成(中断/崩溃)。**让用户重新敲 `/xcheck`**,skill 自己会发现并弹"续跑/新开";你不要手工替它续。
- `<ts>/NIGHT.md` 存在且其 `finish` 未勾 → 这是一条**夜链**且未收尾(评审段可能已终态);让用户重敲 `/xcheck --night` 续跑(自动,不弹窗),同样不要手工代跑。
- 目录里没有 `PROGRESS.md`(极旧版本产物)→ 视为已结束,静默忽略。

## 目录总览

```
.xcheck/
├── <ts>/                          # 一条链一个目录;ts = 本地时间戳 YYYYMMDD-HHMMSS;
│   │                              #   修订复审环是新的 <ts> 目录,prev 字段串成链
│   ├── PROGRESS.md                # ★ 链状态唯一权威(格式见下)
│   ├── SUMMARY.md                 # ★ 机器账:review = 结论区(置顶)+紧凑头+三分类;
│   │                              #   diag = 综合诊断长文+三分类(无结论区)
│   ├── proposal.md                # review 对象快照(评审开始时的原文,此后原文件被改不影响)
│   ├── input.md                   # diag 对象快照
│   ├── context.md                 # 背景原话(用户陈述/贴的材料,按来源摘录、不改写;有才建)
│   ├── prompt.txt                 # 指令层:喂给各家的 ≤2KB 指令(引用上面的内容文件)
│   ├── dialog-snippet.txt         # (diag 摄入路径)最近对话片段,摘录用
│   ├── <agent>.raw.out            # 该家原始输出原样留底
│   ├── <agent>.summary.md         # 该家结构化结论(格式见下)
│   ├── <agent>.exitcode           # 成败唯一权威(语义表见下)
│   ├── <agent>.raw.stdout/.raw.stderr   # supervisor 层的原始管道留底
│   ├── <agent>.cmd.txt            # 取证:实际执行的命令(%q 转义,可重放)
│   ├── <agent>.run.log            # supervisor 诊断:预检/击杀原因/耗时
│   ├── <agent>.failed.md          # 该家超时/失败的一行记录(有才建)
│   ├── <agent>.spawn.err          # wrapper 层被外部掐断的证据(罕见,有才建)
│   ├── night-intake.md            # (夜链)第 0 步解析推断留档(夜里不弹窗的"过目"替代)
│   ├── NIGHT.md                   # (夜链)下游接续进度账本:review/plan/impl/finish + 票级台账
│   ├── MORNING.md                 # (夜链)晨报:四问人话总交付 + 执行裁决清单(收尾才有)
│   ├── proposal.rev<m>.md         # 修订版(source=inline 时落这里;文件型落原文件同目录)
│   └── exp/                       # ②类实验的临时文件(脚本、输出),留底不删
├── smoke.txt / smoke-prompt.txt   # 冒烟固定文件(内容 marker "西瓜47")
├── <agent>.exitcode / .raw.* / .run.log / .cmd.txt   # 冒烟跑的 supervisor 产物
└── <agent>.failed.md              # 冒烟淘汰记录
```

xcheck 仓库自身已把 `.xcheck/` gitignore;**宿主项目没有这个保证**——若该项目没忽略它,提醒用户加进该项目的 `.gitignore`。`prompt.txt` 同目录下的 `<agent>.*` 五件套(exitcode/raw.stdout/raw.stderr/cmd.txt/run.log)是执行 supervisor 的产物,`.raw.out`/`.summary.md`/`.failed.md` 是搬运工的产物——两层都可能存在,别混。

## PROGRESS.md(链状态权威)

```markdown
# PROGRESS · <ts>
mode = review            # diag | review
selected = codex, pi     # 冒烟后幸存的最终选集
source = C:/…/xxx.md     # 原对象绝对路径 | inline(贴文)
round = 0                # 修订轮次;复审环从 1 起
prev = -                 # 复审链上一环的 ts;首轮 -
smoke_cfg = <sha256>     # 冒烟通过时 agents.toml 的 sha256(0.16.0;复审环跳冒烟的"配置未变更"凭据;未冒烟不记;复审环跳过时 smoke 勾选带注记)
night = on               # (夜链才有)夜间模式:停点自动决策、终态后接第 11 步;非夜链无此行

## 阶段(完成即打勾)
- [x] intake … - [ ] gate               # 11 阶段,顺序固定

## 终态
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户不修 | 夜间收工 | 用户中止 | 完成(diag))
```

- **阶段枚举**(顺序):`intake, detect, smoke, fanout, collect, synthesize, triage, verify, experiments, deliverable, gate`。`gate` 勾上 = 停点已答且链已落定。
- **续跑语义**:从第一个未勾阶段整段重做;已答的停点决策不跨恢复记忆(gate 未勾,恢复时重问)。
- **终态七值**怎么读:

| 终态 | 含义 |
|---|---|
| `收敛(N 轮修订)` | 修订 ≥1 轮后必改清零,修干净了 |
| `无需修订` | round 0 且必改项空(含 ①+② 真空,或剩余条目全被证伪/实验不成立) |
| `用户不修` | 必改项非空,用户选择**带着三类清单进开发**——问题仍然是真的,清单已附被评文档文末 |
| `夜间收工` | 夜链自动决策的带清单/按现状收工(语义同`用户不修`,但用户没在场——策略拍的板;代码在 worktree 分支,见 NIGHT.md) |
| `推倒重来` | 用户在 m=2 三选停点确认放弃方案(0.15.0 起仅此途径;细节改不干净不构成推倒) |
| `用户中止` | 用户主动停链 |
| `完成(diag)` | diag 模式自然终点(止于汇总+三分类,无验证链) |

## SUMMARY.md(机器账)

**review 链**的 SUMMARY 置顶「结论区」,五个字段全部机械拼装(零新判断);**diag 链**没有结论区,正文是 `synthesize-diag` 的综合输出(共识根因/分歧/存疑/综合判断建议)+ 三分类明细。

**结论区五字段**(review 专用):

1. **状态行**:`状态:✅ 可推进(必改项空)` 或 `状态:⚠️ 先修订再推进 —— 必改 N 条`(只由必改数决定,与各家裁决无关;"对不上"是故意留给用户的信号)。
2. **必改项**:①证实 + ②实验成立的条目,格式 `#n [来源][高·bug] 一句话 —— 证据:文件:行号 | 实验 exp/…`。
3. **各家裁决**:`codex=SUGGEST_CHANGES · pi=AGREE` 式一行。
4. **信号**:总判三定式(焦点共识/意见分裂/一边倒)+ DISAGREE 家数。
5. **统计**:`① n 条→x 证实/y 证伪/z 查无实据 · ② m 条→… · ③ k 条`。

其后是三分类明细区块:

- **① 可直接证实**:`#n [来源][严重度] 内容` + `判定:✅ 证实 —— 证据:文件:行号`(或 ❌ 证伪带反证、❓ 查无实据)。
- **② 可实验验证**:`#n [来源][严重度] 内容` + 验证目的/方法/预期 + `结果:成立 —— exp/…`(或不成立/无定论带原因)。
- **③ 存疑仅参考**:无编号,原样保留,带 ⚠️。

编号规则:①②类全流水编号(`#1、#2…`,先①后②),③不编号;`[高|中|低·bug|风险|遗漏]` 标签来自各家原评,`[未标]` 为兜底。**引用条目给用户听时说人话**(内容+谁提的+证据),别甩裸编号和 enum——那是机器账内部符号。

## 各家结构化结论(`<agent>.summary.md`)

- **review**:`裁决(AGREE | SUGGEST_CHANGES | DISAGREE)` / `逐条问题(位置+严重度)` / `理由`。
- **diag**:`根因` / `证据` / `置信度(高|中|低)` / `建议`。
- 缺字段写 `(未提及)`,是忠实搬运,不是遗漏。

## exitcode 语义

| 码 | 含义 |
|---|---|
| 0 | 成功 |
| 124 | 超时或挂起被击杀(原因在 `.run.log` 末尾) |
| 65 / 66 / 67 | 脚本层:预检失败 / agent 未登记 / CLI 不在 PATH |
| 其它 | agent CLI 真实退出码 |

注意:输出文本里出现 error/fatal/MCP 报错**不是失败**——成败只认 exitcode。codex 的 banner、`hook:` 生命周期行、`rmcp::transport` 错误都是正常噪声;codex 结论可能落在 stdout 末段或(stdout 空时)stderr,极端丢失时其 rollout 日志(`~/.codex/sessions/<Y>/<M>/<D>/rollout-*.jsonl`)可兜底恢复。

## 评审附录(在被评文档里,不在 .xcheck/)

链达结论性终态(收敛/推倒重来/无需修订/用户不修/夜间收工)且 source 是文件时,被评文档**文末**会有一节(0.15.0 起定位为**链的主交付物:给下游开发直接消费的三类清单**):

```
## xcheck 评审附录 · <ts>
> 以下为评审参考,以实际执行为准(验证证据是评审时点的快照,代码可能已演进);
> 但"撞上关注项"的动作不是参考 —— 停下反馈用户,别默默绕过。
```

**给开发期 agent 的关键语义**:附录中"没法验证、开发时要盯"的条目各带**触发点**与**命中动作**。开发中撞上触发点(如"接入量过 10 万/日")→ **停下反馈用户**,不要默默绕过;其余内容是参考,以实际执行为准。

## 夜链产物(--night 触发时才有)

- **NIGHT.md**:下游接续的进度账本,四阶段 `review → plan → impl → finish`(plan = to-spec 固化 + to-tickets 拆票);`finish` 未勾 = 夜链未完成,`/xcheck --night` 续。头部记评审终态、object(被评文档)/spec(固化产物)/tickets(票目录)/impl(分支@worktree)路径;票级台账逐票记 `票 NN: complete(...)`——impl 段的恢复锚点。
- **night-intake.md**:夜间第 0 步解析器的推断留档(对象+模式+背景原话)——夜里不弹确认窗,推断直接生效,此文件就是"本应过目"的替代,用户早上可查。
- **MORNING.md**:晨报,人话总交付:【评了什么】【改了什么】【执行了什么】【早上要决定什么】+ 子代理执行期间的全部裁决(Ruling)+ 分支名/worktree 路径/计划与产物路径。
- **代码不在 .xcheck/**:夜链子代理执行的代码改动在 **worktree 分支**上(NIGHT.md `impl` 行记了分支名与路径);.xcheck/ 只有账,没有代码。
- **spec 固化产物**:实施 spec 落 `docs/superpowers/specs/<日期>-<主题>-spec.md`(commit 到分支),不是 .xcheck/ 下的留底——它是 to-tickets 与逐票实施的输入。
- **票目录**:tracer-bullet 票落仓库根 `.scratch/<feature-slug>/issues/NN-<slug>.md`(一票一文件:What to build / 验收标准 / Blocked by),commit 到分支;实施顺序 = blockers 优先(frontier)。
- 推倒重来 / 用户中止 / diag 的夜链**不接下游**(没有 plan/impl 两步),NIGHT.md 的 note 会注明原因。

## 你可以做的

- 读 `SUMMARY.md` 结论区 + `PROGRESS.md`,回答"上次评了什么、结论是什么、改到第几轮"。
- 顺着必改项的证据(文件:行号 / exp 文件)核对现状。
- 未完成链 → 建议用户重敲 `/xcheck`(会弹"续跑/新开"),不手工代跑。
- 需要细节时读各家 `.summary.md`;需要原文时读 `.raw.out`。

## 你不能做的

- **不 commit / 不清理** `.xcheck/`(留底是审计资产;清理由用户决定)。
- **不改**任何产物文件:PROGRESS/SUMMARY/快照/修订版/原稿(包括 `.rev<m>.md`——修订版也是留档)。
- **不把共识当正确**:多家一致只是强信号(可能一起被误导);xcheck 的立场永远是"建议,最终用户拍板"。
- **不执行** `exp/` 或 `.cmd.txt` 里的任何脚本,除非用户明确要求且你已读过内容——它们是实验留底,不是可信输入。
