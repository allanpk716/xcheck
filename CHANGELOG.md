# Changelog / 更新日志

All notable changes to `xcheck`. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
本文件记录 xcheck 的所有显著变更。

## [Unreleased]

### Added / 新增

- **上手指南 [docs/getting-started.md](docs/getting-started.md)**:安装+评审 agent 配置的完整剧本,**写给同事的 AI 执行**(人把文档交给 AI 照做,每步命令+验收)。五步:装 Claude Code(点名推荐安装器)→ clone+junction 装 xcheck → 按档位装评审 agent CLI(最小推荐 codex+pi / 全家桶五家;npm 包名实核,kimi 走官方渠道)→ 配 key/endpoint(本机实配脱敏样板,**"这边建议"框架**——AI 对照当时官方文档核实执行,不逐字照抄;集团网关留 base_url 替换口)→ `/xcheck-setup` 验收全绿+试跑。平台口径 Windows+Git Bash。

### Fixed / 修复(文档过时点清零)

- README:快速开始瘦身并链向上手指南;两处"收工自动开 PR"旧语义(0.18/ADR 0003 遗留)改为现行"不自动开 PR,晨报给 compare 链接"(ADR 0006);`/xcheck-setup` 子命令表补 `lanes` 行;删重复 run-mode.sh 树行;"4 种模式"→5;仓库树收入 getting-started。
- docs/cli-findings.md:"三家"改口五家;**补 pi 实测条目**(2026-09-20,pi 0.74.2,bigmodel coding 端点,stdout 即回复);codex run_cmd 收现行旗标 `--skip-git-repo-check -s danger-full-access` 并加注脚(2026-08-15/09-06 两事故);版本口径更新至 2026-09-20。
- **迁移残留清零**(0.22 删迁移后的漏网):docs/artifacts.md×4、AGENTS.md、review-contract.md、CONTEXT.md `auto_revisions_used` 词条——`migrated_from`/"旧迁移 round≥1"/"复审/迁移继承"全删。
- xcheck/lib/subagent-carrier.md:泳道失败语义对齐 0.24 有界重试(ADR 0009),删"超时/失败记 paused 不拖队"旧句。
- AGENTS.md:测试义务补 night-parallel 套件;文档同步义务挂 getting-started(安装/评审 agent 配置口径变化须同步)。
- CONTEXT.md:新增「**评审 agent**」词条(_Avoid_:搬运工、审核者)。
- xcheck/agents.toml:`default_agents` 注释"出厂不设"对齐实际出厂 codex+pi。

### Scope / 边界

- 纯文档与注释同步,无行为变更;回归 5 套件 **263 断言全绿**(run-agent 33/run-mode 28/review-contract 110/night-git 26/night-parallel 66)。`docs/diagrams/` 仍为 0.19 前快照(未跟踪、未重生成,另行处理)。

## [0.24.0] - 2026-09-20

**泳道失败有界重试**(grill-with-docs 设计访谈 + 交互评审三轮收敛 + 夜链评审两轮 + D13 确认;决策:[ADR 0009](docs/adr/0009-bounded-retry-on-lane-failure.md),显式取代 ADR 0007『落者超时/失败记 paused,不拖队』条款——仅该条款,并发帽与调度决策不受影响)。动机:多项目共用上游账号时分钟级并发争抢是常态而非偶发(2026-09-19 十并行子代理 429 集体阵亡实证,CLI 秒级内部重试被持续拥塞打穿),现行"落者超时/失败立即 paused"一次分钟级争抢就丢一整晚产能、恢复全靠次日人工续跑;改为**有界重试**——失败单元先还原再进递增等待梯、梯内自动重派,耗尽才 paused。

### Changed / 改进

- **单元级重试梯**:覆盖实施位、票级评审位、终局全分支 review 三类派发单元(均为主会话子代理),每单元一条独立梯、各自计次;梯形写死 60s 起跳→×2→封顶 15min(N=5 时额外等待合计恰 30min + Σ各次尝试时长);每单元至多 `night_retry_max` 次(`agents.toml [defaults]` 新旋钮,默认 5,**0=关闭**回落现行"失败即 paused");触发=异常终止/回报缺失/超时,四态回报(DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/Blocked)不触发(NEEDS_CONTEXT 走既有补材料通道)。
- **先还原再重派**:失败检出→可归票校验→三步还原(reset→checkout BASE→clean -fd,含越界残留)→还原完成才进等待梯;还原不可归票/还原失败不进梯,走既有"暂停清理记 waiting";票级评审/终局 review 只读,不涉工作区还原。
- **互斥四态→五态 + 占位不回填**:就绪集路径互斥集新增"重试等待中"态(含已还原未重派,视同在跑)——重试中单元占住自己的实施位/评审位,不回填、不进就绪集排队;等待期其他泳道照常、已落地票照常提交。
- **同波错峰 i×30s**:"同一波"=同一次调度循环内检出的失败集合,波内第 i 个(i 从 0 起)等待满后加 i×30s;续跑同一时点到期的等待单元按各自首行检出序号升序重赋 i(从 0 起)。
- **NIGHT 追记行与断链重建**(不新增台账状态):首行在还原完成后落盘——阶段前缀 `impl/review/终局review` + 检出序号 m(m=本夜第 m 个失败检出,全阶段统一递增,终身排序键);此后每次**实际派发时**追记 `… retry k/N(<原因>)`;断链续跑整档重等(按已耗 k 取下一档,不折算档内进度),计数从追记行重建、不重置。
- **耗尽终局**:实施/票级评审耗尽记 `paused(重试耗尽:N×失败,末次原因,阶段=impl|review)`;终局评审耗尽走既有终局阻断 `waiting(终局评审重试耗尽,…)`,finish 不勾;票落定且实施侧重试过(k>0)在票行尾注 `retries=k`(只记实施位)。
- **明确不做**(与 ADR 0007/0008 并行不悖——两者否决的是配置层自动升降 lanes,有界重试是运行时对异常的有界响应,不改 lanes 配置值):无全局重试预算、无独立全局冷却、不自动升降并发;帽外段(冒烟/评审 fan-out/run-agent.sh)仍零重试。

### Scope / 本版边界

- 有界重试语义为**静态契约断言**(flow.md 11.6 + night-parallel 测试),**未压测真实 429**(真实拥塞窗口下的收敛未实测);帽外段(冒烟/评审 fan-out)仍零重试;429 形态探针(支撑二版退出码白名单精准判 429)为独立后续任务。
- 离线测试:night-parallel 40→66(新增有界重试断言 26 条)全绿;不含模型语义与真实托管验证。

## [0.23.0] - 2026-09-19

**并发直设与总并发帽**(grill-with-docs 设计访谈定型;决策:[ADR 0008](docs/adr/0008-concurrency-cap-covers-ticket-review.md))。动机:ferryman 夜(11 票全落地)实证——帽设 2 时画面 4+ 子代理在跑,原帽只卡实施泳道,而 429 阵亡根因是**同时打上游的子代理总数**,帽对不准真实风险;且该值此前只能手改 agents.toml。

### Changed / 改进

- **并发帽改语义(ADR 0008)**:`night_parallel_lanes` 从"实施泳道数"改为**总并发帽**——罩实施位+票级评审位合计的同时在跑数;空位**评审优先**补位(先解锁落地票再派新实施);终局评审同占位;冒烟/评审段 fan-out 不在帽内(后者并发=选集家数,已有自然控制);评审排队不新增台账状态(票保持 committed)。默认 **2→3**(ferryman 干净一夜后的升道,即 ADR 0007 预留路径)。
- **双入口直设**,优先级 `--lanes > night_parallel_lanes`:`/xcheck --night --lanes N` 单晚旗标(单 token 整数 ≥1;仅 `--night` 可携带,否则报错停住;续跑改道只影响后续派发并追记);`/xcheck-setup lanes [N]` 新模式 E(查看/设置,Edit 精确改行,非整数或 <1 报错,≥5 警告不拦——429 前科)。
- **记账与术语**:NIGHT 新增 `lanes = N(来源:--lanes|默认)`(impl 开始写入;账本字段字典加行);泳道泛化为"夜链并发工作位"(实施位/评审位),CONTEXT 词条同步改写;ADR 0007 保持历史原样。
- **文档同步**:README/AGENTS/CONTEXT/CHANGELOG 全量对齐 0.23;`docs/diagrams/` 无并发细节不动。

### Scope / 本版边界

- 并发帽语义为静态契约断言 + ferryman 夜的间接实证;**≥4 道的真实夜链压测未跑**(429 阈值未实测,≥5 警告线是经验值)。
- 离线测试:night-parallel 26→40(新增并发帽断言 14 条)/ review-contract 110 / run-mode 28 / night-git 26 / run-agent 33 = **237 项全绿**;不含模型语义与真实托管验证。

## [0.22.0] - 2026-09-19

**Pre-release / 预发布**:精简管道重构——在 rc.1 三批(0.19~0.21)基础上,经 grill-with-docs 设计访谈 + codex/pi 三轮盲评(16→15→11 收敛)定型。设计:[0.22 lean pipeline redesign](docs/superpowers/specs/2026-09-19-xcheck-0.22-lean-pipeline-redesign.md)(含 rev1/rev2 与终审附录);决策:[ADR 0004–0007](docs/adr/)。

First prerelease of the lean pipeline redesign, consolidating the rc.1 batches under review-driven revision (three blind review rounds, findings 16→15→11, convergent).

### Changed / 改进

- **机械层收缩(批次A)**:`night-git.sh` 116→95 行三动词——start(接管检出/幂等/操作者改动阻挡→blocked)、snapshot(stash create+update-ref 防 gc 脏内容快照)、publish(显式URL直推+`--no-verify`+`GIT_TERMINAL_PROMPT=0`+`GCM_INTERACTIVE=never`+清空ASKPASS+ssh BatchMode+绝不force);**credential.helper 不再清空**(GCM 缓存凭据是 HTTPS 合法主路径——rc.1 的清空设计会让整晚推送全失败,盲评坐实)。`night-pr.sh` 及 73 条测试删除(ADR 0006)。测试 46→26 条只留不变式断言(含 hook 偷运被 `--no-verify` 阻断、非 ff 绝不 force 两条对抗测试)。
- **账本塌缩与契约精简(批次B)**:PROGRESS 删 delivery_schema/七冻结字段/night=on/implementation_blocked 族,新增 `material = trusted|external`(来源外部无论键入粘贴一律 external,第11步失败关闭门);NIGHT 收为 0.22 字段集;**账本字段字典单源节**+36 项同步锁测试;NIGHT_MODE 派生层删除(闸门只看 INTERACTION/TARGET);入口改**旗标直选**(无旗标=交互审核,删三选一);**旧协议链一律拒绝续跑+提示新开**(迁移矩阵与 migrated_from 删除)。
- **并行实施(批次D,ADR 0007)**:事件驱动就绪集(依赖全complete ∧ 路径与在跑/paused未清/committed-unreviewed/rework票及脏区不相交 ∧ 泳道有空位;任一票落地触发重算);**编辑并行提交串行**(泳道 agent 只改文件严禁 git add/commit,主会话按票 `git commit --only --no-verify`);失败票路径还原三步(reset→checkout BASE→clean -fd);rework 追加提交≤2轮;`night_parallel_lanes=2` 起步(429 实证);派单包内联涉及路径文件(目标单票 38→≤20 轮);终审最强档。
- **五文档同步(批次C)**:AGENTS/README/CONTEXT/artifacts 全量对齐;CONTEXT 新术语:接管检出、就绪集与泳道、旗标直选;23 条评审回归全部修复(复审面板钉死、终审最强档、修订稿自代入纪律、第7步查证边界、铁律3"未决逐个问"、背景诚实语等)。

### Scope / 本版边界

- **live 验证未做**(rc→正式版门禁):真实仓库夜链端到端(接管/并行/每票即推/compare链接)未跑;验收四指标——单票平均轮数 ≤20(基线38)、并行度≥2时间占比>50%、意图票数均摊墙钟下降、P90:P50 不劣化;脚本口径沿用外部速度诊断文档。
- 夜链建议 0 点后启动(22–24 点晚高峰实测 3–6 倍延迟);工具下限 bash≥4.4 / git≥2.36(README 记录)。
- 配置分离与逐 CLI 权限隔离仍未实施;敌意环境配置(TM-3)明确出范围(ADR 0004,触发条件=夜链自动实施不可信外部材料前必须先上沙箱)。
- 离线测试:review-contract 110(含同步锁)/ run-mode 28 / night-git 26 / night-parallel 26 / run-agent 33 = **223 项全绿**;不含模型语义与真实托管验证。

## [0.21.0-rc.1] - 2026-09-19

**Pre-release / 预发布**:首个包含下列0.19–0.21三批改动的发布标签;下面的0.19.0/0.20.0条目是开发阶段记录,不是另行发布的正式版本。五套本地检查共258项通过;真实多CLI端到端、真实托管PR/通知与完整回放产物比对尚未完成。配置分离与CLI强制权限隔离仍未实现。

First prerelease containing the three development batches below. The 0.19.0/0.20.0 entries are development milestones, not separate stable releases. All 258 local checks pass; live multi-CLI workflows, hosted PR/notification integration and complete replay-artifact comparison remain unverified. Configuration separation and enforced CLI access isolation are not included.

### Changed / 改进

- **Isolated night delivery, batch 3.** The previous night workflow committed specs/tickets and pushed the host branch, while later recovery could confuse current HEAD with the original baseline. New `delivery_schema = 1`, independent of review_schema=2, freezes host_repo, full start_oid, source_branch, remote_name, unique push remote_url and pr_base at intake; revisions inherit them. Night consensus, revisions and appendices stay under `.xcheck/`, with source=inline and original_source for provenance only. An external worktree is prepared before the first spec; specs, tickets, minimal ignore changes and code commit only on that night branch. The original branch is never committed, pushed, pulled or rebased; uncommitted business changes are not stashed, copied or silently included.
- **隔离夜链交付,第三批。** 旧夜链在原分支提交spec/票并收工直推,恢复又可能把当前HEAD误当启动基线。新增独立于review_schema=2的 `delivery_schema = 1`,摄入冻结host_repo、完整start_oid、source_branch、remote_name、唯一push remote_url与pr_base,复审继承。night共识/修订/附录只写.xcheck,source=inline、original_source仅追溯;第一份spec前建立仓库外worktree,规格、票、最小忽略规则与代码仅同一夜链分支提交。原分支不commit/push/pull/rebase,业务未提交改动不自动stash、复制或纳入基线。

### Added / 新增

- **Versioned delivery contract and mechanical Git helper.** `lib/night-delivery.md` defines boundaries; `lib/night-git.sh` prepares, verifies and publishes the night worktree/branch. Resume checks repository/worktree identity, branch and reachability of every completed full OID, plus separately recorded test and independent-review evidence. Missing worktrees/branches/commits pause this batch; they are not rebuilt from a spec while skipping old completed tickets. Legacy night metadata without delivery_schema is not auto-resumed, even with review_schema=2, and current HEAD cannot be guessed into a missing baseline.
- **交付契约与机械Git helper。** `lib/night-delivery.md`集中边界,`lib/night-git.sh`提供prepare/verify/publish。恢复核验仓库/worktree身份、分支及每个complete完整OID可达,另核测试和独立评审证据;worktree/分支/提交丢失本批暂停,不从spec重建后跳旧票。旧night缺delivery_schema时停止自动恢复,包括review_schema=2记录;不从当前HEAD补猜缺失基线。
- **Publication is separate from implementation.** Only the frozen night branch is pushed; PR lookup/create uses explicit frozen repo/base/head and a self-contained body covering scope, evidence and unfinished work. Missing remote permits local work; missing tools, login or remote base leaves PR uncreated without pushing the base. No force or automatic merge. Ordinary review/auto-review file behavior remains; diag short reports never create worktrees.
- **发布与实施分别记账。** 只推冻结夜链分支,PR显式repo/base/head查询复用或创建,正文自包含范围、证据与未完成工作。无remote可本地执行;缺工具、未登录或远端base不存在则不建PR,不为此推base。不force/自动合并;正常审核/auto-review文件行为保留,diag短稿不建worktree。

### Scope / 本批边界

- **Explicit GitHub PR helper / 显式GitHub PR助手:** `lib/night-pr.sh github <host/owner/repo> <base> <branch> <title> <UTF-8 body-file>` queries and reuses an open same-repository PR or creates one, with no create-on-query-failure fallback. Gitea is not managed by this helper; the controller may use tea only after verifying its explicit target, otherwise it records no PR. 显式查询同目标开放同仓PR后复用或创建,查询失败不转创建;Gitea仅在主会话可核实tea目标时操作,否则记未建,不宣称全面托管支持。

- **Batches 4–5 remain unimplemented:** configuration separation and enforced per-CLI isolation. Batch 3 actual offline results: night-git 46 passed/0 failed; night-pr 73/0; review-contract rerun 73/0; run-mode rerun 33/0; supervisor rerun 33/0. All five suites total 258 passing checks across different scopes, not end-to-end proof; diff and bash syntax checks also passed. Temporary repositories/local bare remotes and stub gh calls are not live hosting, tea or multi-CLI end-to-end validation. Earlier replay-artifact permission limitations remain unchanged.
- **第四、五批仍未实施:**配置分离与真正逐CLI权限隔离。第三批实际离线结果:night-git 46通过/0失败、night-pr 73/0、review-contract复跑73/0、run-mode复跑33/0、supervisor最终复跑33/0。五套共258通过、0失败,范围不同、不代表端到端;diff与bash语法检查通过。仅临时repo/本地bare remote及stub gh,未验收真实托管、tea或多CLI端到端。前批回放产物权限受限记录保留。
- Design / 设计:[审核收敛与可分发配置](docs/superpowers/specs/2026-09-19-xcheck-review-convergence-and-portability-design.md). Plan / 分批计划:[实施计划](docs/superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md).

## [0.20.0] - 2026-09-19

### Added / 新增

- **Interaction and delivery target separated, batch 2 only.** Previously unattended review required selecting the full implementation night chain. `--auto-review` now selects `unattended/review`; `--night` remains `unattended/implementation`, and the two flags are mutually exclusive. A new run without either flag offers one three-way choice: full night (recommended), unattended review only, or interactive review. All new PROGRESS records, including diag, persist `interaction` and `target`. The real pure parser `lib/run-mode.sh` normalizes requests and persisted fields; it does not execute work or grant permissions.
- **交互方式与执行终点解耦,仅第二批。** 旧入口把无人值守审核与完整实施夜链绑在一起。新增 `--auto-review`→`unattended/review`;`--night`保持`unattended/implementation`,两旗标互斥。无旗标新链一次三选:完整night(默认推荐)、仅无人值守审核、正常交互审核。所有新PROGRESS(含diag)保存interaction/target;新增真实纯解析helper `lib/run-mode.sh`,只规范化请求与持久化字段,不执行任务或授予权限。

### Changed / 改进

- **Resume cannot change the original mode.** Both new fields must be absent for legacy mapping (`night=on` → full night; absent night → interactive review). Partial, invalid or contradictory metadata fails closed; explicit mode requests must match the original run. Review targets never create NIGHT, enter step 11, notify, push or open PRs, but local review snapshots, consensus/revision files and appendices remain allowed. `夜间收工` remains a compatible unattended-policy stop label for both auto-review and night, not implementation permission. Diag never implements; full night retains its NIGHT short report and optional notification, while auto-review diag creates neither NIGHT nor notifications.
- **续跑不能改变原模式。** 仅两新字段同时缺失才兼容映射旧night=on为完整night、无night为正常审核;半缺、非法或矛盾记录拒绝,显式模式与原链不符不能接管。review终点不建NIGHT、不进第11步、不通知/推送/PR,仍可写本地审核快照、共识/修订稿与附录。“夜间收工”兼容用于auto-review与night的策略停止,不授予实施权限;diag任何入口不实施,完整night保留NIGHT短稿/可选通知,auto-review diag不建NIGHT、不通知。

### Scope / 本批边界

- **Batches 3–5 remain unimplemented.** Spec/ticket documents still commit and push on the host branch under the existing night workflow; same-branch delivery, configuration separation and enforced per-CLI isolation are not delivered. Batch 2 tests are tracked separately and must not be inferred from batch 1's 73 offline checks and 33 supervisor assertions. Batch 1's replay-artifact permission limitation and unrun live multi-CLI validation remain recorded in the plan.
- **第三至五批未做。** spec/票仍按现行夜链在主仓当前分支提交和推送;同分支交付、配置分离、真正逐CLI隔离尚未实现。第二批测试另行记录,不能把第一批73项离线检查、33项supervisor断言当本批通过证明;第一批回放产物权限受限及真实多CLI端到端未执行记录继续保留。
- **Offline tests / 离线测试:** batch 2 run-mode 33 passed, 0 failed; review-contract rerun 73 passed, 0 failed; supervisor rerun 33 passed, 0 failed. 第二批模式测试33通过、0失败,既有契约检查复跑73通过、0失败,supervisor回归复跑33通过、0失败;diff检查通过。真实CLI/发布/通知仍未验收,不能以离线通过替代。
- Design / 设计:[审核收敛与可分发配置](docs/superpowers/specs/2026-09-19-xcheck-review-convergence-and-portability-design.md). Plan / 分批计划:[实施计划](docs/superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md).

## [0.19.0] - 2026-09-19

### Changed / 改进

- **Review convergence, batch 1 only (tasks 1–4).** The previous “confirmed = must-fix” union and fresh full review on every revision let ordinary suggestions prolong review and silently expand implementation scope. New review runs use `review_schema = 2`, stable D decisions (`decisions.md`) and F findings (`FINDINGS.md`), with source mapping and cross-round history. Intake preserves explicit targets, binds short answers to their questions/options, records superseded decisions and missing context, and does not treat unconfirmed assistant proposals as agreement. Fact verification is separate from disposition: only open blockers or concrete major risks pending evidence/decision constrain the affected paths; ordinary suggestions may remain without requiring revision. SUMMARY and appendices project the recorded rulings. Re-review uses `re-review-context.md` and a dedicated template for original fixes, regressions and new major defects, not another open-ended search for minor improvements. Night performs at most one authorized, actionable automatic revision; stopping or handing off does not clear unresolved constraints.
- **审核收敛,仅第一批(任务1–4)。** 根因是旧“属实即必改”并集与每轮完整重新评审,让普通建议持续触发修订并隐式扩张实施范围。新review写 `review_schema = 2`,新增稳定D决策快照 `decisions.md`、稳定F问题记录 `FINDINGS.md`,保留来源映射与跨轮历史。摄入保留显式对象、短答的问题/选项绑定、后续修正及上下文缺失,助手未确认提议不当共识。事实核实与处置裁定分离:只有开放阻断或有具体重大后果的待决风险约束相关路径,普通建议可留存而不触发修订。SUMMARY/附录从裁定记录投影。复审通过 `re-review-context.md` 与专用模板验证原约束修复、回归和新重大缺陷,不重新开放寻找一般建议。night最多一次已授权且有可执行修复的自动修订;交付或预算耗尽不解除约束。
- **Scoped downstream handoff and versioned recovery.** Specs/tickets inherit confirmed decisions, necessary fixes and acceptance goals; selected optional suggestions do not become new stories or tickets without adoption. Tickets distinguish `complete` (reachable commits and verification evidence), `paused` (direct constraint and release condition), and `blocked` (unfinished dependencies). Unknown independence is not permission to proceed; unresolved constraints cannot be docked into completion or reported green. Finished legacy reviews retain legacy meanings; unfinished legacy reviews migrate idempotently to a linked new run without inheriting approval. Legacy NIGHT runs with planning artifacts or implementation started stop automatic recovery, rather than replaying implementation or old host-branch pushes. Missing required schema2 ledgers, unknown schemas, missing worktrees/branches or unreachable completed commits stop recovery. Diag keeps its original synthesis/triage behavior.
- **限定下游交付与分版本恢复。** spec/票仅继承已确认决策、必要修复和验收目标,精选一般建议未被采纳不转新故事或票。票区分 `complete`(可达提交及验证证据)、`paused`(直接约束及解除条件)、`blocked`(依赖未完成)。未知独立性不能默认放行,未解除约束不能靠停靠变完成或报全绿。已结束旧review保留旧语义;未完旧review幂等迁移关联新环重新审核,不继承旧通过。已有plan产物或实施记录的旧NIGHT停止自动恢复,不重放实施或原分支推送。新版必需账本缺失、未知schema、worktree/分支丢失或完成提交不可达时停止恢复。diag保持原综合与三分类。

- **Final review safeguards / 终审护栏:** downstream specs bind to the latest reviewed proposal snapshot and its D/F records, never the directory's highest revision or a changed source file; incomplete/invalid finding records cannot count as zero constraints. 下游只认最新已审快照及同环D/F,不取目录最高rev或被外改的source;问题字段缺失/枚举非法不能被过滤成零约束,历史已解除问题不能因旧事实属实自动重开。

### Scope / 本批边界

- **Waiting is resumable, not finished.** Paused/blocked tickets or global pending decisions write `NIGHT.waiting` with release conditions; impl/finish remain unchecked while a preliminary morning report may be delivered. Resume validates new evidence/decisions and updates D/F before rescheduling; without new evidence it returns the pause summary without repeating implementation, publication or notifications. Migration preserves `auto_revisions_used`; an unknown prior budget disables another automatic revision.
- **暂停待解除不等于收尾完成。** paused/blocked或全局待决写入NIGHT的waiting及解除条件,impl/finish保持未勾,晨报可先交付。续跑先核新证据/决策并更新D/F再调度,没有新证据则返回暂停摘要,不重复实施、发布或通知。迁移保留auto_revisions_used;无法核实已用预算时禁止自动再修。

- **Batches 2–5 remain unimplemented:** no new `--auto-review` command, no template/personal configuration split, no enforced per-CLI access isolation, and no same-night-branch delivery migration. Current CLI material scope is a prompt instruction, not a security sandbox. Current night still commits and pushes spec/ticket documents on the host branch under the 0.18.0 workflow; the original-branch-unchanged goal is not delivered here. Offline contract/fixture checks are not proof of live model behavior or real CLI end-to-end validation.
- **第二至五批尚未实施:**没有新增 `--auto-review`,没有模板/个人配置分离,没有真正逐CLI权限隔离,也未完成夜链同分支交付迁移。当前CLI材料范围是提示词要求,不是安全沙箱;night仍按0.18.0流程在主仓当前分支提交并推送spec/票,本批未实现“原分支不变”。离线契约/样例检查不等于真实模型行为或真实CLI端到端验证。
- Design / 设计:[审核收敛与可分发配置](docs/superpowers/specs/2026-09-19-xcheck-review-convergence-and-portability-design.md). Plan / 分批计划:[实施计划](docs/superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md). README / AGENTS / CONTEXT / artifacts synchronized for batch 1 / 五处文档按第一批同步。

## [0.18.0] - 2026-09-19

### Changed / 改进

- **Night chain auto-push & readable finish: iron rule 9 reversed — progress always reaches the remote, and the ending is conclusion-first.** Root causes (2026-09-19 grilling, 12 decisions + renhua audit): a night chain runs for hours with everything stranded on one machine (branch, spec, tickets — machine failure = total loss); the finish had no defined chat output (the model improvised, hard to read); Pushover messages couldn't be attributed to a project. Now: **push discipline** — the worktree branch is pushed on creation (baseline carries spec/tickets) and after every completed ticket (each a green vertical slice), the finish pushes the host repo's current branch (spec/tickets/.gitignore doc commits; on non-fast-forward reject: one `git pull --rebase` retry, never force) and opens a PR (base = host current branch, idempotent, title `xcheck 夜链 <ts>:<spec topic>`, body = verdict + ticket states + docked list + morning-report path via UTF-8 `--body-file`); tool chain degrades GitHub gh → Gitea tea → push-only; every failure skips-with-notification, never blocks. **Finish output, three layers one skeleton「夜链结论 → 简报 → 推荐下一步」**: chat ending (four-value verdict + numbers + PR link, ≤5-line briefing, ≤3 command-level next steps with the single most important action first), Pushover (title `【<project>】夜链<verdict>` — project name from origin repo name, dir name as fallback; body = topic + completion numbers + morning-report path; no bare IDs, no branch names; `url` param deep-links the PR; title AND body through UTF-8 files — same GBK cause as 0.17.0's message fix), MORNING.md keeps the four questions with all rulings demoted to a tail appendix ("停靠" glossed on first use). New **夜链结论 four-value verdict** (全绿 / 带停靠完成 / 未完成 / 失败收工; short-form terminals record 未执行实施(reason)) shared by every layer; NIGHT.md gains `push`/`pr` header fields; iron rule 9's outward ban becomes a whitelist (per-ticket push / finish PR / host-branch push) — force push, auto-merge, tracker, main-checkout still banned. renhua audit fixes folded in: machine words purged from gate dialogs (③类→拿不准的风险点, round=3→第三轮, bare terminal-state values dropped), entry-question options rewritten in plain language, resume-dialog stage names glossed in plain words, SKILL.md's four-question list aligned to flow.md's (was a stale third variant). ADR: `docs/adr/0003-night-chain-auto-push.md`. flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md all synced. Design: `docs/superpowers/specs/20260919-xcheck-night-push-and-report-design.md`.
- **夜链自动推送 + 收尾三段式:铁律 9 反转——进度必上远端,收尾结论先行。** 根因(2026-09-19 grilling 12 项决策 + renhua 审计):夜链一跑数小时,产出(分支/spec/票)全部困在本机,机器故障即全损;收尾没有对话播报规范,模型自由发挥、看不懂;Pushover 通知认不出是哪个项目。现在:**推送纪律**——worktree 分支建立即推(基线含 spec/票)、每票完成即推(绿态竖切,不是半成品)、收工直推主仓当前分支(spec/票/.gitignore 文档性提交;被拒非 fast-forward → `git pull --rebase` 一次重试,绝不 force)、收工开 PR(base = 主仓当前分支,幂等,标题 `xcheck 夜链 <ts>:<spec 主题>`,正文 = 结论 + 票状态 + 停靠清单 + 晨报路径,中文走 UTF-8 `--body-file`);工具链 gh(GitHub)→ tea(Gitea)→ 只推分支;任何失败降级通知、不挂链。**收尾输出三层统一「夜链结论 → 简报 → 推荐下一步」**:对话收尾(四值结论 + 数字 + PR 链接、简报 ≤5 行、命令级下一步 ≤3 条且第一条永远是当前最该做的单个动作)、Pushover(title=`【<项目名>】夜链<结论>`——项目名取 origin 仓库名,无远端用目录名;正文 = 主题 + 完成度数字 + 晨报路径,不带裸 ID、不带分支名;`url` 参数直达 PR;title 与正文都走 UTF-8 文件——与 0.17.0 的 message GBK 修复同因同修)、晨报保留四问、全部裁定降级到文末「裁定与停靠附录」("停靠"首现带解释)。新增**夜链结论四值**(全绿/带停靠完成/未完成/失败收工;短稿终态记"未执行实施(<原因>)")各层共用;NIGHT.md 头部新增 `push`/`pr` 字段;铁律 9 对外禁令改为白名单(每票推送/收工开 PR/主仓分支直推三类),force push、自动合并、上 tracker、动主工作区仍全禁。renhua 审计修复并入:停点弹窗机器词清洗(③类→拿不准的风险点、round=3→第三轮、裸终态值删除)、入口一问选项白话化、续跑弹窗阶段名加人话旁注、SKILL.md 四问清单对齐 flow.md(原是过期的第三套)。ADR:`docs/adr/0003-night-chain-auto-push.md`。flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md 已同步。设计稿:`docs/superpowers/specs/20260919-xcheck-night-push-and-report-design.md`。

## [0.17.0] - 2026-09-17

### Added / 新增

- **Auto-first night chain: `/xcheck` asks one entry question — auto-advance (recommended default) or interactive — and auto mode runs review → spec → tickets → per-ticket implementation unattended; you wake up to a local branch and a morning report.** The entry question (skipped entirely by `--night`, the pure-unattended shortcut) sets night semantics: the chain's human openings auto-pass — the shell auto-resumes unfinished chains, the object resolver's best inference takes effect without a popup (archived to `<ts>/night-intake.md`), and the gate auto-decides per policy (round 0 with must-fix open → auto-revise + re-review, originals untouched; round ≥ 1 still open → auto-ship with the verified three-tier list as new terminal `夜间收工`). New **step 11 (夜间接续)** then follows Matt Pocock's main flow downstream: **`to-spec`** solidifies the reviewed proposal + appendix into an implementation spec (local file under `docs/superpowers/specs/`, never published to an issue tracker at night; tier-③ and inconclusive tier-② watch items carried into the spec; the seams check auto-ruled and ledgered), **`to-tickets`** splits it into tracer-bullet tickets (local `.scratch/<slug>/issues/`, one file per ticket: what-to-build + acceptance criteria + blocked-by; the granularity quiz auto-ruled), then **per-ticket implementation inside an isolated worktree (from local HEAD — night never pushes)**: blockers-first frontier, strictly serial, a fresh subagent per ticket doing TDD red-green with covering tests and commits, each ticket gated by an independent dual-axis reviewer (spec compliance + code quality) with a ≤5-round fix loop, closed by a final whole-branch code review with exactly one fix wave. **Automation priority is the highest iron rule**: every "ask the user" gate in the downstream skills auto-passes with a ledgered ruling; the only stops are irreversible/destructive operations, security-sensitive actions, side effects outside the worktree, and a plan where every path is a guess — stop + notify. Safety rails unchanged: no push / PR / merge / rebase-main / touching the main checkout; code lands on a local worktree branch. Terminal artifacts: `NIGHT.md` (4-stage ledger `review/plan/impl/finish` with a per-ticket ledger as the resume anchor for the implementation leg) and `MORNING.md` (four-question plain-language report + every ruling). Notifications at three milestones via direct Pushover curl with the message body passed through a UTF-8 file (inline Chinese in curl args gets re-encoded to GBK by the Windows ANSI codepage and arrives as question marks — proven by binary trace, fixed); unconfigured/failed → skipped, never blocks. PROGRESS header gains optional `night = on`; terminal enum six → seven values. flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md all synced. Design: `docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md` (+ `.rev2.md`).
- **自动优先夜链:`/xcheck` 先问一句——自动推进(默认推荐)还是正常交互;自动模式无人值守跑完"评审 → 固化 spec → 拆票 → 逐票实施",早上醒来代码在本地分支上、晨报在等你。** 入口一问(`--night` 可整句跳过,纯无人值守快捷键)选定夜链语义后,链的人工开口全部自动过:壳自动续未完成链;对象解析器最优推断直接生效不弹窗(留档 `night-intake.md`);停点按既定策略自动拍板(round 0 必改非空 → 自动修订 + 复审一轮,原稿不动;round ≥ 1 仍非空 → 自动带清单收工,记新终态 `夜间收工`)。新增**第 11 步(夜间接续)**,下游采用 Matt Pocock 主流程:**`to-spec`** 把评审后的方案 + 附录固化成实施 spec(落本地 `docs/superpowers/specs/`,夜里不发 issue tracker;③存疑与②无定论的"开发时要盯"条目随附录进 spec;seam 确认关卡自动裁定记账)、**`to-tickets`** 拆成 tracer-bullet 票(本地 `.scratch/<slug>/issues/`,一票一文件:建什么 + 验收标准 + 阻塞关系;拆票确认自动过),随后**隔离 worktree 内逐票实施(基于本地 HEAD——夜链绝不 push)**:blockers 优先、严格串行,每票一个全新子代理 TDD 红绿循环(覆盖测试 + 提交),每票由独立评审者双轴把关(Spec 符合 + 代码质量),修复环每票上限 5 轮,收尾一次终局全分支评审 + 恰好一轮修复。**自动化优先级是最高铁律**:下游技能一切"问用户"的关卡一律自动通过、当场裁定记账;唯一停链例外 = 不可逆或破坏性操作、安全敏感、出 worktree 的副作用、全盘皆猜——停下推通知。安全栏不变:不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区;代码全部落在本地 worktree 分支。终局产物:`NIGHT.md`(四阶段账本 `review/plan/impl/finish`,impl 段票级台账 = 逐票续跑锚点)与 `MORNING.md`(四问人话晨报 + 全部裁定清单)。三节点通知由主会话直推 Pushover,正文走 UTF-8 文件(中文内联 curl 参数会被 Windows GBK 代码页重编码、到手全变问号——二进制 trace 实证后修复);未配置或失败 → 跳过不阻塞(晨报兜底)。PROGRESS 头部新增可选 `night = on`;终态枚举六值 → 七值。flow/SKILL/AGENTS/README/CONTEXT/docs/artifacts.md 已同步。设计稿:`docs/superpowers/specs/2026-09-17-xcheck-night-chain-design.md`(含 `.rev2.md`)。

## [0.16.0] - 2026-09-17

### Changed / 改进

- **B'' landed: smoke parallelized, re-review rings may skip smoke, collect gets the liveness gate.** (Implements the reviewed perf proposal's B'' with the delivery-list refinements baked in.) Smoke now launches all channels concurrently in one message (background-start + block-in-turn discipline; wall = max, not sum — default-set serial 75s → ~45s expected). A re-review ring skips a channel's smoke only when all three hold: (a) it is a re-review ring; (b) the channel's **most recently actually-executed** smoke passed **and** `agents.toml` is unchanged since — evidenced by a `sha256sum` recorded as `smoke_cfg` in that ring's PROGRESS header at smoke time (skip states do **not** propagate: only the latest real smoke counts); (c) the previous ring's run for that channel fully succeeded (`exitcode == 0` **and** `.summary.md` produced — smoke-only-pass doesn't count). The skipped ring's PROGRESS smoke box still gets checked with an annotation. Backstop: **collect-stage liveness gate, all rounds** — `exitcode ≠ 0` / spawn failure / missing `.summary.md` or `<name>.raw.out` (exact protocol names) → `failed.md` with no failure-code enumeration (any non-zero is a failure); survivors < 2 → stop. flow.md/AGENTS/README/CONTEXT/docs/artifacts.md synced (PROGRESS header gains `smoke_cfg`).
- **B'' 落地:冒烟并行化、复审环可跳冒烟、collect 判活闸门。**(实施已过审提速方案的 B'',并把交付清单里的细化一并烧进:冒烟改为一条消息并发后台跑(后台启动+回合内阻塞纪律;wall=max 非 sum——默认集串行 75s → 预计 ~45s)。复审环跳过某通道冒烟须三条件全满足:(a) 复审环;(b) 该通道**最近一次实际执行**的冒烟通过**且** `agents.toml` 自那次未变更——凭据为冒烟通过时记入当环 PROGRESS 头部 `smoke_cfg` 的 `sha256sum`(跳过状态**不传递**,只认最近一次真实冒烟);(c) 上一环该通道完整成功(`exitcode == 0` **且**产出 `.summary.md`,只冒烟过不算)。跳过环的 PROGRESS smoke 照勾带注记。兜底:**collect 判活闸门,全轮生效**——`exitcode ≠ 0` / spawn 失败 / 产物缺 `.summary.md` 或 `<name>.raw.out`(精确协议名)任一 → `failed.md`,不枚举失败码(任何非零即失败);幸存 <2 → 停。flow.md/AGENTS/README/CONTEXT/docs/artifacts.md 已同步(PROGRESS 头部新增 `smoke_cfg`)。

## [0.15.1] - 2026-09-17

### Changed / 改进

- **Smoke precheck: per-agent budget + one automatic retry on timeout.** Multi-call channels (pi) slow down as a whole when their upstream degrades — the fixed 60s budget produced false kills (four same-day occurrences: two 61s stalls recovered on retry, one double-stall recovered at 120s). Step 2 now reads a per-agent `smoke_timeout_sec` from agents.toml (default 60; pi ships 120) and auto-re-runs a timed-out smoke exactly once before excluding the agent ("slow, not dead" — verified pattern); non-timeout failures (65/66/67, non-zero CLI codes, echo-miss) still exclude immediately. Tested: `bash xcheck/tests/run-agent.test.sh` 33/33.
- **冒烟预检:按通道配预算 + 超时自动重试一次。** 多轮调用通道(pi)在上游降速窗口整体变慢——固定 60s 预算产生假击杀(当天四次:两次 61s 停顿重试即过,一次两连停 120s 过)。第 2 步改读 agents.toml 的 per-agent `smoke_timeout_sec`(缺省 60;pi 出厂 120),超时自动原样重跑一次(仅一次)才剔除("慢非死",实证模式);非超时失败(65/66/67、非零 CLI 码、回显缺失)仍立即剔除不重试。已跑 `bash xcheck/tests/run-agent.test.sh` 33/33。
- **Recorded experiment: pi per-run direct route to the bigmodel coding endpoint is auth-blocked.** `pi -p --model bigmodel/glm-5.3` returns 401 — the bigmodel provider in pi's config carries no API key (keys live only in cc-switch). The root fix (put the key in pi's auth, or change cc-switch's routing) is global-config territory and stays behind the backup/verify/rollback discipline until the user opts in; agents.toml keeps the finding as a comment. flake absorption currently rests on the budget+retry above.
- **实验记录:pi 直连 bigmodel coding 端点的 per-run 路线被鉴权挡死。** `pi -p --model bigmodel/glm-5.3` 返回 401——pi 配置里的 bigmodel provider 没有密钥(密钥只在 cc-switch)。根治(给 pi 配密钥 / 改 cc-switch 路由)属全局配置,留在备份-验证-回滚纪律后待用户拍板;agents.toml 以注释留档。波动吸收目前靠上面的预算+重试。

## [0.15.0] - 2026-09-17

### Changed / 改进

- **Mission restated: the chain delivers a classified list, not a perfect plan.** Root cause of the "I can't tell what to decide and the verdict read like jargon" feedback after the first true end-to-end run (xcheck reviewing its own perf proposal, 3 rounds, 32 verified findings): the chain was framed as *converge or die* — "must-fix cleared" was the pass line and two dirty rounds auto-triggered "start over". New **终点观 (endpoint doctrine, iron rule)**: the mission is to sort findings into the three tiers — ① verified on the spot (evidence in hand), ② experimentally testable (resolved to 成立/不成立/无定论 by running it), ③ uncertain (risk points that only coding/testing will settle) — and hand that list to downstream development. Research cannot clear everything; tier-③ belongs to the build phase. **Walking into development with the list is a first-class exit, not a failure.** "Start over" is reserved for directional flaws a reviewer actually named; unclean details never justify it.
- **使命重述:链交付的是分类清单,不是完美方案。** 首次端到端实跑(xcheck 评自己的提速方案,3 轮、32 条查实)后"看不懂要决定什么、汇报全是黑话"的根因:链被框成"要么收敛要么推倒"——必改清零是及格线,两轮改不干净自动判推倒。新立**终点观(铁律)**:使命是把发现按三类分清——①当场查实(证据在手)②可做实验(跑完归入成立/不成立/无定论)③存疑(编码/测试阶段才见分晓的风险点)——把清单交给下游开发。调研阶段清零一切本就不可能,③类天生属于开发期;**带着清单进开发是一等公民出口,不是失败**。"推倒重来"只留给评审点名方向性错误的情形,细节改不干净永远不构成推倒理由。
- **Self-contained plain-language delivery, four mandatory questions.** Step 9's chat rendering is now a fixed four-question structure — 【这次评了什么】【发现了什么】(by the three tiers, each with who raised it + how it was verified)【改了什么】【你现在要决定什么】(options + consequences + one recommendation); missing any question = failed delivery. New **自包含铁律**: the chat must be understandable and decidable *without opening any file — SUMMARY.md, the plan, and revisions are archives, never required reading*. A machine-word ban list (`#n`, AGREE/SUGGEST_CHANGES, ①②③, m/round, 终态, 必改项, fanout/collect/triage, 推倒重来…) now requires translation into plain language inside any chat line; the stop-point question must be answerable without looking at SUMMARY.
- **自包含人话交付,四问缺一即败。** 第 9 步对话呈现固定为四问结构——【这次评了什么】【发现了什么】(按三类,每条带谁提的+怎么核实的)【改了什么】【你现在要决定什么】(选项+后果+一个建议);缺任何一问=交付失败。新立**自包含铁律**:对话呈现必须不看任何文件就能懂、就能选;SUMMARY/方案/修订版只是留底,绝不是"让用户自己去看"的理由。机器词禁用清单(`#n`、AGREE/SUGGEST_CHANGES、①②③、m/round、终态、必改项、fanout/collect/triage、推倒重来…)进对话必须翻译成人话;停点问句不看 SUMMARY 也能选。
- **Stop point is now neutral two-choice; m=2 no longer auto-condemns.** With must-fix items open, the gate asks "改掉再评一轮,还是带着这份三类清单直接进开发?" — both directions presented as equals (no more "fix first" implication); choosing the list ends the chain as `用户不修` (semantics: handed downstream with the verified list). At round 2 with must-fix still open, the chain does **not** auto-terminal "start over" — it presents both sides (nature of the remaining items vs reviewers' own assessment of the direction) and offers three choices: revise again (no more round cap), ship with the list, or confirm start-over. Revision cap is now soft.
- **停点改中性两选;m=2 不再自动判死。** 必改非空时停点问"这 N 条已查实的问题:现在改掉再评一轮,还是直接带着这份三类清单进入开发?"——两个方向平等呈现,不再暗示"改才对";选清单则终态 `用户不修`(语义:带着已验证清单交下游,不是失败)。第 2 轮后必改仍非空时**不自动终态"推倒重来"**,而是把矛盾双方摆全(剩余条目的性质 vs 各家理由段对方向的定性),三选:再修一轮(round=3 起无上限)/ 按现状收工 / 确认推倒。修订上限由硬改软。
- **Review appendix promoted to the chain's primary deliverable.** The end-of-document appendix is now explicitly framed as *the* handoff artifact for downstream development: tier-① items (what to change + evidence), tier-② results (+ experiment artifacts), tier-③ watch items (trigger + "stop and report, don't silently work around"), plus revision paths and artifacts dir.
- **评审附录升格为链的主交付物。** 文末附录明确定位为交给下游开发直接消费的交付物:①查实的(改什么+证据)· ②实验已做的(结果+实验产物)· ③存疑的(触发点+命中动作),外加减版路径与产物目录。

## [0.14.1] - 2026-09-16

### Changed / 改进

- **Factory default agent set is now `["codex", "pi"]`** (net of two post-0.14.0 tweaks: `pi` briefly removed 3→2, then `kimi` swapped for `pi`). Both `kimi` and `opencode` stay registered and fully usable via `--agents` / `/xcheck-setup default`. README now states the shipped default truthfully.
- **出厂默认 agent 集改为 `["codex", "pi"]`**(0.14.0 后两次调整的净结果:先移除 pi 3→2,后 kimi 换 pi)。`kimi`、`opencode` 仍完整登记,`--agents` / `/xcheck-setup default` 随时可用;README 如实标注出厂默认。

### Docs / 文档

- **Documentation rewritten from scratch, split into two audiences.** Human-facing: `README.md` fully rewritten (the old one had accreted five releases of patch-syncs) — what/why, quick start, the chain, a worked gate example, command reference, artifacts map, guardrails, known limits. AI-agent-facing: new `AGENTS.md` at the repo root (maintainer guide: precise lifecycle, module map with edit-warnings, invariants, state protocol, failure semantics, extension recipes, test & doc-sync obligations) and new `docs/artifacts.md` (consumer guide: how to read `.xcheck/<ts>/`, PROGRESS/SUMMARY formats, terminal states, exitcode semantics, what a host agent may and may not do). All docs are Chinese-primary, matching the repo's implementation files.
- **文档推倒重写,按两类读者分流。** 人类向:`README.md` 全量重写(旧版是五个版本补丁的叠加)——是什么/为什么、快速开始、自动链、停点实例、命令参考、产物地图、原则与已知边界。AI agent 向:新增仓库根 `AGENTS.md`(维护导览:精确生命周期、模块地图与修改注意、不变量、状态协议、故障语义、扩展指南、测试与文档同步义务)与 `docs/artifacts.md`(使用向:`.xcheck/<ts>/` 逐文件解读、PROGRESS/SUMMARY 格式、终态六值、exitcode 语义、宿主 agent 能做/不能做)。全部文档中文为主,与实现文件一致。

## [0.14.0] - 2026-09-16

### Changed / 改进

- **Plain-language verdict delivery — the merged review now answers "can I proceed?"** Root cause of the "I can't tell whether to push forward" feedback: every deliverable talked about the *process* (triage tiers, verdict enums, bare item numbers), never about your proposal. New principle: **chat speaks human, files keep the machine ledger.** Step 9 assembles a mechanical **verdict block** at the top of `SUMMARY.md` — status line (✅ 可推进 / ⚠️ 先修订再推进, decided solely by must-fix count), must-fix items in full (`#n [source][severity·type] one-liner — evidence`), per-agent verdicts, signal, stats — and renders it in chat as plain sentences about *your* plan: "方案能用,但有 N 个问题已经查实,建议改完再动手——改不改你定", each must-fix with who raised it and the evidence, refuted items ("查过,不用理"), and **watch items** (tier-③ + inconclusive tier-②, each with a development-time trigger and a "stop and report, don't silently work around" action). The full SUMMARY dump in chat is gone; numbering/enum/①②③ live only in SUMMARY.md. Design: `docs/superpowers/specs/2026-09-16-xcheck-verdict-delivery-design.md`.
- **结论人话交付——合并评审终于回答"能不能推进"。** "看不懂该不该推进"的根因:交付物全在讲流程自己(三分类、enum、裸编号),没有一句在讲你的方案。新原则:**对话说人话,文件留机器账。** 第 9 步在 SUMMARY.md 顶部机械拼装**结论区**——状态行(✅ 可推进 / ⚠️ 先修订再推进,只由必改数决定)、必改项全文(`#n [来源][严重度·类型] 一句话 —— 证据`)、各家裁决、信号、统计——对话里渲染成人话:"方案能用,但有 N 个问题已经查实,建议改完再动手——改不改你定",每条必改带谁提的+证据,证伪条目"查过,不用理",**开发时要盯**(③全部+②无定论,每条带触发点与"命中:停下反馈,别默默绕过")。对话不再平铺 SUMMARY 全文;编号/enum/①②③只活在 SUMMARY.md。
- **Numbering & severity are now defined, not implied.** triage.md numbers tier-①② items in one global serial (`#1、#2…`, tier-③ unnumbered) and preserves each source review's severity tag (`[高·bug]`-style, `[未标]` fallback) — the must-fix references (`#1、#3`) finally point at something. The synthesis one-liner becomes a **three-pattern verdict** (focused consensus / split opinions / one-sided) with explicit DISAGREE count, feeding the verdict block's signal line.
- **编号与严重度从隐含变定义。** triage.md 给①②类条目全流水编号(`#1、#2…`,③不编号),并保留来源评审的严重度标签(`[高·bug]` 式,丢标兜底 `[未标]`)——必改引用的 `#1、#3` 终于有处可指。汇总总判改**三定式**(焦点共识/意见分裂/一边倒)+ 显式 DISAGREE 计数,喂给结论区信号行。
- **Broadcast discipline: the chain tells you what you owe at every moment.** Steps 4–8 broadcast one or two human lines each, marked "无需操作" (e.g. "✓ 3/3 家返回,正在逐条核实,这几分钟不用你做任何事"); details land on disk only. The only question in the whole chain is the gate, and it now carries the count: "要我把这 N 个问题改了、再自动评一轮吗?"
- **播报纪律:链在每个时刻告诉你现在欠什么。** 第 4~8 步各播一两行人话并标"无需操作"(如"✓ 3/3 家返回,正在逐条核实,这几分钟不用你做任何事"),明细只落盘;全链唯一问句是停点,且带数量:"要我把这 N 个问题改了、再自动评一轮吗?"
- **Review appendix — verified findings travel with your plan.** When a chain reaches a conclusionary terminal state (converged / start-over / no-fix-needed / user-declined) and the source was a file, an appendix section is written to the **end of the reviewed document** (idempotent per-ts rewrite, written *before* the terminal state is recorded): the plain-language verdict blocks plus revision path and artifacts dir, headed by "评审参考,以实际执行为准" — reference material for development, but "stop and report on watch items" is an action, not a reference. Inline (pasted) sources skip it with an honest note. The original-untouched iron rule is rescoped: original *text* stays untouched; the end-of-doc appendix is the sole exception.
- **评审附录——已验证的发现跟着方案走。** 链达成结论性终态(收敛/推倒重来/无需修订/用户不修)且 source 为文件时,在**被评文档文末**追加附录节(按 ts 幂等重写,先写附录再记终态):人话版全部区块 + 修订版路径 + 产物目录,节首声明"评审参考,以实际执行为准"——是开发参考,但"撞上关注项停下反馈"是动作不是参考。贴文评审诚实跳过并说明。原稿不动铁律改口径:正文永不动,文末附录是唯一例外。
- **New terminal state `用户不修`.** Declining revision with must-fix items open used to be recorded as `无需修订` — a lie the verdict block would have exposed. `无需修订` is now reserved for genuinely-empty round-0 results; must-fix empty **after ≥1 revision rounds** reads `收敛(m 轮修订)` (fixed clean, not "nothing to fix"); declined-with-must-fix ends as `用户不修`. Terminal enum is now six values (the previously undocumented `完成(diag)` included — glossary drift fixed).
- **新增终态 `用户不修`。** 必改非空却答"不要"过去记 `无需修订`——结论区一置顶这个谎就藏不住。`无需修订` 只留给 round 0 的真空结果;**修订 ≥1 轮后必改清零**记 `收敛(m 轮修订)`(修干净了,不算"无需");拒修结束记 `用户不修`。终态枚举六值(补记此前未入表的 `完成(diag)`,修词汇漂移)。

## [0.13.1] - 2026-09-16

### Changed / 改进

- **Discussion-type resolutions now materialize as a real consensus doc.** When the object resolver falls through to discussion-type (grilling ended with no file written), the solidified proposal no longer lives only inside `.xcheck/<ts>/proposal.md` — the confirm popup states where it will land (`docs/superpowers/specs/<date>-<topic>-consensus.md`), and confirming writes it there. `source` becomes that path, so gate-approved revisions land **next to the consensus doc** instead of buried in the audit directory. Lazy by design: no file is ever created unless `/xcheck` is actually triggered and confirmed.
- **讨论型解析物化为正经共识文档。** 对象解析器落到讨论型(grilling 完没写文件)时,固化稿不再只活在 `.xcheck/<ts>/proposal.md`——确认窗写明将存为 `docs/superpowers/specs/<日期>-<主题>-consensus.md`,确认即落盘;`source`=该路径,停点后的修订版落在**共识文档旁边**而非审计目录深处。懒落盘:不敲 `/xcheck` 或不确认,永远不产生文件。

## [0.13.0] - 2026-09-16

### Added / 新增

- **Object resolver — bare or vague `/xcheck` now infers what you mean.** Empty/referential input (`/xcheck`, `审核刚才的spec`) no longer bounces back with "diagnose or review?" — the shell sets `MODE = auto` and flow step 0's **object resolver** infers the review target from this session's context, in a priority ladder: **file-type** (the spec/plan/design doc you just wrote or edited in this session — cross-session fallback scans `docs/superpowers/{specs,plans}/` and `docs/` for the newest ≤24h .md) > **discussion-type** (no file: distill the settled plan into a neutral proposal + verbatim fact list) > **diagnose-type** (conversation is chasing an error → diag + fact extraction) > ask. Everything lands in **one confirmation popup** (target + mode + background quotes; discussion-type shows the full solidified proposal) — the chain's only opening besides the gate. A file-type resolution sets `source` to the file path, so gate-approved revisions land **next to the original** (`<name>.rev1.md`) instead of inside `.xcheck/`. This replaces four separate heuristics (diagnose-vs-review ask, referential-word exception, scheme-type exception, plain intake). Review keyword list gained `spec / plan / 审核 / 看看 / 过一遍 / 检查`. Design: spec §10, decision record: `docs/adr/0002-object-resolver.md`.
- **对象解析器——裸敲或含糊的 `/xcheck` 能猜到你要什么。** 空/指代性输入不再被"诊断还是评审?"弹回:壳设 `MODE = auto`,flow 第 0 步对象解析器从本会话上下文按阶梯推断评审对象:**文件型**(本会话刚写/刚改的 spec/plan/设计文档;跨会话兜底扫 `docs/superpowers/{specs,plans}/`、`docs/` 近 24h 最新 .md)> **讨论型**(无文件:固化方案 + 原话事实清单)> **诊断型**(对话在追报错 → diag + 摘事实)> 反问。全部推断打包进**一个确认窗**(对象+模式+背景原话;讨论型附固化稿全文)——除停点外全链唯一开口。文件型解析 source=路径,停点后的修订版落**原文件同目录**。取代旧的"诊断还是评审"反问、指代词例外、方案型例外、普通摄入四套判定;review 词表补 `spec/审核/看看/过一遍/检查`。设计见 spec §10、`docs/adr/0002-object-resolver.md`。

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

### Changed / 改进

- **Agent execution fully mechanized: new `lib/run-agent.sh` supervisor replaces the carrier's hand-written shell.** Root cause of the intermittent "prompt fails to pass on the command line" (reported in external projects, too fast to capture): every defensive layer since 0.10 — path normalization, `wc -c` precheck, stale-file cleanup, timeout, hang detection — lived in *markdown instructions* a cheap-model subagent had to execute faithfully each run; any skipped step resurrected the bug, and failure evidence (the exact command, wrapper-level errors) was never persisted. The new script makes all of it mechanical: forward-slash normalization (backslash paths silently read empty), prompt precheck (missing/empty → refuse with exitcode 65, never launch a CLI with an empty prompt), stale-artifact cleanup, verbatim per-`input_mode` command construction (arg = `"$(cat ...)"` single argv via direct child process — the `bash -lc '...'` double shell and its single-quote-in-path bomb are gone), forensic `<agent>.cmd.txt` (the exact `%q`-escaped command, written *before* launch so it survives instant deaths), a monitor loop (hard timeout per-agent > `[defaults]`; hang = zero output growth ~10 min → kill), three-layer kill (process group via `set -m` + `taskkill //F //T` tree + direct kill — empirically, `taskkill //T` alone cannot reach msys grandchildren because cygwin's fork emulation breaks the Windows parent chain), and an **exitcode file that always exists by script end** (65 precheck / 66 unregistered / 67 CLI-not-on-PATH / 124 timeout-or-hang / else real CLI code) — the carrier can never again wait on a CODE file that will never appear. Carrier params shrink 6→3 (`AGENT_NAME` / `PROMPT_FILE` / `RESULT_SHAPE`; CLI command, input mode and timeout are resolved from `agents.toml` by the script). Smoke preflight (flow 1.5) now runs **the same mechanism** as real runs (`run-agent.sh --timeout 60` + `smoke-prompt.txt` file) instead of inlining the prompt — closing the "smoke green ≠ real run green" blind spot; smoke artifacts land in `.xcheck/` root with a defined path. New stub regression suite `xcheck/tests/run-agent.test.sh` (33 assertions: both input modes, timeout/override/hang kills, exit-code propagation, precheck edges, backslash paths, spaces-in-path, special chars `$`/quotes/backticks, tree kill on msys). Verified live against claude (arg), codex (stdin), kimi (arg). Note: non-interactive `claude -p` cannot read paths outside its working directory without permission — real runs are unaffected (all content files live under `<cwd>/.xcheck/`), but hand-rolled tests placing smoke files elsewhere will hit it.
- **agent 执行全面机械化:新增 `lib/run-agent.sh` 全托管 supervisor,取代搬运工手写 shell。** 外部项目偶发"命令行传提示词故障"(太快没抓到现场)的根因:0.10 以来的全部防御——路径转正斜杠、`wc -c` 预检、清残留、超时、挂起判定——都是写在 Markdown 里靠便宜档 subagent 每轮自觉执行的*指令级*纪律,任何一轮跳步故障就复活,且故障证据(实际执行的命令、wrapper 层报错)从不落盘。新脚本把这一切变机械:正斜杠化(反斜杠路径静默读空)、prompt 预检(缺失/为空 → 写 exitcode 65 拒跑,**严禁空 prompt 去跑 CLI**)、清残留、按 `input_mode` 逐字构造命令(arg = `"$(cat ...)"` 单参数、CLI 为**直接子进程** —— `bash -lc '...'` 双层壳及其单引号路径炸弹一并消灭)、取证文件 `<agent>.cmd.txt`(`%q` 转义的实际命令,**启动前**落盘,秒退也留得住)、监控循环(硬超时 per-agent > `[defaults]`;挂起 = 输出零增长 ~10 分钟 → 击杀)、三层击杀(`set -m` 进程组 + `taskkill //F //T` 进程树 + 直接 kill —— 实测 taskkill //T 杀不到 msys 孙进程,cygwin fork 模拟会打断 Windows 父子链,必须组杀兜底)、以及**脚本结束时 exitcode 文件必定存在**(65 预检 / 66 未登记 / 67 CLI 不在 PATH / 124 超时或挂起 / 其余 = CLI 真码)—— 搬运工再也不会等一个永远不会出现的 CODE 文件。搬运工参数 6→3(`AGENT_NAME` / `PROMPT_FILE` / `RESULT_SHAPE`;命令、输入方式、超时由脚本从 agents.toml 解析)。冒烟预检(flow 1.5)改走**与实跑完全相同的机制**(`run-agent.sh --timeout 60` + `smoke-prompt.txt` 文件),不再内联直传 —— "预检绿 ≠ 实跑绿"的形态盲区闭合;冒烟产物路径明确为 `.xcheck/` 根。新增 stub 回归测试 `xcheck/tests/run-agent.test.sh`(33 项断言:两种输入模式、超时/覆盖/挂起击杀、退出码透传、预检边界、反斜杠路径、带空格目录、`$`/引号/反引号特殊字符、msys 进程树击杀)。已对 claude(arg)、codex(stdin)、kimi(arg)实跑验证。注意:非交互 `claude -p` 无授权时读不了工作目录外的路径 —— 实跑不受影响(内容文件全在 `<cwd>/.xcheck/` 下),但手工测试把冒烟文件放别处会踩到。

## [0.10.1] - 2026-08-21

### Changed / 改进

- **Factory default agent set 4→3: `opencode` removed from `default_agents`.** The factory `default_agents` line in `agents.toml` now ships `["codex", "kimi", "pi"]`; opencode keeps its `[agents.opencode]` entry and remains selectable/usable — it is just no longer in the default fan-out set. Also removed the stray nested `.git` directory under `xcheck/` (a leftover pointing at the same remote/HEAD as the outer repo; no unique commits, files were already tracked by the outer repo).
- **出厂默认 agent 集 4→3:`default_agents` 移除 `opencode`。** `agents.toml` 出厂 `default_agents` 改为 `["codex", "kimi", "pi"]`;opencode 的 `[agents.opencode]` 定义保留,仍可勾选使用——只是不再进默认 fan-out 集。另删除 `xcheck/` 下残留的嵌套 `.git` 目录(指向与外层仓库相同的 remote/HEAD、无独有提交,文件本就由外层仓库跟踪)。

## [0.10.0] - 2026-08-17

### Fixed / 修复

- **Four failure classes from the 2026-08-15 live run (root cause of the first-round fan-out wiping out all four agents).** ① New carrier step 0: normalize every path to forward slashes — Windows backslash paths silently read **empty** in Git Bash `$(cat ...)` and some redirections (observed: kimi `Prompt cannot be empty`, opencode `You must provide a message or a command`); pre-check the prompt file is readable (`wc -c`, abort on 0 bytes); clean stale `OUT`/`ERRF`/`CODE` files before launching (a stale `exitcode` from a previous round misjudged the current run). ② New flow step 1.5 smoke preflight per agent (≤60s) — dead CLIs (e.g. pi's 401 out-of-credit) are caught before fan-out instead of after. ③ `agents.toml` gives codex `--skip-git-repo-check` — codex refuses to run outside a trusted git directory, and review targets often live outside the repo. ④ Carrier hang detection (output frozen ~10 min while the process lives → kill and treat as timeout; observed opencode freezing after 19 active minutes) + codex stdout-empty→stderr conclusion recovery.
- **2026-08-15 实跑暴露的四类故障修复(首轮 fan-out 4 家全灭的根因)。** ① 搬运工新增第 0 步:路径一律转正斜杠——Windows 反斜杠路径在 Git Bash 的 `$(cat ...)` 和部分重定向里**静默读空**(实证:kimi 报 `Prompt cannot be empty`、opencode 报 `You must provide a message or a command`);预检 prompt 可读(`wc -c`,0 字节直接停);启动前清残留 `OUT`/`ERRF`/`CODE`(上一轮的 stale `exitcode` 会让本轮成败误判)。② flow 新增第 1.5 步冒烟预检(每家 ≤60s),CLI 欠费/损坏在 fan-out 前拦下(pi 401 实证)。③ `agents.toml` 给 codex 加 `--skip-git-repo-check`——工作目录不在 git 仓库内时 codex 直接拒绝,而评审对象常在仓库外。④ 搬运工挂起检测(输出 ~10 分钟零增长且进程仍在 → 判挂起 kill;opencode 活跃 19 分钟后冻结实证)+ codex stdout 空时从 stderr 恢复结论。

### Changed / 改进

- **AskUserQuestion form discipline (flow step 2 / close-flow C2·C3).** Hard cap: ≤4 options per question, ≤4 questions per call, **one item per option — never merge several agents / experiments / undecided items into a single option**; longer lists split into consecutive questions (multiple calls beyond 16). Flow step 2's agent multi-select follows it (labels = bare agent names); close-flow C2 adds a "skip all" option for multi-question experiment approval; C3 falls back to a plain numbered text list at ≥8 undecided items (batch three-way picks beat nested forms).
- **AskUserQuestion 表单纪律(flow 第 2 步 / close-flow C2·C3)。** 硬规则:每题 ≤4 个选项、一次调用 ≤4 题,**一条条目一个选项,绝不把多个 agent / 实验 / 未决条目合并进一个选项**;条目多则按顺序切多题(超 16 条分多次调用)。flow 第 2 步 agent 多选遵循此纪律(label = agent 名原样,说明放 description);close-flow C2 实验批准多题时第一题加「全跳过」选项;C3 未决条目 ≥8 条时放弃表单、改纯文本编号清单让用户回复编号。### Changed / 改进

- **Instruction/content split: prompts now reference content files instead of inlining them.** flow 3.1 used to inline the full proposal/diagnosis input into the prompt text: file-path inputs were Read into the controller session and Written back out (double token cost), and the whole prompt became a single CLI argument for the four `arg`-mode agents — hitting the Windows 32,767-char command-line limit on large design docs. Every run now splits into an **instruction layer** (`prompt.txt`: guardrails + return shape + absolute paths, ≤2KB) and a **content layer** (`.xcheck/<ts>/proposal.md` / `input.md` / optional `context.md`): file-path inputs are `cp`'d to a snapshot (zero content tokens through the controller, immune to mid-run edits of the original), pasted/solidified content is Written once. Templates now use `{{PROPOSAL_PATH}}` / `{{INPUT_PATH}}` / `{{CONTEXT_PATH}}` and instruct the reviewer to read exactly the listed files (no repo exploration, no edits; unreadable file → say so, never invent a review). The step-1.5 smoke check is upgraded from "reply one word" to "read `<cwd>/.xcheck/smoke.txt` and echo its content" (constructed per `input_mode`: `echo |` pipe for stdin agents), so an agent that cannot read files in non-interactive mode is dropped before fan-out. close-flow C5 re-reviews feed the revision file path (flow 3.1 `cp`s it into the new ts snapshot); context-intake's solidified proposals and fact lists land directly as `proposal.md` / `context.md`.
- **指令与内容分离:prompt 改为引用内容文件,不再内联全文。** flow 3.1 此前把方案/问题全文内联进 prompt 正文:文件路径输入要被主会话 Read 全文再 Write 一遍(双倍 token),且全文经 `"$(cat ...)"` 变成 arg 模式 4 家(claude/opencode/pi/kimi)的单个命令行参数——大设计文档撞 **Windows 32767 字符命令行上限**。现在每次运行拆两层:**指令层** `prompt.txt`(护栏+返回结构+绝对路径,≤2KB)与**内容层** `.xcheck/<ts>/` 下的 `proposal.md` / `input.md` / 可选 `context.md`:文件路径输入用 Bash `cp` 落快照(内容零 token 过主会话、原文件中途被改不影响本轮),贴文/固化内容 Write 一次。模板槽位改为 `{{PROPOSAL_PATH}}` / `{{INPUT_PATH}}` / `{{CONTEXT_PATH}}`,指令明确"只读列出的文件,不探索、不改;读不到就直说,不凭空评审"。第 1.5 步冒烟预检从"回一个字"升级为"读 `<cwd>/.xcheck/smoke.txt` 原样回内容"(按 input_mode 构造,stdin 家走 echo 管道),非交互模式读不了文件的家在 fan-out 前剔除。close-flow C5 复审改喂修订版文件路径(flow 3.1 cp 成新 ts 快照);摄入的固化方案/事实清单直接落 `proposal.md` / `context.md`。

## [0.9.0] - 2026-08-14

### Added / 新增

- **`/xcheck-close` — review feedback close-loop.** After `/xcheck-review`'s triage (three verifiability tiers), the loop used to dead-end at "you decide". The new 5th shell closes it, all human-in-the-loop: **C1** verify tier-1 items read-only (✅/❌/❓, main session, evidence per item); **C2** run tier-2 experiments after one multiSelect approval (temp files under `.xcheck/<ts>/exp/` kept; no business-code edits / no network / no deploy); **C3** distill into a must-fix list (confirmed + experiment-supported), rejected items explicitly excluded, unresolved items decided by the user; **C4** main session writes the revision as a **new** `<name>.rev<m>.md` + diff (original untouched); **C5** optional re-review per round, hard cap 2 revision rounds, convergence = tiers 1+2 clear, otherwise "recommend starting over". Progress lands in `CLOSE.md` (per-stage append, resumable); the source SUMMARY gets a one-line `closed` marker only when the loop finishes. Review runs now also write `run.md` (mode/SELECTED/ts/prompt/source) that close uses to locate the re-review agent set; step 6.5 points review users at `/xcheck-close`. Design: `docs/superpowers/specs/2026-08-14-xcheck-close-loop-design.md`.
- **`/xcheck-close` —— 评审反馈闭环。** `/xcheck-review` 的三类分级(triage)此前止步于"你拍板",反馈没有下文。新增第 5 个入口壳闭环续上,全程人在环:**C1** 只读查证第一类(✅ 证实 / ❌ 证伪 / ❓ 查无实据,主会话逐条带证据);**C2** 第二类实验经一次 multiSelect 批准后执行(临时文件落 `.xcheck/<ts>/exp/` 留底;禁改业务代码 / 禁联网 / 禁部署);**C3** 汇成必改清单(证实+实验成立=必改,证伪=明确排除,未决=用户逐条拍板);**C4** 主会话亲写修订版,只写**新文件** `<原名>.rev<m>.md` + diff,原稿不动;**C5** 每轮问用户要不要复审,硬上限 2 轮修订,第 1+2 类清零=收敛,否则报"建议推倒重来"。过程写 `CLOSE.md`(阶段粒度追加、可断点续跑),SUMMARY 只在闭环结束时加一行 closed 标记。评审第 4 步新增落 `run.md`(mode/SELECTED/ts/prompt/source)供闭环定位复审 agent 集;6.5 收尾加 `/xcheck-close` 引导句。设计见 `docs/superpowers/specs/2026-08-14-xcheck-close-loop-design.md`。

### Changed / 改进

- **Intake hardening.** The "scheme-type reference" exception (e.g. `评审刚才的方案` after a design discussion) used to solidify the proposal and fan out **unguarded** — no user confirmation, and user-stated facts/constraints from the discussion were dropped. Now solidification is three-step: neutral-statement proposal + verbatim user-fact extraction, both shown to the user for approval (never fan out before approval), facts going to `{{CONTEXT}}` separately from `{{PROPOSAL}}`. Self-contained inputs (pasted spec / file path) now also get a **zero-roundtrip** background pass: the main session silently pulls directly-related user verbatim from recent conversation into `{{CONTEXT}}`, says so in one visible line (no popup), nothing added if nothing found. The verbatim-not-summary iron rule is unchanged.
- **摄入强化。** "方案型指代"例外(设计讨论后敲"评审刚才的方案")此前固化 proposal 后**裸奔** fan-out——无用户确认关卡,讨论中用户陈述的事实/约束也全丢。现固化为三步:中性陈述 proposal + 用户原话事实摘录,两者一并呈现用户过目(通过前绝不 fan-out),事实单独走 `{{CONTEXT}}`、与 `{{PROPOSAL}}` 分槽。自包含输入(贴 spec / 文件路径)也补**零往返**背景扫描:主会话静默摘最近对话里直接相关的用户原话填 `{{CONTEXT}}`,对话里明说一句(不弹窗),没摘到就不加。"摘录≠总结"铁律不变。

## [0.8.0] - 2026-08-14

### Fixed / 修复

- **Carrier runs external CLIs in background with full disk redirection (2026-08-14 codex incident).** A long review (45 min) launched via a single foreground Bash call was killed by the 600s tool limit while the CLI kept running as an orphaned Windows process — its conclusion went into a pipe nobody read and was lost permanently. `subagent-carrier.md` step 1 now mandates: launch with `run_in_background: true`, redirect stdout/stderr/exit-code to `<agent>.raw.stdout` / `.raw.stderr` / `.exitcode` files next to the prompt file, then poll via TaskOutput (blocking, ≤600s per wait) until the exit-code file appears or the total TIMEOUT elapses. `timeout_sec` semantics clarified: it is the **total execution budget** honored by the polling loop, not a single foreground wait. New step 7 adds last-resort recovery from agent-native session logs (codex rollout JSONL verified; kimi/opencode marked unverified). `flow.md` step 3.4 and the `agents.toml` header cross-reference the incident note. Defaults raised 1800→2700 across `[defaults]` and all five agents; every stale hardcoded "480" in `SKILL.md` / `flow.md` / carrier / xcheck-setup docs removed (they had already drifted from 1800), and the `/xcheck-setup timeout` sanity-warning range widened to N<60 / N>3600 so the new factory default no longer trips its own "abnormal range" warning.
- **搬运工改为后台启动 + 全程落盘 + 轮询(2026-08-14 codex 事故)。** 长评审(45 分钟)此前用一次前台 Bash 调用直等,600 秒被 harness 掐断,CLI 作为孤儿进程继续跑完,结论写进没人读的管道、永久丢失。`subagent-carrier.md` 第 1 步改为:`run_in_background: true` 启动,stdout/stderr/退出码分别落盘到 prompt 同目录的 `<agent>.raw.stdout` / `.raw.stderr` / `.exitcode`,再用 TaskOutput 阻塞轮询(单次 ≤600s)直到退出码文件出现或总时限到。`timeout_sec` 语义明确为**总执行时限**,由轮询兑现,不是一次前台等待的秒数。新增第 7 步兜底:输出异常丢失时先从 agent 自带会话日志恢复(codex rollout JSONL 已验证;kimi/opencode 标注未验证)。`flow.md` 3.4 与 `agents.toml` 头注同步引用事故注记。默认超时 1800→2700(`[defaults]` + 五家 agent 全量);`SKILL.md` / `flow.md` / carrier / xcheck-setup 文档里所有写死的"480"清除(此前已与 1800 脱节),`/xcheck-setup timeout` 异常区间警告放宽为 N<60 / N>3600,出厂默认 2700 不再触发自己的"异常区间"警告。

### Changed / 改进

- **Factory default agent set enabled.** `agents.toml` `[defaults].default_agents = ["codex", "kimi", "opencode", "pi"]` — shipped uncommented, so `/xcheck` skips the per-run multi-select out of the box (claude excluded from the default reviewers; add it via `/xcheck-setup default` if wanted).
- **出厂启用默认 agent 集。** `agents.toml` 的 `[defaults].default_agents = ["codex", "kimi", "opencode", "pi"]` 取消注释出厂即生效,`/xcheck` 开箱跳过每次勾选(默认评审组不含 claude;需要可 `/xcheck-setup default` 加回)。

## [0.7.0] - 2026-08-13

### Added / 新增

- **Default agent set + `--agents` override.** `/xcheck-setup default <a>,<b>,...` lets you preset the agent group once; subsequent `/xcheck` / `/xcheck-diag` / `/xcheck-review` runs skip the per-run multi-select and go straight to that set. Stored in `agents.toml` `[defaults].default_agents`. `flow.md` 第 2 步 rewritten into a three-branch selection (default set / `--agents` / multi-select), fully backward-compatible (field absent = old per-run picker). A one-off override is possible via `--agents a,b,c` on any of the three shells. Missing agents in the default set trigger a single-select fallback (run with the remainder / re-pick); a corrupted name in `default_agents` is defensively dropped, while a bad name in `--agents` (a typo) stops with an error listing valid names. Heterogeneity is warned-not-blocked at setup time and flagged in SUMMARY at run time (same as before). Design: `docs/superpowers/specs/2026-08-13-xcheck-default-agents-design.md`.
- **默认 agent 集 + `--agents` 临时换集。** `/xcheck-setup default <a>,<b>,...` 可预设一组默认 agent,此后 `/xcheck` / `/xcheck-diag` / `/xcheck-review` 跳过每次的勾选弹窗、直接拿这组跑。存在 `agents.toml` 的 `[defaults].default_agents`。`flow.md` 第 2 步重写为三分支(默认集 / `--agents` / 多选),完全向后兼容(字段缺失 = 旧行为,每次弹窗)。任一壳加 `--agents a,b,c` 可临时换一组、不改默认。默认集里有 agent 当前未装 → 弹单选兜底(用剩余 / 重新选);`default_agents` 里被手改出的坏名 → 防御性剔除,`--agents` 里的坏名(笔误)→ 报错停住并列出合法名字。异构在 setup 阶段只警告不拦、运行时在 SUMMARY 标注(同前)。设计见 `docs/superpowers/specs/2026-08-13-xcheck-default-agents-design.md`。

## [0.5.0] - 2026-08-12

### Added / 新增

- **Recognize `kimi` (Kimi Code CLI) as a fifth default agent.** New `[agents.kimi]` in `agents.toml`: `kimi -p` in `arg` mode, auto-detected via `installed_check = "kimi"` — so it shows up in the `/xcheck` `/xcheck-diag` `/xcheck-review` multi-select list whenever the Kimi Code CLI is on `PATH`, and can be picked as a reviewer / discussant. No effect for users without `kimi` installed. Contract empirically locked (exit 0 on success; stdout is a single `• `-prefixed bullet then the reply — the cleanest of the five, no banner / ANSI / hook noise); see `docs/cli-findings.md`. README default-agent lists (EN + 中文), the carrier's stdout-shape notes, and the heterogeneity reminder examples (`SKILL.md` / `flow.md`) all synced. Heterogeneity win: Kimi K3 (Moonshot) is a fifth, independent opinion source distinct from Claude / OpenAI / GLM.
- **登记 `kimi`（Kimi Code CLI）为第 5 个开箱即识的 agent。** `agents.toml` 新增 `[agents.kimi]`：`kimi -p`，`arg` 模式，`installed_check = "kimi"` 自动探测——只要本机 PATH 上有 Kimi Code CLI，就会出现在 `/xcheck` `/xcheck-diag` `/xcheck-review` 的多选列表里，可选作评审者/讨论者。对没装 `kimi` 的用户无影响。契约已实测锁定（成功 exit 0；stdout 是一行 `• ` 前缀的 bullet 然后 reply——五家里最干净，无 banner / ANSI / 生命周期噪声）；详见 `docs/cli-findings.md`。README 默认 agent 列表（EN + 中文）、carrier 的 stdout 形态说明、异构提醒示例（`SKILL.md` / `flow.md`）均已同步。异构增益：Kimi K3（Moonshot）是区别于 Claude / OpenAI / GLM 的第五个独立意见源。

## [0.4.1] - 2026-08-12

### Fixed / 修复

- **Enforce LF line endings via `.gitattributes`.** `core.autocrlf=true` (Windows default) emitted "LF will be replaced by CRLF" warnings on checkout for `.md`/`.toml` files. The repo blobs were already LF-clean (commit normalizes), so no existing files needed renormalization — the new `.gitattributes` (`* text=auto eol=lf`, plus explicit `*.md`/`*.toml`/`*.sh`/`LICENSE`) pins LF going forward so every platform gets identical endings and the warning is gone.
- **用 `.gitattributes` 强制 LF 行尾。** `core.autocrlf=true`（Windows 默认）在 checkout `.md`/`.toml` 文件时反复报 "LF will be replaced by CRLF"。仓库 blob 本来就是干净的 LF（commit 时已规范化），无需重存现有文件——新增的 `.gitattributes`（`* text=auto eol=lf`，外加显式 `*.md`/`*.toml`/`*.sh`/`LICENSE`）从此固定 LF，跨平台一致、消除警告。

## [0.4.0] - 2026-08-12

### Added / 新增

- **Configurable per-agent timeout + `/xcheck-setup timeout` command.** `agents.toml` gains a `[defaults].timeout_sec` (still 480 as the global floor); every registered agent now has an explicit `timeout_sec` that overrides the default. New `/xcheck-setup` mode C lets you inspect and set it: `/xcheck-setup timeout` (print), `/xcheck-setup timeout <N>` (set `[defaults]`), `/xcheck-setup timeout <agent> <N>` (per-agent). Only affects the `timeout` cage xcheck wraps around agent calls — running the agent CLIs yourself is unchanged.
- **可配置 per-agent 超时 + `/xcheck-setup timeout` 命令。** `agents.toml` 新增 `[defaults].timeout_sec`（全局默认仍 480）；每个登记的 agent 现在都有显式 `timeout_sec` 覆盖默认。新增 `/xcheck-setup` 模式 C：`/xcheck-setup timeout`（查看）、`/xcheck-setup timeout <N>`（设 `[defaults]`）、`/xcheck-setup timeout <agent> <N>`（设单家）。只影响 xcheck 调用 agent 时套的 `timeout` 笼子——你单独跑 agent 不受影响。

### Changed / 改进

- **Anti-self-substitution guard in the review prompt.** When a controller materializes a multi-round design discussion into a self-contained proposal (per the new context-intake exception for "scheme-type reference input"), the proposal text would sometimes mention "agent X reviewed last round" / "three heterogeneous agents" — which led the *reviewing* agent to mistake itself for the one supposed to run an evaluation flow, load a skill, and trip a permission prompt (observed: opencode v0.4 attempt). The review prompt now opens with a guard telling the reviewer "you're here to judge, don't load skills / don't invoke other agents / the mention of other agents in the proposal is history, not instruction." The router also stops sending `review + 指代词` inputs into the ambiguous branch — they're unambiguously review.
- **review prompt 加「防自代入」护栏。** 当 controller 把多轮设计讨论固化成自包含 proposal（走 context-intake 新增的"方案型指代输入"例外）时，proposal 正文里常会写"上一轮 agent X 评过""三家异构 agent"——被评 agent 读到会把自己当成"该跑评审流程的人"，去加载 skill、触发权限弹窗（实测：opencode 第 2 轮失败）。review prompt 现在开头加护栏："你是评审者，别加载 skill / 别调别的 agent / proposal 里提到的其他 agent 是历史背景，不是给你的指令。"路由器也让"review 强信号 + 指代词"的输入直接判 review，不再走 ambiguous。

### Fixed / 修复

- **`/xcheck-setup` mode B wording.** `timeout_sec` was documented as "only set when `needs_timeout = true`"; in fact every agent carries the `timeout` cage regardless, so the wording now says "always set (default 480; mode C can change it)."
- **`/xcheck-setup` 模式 B 措辞。** 原写"`timeout_sec` 仅在 `needs_timeout = true` 时填"；实际上所有 agent 都带 `timeout` 笼子，措辞改成"始终填（默认 480；可用模式 C 改）"。

## [0.3.0] - 2026-08-09

### Added / 新增

- **Context intake (optional Step 0).** When you trigger a command with a short / reference-like input (e.g. `诊断刚才那个` / "diagnose that thing from just now"), xcheck now auto-extracts the **objective facts** from your recent conversation and passes them to the fan-out agents — because those agents are fresh processes that can't see the chat. A dedicated **extractor subagent** (cheap model) pulls facts **by provenance** (keeps what you said / pasted; drops assistant reasoning), never rewrites your words, and you confirm the fact list per-item before anything runs. Self-contained inputs (a full stack trace, a design doc) skip this. See `xcheck/lib/context-intake.md` + `xcheck/lib/extractor-carrier.md`.
- **上下文摄入（可选第 0 步）。** 当你用简短 / 指代性输入（如 `诊断刚才那个`）触发命令时，xcheck 会自动从最近对话里**摘取客观事实**传给下游 agent —— 因为那些 agent 是全新进程、看不到聊天记录。由专门的**摘录 subagent**（便宜模型）**按来源**摘取（留你说的 / 贴过的，丢 assistant 推理），绝不改写原话，且逐条经你确认后才开跑。自包含输入（完整报错栈、设计文档）直接跳过。见 `xcheck/lib/context-intake.md` + `xcheck/lib/extractor-carrier.md`。

## [0.2.0] - 2026-08-09

### Added / 新增

- Recognize **`pi`** ([`pi -p`](https://github.com/earendil-works/pi-mono), non-interactive print mode) as a fourth default agent in `agents.toml`. Auto-detected when installed; users without `pi` are unaffected.
- 识别 **`pi`**（[`pi -p`](https://github.com/earendil-works/pi-mono)，非交互 print 模式）为第四个默认 agent，写入 `agents.toml`。已装则自动检测，未装无影响。

## [0.1.0] - 2026-08-09

### Added / 新增

- First public release.
- 首个公开发布。
- Four manual slash commands: `/xcheck` (auto-router), `/xcheck-diag` (parallel diagnosis), `/xcheck-review` (cross review), `/xcheck-setup` (detect / verify / register).
- 四个手动 slash 命令：`/xcheck`（自动路由）、`/xcheck-diag`（并行诊断）、`/xcheck-review`（交叉评审）、`/xcheck-setup`（检测 / 验证 / 登记）。
- Parallel **blind** evaluation across local heterogeneous agent CLIs; each agent runs in its own isolated Claude subagent (carry-only, no judging); main session synthesizes consensus / divergence / verdict; the human decides.
- 跨本地异构 agent CLI 的并行**盲评**；每个 agent 跑在独立 Claude subagent 里（只搬运不评判）；主会话汇总共识 / 分歧 / 裁决；最终人拍板。
- Default agents: `claude`, `codex`, `opencode`. MIT license.
- 默认 agent：`claude`、`codex`、`opencode`。MIT 许可证。
