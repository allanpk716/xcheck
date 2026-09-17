---
name: xcheck
description: 一次触发全自动异构评审 —— 并行盲评本地多个 AI agent、自动查证与实验、终点交付已验证三分类清单,停点一问。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--night] [--agents a,b,c] [<问题描述或方案>]
---

# /xcheck — 单停点全自动链入口

`$ARGUMENTS` 可空(裸敲 = 只查未完成链,没有就反问)。你(壳)只做四件事:**抠旗标(--night / --agents)→ 查未完成链 → 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(可选)+ 11 步」(第 11 步 = 夜链专属),你不重新实现它。

## 1. 抠旗标(--night / --agents,可选)

若 `$ARGUMENTS` 含独立 token `--night`(布尔,无值):把它从 `$ARGUMENTS` 删除,设 `NIGHT_MODE = 1`(夜链:整链无人值守,第 0 步确认与第 9 步停点自动拍板,评审终态后接 flow 第 11 步"写计划 → 子代理执行";细节全在 flow.md)。可与 `--agents` 并用,顺序不限。**夜链操作前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条 Bash 权限弹窗能挂整夜。

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。token 非空 → `OVERRIDE_AGENTS = <拆成的名字列表>`;名字不在 agents.toml 的 `[agents.<name>]` → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续。token 为空 → 当没敲。

## 2. 查未完成链(弹窗 0)

扫 `<cwd>/.xcheck/*/PROGRESS.md`:文件存在且其 `## 终态` 段**为空** = 该 ts 评审段未完成;再扫 `<cwd>/.xcheck/*/NIGHT.md`:文件存在且其 `## 阶段` 里 `finish` **未勾** = 该 ts 夜链未完成。取 ts 字符串最大的一个(多个未完成:取最新,选项文本顺带列出其余)。

- **都没有** → 进第 3 件。
- **有且 `NIGHT_MODE = 1`** → **不弹窗,自动续**最新未完成链:评审段未完成 → 设 `RESUME_TS = <ts>`,跳过路由与摄入,按第 4 件转派 flow.md 恢复模式;评审段已终态而夜链未完 → 直接按第 4 件转派 flow.md 第 11 步续(NIGHT.md 定位从哪个阶段续)。
- **有且无 NIGHT_MODE** → AskUserQuestion(单选):
  - `续跑 <ts>(停于:<PROGRESS 第一个未勾阶段 / NIGHT 第一个未勾阶段>)` → 评审段未完:**设 `RESUME_TS = <ts>`**,**跳过路由与摄入**,按第 4 件转派 flow.md 恢复模式;评审段已终态(夜链续跑):**不设 RESUME_TS,一并设 `NIGHT_MODE = 1`**——弹窗确认即为人工签字,按第 4 件转派 flow 第 11 步。
  - `新开` → 进第 3 件(输入为空也没关系,第 3 件会转解析器从上下文推断)。

> 旧版产物(run.md、无 PROGRESS.md 的目录)**不算未完成**,静默忽略。

## 3. 定 MODE(自包含走词表;空/含糊走解析器)

先判剩余 `$ARGUMENTS` 是否**自包含**:文件路径 / 完整报错栈 / 设计文档全文 / 大段代码 / 明显足够长的完整描述。

**A. 自包含** → 关键词路由定 MODE(**子串包含、大小写不敏感**):

- **🩺 diag 强信号**(已发生的坏现象 / 根因):中文(报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈);英文(error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE 及类似大写错误码)
- **🔎 review 强信号**(待决策的方案 / 设计 / 改动):中文(评审、审核、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、spec、plan、看看、过一遍、检查、PR、MR);英文(review、design、proposal、spec、plan、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback)
- 判定:单边命中直通;双边命中或双空 → AskUserQuestion 反问一次,不瞎猜。

**B. 空或含糊**(为空、超短、或含指代词:刚才/那个/上面/之前/这个/这/那/this/that/above)→ **不定 MODE**:设 `MODE = auto` 直接进第 4 件转派——flow.md 第 0 步的**对象解析器**会从最近对话推断评审对象、模式与背景,一个确认窗打包过目(见 `lib/context-intake.md` 第 0.0 步)。

## 4. 转派 flow.md

设 `MODE = diag | review | auto`(auto = 空或含糊输入,由 flow 第 0 步解析器落定),连同 `OVERRIDE_AGENTS`(若有)、`RESUME_TS`(若有,仅第 2 件续跑时)、`NIGHT_MODE`(若有,= 1 时 flow 按夜链规则跑),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。diag 用 `prompts/diag.md` + `prompts/synthesize-diag.md`;review 用 `prompts/review.md` + `prompts/synthesize-review.md`。

## 铁律(全套,不打折扣)

- **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合只在主会话。
- **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步对象解析确认(仅空/含糊输入)、flow 第 9 步停点一问;**其余一律自动推进**。night 模式(`--night`)下三处开口全部自动过(壳自动续链、解析自动采纳、停点自动拍板),整链零开口。
- 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,原稿正文不动(唯一例外:review 终态在被评文档文末追加评审附录)。
- **至少一个非 claude**;全 claude 只标注不拦。
- 派 subagent 用便宜模型,一条消息并行;成败看退出码,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 产物落 `.xcheck/<ts>/`(已 gitignore);对话说人话、文件留机器账(机器词只进 SUMMARY.md,进对话必须翻译);终点=把三类清单(查实的/可实验的/存疑的)分好、附在被评文档后交下游,**不是把方案修到完美**——带着清单进开发是一等公民出口;交付按「发现了什么/改了什么/还剩什么/要决定什么」四问结构说全且自包含,不让用户翻文件才能懂;终态收尾原样输出"**以上是建议,共识 ≠ 正确,最终你拍板。**"
