# 夜链隔离交付协议(delivery_schema = 1)

仅完整night的review下游使用。diag短稿不建worktree。`review_schema`仍为2,交付协议单独版本化;旧night已有spec/票/实施但无本协议元数据一律暂停自动恢复,不重放旧原分支动作。

## 冻结与写入边界

- 摄入首次记录PROGRESS:delivery_schema=1、host_repo(原仓绝对root)、start_oid(完整提交OID)、source_branch(启动分支,detached为-)、remote_name、remote_url(唯一push URL)、pr_base。复审不重算,逐项继承。
- remote默认明确的origin,缺失/多个push URL/目标无法确认则记publication_blocked并说明只本地执行;未选定remote时remote_name/remote_url/pr_base全为-。已取得的事实可以保留,但publication_blocked非-时不调用publish/PR。当前helper保守要求fetch URL与唯一push URL均匹配冻结URL,不同则禁发布,不自动改配置。不得在无人值守时新建远端、改凭据、自动猜另一个仓库。含凭据的URL不可落日志/账本,此情况禁自动发布并提示改用凭据管理器。
- 无Git/无HEAD可完成审核,但implementation_blocked明确原因;禁止凭空创建实施基线。冻结元数据缺失不从当前HEAD猜回“启动时点”。旧无交付元数据且没有plan产物也先说明需要明确新开,不静默升级基线。
- night摄入/修订只写原仓 `.xcheck/<ts>/`,source=inline,original_source仅追溯。附录写 `.xcheck/<ts>/review-appendix.md`,不修改被评原文件。普通审核和auto-review的原有文件修订/附录行为保留。
- 业务未提交修改不自动stash、commit、复制或清理。评审对象本身可从未提交文档取得快照,但实施基于冻结HEAD;若方案依赖未提交业务变更,记待决并暂停相关路径。

## 准备与恢复

在写第一份需要提交的spec之前,先记录NIGHT的host_repo/start_oid/source_branch/remote_name/remote_url/pr_base,再选唯一 `branch=xcheck-night-<root-ts>` 与仓库外的worktree绝对路径,先落盘意图后调用:

```text
bash <skill>/lib/night-git.sh prepare <host_repo> <branch> <worktree> <start_oid>
bash <skill>/lib/night-git.sh verify <host_repo> <branch> <worktree> <start_oid> [<complete_oid>...]
```

所有参数分别引用,不eval。prepare只建立新branch/worktree或幂等核验已经匹配的branch/worktree,绝不checkout/reset原工作区。存在非预期路径/分支冲突不得覆盖。恢复已有产物一律先verify,不重新prepare绕过验证。丢失worktree/branch/提交本批安全暂停,留给明确恢复处理;不从spec重建然后跳过旧票。

verify核验Git common-dir、worktree真实路径、HEAD分支、start_oid和每个已完成提交可达。每张complete须完整OID及测试/独立评审证据,不能只记短SHA或“绿”。Git可达不等于测试通过,主会话另核验证记录。HEAD存在未记账新提交/未提交更改时先检查归属及实际结果,不擅自丢弃/标完成。

## 文档与代码统一提交

spec写 `<worktree>/docs/superpowers/specs/`,票写 `<worktree>/.scratch/<slug>/issues/`,必要的最小.gitignore放行只改该worktree。将已审proposal、精选附录和D约束整合进spec形成自包含需求,不把整个.xcheck、原始反馈或私有聊天上传。

所有git add/commit明确 `git -C <worktree>` 并只选本任务路径,不git add全仓。写文件前确认目标目录及其祖先无指向worktree外的符号链接/junction;遇越界链接停止该写入,不能因路径字符串以worktree开头就认为隔离。原分支不commit、不push、不pull/rebase。spec/票与代码在同一分支,PR差异包含它们。

文档提交、每票和最终修复完成先记当前完整HEAD与验证记录,然后尝试发布。对外只发布夜链分支与创建/复用PR,绝不force或自动merge。

## 发布与PR

```text
bash <skill>/lib/night-git.sh publish <host_repo> <branch> <worktree> <start_oid> <remote_name|-> <remote_url|->
```

publish先核验工作区身份和冻结remote URL,只推 `refs/heads/<branch>:refs/heads/<branch>`。无remote跳过并准确记本地完成/未发布;网络或权限拒推不阻止已可执行的本地任务,收工再试一次。remote URL变化、仓库身份/提交不一致属于安全边界失败,暂停发布,不得自动改目标。

PR仅在分支成功推送且冻结目标明确时创建。按remote类型使用gh或tea,显式指定仓库、base=pr_base、head=branch;先查询同一repo/base/head的已有开放PR,有则复用,没有才创建。不凭当前cwd或工具默认仓库选目标,不把其他base的PR拿来复用。无法确认目标/缺工具/未登录/base不在远端→PR未创建,保留分支与本地成果。不为放行PR推送base分支。

GitHub调用机械助手 `bash <skill>/lib/night-pr.sh github <host/owner/repo> <pr_base> <branch> <title> <UTF8正文文件>` 查询/创建;查询失败不得当作“没有PR”继续创建。Gitea/tea本批仅在能核实帮助、显式指定目标三元组时主会话操作,不能证明目标则准确记PR未创建,不猜默认参数。发布前先核对该host/owner/repo确由冻结remote_url解析,不能用评审材料中的URL替换。

PR正文自包含spec主题、实现范围、测试证据摘要、paused/blocked与解除条件、发布状态;本地晨报路径只作补充,不能让远端读者必须访问本机文件。中文正文走UTF-8文件。PR不自动合并,如果有部分实现必须明确标未完成,不推荐直接合并。

实现结论与发布状态分别写:implementation结果仍全绿/带停靠完成/未完成/失败收工;push为已推/未推(原因)/无远端;pr为URL/未建(原因)。全绿只描述已验证实施,不代表发布已成功;对话/通知必须同时说明发布结果。
