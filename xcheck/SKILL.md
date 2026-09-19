---
name: xcheck
description: 一次触发全自动异构评审 —— 并行评审本地多个 AI agent、自动查证与实验,区分阻断与非阻断建议、限定范围复审,终点交付。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--auto-review | --night] [--agents a,b,c] [<问题描述或方案>]
---

# /xcheck — 单停点全自动链入口

`$ARGUMENTS` 可空。你(壳)只做四件事:**抠旗标(--auto-review / --night / --agents)→ 查未完成链(含版本与策略守卫)→ 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(摄入)+ 11 步」(第 11 步 = 完整夜链专属),你不重新实现它。review 遵守 `lib/review-contract.md` 的 `review_schema = 2`;diag保持原有诊断协议。`INTERACTION` 控制是否询问,`TARGET` 控制执行终点,两者不由同一个开关代替。裸敲无未完成链时先入口一问,再从相关讨论/材料解析对象,无对象才按交互策略处理。

## 1. 抠旗标(--auto-review / --night / --agents,可选)

先检查独立布尔 token `--auto-review` 与 `--night`:**两者互斥,同时出现立即报错停止**,不扫描续跑、不启动评审。只含 `--auto-review` → `MODE_REQUEST = auto-review`;只含 `--night` → `MODE_REQUEST = night`;均无 → `MODE_REQUEST = default`。删除已识别模式旗标,不改变剩余输入。两者均可与 `--agents` 并用,顺序不限。

- `--auto-review`:无人值守**仅审核**;摄入与停点不弹窗,最多按审核契约自动修订一次,交付后结束。保留受限查证/实验、审核快照/修订/附录,不创建NIGHT、实施spec/票或worktree,不实施业务代码、不commit/push/开PR、不发夜链通知。
- `--night`:无人值守完整实施;审核终态后按flow第11步固化spec、拆票、逐票实施,含自动推送与收工开PR。审核阶段共识/快照/修订/附录只写`.xcheck/`,不改原稿;首次摄入冻结宿主仓库、启动提交及发布目标。**spec、票与代码在同一夜链分支/worktree提交交付**,原工作区不落实施文档、不commit/push,不替用户stash或rebase;只推选定远端的夜链分支,PR base使用冻结值,不自动合并。没有明确发布目标时仍可本地交付,不自动配远端。Pushover通知可选,未配置或失败不阻塞晨报交付。**夜链操作前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条 Bash 权限弹窗能挂整夜;本技能不修改权限设置。

新链用 `bash ~/.claude/skills/xcheck/lib/run-mode.sh <MODE_REQUEST>` 解析策略,按键读取stdout中的 `interaction` / `target` 赋给 `INTERACTION` / `TARGET`;`night_mode=1` 时才派生 `NIGHT_MODE=1`,`night_mode=0` 必须清除先前的NIGHT_MODE。不得source/eval脚本输出或账本内容。无旗标新链须先经下文入口选择再解析,不能把脚本的default当作已选正常审核。显式旗标免入口选择;恢复必须用下文带盘上字段的四参数形式,不能拿单参数新链结果覆盖账本。

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。缺值、值为空或下一个token以 `--` 开头 → **报缺参并停止**,不得吞掉模式旗标、退回默认集或把后续文本误当模式。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。设 `OVERRIDE_AGENTS = <拆成的名字列表>`;空名字或名字不在 agents.toml 的 `[agents.<name>]` → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续。参数校验使用原token顺序,不能先删除模式旗标后使缺值的 `--agents` 误吞方案文本。

## 2. 查未完成链(弹窗 0)

扫 `<cwd>/.xcheck/*/PROGRESS.md` 与 `NIGHT.md`,先解析迁移和复审交接关系,再建立未完成候选:

- PROGRESS终态空且尚未交接子环 → 评审未完成。**父环gate已勾且有 `next=<子ts>` 不等于待重审**:沿next到最新环,父环去重;每条next须有对应子环且其prev回指父环。缺子环、回指不符、多分叉或循环 → 报状态不一致,不重审父环、不猜最新。父环next已写但gate未勾同样先核对盘上子环,交flow处理交接恢复,不能另建重复子环。
- NIGHT存在且finish未勾 → 夜链未完成候选,包含waiting状态;必须通过下文盘上策略守卫才能接续,不能由NIGHT存在反推实施授权。
- **接续崩溃窗口**:最新环PROGRESS为 `mode=review / review_schema=2`,经下文兼容解析得 `target=implementation`,评审终态为可接续的 `无需修订 / 收敛(*) / 夜间收工`,但NIGHT尚未建立 → 也是待接续候选,续跑从flow第11步建账,不能因此开新链。`target=review` 的无人值守审核终态即完成,即使终态叫“夜间收工”也不列为夜链接续候选。兼容的diag完整night若终态 `完成(diag)`、target=implementation但NIGHT尚未建立,也列为待短稿接续候选,只恢复第11步诊断短稿分流,不实施。

按下面版本守卫解析 `migrated_from` 并去重后,**只用叶环重新判断是否未完成**:叶环评审已终态、NIGHT已finish或不需要夜链接续 → 整链不列为候选,即使父环终态空也不恢复父环。然后在候选最新环中取ts字符串最大的一个(多个未完成则选项顺带列出其余)。无PROGRESS的极旧目录仍静默忽略,不能仅凭孤立NIGHT推断授权。

### 版本守卫(任何恢复/第11步转派之前)

读候选PROGRESS的mode及review_schema,review再读 `lib/review-contract.md` 的恢复契约。NIGHT存在时也检查其schema,不能只因评审已经终态而跳过版本检查。

- **diag**:没有review_schema是正常情形,沿用诊断恢复,不能误判为旧review并迁移。diag不执行实施:TARGET=implementation的完整night保留原短稿分流,完成诊断后第11步只记未执行实施、交付晨报短稿及通知;旧diag-night也只恢复该短稿路径,不把诊断转review、不创建实施spec/票或worktree、不提交推送或开PR。mode缺失或无法判定 → 报状态不一致,不猜测执行。
- **review_schema = 2**:正常恢复;NIGHT存在却无schema或与PROGRESS不一致 → 停止说明。必需产物缺失/字段不合法由flow恢复校验,不能凭阶段勾选补造完成状态。
- **未知或非法review_schema**:拒绝执行,展示账本路径与版本,不自动按2运行。
- **旧review(无review_schema)**:
  - 评审已终态且无未完成NIGHT → 只读保留,不是恢复候选,不把旧终态按新版解释。
  - NIGHT未完成且`plan`已有产物或`impl`已开始 → **暂停该旧链的自动恢复/迁移**。检查不仅是勾选:spec/tickets/impl头部已有路径、对应文件/半截票存在、plan/impl已勾、票台账有记录,任一都须先说明现状;字段缺失而无法排除已有产物也停止。报告旧NIGHT、分支/worktree位置(已知才写),等专门恢复处理;不覆盖旧spec/票、不重新实施、不重放旧原分支commit/push/rebase。人工选择“续跑”也不绕过此守卫。
  - 其余未完成旧review(含review已结束但NIGHT尚无plan产物):只允许建立关联的新版审核运行,不在原目录接着写。续跑选项明确显示“从旧材料重新审核(旧记录保留)”及原交互/终点策略;显式无人值守请求只有与原策略匹配才自动选择同一路径,不增加确认窗。
  - **迁移幂等**:先找 `migrated_from = <旧ts>` 的schema2根环,再沿 `next` 到其最新环,逐跳用子环 `prev` 校验。已有目标 → 只把目标链作为候选,旧目录不再重复计为未完成;目标链已全结束则不再迁移。多个分叉/目标不存在却有冲突记录 → 停止说明,不随意挑一个。
  - 尚无目标且决定继续 → 不设RESUME_TS,设 `MIGRATED_FROM = <旧ts>`、`MODE = review`,把旧proposal(缺失才旧source)作为输入路径,直接转flow第0步/context-intake第0.6的迁移分支。该分支建新schema2目录、source=inline,只复用历史对象/必要背景并重新审核,不继承旧通过或阶段勾选。源内容不可取得就停止;旧目录不改为已完成。

### 夜链交付版本守卫(delivery_schema独立于review_schema)

任何恢复、迁移或第11步转派,对规范化后 `MODE=review / TARGET=implementation` 的候选执行;diag短稿及TARGET=review不要求delivery_schema。沿prev/next核对整链PROGRESS,有NIGHT同时核对其交付字段,不能只看最新环的review_schema=2就放行。

- **旧交付产物先查**:NIGHT的spec/tickets/impl已有路径、对应spec/票/半截文件存在、plan/impl已勾或票台账有记录,任一算已有plan/impl产物;字段缺失而无法排除也不能当作“尚未开始”。已有这些产物却无 `delivery_schema=1`,或缺少可信的冻结元数据/实施身份 → **暂停自动恢复/迁移**,报告已知账本、分支与worktree位置;不重放旧原分支commit/push/rebase、不覆盖旧spec/票、不从当前HEAD重建后跳票。用户选“续跑”不能绕过。
- **delivery_schema=1**:PROGRESS必有 `host_repo / start_oid / source_branch / remote_name / remote_url / pr_base / implementation_blocked / publication_blocked`;根环与复审环冻结值必须一致,NIGHT已建时按flow核验其同名字段及已落实施身份。字段重复、缺失、非法或矛盾即暂停并报告,不从当前仓库补造。`host_repo`须绝对root或明确`-`,`start_oid`须完整commit SHA或明确`-`;`-`必须有一致的不可实施/不发布原因。完整合法的“缺仓库/缺HEAD”记录允许完成审核但禁止实施;合法的“无明确远端/URL/base”记录允许本地交付但禁止push/PR。对不可实施记录不能强求一个编造的SHA以通过守卫。
- **未知或非法delivery_schema**:停止恢复,不自动按1解释。review_schema与delivery_schema任一不合法都不能进入实施。
- **无delivery_schema且可证明尚无plan/impl产物**:旧无review_schema的链仅按上文迁移分支建立新的schema2**审核运行**,迁移不补造delivery字段,不读取当前HEAD作为交付基线。已有review_schema=2的旧链不因缺交付字段自动迁移/重审。两者均允许只读旧审核材料或继续仅`.xcheck/`内的审核,但**暂停实施接续**;不能把恢复/迁移时HEAD当启动提交,不能自动以新交付协议发布。只有用户**明确选择独立新开完整night**才冻结新基线,续跑、自动迁移及再次敲`--night`均不等于明确新开。
- 完整night审核恢复时,历史文件型source也只作追溯,不能借旧source继续向原稿追加附录/同目录修订;flow按完整night只写`.xcheck/`的边界处理。`original_source`不是发布/写入目标,不由它推断授权。

### 盘上策略守卫(恢复/迁移均先核对,再转派)

从PROGRESS头部读取 `interaction` / `target` / `night`:字段重复(即使同值)、存在但空值、存在但值为保留哨兵 `-` 都先报状态不一致停止;**只有字段不存在才传 `-`**。run-mode.sh不解析账本文件,仅接收已读取且校验形状的枚举参数。执行 `bash ~/.claude/skills/xcheck/lib/run-mode.sh <MODE_REQUEST> <interaction或-> <target或-> <night或->`。**必须一次传齐四个参数**;按键读取stdout,将 `interaction` / `target` 赋给 `INTERACTION` / `TARGET`,仅 `night_mode=1` 派生 `NIGHT_MODE=1`,`night_mode=0` 必须清除旧NIGHT_MODE;不得source/eval输出或账本内容。脚本exit 2 → 展示账本路径与不兼容原因并停止,不补字段、不改授权、不先迁移后升级。扫描中先以 `default` 四参数形式归一化候选,选定候选后再用实际MODE_REQUEST匹配;扫描不是新链模式选择。

- 两新字段均缺失:旧 `night=on` → unattended/implementation,无night → interactive/review。**已有schema2仅缺新策略字段仍原环恢复**,不因此迁移或重审,不重置 `auto_revisions_used`。
- 只缺一个新字段、非法值/组合、`night=on` 与显式review终点冲突 → 状态不一致停止。新字段齐全时它们是策略权威,night仅兼容标记。
- 无旗标 `default` 保留盘上策略;`--auto-review` 只匹配unattended/review,`--night` 只匹配unattended/implementation。任何不匹配都明确说明,不得把普通审核续跑升级无人值守或实施,也不得把夜链静默降为仅审核。提示不带旗标续原链,或明确选择新开。
- 沿next及migrated_from关联核验策略一致;已有迁移目标同时核对来源与目标授权,不靠新叶环扩大原授权。迁移只换审核协议,继承实际策略及已耗自动修订预算(不明为unknown),不能因新根round=0重置。旧night已有plan/impl仍受前述暂停守卫限制。
- `TARGET=review` 却存在NIGHT → 报不一致停止,不据它执行下游。diag与TARGET=implementation保留完整night短稿兼容例外,第11步只走诊断短稿分流,绝不执行实施或发布。

### 选择续跑或新开

**waiting幂等**:新版NIGHT已等待解除约束且finish未勾时,先核版本及盘上策略,不能因为再次敲 `/xcheck --night` 就重跑实施或发布。没有用户提供的新决策、解除证据或可核验的状态变化 → 只返回现有等待摘要、受影响路径与解除条件,保持waiting和finish未勾;不生成新运行、不重做spec/票、不push/开PR、不重复通知。无旗标选择续跑也遵守此规则。有新证据时交flow第11步先核验和更新约束,不由壳直接将暂停票改为complete。

- **都没有** → `MODE_REQUEST=default` 时 **入口一问**(AskUserQuestion,单选,完整night推荐列第一):
  - `完整night自动推进到底(推荐) —— 评审→实施说明书→拆票→逐票写代码并互查,全程不问你;审核材料只写.xcheck、不改原稿,spec/票/代码在同一隔离分支交付,不在原分支提交或推送。发布目标明确时每票完成推夜链分支并在收工开PR(不自动合并),否则本地交付;通知需已配置才发送,不配置也有晨报` → `MODE_REQUEST=night`。
  - `无人值守仅审核 —— 自动评审、核实与最多一次必要修订,有未决就记录并交付;不创建实施票、不写业务代码、不提交发布、不发夜链通知` → `MODE_REQUEST=auto-review`。
  - `正常交互审核 —— 评完说明阻断/待决与建议,必要时停点你拍板;评完即止,不接着写代码` → `MODE_REQUEST=interactive`。

  选定后调用单参数run-mode.sh取得INTERACTION/TARGET,再进第3件。`--night` 或 `--auto-review` 已敲则免此问,直接按其请求解析新链策略。裸敲且无未完成链先此问再解析对象,不加两个串行策略弹窗。
- **有且显式 `--night` 或 `--auto-review`** → **不弹窗,自动续**最新未完成链,先执行版本及盘上策略守卫;不匹配/须暂停则停止,不得为了匹配请求悄悄新开。需迁移按迁移分支转第0步;其余评审段未完成 → 设 `RESUME_TS = <ts>`,跳过路由与摄入,按第4件转派flow恢复模式;已终态且 `TARGET=implementation` 的新版夜链未完(含NIGHT尚未建立的接续窗口) → 转flow第11步续;MODE=diag仅恢复短稿分流,不实施;waiting先按上述幂等规则处理。
- **有且无模式旗标** → AskUserQuestion(单选):
  - `续跑 <ts>(停于:<第一个未勾阶段名 + 一句人话>;注明盘上交互方式及仅审核/完整night终点;旧review注明“从旧材料重新审核,旧记录保留”,旧night则注明“重新审核后接续夜链”)` → 先执行版本及盘上策略守卫,用default恢复原INTERACTION/TARGET。旧链可迁移时转迁移分支,不可恢复时说明并停止。新版评审未完:**设RESUME_TS**,跳过路由与摄入,转flow恢复模式;已终态且 `TARGET=implementation` 的新版夜链:**不设RESUME_TS**,按派生的NIGHT_MODE转第11步,MODE=diag仅恢复短稿分流。确认续跑只恢复原授权,不新增实施授权。
  - `新开` → **先走上面的入口一问**(完整night/无人值守仅审核/正常交互审核),再进第3件(输入为空也没关系,第3件会转解析器从上下文推断)。

> 旧版产物(run.md、无 PROGRESS.md 的目录)**不算未完成**,静默忽略。

## 3. 定 MODE(自包含走词表;空/含糊走解析器)

先判剩余 `$ARGUMENTS` 是否**自包含**:文件路径 / 完整报错栈 / 设计文档全文 / 大段代码 / 明显足够长的完整描述。

**A. 自包含** → 关键词路由定 MODE(**子串包含、大小写不敏感**):

- **🩺 diag 强信号**(已发生的坏现象 / 根因):中文(报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈);英文(error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE 及类似大写错误码)
- **🔎 review 强信号**(待决策的方案 / 设计 / 改动):中文(评审、审核、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、spec、plan、看看、过一遍、检查、PR、MR);英文(review、design、proposal、spec、plan、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback)
- 判定:单边命中直通;双边命中或双空 → MODE = auto,交第0步依据对象/意图解析,只在实质歧义时问一次;`INTERACTION=unattended` 不弹窗,仍不能确定对象/模式就停止说明。不要因关键词双命中给明确讨论多加一个确认窗。

**B. 空或含糊**(为空、超短、或含指代词:刚才/那个/上面/之前/这个/这/那/this/that/above)→ **不定 MODE**:设 `MODE = auto` 直接进第4件转派。flow第0步解析器尊重显式意图:指代讨论优先对应讨论,无关最新文件不能抢对象。review自动整理对象与D快照,只有实质歧义才确认;diag保持事实清单确认(见 `lib/context-intake.md`)。

## 4. 转派 flow.md

**诊断分流**:MODE=diag保持原诊断模板/三分类及 `完成(diag)`,不因完整night请求改成review。TARGET=review时诊断交付即止,无人值守仅免摄入确认,不引入D/F、不建NIGHT、不通知。TARGET=implementation时保留原完整night短稿兼容例外:诊断完成后第11步只交付未执行实施的晨报短稿及通知,不创建实施spec/票或worktree、不写业务代码、不commit/push/开PR。MODE=auto由flow第0步落定后执行同一分流。

设 `MODE = diag | review | auto`(auto由第0步解析器落定),连同 `OVERRIDE_AGENTS`、`RESUME_TS`、`MIGRATED_FROM`、`MODE_REQUEST`、`INTERACTION`、`TARGET`、`NIGHT_MODE`(仅TARGET=implementation时派生为1),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。RESUME_TS只用于可恢复的现有环,MIGRATED_FROM用于旧review新摄入,两者不同时设置。首次创建PROGRESS即保存interaction/target,复审和迁移继承实际策略及自动预算;不等摄入完成后才记。首次完整night的review摄入同时按context-intake冻结delivery_schema=1与宿主/启动提交/分支/远端/PR base,source=inline、original_source只追溯;复审继承而不重新探测覆盖,摄入不建worktree。diag用原诊断模板;review用schema2审核契约、首轮/复审模板及review汇总模板。每个新review包括自包含输入都必须生成 `decisions.md`,不能因壳已定MODE跳过。`TARGET=review` 终态收尾后立即结束,不进入第11步。

## 铁律(全套,不打折扣)

- **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合只在主会话。
- **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
- 交互流程开口仍集中在四处:入口选择、续跑确认、第0步摄入(review仅实质歧义;diag事实清单确认)、第9步停点(含需要用户改变已定决策的明确裁定)。其余自动推进。`INTERACTION=unattended` 时摄入/停点不弹窗,显式模式旗标免入口/续跑问句;无旗标接续仍先确认。无人值守**不等于替用户补定重要决策**:局部未决限制相关路径,全局目标不明则停止,已确认约束不能被“自动化优先级”覆盖。只有 `MODE=review / TARGET=implementation` 才接实施;仅审核不建NIGHT、不实施、不发布、不发夜链通知。
- 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,原稿正文不动。正常review与--auto-review保持文件型终态追加附录的原例外;完整night审核共识/快照/修订/附录只写`.xcheck/`,原稿正文与文末均不动。night的spec/票/代码只在同一实施worktree提交,绝不在原分支commit/push、不stash/rebase原工作区、不修改git配置;仅按冻结目标发布夜链分支,绝不force或自动合并。
- **至少一个非 claude**;全 claude 只标注不拦。
- 派 subagent 用便宜模型,一条消息并行;成败看退出码,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 产物落 `.xcheck/<ts>/`(已gitignore);对话说人话、文件留机器账。review交付由FINDINGS中的事实与影响裁定投影,精选一般建议只作参考,不自动进入方案/spec/票;活动阻断或重大风险待决未解除只允许确定独立路径推进,收工不等于放行。diag保持三分类诊断交付。终点不是把方案修到完美;交付按第9步四问结构自包含说明对象/发现/修订/所需决定,不让用户翻文件才能懂;终态收尾原样输出“**以上是建议,共识 ≠ 正确,最终你拍板。**”
