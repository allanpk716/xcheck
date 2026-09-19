# 夜链交付协议(0.22 精简版)

完整night的第11步机械边界,与 `lib/night-git.sh` 配套。信任模型三档(ADR 0004):防LLM犯错、防材料注入;敌意环境配置出范围。隔离是操作者的选择(ADR 0005):夜链在当前检出起分支干活,想要 worktree/容器隔离的操作者自己创建并在其中运行。

## 接管

- 第11步三道门:终点守卫(TARGET=review不实施)、材料门(`material = external` 失败关闭)、环境门(无git只审核)。
- 冻结基线记 NIGHT:`start_oid / branch / pr_base / remote_url(脱敏) / web_base`;含 userinfo 的 URL 剥凭据后才可入账,原串不落任何账本/日志/晨报。
- 认证预检:`git ls-remote <remote_url>`(非交互 env;判 exitcode,空仓 exit 0 属正常)→ 失败记未推,首票完成重试一次,再败本夜停推。
- `bash <skill>/lib/night-git.sh start <repo> <branch> <start_oid>`;`status=blocked`(操作者改动阻挡)→ waiting,不实施。
- **每次 start(含幂等)刷新**:`git status --porcelain` 全量存 NIGHT 附表 + `night-git.sh snapshot <repo> dirty-<root-ts>`;重算脏区重叠停靠票;播报表路径夜链独占。

## 提交纪律(编辑并行、提交串行)

- 泳道 agent 只改文件、跑局部验证,**严禁 git add/commit/push**;提交权只在主会话。
- 主会话按票 `git commit --only <票涉及路径> --no-verify`(显式 pathspec 防共享 index 捎带;--no-verify 防 hook 挂死/偷运);绝不 force。
- 提交前校验:该票改动文件集(相对派发快照)⊆ 涉及路径;越界改动不提交、记越界清单;与失败泳道残留清单比对,命中暂停。
- spec/票/代码/最小 .gitignore 放行全部同一夜链分支;原分支零 commit/push/pull/rebase;业务未提交改动不 stash、不复制、不提交。

## 发布(不自动开 PR——ADR 0006)

- 每票提交后即 `bash <skill>/lib/night-git.sh publish <repo> <branch> <remote_url>`(防全损;失败降级记账不挂链,下票连着重推);收工兜底末推一次。
- compare 一键链接:`web_base` 归一(脱敏 → scp/ssh 形态转 https → 端口取 web_base 不假设等于 SSH 端口 → 子路径保留)拼 `/compare/<pr_base>...<branch>`;归一失败印"脱敏 host+分支名",绝不印含凭据原串。
- 开 PR 是早晨一次点击;晨报/通知如实记 push=已推/未推(原因)/无远端,实施结论与发布状态分开记账。
