---
name: xcheck-setup
description: 检测本地已装的 AI agent CLI、逐个验证非交互命令能跑通、登记新 agent。手动调用 /xcheck-setup。
disable-model-invocation: true
argument-hint: [add <name>]
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
   - `timeout_sec` —— 仅在 `needs_timeout = true` 时填(默认 480)
4. 把新 `[agents.<name>]` 块**追加**写进 `~/.claude/skills/xcheck/agents.toml`(用 Edit,别覆盖整个文件)。
5. 立刻按模式 A 验证这个新 agent 能跑通(写 `/tmp/xcheck-verify-<name>.txt`、跑它的 run_cmd、看 marker `hello-from-<name>` 是否出现)。✅ 才算登记成功;否则回退 agents.toml 的修改并报告失败原因。
