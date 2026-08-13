---
name: xcheck-review
description: 交叉评审 —— 把一个方案/设计/code change(文本或文件路径)喂给本地多个异构 AI agent CLI 各自评审,主会话汇总各家裁决/共识问题/综合建议。手动调用 /xcheck-review。
disable-model-invocation: true
argument-hint: [--agents a,b,c] <方案 文本或文件路径>
---

# /xcheck-review — 交叉评审

`$ARGUMENTS` 是用户要评审的方案(文本,或文件路径)。执行:

### --agents 临时换集(可选)

若 `$ARGUMENTS` 含 `--agents`:

1. 其值 = 紧跟 `--agents` 后的**一个空白分隔 token**(到第一个空格止),须是纯逗号串(如 `codex,kimi`),**不含空格**。
2. 把 `--agents <token>` 从 `$ARGUMENTS` 删掉,**剩余文本**作为真正要评审的方案。
3. token 非空 → 设 `OVERRIDE_AGENTS = <拆成的名字列表>`;token 为空 → 忽略该参数。
4. 转派 flow.md 时带上 `OVERRIDE_AGENTS`(笔误报错停住)。

`--agents` 优先级最高,盖过默认集;本次有效,不改默认。

1. 读 `~/.claude/skills/xcheck/lib/flow.md`,**严格按其中的「第 0 步(可选摄入)+ 5 步」执行**,本次 **mode = review**。
2. 若 `$ARGUMENTS` 是文件路径,先用 Read 读出全文作为方案内容;若第 0 步摄入运行了,则用确认后的事实清单作为 `{{PROPOSAL}}` 内容(见 `lib/context-intake.md`)。
3. 评审外部 prompt:`~/.claude/skills/xcheck/prompts/review.md`。
4. 主会话汇总:`~/.claude/skills/xcheck/prompts/synthesize-review.md`。

铁律同 /xcheck-diag:subagent 只搬运不评判;至少选一个非 claude;opencode 加 timeout;结果落盘;最后交用户拍板,不自动通过/合并。
