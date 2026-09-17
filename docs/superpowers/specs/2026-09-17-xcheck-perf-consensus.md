# xcheck 评审链耗时优化方案（v1 固化稿）

> 共识文档：2026-09-17 会话讨论固化，待异构评审。修订写新文件（`*.rev1.md`），本文正文不动。

## 1. 问题

用户体感：每次评审，单个 agent 执行时间很长。

## 2. 实测基线（2026-09-17，来源：三个项目 .xcheck/ 运行日志）

- agent 实跑（并行，读 1 个方案文件 + 出结构化结论）：
  - codex 通道：近期 2m~3.5m（历史峰值 5m34s）
  - pi 通道：2m16s ~ 5m02s
  - kimi 通道：1m ~ 4m
- 冒烟预检（读一行回显）：codex 45s、pi 30s、kimi 30s —— 单次 spawn 的固定地板
- codex 单轮评审消耗 18,879 tokens（输入仅一个 ~4KB 方案文件）
- 并行派发正常（两家 launch 间隔 6~15s）、从未撞 2700s 超时墙

## 3. 根因（按占比排）

1. **受调 CLI 的全局模型配置重**：codex 通道走本地代理 → glm-5.3 且 model_reasoning_effort="high"；pi 通道默认 claude-opus-4-8。18.9K token 大部分是推理思考。
2. **冒烟串行 + 每轮重跑**：flow 第 2 步主会话前台逐家跑（75s 串行）；第 10 步复审环仍重跑冒烟。
3. **轮次乘数**：收敛 N 轮 = 全链 ×(1+N)。
4. **小额固定开销**：poll 15s 粒度、codex 配置里的失联 MCP 重试、hooks。

## 4. 优化项

- **A（最大杠杆）**：派发 codex 时 per-run 降推理档（run_cmd 追加 `-c model_reasoning_effort=medium`），不动全局配置。预期 codex 3m→2m 上下、token 同步降。代价：单家评审深度略降（主会话查证/实验环节兜底）。
- **B（零风险）**：冒烟并行化（一条消息后台并发，max 代替 sum，75s→45s）；复审环跳过冒烟（同链已验活，每轮省 75s）。
- **C（零风险）**：poll 间隔默认 15s→5s。
- **D（行为变更，待拍板）**：复审环改增量评审——第 2 轮起 prompt 附上轮必改项 + 修订 diff，聚焦验证不整文重评。轮次时间约砍半；风险：可能漏掉修订引入的新问题。折中：diff + 全文都给、指令聚焦。
- **E（零风险）**：清理 codex 失联 MCP 配置、复核 hooks 必要性。

## 5. 验收与回归

- A 需实跑一轮对比评审质量（同一方案 high vs medium 两轮对比）。
- run-agent.sh 改动必跑 `bash xcheck/tests/run-agent.test.sh`（33 断言）。
- 文档同步义务：CHANGELOG / CONTEXT.md / README / AGENTS.md / docs/artifacts.md。

## 6. 不做什么

- 不动「搬运工只搬运 / 单停点 / 实验沙箱」等铁律不变量。
- 不为速度牺牲异构性（≥1 非 claude）。
