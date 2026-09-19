# 场景:旧schema不能继承通过

输入是一条旧review未完成链,目录名20260918-220000。使用同目录old-PROGRESS.md作为原始盘上账;该目录方案内容可取得:实现CSV导出。旧摘要写“没有必改”,没有FINDINGS或decisions。没有旧night实施,没有历史迁移目标。

任务:模拟恢复,不要调CLI;停在新版重新审核开始之前。将新环PROGRESS.md写到回放场景顶层,原旧记录不改复制到old/PROGRESS.md以供比对。可以完成新摄入,但不得把旧smoke/verify/gate等勾选继承到新环,不得把旧摘要直接作新版通过。记录迁移来源,新round=0、prev=-。
