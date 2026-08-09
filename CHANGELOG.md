# Changelog / 更新日志

All notable changes to `xcheck`. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
本文件记录 xcheck 的所有显著变更。

## [Unreleased] / 未发布

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
