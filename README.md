# TimeSand

TimeSand（时间之沙）是一款面向个人成长的艺术化时间管理 App。

> 时间终将流逝，但你可以决定它流向哪里。  
> Time will pass, but you decide where it flows.

## Phase 1 状态

Phase 1 建立跨平台 Flutter 工程基础，当前首页实时展示：

- TimeSand 品牌与产品理念
- 简洁的时间沙漏占位组件
- 当前本地日期
- 当天已流逝时间
- 当天剩余时间
- 当天时间流逝比例与进度条

时间数据来自系统时钟，页面运行期间每秒刷新；应用重新启动后会重新计算当前自然日状态。时间计算使用本地日期起点和下一自然日起点，因此不会把自然日固定假设为 24 小时。

当前尚未实现：时间之瓶、时间海洋、历史统计、账户、同步、数据库、真实流体模拟和复杂动画。

## 技术栈与版本

- Flutter stable channel（由 GitHub Actions 解析；工作流日志打印实际版本）
- Dart（随 Flutter SDK 提供；工作流日志打印实际版本）
- Android 与 macOS 共用 Dart 业务代码
- 当前无第三方运行时依赖；仅使用 Flutter SDK 与 Dart 标准库

每次 CI 运行都会首先输出 flutter --version 和 dart --version。仓库不猜测本地未安装的 SDK 版本；首次成功的云端运行完成后，应将日志中的确切版本回填到本节。

## 支持平台

当前已初始化并优先验证：

- Android（debug APK）
- macOS（debug .app，未签名）

未来预留：

- iOS
- Windows

未配置 Apple 签名、公证或 Android release 签名，因此当前构建产物仅用于开发测试，不代表可正式分发。

## 工程结构

~~~text
lib/
  app/                         App 根组件与主题入口
  core/time/                   本地自然日与时间进度计算
  design/                      共享视觉设计
  features/home/               Phase 1 首页
  features/hourglass/          沙漏占位组件
test/
  core/time/                   时间计算单元测试
android/                       Android 宿主工程
macos/                         macOS 宿主工程
.github/workflows/
  pull-request.yml             PR 格式、分析、测试和平台构建
  build.yml                    手动触发的 Android/macOS 构建
~~~

时间之瓶、时间海洋、历史统计在后续阶段加入，不提前创建空实现目录。

## 开发

需要 Flutter stable SDK。进入项目根目录后执行：

~~~sh
flutter pub get
flutter run -d <device-id>
~~~

Android 与 macOS 使用相同的 lib/ 代码。平台宿主文件由 Flutter 标准工程生成并保留在对应平台目录中。

## 测试与质量检查

~~~sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

核心时间模块通过传入 DateTime now 测试；本地日期边界由 DateTime 的本地时区规则决定，能够覆盖跨午夜以及夏令时产生的 23/25 小时自然日。

## GitHub Actions

Pull Request 工作流在 Ubuntu 与 macOS standard runner 上执行：

1. 安装 Flutter stable
2. flutter pub get
3. Dart 格式检查
4. flutter analyze
5. flutter test
6. Android debug APK 和 macOS debug App 构建
7. 上传临时构建产物

手动构建工作流通过 workflow_dispatch 触发，并上传带有开发测试标记的 Android APK 与 macOS .app。Artifacts 保留 3 天。工作流不使用付费 Larger Runner。

## 后续路线

1. 时间之瓶：活动分类、每日瓶和永久成长瓶
2. 时间海洋：未分类时间补录
3. 历史统计：按日、周、月和长期趋势
4. 本地持久化与数据导出
5. iOS、Windows 宿主工程与发布签名
