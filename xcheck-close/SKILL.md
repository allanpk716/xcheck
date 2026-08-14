---
name: xcheck-close
description: 评审闭环 —— 对 /xcheck-review 已产出三类分级的反馈做闭环处置:逐条证实第一类、批准后执行第二类验证实验、汇总必改清单、修订方案(新文件不动原稿)、可选复审收敛。手动调用 /xcheck-close。
disable-model-invocation: true
argument-hint: [--agents a,b,c] [<ts>]
---

# /xcheck-close — 评审闭环

`$ARGUMENTS` 可空。可选两种参数,解析顺序:先 `--agents` 后 `<ts>`。

### --agents(复审轮临时换集,可选)

规则同三壳:其值 = 紧跟 `--agents` 后的**一个空白分隔 token**(纯逗号串,如 `codex,kimi`,**不含空格**)。把 `--agents <token>` 从 `$ARGUMENTS` 删掉;token 非空 → `OVERRIDE_AGENTS = <拆成的名字列表>`(名字不在 agents.toml → **报错停住**,列出合法名);token 为空 → 当没敲。**只影响复审轮的 agent 集**,不改默认、不影响本轮其余阶段。

### <ts>(指定要闭环的那次评审,可选)

剩余 `$ARGUMENTS` 若是一个形如 `20260814-143012` 的 token → `TARGET_TS = <它>`;否则 `TARGET_TS` 不设(= 取最新)。多个 token / 看不懂的参数 → 反问用户,不猜。

1. 解析完设好 `OVERRIDE_AGENTS`(若有)与 `TARGET_TS`(若有)。
2. 读 `~/.claude/skills/xcheck/lib/close-flow.md`,**严格按其 C0~C5 执行**。你不重新实现闭环逻辑,只做参数解析 + 转派。

铁律(同整套 xcheck):subagent 只搬运不评判;实验不改业务代码、不联网外呼、不部署;修订只写新文件(`<原名>.rev<m>.md`)、原稿不动;每个有成本/副作用的关口用户拍板;结果落盘 `.xcheck/`(已 gitignore)。
