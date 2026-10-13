# TimeSand

TimeSand（时间之沙）是一款面向个人成长的艺术化时间管理 App。

> 时间终将流逝，但你可以决定它流向哪里。  
> Time will pass, but you decide where it flows.

## Phase 2 状态

Phase 2 在 Phase 1 的实时首页基础上加入了本地时间记录能力：

- 使用 SQLite 保存时间之瓶和时间记录
- 创建、编辑和归档时间之瓶
- 开始、停止一个设备上的唯一活动计时器
- 活动计时器关闭 App 后可以根据真实开始时间恢复
- 支持 active 计时记录和 manual 补录记录
- 保存真实开始时间和结束时间，时长由时间区间重新计算
- 每日时间之瓶统计
- 永久成长瓶累计统计和按月历史
- 时间海洋统计：当天已流逝时间减去当天有效记录时间
- 历史记录页面和基础瓶子详情页面
- 保存前检查无效区间、重叠记录和多个活动计时器

每日时间之瓶只表示本地自然日的投入。永久成长瓶从瓶子创建后累计所有历史 TimeEntry，日期切换不会删除历史数据。跨午夜和夏令时的 23/25 小时自然日按本地日期边界计算，不把自然日固定为 24 小时。

## 尚未实现

- 用户账户
- 云端同步和跨设备同步
- 离线同步队列
- iOS 和 Windows 宿主工程
- 复杂流体模拟
- 桌面悬浮沙漏
- AI、社交和付费功能
- 正式发布签名、公证和商店分发

Phase 2 只使用本地数据库，当前没有账户和云端数据备份。

## 技术栈与版本

- Flutter 3.47.7 stable（以 GitHub Actions 实际解析版本为准）
- Dart 3.13.5
- sqflite_common_ffi: ^2.4.3
- Android 和 macOS 共用同一套 Dart 业务代码
- 运行时依赖保持最小化

SQLite 数据库使用 sqflite_common_ffi，在 Android、macOS 和 Flutter 测试环境中使用同一套数据库访问代码。时间以 UTC ISO-8601 字符串保存；界面和每日统计转换为设备本地时间。duration_seconds 是缓存字段，真实时间区间仍由 started_at 和 ended_at 决定。

## 支持平台

当前工程包含：

- Android（Debug APK，云端构建）
- macOS（Debug .app，云端构建，未签名）

Phase 2 的 Android 和 macOS 真机回归需要在当前代码合并后重新执行。构建产物只用于开发测试，不代表正式分发。

## 工程结构

~~~text
lib/
  app/                         App 根组件和主题入口
  core/
    database/                  SQLite 数据库和仓库
    records/                   时间记录模型、校验和统计
    time/                      本地自然日和时间进度计算
  design/                      共享视觉设计
  features/
    home/                      首页、瓶子列表和当前计时
    hourglass/                 沙漏占位组件
    bottles/                   永久成长瓶详情
    history/                   历史记录和手动补录
test/
  core/time/                   Phase 1 时间窗口测试
  core/records/                统计和时间区间测试
  core/database/               SQLite 仓库和计时器恢复测试
  features/home/               首页 Widget 测试
android/                       Android 宿主工程
macos/                         macOS 宿主工程
.github/workflows/
  pull-request.yml             PR 格式、分析、测试和平台构建
  build.yml                    手动 Android/macOS 构建
~~~

## 开发

需要 Flutter 3.47.7 或兼容的 stable SDK：

~~~sh
flutter pub get
flutter run -d <device-id>
~~~

应用启动时初始化 SQLite 数据库。默认数据库路径由 sqflite_common_ffi 提供；不同平台的具体目录以运行时为准。

清理本地数据时，请先退出应用：

- Android：adb shell pm clear com.timesand.timesand
- macOS：删除应用使用的 timesand.db 文件，或在开发环境中调用 TimeSandDatabase.reset() 后重新启动

清理数据会删除瓶子和时间记录，不能恢复。

## 测试与质量检查

~~~sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

测试覆盖：

- 瓶子创建、修改、归档
- 活动计时器创建、停止和数据库恢复
- 手动补录、删除、无效区间和重叠校验
- 每日瓶、永久成长瓶和时间海洋统计
- 跨午夜和边界时刻
- 首页显示瓶子、开始/停止按钮和历史页面导航

## GitHub Actions

Pull Request 工作流在 Ubuntu 和 macOS standard runner 上执行：

1. 安装 Flutter stable
2. flutter pub get
3. Dart 格式检查
4. flutter analyze
5. flutter test
6. Android Debug APK 构建
7. macOS Debug App 构建
8. 将完整 macOS .app 打包成 ZIP，验证 Contents、可执行文件和符号链接后上传

手动构建工作流通过 workflow_dispatch 触发，并上传 Android APK 和 macOS ZIP。Artifacts 保留 3 天，不使用付费 Larger Runner。macOS 构建未签名、未公证。

## 后续路线

1. 在 Android 和 macOS 真机上回归 Phase 2 的持久化、跨午夜和窗口布局
2. 增加更完整的记录编辑和日期筛选
3. 增加本地数据导出和备份
4. 设计账户与云端同步
5. 初始化 iOS、Windows 宿主工程
6. 规划正式签名、公证和发布流程
