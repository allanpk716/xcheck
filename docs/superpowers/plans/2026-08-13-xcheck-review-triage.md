# xcheck 反馈分级(Triage)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 `/xcheck`(diag/review)fan-out 汇总流程后新增"第 6 步:反馈分级"——主会话把各家 agent 的结构化结论逐条按可验证性归三类(可直接证实 / 可设计实验验证 / 存疑仅参考),追加进 `SUMMARY.md`。第 2 类只设计验证方案,绝不执行。

**Architecture:** 改动仅两处,均落在仓库 `C:\WorkSpace\agent\xcheck` 的 `xcheck/` 目录(该目录就是 skill 源,经 junction 链到 `~/.claude/skills/xcheck/`,改仓库文件即改 skill)。① 新建 `xcheck/prompts/triage.md`(diag/review 共用的分级 prompt 模板,内容=spec 第 4 节全文)。② 在 `xcheck/lib/flow.md` 的"第 5 步"与"## 边界与异常处理"之间插入"第 6 步:反馈分级"。现有第 1~5 步、检测、subagent 搬运、4 个入口 SKILL.md 一律不动。

**Tech Stack:** Claude Code skill(Markdown prompt 模板 + `$ARGUMENTS`);prose/prompt 工程,无单测——每个任务的"测试"是**行为验证**(读文件检查内容 / 实跑一次 xcheck 检查 SUMMARY 产出)。

## Global Constraints

(来自已批准 spec `docs/superpowers/specs/2026-08-13-xcheck-review-triage-design.md`,每个任务隐含遵守。)

- **源码位置 = 仓库内**:`xcheck/prompts/triage.md`、`xcheck/lib/flow.md` 直接在仓库 `C:\WorkSpace\agent\xcheck` 编辑并 git commit。仓库 `xcheck/` 经 junction 链到 `~/.claude/skills/xcheck/`,改源即改 skill,下次触发吃到新逻辑(稳妥起见开新会话)。
- **第 6 步铁律**:第 2 类**只设计验证方案、绝不执行**(不跑测试、不调用工具探测、不改文件);第 3 类每条必带 `⚠️ 未必准确,仅作参考,谨慎采纳`;每条必标 `[来源]`;逐条判定不可漏条。
- **不碰副作用**:保住"只搬运不评判、不自动执行、人拍板"铁律。本改动是纯整理,新增的分级动作不读 `.raw.out`、不执行任何实验。
- **追加而非覆盖**:第 6 步产物**追加**进第 5 步已写好的 `SUMMARY.md`,不是新建文件、不覆盖第 5 步内容。第 6 步崩了不影响第 5 步已落盘的汇总。
- **分类兜底**:拿不准往"更不可信"兜(1↔2 模糊归 2;2↔3 模糊归 3)。
- **平台**:Windows + Git Bash。文件用 LF 行尾(仓库已有 `.gitattributes` 强制 LF)。中文标点/emoji(⚠️)必须原样保留。

---

## File Map

仓库 `C:\WorkSpace\agent\xcheck` 下,路径相对仓库根。

| 文件 | 职责 | 本计划动作 |
|---|---|---|
| `xcheck/prompts/triage.md` | 反馈分级 prompt 模板(diag/review 共用),含 `{{ALL_FEEDBACK}}` 槽位 | **新建**(Task 1) |
| `xcheck/lib/flow.md` | 共享 5+1 步编排大脑(现为 5 步) | **修改**:在"第 5 步"与"## 边界与异常处理"之间插入"第 6 步"(Task 2) |

**不动的文件**:`xcheck/agents.toml`、`xcheck/lib/detect.sh`、`xcheck/lib/subagent-carrier.md`、`xcheck/lib/extractor-carrier.md`、`xcheck/lib/context-intake.md`、`xcheck/prompts/diag.md`、`xcheck/prompts/review.md`、`xcheck/prompts/synthesize-diag.md`、`xcheck/prompts/synthesize-review.md`、4 个入口 SKILL.md(`xcheck/`、`xcheck-diag/`、`xcheck-review/`、`xcheck-setup/`)。

---

## Task 1: 新建 `xcheck/prompts/triage.md`

**Goal:** 创建反馈分级 prompt 模板。这是纯文件创建,内容直接取自已批准 spec 第 4 节全文,无自由发挥。

**Files:**
- Create: `C:\WorkSpace\agent\xcheck\xcheck\prompts\triage.md`

**Interfaces:**
- Consumes: 被 `flow.md` 第 6 步(Task 2)读取;槽位 `{{ALL_FEEDBACK}}` 由第 6 步填入"各家 `<agent>.summary.md` 拼接 + 每条 `[来源]` 标注"。
- Produces: 一个 prompt 文本文件,主会话读它后按其指令逐条归类并产出"三个区块"格式。

- [ ] **Step 1: 写入文件全文**

用 Write 工具创建 `xcheck/prompts/triage.md`,内容**原样照抄**下面这段(不得改动任何措辞、emoji、标点;`{{ALL_FEEDBACK}}` 是运行时槽位,保留双花括号原样):

````markdown
你是反馈分级者。下面是 N 个**不同** AI agent 对同一个问题/方案各自独立给出的结构化结论(盲评,每家只基于同样 prompt)。

每家结论里包含若干"问题/建议"条目。你的任务:**逐条**判定每条反馈的可验证性,归入下列**三类之一**,然后按指定格式输出。

【各家结构化结论】
{{ALL_FEEDBACK}}

## 三类判据(逐条套)

**第 1 类 · 可直接证实(verifiable)** —— 不用做实验,靠查/读/对就能当场判真假。
满足任一:能在代码/配置/日志/文档里直接查到证据;是事实性陈述可被现有信息核对;是公开可查的常识/规范。

**第 2 类 · 可设计实验验证(empirical)** —— 不能一眼看穿,但能设计轻量实验证伪/证实。
满足任一:能写测试/最小复现验证行为;能靠运行探测观察;是性能/可行性断言得跑起来才知道。

**第 3 类 · 存疑仅参考(speculative)** —— 既查不到证据、也没法设计实验验证。
主观/口味/风格;对未来/外部的预测;信息不足无法判定对错也设计不出实验。

**分类兜底规则**:拿不准时**默认往"更不可信"方向兜**——1↔2 模糊归 2;2↔3 模糊归 3。宁可保守标记,不可高估。

## 输出格式(严格遵守)

按**三个区块**输出,每个区块一个二级标题。每家 agent 的条目用 `[来源]` 标注。

### 第一类 · 可直接证实
> 这些不用做实验,查/读/对一下就能判。可优先据信。

- `[来源]` 反馈内容原句(或紧缩转述)
  - 判据:一句话说明为什么算可证实(可查 X 处 / 是事实 Y)
- `[来源]` …
  - 判据:…

### 第二类 · 可设计实验验证
> 这些不能一眼看穿,但下面的实验能证伪/证实。**仅设计方案,绝不执行。**

- `[来源]` 反馈内容原句(或紧缩转述)
  - 验证目的:这条要证实/证伪什么
  - 方法(一句话):怎么测(如"写个并发测试压 X"、"跑 benchmark 对比 Y")
  - 预期:结果如何则证明该反馈成立 / 不成立
- `[来源]` …
  - 验证目的:…
  - 方法(一句话):…
  - 预期:…

### 第三类 · 存疑 · 仅作参考
> 这些既查不到证据也设计不出实验,未必准确,**谨慎采纳,仅作参考**。

- `[来源]` 反馈内容原句(或紧缩转述) ⚠️ 未必准确,仅作参考,谨慎采纳
- `[来源]` … ⚠️ 未必准确,仅作参考,谨慎采纳

## 铁律

- **逐条判定,不可漏条**——每家每条都要落到一个类。某条实在无法判定,归第 3 类。
- **来源不可丢**——每条必须标 `[来源]`,用户要能追溯是哪家说的。
- **第 2 类只设计方案,绝不执行**(不写"我去跑一下"、不真的调用任何工具去测)。
- **第 3 类必带** ⚠️ 标注。
- 严禁捏造任何 agent 没说过的条目;某家无结论就跳过那家,不要补条。
````

- [ ] **Step 2: 验证文件内容与行尾**

读回 `xcheck/prompts/triage.md`,核对:
- 文件以"你是反馈分级者"开头,以"某家无结论就跳过那家,不要补条。"结尾。
- `{{ALL_FEEDBACK}}` 原样存在(双花括号)。
- 三个二级标题(`### 第一类`/`### 第二类`/`### 第三类`)齐全。
- ⚠️ emoji 出现在第 3 类区块与铁律两处。

Run(检查行尾与占位符,Git Bash):
```bash
file xcheck/prompts/triage.md && grep -c '{{ALL_FEEDBACK}}' xcheck/prompts/triage.md
```
Expected: `file` 报告 `ASCII text` 或 `UTF-8 Unicode text`(非 `CRLF` 行终止器即 `with CRLF line terminators` 字样应**不出现**;仓库 `.gitattributes` 强制 LF);`grep -c` 输出 `1`(恰好一处 `{{ALL_FEEDBACK}}`)。

- [ ] **Step 3: Commit**

```bash
git add xcheck/prompts/triage.md
git commit -m "feat(xcheck): add triage prompt template (feedback verifiability grading)

新建 prompts/triage.md,diag/review 共用。把各家 agent 反馈逐条归三类
(可直接证实/可设计实验验证/存疑仅参考)。第2类只设计验证方案不执行。
实现 spec docs/superpowers/specs/2026-08-13-xcheck-review-triage-design.md 第4节。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 在 `flow.md` 插入"第 6 步:反馈分级"

**Goal:** 在共享编排流程里,把反馈分级接在第 5 步汇总之后。主会话读完各家 `.summary.md` → 套 `triage.md` → 追加进 `SUMMARY.md`。

**Files:**
- Modify: `C:\WorkSpace\agent\xcheck\xcheck\lib\flow.md` —— 在第 113 行附近"第 5 步"结尾(`**铁律**:绝不自动改代码…决策权在用户`)之后、第 115 行的 `---` 之前,插入新的一节。

**Interfaces:**
- Consumes: Task 1 产出的 `xcheck/prompts/triage.md`(读它,填 `{{ALL_FEEDBACK}}`)、`.xcheck/<ts>/<agent>.summary.md`(第 4 步已落盘)。
- Produces: `flow.md` 多出"第 6 步"小节;第 1~5 步、`## 边界与异常处理` 一律不动。

**关键:插入位置的唯一锚点。** `flow.md` 当前结构是:

```
... 第5步正文 ...
**铁律**:绝不自动改代码 / 自动合并 / 自动"通过"。xcheck 只提供异构第二意见,**决策权在用户**。
                                    ← 在这里(空行后)插入"第6步"整节
---
## 边界与异常处理
```

Edit 工具的 `old_string` 用下面这段(它在前文里唯一,不含歧义):

```
**铁律**:绝不自动改代码 / 自动合并 / 自动"通过"。xcheck 只提供异构第二意见,**决策权在用户**。

---

## 边界与异常处理
```

`new_string` = 上面这段的"铁律行 + 空行"保持不变,在 `---` **之前**插入"第 6 步"整节,再接 `---` 与 `## 边界与异常处理`。

- [ ] **Step 1: 读 flow.md 确认锚点仍在**

读 `xcheck/lib/flow.md` 第 109–123 行,确认"铁律行 + 空行 + `---` + `## 边界与异常处理`"这段与上面写的完全一致(若仓库已变动导致不匹配,先停下核对,不要硬改)。

- [ ] **Step 2: 用 Edit 插入第 6 步**

对 `xcheck/lib/flow.md` 执行 Edit:

- `old_string`(原样,唯一锚点):
```
**铁律**:绝不自动改代码 / 自动合并 / 自动"通过"。xcheck 只提供异构第二意见,**决策权在用户**。

---

## 边界与异常处理
```

- `new_string`(把"第 6 步"整节插在铁律行与 `---` 之间):
````markdown
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

把分级结果**追加**到 `<cwd>/.xcheck/<ts>/SUMMARY.md` 末尾(第 5 步的共识/分歧/存疑在前,三类分级在后)。输出格式严格按 `triage.md` 的三个区块;空类留占位(如"第二类:无。"),不省略区块。

**异常**:
- 三类全空(各家都 LGTM 或全失败)→ 输出一行:`本轮无可分级反馈(各家均未提出问题/建议)。`,不输出空区块。
- 条目重复(两家说本质相同的问题)→ 各自保留、各标来源,不合并。
- **第 6 步崩了不影响第 5 步**——第 5 步的 SUMMARY 已落盘,分级是追加,崩了最多缺分级段,不能带走已有汇总。

### 6.5 收尾

第 6 步**不**单独再喊"你拍板"——第 5 步结尾那句"共识≠正确,你拍板"已覆盖整个 SUMMARY。第 6 步只是给那段话补"可信度依据"。呈现给用户即结束。

---

## 边界与异常处理
````

- [ ] **Step 3: 验证插入正确、第 1~5 步未被改**

读 `xcheck/lib/flow.md`,核对:
- "## 第 6 步:反馈分级"出现在"## 第 5 步"之后、"## 边界与异常处理"之前。
- 第 5 步结尾"铁律"行、"以上是建议,共识 ≠ 正确"那句仍在(未被第 6 步覆盖)。
- `## 边界与异常处理` 段仍在文件末尾,内容未变。

Run(Git Bash,确认步骤数与锚点):
```bash
grep -n '^## ' xcheck/lib/flow.md
```
Expected: 输出依次含 `## 第 0 步:上下文摄入(可选)`、`## 第 1 步:自动检测可用 agent`、`## 第 2 步:让用户多选`、`## 第 3 步:准备 prompt + 并行派 subagent`、`## 第 4 步:收齐 + 落盘`、`## 第 5 步:主会话汇总`、`## 第 6 步:反馈分级`、`## 边界与异常处理`。**必须恰好 8 个 `## ` 标题**,且"第 6 步"在"第 5 步"之后、"边界与异常处理"之前。

- [ ] **Step 4: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): add step 6 — feedback triage into SUMMARY

在 flow.md 第5步汇总后加第6步:主会话读各家 .summary.md,套 prompts/triage.md
把反馈逐条归三类,追加进 SUMMARY.md。第2类只设计验证方案不执行。
实现 spec docs/superpowers/specs/2026-08-13-xcheck-review-triage-design.md 第3节。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 端到端行为验证

**Goal:** 用一次真实的 `/xcheck-review` 或 `/xcheck-diag` 跑通,确认新逻辑真的生效:`SUMMARY.md` 末尾出现合规的"三类验证分级"区块。这是整个改动唯一的"运行时"测试——前面的 Task 1/2 都是静态文件检查。

**Files:** 无改动(只验证)。

**Interfaces:** 依赖 Task 1、Task 2 已完成并 commit。

> **注意**:Task 1/2 改的是仓库 `xcheck/`(经 junction = `~/.claude/skills/xcheck/`)。junction 是活的,文件改了立即生效;但 Claude Code **可能已缓存旧版 flow.md**,稳妥起见**开新会话**再跑本任务。本任务需要用户在交互式会话里手动触发 skill —— 若由 subagent 执行,改为在主会话里手动跑(见 Step 1 说明)。

- [ ] **Step 1: 准备一个轻量、自包含的评审输入**

准备一段适合 review 的短输入(自包含,省去第 0 步摄入),例如一段 10~30 行的真实代码片段或小设计,确保多家 agent 能给出**不止一条**反馈(否则三类分级会偏空,验证不充分)。把这段输入记为 `$INPUT`。

> 这一步由**主会话(人)在交互式 Claude Code 里**执行:`/xcheck-review $INPUT` 或 `/xcheck $INPUT`(命中 review 强信号)。subagent 无法替你触发交互式 skill,故本 Step 在主会话手动跑。

- [ ] **Step 2: 跑 `/xcheck-review`,选 ≥2 个含至少 1 个非 claude 的 agent**

按 flow.md 第 2 步多选,确保返回的 `.summary.md` ≥ 2 家、且至少含 1 个非 claude(避免同构标注干扰验证)。等流程跑完。

- [ ] **Step 3: 检查 `SUMMARY.md` 产出**

定位最新结果目录:
```bash
ls -t .xcheck/ | head -1
```
设为 `<ts>`,读 `.xcheck/<ts>/SUMMARY.md`,逐条核对:

1. **前段**:第 5 步的"共识/分歧/存疑"段仍在(未被覆盖)。
2. **后段**:出现"三类验证分级"内容,含三个区块(`第一类 · 可直接证实` / `第二类 · 可设计实验验证` / `第三类 · 存疑 · 仅作参考`);空类有占位(如"第二类:无。")。
3. **来源标注**:每条反馈带 `[来源]`(可追溯到某家 agent)。
4. **第 2 类格式**:条目含【验证目的 / 方法 / 预期】三行,且**没有**出现"我去跑一下"之类执行措辞(只设计)。
5. **第 3 类标注**:每条带 `⚠️ 未必准确,仅作参考,谨慎采纳`。
6. **收尾**:整个 SUMMARY 只有一句"你拍板"(第 5 步那句),第 6 步没重复喊。

Expected: 以上 6 条全部满足。任一不满足 → 回到 Task 1 或 Task 2 修正对应文件,重跑。

- [ ] **Step 4: 记录验证结果(无代码 commit)**

本任务不产生仓库改动,无需 commit。在交接给用户时说明:已用 `<ts>` 这次实跑验证,`SUMMARY.md` 末尾三类分级区块合规;`.xcheck/` 已 gitignore,不入库。

---

## Self-Review

**1. Spec coverage:**

| Spec 要求 | 实现位置 |
|---|---|
| 三类判定准则(verifiable/empirical/speculative) | Task 1 `triage.md` "三类判据"段 |
| 兜底规则(1↔2 归 2、2↔3 归 3) | Task 1 `triage.md` "分类兜底规则";Task 2 `flow.md` 6.3 重述 |
| 第 2 类轻量三段式(目的/方法/预期),只设计不执行 | Task 1 `triage.md` 第二类区块 + 铁律;Task 2 `flow.md` 6.3 |
| 第 3 类固定 ⚠️ 标注 | Task 1 `triage.md` 第三类区块 + 铁律 |
| 逐条分级、每条标 `[来源]` | Task 1 `triage.md` 铁律;Task 2 `flow.md` 6.2 |
| 新增并存(保留第 5 步汇总) | Task 2 明确"追加、不覆盖";Step 3 验证第 5 步段仍在 |
| 主会话连续做,不新增 subagent | Task 2 全文用"你(主会话)";无 subagent 派发 |
| 原料用 `.summary.md`,不读 `.raw.out` | Task 2 `flow.md` 6.1 |
| 追加进同一 `SUMMARY.md` | Task 2 `flow.md` 6.4 |
| 第 6 步不重复喊"你拍板" | Task 2 `flow.md` 6.5;Task 3 Step 3 核对点 6 |
| 边界:失败家跳过 / 无条目不补 / 三类全空输出一行 / 全同类留空类占位 / 重复不合并 / 第2类验不了降级第3类 | Task 2 `flow.md` 6.1、6.2、6.4 "异常"子项 |
| 容错:第 6 步崩不影响第 5 步已落盘 | Task 2 `flow.md` 6.4 "异常"末条 |
| 改动清单:新建 triage.md + 改 flow.md,其余不动 | File Map + Task 1/2;Task 3 不改文件 |

无遗漏。

**2. Placeholder scan:** 无 "TBD/TODO/implement later"。"第 1 类/第 2 类/第 3 类"区块里的 `…` 是模板里给主会话看的"示例续写占位"(表示"再列一条同结构"),是 prompt 内容的一部分,不是计划占位符——已用代码围栏包住照抄,合规。所有命令含完整内容,所有 Edit 含完整 old/new string。

**3. Type/signature consistency:** 这是 prose/prompt 项目,无函数签名。槽位名 `{{ALL_FEEDBACK}}` 在 Task 1(定义)与 Task 2(`flow.md` 6.3 引用"把 `{{ALL_FEEDBACK}}` 替换成…")一致。文件路径 `xcheck/prompts/triage.md`(仓库相对)与 `~/.claude/skills/xcheck/prompts/triage.md`(运行时 junction 后)指同一文件,Task 2 用运行时路径符合 flow.md 现有风格(flow.md 全篇用 `~/.claude/skills/xcheck/...`)。

无问题,计划可执行。
