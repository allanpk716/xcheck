# 票 03 · night-parallel.test.sh 重试契约断言

## What to build
在 `xcheck/tests/night-parallel.test.sh` 追加一节 `== 有界重试 ==` 静态布线断言(沿用文件头部 contains/absent 先例,读 Markdown/配置断言规则在盘,**不跑真实时钟**),断言 `xcheck/lib/flow.md`(票 01 落地后)与 `xcheck/agents.toml`(票 02 落地后)包含:
1. 触发与四态不触发(如:`四态`/`不触发重试`)
2. 还原次序:失败检出→三步还原→才进等待(如 `还原完成`+`git reset -- <票路径>` 既有断言衔接)
3. 互斥五态(扩展现有"路径互斥含全部占径状态"断言,或新增含 `重试等待` 的断言)
4. 占位不回填(`占住.*泳道位|占位.*不回填`)
5. 梯子参数与口径(`60s`、`封顶 15min|15min\(封顶\)`、`1800s|恰 30 分钟`)
6. 错峰两情形(正常:`调度循环.*失败集合`+`i 从 0 起`;续跑:`检出序号升序重赋|按.*检出序号.*重赋 i`)
7. 三种首行记法(`票 NN impl retry`、`票 NN review retry`、`终局review retry`,且 `检出序号=m`)
8. 实际派发时落盘(`实际派发`)
9. 整档重等(`整档重等`)
10. 计数重建不重置(`重建.*计数|计数从追记行重建`)
11. retries=k 只记实施位(`retries=k`+`只记实施位`)
12. 耗尽 paused 带阶段(`重试耗尽`+`阶段=`)
13. 终局耗尽 waiting、finish 不勾(`终局评审重试耗尽|终局review.*耗尽` 与既有 waiting 衔接)
14. 不新增台账状态(absent:票台账行枚举不变,即不出现 `retrying` 之类新状态词)
15. agents.toml:`night_retry_max = 5` 与注释(`0 = 关闭|0=关闭`)
末尾保持既有 PASS/FAIL 汇总与退出码逻辑不变;断言数量与命名风格与现文件一致(`printf '== … ==\n'` 分节)。

## 验收标准
- [ ] 新增断言覆盖上述 15 组要点(允许合理合并,不漏语义)
- [ ] `bash xcheck/tests/night-parallel.test.sh` 退出码 0、无 FAIL(依赖票 01/02 已落地)
- [ ] 既有断言零回归(不删不改既有 contains/absent 行,除非与其新增语义直接冲突——如四态扩五态的断言更新,需在票内说明)
- [ ] 文件头注释的断言计数(如有)同步

## Blocked by
01, 02

## 涉及路径
- xcheck/tests/night-parallel.test.sh

## 副作用声明
运行 `bash xcheck/tests/night-parallel.test.sh`(本地、只读仓库文件、写 stdout)为独占验证命令;不联网;不改 .xcheck/

## decision_refs
D4 D5 D8 D12 D13(spec §Testing Decisions 全清单)

## review_blocks
无
