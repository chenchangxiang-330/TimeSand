# TimeSand

TimeSand（时间之沙）是一款面向个人成长的艺术化时间管理 App。

> 时间终将流逝，但你可以决定它流向哪里。  
> Time will pass, but you decide where it flows.

## 当前范围：Phase 2.1

保留 Phase 1 实时沙漏首页，以及 Phase 2 的瓶子创建/编辑/归档、单设备计时器、
补录、每日瓶、永久成长瓶和时间海洋。关闭并重新打开 App 后，数据和活动计时器从 SQLite 恢复。

Phase 2.1 增加：

- SQLite schema 1 → 2 的版本化升级和回滚测试
- 本地 JSON 备份、CSV 时间记录导出
- JSON 导入预览，合并追加或覆盖恢复，错误整份拒绝
- 覆盖恢复二次确认，写入失败事务回滚
- 历史日期、月份、瓶子筛选；当天总投入、海洋和所选瓶子的永久累计
- 独立记录编辑页面、删除确认和修改后的统计刷新
- 跨午夜和跨月份记录按真实区间拆分

数据只保存在本设备，没有账户、登录、云端备份或跨设备同步。

## 时间与存储规则

Android 和 macOS 共用 Dart 业务代码，SQLite 通过 `sqflite_common_ffi` 访问。
`bottles` 保存名称、ARGB 颜色、创建/更新时间和归档状态；`time_entries` 保存瓶子引用、
真实开始/结束时间、来源（active/manual）、创建/更新时间及备注字段。
时间以 UTC ISO-8601 字符串保存，界面和自然日统计按设备本地时区显示。
`duration_seconds` 只是已结束记录的缓存，真实起止时间是事实来源。

每日瓶只显示所选本地自然日的投入；永久成长瓶累计历史记录，不因日期切换丢失。
时间海洋 = 当天已经流逝的真实时间 − 当天记录区间的投入时间。
记录按半开区间处理，首尾相接允许，重叠拒绝；同一设备最多一个活动计时器。
自然日使用本地今天零点和下一自然日零点，因此不固定为 24 小时。
编辑、删除和导入后从真实区间重新计算统计，不保存会失效的累计值。

## 数据库迁移

当前 schema version 为 2。创建新库时先创建 v1，再顺序执行与旧库相同的迁移：
v2 为 `time_entries` 增加 `notes TEXT NOT NULL DEFAULT ''`。
现有瓶子、记录、ID 和索引均保留。备注目前用于数据模型和备份保真，尚无备注编辑界面。

后续版本必须递增版本号，在 `TimeSandDatabase.migrations` 添加目标版本步骤，
不可修改已发布的旧迁移，不可删除数据库绕过升级。
sqflite 的 onCreate/onUpgrade 和 user_version 更新在事务内执行；
任何步骤失败均回滚。测试包括实际 v1 数据升级、默认值、
以及成功修改结构和数据后故意失败的回滚场景。暂不支持数据库降级。

## 本地备份与恢复

首页右上角“本地数据”打开导出和导入入口。

- Android：导出使用系统分享面板，请在所选目标中确认保存；取消分享不会保存备份。
- macOS：导出使用系统“保存”对话框；文件选择需要 user-selected.read-write 沙盒权限。
  CI 在生成 macOS 宿主工程后配置此权限。
- JSON 通过系统文件选择器导入。备份限制为 20 MiB。
- 导出是数据库事务中的一致快照，不包含数据库路径、密钥或账户信息。
  备份仍包含用户的瓶子名称和活动记录，文件为明文，请自行妥善保管。

JSON 格式版本为 1，稳定顶层字段：

`format_version`、`exported_at`、`timezone`、`timezone_offset_minutes`、
`database.schema_version`、`bottles`、`time_entries`。

时间戳使用带 Z 的规范 UTC ISO-8601，例如 `2026-10-15T01:00:00.000Z`。
时区字段表示导出时设备信息，不改变记录的绝对时间。
记录含 `id`、`bottle_id`、`started_at`、`ended_at`、`duration_seconds`、
`source`、`created_at`、`updated_at` 和 `notes`。
活动记录的 ended_at 与 duration_seconds 为 null。schema 1 备份缺少 notes 时默认为空；schema 2 必须包含该字段。

CSV 表头：

~~~text
time_entry_id,bottle_id,bottle_name,started_at,ended_at,duration_seconds,source,created_at,updated_at
~~~

CSV 使用 UTC 时间、逗号分隔、引号转义；公式式文本加前导单引号以便安全地用表格工具查看。
CSV 用于查看，不作为恢复格式。

导入会校验格式和数据库版本、必需字段和类型、有效 UTC 日期、正整数 ID、
唯一 ID、瓶子引用、时长一致性、重叠区间和活动记录唯一性；拒绝未来开始或结束的记录。任何错误拒绝整份文件。

默认“合并导入”保留当前数据，为所有导入瓶子和记录分配新 ID 并重映射引用；
不按名称合并或自动去重，时间冲突会拒绝整个导入（重复导入相同记录也会被拒绝）。
“覆盖恢复”在预览后再次确认，用备份替换当前数据并保留备份 ID。
冲突检查及所有写入在同一事务中，失败回滚，不留下部分数据。
仍在进行的活动记录可恢复，时长根据其真实开始时间继续计算。

## 历史使用

日期与月份筛选互斥，并可叠加瓶子筛选。
筛选时长仅计入与所选日期/月相交的部分；当天总投入与海洋仍覆盖所有瓶子。
所选瓶子的永久累计独立于日期/月筛选。

编辑页面显示本地日期时间及明确时区偏移，保留秒和微秒；无效日期、无效区间、
未来结束时间和重叠会提示错误。活动记录须先停止再编辑。
删除需确认。历史列表、返回后的首页以及重新打开的成长瓶详情均重新读取统计。

## SDK 与依赖

云端已使用 Flutter **3.47.7 stable**、Dart **3.13.5**。CI 固定此 Flutter 版本。

| 依赖 | 固定版本 | 用途 |
| --- | --- | --- |
| sqflite_common_ffi | 2.4.4 | Android/macOS SQLite 和真实数据库测试 |
| file_selector | 1.1.0 | Android/macOS 选择 JSON，macOS 保存文件 |
| share_plus | 11.1.0 | Android 系统导出分享 |
| flutter_test | Flutter SDK | 单元与 Widget 测试 |

应用的传递依赖由 `pubspec.lock` 锁定。未新增账户、网络同步或数据库服务依赖。

## 工程结构

~~~text
lib/
  app/                         App 入口
  core/
    database/                  数据库、顺序迁移、仓库、备份和恢复
    records/                   模型、区间规则、每日/永久统计
    time/                      本地自然日和系统时间进度
  design/                      共享视觉设计
  features/
    home/                      首页、瓶子和计时器
    hourglass/                 沙漏占位组件
    bottles/                   永久成长瓶
    history/                   筛选、补录、编辑和删除
    data_management/           本地导入导出与文件接口
test/
  core/                        时间、统计、数据库、迁移和备份测试
  features/                    首页、历史和数据管理 Widget 测试
.github/workflows/
  pull-request.yml             质量检查和双端 Debug 构建
  build.yml                    手动双端 Debug 构建
~~~

## 开发、测试与数据重置

~~~sh
flutter pub get
flutter run -d <device-id>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
~~~

没有宿主工具链的云端环境可使用 CI 构建；无需为了云端任务在本地 Mac 安装完整 SDK。
当前宿主文件由 CI 中 `flutter create` 补全，项目名 timesand，标识符 com.timesand.timesand。
本地生成 macOS 工程时，需在 DebugProfile.entitlements 和 Release.entitlements 设置
`com.apple.security.files.user-selected.read-write = true` 才能在沙盒中读写用户选定文件。

测试覆盖原有 Phase 1/2、迁移及失败回滚、JSON/CSV、往返一致性、损坏或缺字段备份、
区间/引用冲突、事务中途写入失败、筛选、编辑/删除后的时间守恒和界面确认流程。

数据清理会永久删除本地记录，先导出 JSON。
Android 可用系统“清除应用数据”或 `adb shell pm clear com.timesand.timesand`；
开发环境可调用 `TimeSandDatabase.reset()`（保留 schema）。
macOS 在退出 App 后删除运行时数据库文件也可重置，目录由 sqflite_common_ffi 决定。
不要用清理数据作为迁移方案。

## GitHub Actions 与验收

PR 强制运行格式检查、flutter analyze、flutter test，再分别在 Ubuntu 和 macOS
standard runner 上构建 Android Debug APK 与 macOS Debug App。
手动工作流使用 workflow_dispatch。Artifacts 保留 3 天，不使用付费 Larger Runner。

macOS 使用 ditto 先打包完整 .app，解压验证 Contents、可执行文件权限和符号链接再上传 ZIP。
Debug 产物仅用于开发测试。macOS 没有正式 Developer ID 签名或公证，不能视为正式分发版本。
Phase 2 真机测试由用户确认完成；Phase 2.1 的文件对话框、升级迁移和完整界面流程仍需双端真机回归。
云端构建成功不代表这些真机验收通过。

## 尚未实现与下一阶段

尚未实现账户/登录、云端数据库、跨设备同步、离线同步队列、iOS/Windows、
AI、社交、付费、复杂流体动画、桌面悬浮沙漏、正式签名和公证。

下一阶段先设计同步协议：全局稳定 ID、设备身份、记录修订号、
删除标记、幂等合并、重叠冲突解决及备份版本演进；
另行设计身份认证、数据加密、隐私和恢复策略。当前阶段不开始实现同步。
