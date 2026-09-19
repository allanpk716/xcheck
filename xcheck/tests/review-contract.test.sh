#!/usr/bin/env bash
# 离线协议/接线检查。可选实际回放产物比对,不调用模型或执行夜链。
# bash xcheck/tests/review-contract.test.sh [--replay-dir <directory>]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIXTURES="$HERE/fixtures/review"
REPLAY=""
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--replay-dir" ]] || { printf 'usage: %s [--replay-dir directory]\n' "$0" >&2; exit 2; }
  REPLAY="$2"
  [[ -d "$REPLAY" ]] || { printf 'Replay directory not found: %s\n' "$REPLAY" >&2; exit 2; }
fi
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }
contains() {
  if [[ -f "$ROOT/$2" ]] && grep -Eq -- "$3" "$ROOT/$2"; then ok "$1"; else bad "$1 ($2)"; fi
}

# Markdown只是被检查对象,没有把它当可执行裁定函数。
printf '== Production contract and wiring ==\n'
contains 'review schema有唯一契约' xcheck/lib/review-contract.md 'review_schema = 2'
for field in 来源 关联决策 发生条件 取证分类 事实 证据 影响 裁定 范围 解除条件 决策冲突 生命周期 历史; do
  contains "F记录字段:$field" xcheck/lib/review-contract.md "^$field:"
done
contains '事实/严重度不自动决定阻断' xcheck/lib/review-contract.md '严重度.*不是阻断'
contains '重大未知仍须裁定' xcheck/lib/review-contract.md '不能因为①②为空跳过③'
contains '非阻断不扩票' xcheck/lib/review-contract.md '非阻断建议.*不得新增故事/票'
contains '短答绑定问题选项' xcheck/lib/review-contract.md '用户短答.*问题/选项绑定'
contains '旧协议链一律拒绝' xcheck/lib/review-contract.md '旧协议链已不支持自动续跑'
contains '迁移矩阵已删除' xcheck/lib/review-contract.md '迁移矩阵与migrated_from已删除'
contains '旧夜链字段集拒绝' xcheck/lib/review-contract.md '或夜链NIGHT为0.21及更早字段集'
contains '完成依赖必须已验证' xcheck/lib/review-contract.md '所有依赖票已验证complete'
contains '完成提交不可达拒绝恢复' xcheck/lib/review-contract.md '提交不可达.*停止'
contains '活动约束计算前拒绝缺失状态' xcheck/lib/review-contract.md '缺生命周期/裁定不能被过滤成'
contains '下游绑定最新已审快照' xcheck/lib/flow.md 'object只能是该环.*proposal\.md'
contains '下游不扫描旧rev或活动source' xcheck/lib/flow.md '不扫描最大rev、不回退到活动source'
contains '归并不自动重开已解除项' xcheck/prompts/triage-review.md '不自动重设开放'
contains '拒绝不含迁移' xcheck/lib/review-contract.md '不迁移、不重放、不继承旧通过/预算结论'
contains 'flow接入集中契约' xcheck/lib/flow.md 'review-contract\.md'
contains '入口有schema分流' xcheck/SKILL.md 'review_schema'
contains '入口拒绝旧协议链' xcheck/SKILL.md '旧协议链已不支持自动续跑'
contains '摄入落决策快照' xcheck/lib/context-intake.md 'decisions\.md'
contains 'flow引用review专用分类' xcheck/lib/flow.md 'triage-review\.md'
contains 'flow引用限定复审模板' xcheck/lib/flow.md 're-review\.md'
contains 'flow传决策快照路径槽' xcheck/lib/flow.md 'DECISIONS_PATH'
contains 'flow传复审材料路径槽' xcheck/lib/flow.md 'RE_REVIEW_PATH'
contains 'flow落F记录' xcheck/lib/flow.md 'FINDINGS\.md'
contains 'flow传播票阻断' xcheck/lib/flow.md 'review_blocks'
contains 'flow区分paused和blocked' xcheck/lib/flow.md 'paused.*blocked|blocked.*paused'
contains '暂停等待不勾finish' xcheck/lib/flow.md 'waiting.*保持finish未勾'
contains '无解除证据不重复实施发布' xcheck/lib/flow.md '没有则.*不重复实施/发布'
contains 'carrier保留发生条件不补推断' xcheck/lib/subagent-carrier.md '发生条件'
contains 'review分类模板存在' xcheck/prompts/triage-review.md 'FINDINGS|review-contract'
contains '汇总消费新问题记录或契约' xcheck/prompts/synthesize-review.md 'FINDINGS|review-contract'
contains '产物文档声明schema' docs/artifacts.md 'review_schema'
contains '产物文档说明决策快照' docs/artifacts.md 'decisions\.md'
contains '首轮提示保持材料边界' xcheck/prompts/review.md '不要探索其他仓库文件'
contains '复审允许新重大回归' xcheck/prompts/re-review.md '回归'
contains '复审普通建议非阻断' xcheck/prompts/re-review.md '普通新建议.*非阻断'
contains '复审不能读本轮其他反馈' xcheck/prompts/re-review.md '不得读取本轮其他评审员'
contains 'diag仍独立路由' xcheck/lib/flow.md 'synthesize-diag\.md'
stages=(); in_progress=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == '## PROGRESS.md 格式'* ]] && in_progress=1
  [[ "$line" == '## NIGHT.md 格式'* ]] && in_progress=0
  if (( in_progress )) && [[ "$line" =~ ^-[[:space:]]+\[[x\ ]\][[:space:]]+([a-z]+) ]]; then
    stages+=("${BASH_REMATCH[1]}")
  fi
done < "$ROOT/xcheck/lib/flow.md"
if [[ "${stages[*]}" == 'intake detect smoke fanout collect synthesize triage verify experiments deliverable gate' ]]; then
  ok 'PROGRESS retains exact ordered eleven-stage protocol'
else
  bad "PROGRESS stages changed: ${stages[*]}"
fi

# 检查实际模板替换后的字节数,包括中文UTF-8与绝对Windows正斜杠路径。
printf '== Rendered instruction budgets ==\n'
BASE='C:/Work Space/审核-project/.xcheck/20260919-235959'
for template in review re-review; do
  file="$ROOT/xcheck/prompts/$template.md"
  if [[ ! -f "$file" ]]; then bad "$template template missing"; continue; fi
  text="$(< "$file")"
  text="${text//\{\{PROPOSAL_PATH\}\}/$BASE/proposal.rev1.md}"
  text="${text//\{\{CONTEXT_PATH\}\}/$BASE/context.md}"
  text="${text//\{\{DECISIONS_PATH\}\}/$BASE/decisions.md}"
  text="${text//\{\{RE_REVIEW_PATH\}\}/$BASE/re-review-context.md}"
  printf '%s\n' "$text" > "$TMP/$template.txt"
  bytes="$(wc -c < "$TMP/$template.txt")"
  if (( bytes <= 2048 )); then ok "$template rendered $bytes bytes <= 2048"; else bad "$template rendered $bytes bytes > 2048"; fi
  if [[ "$text" == *'{{'* || "$text" == *'}}'* ]]; then bad "$template unresolved slots"; else ok "$template all slots resolved"; fi
  if [[ "$text" == *"$BASE/proposal.rev1.md"* ]]; then ok "$template absolute path rendered"; else bad "$template proposal slot missing"; fi
 done

# 提取契约中的记录/字段。oracle是独立预期,实际产物必须由回放者提供。
record() {
  local file="$1" id="$2" line active=0
  [[ -f "$file" ]] || return 1
  if [[ "$id" == '@' ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do printf '%s\n' "${line%$'\r'}"; done < "$file"
    return 0
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" == '## '* ]]; then
      if [[ "$line" =~ ^##[[:space:]]+$id([[:space:]]|$) ]]; then active=1; else active=0; fi
    fi
    (( active )) && printf '%s\n' "$line"
  done < "$file"
  return 0
}
value() {
  local block="$1" key="$2" line result
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$key:"* ]]; then result="${line#*:}"
    elif [[ "$line" == "$key："* ]]; then result="${line#*：}"
    elif [[ "$line" == "$key ="* ]]; then result="${line#*=}"
    else continue; fi
    result="${result#"${result%%[![:space:]]*}"}"
    result="${result%"${result##*[![:space:]]}"}"
    printf '%s\n' "$result"
  done <<< "$block"
}
check_oracle() {
  local oracle="$1" actual="$2" quiet="${3:-0}" file id key pattern extra block got failures=0 checks=0
  while IFS=$'\t' read -r file id key pattern extra || [[ -n "$file" ]]; do
    [[ -z "$file" || "$file" == \#* ]] && continue
    checks=$((checks+1))
    if [[ -z "$id" || -z "$key" || -z "$pattern" || -n "$extra" || "$file" == /* || "$file" == *..* ]]; then
      (( quiet )) || printf '    malformed oracle row: %s\n' "$file"
      failures=$((failures+1)); continue
    fi
    if [[ ! -f "$actual/$file" ]]; then
      (( quiet )) || printf '    missing actual artifact: %s\n' "$actual/$file"
      failures=$((failures+1)); continue
    fi
    block="$(record "$actual/$file" "$id")"
    if [[ -z "$block" ]]; then failures=$((failures+1)); (( quiet )) || printf '    missing record: %s %s\n' "$file" "$id"; continue; fi
    if [[ "$key" == '!' ]]; then
      if printf '%s\n' "$block" | grep -Eq -- "$pattern"; then
        failures=$((failures+1)); (( quiet )) || printf '    forbidden match: %s %s /%s/\n' "$file" "$id" "$pattern"
      fi
    else
      if [[ "$key" == '?' ]]; then got="$block"; else got="$(value "$block" "$key")"; fi
      if [[ -z "$got" ]] || ! printf '%s\n' "$got" | grep -Eq -- "$pattern"; then
        failures=$((failures+1)); (( quiet )) || printf '    mismatch: %s %s %s expected /%s/, got %s\n' "$file" "$id" "$key" "$pattern" "$got"
      fi
    fi
  done < "$oracle"
  (( checks > 0 && failures == 0 ))
}

printf '== Oracle positive/negative controls (not model replay) ==\n'
mkdir -p "$TMP/control"
printf '# Findings\nreview_schema = 2\n## F1 · missing glossary\n事实: 证实\n裁定: 非阻断建议\n生命周期: 开放\n来源: alpha:1\n' > "$TMP/control/FINDINGS.md"
printf '# Progress\nreview_schema = 2\n## 终态\n无需修订\n' > "$TMP/control/PROGRESS.md"
if check_oracle "$FIXTURES/low-value/expected.tsv" "$TMP/control" 1; then ok 'oracle accepts known conforming low-value control'; else bad 'oracle rejected conforming control'; fi
control="$(< "$TMP/control/FINDINGS.md")"
printf '%s\n' "${control/裁定: 非阻断建议/裁定: 阻断}" > "$TMP/control/FINDINGS.md"
if check_oracle "$FIXTURES/low-value/expected.tsv" "$TMP/control" 1; then bad 'oracle accepted blocking low-value mutation'; else ok 'oracle rejects blocking low-value mutation'; fi
printf '%s\n' "$control" > "$TMP/control/FINDINGS.md"
printf '# Progress\n## 终态\n无需修订\n' > "$TMP/control/PROGRESS.md"
if check_oracle "$FIXTURES/low-value/expected.tsv" "$TMP/control" 1; then bad 'oracle accepted schema-less mutation'; else ok 'oracle rejects schema-less mutation'; fi

printf '# Findings\n## F1 · backup exclusion unknown\n取证分类: ③\n事实: 未确定\n裁定: 重大风险待决\n生命周期: 开放\n解除条件: 验证服务排除保留列表\n' > "$TMP/control/FINDINGS.md"
printf '# Progress\n## 终态\n夜间收工\n' > "$TMP/control/PROGRESS.md"
if check_oracle "$FIXTURES/major-unknown/expected.tsv" "$TMP/control" 1; then ok 'oracle accepts pending major risk control'; else bad 'oracle rejected pending major risk control'; fi
control="$(< "$TMP/control/FINDINGS.md")"
printf '%s\n' "${control/事实: 未确定/事实: 证实}" > "$TMP/control/FINDINGS.md"
if check_oracle "$FIXTURES/major-unknown/expected.tsv" "$TMP/control" 1; then bad 'oracle accepted unsupported confirmed fact'; else ok 'oracle rejects unsupported confirmed fact'; fi
printf '# NIGHT\nreview_schema = 2\nwaiting = F1 排除保留备份\n- [ ] impl\n- [ ] finish\n票 01: paused(F1,检查保留列表)\n票 02: blocked(01)\n票 03: complete(commits synthetic, review clean)\n票 04: paused(独立性未知)\n结论: 未完成\n' > "$TMP/control/NIGHT.md"
if check_oracle "$FIXTURES/paused-dependency/expected.tsv" "$TMP/control" 1; then ok 'oracle accepts dependency pause control'; else bad 'oracle rejected dependency pause control'; fi
control="$(< "$TMP/control/NIGHT.md")"
printf '%s\n' "${control/票 02: blocked(01)/票 02: complete(台账有行)}" > "$TMP/control/NIGHT.md"
if check_oracle "$FIXTURES/paused-dependency/expected.tsv" "$TMP/control" 1; then bad 'oracle accepted completed blocked dependency'; else ok 'oracle rejects completed blocked dependency'; fi
printf '%s\n' "${control/结论: 未完成/结论: 全绿}" > "$TMP/control/NIGHT.md"
if check_oracle "$FIXTURES/paused-dependency/expected.tsv" "$TMP/control" 1; then bad 'oracle accepted green with paused tickets'; else ok 'oracle rejects green with paused tickets'; fi

printf '== Fixture inputs and optional actual replay ==\n'
CASES=(low-value major-unknown re-review-regression re-review-advice decision-change legacy-review paused-dependency)
for case_name in "${CASES[@]}"; do
  case_dir="$FIXTURES/$case_name"
  if [[ -s "$case_dir/input.md" && -s "$case_dir/expected.tsv" ]]; then ok "$case_name has input and separate oracle"; else bad "$case_name fixture missing"; continue; fi
  if [[ -n "$REPLAY" ]]; then
    if check_oracle "$case_dir/expected.tsv" "$REPLAY/$case_name"; then ok "$case_name actual replay matches oracle"; else bad "$case_name actual replay mismatch"; fi
    if [[ "$case_name" == legacy-review ]]; then
      if cmp -s "$case_dir/old-PROGRESS.md" "$REPLAY/$case_name/old/PROGRESS.md"; then ok 'legacy original record unchanged'; else bad 'legacy original record changed/missing'; fi
    fi
  fi
 done
if [[ -z "$REPLAY" ]]; then
  printf 'NOT RUN: semantic replay (supply independently produced artifacts via --replay-dir).\n'
fi
printf '== 字段字典同步锁(0.22;flow字典为唯一定义处) ==
'
for f in xcheck/lib/flow.md xcheck/lib/night-delivery.md xcheck/lib/review-contract.md xcheck/SKILL.md xcheck/lib/context-intake.md; do
  for banned in 'delivery_schema' 'implementation_blocked' 'publication_blocked' 'host_repo' 'worktree = ' 'night_mode' 'NIGHT_MODE'; do
    if grep -q -- "$banned" "$ROOT/$f" 2>/dev/null; then
      bad "$f 不应再含已废弃标识 $banned"
    else
      ok "$f 无已废弃标识 $banned"
    fi
  done
done
if grep -rq --exclude='*.test.sh' -- '票 01: complete(commits' "$ROOT/xcheck" 2>/dev/null; then
  bad '旧票台账格式(commits变体)残留'
else
  ok '票台账格式无旧变体'
fi
if grep -q -- 'material = trusted' "$ROOT/xcheck/lib/context-intake.md" && grep -q -- 'material = external' "$ROOT/xcheck/lib/flow.md"; then
  ok 'material 字段在摄入与失败关闭门两处成对'
else
  bad 'material 字段配对缺失'
fi

printf 'Scope: static wiring, rendered prompt budget, oracle controls; no CLI, permissions, Git, notifications or publishing tested.\n'
printf 'Result: %s pass, %s fail\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
