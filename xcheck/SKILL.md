---
name: xcheck
description: 自动判断 —— 把一段模糊描述路由到并行诊断(/xcheck-diag)或交叉评审(/xcheck-review);判断不了就反问,不瞎猜。手动调用 /xcheck。
disable-model-invocation: true
argument-hint: [--agents a,b,c] <问题描述或方案>
---

# /xcheck — 自动路由

`$ARGUMENTS` 是用户给的一段(可能模糊的)描述。你**先判断**它更像"技术问题"还是"方案评审",再交给 `~/.claude/skills/xcheck/lib/flow.md` 走对应的 mode。**你不重新实现 flow.md 的「第 0 步摄入 + 5 步」,只做分类 + 转派。**

---

### 先抠 --agents(可选,在分类之前)

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本才送去分类;token 非空 → 记 `OVERRIDE_AGENTS = <列表>`,**转派 diag/review 时原样带上**;token 为空 → 当没敲。优先级最高,盖过默认集,不改默认。

## 第 0 步:分类(只这一步是你的活)

扫描 `$ARGUMENTS`(以及刚过去的对话上下文,若有)是否命中下列**强信号**关键词。匹配规则:**子串包含,大小写不敏感**。

**🩺 诊断(diag)强信号** —— 用户在描述一个**已经发生**的坏现象 / 想知道"为什么坏了 / 根因":

- 中文:报错、错误、失败、异常、bug、定位、根因、排查、调查、不工作、不生效、跑不通、卡住、死锁、崩溃、闪退、抛异常、重现、复现、为什么不、怎么不、编译失败、装不上、超时、堆栈
- 英文/代码:error、crash、exception、stack trace、traceback、panic、segfault、fail / fails / failed / failure、hang、deadlock、timeout、ERESOLVE(及类似大写错误码)

**🔎 评审(review)强信号** —— 用户在拿出一个**待决策的方案 / 设计 / 改动**,想知道"这样行不行 / 好不好 / 有没有更好的":

- 中文:评审、方案、设计、评估、改进、重构、行不行、这样写对吗、可行性、取舍、优化方案、代码评审、设计文档、PR、MR
- 英文:review、design、proposal、refactor、trade-off、PR、MR、lgtm、looks good、blocking on、feedback

### 判定(按顺序,逐条 fall through)

1. **只有 diag 命中**(review 一个都没命中)→ 走 **diag**。
2. **只有 review 命中**(diag 一个都没命中)→ 走 **review**。
3. **两边都命中** 或 **两边都没命中** → **走 ambiguous**(第 0.A 步),**不要瞎猜**。

> **Tie-break 原则**:不设"哪边赢"。只要分类不是单边命中,就视为不确定,反问用户。原因:用户输入一旦同时出现"报错"和"方案"(比如"我用了 localStorage 存登录态但报错了,这个方案行不行"),两种意图都合理,模型瞎押一边风险大于多问一句的成本。让用户一句话澄清,远比跑错流程返工划算。

> **指代词例外(不走 ambiguous)**:若输入**命中 review 强信号**、且含指代词(刚才/那个/上面/之前/这个/这/那/this/that/above 等),即使没命中 diag 也**直接走 review** —— 这种组合明确是"评审刚才讨论的方案",不可能是诊断。同理 diag 强信号 + 指代词 → 直接 diag。ambiguous 只留给"review+diag 强信号同时命中"或"两边都无强信号"这两种真不确定的情况。

### 第 0.A 步:ambiguous → AskUserQuestion(不猜)

用 AskUserQuestion 给两个选项(让用户选 + 可补充):

- 标题:"你这是要【诊断一个问题】还是【评审一个方案】?"
- 选项 1:`诊断 —— 我有个报错/异常/不工作的现象,想定位根因`(走 diag)
- 选项 2:`评审 —— 我有个方案/设计/改动,想听异构意见`(走 review)

用户选完(或自由文本补充清楚)后,再按下面对应 mode 转派。**绝不在用户回答前擅自开跑 flow.md。**

---

## 第 1 步:转派给 flow.md(不重新实现)

分类清楚后,**直接交给共享流程**,你别自己造编排:

- **mode=diag** → 按 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步摄入(可选)+ 5 步」执行,本次 mode = diag;外部 prompt 用 `~/.claude/skills/xcheck/prompts/diag.md`(填 `{{USER_INPUT}}` = `$ARGUMENTS`,或第 0 步摄入确认后的事实清单),汇总模板用 `~/.claude/skills/xcheck/prompts/synthesize-diag.md`。
- **mode=review** → 按 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步摄入(可选)+ 5 步」执行,本次 mode = review;外部 prompt 用 `~/.claude/skills/xcheck/prompts/review.md`(若 `$ARGUMENTS` 是文件路径先 Read 出全文;或第 0 步摄入确认后的事实清单),汇总模板用 `~/.claude/skills/xcheck/prompts/synthesize-review.md`。

> 无论 diag 还是 review:若本壳抠到了 `OVERRIDE_AGENTS`,转派 flow.md 时**带上**它(flow.md 第 2 步据此走候选集分支,不再看默认集)。

也就是说,除了你自己的「第 0 步分类」,后面整套都是 flow.md 的逻辑 —— flow.md 会先跑**它自己的第 0 步(摄入,可选)**,再走检测 → 多选 → 并行派 subagent → 收齐落盘 → 主会话汇总。你只是带着确定的 mode 进去执行;若用户输入是"诊断刚才那个"这种指代性输入,flow.md 第 0 步会自动摘对话背景(见 `lib/context-intake.md`)。

---

## 铁律(同 /xcheck-diag、/xcheck-review,不重复打折扣)

- **subagent 只搬运、不评判**(见 `lib/subagent-carrier.md`);综合判断只由主会话做。
- 第 2 步多选时**至少选一个非 claude**(codex / opencode / kimi);全 claude 同构要二次确认并在 SUMMARY 里标注 "⚠️ 本次为同构,异构价值未体现"。
- 派 subagent 用**便宜模型**(haiku 或 sonnet),**一条消息里并行**派出去。
- **opencode / 任何 needs_timeout=true 的 agent 必须加 timeout**(默认读 `agents.toml` 的 `[defaults].timeout_sec`=480,per-agent `timeout_sec` 可覆盖;`/xcheck-setup timeout` 可查改)。
- 成败判定看**退出码**,codex 的 MCP/banner/hook 噪声 ≠ 失败。
- 结果全部落盘到 `<cwd>/.xcheck/<时间戳>/`(prompt.txt、`<agent>.raw.out`、`<agent>.summary.md`、SUMMARY.md);`.xcheck/` 已 gitignore,不要 commit。
- 最后**交用户拍板**,原样输出:"**以上是建议,共识 ≠ 正确,最终你拍板。**" 绝不自动改代码 / 自动合并 / 自动"通过"。
