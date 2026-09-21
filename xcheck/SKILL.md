---
name: xcheck
description: 一次触发全自动异构评审 —— 并行评审本地多个 AI agent、自动查证与实验,区分阻断与非阻断建议、限定范围复审,终点交付。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--auto-review | --night] [--agents a,b,c] [--lanes N] [<问题描述或方案>]
---

# /xcheck — 单停点全自动链入口

`$ARGUMENTS` 可空。你(壳)只做四件事:**抠旗标(--auto-review / --night / --agents / --lanes)→ 查未完成链(含版本守卫)→ 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(摄入)+ 11 步」(第 11 步 = 完整夜链专属),你不重新实现它。review 遵守 `lib/review-contract.md` 的 `review_schema = 2`;diag保持原有诊断协议。`INTERACTION` 控制是否询问,`TARGET` 控制执行终点——**闸门只看这两个字段,不派生第三变量**。

## 1. 抠旗标(--auto-review / --night / --agents / --lanes,可选)

先检查独立布尔 token `--auto-review` 与 `--night`:**两者互斥,同时出现立即报错停止**。只含 `--auto-review` → `MODE_REQUEST = auto-review`;只含 `--night` → `MODE_REQUEST = night`;均无 → `MODE_REQUEST = default`。删除已识别模式旗标,不改变剩余输入。两者均可与 `--agents` 并用,顺序不限。

- `--auto-review`:无人值守**仅审核**;摄入与停点不弹窗,最多按审核契约自动修订一次,交付后结束。保留受限查证/实验、审核快照/修订/附录,不创建NIGHT、不实施、不commit/push、不发夜链通知。
- `--night`:无人值守完整实施;审核终态后按flow第11步固化spec、拆票、并行实施(并发帽=`--lanes`/`night_parallel_lanes`,罩实施+票级评审合计,ADR 0008),每票即推夜链分支;**不自动开PR**,晨报给一键链接;原分支零commit/push/pull/rebase;`material=external` 时实施失败关闭。Pushover通知可选,未配置或失败不阻塞晨报交付。**夜链操作前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条 Bash 权限弹窗能挂整夜;本技能不修改权限设置。

新链用 `bash ~/.claude/skills/xcheck/lib/run-mode.sh <MODE_REQUEST>` 解析,按键读取 stdout 的 `interaction` / `target` 赋给 `INTERACTION` / `TARGET`;不得source/eval脚本输出或账本内容。**入口为旗标直选(0.22)**:无旗标新链 = 正常交互审核(default),不再弹三选一入口问;想无人值守请敲 `--auto-review` 或 `--night`。恢复必须用三参数形式(request + 盘上两字段),不能拿单参数新链结果覆盖账本。

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。缺值、值为空或下一个token以 `--` 开头 → **报缺参并停止**。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。设 `OVERRIDE_AGENTS = <拆成的名字列表>`;空名字或名字不在两层登记表(模板 agents.toml + 个人层 `~/.claude/xcheck/personal.toml` 的 `[agents.<name>]`)→ **报错停住**,打印"名字 X 不在登记表;可用 agent:<列出两层所有 [agents.*] key>"。参数校验使用原token顺序。

若 `$ARGUMENTS` 含 `--lanes`:其值 = 紧跟后**一个空白分隔 token**(整数 ≥1)。缺值、非整数或 <1 → **报缺参并停止**。**仅 `--night` 可携带**(`--auto-review` 或无模式旗标时出现 → **报错停住**:评审段没有泳道,防止误以为评审也会加速)。把 `--lanes <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。设 `OVERRIDE_LANES = <N>`;生效优先级 `--lanes > night_parallel_lanes`(模板 agents.toml [defaults] 默认 3,个人层同名键覆盖;并发帽罩实施泳道+票级评审合计,ADR 0008)。**续跑夜链允许改道**:只影响后续派发,NIGHT 追记一行(原值→新值)。

## 2. 查未完成链(弹窗 0)

扫 `<cwd>/.xcheck/*/PROGRESS.md` 与 `NIGHT.md`:

- PROGRESS终态空且尚未交接子环 → 评审未完成。父环gate已勾且有 `next=<子ts>` 不等于待重审:沿next到最新环(next须有子环且回指prev,缺环/分叉/循环报不一致),父环去重。
- NIGHT存在且finish未勾 → 夜链未完成候选(含waiting);不能由NIGHT存在反推实施授权。
- 接续崩溃窗口:最新环target=implementation、评审终态可接续(无需修订/收敛/夜间收工)但NIGHT尚未建立 → 待接续候选,从flow第11步建账。

**版本守卫(一次读盘、三类守卫跑在同一快照上)**:每个候选读一次PROGRESS/NIGHT,同时校验——① review链必有 `review_schema = 2`(diag无此字段属正常);② NIGHT为0.22字段集(start_oid/branch/remote_url/pr_base等);③ `interaction/target` 字段齐全且为合法枚举,交给 run-mode 三参数形式归一化。**旧协议链(无review_schema、或NIGHT为0.21及更早字段集)一律拒绝**:提示"旧协议链已不支持自动续跑,请新开一条;旧目录只读保留",不迁移、不重放。未知schema同样拒绝。`TARGET=review` 却有NIGHT → 状态不一致停止。

- **waiting幂等**:NIGHT已等待且finish未勾时,再次敲 `/xcheck --night` 不重跑实施/发布;没有新决策或解除证据 → 只返回现有等待摘要与解除条件,不重复通知。有新证据交flow第11步核验,壳不直接改票状态。

**选择续跑或新开**:

- **都没有**(无未完成链)→ 按第1件旗标直选的 `MODE_REQUEST=default` = 正常交互审核,直接进第3件(无入口弹窗)。
- **有且显式 `--night` 或 `--auto-review`** → **不弹窗,自动续**最新未完成链(先过版本守卫);不匹配则停止,不得为匹配请求悄悄新开。评审段未完 → 设 `RESUME_TS`,转flow恢复模式;已终态且target=implementation → 转flow第11步续;waiting先按幂等规则处理。
- **有且无模式旗标** → AskUserQuestion(单选):
  - `续跑 <ts>(停于:<第一个未勾阶段名 + 一句人话>;注明盘上交互方式与终点)` → 过版本守卫,用default恢复原INTERACTION/TARGET;评审未完设RESUME_TS转恢复模式;已终态的夜链确认续跑 = 接管night语义转第11步。确认续跑只恢复原授权,不新增实施授权。
  - `新开` → 按旗标直选语义(default=交互审核)进第3件;输入为空也没关系,第3件会转解析器从上下文推断。

> 旧版产物(run.md、无 PROGRESS.md 的目录)不算未完成,静默忽略。

## 3. 定 MODE(自包含走词表;空/含糊走解析器)

先判剩余 `$ARGUMENTS` 是否**自包含**:文件路径 / 完整报错栈 / 设计文档全文 / 大段代码 / 明显足够长的完整描述。

**A. 自包含** → 关键词路由定 MODE(**子串包含、大小写不敏感**):

- **🩺 diag 强信号**(已发生的坏现象 / 根因):中文(报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈);英文(error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE 及类似大写错误码)
- **🔎 review 强信号**(待决策的方案 / 设计 / 改动):中文(评审、审核、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、spec、plan、看看、过一遍、检查、PR、MR);英文(review、design、proposal、spec、plan、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback)
- 判定:单边命中直通;双边命中或双空 → MODE = auto,交第0步依据对象/意图解析,只在实质歧义时问一次;`INTERACTION=unattended` 不弹窗,仍不能确定对象/模式就停止说明。

**B. 空或含糊**(为空、超短、或含指代词:刚才/那个/上面/之前/这个/这/那/this/that/above)→ **不定 MODE**:设 `MODE = auto` 直接进第4件转派。flow第0步解析器尊重显式意图(见 `lib/context-intake.md`)。

## 4. 转派 flow.md

**诊断分流**:MODE=diag保持原诊断模板/三分类及 `完成(diag)`,不因--night改成review。TARGET=review时诊断交付即止;TARGET=implementation时诊断完成后第11步只交付未执行实施的晨报短稿及通知,不实施。

设 `MODE = diag | review | auto`(auto由第0步解析器落定),连同 `OVERRIDE_AGENTS`、`RESUME_TS`、`MODE_REQUEST`、`INTERACTION`、`TARGET`,按 `~/.claude/skills/xcheck/lib/flow.md` 执行。首次创建PROGRESS即保存interaction/target与 `material = trusted|external`(摄入按context-intake判定),复审继承实际策略及自动预算。每个新review包括自包含输入都必须生成 `decisions.md`。`TARGET=review` 终态收尾后立即结束,不进入第11步。

## 铁律(全套,不打折扣)

- **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合只在主会话。
- **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
- 交互流程开口集中在三处:续跑确认、第0步摄入(review仅实质歧义;diag事实清单确认)、第9步停点(未决逐个问)。**无旗标新链不再有入口问**(0.22 改旗标直选,default=交互审核)。`INTERACTION=unattended` 时摄入/停点不弹窗;无人值守**不等于替用户补定重要决策**。只有 `MODE=review / TARGET=implementation` 才接实施;仅审核不建NIGHT、不实施、不发布、不发夜链通知。
- 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,原稿正文不动(review终态对文件型source追加附录除外;完整night审核只写`.xcheck`)。night的spec/票/代码只在夜链分支提交(接管检出,ADR 0005),绝不在原分支commit/push/pull/rebase、不stash/rebase原工作区;每票即推夜链分支、绝不force、**不自动开PR**(ADR 0006);`material=external` 失败关闭(ADR 0004)。
- **至少一个非 claude**;全 claude 只标注不拦。
- 派 subagent 用便宜模型,一条消息并行;成败看退出码,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 产物落 `.xcheck/<ts>/`(已gitignore);对话说人话、文件留机器账。review交付由FINDINGS投影;终点不是把方案修到完美;交付按第9步四问自包含;终态收尾原样输出"**以上是建议,共识 ≠ 正确,最终你拍板。**"
