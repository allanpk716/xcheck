# xcheck 自动链执行流程(mode = diag | review)

主会话执行第0~9步及必要的第10步修订复审。壳已设 `MODE`(diag/review/auto)、`INTERACTION`(interactive/unattended)、`TARGET`(review/implementation)、可选OVERRIDE_AGENTS/RESUME_TS/MIGRATED_FROM。两维经 `lib/run-mode.sh` 校验,只有unattended+implementation派生NIGHT_MODE=1。**询问只看INTERACTION,接续实施只看TARGET**;不得把无人值守当作授权实施。--auto-review在审核终态收尾后直接结束,不建NIGHT、不发夜链通知、不执行第11步。

**进度只认盘(铁律)**:每阶段完成即在 `<cwd>/.xcheck/<ts>/PROGRESS.md` 打勾(格式见文末)。会话崩了/中断,用户重敲 `/xcheck`,壳检测未完成链、经用户确认后续跑——恢复与排障的唯一依据是这个文件,不依赖任何会话记忆。

**停点纪律**:入口/续跑按壳处理;摄入仅实质歧义确认;第9步负责交付与关键决策,多个未决依赖逐个问而不是将泛答视作全部授权。检测/派发/查证不反复问进度。INTERACTION=unattended时不等人,可确定的技术细化自动裁定,重大待决/用户决策冲突按契约暂停相关路径,不能自动通过。

**审核契约(review_schema = 2)**:review 在摄入、分类与交付前必须读 `lib/review-contract.md`。事实成立与阻断分开,只有活动约束(开放的阻断/重大风险待决)阻止相关路径推进。关键决策足以实施即可,下游细化和普通建议不触发反复修订,不自动扩大规格/票。三分类仍管取证,不管严重程度。diag保持原诊断路径。当前CLI仍只读指定材料,其权限隔离尚未强化,不得声称已实现强制沙箱。

**播报纪律(铁律)**:**对话说人话,文件留机器账**。过程段(第 4~8 步)在对话里只播一两行人话进度并标明"无需操作",明细一律落盘不铺对话;决策问句集中在第9步停点(摄入对象歧义除外)。编号(`#n`)、enum(AGREE/SUGGEST_CHANGES)、严重度标签、①②③、m/round、终态值、"必改项/fanout/collect/triage"这类**机器词只出现在 SUMMARY.md 里**;进对话必须翻译成人话(`#n`→"第 n 条,谁提的";①②③→"当场查实的/做实验证实的/拿不准的";SUGGEST_CHANGES→"建议修改";推倒重来→"建议放弃这份方案从头再来")。agent 名只作为"谁提的"出现,每句话都在说用户的方案,不说流程自己。夜链终局的对话收尾固定三段式「夜链结论 / 简报 / 推荐下一步」(第 11.7),同一纪律。

**自包含铁律(0.15.0)**:对话里的呈现(尤其第 9 步交付与停点问句)必须**不看任何文件就能懂、就能选**——发现了什么、证据是什么、选项有哪些、每个选项的后果、一个建议,全部当场说清;SUMMARY.md / 方案文档 / 修订版只是留底,**绝不是"让用户自己去看"的理由**。让用户翻文件才能懂或才能做决定 = 交付失败(2026-09-17 用户实证)。

---

## 恢复模式(RESUME_TS 存在时,最优先)

1. 读 `<cwd>/.xcheck/<RESUME_TS>/PROGRESS.md`;读不到 → 报"PROGRESS.md 不存在,无法续跑",停。
2. 从头部读出 `mode` / `selected` / `source` / `round` / `prev` / `review_schema` / `next`。若有next,核实子环prev指回本环并沿链找到最新环(环路/缺子环停止报告),不要重跑已交接的父环。review缺schema按契约旧链迁移:保留旧目录,幂等建立 `migrated_from` 新链重新审核;旧NIGHT已有plan产物或impl不得自动迁移执行。未知schema或schema2必要产物缺失 → 停止并报告不一致。diag不走此schema检查。
3. **当前 ts = RESUME_TS**(schema2正常恢复不新建目录)。核验契约所需的decisions/FINDINGS/复审基线后,已勾阶段跳过;从第一个未勾阶段整段重做。
4. 用户已答决策只认decisions.md的出处记录,不靠会话记忆;gate未勾仅重新确认尚未落盘的选择,已落盘的关键决定不得擅自改写;intake已勾且产物完整不再问。
5. 恢复不再弹"续还是新开"(壳已问过)。
6. 从PROGRESS恢复interaction/target,调用 `bash ~/.claude/skills/xcheck/lib/run-mode.sh <MODE_REQUEST> <interaction或-> <target或-> <night或->` 核验(MODE_REQUEST缺省default);按键读取输出设置INTERACTION/TARGET及派生NIGHT_MODE(0清除旧值),非零即停止,不得source/eval输出。头部字段重复、存在但空值先拒绝,只有不存在字段传`-`。仅两新字段均缺时允许旧night兼容映射,半缺/非法/与night=on矛盾都拒绝。迁移与复审保留原模式,显式请求不匹配不能改账接管。TARGET=review却有NIGHT为状态冲突,停止而非发布。

## 第 0 步:对象解析(空/含糊输入)或零往返带背景(自包含输入)

- **MODE = auto** → 按 `lib/context-intake.md` 解析用户显式指向的对象。明确讨论意图优先当前讨论,不被无关近期文件截走。自动整理共识快照,只对影响对象/重要决策的歧义正常模式确认,不强制全文过目。diag仍用诊断摄入。
- **INTERACTION = unattended** → 不弹确认;有明确对象将对象/推断限制记入decisions(完整night另存night-intake.md);全局对象不明记录未完成原因并返回,不猜对象。只有TARGET=implementation可走夜链通知;--auto-review仅本地留档和对话提示。
- **MODE 已定** → 保持显式文件/贴文对象,按context-intake第0.6步附必要背景;review还按契约建立decisions.md,标注来源与未知。不要因近期会话窗口截断把关键决策伪装成不存在。`MIGRATED_FROM`存在时必须优先执行摄入的迁移分支,复制旧材料到新目录、source=inline、记migrated_from,不得将旧proposal当新source而追加修改旧记录。
- 解析/扫描若已建 `<cwd>/.xcheck/<ts>/` → 后续**复用这个 ts**,不重复建。
- 完成后勾 PROGRESS:`intake`(自包含跳过解析也算完成)。

## 第 1 步:检测 + 定选集 + 初始化 PROGRESS

1. 跑 `bash ~/.claude/skills/xcheck/lib/detect.sh`。stdout = 已装 agent(每行 `name \t installed_check \t installed`);stderr = 已登记未装。**已装 < 2** → 告诉用户太少(异构至少 2 家、≥1 非 claude),建议 `/xcheck-setup`,**停**。
2. **初始化 PROGRESS.md**(摄入没建目录时才建):`<cwd>/.xcheck/<YYYYMMDD-HHMMSS>/`(本地时间),写头部interaction/target(所有mode均写;格式见文末;`selected`/`source` 先留待定,本步与 3.1 步补写)。
3. **定候选集**(一条道,无弹窗):
   - `OVERRIDE_AGENTS` 非空(壳已校验名字)→ 候选 = 它。
   - 否则读 `~/.claude/skills/xcheck/agents.toml` 的 `[defaults].default_agents`:存在且非空 → 候选 = 它;坏名(不在 `[agents.*]`,toml 被手改坏)**防御剔除**后用剩余;剔除后空 → 报错停。
   - 都没有 → **报错停住**:"未设默认集也没敲 --agents。先跑 `/xcheck-setup default <a,b,c>` 设默认集,再 /xcheck。"**不弹多选。**
4. 取 `SELECTED = 候选 ∩ INSTALLED`:缺员 → 用交集,输出注明"默认集里 <缺的名> 当前未装/未登录,本轮用 <交集>";交集 < 2 家 → 停。
5. 同构(全 claude 或 <2 家)→ **不拦**,第 9 步 SUMMARY 顶部标注 "⚠️ 本次为同构,异构价值未体现"。
6. 候选集写进 PROGRESS 的 `selected`(冒烟后更新为幸存者),勾 `detect`。

## 第 2 步:冒烟预检(SELECTED 每家;预算 per-agent,超时自动重试一次)

1. 备两个固定文件(一轮一次;第二条 printf 的 `<cwd>` 代入实际绝对路径、正斜杠):
```
mkdir -p <cwd>/.xcheck
printf '西瓜47' > <cwd>/.xcheck/smoke.txt
printf '读文件 <cwd>/.xcheck/smoke.txt(绝对路径、正斜杠),原样回复文件里的内容,不要加别的字。\n' > <cwd>/.xcheck/smoke-prompt.txt
```
2. 对 SELECTED **一条消息并发后台启动**各家的冒烟(沿用「后台启动 + 回合内阻塞等待」纪律,严禁前台串行直等):每家一条 Bash 调用(`run_in_background: true`):
```
bash ~/.claude/skills/xcheck/lib/run-agent.sh <name> <cwd>/.xcheck/smoke-prompt.txt --timeout <预算>
```
   全部启动后逐家 TaskOutput(block=true,timeout=600000)阻塞等齐——wall = max(各通道) 而非 sum。**预算 = 该家在 agents.toml 的 `smoke_timeout_sec`,缺省 60**。
3. 判定(产物落 `.xcheck/` 根):`.xcheck/<name>.exitcode` 为 **0** 且 `.xcheck/<name>.raw.stdout` 含 `西瓜47` → 可用(CLI 活性 ✓ + 读文件能力 ✓ + 传参机制 ✓)。
   - **124 超时 → 自动原样重跑一次**(同预算,每家最多一次;多轮调用通道有 30s~120s 级方差,一次超时不足以判死——2026-09-17 四次实证均为"慢非死")。重跑 exit 0 且含 `西瓜47` → 可用,failed.md 里记一行"首跑超时,重试通过"备查。
   - 重跑仍超时,或 **65/66/67 脚本层故障、非零 CLI 码(401 欠费/未登录/损坏)、exit 0 但没有 `西瓜47`(非交互读不了文件)** → 剔除,告知用户"<name> 预检失败:<exitcode + run.log/stderr 末行>,本轮跳过",落 `<cwd>/.xcheck/<name>.failed.md`(两次结果都记)。
4. 剔除后 <2 家 → 按第 1 步同款话术停。**幸存者 = 最终 SELECTED**,更新 PROGRESS 的 `selected`,勾 `smoke`。

> 冒烟必须带读文件、必须走 run-agent.sh(与实跑同机制):第 3 步起方案全文靠 agent 自己读文件,读不了文件的家整轮只能产空评,必须在 fan-out 前拦下;预检与实跑同机制才闭合"预检绿 ≠ 实跑绿"盲区(2026-08-15 pi 401 实证)。

## 第 3 步:备料 + 并行派发

### 3.1 内容层落盘(两层分离,全文绝不进 prompt)

复用已有 ts 目录,以下文件全进 `.xcheck/<ts>/`(已 gitignore):

| 内容 | 文件 | 怎么落 |
|---|---|---|
| 方案全文(review) | `proposal.md` | `$ARGUMENTS` 是文件路径 → Bash `cp` 成快照(内容零 token 过主会话);贴文/摄入产物 → 主会话 Write 一次 |
| 问题全文(diag) | `input.md` | 同上 |
| 背景(可选,两 mode 共用) | `context.md` | 用户额外上下文/摄入事实清单/零往返摘录 → Write;没有不建 |
| 决策(review必需) | `decisions.md` | 按review-contract建D记录;复审继承并保留变更来源 |
| 复审上下文(round≥1必需) | `re-review-context.md` | 上一环全部F记录、D约束、实际修订差异、逐条修复理由;第10步预建 |

review创建PROGRESS时写 `review_schema = 2`、原生新链 `auto_revisions_used = 0`;旧链迁移预算按契约核实或unknown;intake勾选前核验proposal与decisions已落盘。摄入已建立source时不得由后续泛化规则覆盖;intake已勾且快照完整时复用,不可再次cp已变化原文件。

**source 判定**(写进 PROGRESS):输入是文件路径 → 记其绝对路径;贴文/固化文本 → `inline`。

> 落快照而非直读原文件:原文件可能评审中途被改,快照固定本轮对象、留审计底。
> 为什么拆两层:全文内联进 prompt,arg 模式撞 **Windows 32767 字符命令行上限**;全文 Read 进主会话再 Write 烧双倍 token。拆开后指令层恒 ≤2KB,文件输入不过主会话。

### 3.2 指令层落盘

- **diag** → 读 `~/.claude/skills/xcheck/prompts/diag.md`,`{{INPUT_PATH}}` 替换成 `input.md` 的**绝对路径**;有 `context.md` 就填 `{{CONTEXT_PATH}}`,没有把【上下文】块整块删掉。
- **review** → round 0用 `prompts/review.md`,round≥1用 `prompts/re-review.md`;填 `{{PROPOSAL_PATH}}` / `{{CONTEXT_PATH}}` / `{{DECISIONS_PATH}}` / `{{RE_REVIEW_PATH}}`(仅复审)绝对路径。无context时删该行,必需文件缺失则停止,不得删除决策/基线槽位凑成功。填完检查指令UTF-8字节≤2048,过长就缩短指令措辞/路径呈现而不丢约束,内容不得内联。
- 填的路径一律**绝对路径 + 正斜杠**(`C:/...`),写到 `<cwd>/.xcheck/<ts>/prompt.txt`。

> **固化 proposal 的自代入陷阱**:proposal 正文别写会让被评 agent 自代入的背景(点名 agent、写"异构评审"等触发词),历史上下文用**中性陈述**("本方案曾有一个 X 缺陷,已通过 Y 解决"),否则被评 agent 可能把自己当成"该跑评审流程的人"(实测触发过权限弹窗失败)。

### 3.3 一条消息并发派 |SELECTED| 个 subagent

**在一条消息里**同时开出全部 Agent 工具调用并行跑(不要串行 await)。每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的**全文** + 末尾追加:

```
AGENT_NAME = <name>
PROMPT_FILE = <cwd>/.xcheck/<ts>/prompt.txt   # 绝对路径;正反斜杠皆可,run-agent.sh 自动转正斜杠
RESULT_SHAPE = <diag:根因/证据/置信度/建议 | review:裁决/逐条问题(位置、严重度类型、发生条件、具体影响、证据或缺口、关联决策、解除条件)/理由;复审另带原问题复核(F编号、结论、证据或缺口)>
```

- subagent 用**便宜模型**(haiku/sonnet)——它只是搬运工。
- 搬运工第 1 步必须 `run_in_background: true` 后台启动 run-agent.sh,并**在本回合内立即阻塞等待**:前台直等会被 600s 上限掐断、结论永久丢失(2026-08-14 codex 事故);停回合"等通知再来"则搬运永不发生(2026-08-31 实证)。详见 carrier 文档。
- 全部派出后勾 `fanout`。

## 第 4 步:收齐落盘

等所有 subagent 完成(并行跑,等齐)。每个返回两段(`## <name> 原始输出` + `## <name> 结构化结论`)或超时/失败行,逐个拆开落盘 `.xcheck/<ts>/`:

- `<name>.raw.out` —— 原始 CLI 输出(原样,不洗 ANSI、不删 codex 噪声,留底核查)。
- `<name>.summary.md` —— 结构化结论。
- 失败/超时:另写 `<name>.failed.md` 记一行(原因 + 退出码 + stderr 摘要)。

**判活闸门(0.16.0,全轮生效)**:每家以 exitcode 文件为唯一权威——**exitcode ≠ 0、spawn 失败、或产物缺失(无 `<name>.summary.md` / `<name>.raw.out`),任一即记 failed.md**(不枚举失败码,任何非零退出都是失败:401 欠费、配额、CLI 崩溃一视同仁);collect 后幸存 <2 家 → 按第 1 步同款话术停链。这是复审环跳过冒烟后的兜底闸门,首轮同样生效。

**不要在这一步做综合判断**。完成后勾 `collect`。

## 第 5 步:汇总(主会话)

- **diag** → 读 `~/.claude/skills/xcheck/prompts/synthesize-diag.md`,`{{ALL_CONCLUSIONS}}` 替换成各家 `.summary.md` 内容拼接,按模板输出综合,写 `<cwd>/.xcheck/<ts>/SUMMARY.md`。
- **review** → 读 `~/.claude/skills/xcheck/prompts/synthesize-review.md`(紧凑头版),`{{ALL_REVIEWS}}` 同上,输出**紧凑头**(各家裁决一览一行 + 总判三定式一句 + 返回/失败/同构标注)写 SUMMARY.md。**共识/分歧长文不再输出**——逐条细节交给第 6 步三分类。
- **播报(review,≤2 行人话)**:`✓ N/M 家返回(裁决人话化,如"kimi 建议改 · codex 同意 · gemini 反对"),正在逐条核实,这几分钟不用你做任何事,核实完一起给结论。`

完成后勾 `synthesize`。

## 第 6 步:三分类

1. 读本轮所有成功家的 `.summary.md`,拆出每条反馈及来源,无反馈不造问题。
2. **diag**:保持 `prompts/triage.md` 三分类,重复各留来源,追加SUMMARY;呈现诊断结果及收尾句,终态 `完成(diag)`。夜链仍第11步短稿分流,不执行实施。
3. **review**:读 `lib/review-contract.md` 与 `prompts/triage-review.md`,建立/幂等更新FINDINGS.md。①②③都用稳定F编号,重复归并但每个来源都映射;复审保留上一环全部问题与关闭证据,不得仅处理本轮新增。
4. 摄入关键未决/决策冲突按契约入账,来源与外部反馈分开。SUMMARY列三类索引与计数,原始反馈留底。
5. 勾 `triage`,review始终进第7/8/9步(空类别记无)。**禁止因①②为空提前通过**:③或D中的重大风险待决仍可能约束推进。

## 第 7 步:查证①(自动,只读,不问)

主会话逐条核实FINDINGS①及复审旧问题的解除证据,从相关文件/配置/文档取证;不得把旧通过或本轮没提到当解除。>10条可派便宜subagent只回传证据,裁决仍主会话做。

事实写回F记录:证实/证伪/未确定(查无实据),带文件:行或原文引证;保留历轮证据,标明哪些已失效。无条目记无,勾 `verify`。播报一行属实/不成立/未确定数量,不在这里把属实都叫必改。

## 第 8 步:实验②(自动,沙箱,不问)

逐条按已设计方法执行,产物只写 `<cwd>/.xcheck/<ts>/exp/`;禁止改业务代码、联网外呼、部署。单条超时300秒,失败/超时/环境不足记无定论,继续其他条。

结果及路径写回F记录:成立→事实证实,不成立→证伪,无定论→未确定。空类记无,勾 `experiments`。③保持未确定,不因无法实验而判不成立。

## 第 9 步:裁定、交付 + 停点

1. **先裁定后投影**:主会话逐条按review-contract的顺序,将事实、具体影响、范围、解除条件、决策冲突和裁定写回FINDINGS。先核实原问题是否满足解除条件,已验证修复保持已解除,不能因历史事实属实重新标开放。严重度不是门槛。活动约束=开放阻断+开放重大风险待决。所有待验证/待裁定字段必须处理完(无法判定如实未确定),之后才准出终态。
2. SUMMARY置顶机械五字段:状态(活动约束空→可推进,否则相关路径暂停)、活动约束详情、各家裁决、信号、统计。非阻断建议精选呈现,不强制清零。裁定记录与投影不同步不得勾 `deliverable`。
3. 对话按四问,自包含:
   - **这次评了什么**:对象、几家、第几轮、材料覆盖限制。
   - **发现了什么**:优先哪些必须先解决、为什么、暂停哪里、解除条件;证实与待决分开说。少量一般建议标可选,查过不成立的概述并附证据位置,完整记录留底。
   - **改了什么**:首轮未修订或历轮实际解除/残留、是否触及已定决策;无进展明确说。
   - **你现在要决定什么**:说明可推进范围或所需具体决策、选项后果及一个建议,不能要求翻文件才能懂。
   - 收尾:原始评审和逐条证据在 `.xcheck/<ts>/`。以上是建议,共识 ≠ 正确,最终你拍板。
4. **正常模式停点(INTERACTION = interactive)**:
   - 活动约束空:不问,round0→无需修订,round≥1→收敛(m轮修订);有一般建议不影响此终态。
   - 存在已确认决策冲突:优先在此停点问该具体取舍,一次一个问题。用户明确改定时追加D记录并将旧D标已替代;不能将“修订再评”泛答当作改变所有约束的许可。选择暂不决定则保留未决,可先交付 `用户不修`。
   - 其余活动约束:round<2给“在已确认范围内修订再评/先交付并保留相关路径暂停”;只有有可执行修复才推荐前者。仅缺证据或用户决定时说明无法靠改写消除,不假装修订。
   - round≥2有约束:再修一轮/按现状交付/明确放弃。无新修复路径必须说明无进展,推倒重来只能用户明确选。
   - 用户选择交付→用户不修,不是清空约束或自动授权下游绕过。
5. **无人值守自动决策(INTERACTION = unattended)**(不问,同时适用于auto-review与night):
   - 活动约束空→无需修订/收敛。
   - round0且auto_revisions_used明确为0、并有可在已确认范围内修复的阻断→只修这些并复审一次;其他待决继续保留。
   - 仅待决、需改变用户决定、无可执行修复、自动预算已用/未知或round≥1仍有约束→夜间收工,记录原因/无进展/解除条件,不把它记成人的决定。TARGET=review在终态交付后结束,不得进入实施;TARGET=implementation的下游只能继续明确独立任务。
6. 终态交付先写附录再写终态并勾gate;选择修订则第10步新环和材料落盘后才勾gate。

## 第 10 步:修订 + 限定范围复审

1. 主会话按D约束和F证据亲写修订稿,仅处理已授权、可修复的阻断;一般建议不自动加入。用户决策冲突没有新明确回答则保留,不能替用户改变产品行为。
2. 修订基于本轮proposal快照。TARGET=implementation时只写本轮 `.xcheck/<ts>/proposal.rev<m>.md`,original_source仅追溯不写入;TARGET=review且source是文件时同目录写新 `<原名>.rev<m>.md`;inline写 `<ts>/proposal.rev<m>.md`。原稿正文不动。源文件被外部改过→正常模式确认对象,无人值守暂停该修订;不能静默改用新基线。已有rev先查看,不得覆盖来源不明或用户修改的稿。
3. 新建 `<ts2>/PROGRESS.md`:review_schema=2、mode=review、prev=当前ts、round=m、source=新稿(完整night保持inline并以新稿建子环proposal),继承interaction/target、全部night-delivery冻结元数据(不得重新取当前HEAD/分支/remote)、original_source(只有implementation继承night=on)与auto_revisions_used(本次自动修订则加1)。复制decisions和完整FINDINGS历史,写 `re-review-context.md`(上一环全部F、D约束、实际差异、逐条修复理由)。新proposal落盘后勾intake,当前环记录 `next=<ts2>` 并勾gate。相同恢复遇已有next先验证复用,不重复建环。
4. 当前ts切到新环,重跑1~9但第3步用re-review模板,不是完整重新开题。detect照跑;冒烟可跳过仅当该家最近一次真实smoke成功、agents.toml指纹一致、上一环exit=0且有summary;否则重冒烟。collect仍有不足两家停止闸门。
5. 复审须逐项核实原活动约束解除条件,不因评审员没再提而关闭。新重大缺陷/回归可新增约束,普通建议只留底。第9步统一决定收敛/暂停/再修;无人值守最多一次自动修订。修订差异或必要基线缺失→停止报告状态不一致。

## 第 11 步:夜间接续(TARGET = implementation 且 INTERACTION = unattended,终态收尾已完成)

> 本步先读 `lib/night-delivery.md`,所有Git/写入位置按其隔离交付协议执行。

> **强制终点守卫**:进入本步前重新核对PROGRESS的规范化模式。TARGET=review立即返回,不得建立NIGHT、固化实施spec、拆票、实施、推送、开PR或通知;仅unattended+implementation允许下游。diag无论选何入口都不实施,完整night仅可走第2条诊断短稿分流。

1. **建账/核验**:复用最新评审环ts;新NIGHT写interaction=unattended、target=implementation及night=on,已有NIGHT用run-mode.sh按default规范化且结果必须与PROGRESS一致。review须有review_schema=2及完整D/F记录,NIGHT同记schema;diag短稿不要求D/F。旧NIGHT已有plan产物或impl而缺delivery_schema=1及冻结元数据时停止自动恢复,不重放原分支发布动作。新delivery_schema=1链按night-delivery核验,不能把正常新链当旧链停止。新账勾review,记终态和object;续跑先读账,不得重置票状态。存在waiting时,先只读核验新增证据/用户明确决定并更新D/F及SUMMARY;证据不足保持waiting直接返回。证据充分只解除对应约束,重算票依赖,不直接把paused改complete;若需要改规格/票,保留旧记录并核验已完成票是否仍满足新约束,不得从头覆盖已有实施。
2. **终态分流**:
   - 终态为 `无需修订` / `收敛(*)` / `夜间收工` → 接续(下一条)。
   - 终态为 `推倒重来` / `用户中止` / `完成(diag)` → **不接下游**:NIGHT 记终态与 `note = 未接下游(<原因>)`,写两行晨报短稿 `<cwd>/.xcheck/<ts>/MORNING.md`(终态一句 + "明细在 .xcheck/<ts>/SUMMARY.md"),直接勾 `finish`,推通知(正文"评审判定方向性错误/链被中止,没写代码;晨报 .xcheck/<ts>/MORNING.md")——没写代码、没有分支、主仓无新提交,**跳过收工推送**,夜链结束。推倒重来是人的决定,夜里绝不自动重新设计。
3. **定对象(object)**:沿next/prev核实本链最新已完成审核运行,object只能是该环 `<ts>/proposal.md` 固定快照,与同环decisions.md/FINDINGS.md一起交给to-spec;附录内容从该环记录读取,不靠活动source文件获取。**不扫描最大rev、不回退到活动source**:旧链高编号修订稿或审核中被外改的源文件均不能替代本轮已审对象。快照或关联账本缺失/不一致则暂停接续,不猜对象。
4. **先隔离,再固化spec**:
   - 校验PROGRESS冻结元数据与NIGHT一致;全局受约束/无实施基线先写waiting及晨报返回,不建worktree/发布。`delivery_schema`缺失或未知先停止,不重新取当前HEAD补成启动基线。
   - 先在NIGHT记branch/worktree意图,调用 `night-git.sh prepare <host_repo> <branch> <worktree> <start_oid>`;任何身份/路径/分支冲突停止。若NIGHT已记plan/impl产物,改用verify并带全部complete OID,不能prepare重建后跳票。
   - 全部后续文件写入和实施命令使用绝对worktree路径,不改变原工作区文件。spec/票操作也先verify,原工作区仅写.xcheck账本。
   - 推通知后内联to-spec,不上issue tracker,无需调用外部同名skill。
   - 按其模板写 spec:Problem Statement / Solution(均用户视角)/ User Stories(尽量穷尽,编号列表,"作为<角色>,我想要<功能>,以便<收益>")/ Implementation Decisions(模块/接口/架构/schema/API 契约;不写具体文件路径与代码;原型产出的状态机/schema/类型形状等"决策密集"片段可内联并注明来自原型)/ Testing Decisions(只测外部行为不测实现细节;测哪些模块;仓库既有同类测试先例)/ Out of Scope / Further Notes;术语遵守项目 CONTEXT.md 词汇表与相关 ADR;
   - 输入 = object + decisions.md + FINDINGS.md + 本链必要背景。只把已确认需求/约束、必要修复和验收预期写进规格;一般建议未获明确采纳不新增User Story/任务。活动约束列出受影响行为和解除条件,不能把夜间收工当全面放行。若整个目标都受约束:写waiting与晨报暂停原因,plan/impl/finish均保持未勾,不拆可执行票、不建实施分支、不推送;本次到此返回。
   - 新技术细化不得变相覆盖D中的已确认产品行为/约束;冲突产生待决记录,暂停受影响路径。
   - seam 裁定**自动过**:优先既有最高 seam,确需新 seam 从最高点提案,裁定记 NIGHT(不问用户);
   - 落盘 `<worktree>/docs/superpowers/specs/<YYYYMMDD>-<主题>-spec.md`,通过 `git -C <worktree>` 只提交该文档及必要相关路径,绝不提交原分支。spec整合已审快照及必要D/F约束,不上传原始聊天/机器账。
   完成:NIGHT 头部 `spec` 字段填路径。
5. **拆票(内联 to-tickets 流程)**:仍属 `plan` 阶段 → 主会话**就地**执行 to-tickets 的流程(同样内联;夜链走其本地文件模式):
   - **竖切规则**:每票一条端到端窄竖切(穿过 schema/API/UI/测试各层),完成即可独立验收;粒度≈单个新鲜上下文窗口;预重构(prefactor)排在最前;**宽改动例外**:单一机械改动波及全库的(改列名/改共享符号类型),按 expand(新旧并存)→ 分批 migrate(每批一票,批间保持绿)→ contract(删旧形)排序,不硬切竖片;
   - 每票一文件 `<worktree>/.scratch/<feature-slug>/issues/NN-<slug>.md`(编号从 01 起,阻塞方在前),内容 = **What to build**(该票打通的端到端行为,用户视角,非逐层实现清单)/ **验收标准**(勾选框列表)/ **Blocked by**(所依赖票的编号,或"无,可立即开始");不写具体文件路径与代码(原型决策片段例外,注明来自原型);
   - 自查粒度、验收和真实依赖;每票必须另记 `decision_refs: D编号`、`review_blocks: F编号或无`。活动约束映射到行为/票及依赖方,无法证明独立不能填无。非阻断建议未获采纳不拆票,不能只因评审提到就新增范围。疑点自动记账但不自动改用户决定。
   - 票被gitignore时仅在worktree内做最小放行,先看文件后精确改;用 `git -C <worktree>` 只提交本票目录及该忽略规则。原工作区.gitignore不改。记录文档完整提交OID后按night-delivery尝试publish,失败保留本地成果。
   完成:NIGHT 头部 `tickets` 字段填目录,勾 `plan`(注记"spec + N 票")。
6. **逐票实施(impl,worktree 内)**:推通知("spec 固化 + 拆票完成:N 张票。开始在隔离 worktree 逐票实施,每完成一票自动推远端保存进度。")→:
   - 复用第4条已建worktree;调用night-git.sh verify并带已完成票完整OID。没有匹配worktree/branch或提交不可达就停止恢复,不再以当前HEAD建立新分支。所有子代理brief明确工作目录与只写该worktree边界。
   - **frontier = 自身无活动约束且依赖票全已验证complete**。直接约束票记paused(F编号,解除条件),依赖未完成记blocked(票编号),未知独立性也暂停;不能把停靠/有台账行视为complete。按编号严格串行,没有可执行票就交付暂停原因,不空转。
     a. 记 BASE=当前 HEAD;派 fresh implementer subagent:brief = 票文件全文 + spec 路径 + 前票已定接口与裁定;要求 **TDD**(先写失败测试跑红 → 最小实现跑绿)→ 跑覆盖测试 → commit(一票可多 commit);模型:单文件机械票用便宜档,跨文件/含设计判断票用中档;回报四态(DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / Blocked)。
     b. DONE_WITH_CONCERNS先核疑虑;NEEDS_CONTEXT只补可确认材料;Blocked可在既定范围拆小或换模型,仍缺关键决定/证据则记paused并传播依赖,不把停靠记成完成。
     c. 独立reviewer双轴核Spec验收与代码质量,输入票+BASE..HEAD差异。主会话按具体影响判定阻断,不能仅靠Critical/Important标签;普通建议记账不扩需求。必要修复≤5轮(R1–3原实施者,R4–5更强fresh),每轮只复核发现与修复回归。上限后仍有真实阻断→paused并传播依赖,不是“无下游依赖就停靠当完成”。已证伪/非阻断说明裁定证据。
     d. 票完成:先在NIGHT记complete(完整提交OID、测试与独立评审证据),再按night-delivery调用night-git.sh publish仅推夜链分支;失败仅记发布失败。恢复核验complete提交在当前分支可达、验证记录存在,不能靠有行跳票;paused/blocked仅获解除证据后重新调度。
   - 可执行票处理完→终局全分支review,输入全分支diff+票状态+D/F约束;只对重大问题和回归做一轮修复及一次限定复审,普通建议不自动修。残留阻断记paused并传播依赖,不笼统停靠消失。
   完成:只有全部票complete且终局无活动约束才勾 `impl`;有paused/blocked保持impl未勾,记录等待的解除条件和已完成范围,仍进入收尾交付晨报。
7. **终局收尾(finish)**:
   - **夜链结论**:`全绿`仅全部票验证complete且没有活动约束/终局阻断;`带停靠完成`仅全部票complete、剩余为非阻断参考;有paused/blocked或活动约束→`未完成`(写已完成范围、解除条件;不是盲目建议重跑);spec/拆票失败→`失败收工`。短稿不记四值,写未执行实施及原因。一般建议可以留底,不为取得全绿强迫修复。
   - **收工发布(实现状态与发布状态分开)**:
     a. 先verify全部complete OID及worktree身份;publication_blocked非-则只记未发布及原因,不调用publish/PR。否则 `night-git.sh publish <host_repo> <branch> <worktree> <start_oid> <remote_name|-> <remote_url|->`;无远端记本地完成/未发布,真拒推记未推及原因,不阻止本地成果交付。
     b. **原分支不提交、不推送、不pull/rebase**,不为开PR自动创建/推送base。远端配置与冻结URL不符则停止发布,不猜新的目标。
     c. 分支已推才按night-delivery显式指定冻结仓库/base/head查询并复用或创建PR;GitHub调用night-pr.sh(查询失败不能继续create),tea仅参数和目标均已核实时使用。缺工具/目标不明/base不可用记未建。PR正文给自包含的规格主题、测试/完成范围和暂停原因,不只放本地晨报路径。绝不自动合并或force。
   - **写晨报** `<cwd>/.xcheck/<ts>/MORNING.md`:骨架 = 四问——【评了什么】【改了什么】(评审段修订了几版、消化多少条)【执行了什么】(N 张票逐票状态、分支名、worktree 路径、PR 链接、spec 与票目录、测试结果)【早上要决定什么】(合并/保留/删分支,含建议)——外加文末**「裁定与停靠附录」**(评审段裁定 + to-spec/to-tickets 自动关卡裁定 + 每票修复环停靠 + 终局裁定;"停靠"首次出现带一句解释:**先放一边不修、记在账上,早上裁量**)与 spec/票目录/产物路径;自包含,不翻任何文件就能懂要决定什么。对话收尾的「简报」段(下一条)是它的浓缩投影。
   - **推通知**:title = `【<项目名>】夜链<结论四值>`,正文说明主题、完成/直接暂停/依赖受阻各几票及晨报路径,不能把paused/blocked都叫停靠;有waiting先说解除条件,普通故障才给续跑命令。PR链接仅已创建时附上。
   - **对话终局播报(三段式,固定骨架,机器词照播报纪律翻译)**:
     - **夜链结论**:<四值>一行 + 完成/直接暂停/依赖受阻数量,非阻断参考另列;分支与PR发布结果如实说明,PR给链接。
     - **简报**:≤5 行——评了什么(对象+几家+第几轮)/ 改了什么(修订几版、消化多少条)/ 执行了什么(N 票 TDD、终局评审一句)+ 晨报路径;
     - **推荐下一步**:1–3条具体动作,有paused/blocked先说明要补的证据/用户决定,解除后才续跑;普通崩溃未完成才先推荐 `/xcheck --night`。有活动约束不可推荐直接合并。
   - 若有paused/blocked:写 `waiting = <F/票编号与解除条件>`,保持finish未勾,晨报注明本次已交付但链等待解除。全部票处理完成才勾finish。续跑先核waiting是否有新证据/决策,没有则返回现有暂停说明,不重复实施/发布。合并永远由人决定。

**通知纪律**:三个节点(固化 spec 前 / 逐票实施前 / 收尾)+ 失败变体,由主会话直接 curl 推 Pushover;`PUSHOVER_TOKEN` / `PUSHOVER_USER` 未配置或推送失败 → **跳过不阻塞**(晨报是兜底交付)。**每条通知三件套**:① **title** = `【<项目名>】<一句状态>`——项目名取 origin 仓库名(`git remote get-url origin` 取 basename 去 `.git`;无远端用当前目录名);② 正文一句话人话,不带机器词,也不带分支名/PR 号这类裸 ID(识别靠 title 的项目名 + 正文里的主题 + url 链接);③ 收尾通知 `url` 参数挂 PR 链接(ASCII 可内联;其余节点不带)。**title 与正文的中文一律走 UTF-8 文件,严禁把中文内联进 curl 参数**:先 `printf` 写 `<run目录>/notify-title.txt` 与 `notify.txt`,再 `curl -s -F "token=$PUSHOVER_TOKEN" -F "user=$PUSHOVER_USER" -F "title=<notify-title.txt路径>" -F "message=<notify.txt路径>" -F "url=<PR链接>" https://api.pushover.net/1/messages.json`。原因:Git Bash 调原生 curl.exe 时,命令行参数里的中文经 Windows ANSI(GBK)入口重编码,GBK 字节发到 Pushover 按 UTF-8 解码,整条通知全变问号(2026-09-18 二进制 trace 实证:"夜"上线字节 d2 b9 = GBK);`-F "字段=<文件"` 由 curl 自己读文件字节,线上即 UTF-8(title 与 message 同因同修)。

## 终态收尾(任一终态)

1. review结论性终态:TARGET=implementation只写 `.xcheck/<ts>/review-appendix.md`,不追加原文件;TARGET=review且source为文件才按ts幂等追加原文件文末,原稿正文不改。正文先给活动约束(事实或缺口、具体影响、暂停范围、解除条件),再给已解除问题摘要及精选非阻断参考。明确一般建议不是新增需求,用户先交付不等于解除阻断;不能把所有③都写成“命中整链停”。内容来自FINDINGS与D快照,不另造判断。
2. 附录写失败或仅审核inline无目标文件→说明原因,机器账保留;用户中止/diag不写。终态字段按review-contract解释,不能再按全部属实问题计数。先附录后终态/gate落盘,对话给终态、修订路径、证据及解除条件。
3. TARGET=review到此结束,包括终态标签为夜间收工的--auto-review;标签不授予实施权限。
4. 复审旧环有next且gate已勾是交接环,不是待重跑环;恢复沿next到最新环。旧版语义由schema区分,不重写旧结果。

## PROGRESS.md 格式

```markdown
# PROGRESS · <ts>
mode = review                 # diag | review
interaction = interactive     # interactive | unattended,所有mode必记
target = review               # review | implementation;与interaction共同决定模式
review_schema = 2             # 仅review;缺失为旧协议,未知值禁止执行
selected = codex, kimi        # 冒烟后幸存的最终选集(冒烟前先记候选集)
source = C:/…/xxx.md          # 原方案绝对路径 | inline
round = 0                     # 修订轮次;复审环从 1 起
prev = -                      # 复审链上一环 ts;首轮 -
next = -                      # 已建复审环时填目标ts
migrated_from = -             # 旧review迁移的新首环填来源ts,幂等定位
auto_revisions_used = 0       # 原生首环0;迁移核实已用次数,不明写unknown并禁自动再修
smoke_cfg = <sha256>          # 冒烟通过时 agents.toml 的 sha256 摘要(0.16.0,复审环判"配置未变更"用;未冒烟不记)
night = on                    # 仅target=implementation的兼容标记;auto-review不得写
delivery_schema = 1           # 仅完整night review;下列冻结字段首次摄入写,复审继承
host_repo = <绝对仓库root>
start_oid = <完整提交OID>       # 无HEAD则记-及implementation_blocked原因
source_branch = <启动分支或->
remote_name = <origin或->
remote_url = <唯一push URL或->  # 不得包含凭据;缺失只本地执行
pr_base = <冻结原分支或->
implementation_blocked = -    # 无阻碍为-;否则记录无法隔离实施的原因
publication_blocked = -       # 无阻碍为-;非-只本地执行,所有发布节点跳过
original_source = <原始文件或inline> # 只追溯,night不得向它写入

## 阶段(完成即打勾)
- [x] intake                  # 跳过摄入也算完成
- [x] detect                  # 含选集判定
- [x] smoke
- [x] fanout
- [x] collect
- [x] synthesize
- [x] triage
- [ ] verify
- [ ] experiments
- [ ] deliverable
- [ ] gate                    # 打勾时机:停点已答且(答"不要/按现状收工/确认推倒"链已终态 | 答"要/再修一轮"修订已落盘+复审环已建)

## 终态
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户不修 | 夜间收工 | 用户中止 | 完成(diag))
```

**恢复语义**:终态非空 = 评审段完成(夜链例外:TARGET=implementation且PROGRESS 终态非空但 `<ts>/NIGHT.md` 的 `finish` 未勾 = **夜链未完成**,壳的夜链扫描接管,评审段不重跑、直接按第 11 步续);终态空 + 有未勾阶段 = 未完成,可从第一个未勾阶段续(壳检测、用户确认)。旧版产物(有 run.md 无 PROGRESS.md;或 PROGRESS 终态非空且无 NIGHT.md = 普通链已完成)不算未完成,静默忽略。

## NIGHT.md 格式(夜链专用)

```markdown
# NIGHT · <ts>
night = on
interaction = unattended
target = implementation
review_ts = <ts>               # 评审环 ts(复审链取最新环)
review_schema = 2             # review夜链;diag短稿不写
终态 = 夜间收工                # 评审段终态(七值之一)
delivery_schema = 1
host_repo = <原仓绝对root>
start_oid = <冻结完整OID>
source_branch = <启动分支或->
remote_name = <冻结远端或->
remote_url = <冻结唯一push URL或->
pr_base = <冻结base或->
implementation_blocked = -    # 继承PROGRESS,非-不得开始实施
publication_blocked = -       # 继承PROGRESS,非-不调用publish/PR
branch = xcheck-night-<root-ts>
worktree = <原仓外独立工作树绝对路径>
object = <最新已审环>/proposal.md # 与同环D/F绑定
spec = docs/superpowers/specs/<日期>-<主题>-spec.md   # to-spec 产物;未到填 -
tickets = .scratch/<slug>/issues/   # to-tickets 票目录;未到填 -
impl = <分支名>@<worktree 路径>  # 逐票实施;未到填 -
push = 已推(<夜链分支>) | 无远端 | 未推(<原因>) # 与实施结论分别记录
pr = <PR URL> | 未开(<原因>)      # 收工 PR 结果(0.18.0);未到填 -
note = 未接下游(推倒重来)      # 可选注记
waiting = -                   # 有暂停时填F/票编号、解除条件及证据基线;无新证据不重复运行

## 阶段(完成即打勾)
- [x] review                   # 评审段(含修订复审环)终态落定
- [ ] plan                     # to-spec 固化 + to-tickets 拆票完成
- [ ] impl                     # 逐票实施完(终局评审过)
- [ ] finish                   # 晨报落盘 + 通知 + 夜链结束

## 票级台账(impl 段逐票追加)
票 01: complete(oid=<完整40或64位提交OID>, tests=<实际命令与结果记录路径>, review=<独立评审证据路径>)
票 02: paused(F2,解除条件:补齐删除范围验证)
票 03: blocked(票02)
```

**恢复语义**:finish未勾时按schema及所需产物核验再续。plan未勾先读现有spec/票,不盲目覆盖用户修改。impl只调度无活动约束且依赖全complete的票;complete必须提交可达并有验证记录,paused/blocked保留解除条件,不能以有行即跳过/完成。worktree或分支缺失、提交不可达→停止实施恢复并报告证据缺口,禁止从spec重建后沿旧台账跳票。旧NIGHT有plan产物/impl按契约拒绝自动迁移。有paused/blocked或全局待决则waiting记解除条件,finish保持未勾;再调用先核是否已有新证据,没有则直接返回暂停摘要,不重复发布/通知。

## 边界与异常

| 异常 | 处理 |
|---|---|
| 某家 subagent 超时/失败 | 照落 failed.md,链继续;SUMMARY 头部注明"本轮 <name> 未返回,综合基于其余 N 家" |
| 冒烟后 <2 家 | 停(第 1 步话术),不硬跑单家 |
| 实验失败/超时/环境不满足 | 该条"无定论",不阻塞其他条 |
| 停点处用户打断/不答 | PROGRESS 停在 gate(终态空)→ 下次重敲 /xcheck 弹窗 0 可续(重问) |
| 修订写一半崩 | 旧环 gate 未勾 → 恢复时重问停点;rev 文件已存在 → 提示用户续用或重写 |
| 附录写失败(被评文档只读/被删/路径失效) | 跳过附录、对话注明,不阻塞终态 |
| 全链中途崩 | 已勾阶段成果在盘;重敲 /xcheck → 续跑,不丢盲评结果 |
| 用户对话里要换 agent 集 | 未派发 → 回第 1 步重定;已派发 → 本轮照跑完,下轮用 `--agents` |
| 旧版 .xcheck 产物 | 无 PROGRESS.md → 静默忽略,不算未完成 |
| 夜间解析不出对象(阶梯落"反问"档) | 停链 + 推通知;夜里绝不瞎猜对象 |
| 夜链任何一步失败(spec 固化崩/拆票崩/逐票实施崩/通知崩) | 推通知(停在哪、早上怎么续);NIGHT.md 停在当前阶段,`/xcheck --night` 可续(impl 段按已核验的票状态与依赖调度);通知失败不阻塞,晨报兜底 |
| 每票/收工 push 失败(网络/权限) | 不挂链:NIGHT 记 note,下一票完成连着重推(push 幂等),收工兜底再推一次;到收工仍失败 → 通知与晨报写明"分支未推全" |
| 夜链分支推送被拒或remote URL变更 | 保留本地成果,记发布未完成;不force、不推原分支、不rebase原分支 |
| PR开不成 | 按实际push结果区分已推未建PR/仅本地完成,不谎称分支已推 |
| 早上裸敲 /xcheck(无 --night)遇未完成夜链 | 弹窗 0 的续跑选项注明停于 PROGRESS/NIGHT 阶段;评审段已终态的夜链,确认续跑 = 一并设 NIGHT_MODE = 1;不自动续(人在场,要确认) |

## 铁律(全套,不打折扣)

1. **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合/查证/裁决只在主会话。
2. **进度只认盘**:阶段完成即勾 PROGRESS;恢复不依赖会话记忆。
3. **停点纪律**:链上除壳的续跑确认、第 0 步摄入确认、第 9 步停点一问三处外,全链不问、不停、不等批准(壳的入口一问在链启动前,见 SKILL.md)。
4. 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,**原稿正文永不动**(唯一例外:终态评审附录)。普通审核不自动实施;night仅按第11步在worktree实施,绝不自动合并或把未验证状态说成通过。
5. **至少 1 个非 claude**;同构只标注不拦。
6. 评审/搬运 subagent 用便宜模型、一条消息并行派出;逐票实施按第 11.6 步的档位政策;主会话用强模型做综合。
7. 成败看**退出码**(exitcode 文件),不看输出文本里有没有 "error";codex 的 MCP/banner/hook 噪声 ≠ 失败。
8. 产物全部落盘 `.xcheck/<ts>/`(已 gitignore,不 commit)。
9. **夜链隔离交付**:按night-delivery,共识/修订/附录先写.xcheck,实施spec/票/.gitignore/代码全在night worktree提交。仅可推冻结目标的夜链分支和创建/复用PR,不提交/推送/pull/rebase原分支,不force/merge/建remote。自动细化不覆盖D约束;破坏性/安全敏感/关键冲突暂停相关路径,全局不明停链。通知可选,发布失败保留本地成果,不得自动改会话权限。
