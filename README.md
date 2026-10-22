# MoneyPrinterTurbo for iOS（1:1 移植版）

原版：https://github.com/harry0703/MoneyPrinterTurbo （MIT License，v1.3.9）
本仓库是原版的 iOS 1:1 移植：功能一致、界面 1:1、图标/字体/背景音乐/文案原样带入、
App 名与包名保留原版标识（`com.qingyao.moneyprinterturbo`）。

## 阶段进度
- [x] P0 盘点：功能矩阵 30 点、文件映射表、平台替代说明
- [x] P1 骨架：主题 token、四张设置卡片 1:1、设置页、任务管理、缓存页、Keychain 存 Key
- [ ] P2 核心流水线：素材 → 配音 → 字幕 → AVFoundation 合成出片
- [ ] P3 全 provider 补齐、预设/备份、诊断日志、YouTube 上传
- [ ] P4 14 语言全量、资源入包、完整性报告

## 平台替代（唯一 3 处不等价）
1. ffmpeg → AVFoundation（功能等价，画面一致，码率不逐 bit 相同）
2. 本地 TTS 兜底音色与原版不同（云端 TTS 1:1）
3. 不再起本地 HTTP 服务（原版 FastAPI + Streamlit → 本地直调 + SwiftUI）

## 许可与出处
原项目 MIT License，版权声明见 NOTICE。字体、BGM、图标等资产来自原项目资源目录。
