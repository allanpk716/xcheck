# xcheck

**一次触发 → 本地多个异构 AI agent 盲评 → 自动查证与实验 → 人话结论。停点一问,你拍板。**

*One trigger → blind cross-review by heterogeneous local AI agents → auto-verified verdict in plain language. One gate — you decide.*

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code skill](https://img.shields.io/badge/Claude%20Code-skill-blue)

---

## 这是什么

你在 Claude Code 里写方案、改设计、查 bug,想要第二意见。如果每个"第二意见"都来自你正在对话的这同一个模型,你什么也学不到。

xcheck 是一组全局 [Claude Code](https://code.claude.com/) skill,把你本机装的**其它** AI agent CLI(`codex`、`pi`、`kimi`、`opencode`……)组织成一组**互相看不见对方的盲评审团**:一次 `/xcheck` 触发,自动跑完"盲评 → 逐条核实 → 沙箱实验",最后用一段人话告诉你——**方案能不能推进、哪几个问题已经查实、哪几个查过不用理、哪几个开发时要盯着**。全程只在结尾停一次,问你一句:改不改。

三个关键词:

- **异构** —— 评审员来自不同厂商的不同模型,不是 Claude 自己审自己;
- **已验证** —— 每条反馈不是被查证(只读核实)、就是被实验(沙箱复现)、要么明说"没法验证";
- **单停点** —— 中间全自动,人的控制权放在对最终结果的拍板上,不在流程签字上。

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
/xcheck --night 评审 docs/superpowers/specs/2026-09-16-foo-design.md
                   ← 夜链:评审完自动固化 spec、拆票、逐票实施,每票推远端,收工开 PR,早上看 PR 和晨报
/xcheck            ← 裸敲:续跑未完成的链,或从刚才的对话里猜你要评什么
```

## 一次 /xcheck 会发生什么

```
/xcheck <文字>
   │  输入含糊或为空 ──→ 对象解析器:从本会话猜你要评什么
   │                     (文件 > 固化讨论 > 诊断),一个确认窗打包过目
   │  输入自包含 ──────→ 词表自动路由 review | diag,静默附带对话背景
   ▼
 检测 + 冒烟预检(每家读文件回显,预算按通道配置,超时自动重试一次;坏家在派发前剔除)
   ▼
 并行盲评:每家一个隔离 subagent,agent 自己读内容文件,prompt 只是 ≤2KB 指令层
   ▼
 紧凑头汇总(各家裁决一行 + 总判)→ 三分类:①可直接证实 ②可实验验证 ③存疑仅参考
   ▼
 自动验证:①逐条只读查证(✅/❌/❓ 带证据)· ②沙箱实验(成立/不成立/无定论,单条 300s)
   ▼
 ══ 单停点:四问人话结论 + 唯一一问"现在改掉再评一轮,还是带着三类清单直接进开发?" ══
   ├─ 带清单进开发 → 三类清单附在被评文档文末,终态"用户不修",链结束
   └─ 修订再评 → 写 <原名>.rev1.md(原稿正文不动)→ 自动复审
              必改清零 → 收敛;改到第 2 轮仍有 → 再问一次(再修 / 收工 / 确认推倒)

 diag 模式(排障)止步于汇总 + 三分类,没有验证链和停点问题。
```

过程中的对话只有一两行标注"无需操作"的进度播报;明细全部落盘。整条链只在四处开口等你:入口一问(仅新链:自动推进还是正常交互)、续跑确认(仅当盘上有未完成的链)、对象确认(仅当输入含糊)、结尾停点(自动模式下全部自动过)。

### 停点你会看到什么(示例)

> 方案能用,但有 2 个问题已经查实,建议改完再动手 —— 改不改你定。
>
> **已查实、必须改的:**
> 1. 迁移脚本没有回滚分支 —— kimi 提的,核实属实(migrations/0021.sql:18,只有 UP 没有 DOWN)
> 2. 新缓存层并发下会重复建连接 —— codex 提的,实测复现(`.xcheck/20260916-142233/exp/` 里的实验)
>
> **查过、不用理的:**
> - pi 说"配置热加载会丢默认值" —— 不成立(config/loader.ts:55 有显式 fallback)
>
> **没法验证、开发时要盯的:**
> - "第三方 API 明年限流政策可能收紧"(kimi)—— 触发:接入量过 10 万/日;命中:停下反馈,别默默绕过
>
> 原始评审和逐条证据都在 `.xcheck/20260916-142233/`。以上是建议,共识 ≠ 正确,最终你拍板。
>
> **要我把这 2 个问题改了、再自动评一轮吗?** [要 / 不要]

机器账(编号 `#n`、enum、①②③、严重度标签)只活在 `.xcheck/<ts>/SUMMARY.md`,对话永远在说你的方案。

### 修订与复审

停点选"修订再评":主会话(持有全部证据的那一个)亲自写修订版——评审对象是文件 → 修订版落在**原文件同目录**(`<原名>.rev1.md`);是贴文 → 落 `.xcheck/<ts>/`。**原稿正文永不动**。然后自动完整复审一轮(冒烟可跳过:上一环各家跑成功 + 配置没动过,否则照跑;跳过后由收尾阶段的"活着不足 2 家就停"闸门兜底);必改清零 → 终态"收敛"。改满两轮仍有问题 → **不再自动判"推倒重来"**,停下来让你三选(再修一轮 / 按现状收工 / 确认推倒)——细节改不干净很正常,很多问题本来就要到编码和测试阶段才见分晓。

评审对象来自纯讨论(没有文件)时,确认窗里过目的固化稿会落成正式共识文档 `docs/superpowers/specs/<日期>-<主题>-consensus.md`,修订版落在它旁边。

链走到结论性终态时(收敛 / 推倒重来 / 无需修订 / 用户不修 / 夜间收工),被评文档**文末**会多出一节"评审附录"——**这就是链的主交付物:一份给下游开发直接消费的三类清单**(①查实的:改什么+证据;②实验已验证的:结果+实验产物;③存疑的:开发中何时会撞上+撞上后停下反馈)。附录声明"验证证据是评审时点快照,以实际执行为准",但③类的"命中就停下反馈"是动作,不是参考。

### 夜链:--night,睡前一把梭

入口一问:敲 `/xcheck <方案>` 会先问你一句——**自动推进到底(默认推荐)还是正常交互**;选自动就等于夜链。赶时间可以直接 `/xcheck --night`,连这一问都免。

白天聊完方案,睡前敲 `/xcheck --night 评审 <方案>` 就去睡:

- 评审段照常全自动;**停点不等你**——round 0 查出必改就自动修订(原稿不动)并复审一轮;round 1 仍有必改就自动"带清单收工",终态记 `夜间收工`。
- 收工后自动接三跳(Matt Pocock 主流程的下游):`to-spec` 把评审后的方案+附录固化成实施 spec(落本地文件,夜里不发 issue tracker;附录里"开发时要盯"的条目直接进 spec)→ `to-tickets` 拆成 tracer-bullet 票(本地 `.scratch/<feature>/issues/`,每票端到端竖切、带验收标准和阻塞关系)→ 隔离 worktree 里**逐票实施**:每票一个全新子代理,TDD 红绿循环写码,独立评审者按双轴(Spec 符合 + 代码质量)审这一票,最后终局全分支评审;**每票完成即推远端保存进度**(推的都是测试全绿的完整小步,不是半成品)。
- **安全栏**:代码改动只在隔离分支;每票自动推远端、收工自动开 PR(只保进度,**绝不自动合并、绝不 force push**);主工作区只落 spec/票这类文档。方案被判"推倒重来"或链被中止 → 不写一行代码(也不推送),通知你早上处理。
- 早上看三样:推送通知(Pushover 三节点,title 带【项目名】,点开直达 PR)+ PR(收工自动开,base = 你睡前所在的分支)+ 晨报 `.xcheck/<ts>/MORNING.md`(评了什么 / 改了什么 / 执行了什么 / 要决定什么,文末附全部裁定)。对话收尾是三段式:夜链结论 → 简报 → 推荐下一步。合不合并,你在 PR 上拍板——夜里只保进度,不替你合并。
- 夜里崩了:重敲 `/xcheck --night` 自动续(评审靠 PROGRESS、spec/票靠 NIGHT.md、逐票实施靠 NIGHT.md 里的票级台账,全在盘上)。
- **前提**:夜间会话要用免弹窗权限模式跑(bypassPermissions 或预放行常用命令),否则子代理一条权限弹窗能挂整夜。

### 中断了怎么办

进度只认盘:每个阶段完成即勾 `.xcheck/<ts>/PROGRESS.md`。会话崩了、机器重启了,重新敲 `/xcheck`,它发现未完成的链,问一句"续跑还是新开",确认后从第一个未完成阶段继续——盲评结果不会白跑,不依赖任何会话记忆。

夜链(自动模式)中断同理:重敲 `/xcheck --night` **自动**续(不弹窗)——评审段靠 PROGRESS、spec/票段靠 NIGHT.md、逐票实施段靠票级台账,三段各有盘上锚点。

## 两个命令

都是手动 slash 命令(模型不会自作主张触发)。

| 命令 | 作用 |
|---|---|
| `/xcheck [--night] [--agents a,b,c] [<文字>]` | 整条自动链:路由 → 盲评 → 三分类 → 验证 → 停点。裸敲 = 查未完成链,没有就从会话上下文解析评审对象(一个确认窗)。入口先问"自动推进还是正常交互"(默认推荐自动);自动/`--night` = 评审完自动接"固化 spec → 拆票 → 逐票 TDD 实施 + 双轴评审",每票自动推远端、收工自动开 PR,晨报叫早。 |
| `/xcheck-setup` | 检测 / 验证 / 登记 agent。子命令见下。 |

`/xcheck` 的输入形态:

| 你给什么 | xcheck 怎么做 |
|---|---|
| 文件路径 | `cp` 成快照,按关键词自动定 review/diag |
| 全文贴文 / 完整报错栈 | 同上,自包含直进 |
| 空或含糊("评审刚才那个") | 对象解析器从最近对话推断对象+模式+背景,一个确认窗过目 |
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

全部在项目根的 `.xcheck/`(本仓库已 gitignore;在别的项目里用时,记得把它加进那个项目的 `.gitignore`):

```
.xcheck/
├── <ts>/                          # 一次链一个目录(本地时间戳 YYYYMMDD-HHMMSS)
│   ├── PROGRESS.md                #   阶段勾选 + 终态 —— 断点续跑的唯一权威
│   ├── proposal.md / input.md     #   评审 / 诊断对象快照(原文件中途被改不影响本轮)
│   ├── context.md                 #   背景原话(有才建)
│   ├── prompt.txt                 #   指令层(≤2KB,引用上面的内容文件)
│   ├── <agent>.raw.out            #   各家原始输出,原样留底
│   ├── <agent>.summary.md         #   各家结构化结论
│   ├── <agent>.exitcode 等        #   执行 supervisor 取证(实际命令/运行日志/原始管道)
│   ├── <agent>.failed.md          #   失败记录(有才建)
│   ├── exp/                       #   ②类实验的临时文件,留底不删
│   ├── NIGHT.md                   #   (夜链)下游接续进度:review/plan/impl/finish+票级台账+push/pr 结果
│   ├── night-intake.md            #   (夜链)第 0 步解析留档(夜里不弹窗的过目替代)
│   ├── MORNING.md                 #   (夜链)晨报:四问总交付 + 文末裁定与停靠附录(收尾才有)
│   └── SUMMARY.md                 #   机器账:结论区 + 三分类明细 + 逐条证据
├── smoke.txt / smoke-prompt.txt   # 冒烟固定文件
└── <agent>.failed.md              # 冒烟淘汰记录
```

各字段的精确语义见 [docs/artifacts.md](docs/artifacts.md)(给 AI agent 读的产物解读,人看也行)。

## agent 管理

`~/.claude/skills/xcheck/agents.toml` 是唯一登记表:每家一个 `[agents.<name>]` 块(`installed_check` / `run_cmd` / `input_mode = arg|stdin` / `needs_timeout` / `timeout_sec`),`[defaults]` 放全局超时和默认集。日常用 `/xcheck-setup` 改;手改可以,但别整文件覆盖(会丢注释和实测注记)。

每家 agent 都跑在 `lib/run-agent.sh` 全托管 supervisor 里:后台启动、全程输出落盘、硬超时(默认 2700s)+ 挂起击杀(输出零增长 ~10 分钟)+ 进程树三层击杀;成败只认 exitcode 文件,不认输出里有没有 "error" 字样。

## 设计原则

1. **盲评** —— 独立进程、并行、互不可见,防串通。
2. **subagent 只搬运、不评判** —— 综合与裁决只发生在主会话(强模型);便宜的模型只做搬运和摘录。
3. **单停点人在环** —— 永不自动改代码、自动合并、自动"通过";实验锁沙箱(禁改业务代码/禁联网/禁部署);修订只写新文件,原稿正文永不动(唯一例外:终态评审附录)。
4. **对话说人话、文件留机器账** —— 对话与附录每句都在说你的方案;编号、enum、①②③只活在 SUMMARY.md。
5. **进度只认盘** —— 全量留底、阶段粒度可续跑,不依赖会话记忆。
6. **成败看退出码** —— codex 的 banner/MCP/hook 噪声不是失败;真伪一律有落盘证据可回放。

## 已知边界

- **至少 2 家**才开跑,冒烟淘汰后不足 2 家也停,不硬跑单家。全 claude 同构**不拦**,只在 SUMMARY 标注"异构价值未体现"——但要有意义,至少一家非 claude。
- **codex 0.153.0(Windows 非交互)**:read-only / workspace-write 沙箱一律拒绝进程创建,须 `-s danger-full-access` 才能参评(已在 agents.toml;升级 codex 后可重试降档)。
- **非交互 `claude -p`** 无授权时读不了工作目录外的路径 —— xcheck 的内容文件全在 `<cwd>/.xcheck/` 下,不受影响;手工测试把文件放别处才会踩到。
- **大文档**没有命令行长度问题:指令层与内容层分离,全文由 agent 自己读文件,绕开 Windows 32767 字符上限。
- **修订软上限 2 轮**:第 2 轮后仍有已查实问题时停下来让你拍板(再修 / 带清单收工 / 确认推倒),不自动判推倒。
- **夜链只保进度不合并**:`--night` 每票自动推远端、收工自动开 PR,但绝不自动合并、绝不 force push——合并是早上的手工决定;评审判"推倒重来"、链被中止或 diag 模式不接下游(不写代码,也不推送)。
- 在 **Windows + Git Bash** 上开发与实测;其它 bash 环境理论可用,未系统验证。

## 仓库结构

```
xcheck/
├── SKILL.md                        # /xcheck 入口壳:--agents / 未完成链 / 路由 / 转派
├── agents.toml                     # agent 登记表 + 默认配置(超时、默认集)
├── lib/
│   ├── flow.md                     # 自动链大脑:恢复模式 + 第 0~11 步(第 11 步=夜链接续)+ 铁律
│   ├── context-intake.md           # 对象解析器(文件>讨论>诊断>反问)+ 零往返背景
│   ├── subagent-carrier.md         # 搬运工指令(只搬运不评判)
│   ├── extractor-carrier.md        # 摘录员指令(按来源摘原话)
│   ├── run-agent.sh                # agent 执行 supervisor(超时/挂起/击杀/取证)
│   └── detect.sh                   # PATH 探测
├── prompts/                        # 指令模板:diag/review + 汇总 + 三分类
└── tests/run-agent.test.sh         # supervisor 回归测试(33 断言,零依赖)
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
