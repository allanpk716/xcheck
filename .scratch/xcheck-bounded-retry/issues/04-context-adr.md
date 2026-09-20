# 票 04 · CONTEXT 词条 + ADR 0009 + ADR 0007 修订指针

## What to build
1. **新词条**(CONTEXT.md,按文件既有词条格式:词条名 + 中英对照 + 一段定义 + `_Avoid_` 行):**有界重试(bounded retry)**——实施段派发单元失败后的当夜自动恢复机制:先还原再等待、递增梯(60s→×2→封顶 15min,每单元 N=night_retry_max,0=关闭)、占位不回填、同波错峰 i×30s、轨迹落盘可断链重建、耗尽 paused/终局 waiting;无全局预算与独立冷却,不自动升降并发。_Avoid_: 把重试当成自动升降并发(ADR 0007/0008 否决的是配置自动升降,重试是运行时有界异常响应)、把 retries=k 当新台账状态、把帽外段(冒烟/评审 fan-out)当成已覆盖。
2. **同步改写**「就绪集与泳道(ready set / lane)」词条:互斥四态改五态(+重试等待中含已还原未重派,视同在跑),提一句"泳道失败经有界重试,耗尽才 paused"。
3. **新 ADR**:`docs/adr/0009-bounded-retry-on-lane-failure.md`,按 0007/0008 的文件风格(标题行=决策一句 + 正文动机与决定 + Considered Options + Consequences):
   - 决策标题:泳道失败改有界重试:单元梯 60s×2 封顶15min/night_retry_max,先还原再重派、占位不回填、错峰 i×30s、轨迹落盘断链重建;耗尽 paused、终局 waiting
   - 动机:2026-09-19 十并行 429 集体阵亡(CLI 秒级重试被打穿)+ 多项目共用账号使分钟级争抢成常态;现行"失败即 paused 丢一晚"
   - **显式取代声明**:"经用户确认(D1/D13),本决策**取代 ADR 0007 中『落者超时/失败记 paused,不拖队』条款(仅该条款)**;ADR 0007 的并发帽与调度决策不受影响" + 与 ADR 0007/0008 的边界句:配置(lanes)不自动升降 vs 运行时有界异常响应
   - Considered Options:维持失败即 paused / 固定短间隔(1min×10) / 全局预算+独立冷却 / 本案——各一句否决理由(对应用户否决史:多项目争抢是时间性非次数性)
   - Consequences:互斥五态、整档重等、检出序号排序键、已知残余窗口(失败发生→还原完成落盘,每次崩溃至多多一次尝试;口径以 D12 修订为准——F8 标注)、帽外段仍零重试等实证再议、二版退出码白名单依赖 429 探针
   - 顺带在 **ADR 0007 文首**加一行修订指针:"> 修订:本 ADR 的『落者超时/失败记 paused,不拖队』条款已被 [ADR 0009](0009-bounded-retry-on-lane-failure.md) 取代(2026-09-20);其余条款不受影响。"——不改 0007 其余内容。
4. CONTEXT.md 版本边界行(第 7 行附近"决策记录见 ADR 0004-0008")更新为含 0009。

## 验收标准
- [ ] CONTEXT.md 新增「有界重试」词条(含 _Avoid_),「就绪集与泳道」词条改五态+重试一句
- [ ] ADR 0009 存在,含取代声明(点名字句)、边界句、Considered Options、Consequences、F8 口径标注
- [ ] ADR 0007 文首含修订指针一行,其余内容未动(diff 仅 +1 行)
- [ ] 版本边界行更新含 0009
- [ ] 文风与既有词条/ADR 一致(中文紧凑、无空格装饰)

## Blocked by
无,可立即开始

## 涉及路径
- CONTEXT.md
- docs/adr/0009-bounded-retry-on-lane-failure.md
- docs/adr/0007-event-driven-ticket-scheduling.md

## 副作用声明
只读验证(grep/diff);不联网;不改 .xcheck/;不动 docs/adr/ 其他文件

## decision_refs
D1 D9 D12 D13(spec §Implementation Decisions·ADR 治理节)

## review_blocks
无
