# xcheck 自动链执行流程(mode = diag | review)

主会话(你)执行一条**自动链**:第 0 步(可选摄入)+ 第 1~9 步;停点答"要"才有第 10 步(修订+复审)。壳(xcheck/SKILL.md)已设定:`MODE`(diag | review | auto——auto = 空或含糊输入,由第 0 步解析器落定)、`OVERRIDE_AGENTS`(可选)、`RESUME_TS`(可选 = 恢复模式)。**严格按步骤走,不跳步。**

**进度只认盘(铁律)**:每阶段完成即在 `<cwd>/.xcheck/<ts>/PROGRESS.md` 打勾(格式见文末)。会话崩了/中断,用户重敲 `/xcheck`,壳检测未完成链、经用户确认后续跑——恢复与排障的唯一依据是这个文件,不依赖任何会话记忆。

**停点纪律(铁律)**:全链只有三处开口等用户——① 壳的"续旧的还是开新的"(仅当盘上有未完成链);② 第 0 步对象解析确认(仅当输入空/含糊);③ 第 9 步停点一问。**其余一切(检测/冒烟/派发/汇总/三分类/查证/实验)自动推进,不问、不停、不等批准。**

---

## 恢复模式(RESUME_TS 存在时,最优先)

1. 读 `<cwd>/.xcheck/<RESUME_TS>/PROGRESS.md`;读不到 → 报"PROGRESS.md 不存在,无法续跑",停。
2. 从头部读出 `mode` / `selected` / `source` / `round` / `prev`。
3. **当前 ts = RESUME_TS**(不新建目录)。阶段清单里已勾的跳过;从**第一个未勾阶段**起,按本文对应步骤整段重做。
4. 用户已答的决策**不跨恢复记忆**——停点(gate)未勾,恢复时重新问;摄入(intake)已勾,不再问。
5. 恢复不再弹"续还是新开"(壳已问过)。

## 第 0 步:对象解析(空/含糊输入)或零往返带背景(自包含输入)

- **MODE = auto**(壳没定:输入为空或含糊)→ 按 `~/.claude/skills/xcheck/lib/context-intake.md` 第 0.0 步**对象解析器**执行:解析阶梯(文件型 > 讨论型 > 诊断型 > 反问)从最近对话推断**评审对象 + 模式 + 背景原话**,弹**一个**确认窗打包过目。确认后落定 MODE、落内容文件、建 `<ts>/` 目录与 PROGRESS 头部(`source`:文件型 = 解析出的路径、讨论型 = 固化稿落成的共识文档路径——两者修订都落**对应文档同目录**;诊断型 = `inline`),继续第 1 步。
- **MODE 已定**(自包含输入)→ 直接用 `$ARGUMENTS`。但跳过解析 ≠ 不带背景:仍**零往返静默扫**最近对话,摘直接相关的用户原话落 `context.md`(`lib/context-intake.md` 第 0.6 步),对话里明说一句;没摘到就不建。
- 解析/扫描若已建 `<cwd>/.xcheck/<ts>/` → 后续**复用这个 ts**,不重复建。
- 完成后勾 PROGRESS:`intake`(自包含跳过解析也算完成)。

## 第 1 步:检测 + 定选集 + 初始化 PROGRESS

1. 跑 `bash ~/.claude/skills/xcheck/lib/detect.sh`。stdout = 已装 agent(每行 `name \t installed_check \t installed`);stderr = 已登记未装。**已装 < 2** → 告诉用户太少(异构至少 2 家、≥1 非 claude),建议 `/xcheck-setup`,**停**。
2. **初始化 PROGRESS.md**(摄入没建目录时才建):`<cwd>/.xcheck/<YYYYMMDD-HHMMSS>/`(本地时间),写头部(格式见文末;`selected`/`source` 先留待定,本步与 3.1 步补写)。
3. **定候选集**(一条道,无弹窗):
   - `OVERRIDE_AGENTS` 非空(壳已校验名字)→ 候选 = 它。
   - 否则读 `~/.claude/skills/xcheck/agents.toml` 的 `[defaults].default_agents`:存在且非空 → 候选 = 它;坏名(不在 `[agents.*]`,toml 被手改坏)**防御剔除**后用剩余;剔除后空 → 报错停。
   - 都没有 → **报错停住**:"未设默认集也没敲 --agents。先跑 `/xcheck-setup default <a,b,c>` 设默认集,再 /xcheck。"**不弹多选。**
4. 取 `SELECTED = 候选 ∩ INSTALLED`:缺员 → 用交集,输出注明"默认集里 <缺的名> 当前未装/未登录,本轮用 <交集>";交集 < 2 家 → 停。
5. 同构(全 claude 或 <2 家)→ **不拦**,第 9 步 SUMMARY 顶部标注 "⚠️ 本次为同构,异构价值未体现"。
6. 候选集写进 PROGRESS 的 `selected`(冒烟后更新为幸存者),勾 `detect`。

## 第 2 步:冒烟预检(SELECTED 每家 ≤60s)

1. 备两个固定文件(一轮一次;第二条 printf 的 `<cwd>` 代入实际绝对路径、正斜杠):
```
mkdir -p <cwd>/.xcheck
printf '西瓜47' > <cwd>/.xcheck/smoke.txt
printf '读文件 <cwd>/.xcheck/smoke.txt(绝对路径、正斜杠),原样回复文件里的内容,不要加别的字。\n' > <cwd>/.xcheck/smoke-prompt.txt
```
2. 对 SELECTED 每家,主会话**前台**跑(阻塞 ≤~75s,远在前台 600s 上限内):
```
bash ~/.claude/skills/xcheck/lib/run-agent.sh <name> <cwd>/.xcheck/smoke-prompt.txt --timeout 60
```
3. 判定(产物落 `.xcheck/` 根):`.xcheck/<name>.exitcode` 为 **0** 且 `.xcheck/<name>.raw.stdout` 含 `西瓜47` → 可用(CLI 活性 ✓ + 读文件能力 ✓ + 传参机制 ✓)。**其它**(124 超时;65/66/67 脚本层故障;非零 CLI 码 = 401 欠费/未登录/损坏;exit 0 但没有 `西瓜47` = 非交互读不了文件)→ 剔除,告知用户"<name> 预检失败:<exitcode + run.log/stderr 末行>,本轮跳过",落 `<cwd>/.xcheck/<name>.failed.md`。
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

**source 判定**(写进 PROGRESS):输入是文件路径 → 记其绝对路径;贴文/固化文本 → `inline`。

> 落快照而非直读原文件:原文件可能评审中途被改,快照固定本轮对象、留审计底。
> 为什么拆两层:全文内联进 prompt,arg 模式撞 **Windows 32767 字符命令行上限**;全文 Read 进主会话再 Write 烧双倍 token。拆开后指令层恒 ≤2KB,文件输入不过主会话。

### 3.2 指令层落盘

- **diag** → 读 `~/.claude/skills/xcheck/prompts/diag.md`,`{{INPUT_PATH}}` 替换成 `input.md` 的**绝对路径**;有 `context.md` 就填 `{{CONTEXT_PATH}}`,没有把【上下文】块整块删掉。
- **review** → 读 `~/.claude/skills/xcheck/prompts/review.md`,`{{PROPOSAL_PATH}}` / `{{CONTEXT_PATH}}` 同规则。
- 填的路径一律**绝对路径 + 正斜杠**(`C:/...`),写到 `<cwd>/.xcheck/<ts>/prompt.txt`。

> **固化 proposal 的自代入陷阱**:proposal 正文别写会让被评 agent 自代入的背景(点名 agent、写"异构评审"等触发词),历史上下文用**中性陈述**("本方案曾有一个 X 缺陷,已通过 Y 解决"),否则被评 agent 可能把自己当成"该跑评审流程的人"(实测触发过权限弹窗失败)。

### 3.3 一条消息并发派 |SELECTED| 个 subagent

**在一条消息里**同时开出全部 Agent 工具调用并行跑(不要串行 await)。每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的**全文** + 末尾追加:

```
AGENT_NAME = <name>
PROMPT_FILE = <cwd>/.xcheck/<ts>/prompt.txt   # 绝对路径;正反斜杠皆可,run-agent.sh 自动转正斜杠
RESULT_SHAPE = <diag 结构(根因/证据/置信度/建议) | review 结构(裁决/逐条问题/理由)>
```

- subagent 用**便宜模型**(haiku/sonnet)——它只是搬运工。
- 搬运工第 1 步必须 `run_in_background: true` 后台启动 run-agent.sh,并**在本回合内立即阻塞等待**:前台直等会被 600s 上限掐断、结论永久丢失(2026-08-14 codex 事故);停回合"等通知再来"则搬运永不发生(2026-08-31 实证)。详见 carrier 文档。
- 全部派出后勾 `fanout`。

## 第 4 步:收齐落盘

等所有 subagent 完成(并行跑,等齐)。每个返回两段(`## <name> 原始输出` + `## <name> 结构化结论`)或超时/失败行,逐个拆开落盘 `.xcheck/<ts>/`:

- `<name>.raw.out` —— 原始 CLI 输出(原样,不洗 ANSI、不删 codex 噪声,留底核查)。
- `<name>.summary.md` —— 结构化结论。
- 失败/超时:另写 `<name>.failed.md` 记一行(原因 + 退出码 + stderr 摘要)。

**不要在这一步做综合判断**。完成后勾 `collect`。

## 第 5 步:汇总(主会话)

- **diag** → 读 `~/.claude/skills/xcheck/prompts/synthesize-diag.md`,`{{ALL_CONCLUSIONS}}` 替换成各家 `.summary.md` 内容拼接,按模板输出综合,写 `<cwd>/.xcheck/<ts>/SUMMARY.md`。
- **review** → 读 `~/.claude/skills/xcheck/prompts/synthesize-review.md`(紧凑头版),`{{ALL_REVIEWS}}` 同上,输出**紧凑头**(各家裁决一览一行 + 总判一两句 + 返回/失败/同构标注)写 SUMMARY.md。**共识/分歧长文不再输出**——逐条细节交给第 6 步三分类。

完成后勾 `synthesize`。

## 第 6 步:三分类

1. 读 `<ts>/` 下**所有** `.summary.md`(**只读 summary,不读 raw.out**);只有 failed/无 summary 的家跳过。
2. 每家"问题/建议"逐条拆出、标来源(如 `[codex] 这里用了 localStorage 存 token`);LGTM 家不贡献条目,不强行补条。
3. 读 `~/.claude/skills/xcheck/prompts/triage.md`,`{{ALL_FEEDBACK}}` = 拆条拼接,按模板把每条归三类(兜底:拿不准往更不可信兜,1↔2 归 2、2↔3 归 3、设计不出实验降 3)。
4. 分级结果**追加**写 SUMMARY.md(三个区块,空类留占位;三类全空输出一行"本轮无可分级反馈")。条目重复(两家说本质相同)各自保留、各标来源,不合并。
5. **分支**:
   - **diag 到此为止**:呈现 SUMMARY + 收尾句(第 9 步那句),PROGRESS 终态记 `完成(diag)`,链结束。
   - **review 且 ①+② 均空**:SUMMARY 补一行"无可验证问题,无需修订",终态记 `无需修订`,呈现 + 收尾句,链结束。
   - 否则勾 `triage`,进第 7 步。

## 第 7 步:查证①(自动,只读,不问)

对象:SUMMARY 第一类的**每条**。**你(主会话)逐条查**:只读该条"判据"直指的文件/配置/文档,**不展开探索**;条目 >10 可分批派 subagent(便宜模型,只回传证据原文,你裁决)。每条三值,附一行证据(文件:行号,或引文):

- **✅ 证实**(反馈属实)/ **❌ 证伪**(不成立,写明实际是什么)/ **❓ 查无实据**(判据指向处查不到)。

结果并入 SUMMARY ①区块:每条下追加一行 `判定:✅ 证实 —— 证据:src/foo.ts:42`。第一类为空 → SUMMARY 记"无",直接进第 8 步。完成后勾 `verify`。

## 第 8 步:实验②(自动,沙箱,不问)

对象:SUMMARY 第二类的每条(第 6 步已带【验证目的/方法/预期】)。逐条按其【方法】执行:

- **允许**:写临时验证文件(一律 `<cwd>/.xcheck/<ts>/exp/`,留底不删)+ 跑本地测试 / benchmark / 探测命令;单条**超时 300 秒**(Bash 工具 `timeout: 300000`),到点即判"无定论"。
- **禁止(铁律)**:改业务代码、联网外呼、部署。
- 每条三值:**成立 / 不成立 / 无定论**(执行失败/超时/环境不满足 → 无定论,记原因,**不阻塞其他条**)。

结果并入 SUMMARY ②区块:每条下追加一行 `结果:成立 —— exp/e1-x.js,输出摘要:…`。第二类为空 → SUMMARY 记"无"。完成后勾 `experiments`。

## 第 9 步:交付 + 停点

1. 组装**必改项** = ①✅ 证实 + ②实验成立的条目编号,追加 SUMMARY 末段:
   `## 必改项 = ①✅ + ②成立:#1、#3、#5`(空则写 `无`)。勾 `deliverable`。
2. **呈现 SUMMARY 全文**,并原样输出:

   > **以上是建议,共识 ≠ 正确,最终你拍板。**

3. **停点一问**:
   - 必改项为空 → **不问**,终态 `无需修订`,链结束。
   - 否则 AskUserQuestion(单问):"**要起草修订版并自动复审吗?**"
     - `要 —— 针对必改项写修订版(新文件,原稿不动),自动重跑一轮评审`
     - `不要 —— 到此结束` → 终态 `无需修订`,链结束。

## 第 10 步:修订 + 复审(停点答"要")

1. **主会话亲写**修订版(你持有全量证据:各家反馈 + 查证 + 实验结果,不 fan-out):
   - PROGRESS 的 `source` 是文件路径 → 原文件**同目录**写 `<原名>.rev<m>.md`(m = round + 1)。
   - `source = inline` → 写 `<cwd>/.xcheck/<ts>/proposal.rev<m>.md`。
   - **原稿一律不动**;diff(原稿 vs 修订版)写入对话呈现。原稿被手改过(diff 对不上)→ 提示用户,以**当前文件**为修订基线,rev 序号顺延。
   - 修订版正文遵守 3.1 自代入陷阱纪律(中性陈述,不点名 agent)。
2. **建复审环**:新 `<ts2>/` 目录 + 新 PROGRESS.md(`mode=review`、`prev=<当前ts>`、`round=m`、`source=<rev 文件绝对路径>`、`selected=<旧环 selected ∩ 当前 INSTALLED>`;`OVERRIDE_AGENTS` 若有则直接用它)。当前环勾 `gate`。
3. **自动复审**:当前 ts 切到 `<ts2>`,从第 1 步重跑到第 9 步——detect/冒烟照跑、PROGRESS 照勾(新环从空勾起)。复审环 selected 有 agent 已卸载 → 用交集 + 注明,不弹窗。
4. 新一轮到第 9 步:
   - ①+② 均空 → 终态 `收敛(m 轮修订)`,链结束。
   - 非空且 m < 2 → 同问(停点一问)再一轮。
   - **m = 2 仍非空** → 停,报告"**建议推倒重来**:两轮修订后仍存在 N 个可验证问题,疑方案根基缺陷",终态 `推倒重来`。

## 终态收尾(任一终态)

1. PROGRESS.md `## 终态` 段写终态值:`收敛(N 轮修订)` / `推倒重来` / `无需修订` / `用户中止` / `完成(diag)`。
2. 向用户呈现:终态、修订版路径(若有)、`.xcheck/<ts>/` 产物位置。

## PROGRESS.md 格式

```markdown
# PROGRESS · <ts>
mode = review                 # diag | review
selected = codex, kimi        # 冒烟后幸存的最终选集(冒烟前先记候选集)
source = C:/…/xxx.md          # 原方案绝对路径 | inline
round = 0                     # 修订轮次;复审环从 1 起
prev = -                      # 复审链上一环 ts;首轮 -

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
- [ ] gate                    # 打勾时机:停点已答且(答"不要"链已终态 | 答"要"修订已落盘+复审环已建)

## 终态
(空 | 收敛(N 轮修订) | 推倒重来 | 无需修订 | 用户中止 | 完成(diag))
```

**恢复语义**:终态非空 = 链完成,永不续跑;终态空 + 有未勾阶段 = 未完成,可从第一个未勾阶段续(壳检测、用户确认)。旧版产物(有 run.md 无 PROGRESS.md)不算未完成,静默忽略。

## 边界与异常

| 异常 | 处理 |
|---|---|
| 某家 subagent 超时/失败 | 照落 failed.md,链继续;SUMMARY 头部注明"本轮 <name> 未返回,综合基于其余 N 家" |
| 冒烟后 <2 家 | 停(第 1 步话术),不硬跑单家 |
| 实验失败/超时/环境不满足 | 该条"无定论",不阻塞其他条 |
| 停点处用户打断/不答 | PROGRESS 停在 gate(终态空)→ 下次重敲 /xcheck 弹窗 0 可续(重问) |
| 修订写一半崩 | 旧环 gate 未勾 → 恢复时重问停点;rev 文件已存在 → 提示用户续用或重写 |
| 全链中途崩 | 已勾阶段成果在盘;重敲 /xcheck → 续跑,不丢盲评结果 |
| 用户对话里要换 agent 集 | 未派发 → 回第 1 步重定;已派发 → 本轮照跑完,下轮用 `--agents` |
| 旧版 .xcheck 产物 | 无 PROGRESS.md → 静默忽略,不算未完成 |

## 铁律(全套,不打折扣)

1. **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合/查证/裁决只在主会话。
2. **进度只认盘**:阶段完成即勾 PROGRESS;恢复不依赖会话记忆。
3. **停点纪律**:除壳的续跑确认、第 0 步摄入确认、第 9 步停点一问外,全链不问、不停、不等批准。
4. 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,**原稿永不动**;绝不自动改代码/自动合并/自动"通过"。
5. **至少 1 个非 claude**;同构只标注不拦。
6. subagent 用便宜模型、一条消息并行派出;主会话用强模型做综合。
7. 成败看**退出码**(exitcode 文件),不看输出文本里有没有 "error";codex 的 MCP/banner/hook 噪声 ≠ 失败。
8. 产物全部落盘 `.xcheck/<ts>/`(已 gitignore,不 commit)。
