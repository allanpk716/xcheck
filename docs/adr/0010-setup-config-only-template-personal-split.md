# setup 收窄为纯配置:删验证/永不碰key/可用性归运行时冒烟;agents.toml 拆分发模板(仓库内)+个人层(仓库外),已知家一键启用,默认档 codex+pi+kimi、砍多档位

2026-09-21 setup 复杂度调查(getting-started 第 4 步 key/端点配置占全文约 50% 且 xcheck 完全不接管;启用一家=手填 5 个机器契约字段,坑知识散在 agents.toml 注释/cli-findings/subagent-carrier 三处;agents.toml 单文件身兼机器注册表与个人配置中心,背「禁整文件写」纪律;setup 验证与运行时冒烟双轨两套口径;配置入口 8 触点)。用户定边界原则并经 grilling 多轮确认:setup 只配置用哪些评审 agent,不检查可用性——否则项目持续臃肿。运行时已有完整可用性链(detect ∩ 选集 → 冒烟 → 失败剔除降级,flow.md 第 1-2 步),setup 侧验证是重复职能。

决定(2026-09-21):

1. **setup 职责=纯配置**:登记、选集默认档、个人参数(超时/并发帽/重试)。删除模式 A 验证循环(marker `hello-from-*`、逐家容噪规则、`/tmp/xcheck-verify-*`);无参调用改只读状态展示(登记名单/默认集/个人层覆盖/两层冲突)。可用性唯一权威=运行时冒烟;安装验收=真跑一轮小评审看冒烟汇报。
2. **setup 永不碰 key/登录态**:各 CLI 自管;getting-started 第 4 步砍半——端点/模型名/坑知识收编进分发模板注释,文档只留指引。
3. **两层分离**:模板层(仓库内:契约字段+实测坑注记,随分发走)+ 个人层(仓库外 `~/.claude/xcheck/`:默认档/lanes/retry/超时覆盖);run-agent 与 flow 读两层合并,个人层覆盖模板层。
4. **已知家一键启用**:5 字段零手填;模式 B 填表引导仅保留给未知 CLI(第 6 家起)。
5. **默认档 codex+pi+kimi**(未装者运行时 ∩ INSTALLED 自动降级,不阻塞);**砍多档位**——一个默认档 + `--agents` 单次换 + `default` 子命令永久改,零新增机制。
6. **明确不做**:setup 内探测/验证/探测失败分支、智能推荐、setup 碰 key、多档位预设集、新增命令(命令面仍 2 条,ADR 0001 兼容)。

**取代声明**:本决策取代 2026-08-13 default-agents 设计稿「个人配置随 git 仓库走」取舍——个人层出仓库,defaults 不再随 git 走。与 ADR 0001(命令面 5→2)兼容:全部职能收在 `/xcheck-setup` 内,不新增命令。

## Considered Options

- **只做轻量简化(加预设+自动探测,不分离文件)**——探测即验证分支,违边界原则;第四批仍欠着以后还得再动,否。
- **双轨合一(setup 验证复用冒烟口径)**——仍留 setup 侧第二套执行路径,讨论中用户升级为整体删除,否。
- **个人层放仓库内+gitignore**——junction 场景升级不丢,但「个人配置活在仓库目录」语义仍两混,分发纯净度不如出仓库,否。
- **保持随 git 仓库走(现状)**——升级即冲突面、分发即污染(default-agents 设计稿自己承认的取舍),否。
- **多档位 minimal/standard/full**——实际使用全部 6 链未换过档,`--agents`+`default` 已覆盖,多一坨预设维护面,否。

## Consequences

- run-agent.sh/flow/detect 改两层读取合并 → run-agent.test.sh 33 断言连改;night-parallel.test.sh 中锁 setup/SKILL.md 与 agents.toml 句式的约 10 条断言连改(模式 E 文本、night_parallel_lanes 位置等)。
- 现行 agents.toml 迁移:契约+实测注记留仓库成模板层,`[defaults]` 抽个人层;「禁整文件写」纪律模板层保持(注释仍是事故实测注记),个人层为生成物可整写。
- 五处文档同步义务(AGENTS.md:153-159):CHANGELOG/CONTEXT/README+getting-started/AGENTS+specs;getting-started 第 3/4/5 步重写。
- 可用性反馈延迟:配置错误(未装/key 失效/端点不通)要到真跑评审冒烟才暴露,不再有 setup 预检——用户明确接受(外部自理)。
- key/端点知识从 getting-started 移入模板注释后文档过时面缩小,但模板注释同样会过时,仍靠 cli-findings 实测记录维护。
