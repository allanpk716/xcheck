# 分支接管替代 worktree 隔离：隔离是操作者的选择

rc.1 的夜链隔离方案：摄入冻结 host_repo/start_oid/source_branch/remote_name/remote_url/pr_base，第一份 spec 前建仓库外 worktree，全部提交只进夜链分支，配套 116 行守卫（worktree 边界、注册双核验、路径规范化、Windows 大小写比较）。实际审查发现：冻结 URL 等值检查在 Windows 上因 git 存取路径规范化不一致（`/tmp/...` vs `C:/Users/...`）产生误报；整套仪式保护的是一条从未 live 跑通的管道。决定(v0.22.0)：**夜链直接在当前检出接管**——`git switch -c xcheck-night-<ts>` 起分支干活；操作者工作区的未提交改动原样跟随、不被 stash/复制/提交（夜链只 `git add` 自己的任务路径）；想要隔离（worktree/容器）由操作者自己创建并在其中运行 xcheck，技能不感知。早晨报告与通知声明"你现在在夜链分支，`git switch <原分支>` 返回"。同时推翻 ADR 0003 的"主仓当前分支 spec/票提交收工直推"：spec/票与代码同在夜链分支上交付。

## Considered Options

- **保留 worktree 机制只删仪式**——保留边界检查仍需冻结字段族与恢复核验，且"仓库外路径"在 Windows 各种盘符/大小写/网络盘上永远有新边角，否。
- **stash 操作者改动再干活**——动用户的未提交状态正是夜链最不能做的事，stash 冲突/遗忘都是新事故，否。
- **每次夜链克隆临时仓**——网络/磁盘成本与断连脆弱性换不来的安全，否。

## Consequences

- `delivery_schema` 与七冻结字段族、NIGHT 复制 PROGRESS、恢复 OID 可达性仪式全部删除；NIGHT 只记 start_oid/branch/remote_url/pr_base 四字段。
- 夜链运行期间操作者的检出停在夜链分支上；白天插手改工作区的风险由操作者自担（"开发者决定"的另一半）。
- 并行实施的提交串行纪律（ADR 0007）在单一检出内成立：泳道只编辑、主会话按票提交。
- 原"业务未提交改动不自动处理"的不变式语义不变，只是实现从"worktree 天然隔离"变为"只 add 自己的路径"。
