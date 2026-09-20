# 票 05 · CHANGELOG 0.24.0 + README/AGENTS 同步

## What to build
1. **CHANGELOG.md** 新增 `## [0.24.0] - 2026-09-20` 段(格式仿 0.23.0:一段总述 + ### Changed/Added + ### Scope/本版边界):
   - 总述:泳道失败从"立即 paused"改为**有界重试**(grill-with-docs 设计访谈 + 交互评审三轮收敛 + 夜链评审两轮 + D13 确认;决策:ADR 0009,显式取代 ADR 0007 失败处理条款)
   - Added/Changed 要点:单元级重试梯(60s→×2→封顶 15min,`night_retry_max` 默认 5、0=关闭)、先还原再重派、互斥四态→五态、占位不回填、同波错峰 i×30s(含续跑重赋规则)、NIGHT 追记行(阶段前缀 impl/review/终局review + 检出序号,实际派发时落盘)、整档重等/计数重建、耗尽 paused(带阶段)与终局 waiting、retries=k 尾注只记实施位;无全局预算/独立冷却/自动升降并发
   - Scope:静态契约断言(未压测真实 429);帽外段(冒烟/评审 fan-out)仍零重试;429 形态探针为后续任务
   - 离线测试计数更新(night-parallel 新断言数以票 03 实际为准;全绿)
2. **README.md / AGENTS.md**:只在与 0.23 lanes 描述相邻的适当位置各加 1–3 句(不重排结构):夜链实施段失败走有界重试(一句机制概览 + `night_retry_max` 旋钮 + ADR 0009 指引);若有"失败即 paused"旧表述,改为"重试耗尽才 paused"。
不改动两文件其余内容;版本号若在 README/AGENTS 出现(如 0.23)按需升 0.24。

## 验收标准
- [ ] CHANGELOG 含 [0.24.0] 段,格式/双语小节与 0.23.0 一致,内容与票 01–04 实际落地一致
- [ ] README.md、AGENTS.md 各含重试概览句与 night_retry_max、ADR 0009 引用
- [ ] 无"失败即 paused"残留旧表述(与重试语义冲突处)
- [ ] 不虚报:测试计数、压测边界如实(引用票 03 实际结果)

## Blocked by
01, 02, 03, 04

## 涉及路径
- CHANGELOG.md
- README.md
- AGENTS.md

## 副作用声明
只读验证(grep);不联网;不改 .xcheck/

## decision_refs
D1 D4 D9 D13(spec 全文)

## review_blocks
无
