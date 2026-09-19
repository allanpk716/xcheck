# .xcheck/ 产物解读 —— 给 AI agent 的使用向说明

你在项目里遇到 `.xcheck/`,说明项目用过 **xcheck**。本文说明文件语义、恢复边界和允许的消费方式。术语见 [CONTEXT.md](../CONTEXT.md),新版审核契约见 [review-contract.md](../xcheck/lib/review-contract.md)。

## 先识别版本,再判断状态

读取最新关联环的 `PROGRESS.md`,不要只按目录时间戳猜是否完成。所有新记录(包括diag)均保存 `interaction`/`target`;先按下文模式规则核验,不能仅凭 `night` 或终态名决定是否实施。

- `mode = review` 且 `review_schema = 2`:按本文新版协议解释。沿 `next`/`prev` 找最新环;旧迁移来源通过 `migrated_from` 关联。已交接环(gate 已勾且 next 有值)不是需要重跑的环。
- review 无 `review_schema`:旧协议,不得把旧“必改/收敛”重解释为新版阻断结论。已结束的旧记录只读保留。
- 未完旧 review:skill 保留原目录,幂等建立 `migrated_from=<旧ts>` 的新 schema2 首环,从可取得的对象/背景重新审核,不继承旧验证或通过。已有迁移目标则沿目标续跑,不反复建环;源内容缺失则停止。
- **完整night缺 `delivery_schema = 1` 或冻结元数据:停止自动恢复,包括已有review_schema=2的记录。** 有plan/impl产物时报告账本/分支位置,等待专门恢复;没有plan产物也不能用当前HEAD猜旧基线,需明确新开。不得重放旧原分支推送、重复实施或清理旧分支。
- 未知 schema 或新版必要材料缺失:报告状态不一致,不得凭勾选跳阶段。
- `mode = diag`:仍是诊断综合与旧三分类,不写 review_schema,不走新版 D/F 与验证链。
- 无 `PROGRESS.md` 的极旧目录:静默忽略,不算未完成。

新版 `## 终态` 有值只表示审核段结束,不保证约束解除或实施完成。终态为空且有未勾阶段可建议用户 `/xcheck` 续跑,**不要手工代跑**。兼容的新 NIGHT 若 finish 未勾可由 `/xcheck --night` 核验后续跑;paused/blocked 未解锁时不应反复建议重跑。有paused/blocked或全局待决时写waiting并保持impl/finish未勾;晨报可以先交付,不等于链完成。全部票处理完成才勾finish。

## 目录总览

```text
.xcheck/
├── <ts>/                          # 本地时间戳 YYYYMMDD-HHMMSS;复审各有新环
│   ├── PROGRESS.md                # 阶段/终态/schema/前后环与迁移关联
│   ├── proposal.md                # review 本轮对象快照
│   ├── input.md                   # diag 对象快照
│   ├── context.md                 # 必要背景原话(有才建)
│   ├── decisions.md               # schema2 review 必需:稳定D决策快照
│   ├── FINDINGS.md                # schema2 分类后必需:稳定F事实/裁定/历史
│   ├── re-review-context.md       # schema2复审必需:上轮完整F/D、差异、修复理由
│   ├── SUMMARY.md                 # review投影/索引;diag综合长文+旧三分类
│   ├── prompt.txt                 # ≤2KB指令层,引用内容层绝对路径
│   ├── dialog-snippet.txt         # diag摄入的摘录来源片段(有才建)
│   ├── <agent>.raw.out            # 搬运工:原始输出留底
│   ├── <agent>.summary.md         # 搬运工:结构化结论
│   ├── <agent>.failed.md          # 失败说明(有才建)
│   ├── <agent>.exitcode           # supervisor:成败权威
│   ├── <agent>.raw.stdout/.raw.stderr  # supervisor:原始管道
│   ├── <agent>.cmd.txt            # supervisor:实际执行命令(%q转义)
│   ├── <agent>.run.log            # supervisor:预检/击杀原因/耗时
│   ├── <agent>.spawn.err          # wrapper被掐断的证据(有才建)
│   ├── night-intake.md            # 夜间摄入对象/背景/推断限制
│   ├── NIGHT.md                   # 夜链阶段、票状态、发布结果
│   ├── MORNING.md                 # 夜链人话交付与裁定附录
│   ├── review-appendix.md          # 完整night评审附录,不追加被评原文件
│   ├── proposal.rev<m>.md         # inline/完整night修订版;仅review终点文件型写原目录
│   └── exp/                       # 本地实验脚本/输出,留底不删
├── smoke.txt / smoke-prompt.txt   # 冒烟固定材料
└── <agent>.*                      # 冒烟supervisor产物及淘汰记录
```

`.xcheck/` 在 xcheck 自身仓库被 gitignore,宿主项目未必如此;未忽略时提醒用户。不要 commit 这些审计产物。评审附录、正式共识稿、spec、票和代码不都在此目录,见下文。

## PROGRESS.md

```markdown
# PROGRESS · <ts>
mode = review
review_schema = 2
interaction = unattended
target = implementation
selected = codex, pi
source = inline
original_source = C:/…/xxx.md
delivery_schema = 1
host_repo = C:/…/host-repo
start_oid = <完整提交OID>
source_branch = <启动分支或->
remote_name = <origin或->
remote_url = <冻结唯一push URL或->
pr_base = <冻结启动分支或->
round = 0
prev = -
next = -
migrated_from = -
auto_revisions_used = 0
smoke_cfg = <sha256>
night = on

## 阶段(完成即打勾)
- [x] intake
- [ ] detect
…
- [ ] gate

## 终态
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户不修 | 夜间收工 | 用户中止 | 完成(diag))
```

- `source`:正常审核/auto-review为对象绝对路径或inline,复审指新稿;完整night始终inline,`original_source`仅追溯原始文件/inline,不得作为写回目标。`prev`/`next`关联复审环;迁移新首环round=0、prev=-、migrated_from=旧ts。
- `delivery_schema=1`及host_repo/start_oid/source_branch/remote_name/remote_url/pr_base仅完整night review使用,在首次摄入冻结并逐环继承。start_oid须完整OID;无Git/HEAD记`-`及implementation_unavailable原因,可审核但不实施。不从当前HEAD补猜缺失基线。远端必须明确且唯一push URL,缺失/不确定记`-`只本地执行;含凭据URL不落账本并禁止自动发布。业务未提交变更不自动stash、commit或复制到worktree,方案依赖它们时暂停相关路径。
- `smoke_cfg`:最近实际冒烟通过时 agents.toml 的 sha256;跳冒烟须同时满足最近真实成功、配置指纹一致、上轮该家完整成功,不从连续跳过记录推导成功。
- `auto_revisions_used`:原生首环0,自动修订递增并跨环保留。迁移旧round≥1至少记1,无法核实为unknown并禁自动再修;新首环round=0不重置已用预算。
- `interaction`/`target`:所有新mode都必须同时保存。合法组合仅 `interactive/review`(正常审核)、`unattended/review`(--auto-review)、`unattended/implementation`(--night)。复审/迁移继承原模式。
- 只有两字段同时缺失才作旧兼容映射:`night=on`→完整night,无night→正常审核;半缺、非法枚举、非法组合或与night标记冲突拒绝。`night=on`仅完整night的兼容标记,不是单独授权。
- `lib/run-mode.sh <MODE_REQUEST> [<interaction或-> <target或-> <night或->]`为纯解析helper,MODE_REQUEST为default/interactive/auto-review/night;恢复必传后三项。新命令无显式模式按账本恢复,显式模式不符停止;非零拒绝继续,不得source/eval输出。它不检查schema、产物完整性或执行权限。
- `target=review`不建立NIGHT、不运行第11步、不创建实施票、不通知/推送/PR,仍可写本地审核快照/共识稿/修订稿/附录;若已有NIGHT则状态冲突。diag无论入口如何都不实施;完整night允许NIGHT短稿及可选通知,auto-review diag不建NIGHT、不通知。
- 固定11阶段:`intake, detect, smoke, fanout, collect, synthesize, triage, verify, experiments, deliverable, gate`。
- intake 完成必须有 proposal/decisions;triage 完成须有 FINDINGS;复审还须 re-review-context 与上一环映射。缺失停止,不凭记忆补为已完成。
- 从第一个未勾阶段整段重做,分类须幂等复用来源映射。gate 未勾时不依赖会话记忆恢复用户决定。gate 勾选须已终态,或修订稿与新环均已落盘并记录 next。

### 终态七值(schema2)

| 终态 | 含义 |
|---|---|
| 收敛(N 轮修订) | 修订后活动约束空;可以仍有普通建议,不代表实现/测试通过 |
| 无需修订 | round 0 活动约束空;不是①②必须为空 |
| 用户不修 | 用户选择先交付,约束仍保留,不是绕过阻断的许可 |
| 夜间收工 | auto-review与night共享的兼容标签:无人值守预算/决策边界后的交付,不是人的决定、全面放行或实施权限 |
| 推倒重来 | 仅用户明确选择放弃 |
| 用户中止 | 用户主动停链 |
| 完成(diag) | 诊断模式止于综合+三分类,无验证链 |

## decisions.md 与 FINDINGS.md(schema2)

`decisions.md` 必有 `review_schema = 2`、目标与范围,每条稳定 D 编号包含:

- 状态:已确认 / 未决 / 否决 / 假设 / 已替代。
- 内容、来源、替代关系、影响范围。
- 用户短答绑定问题和选项;文件要求注明来自用户指定材料,不是虚构的会话确认。助手未确认提议不能算已确认。上下文缺失如实说明,即使无可摘决策也建文件记录覆盖限制。

`FINDINGS.md` 必有 schema 头、稳定 F 编号及来源映射。每条字段:

```text
来源 / 关联决策 / 发生条件 / 取证分类 / 事实 / 证据 / 影响 /
裁定 / 范围 / 解除条件 / 决策冲突 / 生命周期 / 历史
```

- 三类都编号,不随排序/分类变化换号。每条外部反馈须映射一个 F;同一故障可归并多来源,不同发生条件/后果不能误合并。摄入与主会话查证的来源另标,不冒充外部意见。
- 事实:待验证 / 证实 / 证伪 / 未确定。①查无实据、②无定论、③均记未确定。
- 裁定:待裁定 / 阻断 / 非阻断建议 / 重大风险待决 / 无需动作。交付前不得留下待验证/待裁定,不能判定就明确未确定及缺口。
- 生命周期:开放 / 已解除。**活动约束 = 开放的阻断或重大风险待决**;开放的普通建议不阻断。
- 证实且影响目标/验收/安全/数据/实施前置条件才是阻断;未确定但有具体严重场景或关键决策缺口才是重大风险待决。泛泛担忧不是暂停理由。
- 复审复制完整历史再更新;没再提不等于解除,闭项重开须新证据或回归。预算耗尽、无下游依赖、先交付均不解除。

`re-review-context.md` 是复审内容层,包含上一环全部 F、D 约束、实际修订差异和逐条修复理由。复审看原约束修复/修改回归/新重大缺陷,不再每轮开题找一般建议;本轮各家输出仍互不可见。

## SUMMARY.md(schema2)

review 的结论区是已裁定 FINDINGS 的机械投影,不另造判断:

1. **状态**:活动约束空则“可推进”,否则“相关路径暂停”,列阻断/重大待决数量与范围。
2. **活动约束详情**:问题、证据或缺口、具体影响、受影响路径、解除条件。
3. **各家裁决**:AGREE / SUGGEST_CHANGES / DISAGREE 一行。
4. **信号**:总判三定式(焦点共识/意见分裂/一边倒)+ DISAGREE 计数,不代替阻断裁定。
5. **统计**:取证分类/事实结果与活动约束计数。

正文含三类索引;完整事实和历史在 FINDINGS。附录/对话可精选一般建议,不要求用户消化全部反馈,不自动转规格或票。对用户解释要当场说明问题、影响和解除条件,不能只甩 D/F 编号。

## 旧 review 与 diag 的 SUMMARY(保留旧释义)

无 schema 的旧 review 五字段是状态、必改项、各家裁决、信号、统计。旧必改项为①证实 + ②实验成立的机械并集;状态“可推进/先修订再推进”由并集是否为空决定;旧收敛是该并集清零。①②先①后②流水 #n,③无编号、存疑仅参考。旧附录包含全部三分类,③关注项带触发点与命中动作。**这些历史规则不适用于 schema2,也不通过编辑旧账本升级。**

diag 保持综合诊断长文(共识根因/分歧/存疑/建议)+旧三分类,没有 review 结论区、D/F 协议、查证/实验链与停点问题。

## 各家结构化结论

- schema2 review:裁决 / 逐条问题(位置、严重度类型、发生条件、具体影响、证据或缺口、关联决策、解除条件)/ 理由;复审另有原问题复核(F编号、结论、证据或缺口)。
- 旧 review:裁决 / 逐条问题(位置+严重度)/ 理由。
- diag:根因 / 证据 / 置信度(高|中|低)/ 建议。
- 缺字段如实写未提供/未提及,搬运工不补推理。原始 .summary.md/.raw.out 保留,归并只在问题记录进行。

## exitcode 语义

| 码 | 含义 |
|---|---|
| 0 | CLI成功;collect还要核验raw.out与summary均存在 |
| 124 | 超时或挂起被击杀,run.log有原因 |
| 65 / 66 / 67 | 脚本预检失败 / agent未登记或字段非法 / CLI不在PATH |
| 其它 | CLI真实退出码 |

输出出现 error/fatal/MCP 字样不等于失败。codex banner/hook/rmcp 噪声可与成功同时出现;结论可能在 stdout 末段或 stderr,极端输出丢失时可按搬运工规则读原生 rollout 留底恢复,不要自行重跑 .cmd.txt。

## 评审附录

review结论性终态(收敛/无需修订/用户不修/夜间收工/推倒重来)写 `## xcheck 评审附录 · <ts>`,按ts幂等。完整night仅写 `.xcheck/<ts>/review-appendix.md`;正常审核/auto-review且source是文件才追加原文件文末。schema2内容来自D/F:先活动约束及解除条件,再已解除摘要与精选建议。原稿正文不动;仅review终点inline没有目标文件或附录写失败会说明原因,机器账仍保留。

下游只能把已确认共识、必要修复和验收目标带入规格;**非阻断建议不是授权需求**。命中具体重大风险时暂停受影响行为及依赖方,不能把所有③都当整链停止开关。

## NIGHT.md 与下游产物

仅 `interaction=unattended / target=implementation`可建立NIGHT;target=review到审核交付即止,即使终态叫“夜间收工”也不能建此账本或发送夜链通知。review新夜链记review_schema=2、delivery_schema=1及interaction/target,从PROGRESS继承冻结host_repo/start_oid/source_branch/remote_name/remote_url/pr_base;生成spec前先记branch/worktree意图。另有review_ts、评审终态、object/spec/tickets/impl路径、push/pr结果。object仅指最新已核验环的proposal快照,与同环D/F绑定,不扫描最大rev或取变化的source。四阶段 `review → plan → impl → finish` 不变;diag只写短稿、不建worktree,不要求review/delivery元数据。

spec/票路径以NIGHT所记worktree为根,不以当前cwd或host_repo为根。branch为 `xcheck-night-<root-ts>`,worktree为原仓外绝对路径。完整OID及验证记录必须按实际提交逐个写入,以下占位符不是真实通过证据:

```text
票 01: complete(commits <完整OID1>, <完整OID2>; tests <命令/结果/证据位置>; review <独立评审证据>)
票 02: paused(F2,解除条件:补齐删除范围验证)
票 03: blocked(票02)
```

- 票文件记 `decision_refs: D编号`、`review_blocks: F编号或无` 及依赖。自身有约束→paused,依赖未完成→blocked,无法证明独立也暂停。
- 只调度自身无活动约束且依赖全部已验证 complete 的票。complete 须当前分支可达提交和验证记录;台账有行、停靠、尝试过不算完成。paused/blocked 须解除证据/新决策才重算。
- worktree/分支丢失或提交不可达:停止实施恢复,不得从spec重建后按旧完成行跳票。plan未勾先看现有spec/票,不盲目覆盖用户改动。
- 夜链结论:全绿仅全部票验证完成且无活动约束/终局阻断;带停靠完成仅全部票complete且仅有非阻断参考;paused/blocked/活动约束残留→未完成;spec/拆票失败→失败收工。有paused/blocked或全局待决时impl/finish保持未勾,写 `waiting = <F/票编号、解除条件及证据基线>`。晨报可以先交付;只有全部票处理完成才勾finish。全局受约束时plan也未勾,只交付原因,不拆可执行票、不建实施分支、不推送。
- waiting恢复先核新证据/决策,更新D/F后重算票状态;无新证据则返回现有暂停摘要,不重复实施、发布或通知。
- MORNING.md 是四问人话交付,附裁定与暂停/依赖状态、解除条件、分支/PR及验证结果。推倒重来/用户中止/diag不接下游,写未执行实施短稿。

**0.21.0隔离交付**:spec在 `<worktree>/docs/superpowers/specs/`,票在 `<worktree>/.scratch/<slug>/issues/`,必要最小.gitignore调整及所有代码也仅该worktree,全部同夜链分支提交。原分支不commit/push/pull/rebase,原仓只写.xcheck审核账本,不自动复制或处理业务未提交改动。规格整合已审proposal、D约束与精选附录形成自包含需求,不上传整个.xcheck、原始反馈或私有聊天。

`night-git.sh prepare <host_repo> <branch> <worktree> <start_oid>`仅创建新分支/工作树或幂等核验匹配项,不覆盖冲突;已有产物恢复只用`verify`并传全部complete完整OID,核验common-dir、真实路径、HEAD分支和提交可达。主会话还须核验测试/独立评审证据,Git可达不代表测试通过。worktree/分支/提交缺失本批暂停,不自动重建;有未记账提交或未提交修改先核归属,不擅自清理/标完成。

`publish`先核验身份与冻结remote URL,只推 `refs/heads/<branch>:refs/heads/<branch>`。无remote记无远端/本地完成;网络或权限拒推保留本地成果,收工再试一次;URL或身份不一致暂停发布,不猜新目标。PR只有夜链分支已推且冻结目标明确才创建:GitHub由 `night-pr.sh github <host/owner/repo> <base> <branch> <title> <UTF-8正文文件>` 显式查询并创建,只复用同目标开放同仓PR,查询失败不尝试创建。Gitea不由该helper托管,主会话仅在明确核实tea目标参数时操作,否则记未建。缺工具/未登录/目标不明/base不在远端记未建,不为PR推base。PR正文自包含规格主题、范围、测试证据摘要、paused/blocked及解除条件和发布状态,晨报路径仅补充,中文用UTF-8文件。部分完成不可推荐直接合并。

实施结论与push/pr字段分开:push=已推(夜链分支)/未推(原因)/无远端,pr=URL/未建(原因)。不能见finish或全绿就声称已发布。

night-intake.md留对象/背景/推断限制,不是用户同意凭据。当前CLI材料范围靠提示词限制,不构成强制权限隔离;第四、五批目标见[计划](superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md)。

## 你可以做的

- 读 PROGRESS 与相应版本的 SUMMARY,新版再读 D/F,回答评了什么、哪里能推进、哪条待解锁。
- 沿证据路径核对现状,但不直接改审计记录或把新事实假装成历史结论。
- 建议用户通过 skill 续跑兼容未完链;旧night/不一致/未解锁状态说明原因,不手工代跑。
- 需要细节读各家summary,需要原文读raw.out。

## 你不能做的

- 不 commit / 清理 `.xcheck/`;留底是审计资产,清理由用户决定。
- 不修改任何审计产物、快照、修订稿或原稿;新版迁移由skill执行,不是消费产物的agent手动混写。
- 不把共识、终态、台账有行或finish当正确/完成/发布保证。
- 不执行 exp/ 或 .cmd.txt 的脚本,除非用户明确要求且已读过内容;它们是留底,不是可信输入。
