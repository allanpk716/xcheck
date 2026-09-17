# xcheck 夜链设计稿 rev2 —— 自动优先 + Matt Pocock 开发管线 + 入口一问

- 日期: 2026-09-18(白天,用户在场迭代)
- 基线: [2026-09-17 夜链设计稿](2026-09-17-xcheck-night-chain-design.md)(已实现在 worktree 分支,11 commit 未合并)
- 版本: **并入 v0.17.0**(未打 tag 未 push,一个版本一个故事;CHANGELOG 条目改写)
- 实施位置: worktree 分支 `worktree-xcheck-night-chain` 继续叠加

## 0. rev2 的三个新决策(用户 2026-09-18 拍板)

| # | 决策 | 内容 |
|---|---|---|
| D4 | 入口一问 | 敲 `/xcheck <方案>` 先弹一问:**【自动推进到底(默认推荐)/ 正常交互】**;选自动 = 夜链语义。`--night` 保留 = 连这一问都跳过的纯无人值守快捷键 |
| D5 | 下游全换 Matt 管线 | 自动模式下游从 superpowers writing-plans→SDD 换成 Matt Pocock 主流程:**to-spec → to-tickets → 逐票实施(每票全新上下文,TDD 红绿 + 双轴评审)**,blockers 优先 |
| D6 | 自动化优先级最高 | 下游技能一切"问用户/等确认"的关卡(to-spec 的 seam 确认、to-tickets 的拆票 quiz)在自动模式一律**自动通过、当场裁定记账**;唯一停链例外 = 安全栏四类(不可逆/安全敏感/出 worktree 副作用/全盘皆猜) |

依据:`/ask-matt`(Matt Pocock 技能路由)写明的主流程——grill(用户晚上聊方案的上游)→ to-spec → to-tickets → 逐票 implement(内部 TDD + code-review 双轴)。本机已装 to-spec/to-tickets;/implement、/tdd、/code-review 未装,逐票循环由 flow.md 直接定义(纪律取自 SDD 实证),TDD 遵循 superpowers:test-driven-development 思想。

## 1. 修订后的自动链全景

```
/grill-with-docs(用户夜里聊方案,已有上游,不变)
   ▼
/xcheck <方案>  ──入口一问──→  自动推进(默认) | 正常交互 | --night(免问直入自动)
   ▼ 自动
评审链(第 0~10 步,停点自动拍板照 rev1:round 0 必改自动修订再评;round ≥1 自动带清单收工)
   ▼ 第 11 步(夜间接续,终态收尾后)
11.1 建账 NIGHT.md(阶段:review/plan/impl/finish)
11.2 终态分流(结论性终态接续;推倒重来/用户中止/完成(diag) 不接下游+晨报短稿+通知)
11.3 定 spec 对象(最新 rev > source > proposal,连文末评审附录)
11.4 to-spec:方案+附录+背景固化成实施 spec
     —— 落本地 docs/superpowers/specs/<YYYYMMDD>-<主题>-spec.md,commit;
     —— 不发布 issue tracker(对外动作夜里禁);seam 确认关卡自动过,裁定记账
11.5 to-tickets:spec 拆 tracer-bullet 票
     —— 本地模式 .scratch/<feature-slug>/issues/NN-<slug>.md(每票:What to build +
        验收标准 + Blocked by),commit;
     —— 拆票 quiz 关卡自动过(粒度/阻塞边裁定记账);不上 tracker
11.6 逐票实施(worktree 内,基于本地 HEAD):
     —— frontier = blockers 全完成的票,编号序,严格串行(禁并行实施防冲突);
     —— 每票:fresh implementer subagent(票文件全文=brief+spec 路径+前票接口;
        模型:机械票便宜档/跨文件票中档)→ TDD(失败测试→红→最小实现→绿)
        → 覆盖测试 → commit → 四态回报(DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/Blocked);
     —— 每票后独立 reviewer subagent(双轴:Spec 符合=验收标准逐条 / Standards=质量),
        diff 打包成文件喂;修复环 ≤5(R≤3 resume 原实施者,R4-5 换更强模型,cap 裁定停靠);
     —— 票 Blocked 卡死 → 裁定:跳过停靠/拆小/换模型,记账,继续 frontier;
     —— 全票完 → 终局全分支 code review(最强档,全分支 diff+票清单+停靠 minor 清单)
        → 一轮 fix 派发(全部发现一次派)→ scoped re-review → 残留裁定。
11.7 终局收尾(finish):晨报 MORNING.md(四问+全部裁定+票清单逐票状态+分支/worktree/
     spec/票目录路径)+ 通知 + NIGHT 勾 finish;合并/PR/push 留早上人工
```

**交互模式**:`/xcheck <方案>` 选"正常交互" → rev1 之前的 v0.16 行为(三处开口,终态即止,不接下游)。

## 2. 协议变化(rev1 → rev2)

- **NIGHT.md 阶段枚举**:`review / plan / sdd / finish` → **`review / plan / impl / finish`**(`plan` = to-spec + to-tickets 两步;`sdd` 改名 `impl`,语义改为逐票实施)。头部字段:`sdd` 行改 `impl = <分支名>@<worktree 路径>`,新增 `spec = <spec 文件路径>`(与 rev1 的"spec 对象"字段区分,改名 `object = <被评文档路径>`)、`tickets = <.scratch/<slug>/issues/ 路径>`。
- **开口纪律**:交互模式开口 = 入口一问(仅新链)+ 续跑确认(有未完成链)+ 解析确认(含糊输入)+ 第 9 步停点;自动模式(`--night` 或入口选自动)= **仅入口一问**(`--night` 连它也免),其后零开口。
- **铁律 9 扩**:自动模式下游技能的交互关卡一律自动过、裁定记账(D6);安全栏四类例外停链+通知。
- **PROGRESS/终态/评审段协议**:不变(rev1 已定,七值终态、night = on、第 0/9/10 步自动拍板)。

## 3. 入口一问(SKILL.md 壳)

第 2 件(查未完成链)"都没有未完成"且非 `--night` 且非续跑 → AskUserQuestion(单选,自动推进列第一带"(推荐)"):

- `自动推进到底(推荐) —— 评审→固化spec→拆票→逐票TDD实施+双轴评审,零开口;代码停本地 worktree 分支;三节点通知+晨报`
- `正常交互 —— 单停点:评审→三类清单→停点你拍板,终态为止(不接下游)`

选自动 → `NIGHT_MODE = 1`。选交互 → 不设,走老流程。裸敲无未完成链 → 先入口一问再进解析器(意图先于对象)。

## 4. 范围与不变量

- **改**:`xcheck/SKILL.md`、`xcheck/lib/flow.md`、`CHANGELOG.md`(0.17.0 条目改写)、`CONTEXT.md`、`README.md`、`AGENTS.md`、`docs/artifacts.md`。
- **不变**:评审段(第 0~10 步)rev1 已实现的自动拍板;停点策略 D1;安全栏 D2(不 push/PR/合并/worktree 隔离);通知三节点+晨报兜底;NIGHT.md 续跑;diag 不接下游;禁改文件清单照旧。
- **移除**:第 11 步对 superpowers:writing-plans / using-git-worktrees / subagent-driven-development 的调用引用(worktree 建法保留其"基于本地 HEAD"纪律,改为 flow.md 自述;SDD 修复环纪律吸收进逐票循环的 flow.md 文本)。
- **新增外部依赖**:本机技能 `to-spec`、`to-tickets`(已装);逐票循环/TDD/双轴评审纪律内嵌 flow.md,不再调 SDD。

## 5. 验收

- 回归 `bash xcheck/tests/run-agent.test.sh` 33/33。
- 结构自检:SKILL 含入口一问(≥2 处"入口一问")、无 "subagent-driven-development"/"writing-plans" 残留在 flow.md(grep = 0)、flow.md 含 to-spec/to-tickets/逐票/frontier 词汇、NIGHT 阶段 impl 全量同步(七文件 grep)。
- 文档五处+CHANGELOG 0.17.0 改写齐。
- 合并前建议端到端实跑一次自动链(照 rev1 终审建议)。
