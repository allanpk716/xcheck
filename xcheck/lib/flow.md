# xcheck 共享执行流程(mode = diag | review)

主会话(你)按**第 0 步(可选摄入)+ 5 步**执行。`$ARGUMENTS` 是用户输入的内容。mode 由调用你的入口 skill 指定(diag / review)。**这一份流程是 /xcheck-diag、/xcheck-review、/xcheck 共用的编排大脑 —— 严格按步骤走,不跳步。**

---

## 第 0 步:上下文摄入(可选)

当 `$ARGUMENTS` 是指代性 / 简短输入(如"诊断刚才那个")、**不自包含**时,先按 `~/.claude/skills/xcheck/lib/context-intake.md` 执行摄入:切最近对话 → 派摘录 subagent(haiku)摘客观事实 → 用户逐条确认 → 用确认后的事实清单作为 `{{USER_INPUT}}`(diag)/ `{{PROPOSAL}}`(review)。

- **自包含输入**(完整报错栈 / 设计文档 / 文件路径)→ **跳过**摄入,直接用 `$ARGUMENTS`,进第 1 步。
- 摄入若运行,已创建 `<cwd>/.xcheck/<ts>/` 目录 → **第 3.2 步复用这个 `<ts>`,不要重复建**。
- 触发判定 / 摘录 subagent / 逐条确认 / 退回反问 / 填槽的细节全在 `lib/context-intake.md`。

---

## 第 1 步:自动检测可用 agent

跑:
```
bash ~/.claude/skills/xcheck/lib/detect.sh
```
- stdout = 已安装可选的 agent(每行 `name \t installed_check \t installed`)。stderr = 已登记但未装的(每行 `... \t missing`)。
- 数 stdout 里的 agent 数。
  - **若已装 < 2 个**:告诉用户装的太少(异构至少要 2 个、且至少 1 个非 claude),建议先 `/xcheck-setup` 核实,然后**停**,不继续。不要硬跑单 agent。
- **记 `INSTALLED`** = stdout 里所有已装 agent 的名字列表(小写,与 agents.toml key 一致),供第 2 步取交集用。

## 第 2 步:定 SELECTED(默认集 / --agents / 多选 三分支)

先定**候选集 CANDIDATES**(优先级从高到低):

1. 若壳传来了 `OVERRIDE_AGENTS`(用户敲了 `--agents a,b,c` 且 token 非空)→ `CANDIDATES = OVERRIDE_AGENTS`。
2. 否则读 `~/.claude/skills/xcheck/agents.toml` 的 `[defaults].default_agents`:字段存在且非空 → `CANDIDATES = default_agents`。
3. 两者都没有 → `CANDIDATES = null`(走分支 A)。

**坏名处理(定 CANDIDATES 时)**:

- CANDIDATES 来自 `OVERRIDE_AGENTS` 且**有名字不在 agents.toml 的 `[agents.<name>]`** → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续(用户显式指令,笔误立即停)。
- CANDIDATES 来自 `default_agents` 且有坏名(toml 被手改坏)→ **防御性剔除**该名,继续(不崩)。
- **CANDIDATES 剔除后变空**(默认集整组都被改坏)→ 视同 `null`,走分支 A(全量多选),别让流程带空集进第 3 步。

然后取交集 `INTER = CANDIDATES ∩ INSTALLED`,按分支走:

- **分支 A · CANDIDATES 为 null**(未设默认、也没 --agents):沿用旧行为。把 INSTALLED 列成 `AskUserQuestion(multiSelect: true)` 让用户挑,问题文本必须原样包含:

  > ⚠️ 至少选一个非 claude(如 codex / opencode / kimi),否则全是 Claude 同构,等于自己审自己。

  选完全是 claude 系 → 再用 AskUserQuestion 确认一次 "确定只要 claude 同构吗?(不推荐)",仍坚持就继续。`SELECTED` = 选中的(小写)。

- **分支 B · CANDIDATES 非空且 CANDIDATES ⊆ INSTALLED**(全装了):**跳过弹窗**,直接 `SELECTED = CANDIDATES`。

- **分支 C · CANDIDATES 非空但有缺失(CANDIDATES ⊄ INSTALLED)**:
  - 若 `INTER` 为空(候选集整组都没装)→ 直接走分支 A(别弹个只剩"重新选"的空壳)。
  - 否则弹 `AskUserQuestion`(**单选**,非 multiSelect),两选项:
    - 选项 1:`用剩余默认集跑(<列出 INTER 里的名字>)` → `SELECTED = INTER`
    - 选项 2:`重新选(弹多选)` → 走分支 A 的完整多选(列所有 INSTALLED,可勾候选集之外的)
  - 弹窗文本写清"候选集里有 X 家当前未装/未登录:<CANDIDATES − INSTALLED>"。

**异构校验(SELECTED 定下之后)**:

- 分支 B、分支 C 选 1:若 `SELECTED` 同构(全 claude 或 < 2 个)→ **不拦**,但在第 5 步 SUMMARY 顶部记标注 "⚠️ 本次为同构诊断/评审,异构价值未体现"。
- 分支 A:维持上面"全 claude 二次确认"的旧逻辑。
- `--agents` 同构:同分支 B,只标注不拦。

记 `SELECTED` = 最终选中的 agent 名列表(小写,与 agents.toml key 一致)。进第 3 步。

## 第 3 步:准备 prompt + 并行派 subagent

### 3.1 套 prompt 模板

- **mode=diag** → 读 `~/.claude/skills/xcheck/prompts/diag.md`,把 `{{USER_INPUT}}` 替换成 `$ARGUMENTS`**或第 0 步摄入确认后的事实清单**(若用户在对话里另外给了上下文/复现,替换 `{{CONTEXT}}`;没给就把整行 `{{CONTEXT}}` 那行删掉)。
- **mode=review** → 读 `~/.claude/skills/xcheck/prompts/review.md`,把 `{{PROPOSAL}}` 替换成 `$ARGUMENTS`**或第 0 步摄入确认后的事实清单**(若 `$ARGUMENTS` 是文件路径,先 Read 出全文再填);`{{CONTEXT}}` 同 diag —— 有额外背景就填,没有就把整行删掉。

> **固化 proposal 时的自代入陷阱**:当 controller 把多轮 brainstorming 讨论固化成自包含 proposal(走 context-intake.md 的"方案型指代"例外)时,**避免在 proposal 正文里写会让被评 agent 自代入的背景** —— 否则被评 agent 可能把自己当成"该跑评审流程的人",去加载 skill / 找别的 agent(实测会触发权限弹窗失败)。需要的历史上下文用**中性陈述**,只讲事实、不带触发词:
> - ❌「codex 上轮抓到口令轮换 bug」「三家异构 agent 都给了 SUGGEST_CHANGES」
> - ✅「本方案曾有一个口令轮换相关缺陷,已通过改用明文备份解决」「这是该方案的第二版」
>
> 讲清楚"发生过什么"即可,别点名 agent / 别写"异构评审"这类会被误读为编排指令的词。

### 3.2 落盘 prompt(当前 cwd)

复用第 0 步摄入时已建的时间戳目录 `.xcheck/<ts>/`;**若第 0 步跳过了摄入**(自包含输入),则在此生成 `<YYYYMMDD-HHMMSS>/`(本地时间,例 `20260809-143012`)。把上一步填好的最终 prompt 写到:
```
<cwd>/.xcheck/<ts>/prompt.txt   # 用绝对路径
```
(`.xcheck/` 已在 .gitignore 里,不会污染仓库。)

### 3.3 读 agents.toml 拿每个 agent 的参数

读 `~/.claude/skills/xcheck/agents.toml`,对 SELECTED 里每个 agent 取出:
- `run_cmd`(如 `codex exec -`、`opencode run`、`claude -p`)—— **不含 prompt**;
- `input_mode`(`arg` 或 `stdin`);
- `needs_timeout` / `timeout_sec`(per-agent 优先;否则取 `agents.toml` 顶部 `[defaults].timeout_sec`,默认 480;`/xcheck-setup timeout` 可查改)。

### 3.4 一条消息里并发派 |SELECTED| 个 subagent(关键)

**在一条消息里** 同时开出 |SELECTED| 个 Agent 工具调用,让它们**并行**跑(不要串行 await)。参考 superpowers 的 `dispatching-parallel-agents`。

每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md` 的**全文**,并在末尾追加该 agent 的填好参数:

```
AGENT_NAME = <name>
CLI_CMD = <run_cmd>
INPUT_MODE = <arg | stdin>
PROMPT_FILE = <cwd>/.xcheck/<ts>/prompt.txt
TIMEOUT = <timeout_sec;per-agent 优先,否则取 [defaults].timeout_sec(480)>
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

## 第 6 步:反馈分级(把各家反馈按可验证性归三类)

紧接第 5 步(已写好 `SUMMARY.md` 的"共识/分歧/存疑"段),**你(主会话)**继续做反馈分级,结果**追加**进同一个 `SUMMARY.md`。

### 6.1 收集原料

读 `<cwd>/.xcheck/<ts>/` 下**所有 `<agent>.summary.md`**(第 4 步落盘的结构化结论)。**只读 `.summary.md`,不读 `.raw.out`**(那是噪声留底)。某家只有 `.failed.md` 或没有 `.summary.md` → 跳过那家(第 5 步顶部已注明"本轮 N 家未返回")。

### 6.2 拆条 + 标来源

把每家 summary 里的"问题/建议"逐条拆出来,每条前面标来源,例如:`[codex] 这里用了 localStorage 存 token`。某家只有"LGTM/无意见" → 该家不贡献条目(不强行补条)。

### 6.3 套模板分级

读 `~/.claude/skills/xcheck/prompts/triage.md`,把 `{{ALL_FEEDBACK}}` 替换成"6.2 拆出的所有条目拼接(带 `[来源]` 标注)"。按该模板把每条归入三类:

- **第 1 类 · 可直接证实** —— 查/读/对一下就能判(附一行"判据:可查 X")。
- **第 2 类 · 可设计实验验证** —— 配轻量方案【验证目的 / 一句话方法 / 预期】。**只设计,绝不执行**(不跑测试、不调工具探测、不改文件)。
- **第 3 类 · 存疑仅参考** —— 每条尾部加 `⚠️ 未必准确,仅作参考,谨慎采纳`。

**分类兜底**:拿不准往"更不可信"兜(1↔2 模糊归 2;2↔3 模糊归 3;第 2 类某条实验设计不出来 → 降级第 3 类)。

### 6.4 写盘(追加,不覆盖)

把分级结果**追加**到 `<cwd>/.xcheck/<ts>/SUMMARY.md` 末尾(第 5 步的共识/分歧/存疑在前,三类分级在后)。输出格式严格按 `triage.md` 的三个区块;空类留占位(如"第二类:无。" / "第三类:无。"),不省略区块。

**异常**:
- 三类全空(各家都 LGTM 或全失败)→ 输出一行:`本轮无可分级反馈(各家均未提出问题/建议)。`,不输出空区块。
- 条目重复(两家说本质相同的问题)→ 各自保留、各标来源,不合并。
- **第 6 步崩了不影响第 5 步**——第 5 步的 SUMMARY 已落盘,分级是追加,崩了最多缺分级段,不能带走已有汇总。

### 6.5 收尾

第 6 步**不**单独再喊"你拍板"——第 5 步结尾那句"共识≠正确,你拍板"已覆盖整个 SUMMARY。第 6 步只是给那段话补"可信度依据"。呈现给用户即结束。

---

## 边界与异常处理

- **subagent 报超时/失败**:照样落 `.failed.md`,继续对其它 agent 做综合(不要因为一个挂了就整体崩)。在 SUMMARY 里注明 "本轮 <agent> 未返回/失败,以下综合基于其余 N 家"。
- **全 claude 同构**(用户坚持):照常跑,但 SUMMARY 顶部必须显著标注 "⚠️ 本次为同构,异构价值未体现"。
- **用户在对话里改主意**(想加/换 agent):回到第 2 步重选(适用 --agents / 默认集 / 多选三种来源),然后第 3 步重新派。
- **`.xcheck/` 不要 commit** —— 已 gitignore。源文件只有仓库里的 skill 文件本身。
