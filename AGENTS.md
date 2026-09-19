# AGENTS.md — xcheck 维护导览(AI agent 版)

你是来**维护或扩展 xcheck** 的 AI agent(任何 CLI 都适用)。本文是你的地图与约束。术语的权威定义在 [CONTEXT.md](CONTEXT.md);本文与实现文件(`xcheck/lib/flow.md` 等)冲突时,**以实现文件为准,并顺手修本文**。给人类看的使用文档是 [README.md](README.md),本文不重复其内容,只补充"改这个仓库必须知道的事"。

---

## 系统一句话

xcheck 是两枚全局 Claude Code skill:`/xcheck`(评审/诊断链)和 `/xcheck-setup`(agent管理)。编排大脑是 Markdown 指令 flow.md,主会话做综合/取证裁定,run-agent.sh 机械执行CLI。0.19.0第一批review采用review_schema=2:保真共识→稳定D/F账本→三类取证→事实/阻断独立裁定→限定复审。diag保持旧路径。

**分期边界**:第一批任务1–4及第二批交互方式/执行终点解耦已实现;0.21.0新增第三批delivery_schema=1夜链同分支交付。第四、五批配置分离与真正权限隔离未实施。现有材料范围仍靠提示词要求,不能称强制隔离。

夜链由入口选完整night/--night触发,评审后内联to-spec/to-tickets再worktree逐票实施;新版仅推进无活动约束且依赖已验证完成的票。摄入冻结Git基线及发布目标,审核共识/修订/附录只在原仓.xcheck;spec/票之前建仓库外worktree,规格/票/最小.gitignore/代码全部仅该夜链分支提交。原分支不commit/push/pull/rebase,对外仅推冻结目标的夜链分支及显式repo/base/head创建或复用PR,不为PR推base。发布结果单列,绝不force/自动合并。

## 一次 /xcheck 的完整生命周期(精确版)

```
壳 xcheck/SKILL.md
  抠互斥--auto-review/--night及--agents → run-mode.sh核验模式 → 找未完成链与next/迁移目标
  无模式旗标新链三选:完整night(推荐)/仅无人值守审核/正常交互审核 → 定MODE → 转派flow
  续跑继承interaction/target;显式模式不符停止,无旗标正常确认续跑或新开
  旧review未完:幂等建migrated_from新schema2环重新审核
  旧night缺delivery_schema/冻结元数据即停,含review_schema2;不从当前HEAD补猜旧基线

flow.md(严格保持0~11编号)
  恢复:识别schema、核验必要D/F/快照/复审基线,沿next到最新环
        新命令不升级旧运行授权;必要材料缺失/未知schema停止
  0 摄入:显式文件/贴文优先;明确“刚讨论”优先当前讨论
    proposal+context+decisions(D稳定编号),短答绑定问题/选项,修正留替代关系
    仅对象/重要决定歧义正常确认;unattended局部待决,全局目标不明停止
    完整night冻结delivery_schema1与host_repo/start_oid/source_branch/remote_name/remote_url/pr_base
    night审核只写.xcheck,source=inline,original_source仅追溯;未提交业务改动不复制/stash/commit
  1 detect.sh探测与选集:--agents > default_agents > 报错;与已装取交集
  2 并发后台冒烟+回合内阻塞等待:读文件回显西瓜47
    预算per-agent(缺省60s),124只重试一次;不足两家停,记录smoke_cfg
  3 内容/指令分离:review决策快照必需;复审另需re-review-context
    首轮review.md/后续re-review.md;指令≤2048 UTF-8字节
    一条消息并发搬运工(AGENT_NAME/PROMPT_FILE/RESULT_SHAPE)
  4 collect:exitcode非零/spawn失败/raw.out或summary缺失即失败;不足两家停
  5 主会话汇总:review紧凑头;diag诊断长文
  6 diag用triage.md,终态完成(diag);review用triage-review.md建FINDINGS
    全来源映射稳定F,三类都编号,摄入关键未决也入账;不得①②空即通过
  7 只读查证①及旧问题解除证据;事实写回F,属实不直接叫必改
  8 本地实验②(≤300s/条,exp留底,禁业务改动/联网/部署),③保留未确定
  9 全部F按影响裁定:阻断/非阻断建议/重大风险待决/无需动作
    活动约束=开放阻断+开放重大待决;F裁定后机械投影SUMMARY五字段
    四问人话交付:对象/发现与暂停范围/实际修订/需要的决定
    空约束无需修订或收敛;正常可修订或先交付但不解除约束
    决策冲突优先问具体取舍;泛答修订不授权改定需求
    unattended最多一次自动修订,仅已确认范围内可修复阻断;否则夜间收工
 10 基于本轮快照写新rev,原稿正文不动;新环继承完整D/F和差异/修复理由
    当前环记next;限定复审原约束修复/修改回归/新重大缺陷
    旧问题没再提不算解除,普通建议不触发再修
    detect照跑;smoke仅最近真实成功+配置一致+上轮完整成功才可跳
 终态收尾:review先写D/F投影附录再记终态;一般建议不是新需求
    night仅.xcheck/review-appendix.md;正常/auto-review文件型仍追加原文件文末
 11 仅unattended/implementation夜链:建/核验NIGHT(review写schema2) → 分流(放弃/中止/diag不实施)
    diag任何入口不实施;完整night允许NIGHT短稿/可选通知,auto-review diag不建NIGHT/不通知
    target=review不建NIGHT、不进本步、不通知/推送/PR;仍允许审核本地修订/附录
    内联to-spec绑定最新已核验环proposal及同环D/F,不取目录最大rev/活动source
    仅继承已确认共识/必要修复/验收目标;未采纳建议不扩故事
    内联to-tickets记decision_refs/review_blocks/依赖
    spec前记branch/worktree意图,night-git prepare仓库外worktree;所有文档/代码只在该分支提交
    已有产物恢复先verify身份和全部complete完整OID,丢失worktree/分支本批暂停不重建
    frontier=自身无活动约束且依赖全部已验证complete;paused/blocked分别记
    逐票fresh TDD+独立双轴评审,修复≤5轮;残留阻断暂停而非停靠当完成
    complete记可达提交/验证证据后推分支;终局仅重大问题/回归修复一次
    收工verify后publish仅推冻结目标夜链分支,PR显式repo/base/head且正文自包含
    原分支不commit/push/pull/rebase,不为PR推base,无remote仅本地,不force/merge
    晨报/通知/对话:已完成与暂停范围、解除条件、发布结果
    paused/blocked或全局待决写waiting,impl/finish未勾;无新证据不重复执行/发布/通知
    全局约束则plan也未勾,只交付暂停原因,不拆可执行票/建实施分支/推送
```

**开口纪律**:正常模式集中在入口选择、续跑确认、第0步对象/重要决策歧义确认、第9步结果停点。明确对象不强制全文过目;关键冲突在停点问具体决定。night与auto-review都不等用户但不能擅改已定需求,记录待决并暂停受影响路径;全局目标不明停止,自动化不能越过边界。

## 模块地图

| 文件 | 职责 | 修改注意 |
|---|---|---|
| `xcheck/SKILL.md` | 入口壳:互斥模式旗标(--auto-review/--night)与--agents、未完成链检查、MODE路由、转派 | 无旗标新链三选;续跑不改原交互方式/终点;词表只在此文件 |
| `xcheck/lib/run-mode.sh` | 纯模式解析helper:MODE_REQUEST及可选持久化interaction/target/night → 规范化字段和night_mode | 新链一参数、恢复四参数;缺字段用-;非零停止,输出不得source/eval;不检查schema或授予权限 |
| `xcheck/agents.toml` | agent 登记表 + `[defaults]`(timeout_sec、default_agents) | **只能 Edit 精确匹配,禁止整文件 Write**(注释是实测注记);`/xcheck-setup` 模式 C/D 也走 Edit |
| `xcheck/lib/flow.md` | 自动链大脑:步骤定义、播报纪律、边界表、铁律 | **步骤编号(0~11)与 PROGRESS 阶段枚举是跨文件协议**(SKILL、carrier、setup、两份 AI 文档都引用);改编号 = 改协议,须全量同步 |
| `xcheck/lib/context-intake.md` | review共识快照/对象优先级;diag沿用原摄入 | 短答绑定问题/选项,助手提议不冒充已确认,当前讨论不被无关新文件截走 |
| `xcheck/lib/review-contract.md` | schema2唯一集中契约:D/F、裁定、复审、下游与恢复 | review摄入/分类/交付前必读;变更须同步全部投影,不得重解释旧记录 |
| `xcheck/lib/night-delivery.md` | delivery_schema1:冻结基线/目标、原仓.xcheck边界、同分支提交与PR/恢复 | 与review_schema独立;原分支不commit/push/pull/rebase,旧night缺元数据不得补猜基线 |
| `xcheck/lib/night-git.sh` | prepare/verify/publish机械Git检查与夜链分支发布 | 校验仓库common-dir、路径、分支、完整OID可达及冻结remote;不替代测试/独立评审证据,恢复不自动重建 |
| `xcheck/lib/night-pr.sh` | GitHub PR边界helper:platform、host/owner/repo、base、branch、title、UTF-8 body-file | 显式repo/base/head查开放同仓PR并复用/创建,查询失败不创建;调用者先确认授权/冻结目标/分支已推。Gitea不由该helper托管,主会话仅在可明确核实tea目标时操作,否则记未建 |
| `xcheck/lib/subagent-carrier.md` | 搬运工指令(7 步) | 后台启动 + **回合内阻塞等待**两条纪律是用事故换来的,别"简化";CLI 噪声剥离表(update 时同步 cli-findings) |
| `xcheck/lib/extractor-carrier.md` | 摘录员指令:按来源筛([用户]/[材料]),不改写不评判 | 输出格式 `## 摘录事实清单` 被 context-intake 0.2 引用 |
| `xcheck/lib/run-agent.sh` | agent 执行 supervisor:预检/构造/取证/监控/三层击杀 | 改它必跑回归测试(见下);exitcode 协议(0/124/65/66/67)是 API,别复用码值;内部节流可用环境变量 `XCHECK_POLL_SEC`/`XCHECK_STALL_SEC` 覆盖 |
| `xcheck/lib/detect.sh` | PATH 探测(`command -v`;stdout=已装,stderr=登记未装) | CRLF 容错解析,勿引入重依赖 |
| `xcheck/prompts/diag.md` `review.md` `re-review.md` | 外部agent指令模板 | 防自代入护栏不可删;review新增DECISIONS_PATH,复审另有RE_REVIEW_PATH;填路径后UTF-8≤2048字节;返回形状同步RESULT_SHAPE/carrier |
| `xcheck/prompts/synthesize-diag.md` `synthesize-review.md` `triage.md` `triage-review.md` | 主会话汇总、分模式分类 | diag不变;review三类稳定F,最终裁定先入FINDINGS再投影,禁止恢复旧必改并集 |
| `xcheck-setup/SKILL.md` | 4 种模式:检测验证 / add / timeout / default | setup 不校验"已装"(运行时 detect 管);homogeneity 只警告不拦 |
| `xcheck/tests/run-agent.test.sh` | supervisor 的 stub 回归(33 断言,零依赖,~15s) | 改 run-agent.sh / toml 解析必须全绿;新行为补断言 |

## 铁律(不变量——改代码、改文档、改 prompt 都不许破)

1. **subagent 只搬运、不评判**:综合/查证/裁决只在主会话(强模型)。
2. **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
3. **开口与决策边界**:入口/续跑/摄入/结果停点之外自动推进;night无弹窗不代表可替用户改定需求,具体重大待决暂停相关路径。
4. **实验禁改业务代码/禁联网/禁部署;修订只写新文件,原稿正文不动**(终态附录按ts幂等例外);正常审核和auto-review均不自动实施,仅unattended/implementation的night按第11步在worktree实施,绝不自动合并或伪称通过。
5. **异构目标**:至少一家非claude才有跨CLI第二意见价值;现行全claude只标注不拦,不同CLI也不能保证模型来源不同。
6. **成败只认 exitcode 文件**,不认输出文本;codex 的 banner/MCP/hook 噪声 ≠ 失败。
7. **审核审计产物落 `.xcheck/<ts>/`**(已 gitignore,不 commit);night的spec/票/代码仅在外部worktree提交,普通审核/auto-review的文件修订与附录位置保留;对话说人话、文件留机器账。
8. **搬运工必须后台启动 run-agent.sh 并在回合内阻塞等待**:前台直等 600s 被 harness 掐断、结论永久丢失;停回合等通知则搬运永不发生(两次事故实证)。
9. **夜链隔离交付**:按night-delivery执行,摄入/共识/修订/附录只写原仓.xcheck,source=inline、original_source仅追溯;spec/票/.gitignore/代码只在仓库外night worktree提交。仅发布冻结目标的夜链分支并创建/复用显式repo/base/head的PR;原分支不commit/push/pull/rebase,不为PR推base,不force/merge/建remote/上issue tracker。无remote本地执行,网络/权限拒推保留本地成果;身份/URL/提交不一致暂停发布,不猜目标。下游技术细化不改变已定需求,破坏性/安全敏感/决策冲突暂停相关路径并传播依赖,全局不明停止。通知可选,不得自动改变会话权限。
10. **事实不等于阻断**:只有开放阻断/重大风险待决约束推进;非阻断建议未采纳不扩规格/票。预算耗尽、无下游依赖或先交付不解除问题;暂停/受阻不算complete。

## 状态协议

- **模式字段(所有mode)**:新PROGRESS必写interaction/target。仅interactive/review、unattended/review、unattended/implementation有效;分别对应正常审核、--auto-review、--night。两新字段同时缺才映射旧night=on为完整night、无night为正常审核;半缺/非法/与night矛盾拒绝。显式请求不符不能接管原链;迁移/复审继承模式。target=review若有NIGHT即状态冲突,不能借终态“夜间收工”接实施。
- **PROGRESS阶段**仍11值:`intake, detect, smoke, fanout, collect, synthesize, triage, verify, experiments, deliverable, gate`。gate须已终态或新rev/新环已建且next已记;沿next找最新环,不重跑交接环。
- **schema2新字段/材料**:review_schema=2、next、migrated_from;intake完成须proposal+decisions,triage完成须FINDINGS,复审须re-review-context及上一环映射。D/F链内稳定,复审保留完整历史;必需产物缺失/未知schema停止。
- **自动修订预算**:auto_revisions_used原生0、自动修订递增且跨环保留;旧迁移round≥1至少记1,无法核实写unknown禁止自动再修,不因新环round=0重置预算。
- **终态七值**保留:无需修订=首轮活动约束空;收敛(N轮修订)=修订后活动约束空;用户不修=用户先交付但约束保留;夜间收工=auto-review或night的策略预算/决策边界交付,不代表实施权限;推倒重来仅用户明确放弃;用户中止;完成(diag)。无需建议清零,结束不等于放行/实现完成。
- **SUMMARY五字段**:状态(可推进/相关路径暂停)、活动约束(证据或缺口/范围/解除条件)、各家裁决、信号、统计。先FINDINGS裁定,后机械投影;附录和对话精选建议不扩票。
- **NIGHT四阶段**review/plan/impl/finish不变,review夜链写schema2。票只以complete(可达提交+验证记录)/paused(F及解除条件)/blocked(依赖票)调度,不能有行就跳过。有paused/blocked或全局待决则写waiting(解除条件与证据基线),impl/finish未勾,晨报可先交付;恢复先核新证据并更新D/F再重算,没有则返回暂停摘要,不重复实施/发布/通知。全部票处理完成才勾finish;全部complete且无约束/终局阻断才全绿,只剩非阻断参考可带停靠完成,有paused/blocked/活动约束则未完成,spec/拆票失败则失败收工。push/pr分别记录已推/未推及原因/无远端与PR URL/未建原因;全绿不代表发布成功。
- **交付协议**:完整night review的PROGRESS/NIGHT写delivery_schema=1及冻结host_repo/start_oid/source_branch/remote_name/remote_url/pr_base;复审继承,不从当前HEAD补猜。source=inline,original_source仅追溯;无Git/HEAD记implementation_unavailable,无remote只本地。spec前记录branch与仓库外worktree意图再prepare;恢复已有产物只verify,分支/worktree丢失或OID不可达暂停不重建。complete必须完整OID和测试/独立评审证据,不能只短SHA或“绿”。
- **旧协议**:无schema的旧review已终态只读保留,旧必改=①证实+②成立,不按新语义重解释。未完旧review可幂等迁移新环重新审核;但旧night缺delivery_schema/冻结元数据时停止自动恢复,包括已有review_schema2,没有plan产物也需明确新开。无PROGRESS极旧目录仍忽略。diag保留旧三分类、无新版验证链且不建worktree。
- 逐文件语义见 [docs/artifacts.md](docs/artifacts.md),改格式必须同步。

## 故障语义速查

| exitcode | 含义 |
|---|---|
| 0 | 成功(成败唯一权威是 `<agent>.exitcode` 文件) |
| 124 | 硬超时或挂起击杀(`.run.log` 末尾有具体原因) |
| 65 / 66 / 67 | 脚本层:预检失败(prompt 缺失/空)/ agent 未登记或字段非法 / CLI 不在 PATH |
| 其它 | agent CLI 真实退出码(401 欠费、未登录……) |

Windows 已知坑(都已在代码里处理,重构时别退化):反斜杠路径在 `$(cat ...)` 里**静默读空**;前台上限 600s;`taskkill //T` 杀不到 msys 孙进程(cygwin fork 模拟打断父子链,须进程组 + 树杀并用);大 prompt 撞 32767 字符命令行上限(指令/内容两层分离解决);codex 0.153.0 Windows 非交互下非全权沙箱拒绝一切进程创建(故 `-s danger-full-access`)。

## 扩展指南

**新增 agent CLI**:优先让用户跑 `/xcheck-setup add <name>`(自动核实 `--help`、引导字段、验证、失败回退)。手工路径:在 `agents.toml` 追加 `[agents.<name>]` —— `installed_check`(探测命令,一般就是名字)/ `run_cmd`(不含 prompt 的前缀,**按空格分词、token 不得含空格**)/ `input_mode = arg|stdin` / `needs_timeout`(历史会卡才 true)/ `timeout_sec`。然后用 `/xcheck-setup`(模式 A)验证 marker `hello-from-<name>` 回显。CLI 噪声形态若有新花样,补进 `subagent-carrier.md` 第 3 步和 `docs/cli-findings.md`。

**改 prompt 模板**:保持指令层 ≤2KB、槽位命名、防自代入护栏;返回结构字段变了要顺藤改 RESULT_SHAPE(flow 3.3)、汇总与 triage 模板。

**改链结构**:flow.md 步骤编号、PROGRESS 阶段枚举、终态枚举三者是协议,一动全动(SKILL.md、carrier、setup、AGENTS.md、docs/artifacts.md、CONTEXT.md);向后兼容义务:旧 `.xcheck/` 产物(无 PROGRESS.md)必须继续"静默忽略、不算未完成"。

## 测试义务

```bash
bash xcheck/tests/run-agent.test.sh    # 零依赖(只要 bash + coreutils),~15s,33 断言
```

改night-delivery/night-git及第11步需跑 `bash xcheck/tests/night-git.test.sh`,改GitHub PR边界需跑 `bash xcheck/tests/night-pr.test.sh`;只用临时repo、本地bare remote与stub gh,不得真实推送或创建PR。机械Git通过不证明模型的PR正文、gh/tea目标参数或全链行为已验收。改模式解析/入口/恢复需跑 `bash xcheck/tests/run-mode.test.sh`。改 `run-agent.sh`、`detect.sh`、`agents.toml` 解析逻辑 → **必须全绿再交付**。review契约/模板/flow还需跑 `bash xcheck/tests/review-contract.test.sh` 的离线结构与样例检查;静态检查不能证明模型正确理解,须区分已运行检查、场景回放和未授权未执行的真实CLI端到端。禁止偷偷调用付费CLI或外发材料作验收。

## 文档同步义务(改行为必须五处对齐)

1. `CHANGELOG.md` —— 新版本条目,中英对照,写清根因与设计稿链接(体例看旧条目)。
2. `CONTEXT.md` —— 新术语入表 / 旧术语改口径(附 _Avoid_)。
3. `README.md` —— 用户可感知的行为变化。
4. `AGENTS.md`(本文)+ `docs/artifacts.md` —— 协议、不变量、产物格式变化。
5. `docs/superpowers/specs|plans/` —— 大改先落设计稿与计划(体例看旧稿),再动实现。

## 仓库约定

- 语言:仓库文档与 prompt 中文为主,术语保留英文原名。
- 行尾 LF(`.gitattributes` 锁定);`.xcheck/` 已 gitignore,产物永不 commit。
- 提交信息看 `git log` 体例:conventional 前缀,主题中英皆可,关键事故写明实证日期。
- 依赖极简:bash + coreutils;skill 运行时依赖 Claude Code 的 Agent/AskUserQuestion/Bash 工具语义。
