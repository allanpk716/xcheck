# AGENTS.md — xcheck 维护导览(AI agent 版)

你是来**维护或扩展 xcheck** 的 AI agent(任何 CLI 都适用)。本文是你的地图与约束。术语的权威定义在 [CONTEXT.md](CONTEXT.md);本文与实现文件(`xcheck/lib/flow.md` 等)冲突时,**以实现文件为准,并顺手修本文**。给人类看的使用文档是 [README.md](README.md),本文不重复其内容,只补充"改这个仓库必须知道的事"。

---

## 系统一句话

xcheck 是两枚全局 Claude Code skill:`/xcheck`(单停点全自动评审链)和 `/xcheck-setup`(agent 管理)。它把本机异构 AI agent CLI 组织成盲评审团,对方案(review)或故障(diag)并行盲评,自动完成"三分类 → ①只读查证 → ②沙箱实验",终点用人话交付结论并只问一个问题(要不要修订+复审)。编排大脑是 Markdown 指令(`flow.md`),由主会话的模型执行;agent 执行是机械化的(`run-agent.sh`)。

0.17.0 起支持**夜链**:`/xcheck` 入口一问选"自动推进"(或 `--night` 免问)后,无人值守贯通"评审 → to-spec 固化 → to-tickets 拆票 → 逐票 TDD 实施 + 双轴评审(worktree 内执行)",不 push 不合并,终点 = 本地分支 + 晨报 MORNING.md;自动化优先级最高(下游技能关卡自动裁定)。

## 一次 /xcheck 的完整生命周期(精确版)

```
壳 xcheck/SKILL.md(只做 4 件事)
  1. 抠旗标(--night 布尔 → NIGHT_MODE=1;--agents 单 token 纯逗号串,
     名字不在 agents.toml → 报错停)
  2. 查未完成链(PROGRESS.md ## 终态 为空 = 评审段未完;NIGHT.md finish
     未勾 = 夜链未完;取最大 ts)→ 弹窗 0:续跑/新开;NIGHT_MODE=1 →
     不弹窗自动续(评审段未完走恢复模式;已终态走第 11 步)
     (新链且非 --night → 入口一问:自动推进(设 NIGHT_MODE=1,默认推荐)/正常交互)
  3. 定 MODE:自包含输入走关键词词表(单边命中直通,双边/双空反问一次);
     空/含糊(含指代词)→ MODE = auto
  4. 转派 lib/flow.md

flow.md(主会话执行,严格按步走)
  恢复模式(RESUME_TS 存在时最优先):复用 ts,已勾阶段跳过,
    从第一个未勾阶段整段重做;已答决策不跨恢复记忆(gate 重问,intake 不再问)
  第 0 步  MODE=auto → context-intake.md 对象解析器:
             阶梯 = 文件型 > 讨论型 > 诊断型 > 反问,一个确认窗打包
             (对象+模式+背景原话);讨论型固化稿确认后落
             docs/superpowers/specs/<YYYYMMDD>-<主题>-consensus.md
           MODE 已定(自包含)→ 零往返静默摘背景原话(context-intake 0.6)
  第 1 步  detect.sh 探测;已装 <2 → 停。定选集(一条道,无弹窗):
             OVERRIDE_AGENTS > default_agents(坏名防御剔除)> 报错提示先设默认集;
             SELECTED = 候选 ∩ INSTALLED(缺员降级注明)
  第 2 步  冒烟(0.16.0 起一条消息并发后台跑,wall=max 非 sum;纪律=后台启动+
             回合内阻塞等):每家 run-agent.sh --timeout <smoke_timeout_sec|60>,
             判据 = exitcode 0 且 stdout 含 "西瓜47"(读文件回显);124 超时自动
             原样重跑一次(仅一次,重跑过=慢非死,2026-09-17 四次实证);失败剔除
             并落 <name>.failed.md;幸存 <2 → 停;通过时记 agents.toml 的 sha256
             到 PROGRESS 头部 smoke_cfg(复审环判"配置未变更"凭据)
  第 3 步  备料:内容层(proposal.md/input.md/context.md 落 <ts>/,文件路径
             输入用 cp 快照)+ 指令层(prompt.txt,≤2KB,模板槽位填绝对正斜杠路径);
             一条消息并发派 |SELECTED| 个 subagent(subagent-carrier.md 全文
             + AGENT_NAME/PROMPT_FILE/RESULT_SHAPE 三参数)
  第 4 步  收齐落盘(<name>.raw.out + .summary.md,失败 .failed.md),此步禁止综合;
             判活闸门(0.16.0):exitcode≠0 / spawn 失败 / 产物缺 .summary.md 或
             <name>.raw.out 任一 → failed.md(不枚举码);幸存 <2 → 停(全轮生效)
  第 5 步  汇总(diag→synthesize-diag.md;review→synthesize-review.md 紧凑头:
             各家裁决一行 + 总判三定式 + DISAGREE 计数)→ SUMMARY.md
  第 6 步  三分类(triage.md):①可直接证实 ②可实验验证 ③存疑;①②全流水编号
             #n、保留来源严重度标签;diag 到此终态 完成(diag);
             review 且 ①+② 均空 → 终态 无需修订
  第 7 步  查证①:主会话逐条只读(>10 条可分批派便宜 subagent 回传证据),
             ✅证实 / ❌证伪 / ❓查无实据,各带一行证据
  第 8 步  实验②:沙箱(临时文件只落 <ts>/exp/;禁改业务代码/禁联网/禁部署;
             单条 300s 超时),成立 / 不成立 / 无定论
  第 9 步  交付 + 停点:SUMMARY.md 置顶机械拼装「结论区」(状态行/必改项/
             各家裁决/信号/统计,零新判断);对话 = 结论区的人话渲染;
             必改空 → 不问直接终态;非空 → AskUserQuestion(全链唯一问句,
             中性两选:修订再评 / 带清单进开发)
  第 10 步 停点选"修订再评":主会话亲写修订版(source=路径 → 原文件同目录
             <原名>.rev<m>.md;inline → <ts>/proposal.rev<m>.md;原稿正文不动);
             建复审环(新 ts2 + 新 PROGRESS:round=m、prev=<ts>)自动重跑 1~9;
             m=2 仍必改非空 → 三选停点(再修一轮/按现状收工/确认推倒),
             推倒仅用户确认,不自动判
  终态收尾  先写评审附录(review + 结论性终态 + source 是文件 → 被评文档文末,
             按 ts 幂等重写),再写 PROGRESS 终态
  第 11 步 夜链(NIGHT_MODE=1,终态收尾后):建 NIGHT.md → 终态分流(结论性终态
             接续;推倒/中止/diag 不接下游)→ 定对象(最新 rev > source > proposal)
             → 内联 to-spec 流程固化实施 spec(本地 docs/superpowers/specs/,不上 tracker,
             seam 关卡自动裁定)→ 内联 to-tickets 流程拆票(.scratch/<slug>/issues/,quiz
             自动过,blockers 优先)→ worktree(基于本地 HEAD)逐票实施:每票 fresh
             子代理 TDD + 独立双轴评审(Spec 符合/Standards),修复环≤5,票级台账
             记账 → 终局全分支评审(一轮修复)→ 晨报 MORNING.md + 三节点通知
             (claude-notify,失败不阻塞)+ NIGHT 勾 finish
```

**开口纪律**:交互流程四处等用户 —— 壳的入口一问(仅新链)、壳的续跑确认(仅有未完成链)、第 0 步对象解析确认(仅含糊输入)、第 9 步停点一问。其余一律自动推进。自动模式(`--night` 或入口选"自动推进")下除入口一问外(`--night` 连它也免)一切开口自动过,其后零开口——自动化优先级最高。

## 模块地图

| 文件 | 职责 | 修改注意 |
|---|---|---|
| `xcheck/SKILL.md` | 入口壳:旗标抠取(--night/--agents)、未完成链检查(含夜链)、MODE 词表路由、转派 | 壳不实现链逻辑;词表只在此文件,改词表要同步 README 输入形态描述 |
| `xcheck/agents.toml` | agent 登记表 + `[defaults]`(timeout_sec、default_agents) | **只能 Edit 精确匹配,禁止整文件 Write**(注释是实测注记);`/xcheck-setup` 模式 C/D 也走 Edit |
| `xcheck/lib/flow.md` | 自动链大脑:步骤定义、播报纪律、边界表、铁律 | **步骤编号(0~11)与 PROGRESS 阶段枚举是跨文件协议**(SKILL、carrier、setup、两份 AI 文档都引用);改编号 = 改协议,须全量同步 |
| `xcheck/lib/context-intake.md` | 对象解析阶梯 + 摘录路径(0.1/0.2)+ 零往返背景(0.6) | 解析结果必须过一个确认窗才准 fan-out(错对象 = 整链白跑);摘录铁律 = 用户原话不改写 |
| `xcheck/lib/subagent-carrier.md` | 搬运工指令(7 步) | 后台启动 + **回合内阻塞等待**两条纪律是用事故换来的,别"简化";CLI 噪声剥离表(update 时同步 cli-findings) |
| `xcheck/lib/extractor-carrier.md` | 摘录员指令:按来源筛([用户]/[材料]),不改写不评判 | 输出格式 `## 摘录事实清单` 被 context-intake 0.2 引用 |
| `xcheck/lib/run-agent.sh` | agent 执行 supervisor:预检/构造/取证/监控/三层击杀 | 改它必跑回归测试(见下);exitcode 协议(0/124/65/66/67)是 API,别复用码值;内部节流可用环境变量 `XCHECK_POLL_SEC`/`XCHECK_STALL_SEC` 覆盖 |
| `xcheck/lib/detect.sh` | PATH 探测(`command -v`;stdout=已装,stderr=登记未装) | CRLF 容错解析,勿引入重依赖 |
| `xcheck/prompts/diag.md` `review.md` | 喂给外部 agent 的指令模板 | 槽位 `{{INPUT_PATH}}`/`{{PROPOSAL_PATH}}`/`{{CONTEXT_PATH}}` 由 flow 3.2 填;**开头的防自代入护栏不能删**(实测删了会被评 agent 把自己当成编排者);返回结构字段名被 RESULT_SHAPE/汇总/triage 引用,改名 = 改协议 |
| `xcheck/prompts/synthesize-diag.md` `synthesize-review.md` `triage.md` | 主会话汇总与三分类模板 | review 汇总只出紧凑头(≤6 行);triage 的编号/严重度格式直接决定结论区必改项的引用格式 |
| `xcheck-setup/SKILL.md` | 4 种模式:检测验证 / add / timeout / default | setup 不校验"已装"(运行时 detect 管);homogeneity 只警告不拦 |
| `xcheck/tests/run-agent.test.sh` | supervisor 的 stub 回归(33 断言,零依赖,~15s) | 改 run-agent.sh / toml 解析必须全绿;新行为补断言 |

## 铁律(不变量——改代码、改文档、改 prompt 都不许破)

1. **subagent 只搬运、不评判**:综合/查证/裁决只在主会话(强模型)。
2. **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
3. **开口纪律**:除入口一问、续跑确认、解析确认、停点一问四处外全链不问、不停、不等批准(自动模式下全部自动过)。
4. **实验禁改业务代码/禁联网/禁部署;修订只写新文件,原稿正文永不动**(唯一例外:终态评审附录,按 ts 幂等);绝不自动改代码/合并/"通过"。
5. **至少 1 个非 claude**;同构只标注不拦。
6. **成败只认 exitcode 文件**,不认输出文本;codex 的 banner/MCP/hook 噪声 ≠ 失败。
7. **产物全落 `.xcheck/<ts>/`**(已 gitignore,不 commit);对话说人话、文件留机器账。
8. **搬运工必须后台启动 run-agent.sh 并在回合内阻塞等待**:前台直等 600s 被 harness 掐断、结论永久丢失;停回合等通知则搬运永不发生(两次事故实证)。
9. **夜链安全栏与自动化优先级(--night / 自动推进)**:第 11 步下游执行的一切代码改动只在 worktree;不 push、不开 PR、不合并、不 rebase 主分支、不动主工作区(spec 与票文件在主仓落盘+commit 是唯一例外,含为放行票目录对宿主 .gitignore 的最小修改);下游技能(to-spec/to-tickets/修复环)确认关卡自动裁定记账,唯一停链例外 = 不可逆或破坏性/安全敏感/出 worktree 副作用/全盘皆猜;通知失败不阻塞,晨报兜底;夜间会话须免弹窗权限模式。

## 状态协议

- **PROGRESS.md 阶段枚举**(11 值,顺序固定):`intake, detect, smoke, fanout, collect, synthesize, triage, verify, experiments, deliverable, gate`。`gate` 勾选时机特殊:停点已答且(答"带清单进开发/收工/确认推倒"链已终态 | 答"修订再评/再修一轮"修订已落盘+复审环已建)。
- **终态七值**:`收敛(N 轮修订)` / `推倒重来`(**仅用户在 m=2 三选停点确认**)/ `无需修订`(仅 round 0 且必改项空:①+② 真空,或剩余全被证伪/实验不成立)/ `用户不修`(必改非空,用户选择带三类清单进开发)/ `夜间收工`(夜链自动决策的带清单/按现状收工,用户未在场)/ `用户中止` / `完成(diag)`。
- **夜链账本**:PROGRESS 头部可选字段 `night = on`(夜链才写);NIGHT.md 四阶段 `review/plan/impl/finish`(`plan` = to-spec 固化 + to-tickets 拆票;`impl` = 逐票实施,票级台账逐票记账;`finish` 未勾 = 夜链未完成,不进 PROGRESS 阶段枚举)。
- **SUMMARY.md 结论区五字段**(机械拼装,零新判断):状态行、必改项(①✅+②成立)、各家裁决、信号(三定式)、统计。
- 产物逐文件语义见 [docs/artifacts.md](docs/artifacts.md) —— **改产物格式必须同步该文件**。

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

改 `run-agent.sh`、`detect.sh`、`agents.toml` 解析逻辑 → **必须全绿再交付**。prompt/flow 是指令级内容,没有自动化测试——改动靠 CHANGELOG 记录 + 对应设计稿更新兜底。

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
