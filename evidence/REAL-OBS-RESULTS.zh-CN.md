# PULSE 历史真实 OBS 验收范围

本文件是 2026-10-08 已有交付记录的公开范围摘要，不是本轮复测。

Windows OBS 32.2.2 的九组核心检查历史通过：真实 LuaJIT/OBS 绑定、未选目标拒绝、UUID 定向、三种命令、0/5 边界、无效目标拒绝、页面未启用忽略、隐藏源拒绝且不重放、页面重载后状态恢复。另有脚本重载、OBS 重启和删除源检查记录。

真人焦点短按序列由用户确认，代理没有独立观察。本轮没有启动 OBS；自动 SendInput、长按/系统重复、后台快捷键、其他系统/版本均 NOT_RUN。没有建立直播、录制验收或线上部署证据。

脱敏历史结构记录见 [real-obs-sanitized-20261008.json](history/real-obs-sanitized-20261008.json)，英文说明见 [HISTORICAL_VALIDATION.md](HISTORICAL_VALIDATION.md)。原截图、环境配置、UUID、个人对话和本机日志未复制。
