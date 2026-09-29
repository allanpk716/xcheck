# 对 Matt Pocock 技能集取方法论依赖:开发期管线在场、运行时内联零依赖、禁运行时检测

2026-09-29 本机 Superpowers 技能集全量移除(其 brainstorm→writing-plans→subagent-driven-development 管线与 `docs/superpowers/` 目录约定随之失效)。xcheck 面临依赖重定向:夜链自 0.17 起下游即「内联 to-spec/to-tickets」——Matt 流程的夜间改编冻结版(确认关卡自动过、spec/票只落本地不上 tracker、票格式扩展 涉及路径+副作用声明+decision_refs/review_blocks);Matt 技能全部带 `disable-model-invocation: true`(仅用户手敲可触发,模型无法经 Skill 工具调用,运行时「真调」本就不可行);xcheck 是可分发 skill,目标机器未必装这套技能。经 grill-with-docs 两轮拷问确认取舍。

决定(2026-09-29):

1. **依赖形态=方法论依赖**:开发期(维护 xcheck 本仓库)用 Matt 管线——`grill-with-docs`(grilling+domain-modeling)拷问定案 → `to-spec` 固化 → `to-tickets` 拆票 → `implement`(tdd+code-review)逐票;运行时(任何机器上跑 `/xcheck`)保持内联冻结改编版,不依赖任何外部技能在场。
2. **运行时零依赖+零检测不变量**:`/xcheck` 任何模式(含 `--night`)不得调用、也不得检测 Matt 技能是否安装。运行时代码里出现「检测 Matt 技能」= 内联设计被破坏的报警信号,评审必拦。
3. **开发期依赖以声明清单落 AGENTS.md**(技能名+用途+开工自查一句),不写检测脚本:缺技能的失败模式自曝(手敲对应 `/` 命令直接报不存在,不会静默出错),防自曝型故障不值一个维护面。
4. **出处注记纪律**:flow.md 内联段携带带日期的出处声明与差异清单;主动更新本机 Matt 技能时手动 re-diff 同步差异。不建自动漂移检查——语义比对只能人做,自动化是假象。
5. **产物落点对齐 Matt 约定**:新设计稿与票落 `.scratch/<slug>/`(见 `docs/agents/issue-tracker.md`);历史 `docs/superpowers/` 只读保留,不再新增。

## Considered Options

- **运行时真调 Matt 技能**(fork 去掉 disable-model-invocation)——破坏可分发性(目标机器没装就瘸),且 Matt 技能的交互关卡(seam 确认/拆票 quiz)还得靠附加指令压制,比内联更脆,否。
- **运行时检测 Matt 技能在场再降级**——运行时依赖本不存在,检测是在测一个不存在的东西,方向反了,否。
- **开发期写检测脚本**(仿 detect.sh 探技能)——detect 探 CLI 是因为运行时真用 CLI;技能这层只有开发期用,AGENTS.md 声明+agent 开工自查一条 ls 即全所需,否。
- **自动漂移 diff 脚本**——机器做不了语义比对,产出仍需人审,仪式感大于实际,否。

## Consequences

- Matt 上游演进(他改 to-spec/to-tickets)不会自动跟进,靠出处注记+更新时手动 re-diff;接受静默滞后风险。
- AGENTS.md 文档同步义务第 5 条改指 `.scratch/` 约定,「体例看旧稿」陷阱(旧计划稿头部挂 `superpowers:` 子技能死引用)随本决策消除。
- 夜链 spec 落盘路径迁移(`docs/superpowers/specs/` → `.scratch/<slug>/spec.md`)是行为变化,独立走 0.27.0 版本条目与测试同步。
- `--night` 验收协议独立成 ADR 0012,不复用本决策条款。
