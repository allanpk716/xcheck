# xcheck 上手指南 —— 安装与评审 agent 配置

> **这份文档写给谁:写给"你的 AI"。** 人把本文整篇交给 AI(推荐 Claude Code,其他能执行命令的 AI 工具也行),AI 按步骤装、每步验收;人只在出错或需要拍板时介入。装好之后怎么**使用** xcheck,看 [README](../README.md)——使用是人来操作的,不在本文范围。
>
> **平台**:Windows + Git Bash(唯一实测环境;macOS/Linux 未验证)。

## 做完长什么样(总验收)

1. `~/.claude/skills/` 下有 `xcheck`、`xcheck-setup` 两个 skill(skill 是 Claude Code 的指令包,斜杠命令触发);
2. 至少 2 个评审 agent CLI 装好、key 配好,**至少 1 家不是 claude**——全 claude 拿不到有价值的第二意见;
3. 在 Claude Code 里跑 `/xcheck-setup`(无参,只读):配置一览与你要的一致(默认评审组、各家登记都在);
4. `/xcheck 评审 <任一小文件>` 能完整跑一轮——开头冒烟预检逐家通过、最后给出结论。

**前提**:已装 Node.js(带 npm)和 git,网络能到 npm 与各家 API。验收:`node --version`、`git --version` 都出版本号。

## 先弄清一个词:评审 agent

**评审 agent = 被 xcheck 当"第二意见"调用的外部 AI 命令行工具(CLI)**,比如 `codex`、`pi`。一次评审,xcheck 把材料同时发给几家、互不可见地盲评,再由主会话综合裁定。

它和 xcheck 内部的"搬运工"不是一回事:搬运工是 Claude Code 里跑腿的 subagent,只调脚本、搬输出,不发表意见。别把两个词混着用。

**装几家**:出厂默认评审组 = **codex + pi + kimi**,装完即用(kimi 没装也不挡路——运行时自动降级用已装交集)。想要更多独立意见源,再装 opencode / claude。xcheck 的配置分两层(0.25,ADR 0010):**模板层**随 xcheck 分发,五家的调用契约和坑注记都内置,你不用填;**个人层**(`~/.claude/xcheck/personal.toml`)只放你的个人选择(默认组、并发帽这类),由 `/xcheck-setup` 维护,装完可以完全不碰。

## 第 1 步:装 Claude Code

Claude Code 是 xcheck 的宿主(两个 skill 都在它里面跑),也推荐用它来执行后面所有安装和配置。

任选一种(Windows):

```powershell
# PowerShell:官方原生安装器(推荐)
irm https://claude.ai/install.ps1 | iex
```

```bash
# 或 npm
npm install -g @anthropic-ai/claude-code
```

装完**登录**:终端里敲 `claude`,按提示登录 Anthropic 账号。

验收:

```bash
claude --version   # 应输出版本号,例如 2.1.273
```

## 第 2 步:装 xcheck

```bash
git clone <仓库地址> && cd xcheck
```

`<仓库地址>`:找分享给你的同事要。

把两个 skill 目录挂进 Claude Code。Windows 用 junction(一种目录链接:程序把它当真实目录,而且仓库一改、skill 跟着变):

```bash
mkdir -p ~/.claude/skills
cmd //c mklink //J "%USERPROFILE%\.claude\skills\xcheck"      "<仓库绝对路径>\xcheck"
cmd //c mklink //J "%USERPROFILE%\.claude\skills\xcheck-setup" "<仓库绝对路径>\xcheck-setup"
```

不想用链接就拷贝:`cp -r xcheck xcheck-setup ~/.claude/skills/`——但仓库更新后要重新拷。

验收:

```bash
ls ~/.claude/skills/xcheck/SKILL.md ~/.claude/skills/xcheck-setup/SKILL.md   # 两个文件都在
```

以后更新 xcheck = 在仓库里 `git pull`;junction 挂法下即时生效,个人层 `~/.claude/xcheck/` 不在仓库里,升级不碰它。

## 第 3 步:装评审 agent CLI

每家装完都有验收命令。

### codex(OpenAI 的编码 agent CLI;默认组)

```bash
npm install -g @openai/codex
codex --version   # 应输出 codex-cli 0.x.x
```

### pi(轻量编码 agent CLI;默认组)

```bash
npm install -g @earendil-works/pi-coding-agent
pi --version      # 应输出 0.x.x
```

### kimi(Kimi Code CLI,Moonshot 出品;默认组)

不走 npm。安装渠道以官方文档为准——**让 AI 现场查 Kimi Code 官方发布页,按当时的说明装**(我们这边实装的 0.35.0 独立安装在 `~/.kimi-code/`,自带 bin 目录)。装完:

```bash
kimi --version   # 应输出 0.x.x
```

### opencode(可选)

```bash
npm install -g opencode-ai
opencode --version
```

## 第 4 步:配 key 和 endpoint

(endpoint = API 的服务地址;key = 证明你有权调这个 API 的密钥。)

> **⚠️ 先读这段**
>
> 每家 CLI 都要把自己的 key 和 endpoint 配好,这是**各 CLI 自己主目录里的事,xcheck 永不经手**(ADR 0010)。下面只留每家的"配在哪、坑在哪"速查;**各家配置的权威形状在 xcheck 分发模板的注释里**——让 AI 读 `~/.claude/skills/xcheck/agents.toml` 里各家的"配置速览"注记和 `docs/cli-findings.md`,对照当时各家的官方文档核实后再动手。版本号、端点地址、key 申请入口都在变,任何写死的样本都是下一处过时。
>
> 如果集团有统一的 API 网关:把各家配置里的 `base_url` / `baseURL` 换成网关地址即可,其余不变。

### key 去哪申请(让 AI 现场核实申请入口和价格)

| 用途 | 去哪 | 说明 |
|---|---|---|
| GLM(智谱) | open.bigmodel.cn 控制台 | 给 pi / opencode 用;注意 coding 端点和普通端点是两条路径,别混 |
| Kimi | kimi.com / Moonshot 开放平台 | Kimi Code 的 coding 端点 |
| OpenAI / Anthropic | 官网 | codex / claude 走官方账号登录,不需要手工 key |

### 各家怎么配(速查;权威形状见 agents.toml 模板注释)

- **claude**:官方账号交互登录即可(第 1 步已做),无需手工 key。
- **codex**:标准做法 = 终端敲 `codex` 交互登录,凭据自动写 `~/.codex/`。替代做法(不走 OpenAI,指自建代理/GLM)= 手编 `~/.codex/config.toml`(model_provider/base_url/wire_api/experimental_bearer_token)。
- **pi**:手工配两个文件——`~/.pi/agent/settings.json`(defaultProvider/defaultModel)+ `models.json`(baseUrl 用 **coding 端点**、apiKey、模型条目含 compat 块)。先跑一次 `pi` 让它生成目录。
- **opencode**:编辑 `~/.config/opencode/opencode.json`(provider 块:npm/apiKey/baseURL/models)。
- **kimi**:编辑 `~/.kimi-code/config.toml` 两段(default_model + `[providers."managed:kimi-code"]` 的 base_url/api_key)。**警告:这个文件可能混有与本仓无关的 hooks(如 Orca),不要整抄别机样本。**

xcheck 调用各家所需的旗标(如 codex 的 `--skip-git-repo-check -s danger-full-access`)已内置在模板层 `agents.toml`,**不用管**。

## 第 5 步:验收

在 Claude Code 里先敲:

```
/xcheck-setup
```

无参 = 只读状态一览(0.25 起不再试跑任何 CLI):核对登记表、默认评审组、各家超时与你要的一致。配置不对就用它的子命令改(如 `/xcheck-setup default codex,pi,kimi`),详见 README「/xcheck-setup 子命令」。

然后**真跑一轮**(这就是可用性验收——开头的冒烟预检会逐家实测):

```
/xcheck 评审 README.md
```

冒烟结果怎么看:预检通过的家直接进评审;某家被剔除会明确告知原因(超时/未登录/命令错)。要求:你要用的每家都活着,且 ≥2 家、至少 1 家非 claude。谁没活 → 回第 4 步修那家的 key/endpoint,再跑一次。能给出评审结论,安装配置就全部完成。

## 装完之后

日常使用是人敲 `/xcheck`(各种玩法、夜链 `--night`、产物落在哪)看 [README](../README.md)。出问题直接跑一轮 `/xcheck` 看冒烟谁没活,再让 AI 读 `~/.claude/skills/xcheck/agents.toml` 模板注释、`docs/cli-findings.md` 排查。
