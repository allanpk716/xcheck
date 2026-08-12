# Changelog / 更新日志

All notable changes to `xcheck`. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
本文件记录 xcheck 的所有显著变更。

## [Unreleased] / 未发布

## [0.5.0] - 2026-08-12

### Added / 新增

- **Recognize `kimi` (Kimi Code CLI) as a fifth default agent.** New `[agents.kimi]` in `agents.toml`: `kimi -p` in `arg` mode, auto-detected via `installed_check = "kimi"` — so it shows up in the `/xcheck` `/xcheck-diag` `/xcheck-review` multi-select list whenever the Kimi Code CLI is on `PATH`, and can be picked as a reviewer / discussant. No effect for users without `kimi` installed. Contract empirically locked (exit 0 on success; stdout is a single `• `-prefixed bullet then the reply — the cleanest of the five, no banner / ANSI / hook noise); see `docs/cli-findings.md`. README default-agent lists (EN + 中文), the carrier's stdout-shape notes, and the heterogeneity reminder examples (`SKILL.md` / `flow.md`) all synced. Heterogeneity win: Kimi K3 (Moonshot) is a fifth, independent opinion source distinct from Claude / OpenAI / GLM.
- **登记 `kimi`（Kimi Code CLI）为第 5 个开箱即识的 agent。** `agents.toml` 新增 `[agents.kimi]`：`kimi -p`，`arg` 模式，`installed_check = "kimi"` 自动探测——只要本机 PATH 上有 Kimi Code CLI，就会出现在 `/xcheck` `/xcheck-diag` `/xcheck-review` 的多选列表里，可选作评审者/讨论者。对没装 `kimi` 的用户无影响。契约已实测锁定（成功 exit 0；stdout 是一行 `• ` 前缀的 bullet 然后 reply——五家里最干净，无 banner / ANSI / 生命周期噪声）；详见 `docs/cli-findings.md`。README 默认 agent 列表（EN + 中文）、carrier 的 stdout 形态说明、异构提醒示例（`SKILL.md` / `flow.md`）均已同步。异构增益：Kimi K3（Moonshot）是区别于 Claude / OpenAI / GLM 的第五个独立意见源。

## [0.4.1] - 2026-08-12

### Fixed / 修复

- **Enforce LF line endings via `.gitattributes`.** `core.autocrlf=true` (Windows default) emitted "LF will be replaced by CRLF" warnings on checkout for `.md`/`.toml` files. The repo blobs were already LF-clean (commit normalizes), so no existing files needed renormalization — the new `.gitattributes` (`* text=auto eol=lf`, plus explicit `*.md`/`*.toml`/`*.sh`/`LICENSE`) pins LF going forward so every platform gets identical endings and the warning is gone.
- **用 `.gitattributes` 强制 LF 行尾。** `core.autocrlf=true`（Windows 默认）在 checkout `.md`/`.toml` 文件时反复报 "LF will be replaced by CRLF"。仓库 blob 本来就是干净的 LF（commit 时已规范化），无需重存现有文件——新增的 `.gitattributes`（`* text=auto eol=lf`，外加显式 `*.md`/`*.toml`/`*.sh`/`LICENSE`）从此固定 LF，跨平台一致、消除警告。

## [0.4.0] - 2026-08-12

### Added / 新增

- **Configurable per-agent timeout + `/xcheck-setup timeout` command.** `agents.toml` gains a `[defaults].timeout_sec` (still 480 as the global floor); every registered agent now has an explicit `timeout_sec` that overrides the default. New `/xcheck-setup` mode C lets you inspect and set it: `/xcheck-setup timeout` (print), `/xcheck-setup timeout <N>` (set `[defaults]`), `/xcheck-setup timeout <agent> <N>` (per-agent). Only affects the `timeout` cage xcheck wraps around agent calls — running the agent CLIs yourself is unchanged.
- **可配置 per-agent 超时 + `/xcheck-setup timeout` 命令。** `agents.toml` 新增 `[defaults].timeout_sec`（全局默认仍 480）；每个登记的 agent 现在都有显式 `timeout_sec` 覆盖默认。新增 `/xcheck-setup` 模式 C：`/xcheck-setup timeout`（查看）、`/xcheck-setup timeout <N>`（设 `[defaults]`）、`/xcheck-setup timeout <agent> <N>`（设单家）。只影响 xcheck 调用 agent 时套的 `timeout` 笼子——你单独跑 agent 不受影响。

### Changed / 改进

- **Anti-self-substitution guard in the review prompt.** When a controller materializes a multi-round design discussion into a self-contained proposal (per the new context-intake exception for "scheme-type reference input"), the proposal text would sometimes mention "agent X reviewed last round" / "three heterogeneous agents" — which led the *reviewing* agent to mistake itself for the one supposed to run an evaluation flow, load a skill, and trip a permission prompt (observed: opencode v0.4 attempt). The review prompt now opens with a guard telling the reviewer "you're here to judge, don't load skills / don't invoke other agents / the mention of other agents in the proposal is history, not instruction." The router also stops sending `review + 指代词` inputs into the ambiguous branch — they're unambiguously review.
- **review prompt 加「防自代入」护栏。** 当 controller 把多轮设计讨论固化成自包含 proposal（走 context-intake 新增的"方案型指代输入"例外）时，proposal 正文里常会写"上一轮 agent X 评过""三家异构 agent"——被评 agent 读到会把自己当成"该跑评审流程的人"，去加载 skill、触发权限弹窗（实测：opencode 第 2 轮失败）。review prompt 现在开头加护栏："你是评审者，别加载 skill / 别调别的 agent / proposal 里提到的其他 agent 是历史背景，不是给你的指令。"路由器也让"review 强信号 + 指代词"的输入直接判 review，不再走 ambiguous。

### Fixed / 修复

- **`/xcheck-setup` mode B wording.** `timeout_sec` was documented as "only set when `needs_timeout = true`"; in fact every agent carries the `timeout` cage regardless, so the wording now says "always set (default 480; mode C can change it)."
- **`/xcheck-setup` 模式 B 措辞。** 原写"`timeout_sec` 仅在 `needs_timeout = true` 时填"；实际上所有 agent 都带 `timeout` 笼子，措辞改成"始终填（默认 480；可用模式 C 改）"。

## [0.3.0] - 2026-08-09

### Added / 新增

- **Context intake (optional Step 0).** When you trigger a command with a short / reference-like input (e.g. `诊断刚才那个` / "diagnose that thing from just now"), xcheck now auto-extracts the **objective facts** from your recent conversation and passes them to the fan-out agents — because those agents are fresh processes that can't see the chat. A dedicated **extractor subagent** (cheap model) pulls facts **by provenance** (keeps what you said / pasted; drops assistant reasoning), never rewrites your words, and you confirm the fact list per-item before anything runs. Self-contained inputs (a full stack trace, a design doc) skip this. See `xcheck/lib/context-intake.md` + `xcheck/lib/extractor-carrier.md`.
- **上下文摄入（可选第 0 步）。** 当你用简短 / 指代性输入（如 `诊断刚才那个`）触发命令时，xcheck 会自动从最近对话里**摘取客观事实**传给下游 agent —— 因为那些 agent 是全新进程、看不到聊天记录。由专门的**摘录 subagent**（便宜模型）**按来源**摘取（留你说的 / 贴过的，丢 assistant 推理），绝不改写原话，且逐条经你确认后才开跑。自包含输入（完整报错栈、设计文档）直接跳过。见 `xcheck/lib/context-intake.md` + `xcheck/lib/extractor-carrier.md`。

## [0.2.0] - 2026-08-09

### Added / 新增

- Recognize **`pi`** ([`pi -p`](https://github.com/earendil-works/pi-mono), non-interactive print mode) as a fourth default agent in `agents.toml`. Auto-detected when installed; users without `pi` are unaffected.
- 识别 **`pi`**（[`pi -p`](https://github.com/earendil-works/pi-mono)，非交互 print 模式）为第四个默认 agent，写入 `agents.toml`。已装则自动检测，未装无影响。

## [0.1.0] - 2026-08-09

### Added / 新增

- First public release.
- 首个公开发布。
- Four manual slash commands: `/xcheck` (auto-router), `/xcheck-diag` (parallel diagnosis), `/xcheck-review` (cross review), `/xcheck-setup` (detect / verify / register).
- 四个手动 slash 命令：`/xcheck`（自动路由）、`/xcheck-diag`（并行诊断）、`/xcheck-review`（交叉评审）、`/xcheck-setup`（检测 / 验证 / 登记）。
- Parallel **blind** evaluation across local heterogeneous agent CLIs; each agent runs in its own isolated Claude subagent (carry-only, no judging); main session synthesizes consensus / divergence / verdict; the human decides.
- 跨本地异构 agent CLI 的并行**盲评**；每个 agent 跑在独立 Claude subagent 里（只搬运不评判）；主会话汇总共识 / 分歧 / 裁决；最终人拍板。
- Default agents: `claude`, `codex`, `opencode`. MIT license.
- 默认 agent：`claude`、`codex`、`opencode`。MIT 许可证。
