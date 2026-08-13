---
name: xcheck-setup
description: 检测本地已装的 AI agent CLI、逐个验证非交互命令能跑通、登记新 agent。手动调用 /xcheck-setup。
disable-model-invocation: true
argument-hint: [add <name> | timeout [N | <agent> N] | default [<n1>,<n2>,... | --clear]]
---

# /xcheck-setup — 检测 / 验证 / 登记 xcheck 的 agent

args = "$ARGUMENTS"。分两种模式:

## 模式 A:无参数 → 检测 + 验证(默认)

1. 跑检测:`bash ~/.claude/skills/xcheck/lib/detect.sh`
   - stdout 里的 agent = 已安装。stderr 里的 = 已登记但没装。
2. 对每个**已安装**的 agent,读 `~/.claude/skills/xcheck/agents.toml` 拿到它的 `run_cmd` / `input_mode` / `needs_timeout` / `timeout_sec`(默认 480)。
3. 逐个**验证**:给该 agent 喂一句极小 prompt(用 Bash 调它的非交互命令):
   - 写一个临时文件 `/tmp/xcheck-verify-<agent>.txt`,内容:`Reply with exactly: hello-from-<agent>`
   - stdin 模式:`timeout <sec> bash -c '<run_cmd> < /tmp/xcheck-verify-<agent>.txt'`
   - arg 模式:`timeout <sec> <run_cmd> "$(cat /tmp/xcheck-verify-<agent>.txt)"`
   - 每个独立跑,互不影响。
   - `<sec>` 取该 agent 的 `timeout_sec`;**verify 是极小 prompt,实务上 90s 已经够**(Task 1 实测三个 CLI 都是单位数秒返回),所以可取 `min(timeout_sec, 90)` 或直接 90。
4. 汇报每个 agent 的结果,判定标准 = **stdout 里是否出现 marker `hello-from-<agent>`**:
   - ✅ 能跑通(贴一句它的输出 —— 即含 marker 的那一行)
   - ⏱️ 超时(`timeout` 杀掉,exit 124)
   - ❌ 命令错(非 0 退出且没超时 —— 贴 stderr 摘要)
   - 🔑 可能未登录(stdout/stderr 出现 `login` / `auth` / `sign in` 字样)
   - **容噪原则**(见仓库 `docs/cli-findings.md` 的 Quirks):
     - **codex** stdout 很吵(启动 banner、`hook:` 生命周期行、非致命 `rmcp::transport` MCP 错误、`codex` 角色标签、reply、`tokens used` 摘要、再回显一遍 reply)。MCP 错误**不算失败**,exit 仍是 0,marker 在 stdout 里就 ✅。marker 一般是最后一个非空行 / `hook: Stop` 前一行。
     - **opencode** stdout 开头有 ANSI 色码 + 一行 profile banner(`> build · glm-5.2`),空行,然后 reply。reply 是最后一个非空行;ANSI 不影响 grep marker。
     - **claude** stdout 干净,整段就是 reply。
5. 给一句总结:哪些可用、哪些要修。提醒:要让 xcheck 有意义,**至少需要 1 个非 claude**(codex / opencode)可用。

## 模式 B:`add <name>` → 登记新 agent

用户要登记一个 agents.toml 里没有的新 CLI(例如 gemini-cli):
1. 先确认它装了:`command -v <name>`。没装就停下来告诉用户。
2. 跑 `<name> --help` **核实**它的非交互命令长啥样(别凭记忆)—— 找出非交互子命令(如 `run` / `exec` / `-p` / `--print`)和 prompt 是走 argv 还是从 stdin 读。
3. 引导用户提供以下字段(填进 agents.toml 的 `[agents.<name>]` 块):
   - `installed_check` —— 一般就是 `<name>` 本身(或绝对路径)
   - `run_cmd` —— 不含 prompt 的命令前缀(如 `gemini -p` / `qwen exec -`)
   - `input_mode` —— `arg`(prompt 作为单个 argv)或 `stdin`(prompt 管道喂入)
   - `needs_timeout` —— 历史上会卡输入的 CLI 写 `true`(参考 opencode)
   - `timeout_sec` —— 显式填(默认 480;也可登记后用模式 C `/xcheck-setup timeout <name> <秒>` 改)。所有 agent 都带 `timeout` 笼子,与 needs_timeout 无关(needs_timeout=true 只是标记"历史会卡"的提示)。
4. 把新 `[agents.<name>]` 块**追加**写进 `~/.claude/skills/xcheck/agents.toml`(用 Edit,别覆盖整个文件)。
5. 立刻按模式 A 验证这个新 agent 能跑通(写 `/tmp/xcheck-verify-<name>.txt`、跑它的 run_cmd、看 marker `hello-from-<name>` 是否出现)。✅ 才算登记成功;否则回退 agents.toml 的修改并报告失败原因。

## 模式 C:`timeout [...]` → 查看 / 设置 agent 最大执行秒数

xcheck 调用 agent 时给 shell 套的 `timeout <sec>` 上限。**只影响 xcheck,不影响 agent 自己单独跑。** 优先级: per-agent `timeout_sec` > `[defaults].timeout_sec`(默认 480)。

3 种调用:

- **`/xcheck-setup timeout`**(无参)→ 读 `agents.toml`,打印当前 `[defaults].timeout_sec` + 每个 agent 的 `timeout_sec`,表格呈现。
- **`/xcheck-setup timeout <N>`**(一个整数)→ 把 `[defaults].timeout_sec` 改成 N(影响所有"没单独配 per-agent timeout"的 agent;per-agent 显式值不受影响)。改前给一句确认提示(N<60 或 N>1800 时警告"异常区间,确认?")。
- **`/xcheck-setup timeout <agent> <N>`**(agent 名 + 整数)→ 把 `[agents.<agent>].timeout_sec` 改成 N(per-agent 覆盖)。agent 名必须在 agents.toml 里存在,否则报错并列出可用 agent。

执行(主会话):
1. 读 `~/.claude/skills/xcheck/agents.toml`。
2. 用 **Edit** 精确匹配改对应行(`timeout_sec = <旧值>` → `timeout_sec = <新值>`),**不要** Write 覆盖整个文件(会丢注释/格式)。改 `[defaults]` 就匹配 `[defaults]` 块下那行;改 per-agent 就匹配 `[agents.<name>]` 块下那行。
3. 改完回显新配置(同无参视图),并提示"下次 /xcheck 即生效"。
4. N 必须是正整数;非整数报错不改。

## 模式 D:`default [...]` → 查看 / 设置 / 清空默认 agent 集

设了默认集之后,`/xcheck`(及 diag/review)会**直接拿这组跑,跳过每次的勾选弹窗**;没设就回退到每次弹多选。详见 `~/.claude/skills/xcheck/lib/flow.md` 第 2 步。优先级:`--agents` 临时参数 > `default_agents` > 每次弹窗。

3 种调用:

- **`/xcheck-setup default`**(无参)→ 读 `agents.toml` 的 `[defaults].default_agents`。有值就表格/列表呈现当前默认集;没设(字段缺失/空)就提示"未设默认,每次运行会弹多选"。
- **`/xcheck-setup default <n1>,<n2>,...`**(逗号分隔的名字)→ 设置默认集。空格忽略;同名去重、保序(首次出现为准)。
- **`/xcheck-setup default --clear`**(或设空字符串 `default ""`)→ 清空默认集(回到每次弹窗),提示"已清空"。

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
