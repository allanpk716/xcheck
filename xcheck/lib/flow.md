# xcheck 共享执行流程(mode = diag | review)

主会话(你)按这 5 步执行。`$ARGUMENTS` 是用户输入的内容。mode 由调用你的入口 skill 指定(diag / review)。**这一份流程是 /xcheck-diag、/xcheck-review、/xcheck 共用的编排大脑 —— 严格按步骤走,不跳步。**

---

## 第 1 步:自动检测可用 agent

跑:
```
bash ~/.claude/skills/xcheck/lib/detect.sh
```
- stdout = 已安装可选的 agent(每行 `name \t installed_check \t installed`)。stderr = 已登记但未装的(每行 `... \t missing`)。
- 数 stdout 里的 agent 数。
  - **若已装 < 2 个**:告诉用户装的太少(异构至少要 2 个、且至少 1 个非 claude),建议先 `/xcheck-setup` 核实,然后**停**,不继续。不要硬跑单 agent。

## 第 2 步:让用户多选(AskUserQuestion,multiSelect: true)

把已装的 agent 列成 AskUserQuestion 的选项让用户挑(multiSelect: true)。**问题文本里必须原样包含这句提醒**:

> ⚠️ 至少选一个非 claude(如 codex / opencode),否则全是 Claude 同构,等于自己审自己。

- **若用户选的全是 claude 系**:再用 AskUserQuestion 确认一次 "确定只要 claude 同构吗?(不推荐)",仍坚持就继续,但在最终 SUMMARY 与汇报里**显著标注** "⚠️ 本次为同构诊断/评审,异构价值未体现"。
- **若选的 ≥ 2 个且至少 1 个非 claude**:正常进行。
- 记 `SELECTED` = 选中的 agent 名列表(小写,与 agents.toml 的 key 一致)。

## 第 3 步:准备 prompt + 并行派 subagent

### 3.1 套 prompt 模板

- **mode=diag** → 读 `~/.claude/skills/xcheck/prompts/diag.md`,把 `{{USER_INPUT}}` 替换成 `$ARGUMENTS`(若用户在对话里另外给了上下文/复现,替换 `{{CONTEXT}}`;没给就把整行 `{{CONTEXT}}` 那行删掉)。
- **mode=review** → 读 `~/.claude/skills/xcheck/prompts/review.md`,把 `{{PROPOSAL}}` 替换成 `$ARGUMENTS`(若 `$ARGUMENTS` 是文件路径,先 Read 出全文再填)。

### 3.2 落盘 prompt(当前 cwd)

生成时间戳目录 `.xcheck/<YYYYMMDD-HHMMSS>/`(本地时间,例 `20260809-143012`)。把上一步填好的最终 prompt 写到:
```
<cwd>/.xcheck/<ts>/prompt.txt   # 用绝对路径
```
(`.xcheck/` 已在 .gitignore 里,不会污染仓库。)

### 3.3 读 agents.toml 拿每个 agent 的参数

读 `~/.claude/skills/xcheck/agents.toml`,对 SELECTED 里每个 agent 取出:
- `run_cmd`(如 `codex exec -`、`opencode run`、`claude -p`)—— **不含 prompt**;
- `input_mode`(`arg` 或 `stdin`);
- `needs_timeout` / `timeout_sec`(默认 480)。

### 3.4 一条消息里并发派 |SELECTED| 个 subagent(关键)

**在一条消息里** 同时开出 |SELECTED| 个 Agent 工具调用,让它们**并行**跑(不要串行 await)。参考 superpowers 的 `dispatching-parallel-agents`。

每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的**全文**,并在末尾追加该 agent 的填好参数:

```
AGENT_NAME = <name>
CLI_CMD = <run_cmd>
INPUT_MODE = <arg | stdin>
PROMPT_FILE = <cwd>/.xcheck/<ts>/prompt.txt
TIMEOUT = <timeout_sec 或 480>
RESULT_SHAPE = <diag 结构 | review 结构>   # 由本 skill 的 mode 决定
```

- **subagent 模型用便宜档(haiku 或 sonnet)** —— 它只是搬运工,不需要重模型。
- RESULT_SHAPE:
  - diag 模式 → `diag 结构(根因/证据/置信度/建议)`
  - review 模式 → `review 结构(裁决/逐条问题/理由)`

## 第 4 步:收齐 + 落盘

等所有 subagent 完成(它们并行跑,你等齐)。每个返回两段(`## <name> 原始输出` + `## <name> 结构化结论`),或超时/失败那一行。

对每个 agent,把内容拆开落盘到 `.xcheck/<ts>/`:

- `<name>.raw.out` —— 该 agent 的**原始 CLI 输出**(从 subagent 回复的"原始输出"段抠出来,原样写,不洗 ANSI、不删 codex 噪声 —— 留底供事后核查)。
- `<name>.summary.md` —— 该 agent 的**结构化结论**(摘录段)。
- 失败/超时的 agent:除了上面的 raw.out(若有部分输出),再写一份 `<name>.failed.md` 记一行:超时/失败 + 退出码 + stderr 摘要。

**不要** 在这一步做综合判断。综合在第 5 步。

## 第 5 步:主会话汇总(你做综合判断)

把所有 subagent 带回的**结构化结论**拼起来(`.xcheck/<ts>/<name>.summary.md` 的内容,逐个 agent 一段),填进汇总指令模板:

- **mode=diag** → 读 `~/.claude/skills/xcheck/prompts/synthesize-diag.md`,把 `{{ALL_CONCLUSIONS}}` 替换成拼接好的各家结论。
- **mode=review** → 读 `~/.claude/skills/xcheck/prompts/synthesize-review.md`,把 `{{ALL_REVIEWS}}` 替换成拼接好的各家评审。

然后**你(主会话)**按该模板输出综合:共识 / 分歧 / 存疑(或各家裁决)+ 综合建议。写到:
```
<cwd>/.xcheck/<ts>/SUMMARY.md
```

最后,把 SUMMARY 内容**呈现给用户**,并**明确收尾**这句(原样输出):

> **以上是建议,共识 ≠ 正确,最终你拍板。**

**铁律**:绝不自动改代码 / 自动合并 / 自动"通过"。xcheck 只提供异构第二意见,**决策权在用户**。

---

## 边界与异常处理

- **subagent 报超时/失败**:照样落 `.failed.md`,继续对其它 agent 做综合(不要因为一个挂了就整体崩)。在 SUMMARY 里注明 "本轮 <agent> 未返回/失败,以下综合基于其余 N 家"。
- **全 claude 同构**(用户坚持):照常跑,但 SUMMARY 顶部必须显著标注 "⚠️ 本次为同构,异构价值未体现"。
- **用户在对话里改主意**(想加/换 agent):回到第 2 步重选,然后第 3 步重新派。
- **`.xcheck/` 不要 commit** —— 已 gitignore。源文件只有仓库里的 skill 文件本身。
