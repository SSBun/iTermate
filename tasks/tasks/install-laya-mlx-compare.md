# 安装 Laya-MLX 并复测客服分类示例

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-22 14:36) |
| Kind | Task |

## Target
- [x] T1: 在本机安装可运行的 Laya-MLX 与必要模型，报告安装位置。
- [x] T2: 本地执行与 Jev 相同消息、问题和三个选项，报告实际结果与耗时或明确阻碍，不将本地耗时误当作与远程端到端耗时等价。

## Result

- T1: uv tool install --python 3.12 laya-mlx 成功；隔离环境 /Users/caishilin/.local/share/uv/tools/laya-mlx，入口 /Users/caishilin/.local/bin/laya-mlx。版本 laya-mlx 0.2.0、MLX 0.32.2；uv pip check 全部 20 个包兼容。英文模型 aac6fef/laya-mlx revision 20aed815fc6acde75733882e7ec0e3f28aeb9717 已缓存，11 个文件大小及 SHA256 匹配 manifest。首次 Xet 下载超时，关闭 Xet 后下载成功，保留原缓存未删除。
- T2: Apple M4 GPU/FP16，在 HF_HUB_OFFLINE=1 下加载本地快照；由 Jev 脚本 --dry-run 获取完全相同输入。6 次本地推理答案一致：billing，概率 .9573，technical_support .03，account_management .0128，confidence .8156；加载 .397 秒，首次推理 1609.398 ms，后5次37.878/30.415/30.678/29.914/30.161 ms，中位数30.415 ms。input_tokens74/output_tokens0。加载警告仅指出 choice:11+ 温度截断，本题3选项；未使用Jev密钥，未调用Jev，未运行项目测试。
- Review gate: Skipped — R1 常规隔离安装，版本和权重已核对，真实离线推理验证；无额外独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 标准隔离工具安装与单个合成问题的本地推理，无自定义应用逻辑或系统 Python 修改。
- Snapshot: laya-mlx=0.2.0;mlx=0.32.2;model=20aed815fc6acde75733882e7ec0e3f28aeb9717;weights-sha256=b9c07bf14be2fa5c78a9193a3e6d840ac80e89e62fc40f425834c3d8a6eaa3de
- Evidence: uv pip check、版本查询、11文件哈希检查与6次离线GPU调用均成功。
- Result clarity: 用户确认本机隔离安装并复测完全相同选择题；两项均实际完成。
- Bounded impact: 仅用户目录工具环境、入口及模型缓存；未改系统Python、应用或Jev脚本。
- Low risk: 授权安装公开发行包与safetensors权重；凭据未读取，合成问题离线推理；安装可移除且没有服务常驻。
- Sufficient verification: 实际版本、依赖兼容、模型发布清单匹配，离线GPU重复预测一致；加载和冷暖推理分别计时，不将远程网络耗时当作模型本身速度。
- Task fingerprint: fb35a4e1555d3a507be70e8fd46ac2da922283b927a77bd04cda49705730003e

## Verification

- Passed: 最终 uv pip check 与 laya-mlx --version 成功，11文件哈希匹配固定revision；相同问题6次离线结果均为billing，冷暖计时分别记录。既有代码改动未触及，无项目测试。
