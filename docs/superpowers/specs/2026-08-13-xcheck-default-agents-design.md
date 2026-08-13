# xcheck 默认 agent 集设计

- 日期:2026-08-13
- 范围:`xcheck-setup` 增设"默认 agent 集";`flow.md` 第 1/2 步改造,设了默认就跳过每次勾选。
- 状态:设计已与用户逐节确认。

## 背景与动机

xcheck 当前每次运行,`flow.md` 第 2 步都弹 `AskUserQuestion(multiSelect)` 让用户从已装 agent 里勾选,并强制至少 1 个非 claude。用户的核心诉求:**预设一组默认 agent,以后 `/xcheck` 直接拿这组跑,省掉每次勾选**,偶尔想换再加临时参数。

## 关键决策(已与用户确认)

1. **交互模型**:设了默认 → 跳过弹窗直接用默认;没设默认 → 回退到现在的每次弹多选。
2. **存储**:写进 `agents.toml` 的 `[defaults]` 块,加 `default_agents` 字段(与现有 `timeout_sec` 同处,单文件,改即生效)。
3. **异构校验**:setup 设默认时,同构(全 claude 或 < 2 个)→ **警告但允许**,不拦。运行时同构 → SUMMARY 顶部标注,不拦。
4. **默认集里有缺失**:默认集里某家当前未装/未登录 → **弹窗问**(单选:用剩余默认集跑 / 重新选弹多选),不自动剔除硬跑,也不直接停。
5. **临时换集**:给三个壳加 `--agents a,b,c` 参数,本次有效,不改默认,优先级最高。

## 数据模型(agents.toml 扩展)

在现有 `[defaults]` 块加一个可选字段:

```toml
[defaults]
timeout_sec = 1800
default_agents = ["claude", "codex", "kimi"]   # 可选;不存在/空 = 未设默认 → 每次弹窗
```

- 字段**可选**。没这行 / 空数组 = 未设默认,flow.md 第 2 步回退每次弹窗(完全向后兼容)。
- 名字必须对得上 `agents.toml` 里某个 `[agents.<name>]` 的 key(小写一致)。
- 这是本机配置随 git 仓库走;多机器拉同一仓库时 `default_agents` 会随仓库走 —— 与现有 `timeout_sec` 一致,不引入新问题。出厂态保持"未设"(不在 toml 里写示例值)。

## `/xcheck-setup default` 子命令

与现有 `timeout` 子命令同构,三种调用:

| 调用 | 动作 |
|------|------|
| `/xcheck-setup default` | 读 `[defaults].default_agents`,表格呈现当前默认集;没设就提示"未设默认,每次运行会弹多选" |
| `/xcheck-setup default <n1>,<n2>,...` | 设置默认集(逗号分隔,空格忽略) |
| `/xcheck-setup default --clear` | 清空默认集(删 `[defaults]` 下的 `default_agents` 行),回到每次弹窗 |

**设置时的校验与处理(主会话执行)**:

1. **名字合法性**:每个名字必须存在于 `agents.toml` 的 `[agents.<name>]`。不存在的 → 报错,列出可用 agent 名,**不改文件**。
2. **异构校验(警告但允许)**:若设的全是 claude(或 `count < 2` / 无非 claude),打印警告"⚠️ 默认集为同构/单 agent,异构价值未体现,仍照设"。**不拦**,照常写入。
3. **写文件**:用 **Edit** 精确匹配改 `[defaults]` 块下那行 —— 与 `timeout` 模式完全一样,不 Write 覆盖(保注释/格式)。
   - 首次设置(文件里还没 `default_agents` 行)→ 在 `[defaults]` 块里 `timeout_sec` 行下方插入新行。
   - 已有 → 替换值。
   - `--clear` → 删掉那行(或改为 `default_agents = []`)。
4. **改完回显**新配置(同无参视图),提示"下次 /xcheck 即生效"。
5. **去重 + 保序**:`claude,codex,claude` → `["claude", "codex"]`,按首次出现顺序。
6. **setup 阶段不校验"已装"**:默认集里的 agent 是否已装,由运行时(`flow.md` 第 1 步 detect)判定。setup 只保证名字在 toml 里合法。

## flow.md 第 1/2 步改造(核心交互)

### 第 1 步(自动检测)末尾新增

跑完 `detect.sh` 后,除了原来的"已装 < 2 个就停",把**当前已装 agent 清单**记为 `INSTALLED` 列表,供第 2 步用。

### 第 2 步整段重写为三分支 + 统一选择源

**先定选择源(优先级)**:

```
SELECT_SOURCE = OVERRIDE_AGENTS   ← 若 --agents 指定了(最高优先)
             ?? DEFAULTS          ← 否则 [defaults].default_agents
             ?? null              ← 都没有 → 分支 A
```

然后取交集并分支:

```
SELECT_SOURCE
     │
     ├─ null(未设默认且无 --agents)──→ 【分支 A】沿用现在的行为:弹多选(multiSelect),提醒≥1非claude
     │
     └─ 非空候选集 CANDIDATES ──→ 取交集: SELECTED = CANDIDATES ∩ INSTALLED
                                    │
                                    ├─ 交集 = CANDIDATES(全在)──→ 【分支 B】跳过弹窗,直接用 SELECTED
                                    │
                                    └─ 交集 ⊊ CANDIDATES(有缺失)──→ 【分支 C】弹窗问
```

- **分支 A(无候选集)**:完全不变 —— 现有的 `AskUserQuestion(multiSelect)`、"全 claude 二次确认"、记 `SELECTED`。向后兼容的兜底。
- **分支 B(候选集齐全)**:跳过 `AskUserQuestion`,直接 `SELECTED = 候选集`。这是用户要的"省掉每次勾选"。
- **分支 C(候选集有缺失)**:弹 `AskUserQuestion`(**单选**,非 multiSelect),两选项:
  - 选项 1:`用剩余默认集跑(<列出还在的 N 家>)` → `SELECTED = 交集`
  - 选项 2:`重新选(弹多选)` → 走分支 A 的完整多选(列所有已装 agent,跟分支 A 一样,可勾候选集之外的)
  - 弹窗文本写清"候选集里有 X 家当前未装/未登录:<名字>"。

### 异构校验(放在 SELECTED 定下之后)

- **分支 B / 分支 C 选 1**:若最终 `SELECTED` 是同构(全 claude 或 < 2),在 SUMMARY 顶部标注"⚠️ 本次为同构,异构价值未体现"。**不拦**(setup 阶段已警告、或用户显式 `--agents` 要的,运行时再拦等于推翻用户决定)。
- **分支 A 多选**:维持现在"全 claude 二次确认"逻辑不变。
- **`--agents` 同构**:同分支 B,只标注不拦。

### 第 3 步起不变

`SELECTED` 定了之后,套模板、落盘、并行派 subagent、收齐、汇总,全照旧。

## 坏名处理(防御性差异)

- **`--agents` 里的名字不在 toml(笔误)**:flow.md **报错停住**,列出合法 agent 名。理由:用户刚敲的显式指令,名字错了大概率是笔误,立刻停比弹窗省事。
- **默认集里的坏名(toml 被手改坏、setup 没拦住的边缘情况)**:**防御性剔除**该名,走交集 + 分支 C,不崩。理由:setup 已校验过,这是边缘情况,运行时别因为一个坏名卡死整个流程。

## --agents 参数解析与透传

三个壳(`/xcheck`、`/xcheck-diag`、`/xcheck-review`)都加。

**解析规则(壳执行,先做)**:

1. 在 `$ARGUMENTS` 里找子串 `--agents`,其后的值 = **下一个空白分隔的 token**(到第一个空格为止),必须是纯逗号串(如 `codex,kimi`),不含空格。
2. 取出该 token 后,把 `--agents <token>` 这一段从 `$ARGUMENTS` 删掉,**剩余文本**作为真正的用户输入(走分类/摄入/套模板)。
3. token 拆成名字列表 → 走"坏名处理"(`--agents` 名字不在 toml → 报错停住)。
4. **token 为空**(用户敲了 `--agents` 但后面紧跟空格/换行,没给名字)→ 视为**未指定 `--agents`**,忽略该参数,回退到默认集/分支 A。不报错(留宽容)。
5. 约定提示:agent 名都是小写英文无空格,所以 `--agents <token>` 后必须直接接用户输入,**不要写 `--agents codex, kimi 问题` 这种带空格的逗号列表**(会被解析成 `codex,` + 剩余)。文档/argument-hint 里写清楚这点。

**透传**:

6. 壳在转派给 flow.md 的指令里设变量 `OVERRIDE_AGENTS = ["codex", "kimi"]`(仅当 token 非空且名字全合法)。
7. 三个壳的 `argument-hint` 都加提示,如 `/xcheck-diag` → `[--agents a,b,c] <问题>`。
8. `--agents` 优先级最高,盖过默认集;临时一次,不改默认。

## 异常与边界清单

| 场景 | 处理 |
|------|------|
| `default_agents` 字段缺失 / 空数组 | 分支 A,弹多选(向后兼容,旧 toml 不破坏) |
| 默认集里某家当前未装/未登录 | 分支 C 弹窗:用剩余 / 重新选 |
| 默认集整组都没装(全卸了) | 交集为空 → 视为"未设默认",回退分支 A 弹多选 |
| 默认集同构 | setup 警告但允许;运行时 SUMMARY 标"⚠️ 同构",不拦 |
| `--agents` 名字笔误(不在 toml) | 报错停住,列合法 agent 名 |
| `--agents` 名字合法但当前没装 | 走交集 + 分支 C(跟默认集缺失同处理) |
| `--agents` 后没给名字(token 空) | 视为未指定,忽略该参数,回退默认集/分支 A |
| `--agents` + 默认集都没设 | `--agents` 优先;但 `--agents` 为空则回退分支 A |
| toml 被手改出坏 `default_agents`(非法名) | 防御性剔除该名,走交集;不崩 |
| `default` 子命令设空字符串 | 等同 `--clear`,提示"已清空" |
| 用户对话中途改主意想加/换 | 现有 flow.md 边界"回第 2 步重选"保留,适用所有分支 |

## 改动范围

1. `xcheck/agents.toml` —— 文档注释加 `default_agents` 字段说明(不加示例值,保出厂"未设"态)。
2. `xcheck-setup/SKILL.md` —— 加"模式 D:`default [...]`"一节(同构 timeout 写法);`argument-hint` 加 `default`。
3. `xcheck/lib/flow.md` —— 第 1 步末尾记 `INSTALLED`;第 2 步整段重写成三分支 + 统一选择源;边界条目补"适用 --agents/默认/多选"。
4. `xcheck/SKILL.md`、`xcheck-diag/SKILL.md`、`xcheck-review/SKILL.md` —— 三个壳加 `--agents` 解析与透传,改 `argument-hint`。

## 验证方式

本次只设计不执行。首次实跑**开新会话**(junction 活的,但调用时读文件,开新会话确保吃到新逻辑)。实跑清单(留给实现后):

1. 未设默认 → 弹多选(回归旧行为)。
2. 设默认集全装 → 跳过弹窗直跑。
3. 设默认集缺一家 → 弹窗两选项(用剩余 / 重新选)。
4. `--agents codex,kimi` 临时换集 → 用这组跑,默认集不动。
5. `--agents 笔误名` → 报错停住,列合法 agent 名。
6. 设同构默认集 → setup 警告但允许;运行时 SUMMARY 顶部标"⚠️ 同构"。
7. `--clear` → 清空,回到每次弹窗。
8. 默认集整组都没装 → 回退分支 A 弹多选。

## 不做(YAGNI)

- **不分 mode 存默认**:diag 和 review 共用同一组默认 agent,不区分。理由:agent 选择与 mode 正交,额外复杂度无收益。
- **不做"每个 agent 的 verify 状态缓存进默认集"**:setup 的 verify 是一次性快照,运行时 detect 才是真相,默认集不缓存 verify 结果。
- **不给 `--agents` 加"追加/删除"语法**(如 `--agents +codex`):YAGNI,要换就直接列完整集。
