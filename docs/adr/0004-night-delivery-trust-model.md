# night 交付信任模型三档定界：防犯错、防注入，不防恶意环境

0.21.0-rc.1 的 `night-git.sh` 用 116 行守卫 + 49 行交付契约 + 7 个冻结字段追"枚举式防一切"：堵了 GIT_DIR 家族 7 变量、mirror、insteadOf、多 push 目标、缩写 OID、worktree 边界（含 Windows 大小写），审查仍坐实三洞——pre-push hook 借 publish 把分支偷运到非冻结远端（已本地复现，wrapper 照报 status=published）、`GIT_CONFIG_COUNT` 环境注入绕过守卫、凭据过期时 push 无限挂死。决定(v0.22.0)：**信任模型显式分三档**——TM-1 防 LLM 犯错（推错分支/远端、force、挂死）、TM-2 防被审材料注入（贴文/讨论藏指令操纵实施），这两档用旗标级防线覆盖（显式 URL 直推、显式 refspec、`--no-verify`、prompt-off、绝不 force）；**TM-3 防恶意环境配置（敌意 hook/env/gitconfig）明确出范围**，不再靠枚举追赶。触发条件：开始夜链自动实施不可信外部材料之前，必须先上真沙箱（容器/专用环境），枚举式守卫永远到不了岸。

## Considered Options

- **补完整枚举**（--no-verify+hooksPath 清空+GIT_CONFIG_* 守卫+ssh BatchMode……）——堵住今天三个洞，明天还有 filters、includes、receivepack；rc.1 的 46 条测试已经把不完整的威胁模型固化成"已验证"，继续枚举是跑步机，否。
- **现在就上沙箱**（容器内跑夜链）——TM-3 的正解，但为单机单人工具引入容器依赖，当前没有不可信材料自动实施的真实场景，过度，否（记为触发条件而非现状）。
- **信任模型不分档，全部交给散文约束**——LLM 执行器守不住 push 旗标这种必须成立的不变式，rc.1 已证明散文会漂移，否。

## Consequences

- `night-git.sh` 收缩为 start+publish 约 40 行；hostile 环境下不设防，操作者自担（与 ADR 0005"隔离是操作者的选择"同一立场）。
- `GIT_CONFIG_*` 注入类发现不再修，按 TM-3 记录为已知接受的风险。
- 守卫只剩测试得动的不变式：不推原分支 ref、不 force、不交互、不跑 hook——测试从"测仪式"转向"测事故"。
- 将来引入不可信材料审核+自动实施时，本 ADR 是"为什么没有枚举式守卫"的答案，也是上沙箱的依据。
