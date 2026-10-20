# TimeSand

TimeSand（时间之沙）是一款面向个人成长的艺术化时间管理 App。

> 时间终将流逝，但你可以决定它流向哪里。  
> Time will pass, but you decide where it flows.

## 玻璃沙漏 UI

本分支基于 main 的 Phase 2（79deaf6）进行原生 Flutter UI 改造。按用户确认，Phase 2.1 PR #3 保持独立，当前分支不包含其导入/导出或 schema 2 迁移；SQLite schema 1 和已有数据不变。

- 明亮天空、暖光海岸背景；通透玻璃沙漏和彩色时间瓶由 CustomPainter 实时绘制。
- 手机纵向滚动、浮动胶囊导航；宽度至少 1000 的窗口使用玻璃侧栏与 Dock，大字号自动退回紧凑布局。
- 首页/历史/统计/我的均连接真实功能；日历入口选择本地日期，无虚假搜索、目标或专注模式页面。
- 瓶子点击查看永久累计，独立选择与开始按钮，保留新建、编辑和归档；已归档瓶子可从“我的”查看。
- 海洋为当天已流逝减去有效记录时长；今日剩余单独标注。瓶子液面表示该瓶占今日已记录时长的比例，不代表目标完成率。
- 记录页支持日期筛选、补录、编辑和删除确认；编辑仍经过现有区间与重叠校验。
- 无活动计时的成长瓶详情也会在跨午夜后刷新当天数值；日历入口每次读取当前日期。
- 所有时长来自系统时钟和 SQLite 起止时间。动画只作装饰，遵守系统减少动画、路由可见性与后台生命周期。
- 磨砂模糊限制在侧栏、导航和汇总卡片；表单采用较高不透明度确保可读。

实际 Widget 渲染截图见 [手机](docs/ui/phone.png)、[手机开始操作](docs/ui/phone-idle.png)、[手机计时中](docs/ui/phone-active.png)、[手机下部](docs/ui/phone-scroll.png)、[桌面](docs/ui/desktop.png)。这些是云端 Flutter 实际实现的截图，使用明确的内存测试样本和固定测试时钟，不是设计图或真实用户数据；生产 App 不加载这些样本。

背景采用 Hommie09 以 CC0 发布的真实海上日出照片，在云端调整阴影、色彩和分辨率后离线打包；保留原创程序场景作为回退。来源、授权、处理脚本及哈希见 [资产说明](assets/scenes/README.md)。海面和云层比参考图更平静，玻璃使用实时绘制的厚壁、高光与弧形沙面，没有物理折射或流体模拟。参考图中的设备外框、假状态栏和假窗口按钮不进入界面。

## Phase 2 保留功能

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

- Flutter 3.47.7 stable（工作流固定版本）
- Dart 3.13.5
- sqflite_common_ffi: 2.4.4，传递依赖由 pubspec.lock 锁定
- Android 和 macOS 共用同一套 Dart 业务代码
- 运行时依赖保持最小化

SQLite 数据库使用 sqflite_common_ffi，在 Android、macOS 和 Flutter 测试环境中使用同一套数据库访问代码。时间以 UTC ISO-8601 字符串保存；界面和每日统计转换为设备本地时间。duration_seconds 是缓存字段，真实时间区间仍由 started_at 和 ended_at 决定。

## 支持平台

当前工程包含：

- Android（Debug APK，云端构建）
- macOS（Debug .app，云端构建，未签名）

Phase 2 真机回归已由用户确认完成。本次玻璃 UI 的触控、键盘、系统窗口和实际设备性能仍需 Android/macOS 真机回归；云端 Widget 截图不能替代真机验收。构建产物只用于开发测试，没有正式 Developer ID 签名或公证。

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
    hourglass/                 实时玻璃沙漏
    bottles/                   永久成长瓶详情
    history/                   日期筛选、补录、编辑和删除
    statistics/                真实每日和永久统计
test/
  core/time/                   Phase 1 时间窗口测试
  core/records/                统计和时间区间测试
  core/database/               SQLite 仓库和计时器恢复测试
  features/home/               首页与响应式交互回归
  features/history/            日期筛选、编辑、删除和统计刷新
  visual/                      实际 Widget 截图测试
assets/scenes/                 离线海景照片、原创回退背景与来源说明
tool/                          资产处理源码及核实授权的原始照片
docs/ui/                       云端实际实现截图
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

## 视觉验证

普通 flutter test 保留已有测试并运行响应式/交互回归。截图测试默认跳过；CI 单独启用：

~~~sh
RUN_UI_SCREENSHOTS=true flutter test test/visual/glass_screenshots_test.dart --concurrency=1
~~~

输出 build/ui-screenshots/*.png。截图 runner 安装 fonts-roboto 和 fonts-noto-cjk（仅测试字体，不打包到 App）。海景照片处理和原有回退背景重建使用 Python/Pillow 11.3.0；没有新增 Flutter 运行时依赖。测试字体的许可随 Ubuntu 软件包提供；不复制到仓库或 App，运行 App 使用系统字体回退。

## GitHub Actions

Pull Request 工作流在 Ubuntu 和 macOS standard runner 上执行：

1. 安装 Flutter stable
2. flutter pub get
3. Dart 格式检查
4. flutter analyze
5. flutter test，以及手机/桌面实际 Widget 渲染截图
6. Android Debug APK 构建
7. macOS Debug App 构建
8. 将完整 macOS .app 打包成 ZIP，验证 Contents、可执行文件和符号链接后上传

手动构建工作流通过 workflow_dispatch 触发，并上传 Android APK 和 macOS ZIP。Artifacts 保留 3 天，不使用付费 Larger Runner。macOS 构建未签名、未公证。

## 后续路线

1. 在 Android 和 macOS 真机上回归玻璃 UI 的持久化、跨午夜、窗口和键盘布局
2. 独立审查 Phase 2.1 PR #3 的数据迁移、导入导出与历史改进，再处理两分支页面合并
3. 根据真实设备测量优化玻璃材质和动画性能
4. 设计账户与云端同步
5. 初始化 iOS、Windows 宿主工程
6. 规划正式签名、公证和发布流程
