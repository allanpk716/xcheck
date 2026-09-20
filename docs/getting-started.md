# xcheck 上手指南 —— 安装与评审 agent 配置

> **这份文档写给谁:写给"你的 AI"。** 人把本文整篇交给 AI(推荐 Claude Code,其他能执行命令的 AI 工具也行),AI 按步骤装、每步验收;人只在出错或需要拍板时介入。装好之后怎么**使用** xcheck,看 [README](../README.md)——使用是人来操作的,不在本文范围。
>
> **平台**:Windows + Git Bash(唯一实测环境;macOS/Linux 未验证)。

## 做完长什么样(总验收)

1. `~/.claude/skills/` 下有 `xcheck`、`xcheck-setup` 两个 skill(skill 是 Claude Code 的指令包,斜杠命令触发);
2. 至少 2 个评审 agent CLI 装好、key 配好,**至少 1 家不是 claude**——全 claude 拿不到有价值的第二意见;
3. 在 Claude Code 里跑 `/xcheck-setup`,你要用的每家都是 ✅;
4. `/xcheck 评审 <任一小文件>` 能完整跑一轮、给出结论。

**前提**:已装 Node.js(带 npm)和 git,网络能到 npm 与各家 API。验收:`node --version`、`git --version` 都出版本号。

## 先弄清一个词:评审 agent

**评审 agent = 被 xcheck 当"第二意见"调用的外部 AI 命令行工具(CLI)**,比如 `codex`、`pi`。一次评审,xcheck 把材料同时发给几家、互不可见地盲评,再由主会话综合裁定。

它和 xcheck 内部的"搬运工"不是一回事:搬运工是 Claude Code 里跑腿的 subagent,只调脚本、搬输出,不发表意见。别把两个词混着用。

**装几家的两档**:

| 档位 | 装什么 | 说明 |
|---|---|---|
| 最小推荐 | Claude Code + codex + pi | 出厂默认评审组就是 codex + pi,装完即用 |
| 全家桶 | claude / codex / opencode / pi / kimi 全装 | 独立意见源更多,要配的 key 也更多 |

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

以后更新 xcheck = 在仓库里 `git pull`;junction 挂法下即时生效。

## 第 3 步:装评审 agent CLI

按你选的档位装,每家装完都有验收命令。

### codex(OpenAI 的编码 agent CLI)

```bash
npm install -g @openai/codex
codex --version   # 应输出 codex-cli 0.x.x
```

### pi(轻量编码 agent CLI)

```bash
npm install -g @earendil-works/pi-coding-agent
pi --version      # 应输出 0.x.x
```

### opencode(全家桶档)

```bash
npm install -g opencode-ai
opencode --version
```

### kimi(全家桶档;Kimi Code CLI,Moonshot 出品)

不走 npm。安装渠道以官方文档为准——**让 AI 现场查 Kimi Code 官方发布页,按当时的说明装**(我们这边实装的 0.35.0 独立安装在 `~/.kimi-code/`,自带 bin 目录)。装完:

```bash
kimi --version   # 应输出 0.x.x
```

## 第 4 步:配 key 和 endpoint

> **⚠️ 先读这段——本文最重要的一段**
>
> 下面每家的配置是**我们这边机器上实际在用的做法,当参考样本看**,不是照抄的规范。版本号、端点地址、key 申请入口都在变,抄死的东西就是下一处过时。
>
> 正确用法:**人只要知道"每家 CLI 都要把 key 和 endpoint 配好"这件事,然后把本节交给 AI**。AI 拿这里当起点,对照当时各家的官方文档核实后再动手,不要逐字照抄本文。
>
> 如果集团有统一的 API 网关:把下文各家配置里的 `base_url` / `baseURL` 换成网关地址即可,其余不变。

(endpoint = API 的服务地址;key = 证明你有权调这个 API 的密钥。)

### key 去哪申请(让 AI 现场核实申请入口和价格)

| 用途 | 去哪 | 说明 |
|---|---|---|
| GLM(智谱) | open.bigmodel.cn 控制台 | 我们给 pi / opencode 用的;coding 端点和普通端点是两条路径,见下文各家配置 |
| Kimi | kimi.com / Moonshot 开放平台 | Kimi Code 的 coding 端点 |
| OpenAI / Anthropic | 官网 | codex / claude 走官方账号登录,不需要手工 key |

### claude —— 官方登录即可

第 1 步已经登录过,这步不用再配。(我们这边额外把 claude 接到了自建 GLM 代理,属于个人环境,同事不需要。)

### codex —— 标准做法:交互登录

```bash
codex   # 首次运行,按提示用 ChatGPT 账号登录,凭据自动写入 ~/.codex/
```

xcheck 调 codex 需要的旗标(`--skip-git-repo-check -s danger-full-access`)已经写在 xcheck 的 `agents.toml` 里,同事**不用管**。

我们这边的替代做法(仅供参考):不走 OpenAI,把 codex 指到自建代理→GLM。`~/.codex/config.toml`:

```toml
model_provider = "custom"
model = "glm-5.3"
model_reasoning_effort = "high"

[model_providers.custom]
name = "zhipu_glm"
base_url = "<你的代理地址>/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "<代理管理的 token>"
```

### pi —— 手工配 provider

装完先跑一次 `pi` 让它生成 `~/.pi/agent/` 目录,退出,然后编辑两个文件。

`~/.pi/agent/settings.json`:

```json
{
  "defaultProvider": "bigmodel",
  "defaultModel": "glm-5.3"
}
```

`~/.pi/agent/models.json`(key 放这里):

```json
{
  "providers": {
    "bigmodel": {
      "baseUrl": "https://open.bigmodel.cn/api/coding/paas/v4",
      "api": "openai-completions",
      "apiKey": "<你的 GLM API key>",
      "models": [
        {
          "id": "glm-5.3",
          "name": "GLM-5.3",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 1000000,
          "maxTokens": 131072,
          "compat": {
            "supportsDeveloperRole": false,
            "thinkingFormat": "zai",
            "zaiToolStream": true
          }
        }
      ]
    }
  }
}
```

说明:用的是 coding 端点(`/api/coding/paas/v4`)。`compat` 块是 GLM 兼容性开关,让 AI 按 pi 当前文档核对;模型的其他字段(上下文窗口等)以官方模型页为准。

### opencode(全家桶档)

编辑 `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "glmcode/glm-5.2",
  "provider": {
    "glmcode": {
      "name": "Zhipu GLM",
      "npm": "@ai-sdk/anthropic",
      "options": {
        "apiKey": "<你的 GLM API key>",
        "baseURL": "https://open.bigmodel.cn/api/paas/v4"
      },
      "models": {
        "glm-5.2": { "name": "GLM-5.2" }
      }
    }
  }
}
```

### kimi(全家桶档)

编辑 `~/.kimi-code/config.toml`,核心两段(其余字段让 AI 对照装机默认配置补):

```toml
default_model = "kimi-code/k3"

[providers."managed:kimi-code"]
type = "kimi"
base_url = "https://api.kimi.com/coding/v1"
api_key = "<你的 Kimi API key>"
```

想让模型档位可选,再补一段(我们机器上的形状):

```toml
[models."kimi-code/k3"]
provider = "managed:kimi-code"
model = "k3"
max_context_size = 1048576
capabilities = [ "thinking", "always_thinking", "image_in", "video_in", "tool_use" ]
display_name = "K3"
support_efforts = [ "low", "high", "max" ]
default_effort = "high"
```

(我们机器上这个文件里还有一大段 Orca 工具管理的 hooks,与 xcheck 无关,**不要抄**。)

## 第 5 步:验收

在 Claude Code 里敲:

```
/xcheck-setup
```

它会对每家已装 CLI 喂一句极小 prompt 实测,结果含义:

| 符号 | 含义 | 下一步 |
|---|---|---|
| ✅ | 跑通 | 不用动 |
| 🔑 | 疑似未登录 / key 无效 | 回第 4 步,查那家的 key |
| ⏱️ | 超时 | 查网络和 endpoint(端点慢或挂了) |
| ❌ | 命令本身报错 | 把 stderr 贴给 AI 排查 |

要求:你要用的每家 ✅,且 ≥2 家、至少 1 家非 claude。出厂默认评审组 = codex + pi,要换就 `/xcheck-setup default <名字逗号分隔>`(如 `/xcheck-setup default codex,kimi`)。

最后试跑一轮:

```
/xcheck 评审 README.md
```

能给出评审结论,安装配置就全部完成。

## 装完之后

日常使用是人敲 `/xcheck`(各种玩法、夜链 `--night`、产物落在哪)看 [README](../README.md)。出问题先跑 `/xcheck-setup` 复测,再让 AI 读 `~/.claude/skills/xcheck/` 下的文档排查。
