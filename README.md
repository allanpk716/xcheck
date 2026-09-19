# xcheck

**一次触发 → 本地多个异构 AI agent 盲评 → 自动查证与实验 → 人话结论。停点一问,你拍板。**

*One trigger → blind cross-review by heterogeneous local AI agents → auto-verified verdict in plain language. One gate — you decide.*

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

## 这是什么

你在 Claude Code 里写方案、改设计、查 bug,想要第二意见。如果每个"第二意见"都来自你正在对话的这同一个模型,你什么也学不到。

xcheck 是一组全局 [Claude Code](https://code.claude.com/) skill,把本机其它 AI agent CLI(`codex`、`pi`、`kimi`、`opencode`……)组织成独立盲评审团。一次 `/xcheck` 自动完成摄入、盲评、取证与裁定,用人话交付**哪里能推进、哪里因具体问题暂停、缺什么证据或决定、怎样解除**。正常审核在结果阶段由你决定下一步;night按有限策略接续下游,不替你改定关键需求。

三个关键词:

- **异构** —— 用其它 CLI 取得第二意见;不同 CLI 也可能接同一模型,来源未知不冒称已验证异构;
- **事实与阻断分离** —— 属实不等于必须修订。真正影响目标、验收、安全、数据或实施前提的问题才阻断;有具体严重后果但缺证据/决策的风险单列待决,只暂停相关路径;
- **限定复审** —— 验证原问题修复及重大回归,不为普通新增建议反复改稿。交付精选建议,不自动扩成需求或票。

### 0.21.0 的分期范围

[批准计划](docs/superpowers/plans/2026-09-19-xcheck-review-convergence-and-portability.md)第一、二批已实现保真共识、`review_schema = 2` 决策/问题账本、限定复审、局部暂停及 `--auto-review`。**0.22 精简重构**:三批功能经盲评修订定型——账本塌缩(字段字典单源)、**接管检出**替代 worktree(隔离是操作者的选择,ADR 0005)、**不自动开PR**(交付止于已推分支+晨报一键compare链接,ADR 0006)、**事件驱动并行实施**(就绪集调度,编辑并行提交串行,ADR 0007)、信任模型三档定界(ADR 0004,`material=external` 失败关闭)。旧协议链一律拒绝续跑+提示新开。

配置分离与真正权限隔离**尚未实现**。完整[设计蓝图](docs/superpowers/specs/2026-09-19-xcheck-review-convergence-and-portability-design.md)与[0.22精简重构设计](docs/superpowers/specs/2026-09-19-xcheck-0.22-lean-pipeline-redesign.md)不是已完成功能表。当前 CLI 仍靠提示词要求只读指定材料,**不是强制访问隔离,也不是全库取证**;接管检出只约束提交位置,不隔离文件读取、网络或插件(敌意环境配置出范围,触发条件见 ADR 0004)。diag任何入口都不实施;auto-review诊断不建NIGHT、不通知。

## 快速开始

```bash
git clone <本仓库> && cd xcheck
mkdir -p ~/.claude/skills && cp -r xcheck xcheck-setup ~/.claude/skills/
```

> Windows 开发机可以用 junction 代替拷贝(免提权,且是活的——改仓库即改 skill):
> ```bash
> cmd //c mklink //J "%USERPROFILE%\.claude\skills\xcheck"      "<仓库绝对路径>\xcheck"
> cmd //c mklink //J "%USERPROFILE%\.claude\skills\xcheck-setup" "<仓库绝对路径>\xcheck-setup"
> ```

1. 确保 [Claude Code](https://code.claude.com/) 可用,且**至少两个** agent CLI 在 `PATH` 上、已登录。出厂认识:`claude`、`codex`、`opencode`、`pi`、`kimi`(加新的见 [agent 管理](#agent-管理))。要有意义,至少一家得是非 `claude`。
2. 在 Claude Code 里跑一次 `/xcheck-setup` —— 逐家实测非交互能不能跑通,给出 ✅ / ⏱️ / ❌ / 🔑 一览。
3. 出厂默认评审组 = **codex + pi**(`agents.toml` 里的 `default_agents`),不合适就换:`/xcheck-setup default codex,kimi`。
4. 给它任何东西:

```
/xcheck 评审 docs/superpowers/specs/2026-09-16-foo-design.md
/xcheck 帮我看看这个方案行不行:<贴方案全文>
/xcheck 为什么这个服务一起动就崩:<完整报错栈>
/xcheck --auto-review 评审 docs/superpowers/specs/2026-09-16-foo-design.md
                   ← 无人值守审核:必要时修订并复审一次,到审核交付结束,不实施或发布
/xcheck --night 评审 docs/superpowers/specs/2026-09-16-foo-design.md
                   ← 夜链:评审完自动固化 spec、拆票、逐票实施,每票推远端,收工开 PR,早上看 PR 和晨报
/xcheck            ← 裸敲:续跑未完成的链,或从刚才的对话里猜你要评什么
```

## 一次 /xcheck 会发生什么

```
/xcheck <文字>
   │  明确文件/贴文 ──→ 保持指定对象
   │  明确“刚讨论” ─→ 固定当前讨论,短答绑定问题/选项,保留修正与未决
   │  含糊输入 ─────→ 自动整理,仅对象/重要决策歧义时正常模式确认
   ▼
 proposal + 必要背景 + decisions.md(稳定D编号)
   ▼
 检测 + 冒烟预检(读文件回显,超时只重试一次;不足两家停止)
   ▼
 并行盲评(首轮互不可见;≤2KB指令引用内容文件,非权限隔离)
   ▼
 紧凑头汇总 → 三类取证分类 → FINDINGS.md(三类均有稳定F编号)
   ▼
 ①只读查证 · ②本地实验 · ③保留未确定
   ▼
 主会话分别裁定事实、具体影响、阻断/非阻断/重大风险待决与解除条件
   ▼
 ══ 结果停点:能推进哪里、暂停哪里、怎么解除、需要你决定什么 ══
   ├─ 无活动约束 → 无需修订/收敛;普通建议可保留
   ├─ 先交付 → 保留相关路径暂停,不等于授权绕过问题
   └─ 有已授权可执行修复 → 新修订稿(原稿正文不动)→ 限定范围复审
       正常模式两轮后仍有约束 → 再修 / 按现状交付 / 明确放弃

 diag 止于综合诊断 + 旧三分类,没有验证链与停点问题。
```

过程只播简短进度,明细落盘。正常模式的开口集中在入口选择、续跑确认、对象/重要决策歧义确认和结果停点。无人值守审核与night都不等用户,但不能自动改定关键决策:记录未决并暂停受影响路径,全局目标不明则停止。

### 停点你会看到什么(示例)

> 数据迁移路径暂时不能推进;独立的界面文案工作可以继续。
>
> **必须先解决:**迁移方案在导入失败时先删旧数据,会丢失用户记录。codex 提出,主会话核对迁移步骤后证实。需改成失败保留旧数据,并验证失败路径,才能解除暂停。
>
> **需要你决定:**方案同时写了“保留全部历史记录”和“30天自动删除”。目前无法替你选择,删除任务及其依赖先暂停;决定保留规则后再更新约束并验证。
>
> **可选建议:**补充一张流程图便于阅读,不影响实施,也不会自动拆成新票。
>
> 这轮还没改稿。建议先确定保留规则,再修订迁移路径。原始评审和逐条证据都在 `.xcheck/20260919-142233/`,不需要先打开文件才能决定。

机器编号、事实/裁定状态和完整来源留在 decisions/FINDINGS/SUMMARY;对话当场解释问题、影响范围和解除条件。

### 修订与复审

修订只针对已授权且可修复的阻断。主会话基于本轮快照写新稿:正常审核/auto-review的文件型在原文件同目录 `<原名>.rev1.md`,贴文在 `.xcheck/<ts>/`;**完整night的共识、修订与评审附录始终只写 `.xcheck/<ts>/`**,不追加被评原文件。night的 `source=inline`,`original_source` 仅追溯。**原稿正文不动**,源文件中途被改不能静默换基线;关键决策冲突须明确回答,泛答“再修一轮”不授权改定所有约束。

复审使用独立模板及 `re-review-context.md`,带上轮完整问题、决策约束、差异和逐条修复理由。只审原约束修复、修改回归和新重大缺陷;普通新增建议不触发再修,旧问题没再提也不等于解除。冒烟仅在最近真实成功、配置指纹一致、上轮完整成功时可跳,收集时仍须至少两家成功。

活动约束(开放的阻断或重大风险待决)清空即收敛,不要求建议清零,也不代表代码/测试已通过。正常模式两轮后仍有约束时可再修、按现状交付或明确放弃;没有新修复路径时会说明无进展,不靠润色假装修好。

正常审核/auto-review的讨论对象可固化为 `docs/superpowers/specs/<日期>-<主题>-consensus.md`,结论性终态的文件型对象会在文末收到评审附录;完整night的共识只留 `.xcheck/`,附录为 `.xcheck/<ts>/review-appendix.md`。附录给出活动约束及证据/缺口、暂停范围、解除条件,加已解除摘要和精选建议。**附录是有范围约束的交付,不是把全部意见转成需求。**

### 夜链:--night,睡前一把梭

**入口为旗标直选(0.22)**:无旗标 = 正常交互审核;`--auto-review` = 仅无人值守审核;`--night` = 完整夜链(含实施与推送)。两旗标互斥,不再弹三选一入口问。

`--auto-review` 不等用户,仅在已确认范围内有可执行阻断修复时最多自动修订并限定复审一次;预算用尽或遇决策边界可记兼容终态“夜间收工”,但**不建 NIGHT、不进第11步、不拆实施票、不推送/开PR/通知**。仍可写本地快照、共识稿、新修订稿和文件评审附录,不是零文件写入模式。

白天聊完方案,睡前敲 `/xcheck --night 评审 <方案>` 就去睡:

- 评审段不等你:仅在首轮有已确认范围内可修复的阻断时自动修订并限定复审一次。仅重大待决、需要变更用户决定、无可执行修复或复审后仍有约束,记 `夜间收工`;**这不解除约束、不代表全面放行**。
- 下游仍内联执行 `to-spec` → `to-tickets` → 并行实施(就绪集调度、泳道编辑+主会话按票提交),但只把已确认共识、必要修复和验收目标写进规格。**精选一般建议未经明确采纳不扩成故事/票**。问题映射到票及真实依赖:直接约束票 `paused`,依赖未完成票 `blocked`,确定独立的票才推进;未知依赖不假定独立。
- 完成票记 `complete`(提交和验证证据)后尝试推远端。暂停/受阻不算完成,修复上限耗尽、无下游依赖或先停靠也不能把真实阻断变完成;有残留约束或未完成票不报全绿。
- **交付边界(0.22)**:夜链接管当前检出起分支干活(`night-git.sh start`);NIGHT冻结start_oid/branch/remote_url(脱敏)/pr_base/web_base;每次start刷新脏区底账+内容快照,与操作者未提交改动路径重叠的票停靠。spec/票/必要.gitignore与代码全部在夜链分支提交(`git commit --only --no-verify`),不在原分支commit/push/pull/rebase。每票提交后即推夜链分支(显式URL、不force、不交互、不跑hook);**收工不自动开PR**,晨报给脱敏compare一键链接。`material=external`时实施失败关闭;无remote可本地执行;无Git/HEAD则只审核。
- 早上先看晨报 `.xcheck/<ts>/MORNING.md`:评了什么/改了什么/执行了什么/要决定什么,列已完成、暂停及受依赖阻塞范围和解除条件。对话收尾是“夜链结论 → 简报 → 推荐下一步”。配置了Pushover则尝试三节点通知。PR显式指定冻结仓库/base/head,查询同目标开放PR复用;正文自包含规格、测试证据与未完成范围,不只放本机晨报路径。base不在远端则不建PR,不为此推base。**实施结果与push/PR结果分别记账,全绿不代表已发布**,合并仍由你决定。
- 夜里中断:兼容的新链可 `/xcheck --night` 从票账本重算就绪集续跑;`complete` 需完整OID可达、scoped验证及评审证据;账本无complete提交但路径有残留的票先按失败票路径还原(reset→checkout→clean -fd)再调度。`paused/blocked` 或全局待决写入 `NIGHT.md waiting`,impl/finish保持未勾,晨报先交付暂停原因。续跑先核新证据/决策并更新问题记录再重算,没有新证据就返回暂停摘要,不重复实施、发布或通知。全局受约束时不拆可执行票、不建实施分支、不推送。**旧协议链(无review_schema或0.21字段集)一律拒绝续跑,提示新开**。
- **前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条权限弹窗能挂整夜。

### 中断了怎么办

进度记录在 `.xcheck/<ts>/PROGRESS.md`,新链所有mode均保存 `interaction`/`target`:正常审核为 `interactive/review`,--auto-review为 `unattended/review`,完整night为 `unattended/implementation`。重新敲 `/xcheck` 发现未完成链会询问续跑/新开,续跑沿用账本模式;显式旗标与原链不符则停止,不能借续跑接管或升级授权。旧记录仅两新字段同时缺失时兼容映射:`night=on` 为完整night,无night为正常审核;半缺、非法值或矛盾标记都拒绝。

新版先核验所需快照、D/F账本及复审基线,从第一个未勾阶段重做。缺失材料/未知schema明确停止,不凭会话记忆或勾选假装完成。

旧协议链(无 `review_schema` 的review、0.21及更早字段集的night)一律拒绝自动续跑,提示新开;旧目录只读保留,已结束旧产物仍按旧规则阅读。新版夜链分支丢失或完成提交不可达会停,不会从spec重建后跳过旧完成票。

## 两个命令

都是手动 slash 命令(模型不会自作主张触发)。

| 命令 | 作用 |
|---|---|
| `/xcheck [--auto-review \| --night] [--agents a,b,c] [<文字>]` | 摄入 → 盲评 → 取证 → 裁定交付。裸敲先找兼容未完链,否则解析对象;入口旗标直选(无旗标=交互审核)。--auto-review仅无人值守审核,--night才含spec/票、并行实施与推送(不自动开PR)。模式旗标互斥,续跑不得变更原链交互方式或终点;diag始终不实施。 |
| `/xcheck-setup` | 检测 / 验证 / 登记 agent。子命令见下。 |

`/xcheck` 的输入形态:

| 你给什么 | xcheck 怎么做 |
|---|---|
| 文件路径 | `cp` 成快照,按关键词自动定 review/diag |
| 全文贴文 / 完整报错栈 | 同上,自包含直进 |
| 空或含糊("评审刚才那个") | 明确讨论意图优先当前讨论,保留决策及修正;仅对象/重要决策歧义时正常模式确认 |
| 什么都没有(裸敲) | 先查未完成链;没有就走上面的解析器 |

选集规则:`--agents` 临时指定 > `default_agents` 默认集 > 报错提示先设默认集。默认集里有当前没装的家,自动降级用交集并注明,不弹窗。全 claude 同构不拦,但 SUMMARY 会标注"异构价值未体现"。

### /xcheck-setup 子命令

| 用法 | 作用 |
|---|---|
| `/xcheck-setup` | 探测 PATH 上已登记的 CLI,逐家喂极小 prompt 实测(marker 回显),报 ✅ 跑通 / ⏱️ 超时 / ❌ 命令错 / 🔑 未登录 |
| `/xcheck-setup add <name>` | 登记新 CLI:核实 `--help`、引导填 `agents.toml` 字段、立即验证,失败自动回退 |
| `/xcheck-setup timeout [N \| <agent> N]` | 查看 / 设置 agent 总执行预算(默认集全局 2700s,可按家覆盖) |
| `/xcheck-setup default [a,b,c \| --clear]` | 查看 / 设置 / 清空默认评审组 |

## 产物落在哪

审核留底在项目根 `.xcheck/`(本仓库已gitignore,宿主项目需自行确认)。正常审核/auto-review的正式共识稿、文件修订稿和附录可在原文件位置;完整night审核材料只在 `.xcheck/`,其spec/票/代码则在当前检出的同一夜链分支(接管检出):

```
.xcheck/
├── <ts>/                          # 一次链一个目录(本地时间戳 YYYYMMDD-HHMMSS)
│   ├── PROGRESS.md                #   阶段勾选 + 终态 —— 断点续跑的唯一权威
│   ├── proposal.md / input.md     #   评审 / 诊断对象快照(原文件中途被改不影响本轮)
│   ├── context.md                 #   背景原话(有才建)
│   ├── decisions.md               #   schema2 review:稳定D决策快照
│   ├── FINDINGS.md                #   schema2 review:稳定F事实/裁定/范围/解除条件/历史
│   ├── re-review-context.md       #   复审:上轮完整F/D、修订差异和修复理由
│   ├── prompt.txt                 #   指令层(≤2KB,引用上面的内容文件)
│   ├── <agent>.raw.out            #   各家原始输出,原样留底
│   ├── <agent>.summary.md         #   各家结构化结论
│   ├── <agent>.exitcode 等        #   执行 supervisor 取证(实际命令/运行日志/原始管道)
│   ├── <agent>.failed.md          #   失败记录(有才建)
│   ├── exp/                       #   ②类实验的临时文件,留底不删
│   ├── review-appendix.md          #   完整night评审附录,不追加被评原文件
│   ├── NIGHT.md                   #   (夜链)0.22字段集(基线/分支/远端/compare基准)、四阶段、票台账、push结果
│   ├── night-intake.md            #   (夜链)第 0 步解析留档(夜里不弹窗的过目替代)
│   ├── MORNING.md                 #   (夜链)晨报:四问总交付 + 文末裁定与停靠附录(收尾才有)
│   └── SUMMARY.md                 #   review:裁定投影+三类索引;diag:诊断长文+旧三分类
├── smoke.txt / smoke-prompt.txt   # 冒烟固定文件
└── <agent>.failed.md              # 冒烟淘汰记录
```

各字段的精确语义见 [docs/artifacts.md](docs/artifacts.md)。**无schema旧review**保留旧必改并集(①证实+②成立)、#n编号和旧收敛释义;新版不能重解释历史结论。diag仍用原综合与三分类,不写新版D/F账本。

## agent 管理

`~/.claude/skills/xcheck/agents.toml` 是唯一登记表:每家一个 `[agents.<name>]` 块(`installed_check` / `run_cmd` / `input_mode = arg|stdin` / `needs_timeout` / `timeout_sec`),`[defaults]` 放全局超时和默认集。日常用 `/xcheck-setup` 改;手改可以,但别整文件覆盖(会丢注释和实测注记)。

每家 agent 都跑在 `lib/run-agent.sh` 全托管 supervisor 里:后台启动、全程输出落盘、硬超时(默认 2700s)+ 挂起击杀(输出零增长 ~10 分钟)+ 进程树三层击杀;成败只认 exitcode 文件,不认输出里有没有 "error" 字样。

## 设计原则

1. **盲评** —— 独立进程、并行、互不可见,防串通。
2. **subagent 只搬运、不评判** —— 综合与裁决只发生在主会话(强模型);便宜的模型只做搬运和摘录。
3. **保留人的决策边界** —— 正常审核与auto-review都不自动实施;night只推进已确认范围内且不受约束的票,不自动改定关键需求或合并。实验禁改业务代码/禁联网/禁部署;修订只写新文件,原稿正文不动(终态附录除外)。
4. **对话说人话、文件留机器账** —— 对话当场说清问题、影响和解除条件;D/F编号与完整来源在账本,一般建议不自动扩票。
5. **进度只认盘** —— 全量留底、阶段粒度可续跑,不依赖会话记忆。
6. **成败看退出码** —— codex 的 banner/MCP/hook 噪声不是失败;真伪一律有落盘证据可回放。

## 已知边界

- **至少 2 家**才开跑,冒烟淘汰后不足 2 家也停,不硬跑单家。全 claude 同构**不拦**,只在 SUMMARY 标注"异构价值未体现"——但要有意义,至少一家非 claude。
- **codex 0.153.0(Windows 非交互)**:read-only / workspace-write 沙箱一律拒绝进程创建,须 `-s danger-full-access` 才能参评(已在 agents.toml;升级 codex 后可重试降档)。
- **非交互 `claude -p`** 无授权时读不了工作目录外的路径 —— xcheck 的内容文件全在 `<cwd>/.xcheck/` 下,不受影响;手工测试把文件放别处才会踩到。
- **大文档**没有命令行长度问题:指令层与内容层分离,全文由 agent 自己读文件,绕开 Windows 32767 字符上限。
- **修订预算**:正常模式两轮后仍有活动约束时由用户选择再修/交付/放弃;无人值守审核与night都最多自动修订一次,无可执行修复不空转。预算耗尽不解除阻断。旧链迁移也保留已用自动修订次数,无法核实则禁止自动再修,不会因新环轮次归零获得额外预算。
- **材料范围不是权限隔离**:当前提示词限制读取列出的材料,CLI实际权限仍依赖现有配置(包括codex的danger-full-access);接管检出也不隔离文件读取、网络或插件;`material=external`+自动实施按 ADR 0004 失败关闭。沙箱能力尚未实施。
- **夜链只保进度不合并**:`--night` 每票自动推远端、收工自动开 PR,但绝不自动合并、绝不 force push——合并是早上的手工决定;评审判"推倒重来"、链被中止或 diag 模式不接下游(不写代码,也不推送)。
- 在 **Windows + Git Bash** 上开发与实测;其它 bash 环境理论可用,未系统验证。
- 最低工具版本(0.22 实测口径):**bash ≥ 4.4**(`[[ -v ]]` 需 4.3、`mapfile -d` 需 4.4;macOS 自带 3.2 不达标)、**git ≥ 2.36**(worktree/porcelain -z 系特性;Git for Windows 现行版本远超)。低于下限时 helper 报错方向可能误导,先升工具。
- 夜链建议 **0 点后启动**:22:00–24:00 为上游晚高峰(实测每轮延迟 3–6 倍),见速度诊断。

## 仓库结构

```
xcheck/
├── SKILL.md                        # /xcheck 入口壳:--agents / 未完成链 / 路由 / 转派
├── agents.toml                     # agent 登记表 + 默认配置(超时、默认集)
├── lib/
│   ├── flow.md                     # 自动链大脑:恢复模式 + 第 0~11 步(第 11 步=夜链接续)+ 铁律
│   ├── context-intake.md           # 对象/共识摄入与必要背景
│   ├── review-contract.md          # schema2 D/F、裁定、复审、下游与迁移契约
│   ├── subagent-carrier.md         # 搬运工指令(只搬运不评判)
│   ├── extractor-carrier.md        # 摘录员指令(按来源摘原话)
│   ├── night-delivery.md           # 0.22精简交付协议:接管/提交纪律/发布(不自动开PR)
│   ├── night-git.sh                # start/snapshot/publish:接管检出、脏内容快照、显式URL推送
│   ├── run-mode.sh                 # 纯模式解析(request+两持久字段)
│   ├── run-mode.sh                 # 纯模式解析/旧字段映射/续跑一致性校验
│   ├── run-agent.sh                # agent 执行 supervisor(超时/挂起/击杀/取证)
│   └── detect.sh                   # PATH 探测
├── prompts/                        # diag/review/re-review + 汇总 + 分模式三分类
└── tests/                          # supervisor回归 + review协议离线检查/样例
xcheck-setup/SKILL.md               # /xcheck-setup 壳(4 种模式)
CONTEXT.md                          # 术语表(权威定义)
AGENTS.md                           # 给 AI agent 的维护导览
docs/artifacts.md                   # .xcheck/ 产物解读(给 AI agent)
docs/adr/                           # 架构决策记录
docs/cli-findings.md                # 各 CLI 非交互契约的实测记录(agents.toml 的事实来源)
docs/superpowers/                   # 设计稿与实施计划(历史存档)
CHANGELOG.md
```

## 开发

改 `run-agent.sh` 或 `agents.toml` 解析逻辑,必须跑回归测试(只要 bash + coreutils,约 15 秒):

```bash
bash xcheck/tests/run-agent.test.sh
```

给 AI agent 的维护导览(模块地图、铁律不变量、扩展指南、文档同步义务)见 [AGENTS.md](AGENTS.md);术语的权威定义见 [CONTEXT.md](CONTEXT.md)。

## License

[MIT](LICENSE) © 2026 allanpk716
