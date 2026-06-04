# scripts

日常实用脚本集合，用于定时任务和文件处理等。

## 目录结构

| 目录 | 说明 |
|------|------|
| `task/` | 定时任务与自动化脚本 |
| `tool/` | 实用工具脚本 |

## 脚本列表

### task — 定时任务

| 名称 | 描述 |
|------|------|
| [auto_certbot_ssl.sh](task/auto_certbot_ssl.sh) | 遍历 Let's Encrypt 所有证书，到期前自动停止 Nginx、清空 iptables 后通过 standalone 模式续期，再重启 Nginx |
| [auto_push.bat](task/auto_push.bat) | Windows 下自动 git add/commit/push 指定仓库，支持自定义提交信息，默认为 "update" |

### tool — 工具

| 名称 | 描述 |
|------|------|
| [convert_lrc_to_ansi.py](tool/convert_lrc_to_ansi.py) | 将 LRC 歌词文件批量转换为 ANSI(GBK) 编码 |
| [excel_to_json.py](tool/excel_to_json.py) | 将 Excel 文件转换为 JSON 格式 |
| [fetch_steam_games.py](tool/fetch_steam_games.py) | 通过 Steam Web API 获取用户游戏库，返回游戏名称、游玩时长、图标、最后游玩时间和商店链接，按游玩时长降序排列 |

## 许可证

[MIT License](LICENSE)
