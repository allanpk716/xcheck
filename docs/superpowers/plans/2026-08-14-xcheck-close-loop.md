# xcheck 评审闭环(/xcheck-close)+ 摄入强化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-08-14-xcheck-close-loop-design.md`(v0.9.0):① 新 skill `/xcheck-close` 把 review 三类分级反馈闭环处置(查证→实验→必改清单→修订→复审,≤2 轮);② flow.md 第 4 步落 `run.md` 元数据 + 6.5 收尾引导;③ context-intake.md 方案型例外补确认关卡与事实提取、自包含输入零往返带背景。

**Architecture:** 全部改动落在仓库 `C:\WorkSpace\agent\xcheck`(`xcheck/` 经 junction = `~/.claude/skills/xcheck/`,改仓库文件即改 skill)。新增两个文件(`xcheck/lib/close-flow.md` 闭环编排大脑、`xcheck-close/SKILL.md` 第 5 个入口壳,后者需新建 junction);修改两个文件(`xcheck/lib/flow.md` 三处、`xcheck/lib/context-intake.md` 三处);CHANGELOG 加 0.9.0。

**Tech Stack:** Claude Code skill(Markdown prompt 模板 + `$ARGUMENTS`);prose/prompt 工程,无单测——"测试"是行为验证(读文件检查 / 实跑检查 `.xcheck/` 产出)。

## Global Constraints

(来自已批准 spec,每个任务隐含遵守。)

- **闭环铁律**:实验不改业务代码、不联网外呼、不部署;修订只写新文件(`<原名>.rev<m>.md`)、原稿不动;每个有成本/副作用的关口(multiSelect 批准实验 / 采纳修订 / 是否复审)用户拍板;SUMMARY 只在闭环**全部结束时**加一行 closed 标记,过程全写 `CLOSE.md`(阶段粒度追加)。
- **事实层摘录铁律不变**:只摘用户原话不改写;方案层固化允许改写但必过用户过目。
- **闭环上限 2 轮修订**;不收敛报"推倒重来"。
- **平台**:Windows + Git Bash;LF 行尾(`.gitattributes` 强制);中文标点/emoji(⚠️✅❌❓)原样保留。
- **版本 0.9.0**(0.8.0 已被同日 carrier 修复占用,见 CHANGELOG)。

---

## File Map

仓库 `C:\WorkSpace\agent\xcheck` 下,路径相对仓库根。

| 文件 | 职责 | 本计划动作 |
|---|---|---|
| `xcheck/lib/flow.md` | 共享 0+6 步编排大脑 | **修改**三处(Task 1):第 4 步落 run.md、第 0 步自包含 bullet 加零往返指针、6.5 加 review 引导句 |
| `xcheck/lib/context-intake.md` | 第 0 步摄入细则 | **修改**三处(Task 2):0.0 例外补强、0.5 填槽更新、新增 0.6 零往返小节 + 边界补一行 |
| `xcheck/lib/close-flow.md` | /xcheck-close 闭环编排大脑(C0~C5) | **新建**(Task 3) |
| `xcheck-close/SKILL.md` | 第 5 个入口壳(参数解析 + 转派) | **新建** + junction(Task 4) |
| `CHANGELOG.md` | 版本日志 | **修改**(Task 5):加 0.9.0 |

**不动的文件**:`xcheck/agents.toml`、`xcheck/lib/detect.sh`、`xcheck/lib/subagent-carrier.md`、`xcheck/lib/extractor-carrier.md`、`xcheck/prompts/*`(review.md 的 `{{CONTEXT}}` 槽现成)、其余 4 个入口 SKILL.md。

---

## Task 1: flow.md 三处修改

**Goal:** ① 第 4 步收尾时落 `run.md`(闭环元数据);② 第 0 步"自包含跳过"bullet 指向零往返扫描;③ 6.5 收尾加 review 引导句。

**Files:**
- Modify: `C:\WorkSpace\agent\xcheck\xcheck\lib\flow.md`

**Interfaces:**
- Produces(`run.md` 格式,close-flow.md C0 消费):`mode` / `ts` / `selected` / `prompt` / `source` 五行。`source` = 原方案来源:第 3.1 步时 `$ARGUMENTS`/摄入产物是文件路径 → 记该绝对路径;否则记 `inline`。

- [ ] **Step 1: Edit A —— 第 4 步末尾加 run.md 落盘**

先读 flow.md 确认锚点未变,然后 Edit:

`old_string`(唯一):
```
**不要** 在这一步做综合判断。综合在第 5 步。
```

`new_string`:
````
**不要** 在这一步做综合判断。综合在第 5 步。

**落 run.md(闭环元数据)**:本步最后把本次运行元数据写到 `<cwd>/.xcheck/<ts>/run.md`(供 `/xcheck-close` 定位复审 agent 集与判 mode),一行一个字段:

```
mode = review            # diag | review
ts = <ts>
selected = codex, kimi, opencode   # 本次 SELECTED,逗号分隔小写名
prompt = <cwd>/.xcheck/<ts>/prompt.txt
source = <原方案的文件绝对路径 | inline>
```

`source` 判定:第 3.1 步时 `$ARGUMENTS`(或摄入产物)是文件路径 → 记该路径;是用户贴文/固化文本 → 记 `inline`。
````

- [ ] **Step 2: Edit B —— 第 0 步自包含 bullet 加指针**

`old_string`(唯一,flow.md 第 11 行):
```
- **自包含输入**(完整报错栈 / 设计文档 / 文件路径)→ **跳过**摄入,直接用 `$ARGUMENTS`,进第 1 步。
```

`new_string`:
```
- **自包含输入**(完整报错栈 / 设计文档 / 文件路径)→ **跳过**摄入,直接用 `$ARGUMENTS`,进第 1 步。但跳过摄入 ≠ 不带背景:主会话仍**零往返静默扫**最近对话,摘与输入直接相关的用户原话填 `{{CONTEXT}}`(见 `lib/context-intake.md` 第 0.6 步),并在对话里明说一句;没摘到就不填。
```

- [ ] **Step 3: Edit C —— 6.5 加 review 引导句**

`old_string`(唯一):
```
第 6 步**不**单独再喊"你拍板"——第 5 步结尾那句"共识≠正确,你拍板"已覆盖整个 SUMMARY。第 6 步只是给那段话补"可信度依据"。呈现给用户即结束。
```

`new_string`:
```
第 6 步**不**单独再喊"你拍板"——第 5 步结尾那句"共识≠正确,你拍板"已覆盖整个 SUMMARY。第 6 步只是给那段话补"可信度依据"。呈现给用户即结束。

**mode=review 时**,呈现完再追加一句(原样输出):

> **要闭环处置这些反馈(逐条证实 / 执行实验 / 修订方案 / 复审)→ 敲 `/xcheck-close`。**

diag 模式**不加**这句(diag 闭环暂不支持,别引导)。
```

- [ ] **Step 4: 验证**

Run:
```bash
grep -n 'run.md\|闭环处置\|零往返' xcheck/lib/flow.md
```
Expected: 三处各命中;`grep -c '^## '` 仍为 8 个二级标题(结构未破坏)。读 diff 确认第 1~5 步其余内容、边界段未被误改。

- [ ] **Step 5: Commit**

```bash
git add xcheck/lib/flow.md
git commit -m "feat(xcheck): step 4 run.md metadata + step 6.5 close-loop pointer

评审第4步收尾落 run.md(mode/ts/selected/prompt/source)供 /xcheck-close
定位复审集;第0步自包含 bullet 指向零往返背景扫描;6.5 收尾 review 模式
加 /xcheck-close 引导句。实现 close-loop spec 前置部分。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: context-intake.md 三处修改

**Goal:** ① 0.0 方案型例外补"确认关卡 + 事实提取";② 0.5 填槽更新(PROPOSAL/CONTEXT 分槽);③ 新增 0.6 零往返小节 + 边界补一行。

**Files:**
- Modify: `C:\WorkSpace\agent\xcheck\xcheck\lib\context-intake.md`

- [ ] **Step 1: Edit A —— 0.0 例外补强**

`old_string`(0.0 例外 bullet 的结尾句,唯一):
```
判定信号:指代词 + 最近对话 assistant 输出明显长于用户 + 对话主题是方案设计而非排错。
```

`new_string`:
```
判定信号:指代词 + 最近对话 assistant 输出明显长于用户 + 对话主题是方案设计而非排错。固化时按三步走:① 把已定方案固化成自包含 proposal(历史背景用中性陈述,遵守 flow 3.1 自代入陷阱纪律);② **同时**把讨论中用户陈述过的事实/约束单独摘出(**摘录铁律:用户原话,不改写**);③ **呈现给用户过目**(proposal 全文 + 事实清单,AskUserQuestion:① 就这样,继续 / ② 我要改)——**过目通过前绝不 fan-out**。通过后:固化方案填 review 模板 `{{PROPOSAL}}`,事实清单填 `{{CONTEXT}}`,分槽不混流。
```

- [ ] **Step 2: Edit B —— 0.5 填槽更新**

`old_string`(唯一):
```
- **mode=review** → flow.md 第 3 步填 `{{PROPOSAL}}` = [用户原始 `$ARGUMENTS` 中含实质内容的首段,若有] + 确认后的事实清单。
```

`new_string`:
```
- **mode=review**(普通摄入路径)→ flow.md 第 3 步填 `{{PROPOSAL}}` = [用户原始 `$ARGUMENTS` 中含实质内容的首段,若有] + 确认后的事实清单。
- **mode=review**(方案型例外路径)→ `{{PROPOSAL}}` = 过目确认后的固化方案全文;`{{CONTEXT}}` = 过目确认后的事实清单(见 0.0 例外的三步固化)。
```

- [ ] **Step 3: Edit C —— 新增 0.6 小节**

`old_string`(唯一,0.5 结尾与边界区之间):
```
然后**正常进 flow.md 第 1 步**(检测 agent → 多选 → 并行派 → 收齐 → 汇总),后续不变。

---

## 边界(铁律)
```

`new_string`:
```
然后**正常进 flow.md 第 1 步**(检测 agent → 多选 → 并行派 → 收齐 → 汇总),后续不变。

---

## 第 0.6 步:自包含输入零往返带背景(跳过摄入路径专用)

自包含输入跳过摄入,**不等于不带背景**。主会话在直接用 `$ARGUMENTS` 之前:

1. **静默扫**最近对话(范围同 0.1:最近 ~20 轮),摘出与输入**直接相关**的**用户原话**(约束、环境、已知现象);assistant 推理一律不带。
2. 摘录铁律不变:只摘原话,不改写、不总结。
3. 摘到了 → 填该 mode 模板的 `{{CONTEXT}}` 槽,并在对话里**明说一句**(不弹窗、不阻塞):
   > 已附带 N 条来自刚才对话的背景(未经逐条确认,若有出入请打断)。
   没摘到 → 不填,flow 第 3 步把 `{{CONTEXT}}` 整行删掉。
4. `prompt.txt` 落盘含 CONTEXT 段,事后可核查。

---

## 边界(铁律)
```

- [ ] **Step 4: Edit D —— 边界区补一行**

`old_string`(边界区末条,唯一):
```
- **自包含输入跳过摄入**:别给本来就很完整的问题多加一次往返。
```

`new_string`:
```
- **自包含输入跳过摄入**:别给本来就很完整的问题多加一次往返;但按第 0.6 步零往返附带背景——不弹确认窗,必须明说一句,摘的是用户原话不是总结。
```

- [ ] **Step 5: 验证 + Commit**

Run:
```bash
grep -n '0.6\|过目\|已附带' xcheck/lib/context-intake.md
```
Expected: 0.6 小节标题、两处"过目"、明说句均在。读 diff 确认 0.1~0.5 其余内容未被误改。

```bash
git add xcheck/lib/context-intake.md
git commit -m "feat(xcheck): intake hardening — scheme-exception confirmation + zero-roundtrip context

方案型指代例外补两件事:固化 proposal 呈现用户过目(通过前绝不 fan-out)
+ 同时摘讨论中用户事实填 {{CONTEXT}} 分槽提交。新增 0.6 自包含输入
零往返带背景(静默摘用户原话+对话里明说一句,不弹窗)。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 新建 `xcheck/lib/close-flow.md`

**Goal:** 闭环编排大脑(C0~C5 + 收尾 + 恢复 + 边界),内容按 spec §3~§7 落成 flow.md 同风格的可执行指令。

**Files:**
- Create: `C:\WorkSpace\agent\xcheck\xcheck\lib\close-flow.md`

- [ ] **Step 1: 写入文件全文**

用 Write 工具创建,内容如下(照抄,措辞/emoji/标点不得改动):

````markdown
# xcheck 闭环执行流程(/xcheck-close 专用)

主会话(你)按 **C0~C5** 执行。前置:一次**已跑完 triage**(三类分级段)的 `/xcheck-review` 产物。`OVERRIDE_AGENTS`(壳传来,来自 `--agents`)只作用于复审轮的 agent 集。

闭环产出统一写到 `<cwd>/.xcheck/<ts>/CLOSE.md`(**阶段粒度追加**:每阶段完成即落盘);`SUMMARY.md` 只在闭环**全部结束时**追加一行 closed 标记,过程不碰它。

---

## C0:定位与校验

1. **定 ts**:壳传来 `TARGET_TS` → 用它;否则扫 `<cwd>/.xcheck/` 取**最新**目录名(形如 `20260814-143012`)。
2. **校验**(任一不过 → 按提示停住,不硬猜、不代跑):
   - `<ts>` 目录存在且含 `SUMMARY.md` → 否则报"找不到该次评审",列出现有 ts 供挑。
   - `run.md` 存在 → 否则提示"旧版本评审产物,无 run.md;请重跑一次 /xcheck-review 再闭环"。
   - `run.md` 的 `mode = review` → 否则提示"diag 闭环暂不支持"。
   - SUMMARY 含"三类验证分级"段(第 6 步产物)→ 否则提示"该评审无分级段(旧版产物),请重跑 /xcheck-review"。
   - SUMMARY 末尾**无** closed 标记(形如 `<!-- closed: … · 终态: … -->`)→ 否则提示"已于 <时间> 闭环,终态 <X>",停。
3. **恢复判定**:`CLOSE.md` 已存在 → 读它的阶段区块(`## 阶段N · …`),已完成的不重做,从未完成阶段续跑(见文末"恢复");否则从 C1 全量开始,先写 CLOSE.md 头部(源评审 ts/mode/家数)。
4. 从 `run.md` 读出:`selected`(复审 agent 集)、`source`(原方案是文件路径还是 `inline`)、`prompt`(原 prompt 位置)。

## C1:查证第一类(只读,自动,不问)

- 对象:SUMMARY 分级段"第一类 · 可直接证实"的**每条**。
- **你(主会话)逐条查**:只读该条"判据"直接指向的文件/配置/文档,**不展开探索**。条目 >10 条 → 可分批派 subagent(便宜模型;subagent 只回传证据原文,你裁决)。
- 每条判三值,各附一行证据(文件:行号,或引文):
  - **✅ 证实**(反馈属实)/ **❌ 证伪**(反馈不成立,写明实际是什么)/ **❓ 查无实据**(判据指向处查不到)。
- 纯读操作,不弹窗、不批准。第一类为空 → CLOSE.md 记"无",直接进 C2。
- 结果追加写 CLOSE.md `## 阶段1 · 查证(完成 <时间>)` 区块。

## C2:执行第二类实验(AskUserQuestion 批准后)

- 对象:SUMMARY 分级段"第二类 · 可设计实验验证"的条目(第 6 步已带【验证目的/一句话方法/预期】)。为空 → CLOSE.md 记"无",跳到 C3。
- **一次 multiSelect** 列出全部第二类条目(选项 = 条目紧缩转述 + `[来源]`),让用户勾要执行哪些(**可全跳过**)。批过的执行,**不再逐条二次确认**;全跳过 → 全部条目归"未决",跳到 C3。
- **执行约束(铁律)**:
  - **允许**:写临时验证文件(一律放 `<cwd>/.xcheck/<ts>/exp/`,留底不删)+ 运行本地测试 / benchmark / 探测命令。
  - **禁止**:改业务代码、联网外呼、部署。
- 每条按其【方法】执行,结果三值:**成立 / 不成立 / 无定论**(执行失败、超时、环境不满足 → 无定论,记原因,**不阻塞其他条**)。
- 结果追加写 CLOSE.md `## 阶段2 · 实验(完成 <时间>,批准 X/N 条)`(逐条结果 + 输出摘要 + exp/ 文件名)。

## C3:必改清单(汇总,呈现给用户)

按查证/实验结果组装:

| 结果 | 归宿 |
|---|---|
| 第 1 类 ✅ 证实 + 实验 **成立** | **必改** |
| 第 1 类 ❌ 证伪 + 实验 **不成立** | **不需采纳**(明确排除) |
| ❓ 查无实据 / 实验**无定论** / 用户跳过未执行的 | **未决** |
| 第 3 类 存疑 | **仅参考**(列出带 ⚠️,不进清单主体) |

- **未决条目逐条问用户拍板**:按必改处理 / 豁免 / 保持未决。
- **必改为空** → 呈现清单后输出"无需修订",跳过 C4,直接到 C5 问一句"要不要复审一轮确证?"(用户说不 → 收尾,终态"无需修订")。
- 追加写 CLOSE.md `## 阶段3 · 必改清单(完成 <时间>)`。

## C4:修订方案(用户批准后,主会话亲写)

- 输入:必改清单(含未决条目的用户处置)。**你(主会话)亲写**——你持有全量证据(各家反馈 + 查证结果 + 实验结果),不 fan-out。
- 落盘(**原稿一律不动**):
  - `run.md` 的 `source` 是文件路径 → 原文件**同目录**写 `<原名>.rev<m>.md`(m = 修订轮次,从 1 起)。
  - `source = inline` → 写 `<cwd>/.xcheck/<ts>/proposal.rev<m>.md`。
- **diff(原稿 vs 修订版)呈现给用户**;原稿被手改过(diff 对不上)→ 提示用户,以**当前文件**为修订基线,rev 序号顺延。
- 修订版正文遵守 flow 3.1 自代入陷阱纪律:历史背景用中性陈述,不点名 agent、不写"异构评审"等触发词。
- 呈现修订版 + diff 后问:"采纳这份修订版进入复审?"(用户可要求再改,改完再问)。
- 追加写 CLOSE.md `## 阶段4 · 修订 rev<m>(完成 <时间>)`(产出文件路径)。

## C5:复审(问用户,硬上限 2 轮修订)

- 修订版落定后问:"要跑一轮复审吗?"——**每轮都问,不自动接续**。用户不审 → 收尾(终态"用户中止复审")。
- 复审 = **完整跑一遍 flow.md**(mode=review):`{{PROPOSAL}}` = 修订版全文,新 ts 目录,照常落 run.md / prompt / summary / SUMMARY(含 triage)。
  - agent 集:`OVERRIDE_AGENTS`(若有)> `run.md` 的 selected ∩ 当前 INSTALLED(先跑 detect.sh 重新探测);缺员走 flow 第 2 步**分支 C** 弹窗(用剩余集 / 重选)。
- 新一轮 SUMMARY 出来 → **回到 C1** 对新一轮分级再闭环(CLOSE.md 复审链追加新 ts)。
- **收敛** = 最新一轮分级第 1+2 类问题清零(或只剩用户显式豁免条目)→ 收尾,终态"收敛(N 轮修订)"。
- **硬上限:2 轮修订**。第 2 轮修订后仍有第 1+2 类问题 → 停,报告"**建议推倒重来**:两轮修订后仍存在 N 个可验证问题,疑方案根基缺陷",终态"推倒重来"。

## 收尾(任一终态:收敛 / 推倒重来 / 无需修订 / 用户中止)

1. CLOSE.md 末尾写终态段:`## 终态: <终态>(<N> 轮修订)` + 产出文件清单。
2. 给**最新一轮评审的 SUMMARY** 追加一行:`<!-- closed: <本地时间> · 终态: <终态> -->`
3. 向用户呈现闭环总结:必改了什么、修订版在哪、终态是什么。

## 恢复(中断续跑)

重跑 `/xcheck-close <ts>`(无参时最新 ts 已有 CLOSE.md 也算):C0.3 读 CLOSE.md 已有阶段区块,**已完成的不重做,从未完成阶段续**。粒度到**阶段**(阶段内做到一半崩了,重跑整个该阶段)。阶段内的用户批准**不跨恢复记忆**——重进未完成阶段时,该问的关口重新问。

## 边界与异常

- 分级第 1+2 类全空(全 LGTM 或全第 3 类)→ C1/C2 记"无",C3 输出"无需修订"直接收尾。
- 实验失败/超时 → 该条"无定论",不阻塞其他条。
- 复审轮 selected 有 agent 已卸载 → flow 分支 C 弹窗;`--agents` 直接盖过。
- 用户中途中止 → CLOSE.md 记"中止于阶段 N";SUMMARY **不加** closed 标记(下次可续)。
- close 崩了 → 已落盘的阶段成果保得住,重跑从未完成阶段续。
````

- [ ] **Step 2: 验证**

```bash
grep -n '^## ' xcheck/lib/close-flow.md && grep -c 'CLOSE.md' xcheck/lib/close-flow.md
```
Expected: `## ` 标题依次为 C0~C5、收尾、恢复、边界与异常(共 9 个);CLOSE.md 出现多处。文件 UTF-8、LF 行尾(`file` 无 CRLF 字样)。

- [ ] **Step 3: Commit**

```bash
git add xcheck/lib/close-flow.md
git commit -m "feat(xcheck): add close-flow.md — close-loop orchestration brain

C0 定位校验(六项校验+恢复判定) / C1 查证第一类(只读三值判定) /
C2 第二类实验(multiSelect 批准+副作用铁律) / C3 必改清单(含未决档) /
C4 修订(主会话亲写新文件不动原稿) / C5 复审(每轮问,上限 2 轮) /
收尾 closed 标记 / 阶段粒度恢复。实现 spec 2026-08-14-xcheck-close-loop-design §3~§7。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 新建 `xcheck-close/SKILL.md` + junction

**Goal:** 第 5 个入口壳:参数解析(--agents / <ts>)+ 转派 close-flow.md;junction 到 `~/.claude/skills/`。

**Files:**
- Create: `C:\WorkSpace\agent\xcheck\xcheck-close\SKILL.md`

- [ ] **Step 1: 写入 SKILL.md 全文**

````markdown
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
````

- [ ] **Step 2: 建 junction + 验证**

Run(PowerShell 经 Git Bash 调用;若 junction 已存在会报错,先确认不存在):
```bash
powershell -NoProfile -Command "New-Item -ItemType Junction -Path \"$env:USERPROFILE\.claude\skills\xcheck-close\" -Target 'C:\WorkSpace\agent\xcheck\xcheck-close'" && ls ~/.claude/skills/xcheck-close/
```
Expected: junction 创建成功,`ls` 列出 `SKILL.md`。

- [ ] **Step 3: Commit(仓库文件;junction 不入库)**

```bash
git add xcheck-close/SKILL.md
git commit -m "feat(xcheck): add /xcheck-close shell skill (5th entry)

参数解析(--agents 复审换集 + <ts> 指定评审)+ 转派 lib/close-flow.md。
junction 到 ~/.claude/skills/xcheck-close(不入库)。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: CHANGELOG 加 0.9.0

**Files:**
- Modify: `C:\WorkSpace\agent\xcheck\CHANGELOG.md`

- [ ] **Step 1: 在 `## [Unreleased]` 与 `## [0.8.0]` 之间插入**

`old_string`:
```
## [Unreleased] / 未发布

## [0.8.0] - 2026-08-14
```

`new_string`:
````
## [Unreleased] / 未发布

## [0.9.0] - 2026-08-14

### Added / 新增

- **`/xcheck-close` — review feedback close-loop.** After `/xcheck-review`'s triage (three verifiability tiers), the loop used to dead-end at "you decide". The new 5th shell closes it, all human-in-the-loop: **C1** verify tier-1 items read-only (✅/❌/❓, main session, evidence per item); **C2** run tier-2 experiments after one multiSelect approval (temp files under `.xcheck/<ts>/exp/` kept; no business-code edits / no network / no deploy); **C3** distill into a must-fix list (confirmed + experiment-supported), rejected items explicitly excluded, unresolved items decided by the user; **C4** main session writes the revision as a **new** `<name>.rev<m>.md` + diff (original untouched); **C5** optional re-review per round, hard cap 2 revision rounds, convergence = tiers 1+2 clear, otherwise "recommend starting over". Progress lands in `CLOSE.md` (per-stage append, resumable); the source SUMMARY gets a one-line `closed` marker only when the loop finishes. Review runs now also write `run.md` (mode/SELECTED/ts/prompt/source) that close uses to locate the re-review agent set; step 6.5 points review users at `/xcheck-close`. Design: `docs/superpowers/specs/2026-08-14-xcheck-close-loop-design.md`.
- **`/xcheck-close` —— 评审反馈闭环。** `/xcheck-review` 的三类分级(triage)此前止步于"你拍板",反馈没有下文。新增第 5 个入口壳闭环续上,全程人在环:**C1** 只读查证第一类(✅ 证实 / ❌ 证伪 / ❓ 查无实据,主会话逐条带证据);**C2** 第二类实验经一次 multiSelect 批准后执行(临时文件落 `.xcheck/<ts>/exp/` 留底;禁改业务代码 / 禁联网 / 禁部署);**C3** 汇成必改清单(证实+实验成立=必改,证伪=明确排除,未决=用户逐条拍板);**C4** 主会话亲写修订版,只写**新文件** `<原名>.rev<m>.md` + diff,原稿不动;**C5** 每轮问用户要不要复审,硬上限 2 轮修订,第 1+2 类清零=收敛,否则报"建议推倒重来"。过程写 `CLOSE.md`(阶段粒度追加、可断点续跑),SUMMARY 只在闭环结束时加一行 closed 标记。评审第 4 步新增落 `run.md`(mode/SELECTED/ts/prompt/source)供闭环定位复审 agent 集;6.5 收尾加 `/xcheck-close` 引导句。设计见 `docs/superpowers/specs/2026-08-14-xcheck-close-loop-design.md`。

### Changed / 改进

- **Intake hardening.** The "scheme-type reference" exception (e.g. `评审刚才的方案` after a design discussion) used to solidify the proposal and fan out **unguarded** — no user confirmation, and user-stated facts/constraints from the discussion were dropped. Now solidification is three-step: neutral-statement proposal + verbatim user-fact extraction, both shown to the user for approval (never fan out before approval), facts going to `{{CONTEXT}}` separately from `{{PROPOSAL}}`. Self-contained inputs (pasted spec / file path) now also get a **zero-roundtrip** background pass: the main session silently pulls directly-related user verbatim from recent conversation into `{{CONTEXT}}`, says so in one visible line (no popup), nothing added if nothing found. The verbatim-not-summary iron rule is unchanged.
- **摄入强化。** "方案型指代"例外(设计讨论后敲"评审刚才的方案")此前固化 proposal 后**裸奔** fan-out——无用户确认关卡,讨论中用户陈述的事实/约束也全丢。现固化为三步:中性陈述 proposal + 用户原话事实摘录,两者一并呈现用户过目(通过前绝不 fan-out),事实单独走 `{{CONTEXT}}`、与 `{{PROPOSAL}}` 分槽。自包含输入(贴 spec / 文件路径)也补**零往返**背景扫描:主会话静默摘最近对话里直接相关的用户原话填 `{{CONTEXT}}`,对话里明说一句(不弹窗),没摘到就不加。"摘录≠总结"铁律不变。

## [0.8.0] - 2026-08-14
````

- [ ] **Step 2: 验证 + Commit**

```bash
grep -n '0.9.0' CHANGELOG.md
git add CHANGELOG.md && git commit -m "docs(changelog): 0.9.0 /xcheck-close 评审闭环 + 摄入强化

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 端到端行为验证(手动,开新会话)

**Goal:** 真跑一遍,验证 v0.6 triage + v0.9 闭环 + 摄入强化全部生效。junction 是活的,但 Claude Code 可能缓存旧版 skill 文件——**必须开新会话**。

**Files:** 无改动(只验证)。

> 本任务由用户在交互式会话手动触发;subagent 无法替跑交互式 skill。

- [ ] **Step 1: 摄入验证(自包含零往返)**:先在对话里聊两句给方案相关的约束(如"必须兼容 Windows、不能引新依赖"),再敲 `/xcheck-review <某 spec 文件路径>`。验证:对话里出现"已附带 N 条来自刚才对话的背景";`prompt.txt` 含 CONTEXT 段。
- [ ] **Step 2: 摄入验证(方案型例外)**:讨论出一个方案后敲 `/xcheck-review 评审刚才的方案`。验证:出现固化 proposal + 事实清单的**过目确认**弹窗;确认后 `prompt.txt` 的 PROPOSAL=固化方案、CONTEXT=事实清单。
- [ ] **Step 3: run.md 验证**:评审跑完,`ls .xcheck/<ts>/` 应有 `run.md`,五个字段齐(mode=review/ts/selected/prompt/source)。
- [ ] **Step 4: 闭环全流程**:敲 `/xcheck-close`。验证:C0 校验通过;C1 逐条三值判定落 CLOSE.md;C2 弹 multiSelect 批准;C3 必改清单(有未决则逐条问);C4 产出 `.rev1.md` + diff、原稿未动;C5 问复审;结束后 SUMMARY 末尾有 closed 标记、CLOSE.md 有终态段。
- [ ] **Step 5: 异常路径抽验**(至少 2 项):① 再敲一次 `/xcheck-close` → 应提示"已闭环";② `/xcheck-close 20260101-000000`(不存在)→ 报"找不到该次评审"并列出现有 ts;③ 复审跑到一半 Ctrl 打断,再 `/xcheck-close <ts>` → 从未完成阶段续。
- [ ] **Step 6: 记录结果**(无 commit;`.xcheck/` 已 gitignore)。发现偏差 → 回对应 Task 修正文件后重验。

---

## Self-Review

**1. Spec coverage:**

| Spec 要求 | 实现位置 |
|---|---|
| C0 六项校验 + closed 标记格式 + 恢复判定 | Task 3 close-flow.md C0 |
| C1 只读查证三值、>10 条分批 subagent | Task 3 C1 |
| C2 multiSelect 一次批准、exp/ 落盘、三禁令 | Task 3 C2 |
| C3 归宿表(必改/不需采纳/未决/仅参考)、空必改走向 | Task 3 C3 |
| C4 主会话亲写、rev 命名两分支、原稿不动、自代入纪律、手改基线 | Task 3 C4 |
| C5 每轮问、≤2 轮、收敛判据、推倒重来、复审集(run.md selected ∩ INSTALLED、分支 C、--agents) | Task 3 C5 |
| 收尾三件套(CLOSE.md 终态段/closed 标记/闭环总结) | Task 3 收尾 |
| 阶段粒度恢复、批准不跨恢复记忆、中止不加 closed | Task 3 恢复 + 边界 |
| run.md 五字段(含 source) | Task 1 Edit A |
| 6.5 引导句(review 加、diag 不加) | Task 1 Edit C |
| 方案型例外三步固化(过目 + 事实提取 + 分槽) | Task 2 Edit A/B |
| 自包含零往返(静默摘 + 明说一句 + prompt.txt 留底) | Task 1 Edit B 指针 + Task 2 Edit C |
| junction 安装 | Task 4 Step 2 |
| CHANGELOG 0.9.0 | Task 5 |
| 端到端五步测试法 | Task 6(六步,异常抽验并入) |

无遗漏。

**2. Placeholder scan:** 无 TBD/TODO;所有 Edit 含完整 old/new string;close-flow.md / SKILL.md 全文嵌入照抄。

**3. 一致性:** `run.md` 字段名(mode/ts/selected/prompt/source)在 Task 1(写入)与 Task 3 C0(读取)一致;`{{CONTEXT}}`/`{{PROPOSAL}}` 槽位与 review.md 现有模板一致;`TARGET_TS`/`OVERRIDE_AGENTS` 变量名在 Task 4(壳设置)与 Task 3(close-flow 消费)一致;junction 路径与既有四壳安装方式一致。

计划可执行。
