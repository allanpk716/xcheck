# Changelog / 更新日志

All notable changes to `xcheck`. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
本文件记录 xcheck 的所有显著变更。

## [Unreleased] / 未发布

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
