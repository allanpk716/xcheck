# 票 02 · agents.toml 新增 night_retry_max 旋钮

## What to build
在 `xcheck/agents.toml` 的 `[defaults]` 段新增 `night_retry_max = 5`,并写注释说明(仿照同文件 `night_parallel_lanes` 注释风格):
- 语义:实施段派发单元(实施位/票级评审/终局 review)的重试次数上限,每单元独立计;0 = 关闭重试、失败即 paused(回落现行行为)。
- 梯形写死于契约不随本值变化:60s 起跳、×2 递增、封顶 15min;额外等待合计恰 30 分钟(1800s)+ 各次尝试时长。
- 引用:ADR 0009;同波失败按检出顺序错峰 i×30s。
- 手改本文件即可(无 /xcheck-setup 模式)。
不改动其他键、其他段落、其他文件。

## 验收标准
- [ ] `[defaults]` 段含 `night_retry_max = 5`
- [ ] 注释覆盖:每单元独立、0=关闭回落现行、梯形 60s/×2/15min 写死、1800s 口径、ADR 0009 引用
- [ ] TOML 语法有效(`python -c "import tomllib;tomllib.load(open('xcheck/agents.toml','rb'))"` 或等价校验通过;若本机无 tomllib,用肉眼结构校验并说明)
- [ ] 不动 night_parallel_lanes / timeout_sec / default_agents 等既有键

## Blocked by
无,可立即开始

## 涉及路径
- xcheck/agents.toml

## 副作用声明
只读验证(TOML 解析);不联网;不改 .xcheck/

## decision_refs
D4 D13(spec §Implementation Decisions 梯子节)

## review_blocks
无
