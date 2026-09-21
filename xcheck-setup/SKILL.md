---
name: xcheck-setup
description: 查看/维护 xcheck 的评审 agent 配置——登记新 CLI、默认评审组、超时、夜链并发帽。只配置,不检测不验证(可用性由运行时冒烟与用户外部操作保障,ADR 0010)。手动调用 /xcheck-setup。
disable-model-invocation: true
argument-hint: [add <name> | timeout [N | <agent> N] | default [<n1>,<n2>,... | --clear] | lanes [N]]
---

# /xcheck-setup — xcheck 的评审 agent 配置器(只配置,不验证)

args = "$ARGUMENTS"。

**职责边界(0.25,ADR 0010)**:本命令只管"用哪些评审 agent 上场"——登记、默认组、超时、并发帽。**不检查可用性**:CLI 装没装、key 配没配、端点通不通,是用户自己的外部事务;运行时 `/xcheck` 第 2 步冒烟是唯一活性权威。因此这里**没有探测、没有试跑、没有 marker 验证**——想知道各家活没活,真跑一轮 `/xcheck 评审 <小文件>` 看冒烟汇报。

**两层配置(0.25,ADR 0010)**:

- **模板层** `~/.claude/skills/xcheck/agents.toml`(= 仓库文件,随 xcheck 分发/升级):五家已知 agent 的契约字段、坑注记与 key/端点配置速览 + `[defaults]` 出厂值(默认组 codex+pi+kimi)。**只许 Edit 精确匹配,禁止整文件 Write**(注释是事故实测注记)。
- **个人层** `~/.claude/xcheck/personal.toml`(仓库外,升级/分发不碰):你的个人覆盖与新 CLI 登记。**本命令的一切"写"都落个人层**;手改也可以。同名字段个人层覆盖模板;无个人层 = 纯出厂配置,开箱即用。

## 模式 A:无参数 → 只读状态一览

读两层配置(个人层缺席就只读模板),**零命令执行、零探测**:

1. **登记表**:每个 agent 一行——名字 / run_cmd / input_mode / timeout_sec / smoke_timeout_sec(有才列),标注来源(模板 / 个人层 / 个人层覆盖模板)。
2. **默认评审组**:两层合并后的生效值 + 来自哪层;名字不在两层任一 `[agents.*]` → ⚠️ 标坏名(运行时会防御剔除),列出坏名。
3. **全局参数**:timeout_sec / night_parallel_lanes / night_retry_max 的生效值 + 来源层。
4. 一句提醒:至少 1 个非 claude 才有异构价值;想实测各家活没活,真跑 `/xcheck 评审 <小文件>` 看冒烟结果。

## 模式 B:`add <name>` → 登记新 CLI(未知家)

名字已在两层任一 `[agents.<name>]`(模板五家 claude/codex/opencode/pi/kimi 是内置的)→ 告知已登记,不重复;要让它上场用模式 D 加进默认组。

登记模板没有的新 CLI(如 gemini-cli):

1. 确认它装了:`command -v <name>`。没装 → 停下告诉用户(装 CLI 是用户外部事务,本命令不代装)。
2. 跑 `<name> --help` **核实**它的非交互命令长啥样(别凭记忆)—— 找出非交互子命令(如 `run` / `exec` / `-p` / `--print`)和 prompt 是走 argv 还是从 stdin 读。
3. 引导用户确认五字段(同 agents.toml 契约):
   - `installed_check` —— 一般就是 `<name>` 本身(或绝对路径)
   - `run_cmd` —— 不含 prompt 的命令前缀(如 `gemini -p` / `qwen exec -`),**按空格分词、token 不得含空格**
   - `input_mode` —— `arg`(prompt 作为单个 argv)或 `stdin`(prompt 管道喂入)
   - `needs_timeout` —— 历史上会卡输入的 CLI 写 `true`(参考 opencode)
   - `timeout_sec` —— 显式填(缺省落 `[defaults].timeout_sec`;登记后也可用模式 C 改)
4. 写入**个人层** `~/.claude/xcheck/personal.toml`:文件不存在就先建,首行注释 `# xcheck 个人层:同名字段覆盖模板 agents.toml;新 CLI 登记也写这里。本文件可手改。`;已有文件则把 `[agents.<name>]` 块**追加**到文末(同名块已存在就 Edit 精确替换该块内字段),**不碰其他块**。
5. 登记完成即结束(**不试跑**)。提示:真跑一轮 `/xcheck` 冒烟自验;该 CLI 噪声形态有新花样的话,补进 `docs/cli-findings.md` 与 `lib/subagent-carrier.md` 的噪声剥离表。

## 模式 C:`timeout [...]` → 查看 / 设置 agent 最大执行秒数

xcheck 调用 agent 时给的执行时限。**只影响 xcheck,不影响 agent 自己单独跑。** 优先级: per-agent `timeout_sec` > `[defaults].timeout_sec`(出厂 2700);**同名时个人层覆盖模板**。

3 种调用:

- **`/xcheck-setup timeout`**(无参)→ 读两层,打印合并生效值:`[defaults].timeout_sec` + 每个 agent 的 `timeout_sec`(标注来源层),表格呈现。
- **`/xcheck-setup timeout <N>`**(一个整数)→ 把**个人层** `[defaults].timeout_sec` 设为 N(影响所有"两层都没有 per-agent 显式值"的 agent)。改前给一句确认提示(N<60 或 N>3600 时警告"异常区间,确认?")。
- **`/xcheck-setup timeout <agent> <N>`**(agent 名 + 整数)→ 把**个人层** `[agents.<agent>].timeout_sec` 设为 N(per-agent 覆盖,优先于两层 defaults)。agent 名必须在两层登记表里,否则报错并列出可用 agent。

执行(主会话):

1. 读个人层 `~/.claude/xcheck/personal.toml`(不存在视为空)。
2. 目标键已有值行 → **Edit 精确替换**该行;没有 → 追加(文件不存在先建,带模式 B 的头注释;per-agent 键追加进对应 `[agents.<name>]` 块,块不存在就新建块)。**模板层永不动**。
3. 改完回显合并生效值(同无参视图),提示"下次 /xcheck 即生效"。
4. N 必须是正整数;非整数报错不改。

## 模式 D:`default [...]` → 查看 / 设置 / 清空默认评审组

设了默认组之后,`/xcheck` **直接拿这组跑**;两层都没有 → `/xcheck` **报错停住**。优先级:`--agents` 临时参数 > `default_agents`(个人层同名键覆盖模板出厂组 codex+pi+kimi)。详见 `~/.claude/skills/xcheck/lib/flow.md` 第 1 步。

3 种调用:

- **`/xcheck-setup default`**(无参)→ 读两层,呈现合并生效的默认组 + 来源层(个人层覆盖时两值都列)。
- **`/xcheck-setup default <n1>,<n2>,...`**(逗号分隔的名字)→ 设置默认组(写个人层 `[defaults].default_agents`)。空格忽略;同名去重、保序(首次出现为准)。
- **`/xcheck-setup default --clear`** → 删掉**个人层**的 `default_agents` 行(回落模板出厂组;不是清空成未设)。提示"已回落出厂组 codex+pi+kimi"。

执行(主会话):

1. 读两层登记表。
2. **名字合法性**:每个名字必须存在于两层任一 `[agents.<name>]` 块。任一不存在 → 报错、列出两层全部合法 agent 名、**不改文件**。
3. **异构校验(警告但允许)**:若设的组同构(全 claude,或 < 2 个,或无非 claude)→ 打印警告"⚠️ 默认组为同构/单 agent,异构价值未体现,仍照设",**不拦**,继续写。
4. 写**个人层**(同模式 C 做法:有值行 Edit 精确替换,无则追加;数组按 toml 语法双引号+逗号)。**模板层永不动**。
5. **改完回显**合并生效组,提示"下次 /xcheck 即生效;本轮已派发的评审不追改"。
6. **不校验"已装"**:组里的 agent 当前装没装,由运行时 flow.md 第 1 步 detect 判定(缺员自动降级用交集)。setup 只保证名字在两层登记表里合法。

## 模式 E:`lanes [...]` → 查看 / 设置夜链并发帽

夜链并行实施的最大并发位:**实施泳道 + 票级评审**合计的同时在跑上限(ADR 0008;冒烟与评审段 fan-out 不在此帽,后者并发=选集家数已有自然控制)。模板出厂默认 3。单晚临时改用旗标 `/xcheck --night --lanes N`,**优先级 `--lanes > night_parallel_lanes`**(个人层同名键覆盖模板)。

2 种调用:

- **`/xcheck-setup lanes`**(无参)→ 读两层,呈现合并生效值 + 来源层 + 一句语义说明(罩实施+票级评审)+ 优先级提示。
- **`/xcheck-setup lanes <N>`**(一个整数)→ 把**个人层** `[defaults].night_parallel_lanes` 设为 N。N 非整数或 <1 → **报错不改**。**N ≥ 5 → 警告不拦**(2026-09-19 十个并行子代理触发 429 集体阵亡的前科提示;上游独立或时段空闲时用户确认后照设),复刻模式 C 的"异常区间确认"交互。

执行(主会话):

1. 读个人层 `~/.claude/xcheck/personal.toml`(不存在视为空)。
2. 目标键已有值行 → **Edit 精确替换**;没有 → 追加/建文件(同模式 C 做法)。**模板层永不动**。
3. 改完回显合并生效值,提示"下次 /xcheck --night 即生效;单晚临时改用 `--lanes` 旗标,不必动配置"。
