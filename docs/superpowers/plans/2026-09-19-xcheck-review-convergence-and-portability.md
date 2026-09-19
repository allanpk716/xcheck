# xcheck 审核收敛与可分发配置实施计划

## 背景与本次边界

用户已确认设计: `docs/superpowers/specs/2026-09-19-xcheck-review-convergence-and-portability-design.md`,共22项决策;ADR 0004 记录阻断语义与夜链同分支交付取舍。核心痛点是普通建议不断触发修订,不是缺少审核轮数。

本计划按完整目标列出依赖顺序,最初批准只启动第一批(任务1–4);2026-09-19已追加批准第二、三批,第四、五批配置与权限适配尚未实施。第一批剩余回放/真实CLI验收限制继续保留,后续技术闸门未通过不得宣称全部设计已完成。

不自动 commit/push/开PR,不改个人登录、全局权限或真实远端。现有设计文档与术语改动保留。运行实现开始前新建普通 feature 分支,不沿用历史计划里的 worktree 路径或旧提交指令。

## 已验证基线

- 工作区现有改动: CONTEXT.md,新设计稿,ADR 0004;没有运行文件改动。
- `bash xcheck/tests/run-agent.test.sh`: **33 pass, 0 fail**(2026-09-19,Windows Git Bash)。现有 stub 测试覆盖参数/stdin、超时/挂起、进程树、路径与退出码。
- 当前关键耦合: review 的 RESULT_SHAPE → carrier → triage 编号 → verify/experiments → 必改项并集 → gate/revision → 附录 → 第11步规格/票。该链必须同批升级,不能只改 review.md。
- 现有 step 0–11 和11个 PROGRESS 阶段尽量不改编号;在现有阶段内部插入新职责,降低跨文件协议变动。

## 第一批:审核收敛的完整闭环

执行跟踪(2026-09-19,分支 `feat/review-convergence`):

- [x] 任务1:集中契约、schema2及离线场景/校验器。
- [x] 任务2:讨论意图优先、D快照、实质歧义确认与旧链迁移守卫。
- [x] 任务3:事实/阻断分离、限定范围复审、稳定F记录、迁移不重置自动预算。
- [x] 任务4:交付与下游范围约束、paused/blocked依赖、文档同步。
- [x] 离线静态/接线/提示词预算测试:73通过,0失败;supervisor回归:33通过,0失败。
- [x] 独立8例文本语义回放与缺陷复核;修正下游对象漂移、缺字段误算零约束、历史问题无证据重开风险。
- [ ] 七场景回放产物自动比对:判断已返回,但四份FINDINGS写入被子代理权限钩子拒绝;未由主会话代写绕过,因此未运行完整 --replay-dir 验收。
- [ ] 真实多CLI端到端验证(未执行,不能用静态通过替代)。

以上为第一批历史结果;第二、三批实施跟踪见下节,第四、五批尚未实施。新增triage-review模板隔离diag,没有改变其旧分类模板;没有修改agent配置或权限。

### 任务1:先定义新版审核协议和可回放样例

**文件**:新增 `xcheck/lib/review-contract.md`, `xcheck/tests/fixtures/review/`, `xcheck/tests/review-contract.test.sh`;修改 `docs/artifacts.md`。

- 新运行记录 `review_schema = 2`;没有字段的记录视为旧协议,不把旧“必改/收敛”按新版重解释。
- 保留现有步骤/阶段枚举。新增内容协议通过一个紧凑契约文件集中定义,flow和模板引用,避免多处复制判据。
- 共识快照建议复用 `proposal.md` + `context.md`,并新增 `decisions.md` 记录稳定 D 编号、已确认/未决/否决/假设/已替代状态及必要出处。不存不必要的整段聊天。
- 新增 `FINDINGS.md` 作为新版问题记录:稳定 F 编号、原始来源、发生条件、关联D、取证分类、事实结论、具体影响、裁定、解除条件、影响范围、状态及历史。三个取证类别均可获得稳定编号,不再用“先①后②、③无编号”的排序做身份。
- 区分三个维度:事实(证实/证伪/未确定)、处置(阻断/非阻断/重大风险待决/无需动作)、生命周期(开放/已解除)。未确定的重大风险不得伪称证实。
- SUMMARY及附录从该记录生成,不另造裁定。问题归并保留多来源,不将不同故障条件误合并;重新开启须新证据或回归。
- 新版状态行显示“可推进/相关路径暂停”,附阻断和风险待决数量与范围。七个终态标签尽量保留,由schema区分释义;无人值守在有限修订后收工不等于放行阻断。

**旧运行处理建议**:

- 已终态产物只读保留,极旧无PROGRESS目录仍忽略。
- 旧评审未完不在原目录混写新协议;建立关联的新schema=2审核运行,复用对象及有效背景,重新审核/核实,不直接继承旧“完成/通过”。原目录保留为迁移来源。
- 旧night已进入实施时不可当新链自动重复实施或恢复旧主分支push;进入后续旧链适配路径,本批先安全暂停并说明原因。
- 新版但所需账本缺失/字段不合法时明确拒绝跳阶段,不得凭会话记忆补成已完成。

**验收**:先写正反样例(含旧版记录)和结构检查;明确静态检查只能证明协议形状,不能证明模型正确理解。

### 任务2:保真摄入当前讨论共识

**文件**: `xcheck/lib/context-intake.md`, `xcheck/SKILL.md`, `xcheck/lib/flow.md` 第0/3步,契约与样例。

- 显式文件/贴文仍按用户指定对象;明确“刚讨论的方案”优先当前讨论,不被新ADR或24小时内无关Markdown抢走。
- 把用户短答绑定原问题及选项,保存后续修正关系;助手未获确认的提议不计入已定决策。
- 当前可见上下文不全时记录缺失,不编造出处或默认前文已同意。
- 自动整理,仅对影响对象或关键决定的歧义在正常模式询问;night记录未决与影响范围,全局对象不明则停止而非硬猜。
- 已确认决策、否决项和约束传入每个评审员及修订者;CONTEXT/ADR仅为背景或明确约束。

**验收**:选A后改B、短答绑定、未确认助手提案、无关最新文件、明确文件优先、上下文缺失、无Matt技能照常接入。

### 任务3:分离事实与阻断,限定范围复审

**文件**: `xcheck/prompts/review.md`,新增 `xcheck/prompts/re-review.md`, `xcheck/prompts/triage.md`(或review专用分类模板以隔离diag), `xcheck/lib/subagent-carrier.md`, `xcheck/lib/flow.md` 第3–10步,契约。

- 首轮评审要求发生条件、具体影响、决策/材料位置和证据;缺失字段由carrier如实写未提供,不由搬运工补推理。
- 取证分类与事实验证保持独立;在查证/实验之后裁定是否影响目标/验收/安全/数据/实施前置条件。
- 删去“①证实+②成立直接等于必须修订”的review逻辑;不能在①②为空时绕过③中的具体重大待决风险。
- 普通补充、偏好、下游应细化的步骤不阻断;真正阻断须有影响依据。限定审核范围不是忽略安全缺陷。
- 复审使用新模板,内容层包含原问题、修订差异、修复理由、已确认约束;指令层维持≤2KB,大型内容走文件路径。
- 首轮保持评审员互不可见;复审允许共同读取上一轮问题基线,仍不能看到本轮其他评审员的输出。
- night最多自动修订一次;无实质进展不重复改写。正常模式保留用户决定是否再修的出口,不把策略停工写成用户决定。
- 未授权改变关键决策时停止相关修订,而不是创造需求。保留原稿正文不直接覆盖的约束。
- 本批不扩大CLI仓库访问权限,仍沿用现有输入范围并如实说明强制隔离尚未实现;新取证能力留待第五批验证上线。

**验收**:低价值属实建议不触发修订、真实缺陷阻断、重大未验证风险暂停、重复问题合并、修复验证不开放找小问题、新重大回归可阻断、闭项重新打开必须有证据、diag行为不退化。

### 任务4:同步交付与下游局部暂停,防止建议重新扩张

**文件**: `xcheck/lib/flow.md` 第9/11步与附录/NIGHT段, `xcheck/prompts/synthesize-review.md`, `docs/artifacts.md`, `CONTEXT.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`。

- 交付正文优先结论、阻断/待决及解除条件;精选一般建议留参考,不自动进入spec或票。
- spec/票要追溯已确认决策和必要修复,不把意见清单全量翻译为需求。
- 问题影响范围映射到任务后沿真实依赖传播暂停;未知是否独立不能自动当独立。
- 区分票的完成、暂停及受依赖阻塞,不再用“台账有行”判断全部完成或可跳过。只有已完成依赖才放行下一票。
- 局部推进、整体收敛、实现完成分别呈现;无下游依赖的真实阻断不能因“停靠”视为已解除,不能误报全绿。
- 同批更新新版术语及产物表,删除新路径中的旧必改并集规则;旧产物解释保留并标版本。
- CHANGELOG只记录本批实际完成的范围,不提前声称配置分离、隔离取证或夜链分支迁移已经实现。

**本批验收**:

1. 全部合同/路径/字段检查通过,既有supervisor测试仍33/33。
2. 用固定合成会话和预制评审结果回放任务2–4场景,逐项记录实际输出与预期;静态字串检查不能替代回放。
3. 正常review、复审、diag、night局部暂停、新/旧进度分别覆盖。
4. 不调用付费真实CLI或发送项目材料到外部服务来“偷偷验收”;真实跨CLI测试单独列出并在执行前明确授权与费用。
5. 审查git diff确保没有个人配置、权限、发布目标改动;向用户交付本批结果与未完成清单。

## 第二批:交互方式与执行终点解耦

执行跟踪(2026-09-19,本批已获批准):

- [x] 实现三种模式、互斥旗标、无旗标三选入口(完整night默认推荐),所有mode持久化interaction/target。
- [x] 新增纯解析helper `xcheck/lib/run-mode.sh`;严格旧字段映射、拒绝半缺/非法/冲突及显式模式不符接管,复审/迁移保留原模式。
- [x] TARGET=review不建NIGHT、不进第11步、不通知/推送/PR;保留审核本地修订/附录,diag始终不实施;五处文档同步到0.20.0。
- [x] 本批实际测试(主会话确认):`xcheck/tests/run-mode.test.sh` 33通过、0失败;既有review-contract复跑73通过、0失败,supervisor回归复跑33通过、0失败;git diff --check通过。不替代真实CLI验收,第一批回放产物受限记录不变。
- [x] 保留完整night+diag的NIGHT短稿/可选通知兼容路径,任何入口diag均不实施;auto-review diag不建NIGHT、不通知。统一请求变量MODE_REQUEST。
- [ ] 真实多CLI端到端/发布/通知验证(未执行)。

**依赖**:第一批。

**文件**: `xcheck/SKILL.md`, `xcheck/lib/flow.md`, `xcheck/lib/context-intake.md`, `xcheck/lib/run-mode.sh`, `xcheck/tests/run-mode.test.sh`,契约/产物/入口场景。

- 新增 `--auto-review` 表示仅无人值守审核;保留 `--night` 表示无人值守实施到PR;两者同时使用报互斥错误。
- 内部保存 `interaction = interactive|unattended` 与 `target = review|implementation`;不再用一个NIGHT_MODE隐含两个维度。
- 无旗标沿用一次入口选择,提供正常审核/无人值守审核/完整night的明确后果,不要加两个串行弹窗。
- 续跑以账本终点为准,新命令不能静默升级授权;不兼容目标时明确提示,不重新解释旧链。
- 仅审核不得创建实施票、运行代码或发布。复用PROGRESS承载审核自动策略,仅完整实施建立NIGHT账本。

**验收**:旗标矩阵、冲突/缺参、只审核零发布、续跑不升级、diag不接实施。

## 第三批:夜链同分支交付与可核实恢复

执行跟踪(2026-09-19,本批已获批准,目标版本0.21.0):

- [x] 新增delivery_schema=1交付契约,摄入冻结host_repo/start_oid/source_branch/remote_name/remote_url/pr_base,复审继承;night审核共识/修订/附录只写.xcheck,source=inline、original_source仅追溯。
- [x] 第11步改为spec/票之前建立仓库外worktree,规格/票/最小.gitignore/代码只在夜链分支提交;原分支不commit/push/pull/rebase。恢复带完整OID及测试/独立评审证据,丢失时本批暂停不自动重建。
- [x] 发布只推冻结夜链分支,PR显式repo/base/head且正文自包含,不为PR推base;无remote本地执行,实施结果与发布结果分开。旧night缺delivery_schema停止自动恢复,包括review_schema2;diag短稿不建worktree,auto-review边界不变。
- [x] README/AGENTS/CONTEXT/artifacts/CHANGELOG按第三批同步,第四、五批仍未做,前批回放产物受限记录保留。
- [x] `night-git.sh` prepare/verify/publish实现与临时repo/本地bare remote测试:主会话实际回报46通过、0失败,不触碰真实远端。
- [x] `night-pr.sh`显式GitHub repo/base/head查询复用/创建及UTF-8正文文件;stub gh测试实际73通过、0失败。Gitea不由helper托管,仅主会话可明确核实tea目标时操作,否则记未建;未验收真实托管或tea。
- [x] 本轮既有离线复跑:review-contract 73通过、0失败;run-mode 33通过、0失败。
- [x] supervisor本轮最终复跑33通过、0失败。五套离线检查合计258通过、0失败,各套范围不同,不代表端到端验收;主会话确认git diff --check与bash -n通过。
- [ ] 真实多CLI端到端/远端发布/PR/通知验收(未执行)。

**依赖**:第一、二批。

**文件**: `xcheck/lib/flow.md`, `xcheck/lib/context-intake.md`, `xcheck/SKILL.md`, `xcheck/lib/review-contract.md`,新增 `xcheck/lib/night-delivery.md`、`xcheck/lib/night-git.sh`、`xcheck/tests/night-git.test.sh`、`xcheck/lib/night-pr.sh`、`xcheck/tests/night-pr.test.sh`, NIGHT协议与相关文档。

- 首次摄入冻结完整Git基线和发布目标;night审核材料只写原仓.xcheck。无Git/HEAD可审核但不实施;未提交业务修改不自动stash/commit/复制,依赖它们的路径暂停。
- 在spec/票写入前先记录NIGHT的branch/worktree意图,再prepare仓库外worktree。spec、票、所需最小gitignore改动与代码全部在夜链分支;去掉原分支commit/push/pull --rebase路径。
- 自动发布只推冻结夜链分支,显式repo/base/head查询同目标开放PR并复用或创建,PR正文自包含;不为PR推base,不merge/force,不安装工具或创建远端。
- 拆分实现状态与发布状态;无remote/无PR工具/权限失败可本地完成并明确未发布,URL/身份不一致安全暂停发布。
- 对机械Git检查提取小脚本:验证仓库common-dir、真实worktree路径、HEAD分支与完整OID可达;脚本不做模型裁定或替代测试。
- 票级账本保存完整完成OID及测试/独立评审证据,恢复已有产物先verify。分支/worktree/提交丢失本批安全暂停,禁止自动重建后按旧台账跳过已完成票。
- 旧night缺delivery_schema/冻结元数据拒绝自动恢复,包括review_schema2;没有plan产物也不从当前HEAD补猜旧基线,需明确新开。保留旧分支/提交,不自动清理或重复实施。

**验收目标**:临时repo + 本地bare remote + gh/tea stub;断言原分支HEAD/文件不变,所有产物在同PR diff,无remote降级,推送拒绝、PR幂等、提交不可达、worktree丢失与旧账本不误跳票。测试不触碰真实远端;实际覆盖与未测项目按真实回报填写,不把目标清单当已验收结果。

## 第四批:模板与个人配置分离,统一setup与执行路径

**依赖**:第一批契约;发布字段接第三批。

**文件**: `xcheck/agents.toml`(只Edit迁移通用模板内容),新增配置解析模块及 `xcheck/tests/config.test.sh`, `xcheck/lib/detect.sh`, `xcheck/lib/run-agent.sh`, `xcheck-setup/SKILL.md`,flow/carrier有效配置引用。

- 推荐个人配置默认 `~/.config/xcheck/config.toml`(可用XCHECK_CONFIG显式替代),项目非秘密设置 `.xcheck.toml`;安装目录agents.toml作为分发模板。最终字段集中由唯一解析器定义。
- 保留bash+coreutils依赖;实现受限、明确的配置语法而非宣称完整TOML。遇未支持语法清楚报错,不静默读错。
- 合并顺序:显式运行参数 > 已授权项目设置 > 个人配置 > 模板;数组整体替换,标量覆盖,未知字段报错,保留来源输出。
- 项目层不得定义任意run_cmd/凭据/新外发地址;测试命令或发布目标须来自受信任选择,不能用仓库配置绕过信任。
- 去掉个人通道/凭据片段注释及固定个人默认组;配置迁移先读取旧值、保留备份、不覆盖已有个人设置,不顺手改各CLI配置。
- 检测/冒烟/setup/运行都复用解析器与supervisor,不再用单独timeout调用冒充完整验证。保留脚本现有显式配置参数及退出码协议供兼容与测试。
- smoke配置指纹针对有效配置,取证能力还须包含CLI版本与运行权限配置。
- Pushover继续可选,凭据只由外部环境取得;不进项目文件、评审prompt或日志。未知模型来源显式标未知,不同CLI不冒充不同模型。

**验收**:隔离HOME与stub配置;复制/链接安装、迁移幂等/冲突、数组替换、CRLF、含空格路径、未知字段、恶意项目命令、凭据不泄漏、配置指纹变化、未登录/缺CLI/未配通知。

## 第五批:只读取证与材料隔离能力闸门

**依赖**:第四批有效配置与测试入口。

- 先探测已安装CLI版本和help,使用官方契约与非敏感临时材料验证,不先给出“全部CLI支持”的承诺。
- 建立逐CLI能力矩阵:真正限制仓库写入的只读模式/真正禁工具或隔离输入的材料模式/不支持。
- 提示词、cwd和worktree不是隔离。验证应同时覆盖不能写仓库、不能读哨兵私有文件、不能借shell/MCP/插件越界;可预期的正常模型通信与任意外部动作分开。
- 无可靠材料模式或只读机制的CLI标不可用,不足两家停止;不退回danger-full-access。
- 指令模板、carrier与冒烟适配材料模式:完整材料走stdin或受控文件,控制命令长度,不能用“回显一个marker”证明权限隔离。
- 新增能力检查样例与adapter测试,实际CLI验证单独记录版本、平台、权限配置、证据及限制。
- 本批技术闸门失败时暂停相应adapter交付,明确尚未达到用户要求;不为跨平台隔离临时引入未讨论的大型容器平台。

## 最终验收与发布文档

- 每批行为变化当批同步文档/术语/产物与CHANGELOG,不等最后补。
- 全量跑现有及新增离线测试;记录实际执行项/失败项/未测项。
- 用同一组讨论输入比较旧/新版:阻断误报、重大缺陷漏报、无收益修订、未经确认扩范围;不承诺没有基线的百分比。
- 真实CLI多模型端到端、真实Pushover与PR只在获得相应授权后做,使用非敏感测试材料/专用测试仓库。
- 完成后将本计划落入 `docs/superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md` 并维护任务勾选。计划不携带历史硬编码路径、不要求额外外部skills,不隐含commit/push授权。
