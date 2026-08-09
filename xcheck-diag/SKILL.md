---
name: xcheck-diag
description: 并行诊断 —— 把一个技术问题(报错/异常/失败/为什么不工作)并行喂给本地多个异构 AI agent CLI,各家独立定位根因,主会话汇总共识/分歧/存疑。手动调用 /xcheck-diag。
disable-model-invocation: true
argument-hint: <技术问题>
---

# /xcheck-diag — 并行诊断

`$ARGUMENTS` = 用户要诊断的技术问题(报错描述 / 异常 / "为什么这个不工作" 等)。本次 **mode = diag**。

执行:

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中的 5 步执行**(检测 → 多选 → 并行派 subagent → 收齐落盘 → 主会话汇总)。本次 mode = diag。
2. 诊断用的外部 prompt 模板:`~/.claude/skills/xcheck/prompts/diag.md`(填 `{{USER_INPUT}}` = `$ARGUMENTS`,`{{CONTEXT}}` = 用户额外给的上下文或删掉)。
3. 主会话汇总模板:`~/.claude/skills/xcheck/prompts/synthesize-diag.md`。
4. 每个 subagent 的指令 = `~/.claude/skills/xcheck/lib/subagent-carrier.md`(填好该 agent 的 AGENT_NAME / CLI_CMD / INPUT_MODE / PROMPT_FILE / TIMEOUT / RESULT_SHAPE=diag 结构)。

## 铁律(见 flow.md 与 agents.toml)

- subagent **只搬运、不评判**(见 subagent-carrier.md);综合判断只由主会话做。
- 第 2 步多选时**至少选一个非 claude**(codex / opencode);全 claude 同构要二次确认并在 SUMMARY 里标注。
- 派 subagent 用**便宜模型**(haiku 或 sonnet),**一条消息里并行**派出去。
- opencode / 任何 needs_timeout=true 的 agent 必须加 timeout。
- 成败判定看**退出码**,codex 的 MCP/banner/hook 噪声 ≠ 失败(见 subagent-carrier.md)。
- 结果全部落盘到 `<cwd>/.xcheck/<时间戳>/`(prompt.txt、<agent>.raw.out、<agent>.summary.md、SUMMARY.md)。
- 最后**交用户拍板**,原样输出:"**以上是建议,共识 ≠ 正确,最终你拍板。**" 绝不自动改代码。
