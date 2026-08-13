# xcheck 默认 agent 集 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `/xcheck-setup` 能预设一组默认 agent,设了默认就跳过 `/xcheck` 每次的勾选;并给三个壳加 `--agents` 临时换集参数。

**Architecture:** 数据上往 `agents.toml` 的 `[defaults]` 块加一个可选字段 `default_agents`;行为上重写 `flow.md` 第 2 步为"选择源 → 取交集 → 三分支";setup 加一个与 `timeout` 同构的 `default` 子命令;三个薄壳加 `--agents` 解析与透传。完全向后兼容(字段缺失 = 旧行为)。

**Tech Stack:** Claude Code skill 文件(markdown 指令)+ TOML 配置 + 一个 bash 脚本(`detect.sh`)。无传统测试框架 —— 验证靠静态检查(grep / 回读 / `detect.sh` 仍跑)加末尾端到端实跑。

**Spec:** `docs/superpowers/specs/2026-08-13-xcheck-default-agents-design.md`

## Global Constraints

- **沟通语言**:所有新增/修改的 skill 指令文本用**中文**,短句直说,风格与现有 SKILL.md / flow.md 一致。
- **改源即生效**:这 4 个目录是 junction 到 `~/.claude/skills/` 的;仓库文件改了 skill 就改了。但调用时读文件,**端到端实跑必须开新会话**(吃新逻辑、躲缓存)。
- **Edit 不 Write**:改 `agents.toml` 一律用 Edit 精确匹配,**绝不** Write 覆盖(会丢注释/格式)。
- **出厂态**:`agents.toml` 里**不写** `default_agents` 的实际值(保持"未设"作为出厂默认),只加注释说明字段。
- **异构命门**:默认集/`--agents` 同构 → 警告或标注,**不硬拦**(用户自由);只有分支 A 多选保留"全 claude 二次确认"。
- **每个 Task 结尾 commit**;commit message 用 `feat(xcheck):` / `docs(xcheck):` 前缀,与现有提交风格一致(见 `git log`)。

## File Structure(改动清单)

| 文件 | 职责 | 动作 |
|------|------|------|
| `xcheck/agents.toml` | agent 注册表 + 默认配置 | 加 `default_agents` 字段注释说明 |
| `xcheck-setup/SKILL.md` | 检测/验证/登记/超时/默认集 | 加"模式 D:default";改 argument-hint |
| `xcheck/lib/flow.md` | 共享执行流程(编排大脑) | 第 1 步末尾记 INSTALLED;第 2 步整段重写为三分支;边界条目补一句 |
| `xcheck/SKILL.md` | /xcheck 自动路由 | 加 `--agents` 解析与透传;改 argument-hint |
| `xcheck-diag/SKILL.md` | /xcheck-diag 并行诊断 | 加 `--agents` 解析与透传;改 argument-hint |
| `xcheck-review/SKILL.md` | /xcheck-review 交叉评审 | 加 `--agents` 解析与透传;改 argument-hint |

---

## Task 1: agents.toml 加 default_agents 字段说明

**Files:**
- Modify: `xcheck/agents.toml`(顶部注释块 + `[defaults]` 块)

**Interfaces:**
- Produces: `[defaults]` 块下一个**注释行**(字段形状说明,不出厂值)。后续 Task 2/3 依赖这个字段名 `default_agents`。

- [ ] **Step 1: 在顶部注释块补一段 default_agents 说明**

用 Edit,精确匹配现有这段(注意 CRLF —— 仓库 git autocrlf=on,Edit 工具按文件实际内容匹配):

old_string(文件第 6-8 行附近,三行注释):
```
# 超时配置: xcheck 调用 agent 时给 shell 套的 `timeout <sec>` 上限(只影响 xcheck,
# 不影响 agent 自己单独跑)。优先级: per-agent timeout_sec  > [defaults].timeout_sec。
# 用 /xcheck-setup timeout [N|<agent> N] 查看/设置。
```

new_string(原三行 + 新四行):
```
# 超时配置: xcheck 调用 agent 时给 shell 套的 `timeout <sec>` 上限(只影响 xcheck,
# 不影响 agent 自己单独跑)。优先级: per-agent timeout_sec  > [defaults].timeout_sec。
# 用 /xcheck-setup timeout [N|<agent> N] 查看/设置。
#
# 默认 agent 集: 设了之后 /xcheck 直接拿这组跑,跳过每次勾选。
# 字段 default_agents = ["claude", "codex", ...](名字须对得上下面 [agents.<name>] 的 key)。
# 字段缺失/空 = 未设默认 → 每次运行弹多选(出厂默认)。
# 用 /xcheck-setup default [a,b,c | --clear] 查看/设置/清空。
```

- [ ] **Step 2: 在 [defaults] 块加注释行(不出厂值)**

old_string(`[defaults]` 块,第 10-12 行):
```
[defaults]
# 所有 agent 的默认最大执行秒数。per-agent timeout_sec 覆盖此值。
timeout_sec = 1800
```

new_string:
```
[defaults]
# 所有 agent 的默认最大执行秒数。per-agent timeout_sec 覆盖此值。
timeout_sec = 1800
# 默认 agent 集(可选)。设了 /xcheck 就跳过每次勾选直接用这组。
# 出厂不设(注释掉);要用就取消注释、填名字。详见顶部说明。
# default_agents = ["claude", "codex", "kimi"]
```

- [ ] **Step 3: 回读验证字段说明在位**

Run: `git --no-pager diff xcheck/agents.toml`
Expected: 看到 4 行新注释 + 1 行注释掉的 `default_agents` 示例;**没有任何非注释行被改**(timeout_sec 值不变)。

- [ ] **Step 4: 确认 detect.sh 仍能解析(没破坏 toml 结构)**

Run: `bash xcheck/lib/detect.sh`
Expected: stdout 正常列出 5 个 agent(claude/codex/opencode/pi/kimi)`installed` 或 `missing`,无 ERROR。(detect.sh 只读 `[agents.*]` 块的 installed_check,加注释不影响它。)

- [ ] **Step 5: Commit**

```bash
git add xcheck/agents.toml
git commit -m "docs(xcheck): agents.toml 标注 default_agents 字段(不出厂值)"
```

---

## Task 2: xcheck-setup 加"模式 D:default"

**Files:**
- Modify: `xcheck-setup/SKILL.md`(argument-hint 第 5 行 + 文末追加模式 D)

**Interfaces:**
- Consumes: Task 1 的 `default_agents` 字段名。
- Produces: `/xcheck-setup default` 三种调用语义(无参查看 / 设置 / --clear),与 `timeout` 子命令同构。

- [ ] **Step 1: 改 argument-hint,把 default 加进去**

old_string(第 5 行):
```
argument-hint: [add <name> | timeout [N | <agent> N]]
```

new_string:
```
argument-hint: [add <name> | timeout [N | <agent> N] | default [<n1>,<n2>,... | --clear]]
```

- [ ] **Step 2: 在模式 C 之后(文件末尾)追加模式 D**

用 Edit,锚定模式 C 最后一行(第 63 行附近 `4. N 必须是正整数;非整数报错不改。`),在其**后面**插入整段模式 D。

old_string(模式 C 结尾那一句,作为锚):
```
4. N 必须是正整数;非整数报错不改。
```

new_string(原句 + 整段模式 D):
```
4. N 必须是正整数;非整数报错不改。

## 模式 D:`default [...]` → 查看 / 设置 / 清空默认 agent 集

设了默认集之后,`/xcheck`(及 diag/review)会**直接拿这组跑,跳过每次的勾选弹窗**;没设就回退到每次弹多选。详见 `~/.claude/skills/xcheck/lib/flow.md` 第 2 步。优先级:`--agents` 临时参数 > `default_agents` > 每次弹窗。

3 种调用:

- **`/xcheck-setup default`**(无参)→ 读 `agents.toml` 的 `[defaults].default_agents`。有值就表格/列表呈现当前默认集;没设(字段缺失/空)就提示"未设默认,每次运行会弹多选"。
- **`/xcheck-setup default <n1>,<n2>,...`**(逗号分隔的名字)→ 设置默认集。空格忽略;同名去重、保序(首次出现为准)。
- **`/xcheck-setup default --clear`** → 清空默认集(回到每次弹窗)。

执行(主会话):

1. 读 `~/.claude/skills/xcheck/agents.toml`。
2. **名字合法性**:每个名字必须存在于 `[agents.<name>]` 块。任一不存在 → 报错、列出当前 toml 里所有合法 agent 名、**不改文件**。
3. **异构校验(警告但允许)**:若设的集同构(全 claude,或 < 2 个,或无非 claude)→ 打印警告"⚠️ 默认集为同构/单 agent,异构价值未体现,仍照设",**不拦**,继续写。
4. **写文件用 Edit 精确匹配改 `[defaults]` 块**(跟模式 C 同做法,不要 Write 覆盖):
   - 首次设置(toml 里 `default_agents` 还是注释行/不存在)→ 把注释行 `# default_agents = [...]` 替换成实际值行 `default_agents = ["claude", "codex", ...]`(数组按 toml 语法:双引号名字、逗号分隔、空格可忽略)。
   - 已有实际值 → 把旧的那行 `default_agents = [旧值]` 替换成新值。
   - `--clear` → 把实际值行改回注释行 `# default_agents = [...]`(或直接删该行)。
5. **改完回显**新配置(同无参视图),提示"下次 /xcheck 即生效"。
6. **不在 setup 阶段校验"已装"**:默认集里的 agent 当前装没装,由运行时 flow.md 第 1 步 detect 判定。setup 只保证名字在 toml 里合法。
```

- [ ] **Step 3: 回读验证模式 D 在位、argument-hint 已改**

Run: `git --no-pager diff xcheck-setup/SKILL.md`
Expected: argument-hint 含 `default`;文末出现"模式 D"整段;模式 A/B/C 原文未被改动。

- [ ] **Step 4: Commit**

```bash
git add xcheck-setup/SKILL.md
git commit -m "feat(xcheck-setup): 加 default 子命令(默认 agent 集)"
```

---

## Task 3: flow.md 第 1/2 步改造(核心)

**Files:**
- Modify: `xcheck/lib/flow.md`(第 1 步末尾 + 第 2 步整段 + 边界条目)

**Interfaces:**
- Consumes: Task 1 的 `default_agents` 字段;三个壳(Task 4)会传 `OVERRIDE_AGENTS` 变量进来。
- Produces: 第 2 步最终定下 `SELECTED`(agent 名列表),喂给第 3 步(不变)。

- [ ] **Step 1: 第 1 步末尾加"记 INSTALLED"**

old_string(第 1 步结尾,第 23-26 行附近):
```
- stdout = 已安装可选的 agent(每行 `name \t installed_check \t installed`)。stderr = 已登记但未装的(每行 `... \t missing`)。
- 数 stdout 里的 agent 数。
  - **若已装 < 2 个**:告诉用户装的太少(异构至少要 2 个、且至少 1 个非 claude),建议先 `/xcheck-setup` 核实,然后**停**,不继续。不要硬跑单 agent。
```

new_string(原三行 + 新一行记 INSTALLED):
```
- stdout = 已安装可选的 agent(每行 `name \t installed_check \t installed`)。stderr = 已登记但未装的(每行 `... \t missing`)。
- 数 stdout 里的 agent 数。
  - **若已装 < 2 个**:告诉用户装的太少(异构至少要 2 个、且至少 1 个非 claude),建议先 `/xcheck-setup` 核实,然后**停**,不继续。不要硬跑单 agent。
- **记 `INSTALLED`** = stdout 里所有已装 agent 的名字列表(小写,与 agents.toml key 一致),供第 2 步取交集用。
```

- [ ] **Step 2: 整段替换第 2 步为三分支逻辑**

old_string(整段第 2 步,从 `## 第 2 步:` 到 `- 记 \`SELECTED\` = 选中的 agent 名列表(小写,与 agents.toml 的 key 一致)。` 结束 —— 即当前第 27-36 行全文):
```
## 第 2 步:让用户多选(AskUserQuestion,multiSelect: true)

把已装的 agent 列成 AskUserQuestion 的选项让用户挑(multiSelect: true)。**问题文本里必须原样包含这句提醒**:

> ⚠️ 至少选一个非 claude(如 codex / opencode / kimi),否则全是 Claude 同构,等于自己审自己。

- **若用户选的全是 claude 系**:再用 AskUserQuestion 确认一次 "确定只要 claude 同构吗?(不推荐)",仍坚持就继续,但在最终 SUMMARY 与汇报里**显著标注** "⚠️ 本次为同构诊断/评审,异构价值未体现"。
- **若选的 ≥ 2 个且至少 1 个非 claude**:正常进行。
- 记 `SELECTED` = 选中的 agent 名列表(小写,与 agents.toml 的 key 一致)。
```

new_string(完整新第 2 步):
```
## 第 2 步:定 SELECTED(默认集 / --agents / 多选 三分支)

先定**候选集 CANDIDATES**(优先级从高到低):

1. 若壳传来了 `OVERRIDE_AGENTS`(用户敲了 `--agents a,b,c` 且 token 非空)→ `CANDIDATES = OVERRIDE_AGENTS`。
2. 否则读 `~/.claude/skills/xcheck/agents.toml` 的 `[defaults].default_agents`:字段存在且非空 → `CANDIDATES = default_agents`。
3. 两者都没有 → `CANDIDATES = null`(走分支 A)。

**坏名处理(定 CANDIDATES 时)**:

- CANDIDATES 来自 `OVERRIDE_AGENTS` 且**有名字不在 agents.toml 的 `[agents.<name>]`** → **报错停住**,打印"名字 X 不在 agents.toml;可用 agent:<列出所有 [agents.*] key>",不继续(用户显式指令,笔误立即停)。
- CANDIDATES 来自 `default_agents` 且有坏名(toml 被手改坏)→ **防御性剔除**该名,继续(不崩)。

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
```

- [ ] **Step 3: 边界条目补一句(适用范围)**

old_string(边界区那条"用户在对话里改主意",第 158 行附近):
```
- **用户在对话里改主意**(想加/换 agent):回到第 2 步重选,然后第 3 步重新派。
```

new_string:
```
- **用户在对话里改主意**(想加/换 agent):回到第 2 步重选(适用 --agents / 默认集 / 多选三种来源),然后第 3 步重新派。
```

- [ ] **Step 4: 回读验证第 2 步三分支结构在位**

Run: `grep -n "分支 A\|分支 B\|分支 C\|CANDIDATES\|OVERRIDE_AGENTS\|INSTALLED" xcheck/lib/flow.md`
Expected: 至少各出现一次;`## 第 2 步:定 SELECTED` 标题存在;旧的"让用户多选"标题已不在。

Run: `grep -c "至少选一个非 claude" xcheck/lib/flow.md`
Expected: `1`(那句提醒现在只在分支 A 里,不重复)。

- [ ] **Step 5: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): flow.md 第2步改造为默认集/--agents/多选三分支"
```

---

## Task 4: 三个壳加 --agents 解析与透传

**Files:**
- Modify: `xcheck/SKILL.md`(argument-hint + 解析段 + 转派带 OVERRIDE_AGENTS)
- Modify: `xcheck-diag/SKILL.md`(argument-hint + 解析段)
- Modify: `xcheck-review/SKILL.md`(argument-hint + 解析段)

**Interfaces:**
- Consumes: Task 3 的 `OVERRIDE_AGENTS` 变量名(flow.md 第 2 步认这个名字)。
- Produces: 三个壳都能从 `$ARGUMENTS` 抠出 `--agents`,设 `OVERRIDE_AGENTS`,把剩余文本当真正输入。

> 三个壳的 `--agents` 解析规则**完全相同**;下面 Step 1 给出共享文本,三个文件各粘贴一次(别只改一个)。

- [ ] **Step 1: 改 xcheck-diag/SKILL.md**

1a. argument-hint。old_string:
```
argument-hint: <技术问题>
```
new_string:
```
argument-hint: [--agents a,b,c] <技术问题>
```

1b. 在"执行:"列表前插入 `--agents` 解析段。锚点 = `执行:` 那行。

old_string:
```
执行:
```
new_string:
```
### --agents 临时换集(可选)

若 `$ARGUMENTS` 含 `--agents`:

1. 其值 = 紧跟 `--agents` 后的**一个空白分隔 token**(到第一个空格止),须是纯逗号串(如 `codex,kimi`),**不含空格**(别写 `codex, kimi`)。
2. 把 `--agents <token>` 从 `$ARGUMENTS` 删掉,**剩余文本**作为真正要诊断的问题。
3. token 非空 → 设 `OVERRIDE_AGENTS = <拆成的名字列表>`;token 为空(敲了 `--agents` 没给名字)→ 忽略该参数,当没敲。
4. 转派 flow.md 时带上 `OVERRIDE_AGENTS`(flow.md 第 2 步会校验名字合法性:笔误就报错停住)。

`--agents` 优先级最高,盖过默认集;本次有效,不改默认。

执行:
```

- [ ] **Step 2: 改 xcheck-review/SKILL.md**

2a. argument-hint。old_string:
```
argument-hint: <方案 文本或文件路径>
```
new_string:
```
argument-hint: [--agents a,b,c] <方案 文本或文件路径>
```

2b. 同样的 `--agents` 解析段(文案里"诊断"换成"评审"),插在 `$ARGUMENTS` 是用户要评审的方案` 那段之后、`1. 读 ~/.claude/skills/xcheck/lib/flow.md` 之前。

old_string(锚 = 执行列表第一项):
```
1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中的「第 0 步(可选摄入)+ 5 步」执行**,本次 **mode = review**。
```
new_string(解析段 + 原第一项):
```
### --agents 临时换集(可选)

若 `$ARGUMENTS` 含 `--agents`:

1. 其值 = 紧跟 `--agents` 后的**一个空白分隔 token**(到第一个空格止),须是纯逗号串(如 `codex,kimi`),**不含空格**。
2. 把 `--agents <token>` 从 `$ARGUMENTS` 删掉,**剩余文本**作为真正要评审的方案。
3. token 非空 → 设 `OVERRIDE_AGENTS = <拆成的名字列表>`;token 为空 → 忽略该参数。
4. 转派 flow.md 时带上 `OVERRIDE_AGENTS`(笔误报错停住)。

`--agents` 优先级最高,盖过默认集;本次有效,不改默认。

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中的「第 0 步(可选摄入)+ 5 步」执行**,本次 **mode = review**。
```

- [ ] **Step 3: 改 xcheck/SKILL.md(路由壳)**

3a. argument-hint。old_string:
```
argument-hint: <问题描述或方案>
```
new_string:
```
argument-hint: [--agents a,b,c] <问题描述或方案>
```

3b. 在第 0 步分类之前加 `--agents` 解析。锚 = `## 第 0 步:分类` 标题行。

old_string:
```
## 第 0 步:分类(只这一步是你的活)
```
new_string:
```
### 先抠 --agents(可选,在分类之前)

若 `$ARGUMENTS` 含 `--agents`:其值 = 紧跟后**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,不含空格)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉,剩余文本才送去分类;token 非空 → 记 `OVERRIDE_AGENTS = <列表>`,**转派 diag/review 时原样带上**;token 为空 → 当没敲。优先级最高,盖过默认集,不改默认。

## 第 0 步:分类(只这一步是你的活)
```

3c. 转派指令里补一句带上 OVERRIDE_AGENTS。锚 = 第 1 步里那两行 diag/review 转派说明的结尾(在 `汇总模板用 ~/.claude/skills/xcheck/prompts/synthesize-review.md。` 之后)。

old_string:
```
- **mode=review** → 按 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步摄入(可选)+ 5 步」执行,本次 mode = review;外部 prompt 用 `~/.claude/skills/xcheck/prompts/review.md`(若 `$ARGUMENTS` 是文件路径先 Read 出全文;或第 0 步摄入确认后的事实清单),汇总模板用 `~/.claude/skills/xcheck/prompts/synthesize-review.md`。
```
new_string:
```
- **mode=review** → 按 `~/.claude/skills/xcheck/lib/flow.md` 的「第 0 步摄入(可选)+ 5 步」执行,本次 mode = review;外部 prompt 用 `~/.claude/skills/xcheck/prompts/review.md`(若 `$ARGUMENTS` 是文件路径先 Read 出全文;或第 0 步摄入确认后的事实清单),汇总模板用 `~/.claude/skills/xcheck/prompts/synthesize-review.md`。

> 无论 diag 还是 review:若本壳抠到了 `OVERRIDE_AGENTS`,转派 flow.md 时**带上**它(flow.md 第 2 步据此走候选集分支,不再看默认集)。
```

- [ ] **Step 4: 回读验证三个壳都改了**

Run: `grep -l "OVERRIDE_AGENTS" xcheck/SKILL.md xcheck-diag/SKILL.md xcheck-review/SKILL.md`
Expected: 三个文件名都列出(三个都含 OVERRIDE_AGENTS)。

Run: `grep -c "\-\-agents" xcheck/SKILL.md xcheck-diag/SKILL.md xcheck-review/SKILL.md`
Expected: 三个都 ≥ 2(argument-hint 一处 + 解析段)。

- [ ] **Step 5: Commit**

```bash
git add xcheck/SKILL.md xcheck-diag/SKILL.md xcheck-review/SKILL.md
git commit -m "feat(xcheck): 三壳加 --agents 临时换集参数解析与透传"
```

---

## Task 5: 端到端实跑验证(开新会话)

**Files:** 无(只跑,不改文件)。

**Interfaces:** 验证 Task 1-4 的整体行为。

> **前置**:junction 是活的,但调用时读文件。**必须开一个新 Claude Code 会话**跑这些,确保吃到改后的 skill 逻辑(旧会话可能缓存)。跑之前先确认 4 个目录已 junction 到 `~/.claude/skills/`(memory 记录的安装方式)。

- [ ] **Step 1: 静态冒烟 —— setup default 无参查看**

新会话里跑:`/xcheck-setup default`
Expected: 提示"未设默认,每次运行会弹多选"(因为出厂没写 default_agents 值)。

- [ ] **Step 2: 设置一个全装的默认集**

跑:`/xcheck-setup default claude,codex,kimi`(按本机实际已装的挑 ≥2 且含非 claude)
Expected: 回显新默认集;`agents.toml` 里 `[defaults]` 下出现实际值行 `default_agents = [...]`。用 `grep default_agents xcheck/agents.toml` 确认值在、非注释。

- [ ] **Step 3: 跑一次 /xcheck-diag 验证跳过弹窗**

跑:`/xcheck-diag <一个小问题>`
Expected: **不弹** agent 多选,直接用默认集并行派 subagent(分支 B)。SUMMARY 正常产出。

- [ ] **Step 4: 模拟缺失 —— 分支 C 弹窗**

临时把 agents.toml 默认集里加一个本机没装的名字(如 `gemini`),或卸载一个默认集里的 CLI,再跑 `/xcheck-diag <问题>`。
Expected: 弹**单选**窗(用剩余 / 重新选),文本列出缺失的那家。验完**改回** toml。

- [ ] **Step 5: --agents 临时换集**

跑:`/xcheck-diag --agents codex,pi <问题>`(用本机已装的)
Expected: 用 codex+pi 这组跑,不碰默认集;默认集仍是 Step 2 设的那组(再跑一次无 --agents 的验证)。

- [ ] **Step 6: --agents 笔误 → 报错停住**

跑:`/xcheck-diag --agents codex,typo <问题>`
Expected: 报错"名字 typo 不在 agents.toml",列出合法 agent 名,**不**开跑。

- [ ] **Step 7: 同构默认 → 警告 + 标注**

跑:`/xcheck-setup default claude`(单 claude)
Expected: setup 打印同构警告但照设。再跑 `/xcheck-diag <问题>` → SUMMARY 顶部出现 "⚠️ 本次为同构" 标注。

- [ ] **Step 8: --clear 回到弹窗**

跑:`/xcheck-setup default --clear`
Expected: 默认集清空(toml 里值行改回注释/删除)。再跑 `/xcheck-diag <问题>` → 弹回多选(分支 A 回归)。

- [ ] **Step 9: 记录结果,不改文件**

8 个场景全过 = 完成。若有未过项,回到对应 Task 修。**不 commit**(本 task 无文件改动)。把结果口头汇报给用户。

---

## Self-Review(已自查)

**Spec coverage**:
- 数据模型 `default_agents` → Task 1 ✓
- setup `default` 子命令(查看/设置/--clear + 名字校验 + 同构警告 + Edit 写 + 去重保序) → Task 2 ✓
- flow.md 第 1 步记 INSTALLED → Task 3 Step 1 ✓
- flow.md 第 2 步三分支(选择源 / 交集 / 分支 A/B/C / 异构标注 / 坏名差异) → Task 3 Step 2 ✓
- 边界条目适用范围 → Task 3 Step 3 ✓
- `--agents` 解析规则(token / 空值 / 剩余文本 / 透传) → Task 4 ✓
- 三个壳 argument-hint → Task 4 ✓
- 验证 8 场景 → Task 5 ✓

**Placeholder scan**: 无 TBD/TODO;每个改文件 step 都给了精确 old/new 字符串。

**Type/命名一致性**:`OVERRIDE_AGENTS`、`CANDIDATES`、`INTER`、`INSTALLED`、`SELECTED`、`default_agents` 跨 Task 一致;`--agents` 解析文案三个壳统一。
