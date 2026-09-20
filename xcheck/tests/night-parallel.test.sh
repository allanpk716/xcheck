#!/usr/bin/env bash
# 0.22 并行实施调度契约 + 0.23 并发帽(ADR 0008) + 0.24 有界重试(ADR 0009)的静态布线检查(读 Markdown 断言规则在盘;不含语义回放)。
# bash xcheck/tests/night-parallel.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }
contains() {
  local label="$1" file="$2" pat="$3"
  if grep -qE -- "$pat" "$ROOT/$file" 2>/dev/null; then ok "$label"; else bad "$label ($file 缺 /$pat/)"; fi
}
absent() {
  local label="$1" file="$2" pat="$3"
  if grep -qE -- "$pat" "$ROOT/$file" 2>/dev/null; then bad "$label ($file 不应含 /$pat/)"; else ok "$label"; fi
}

FLOW=xcheck/lib/flow.md
CARRIER=xcheck/lib/subagent-carrier.md
DELIVERY=xcheck/lib/night-delivery.md
TOML=xcheck/agents.toml

printf '== 就绪集与互斥 ==\n'
contains '就绪集依赖条件' "$FLOW" '依赖票全 ?complete|依赖全complete'
contains '路径互斥含全部占径状态' "$FLOW" '在跑票.*paused未清理票.*committed-unreviewed票.*rework票|committed-unreviewed.*/ ?rework'
contains '脏区不相交停车条件' "$FLOW" '与脏区.*相交的票记.*paused|脏区.*停靠'
contains '路径比较先规范化' "$FLOW" '统一正斜杠、去|路径比较先规范化'
contains '事件驱动重算' "$FLOW" '任一票落地事件触发重算'

printf '== 提交纪律 ==\n'
contains '泳道禁git写入' "$FLOW" '严禁 .git add/commit|严禁 `git add`/`git commit`/`git push`'
contains '按票pathspec提交' "$FLOW" 'git commit --only <票涉及路径>|git commit --only'
contains '提交带--no-verify' "$FLOW" 'commit --only.*--no-verify|--no-verify.*commit --only'
contains '每票即推' "$FLOW" '每票即推|每票提交后即'
contains 'carrier泳道禁令' "$CARRIER" '严禁执行 git add / git commit / git push'
contains 'carrier模板前缀稳定' "$CARRIER" '前缀.*稳定|模板前缀保持'

printf '== 失败与恢复 ==\n'
contains '失败票三步还原' "$FLOW" 'git reset -- <票路径>|reset -- <票路径>'
contains 'checkout BASE 还原' "$FLOW" 'checkout <BASE> -- <票路径>'
contains 'clean -fd 清新增' "$FLOW" 'clean -fd -- <票路径>'
contains 'committed-unreviewed状态' "$FLOW" 'committed-unreviewed'
contains 'rework追加提交' "$FLOW" '追加修复提交|追加修复 commit'
contains 'rework上限2轮' "$FLOW" 'scoped re-review 上限 2 轮|re-review.*2 轮'

printf '== 发布与链接 ==\n'
contains '不自动开PR' "$FLOW" '不自动开 ?PR|不自动开PR'
contains '脱敏先行' "$FLOW" '脱敏'
contains 'web_base存在' "$FLOW" 'web_base'
contains 'delivery同款不自动开PR' "$DELIVERY" '不自动开 ?PR|不自动开PR'
contains 'delivery脱敏' "$DELIVERY" '脱敏'
absent 'flow无旧PR助手引用' "$FLOW" 'night-pr'

printf '== 配置与档位 ==\n'
contains 'lanes配置存在' "$TOML" 'night_parallel_lanes'
contains 'lanes默认3(toml)' "$TOML" 'night_parallel_lanes = 3'
contains 'flow默认3' "$FLOW" 'night_parallel_lanes.*默认 ?3|默认 3.*night_parallel_lanes'
contains '终审最强档' "$FLOW" '终局全分支 review:派最强档|派最强档 reviewer'

printf '== 并发帽(0.23,ADR 0008) ==\n'
SKILL=xcheck/SKILL.md
SETUP=xcheck-setup/SKILL.md
ADR8=docs/adr/0008-concurrency-cap-covers-ticket-review.md
contains '帽罩实施+票级评审' "$FLOW" '实施泳道.*票级评审|实施位.*评审位'
contains 'fan-out不在帽内' "$FLOW" 'fan-out 不在此帽|fan-out.*不在'
contains '评审优先补位' "$FLOW" '评审优先'
contains '评审排队不新增状态' "$FLOW" '不新增台账状态'
contains 'NIGHT记lanes' "$FLOW" 'lanes = <N>|lanes = N'
contains '续跑改道追记' "$FLOW" '改道.*追记|原值→新值'
contains '字段字典lanes行' "$FLOW" '\| lanes \| NIGHT \|'
contains '旗标lanes解析' "$SKILL" '--lanes'
contains 'lanes须配night' "$SKILL" '仅 .--night. 可携带|--lanes.*--night.*报错'
contains '优先级旗标大于配置' "$SKILL" '--lanes > agents.toml \[defaults\].night_parallel_lanes|--lanes > night_parallel_lanes'
contains 'setup模式E存在' "$SETUP" '模式 E:.`lanes|模式 E.*lanes'
contains 'setup警告不拦' "$SETUP" '警告不拦'
contains 'ADR0008在册' "$ADR8" '并发帽'

printf '== 有界重试(0.24,ADR 0009) ==\n'
contains '四态回报不触发重试' "$FLOW" '四态.*不触发'
contains '失败检出三步还原后才进等待' "$FLOW" '失败检出.*三步还原.*还原完成'
contains '互斥由四态扩为五态' "$FLOW" '互斥由四态扩为五态'
contains '互斥五态含重试等待中票' "$FLOW" '重试等待中票.*不相交'
contains '重试占位不回填' "$FLOW" '占位.*不回填'
contains '重试梯起跳60s' "$FLOW" '60s'
contains '重试梯封顶15min' "$FLOW" '封顶 15min|15min\(封顶\)'
contains '额外等待恰30分钟' "$FLOW" '1800s|恰 30 分钟'
contains '每单元night_retry_max上限' "$FLOW" 'night_retry_max.*默认 5'
contains '错峰同一波失败集合' "$FLOW" '调度循环.*失败集合'
contains '错峰i从0起' "$FLOW" 'i 从 0 起'
contains '错峰续跑检出序号升序重赋' "$FLOW" '检出序号升序重赋'
contains '首行记法impl retry' "$FLOW" '票 NN impl retry'
contains '首行记法review retry' "$FLOW" '票 NN review retry'
contains '首行记法终局review retry' "$FLOW" '终局review retry'
contains '首行带检出序号m' "$FLOW" '检出序号=m'
contains '重试追记实际派发时落盘' "$FLOW" '实际派发'
contains '断链重建整档重等' "$FLOW" '整档重等'
contains '计数从追记行重建不重置' "$FLOW" '重建.*计数|计数从追记行重建'
contains 'retries尾注只记实施位' "$FLOW" 'retries=k.*只记实施位'
contains '重试耗尽paused带阶段' "$FLOW" '重试耗尽.*阶段='
contains '终局耗尽waiting不勾finish' "$FLOW" '终局评审重试耗尽.*finish 不勾'
contains '重试追记行非新状态' "$FLOW" '重试追记行.*非新状态'
absent '票台账无retrying新状态' "$FLOW" 'retrying'
contains 'night_retry_max默认5(toml)' "$TOML" 'night_retry_max = 5'
contains 'retry关闭注释(toml)' "$TOML" '0 = 关闭|0=关闭'

printf 'Scope: 静态布线断言;无模型语义回放、无真实实施/推送。\n'
printf 'Result: %d pass, %d fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
