# 主沙漏 → 活动时间瓶：实际实现连续帧

这些图片由 GitHub Actions 中的 Flutter Widget 测试运行实际 `HomePage` 生成，**不是设计图或真实设备录屏**。手机视口为 390 × 844，桌面视口为 1440 × 960。测试通过真实按钮开始“学习”、让动画连续运行、停止计时并等待在途粒子落完。

演示使用独立内存 SQLite 数据库、明确的样本瓶子及 2026-10-27 的可推进测试时钟；不会在正式 App 中创建演示数据。学习瓶使用绿色，验证沙粒颜色来自用户瓶子，而不是固定蓝色。瓶内沙面仍由真实统计函数计算，动画不放大填充量。

| 时刻 | 手机原图 | 桌面原图 | 桌面小体积预览 |
| --- | --- | --- | --- |
| 未开始 | [PNG](sand-flow-phone-00-idle.png) | [PNG](sand-flow-desktop-00-idle.png) | [JPEG](sand-flow-desktop-00-idle-preview.jpg) |
| 开始后 0.6 秒 | [PNG](sand-flow-phone-01-running-0600ms.png) | [PNG](sand-flow-desktop-01-running-0600ms.png) | [JPEG](sand-flow-desktop-01-running-0600ms-preview.jpg) |
| 连续流沙 1.2 秒 | [PNG](sand-flow-phone-02-running-1200ms.png) | [PNG](sand-flow-desktop-02-running-1200ms.png) | [JPEG](sand-flow-desktop-02-running-1200ms-preview.jpg) |
| 连续流沙 2 秒 | [PNG](sand-flow-phone-03-running-2000ms.png) | [PNG](sand-flow-desktop-03-running-2000ms.png) | [JPEG](sand-flow-desktop-03-running-2000ms-preview.jpg) |
| 停止后 0.25 秒，在途粒子收尾 | [PNG](sand-flow-phone-04-draining-0250ms.png) | [PNG](sand-flow-desktop-04-draining-0250ms.png) | [JPEG](sand-flow-desktop-04-draining-0250ms-preview.jpg) |
| 停止后 2 秒，无新粒子 | [PNG](sand-flow-phone-05-stopped-2000ms.png) | [PNG](sand-flow-desktop-05-stopped-2000ms.png) | [JPEG](sand-flow-desktop-05-stopped-2000ms-preview.jpg) |

测试同时断言开始后的目标瓶 ID、连续发射数量增长、运行帧有差异、停止后不再发射且最终粒子归零，以及 SQLite 记录保存实际 2 秒区间。手机与桌面画面使用同一业务代码。

复现（测试环境需有 Roboto 和 Noto CJK 字体）：

```sh
RUN_UI_SCREENSHOTS=true flutter test test/visual/sand_flow_frames_test.dart --concurrency=1
python -m pip install Pillow==11.3.0
python tool/render_sand_flow_previews.py
```

输出在 `build/ui-screenshots/`。JPEG 仅为原始桌面 PNG 的同尺寸压缩预览，没有增加绘制内容、插帧或替换界面；原始无损 PNG 全部保留。Pillow 仅用于开发验证，不是 App 依赖。

## 验证范围

- Widget 测试覆盖缩放、手机/桌面视口、垂直滚动、横向瓶架滚动、后台、路由切换和减少动画。
- Android 模拟器检查 APK 启动和真实磁盘持久化；macOS 检查构建及 ZIP 中的完整 App、执行权限和符号链接。
- 尚未验证此次动画在真实 Android/macOS 设备上的帧率、耗电、触控及系统窗口行为。截图与云端构建不代表真机验收或正式发布。
