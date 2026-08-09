---
name: xcheck-review
description: 交叉评审 —— 把一个方案/设计/code change(文本或文件路径)喂给本地多个异构 AI agent CLI 各自评审,主会话汇总各家裁决/共识问题/综合建议。手动调用 /xcheck-review。
disable-model-invocation: true
argument-hint: <方案 文本或文件路径>
---

# /xcheck-review — 交叉评审

`$ARGUMENTS` 是用户要评审的方案(文本,或文件路径)。执行:

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中 5 步执行**,本次 **mode = review**。
2. 若 `$ARGUMENTS` 是文件路径,先用 Read 读出全文作为方案内容。
3. 评审外部 prompt:`~/.claude/skills/xcheck/prompts/review.md`。
4. 主会话汇总:`~/.claude/skills/xcheck/prompts/synthesize-review.md`。

铁律同 /xcheck-diag:subagent 只搬运不评判;至少选一个非 claude;opencode 加 timeout;结果落盘;最后交用户拍板,不自动通过/合并。
