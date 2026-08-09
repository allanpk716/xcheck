# xcheck Skill 设计文档

> **文档性质**:`/xcheck` 全局 Claude Code skill 的实现设计。本机(2026-08-09)实测环境后整合交接规格 + 验证结论 + 检测/配置分工讨论而成。
> **范围**:本会话按"做完整个 skill 再实测"(范围 A)。
> **上游交接包**:`<上游交接包>/`(README + 01_设计规格 + 02_调研报告)。本文档是经本机核实、可据此实现的当前版本。
> **日期**:2026-08-09

---

## 0. 一句话定位

全局 skill,把用户给的技术问题或方案,**并行喂给本地几个异构 AI agent CLI**(自动检测、用户每次多选),用 subagent 隔离收集(**只搬运不评判**),主会话做"共识 / 分歧 / 裁决"汇总,**人拍板**。覆盖并行诊断 + 交叉评审两个场景。

---

## 1. 已敲定的设计决策

| 决策点 | 选择 | 理由 |
|---|---|---|
| 触发方式 | **slash 命令主动调**(`disable-model-invocation: true`) | 明确可控、不误触发、省 token |
| 默认 agent | **每次自动检测 + 用户多选** | 不写死组合,永远反映当前机器;选 agent 由人拍板保异构 |
| 检测分工 | 运行命令里 **inline 自动检测**;`/xcheck-setup` 负责**验证 + 登记新 agent** | 检测便宜放每次;"命令能不能跑通"这种重验证单独按需做 |
| 选 agent | **人来多选,不自动选** | 自动选会绕过"≥1 个非 claude"的异构命门 |
| 安装位置 | **全局 `~/.claude/skills/`** | 通用开发工具,所有项目都要能用 |
| 命令结构 | **4 个入口**(3 个 run + 1 个 setup),共享底层 | 三个独立顶层命令(用户原意)+ 一个可选配置命令 |
| 执行模型 | **Claude Code subagent 并行**,主会话汇总 | subagent 隔离外部 CLI 的长输出,省主会话上下文 |

---

## 2. 本机环境(2026-08-09 实测)

**已装三个 CLI**(与交接包那台机器一致):

| CLI | 版本 | 路径 | 非交互调用(已核实) |
|---|---|---|---|
| `claude` | 2.1.202 | `claude` | `claude -p "<prompt>"`(print 模式) |
| `codex` | 0.141.0 | `.../Roaming/npm/codex` | `codex exec "<prompt>"`(或 `codex exec - < file` 走 stdin) |
| `opencode` | 1.17.12 | `.../Roaming/npm/opencode` | `opencode run "<msg>"`(支持 `--format json`、`-m provider/model`) |

**没装**:crush / pi / omp / grok / aider / gemini-cli / qwen / cline / copilot 等。

**实测发现的有用增强(比交接规格更稳)**:
- `codex exec` 支持 **stdin 喂 prompt**(`-` 或无参时读 stdin)→ 彻底绕开 Windows Git Bash 引号转义地狱。
- `opencode run` 支持 `--format json`(稳定解析,不用抓格式化文本)+ `-m provider/model`(可切异构后端,如 `anthropic/claude`、`openai/gpt`、`google/gemini`)→ 单个 opencode 安装本身就能当异构来源。
- `codex` 另有 `codex review`(专用非交互 code review)和 `-c model="..."` 覆盖模型。

**环境**:Windows + Git Bash (MSYS)。注意 MSYS `timeout`、引号转义、路径格式(`/c/` vs `C:\`)、并行用 `&`+`wait` 或后台。

> 检测逻辑必须**动态**(`which`/`where` 查 PATH),不能写死"就这三个";`agents.toml` 要能加新 agent。

---

## 3. 命令入口(4 个)

底层同一套流程(§5),入口不同只是"选哪个 prompt 模板 + 判断什么"。四个都是 SKILL.md,均设 `disable-model-invocation: true`(只手动敲)。

| 命令 | 职责 | 用户输入($ARGUMENTS) | 汇总产出 |
|---|---|---|---|
| `/xcheck-diag` | 并行诊断 | 一个技术问题(报错/异常/失败/为什么不工作) | 各家根因 + **共识根因**(多家都指→强信号)+ **存疑**(只一家说) |
| `/xcheck-review` | 交叉评审 | 一个方案/设计/code change(文件路径或文本) | 各家 AGREE/SUGGEST_CHANGES/DISAGREE + 理由 + **综合裁决建议** |
| `/xcheck` | 自动路由 | 一段模糊描述 | 关键词路由:命中"报错/失败/为什么不/定位/bug/异常"→ diag;命中"方案/评审/设计/行不行/评估/review"→ review;**判不了反问用户** |
| `/xcheck-setup` | 检测+验证+登记(可选) | 无 / `add <name>` | 列出已装 CLI + 逐个"说 hello"测非交互命令能否跑通 + 登记/改 `agents.toml` |

---

## 4. 文件结构

主文件夹 `~/.claude/skills/xcheck/` 放所有共享资源;另三个入口是薄壳 SKILL.md,引用主文件夹里的流程文件。

```
~/.claude/skills/
├── xcheck/                         # 主 skill + 共享资源
│   ├── SKILL.md                    # /xcheck 自动路由入口
│   ├── agents.toml                 # agent → 非交互命令 映射(可扩展)
│   ├── lib/
│   │   ├── flow.md                 # 共用 5 步流程(三个 run 命令引用)
│   │   ├── detect.sh               # 检测脚本(which 查 agents.toml)
│   │   └── subagent-carrier.md     # subagent 搬运工指令模板
│   └── prompts/
│       ├── diag.md                 # 喂给外部 agent 的诊断 prompt
│       ├── review.md               # 喂给外部 agent 的评审 prompt
│       ├── synthesize-diag.md      # 主会话诊断汇总指令
│       └── synthesize-review.md    # 主会话评审汇总指令
├── xcheck-diag/SKILL.md            # 薄壳:引用 xcheck/lib/flow.md + prompts/diag.md
├── xcheck-review/SKILL.md          # 薄壳:引用 xcheck/lib/flow.md + prompts/review.md
└── xcheck-setup/SKILL.md           # 检测+验证+登记
```

> 备选方案(已否决):合成一个 `/xcheck diag|review|setup` 带参数路由的单 skill。否决理由:用户原意要三个独立顶层命令。薄壳引用共享文件既满足三个命令、又不重复逻辑。

---

## 5. 核心流程(5 步,三个 run 命令共用)

```
用户敲 /xcheck-diag(或 -review 或 /xcheck + 自动路由到其一)+ 内容
        │
        ▼
[1] 自动检测:跑 lib/detect.sh,which 查 agents.toml 登记的 CLI → 列出已装的
        │
        ▼
[2] 多选(AskUserQuestion):让用户挑用哪几个
    提醒:至少选一个非 claude,否则同构没意义
        │
        ▼
[3] 并行:每个选中 agent 开一个 subagent(§7.3),
    subagent 内 Bash 调对应 CLI 非交互命令,喂同一份内容,
    各自读输出、忠实精简带回结论(不评判)
        │
        ▼
[4] 收齐:等所有 subagent 完成(或超时),读回各自结论;失败/超时的标注
        │
        ▼
[5] 主会话汇总:读所有结论 → 共识/分歧/裁决建议 → 用户拍板
    原始输出 + 精简结论落盘 .xcheck/<时间戳>/ 备查
```

`/xcheck` 自动路由:在 [1] 之前先判 `$ARGUMENTS` 关键词,决定走 diag 还是 review 流程;判不了用 AskUserQuestion 反问。

---

## 6. 执行模型(subagent 并行)— 关键章节

**不在主会话直接 Bash 起多个 CLI**。每个外部 agent 包一个 Claude subagent(Agent 工具):

```
主会话(综合判断)
  ├─ subagent 1 ──Bash──> codex exec    ──读输出──> 忠实带回"codex 的结论"
  ├─ subagent 2 ──Bash──> opencode run  ──读输出──> 忠实带回"opencode 的结论"
  ├─ subagent 3 ──Bash──> claude -p     ──读输出──> 忠实带回"另一个 claude 实例的结论"
  └─ 一条消息里并发开 N 个(= dispatching-parallel-agents 模式)
     全部完成 ↓
  主会话收齐 → 汇总(共识/分歧/裁决)→ 用户拍板
```

**为什么用 subagent**:
1. **省主会话上下文(最关键)**:CLI 输出动辄几百上千行,直接 Read 进主会话会挤爆上下文。subagent 在独立上下文消化完,只带回精简结论。
2. **并行**:一条消息开多个并发跑。
3. **容错**:某个 CLI 卡/超时(opencode 有此风险),那个 subagent 自己处理返回"超时",不拖垮整体。

**两条铁律(违反就毁了整个 skill 的价值)**:
1. **subagent 只当"搬运工 + 精简",绝对不许评判/合并/补充自己的意见。** 它只摘录目标 agent 的结论并格式化。理由:subagent 也是 Claude,一评判就把异构意见同质化,用户丢掉要的"独立第二意见"。综合判断只在主会话做。
2. **subagent 用便宜模型档(haiku/sonnet)。** 搬运工不需要 opus;主会话汇总才用强模型。

---

## 7. 技术规格

### 7.1 agents.toml(agent → 非交互命令 映射)

```toml
# ~/.claude/skills/xcheck/agents.toml —— skill 据此知道怎么调每个 agent

[agents.claude]
installed_check = "claude"            # which 查的命令名
run_cmd         = "claude -p {prompt}"
input_mode      = "arg"               # arg | stdin(大段 prompt 怎么喂)
needs_timeout   = false

[agents.codex]
installed_check = "codex"
run_cmd         = "codex exec -"      # 走 stdin(prompt 从临时文件喂入)
input_mode      = "stdin"
needs_timeout   = false

[agents.opencode]
installed_check = "opencode"
run_cmd         = "opencode run --format json"   # json 稳定解析
input_mode      = "arg"
needs_timeout   = true                # 已知会卡输入,强制 timeout
timeout_sec     = 480

# 用户装新 agent 在这里加一行,例如:
# [agents.gemini]
# installed_check = "gemini"
# run_cmd         = "gemini -p {prompt}"
# input_mode      = "arg"
```

> **实现提醒**:
> - 大段 prompt 一律先写到临时文件(如 `.xcheck/<ts>/prompt.txt`),再按各 agent 的 `input_mode` 喂(stdin 或 `$(cat file)`)。
> - `input_mode` 的确切喂法(stdin 还是 arg)实现时对每个 CLI 跑通小测试最终确认(`codex` stdin 已验证;`claude -p` / `opencode run` 的 stdin 喂法在 §9 第 2 步实测锁定)。
> - 引号/特殊字符:走 stdin 或临时文件可基本绕开;仍需注意 TOML 里的命令串本身。

### 7.2 检测脚本(lib/detect.sh,第 1 步)

```bash
# 遍历 agents.toml 里所有 installed_check,which/where 查 PATH
# 输出:已装的 agent 名清单(给主会话做多选)
for agent in (agents.toml 的 keys):
    if which <installed_check> 成功:
        输出 "<agent> 已安装,可选"
    else:
        跳过
```

### 7.3 并行 + 超时 + 容错(第 3–4 步)

- 每个 agent 调用包在独立 subagent 里;subagent 内部 Bash 调 CLI。
- 每个 CLI 调用加 `timeout`(默认 300–600s,`agents.toml` 可配);`needs_timeout=true` 的强制加。
- timeout/失败/非零退出 → subagent 返回结构化"该 agent 失败原因",**不中断整体**。
- 并行:主会话一条消息里开 N 个 Agent 工具调用 → 并发(参考 superpowers `dispatching-parallel-agents`)。

### 7.4 输出存放

- 每个 agent 的**原始输出** + subagent **精简结论**落到 `.xcheck/<时间戳>/`(cwd 下)。
- 主会话读 subagent 返回的精简结论做汇总;原始输出留底备查。
- 汇总结果落 ` .xcheck/<时间戳>/SUMMARY.md`。

### 7.5 Prompt 模板(prompts/)

**diag(喂给每个外部 agent)**:
```
你是独立诊断专家。下面是一个技术问题,请独立定位根因,不要假设别人会帮你。
【问题】<用户的问题>
【上下文/复现】<如果用户提供了>
请给出:1) 最可能的根因 2) 支撑证据(代码/日志/推理)3) 置信度(高/中/低)4) 建议的验证或修复方向
```

**review(喂给每个外部 agent)**:
```
你是独立评审员。下面是一个方案,请独立评审,不要假设别人会帮你看。
【方案】<用户给的方案全文/文件路径>
请按以下结构返回:
- 裁决:AGREE / SUGGEST_CHANGES / DISAGREE(三选一)
- bug/风险/遗漏(逐条,带位置和严重度)
- 理由
```

**主会话诊断汇总(synthesize-diag)**:
```
你是综合判断者。下面是 N 个不同 AI agent 对同一问题各自独立给出的诊断。
【各家结论】<subagent 带回的 N 份>
请输出:1) 共识根因(多家都指向的→强信号)2) 分歧(谁和谁不一样)3) 存疑(只一家说的)4) 综合判断建议。
注意:共识不等于正确,保留分歧,最终由用户拍板。
```

**主会话评审汇总(synthesize-review)**:
```
你是综合判断者。下面是 N 个不同 AI agent 对同一方案各自独立给出的评审。
【各家评审】<subagent 带回的 N 份>
请输出:1) 各家裁决一览(谁 AGREE/SUGGEST/DISAGREE)2) 共识问题(多家都指出的→优先修)3) 单家提出的问题(存疑)4) 综合裁决建议。最终由用户拍板。
```

### 7.6 subagent 搬运工指令(lib/subagent-carrier.md)

```
你是搬运工,不是评审员。任务:
1. 用 Bash 执行:<CLI 非交互命令>,prompt 从临时文件喂入(stdin 或 arg,按该 agent 的 input_mode)
2. 等它完成(加 timeout,超时则只返回"该 agent 超时未返回")
3. 读它的全部输出
4. 把它的核心结论原样摘录并格式化成结构化结果(根因/证据/置信度,或 AGREE/SUGGEST_CHANGES/DISAGREE + 理由)
5. 严禁:掺入你自己的判断、合并多个观点、补充意见、润色其立场
6. 只返回那个 agent 的结论本身
```

### 7.7 /xcheck-setup

- **检测**:跑 `lib/detect.sh` 列出已装 CLI。
- **验证**:对每个已装 agent 塞一句极小 prompt(如"用一句话回 hello"),跑非交互命令,加 timeout,报告每个"能跑通 / 超时 / 命令错 / 未登录"。
- **登记**:`add <name>` 引导用户往 `agents.toml` 加新 agent 的 `installed_check` + `run_cmd` + `input_mode`(提醒跑 `--help` 核实命令)。

---

## 8. 边界(不做 + 命门)

**不做(YAGNI)**:
- ❌ worktree 隔离(走轻量文件总线,各 agent 在当前 cwd 跑)
- ❌ 自动裁决 / MAV 打分(主会话汇总 + 人拍板)
- ❌ 多轮辩论(先一次性并行;往返以后再说)
- ❌ 自动成本控制(靠用户挑便宜 agent + subagent 用 haiku/sonnet)
- ❌ GUI / dashboard

**命门(必守)**:
1. **异构**:选 agent 那步提醒用户至少选一个非 claude(否则 Claude 自己审自己,白做)。
2. **subagent 不许评判**:指令里写死;违反则异构意见被同质化,价值归零。
3. **盲评**:各 agent 独立进程、互不可见、并行起 → 自动盲评,防串通。别让它们看彼此输出。
4. **OpenCode 卡输入坑**:`needs_timeout=true` 强制 timeout,卡了当超时处理。
5. **Windows + Git Bash**:`timeout`(MSYS)、引号转义、路径格式、并行 `&`+`wait` / 后台。
6. **主会话上下文保护**:正因为输出长才必须 subagent 隔离,别图省事直接 Read 大段输出。
7. **人在环**:永远只给"建议",不自动改代码/合并/通过。

---

## 9. 开发顺序(本会话按范围 A)

1. **本机核实 CLI 喂法**:对 `claude -p` / `codex exec` / `opencode run` 各跑一句小 prompt,锁定 `input_mode`(stdin/arg)+ 大段 prompt 走临时文件的喂法。(已部分核实,见 §2)
2. 搭 `agents.toml` + `lib/detect.sh`。
3. 先做 **`/xcheck-setup`**:检测 + "说 hello"验证,确认三个 CLI 都能非交互跑通。
4. 做 **`/xcheck-diag`**(主文件夹 `flow.md` + `prompts/diag.md` + `subagent-carrier.md` + 薄壳 SKILL.md):先固定选 codex + opencode 两个**串行**调通链路 → 再加 **subagent 并行 + 精简返回** → 再加 **多选 + timeout 容错**。
5. 做 **`/xcheck-review`**(复用底层,换 `prompts/review.md` + `synthesize-review.md`)。
6. 做 **`/xcheck`** 自动路由。
7. **实测**:一个简单报错做 diag、一个 5 行方案做 review、setup 验证三 CLI 跑通。

---

## 10. 验收标准

- [ ] `/xcheck-setup` 能检测已装 CLI + 逐个验证非交互命令能跑通 + 能登记新 agent
- [ ] `/xcheck-diag` 能自动检测、多选、并行调、汇总"共识/分歧/存疑"
- [ ] `/xcheck-review` 能汇总"各家裁决/共识问题/综合建议"
- [ ] `/xcheck` 能按描述自动路由到 diag 或 review(判不了反问)
- [ ] 选 agent 时提醒"至少选一个非 claude"(全选 claude 给警告,但仍可执行,不强制阻止)
- [ ] 用了 subagent 隔离(主会话不被大段原始输出挤爆)
- [ ] subagent 只搬运不评判(返回的是"那个 agent 的结论",不是 Claude 的加工)
- [ ] OpenCode 卡了不拖死整体(timeout 兜底)
- [ ] 结果落盘备查,人在环(不自动通过)

---

## 11. 参考

- **上游交接包**:`<上游交接包>/`(README + 01_设计规格 + 02_调研报告)
- **学术**:多 agent 框架失败率 [arxiv 2503.13657](https://arxiv.org/pdf/2503.13657);[Anthropic 多 agent 研究系统](https://www.anthropic.com/engineering/multi-agent-research-system)
- **执行模式**:superpowers `dispatching-parallel-agents`(并行 subagent)
- **CLI**:[Codex 非交互模式](https://learn.chatgpt.com/docs/non-interactive-mode)、[OpenCode CLI](https://opencode.ai/docs/cli/)
- **Claude Code skill 机制**:[Skills 文档](https://code.claude.com/docs/en/skills.md)
