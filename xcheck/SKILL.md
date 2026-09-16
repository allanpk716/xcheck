---
name: xcheck
description: 一次触发全自动异构评审 —— 并行盲评本地多个 AI agent、自动查证与实验、终点交付已验证三分类清单,停点一问。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--agents a,b,c] [<问题描述或方案>]
---

# /xcheck — 单停点全自动链入口

`$ARGUMENTS` 可空(裸敲 = 只查未完成链,没有就反问)。你(壳)只做四件事:**抠 --agents → 查未完成链 → 路由 → 转派**。编排大脑是 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步(可选)+ 10 步」,你不重新实现它。

## 1. 抠 --agents(可选)

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本 = 待分类内容。token 非空 → `OVERRIDE_AGENTS = <拆成的名字列表>`;名字不在 agents.toml 的 `[agents.<name>]` → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续。token 为空 → 当没敲。

## 2. 查未完成链(弹窗 0)

扫 `<cwd>/.xcheck/*/PROGRESS.md`:文件存在且其 `## 终态` 段**为空** = 该 ts 未完成。取 ts 字符串最大的一个(多个未完成:取最新,选项文本顺带列出其余)。

- **没有未完成** → 进第 3 件。
- **有** → AskUserQuestion(单选):
  - `续跑 <ts>(停于:<PROGRESS 第一个未勾阶段>)` → 设 `RESUME_TS = <ts>`,**跳过路由与摄入**,直接按第 4 件转派 flow.md 恢复模式。
  - `新开` → 剩余 `$ARGUMENTS` 非空 → 进第 3 件;为空 → 反问"要评审什么/诊断什么?"拿到内容再进第 3 件。

> 旧版产物(run.md、无 PROGRESS.md 的目录)**不算未完成**,静默忽略。

## 3. 路由(diag | review)

扫描剩余 `$ARGUMENTS`(及最近对话,若有)是否命中强信号关键词。**子串包含、大小写不敏感。**

**🩺 diag 强信号**(已发生的坏现象 / 根因):
- 中文:报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈
- 英文:error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE(及类似大写错误码)

**🔎 review 强信号**(待决策的方案 / 设计 / 改动):
- 中文:评审、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、PR、MR
- 英文:review、design、proposal、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback

**判定**(按顺序):
1. 只有 diag 命中 → **diag**;只有 review 命中 → **review**。
2. 双边命中或双边都无 → **AskUserQuestion 反问,不瞎猜**:选项 `诊断 —— 我有个报错/异常/不工作的现象,想定位根因` / `评审 —— 我有个方案/设计/改动,想听异构意见`。
3. **指代词例外**:单边强信号 + 指代词(刚才/那个/上面/之前/这个/这/那/this/that/above)→ 直接走该边("评审刚才的方案"不可能是诊断)。

## 4. 转派 flow.md

设 `MODE = diag | review`,连同 `OVERRIDE_AGENTS`(若有)、`RESUME_TS`(若有,仅第 2 件续跑时),按 `~/.claude/skills/xcheck/lib/flow.md` 执行。diag 用 `prompts/diag.md` + `prompts/synthesize-diag.md`;review 用 `prompts/review.md` + `prompts/synthesize-review.md`。

## 铁律(全套,不打折扣)

- **subagent 只搬运、不评判**(`lib/subagent-carrier.md`);综合只在主会话。
- **进度只认盘**:阶段完成即勾 PROGRESS.md;恢复不依赖会话记忆。
- 全链只在三处开口:第 2 件续跑确认、flow 第 0 步摄入确认(仅不自包含输入)、flow 第 9 步停点一问;**其余一律自动推进**。
- 实验**禁改业务代码、禁联网、禁部署**;修订只写新文件,原稿不动。
- **至少一个非 claude**;全 claude 只标注不拦。
- 派 subagent 用便宜模型,一条消息并行;成败看退出码,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 产物落 `.xcheck/<ts>/`(已 gitignore);终态收尾原样输出"**以上是建议,共识 ≠ 正确,最终你拍板。**"
