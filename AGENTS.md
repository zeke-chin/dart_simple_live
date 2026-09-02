# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

Simple Live 是一个聚合直播客户端（类似 AllLive 的 Dart/Flutter 版），支持虎牙、斗鱼、哔哩哔哩、抖音四个平台。这是 monorepo，包含四个子项目：

- `simple_live_core/` — 纯 Dart 核心库（不依赖 Flutter），负责获取各平台的房间信息、播放地址、弹幕。**新站点/平台协议改动几乎都在这里**。
- `simple_live_app/` — 主力 Flutter 客户端（Android/iOS/Windows/macOS/Linux）。
- `simple_live_tv_app/` — 基于 core 的 Android TV 客户端（独立 Flutter 工程，不共享 app 的代码）。
- `simple_live_console/` — 基于 core 的控制台演示程序，可用来快速验证 core 的接口。

所有 Flutter 工程通过 `path:` 依赖指向 `../simple_live_core`，改 core 代码无需发布包。

## 常用命令

```bash
# simple_live_app（Flutter 工程内执行）
flutter pub get
flutter run -d <device>          # 运行，如 macOS 桌面: flutter run -d macos
flutter analyze
flutter test                     # 全部测试
flutter test test/xxx_test.dart  # 单个测试文件

# simple_live_core / simple_live_console（纯 Dart 包）
dart pub get
dart analyze
dart test
dart run example/xxx.dart        # core 的 example 是接口冒烟验证
dart run bin/simple_live_console.dart  # console 程序，交互式输入房间信息

# 发版（在仓库根目录，先改 pubspec version 再跑）
scripts/release-tag --dry-run    # 预览 tag 与更新说明草稿
scripts/release-tag              # 校验 tag、编辑必填的更新内容、打 tag 并推送
```

App 需要修改 Hive 模型字段后运行 `dart run build_runner build` 重新生成 `.g.dart`（`follow_user.g.dart` 等，模型在 `simple_live_app/lib/models/db/`）。

## 核心架构

### simple_live_core：站点抽象

`simple_live_core/lib/src/interface/live_site.dart` 定义 `LiveSite` 抽象类，是全部站点的统一接口：

- 分类/推荐/搜索/房间详情/清晰度/播放地址：`getCategores`、`getRecommendRooms`、`searchRooms`、`getRoomDetail`、`getPlayQualites`、`getPlayUrls`
- 弹幕：`getDanmaku()` 返回 `LiveDanmaku` 实例（`interface/live_danmaku.dart`），监听/发送/SC 消息
- 各平台实现位于 `lib/src/`：`bilibili_site.dart`、`douyu_site.dart`、`huya_site.dart`、`douyin_site.dart`，对应弹幕实现在 `lib/src/danmaku/`

协议相关的特殊代码：
- 虎牙走 Tars 协议，`lib/src/model/tars/` 是从 Tars IDL 生成的 Dart（依赖 `packages/tars_dart`）
- 抖音弹幕是 protobuf，`lib/src/danmaku/proto/douyin.pb*.dart` 是生成代码
- 抖音/斗鱼签名脚本在 `lib/src/scripts/`（douyin_sign / douyu_sign，抖音用 dart_quickjs 跑 JS）

模型类（`lib/src/model/`）是所有请求的返回结构，改动站点实现时保持模型兼容。

### simple_live_app：Flutter 客户端

组织方式是 GetX（状态管理 + 路由）：

- `lib/main.dart` — 启动初始化顺序：Hive 迁移 → 窗口 → `initServices()` 依次 `Get.put` 各服务 → `runApp`。新增全局服务要在这里注册。
- `lib/app/sites.dart` — `Sites.allSites` 用常量 `Constant.kBiliBili/kDouyu/kHuya/kDouyin` 注册四个站点，App 只依赖 `LiveSite` 接口。新增站点 = core 实现 + 此处注册。
- `lib/app/controller/` — 全局控制器（`app_settings_controller.dart` 是核心，含站点排序、弹幕屏蔽等设置）。
- `lib/services/` — 全局服务：`DBService`（Hive 盒子管理）、`FollowService`、`SyncService`（WebDAV 同步）、`SignalR`、B站/抖音账号服务、DeepLink。
- `lib/modules/` — 按功能分模块的页面（home/category/live_room/search/follow/mine/settings/sync 等）。
- `lib/modules/live_room/` — 直播间核心：`live_room_controller.dart` + `player/`（media_kit 播放器封装）。弹幕屏蔽逻辑在 `danmu_shield_matcher.dart`、`danmu_keyword_selection.dart`、`widgets/danmu_block_dialog.dart`，这部分有较完整的单元测试。
- `lib/routes/` — `RoutePath` + `AppPages` 定义 GetX 路由。

### 本地存储与数据流

- Hive 存储，盒子包括 followuser、followusertag、history、localstorage、danmushield 等。桌面平台数据目录在 Application Support（`main.dart` 的 `migrateData()` 负责把旧文档目录数据搬过去）。
- 网络层：app 和 core 各自有 dio 封装（`lib/requests/http_client.dart` / core 的 `common/http_client.dart`），core 的日志通过 `CoreLog.onPrintLog` 回调接到 app 的 `Log`。

### 版本与发版

不要手打 `git tag`。流程是：先改 `simple_live_app/pubspec.yaml` 的 `version`，再在仓库根目录跑 `scripts/release-tag`。

- 版本号唯一来源是 `simple_live_app/pubspec.yaml` 的 `version: x.y.z+code`（如 `1.12.0+11200`）。`+` 前是版本名，后是构建号（`1.12.0` → `11200`）。
- git tag **必须**等于 `v<版本名>`（如 `v1.12.0`）。脚本和 `release-app` workflow 都会校验，和 pubspec 对不上直接失败。
- **更新内容必填**。它会出现在 GitHub Release 标题下面的说明区（就是现在「Latest Build」里「自动构建版本 / 提交: xxx」那一块），不能为空、也不能只留提交 hash。脚本会用上次 `v*` tag 以来的提交生成草稿，打开编辑器让你改；删空则拒绝打 tag。
- 推送 tag 后 `release-app` 构建全平台：Android APK、iOS 未签名 IPA、macOS dmg/zip、Linux deb、Windows msix。产物名 `SimpleLiveApp-<版本>-<平台>`。
- 版本名含 alpha/beta/rc 会标成 prerelease。
- TV 仍走 `publish_tv_app_dev.yaml` / `publish_tv_app_release.yaml`，版本号在 `simple_live_tv_app/pubspec.yaml`，这次发版流程不管它。

## 注意事项

- **Flutter 版本固定 3.38**（CI 用 3.38.3），升级 Flutter 前先跑一遍测试。
- pubspec 里有几个**故意锁死的版本**，不要随意升级：`dynamic_color: 1.8.1`（1.9.0 的 Android Gradle 与当前 AGP/Kotlin 不兼容）、`auto_orientation_v2: 2.3.8`（2.4.6 Android pluginClass 包名错误）、`hive: 2.2.3`、`flutter_easyrefresh: 2.2.2`。
- 视频播放依赖系统 mpv（media_kit），Linux 构建需先装 mpv 相关包。
- Windows 本地运行：路径过长会触发 `MSB3491`，用 `subst` 映射短盘符后再编；需要 NuGet CLI 在 PATH 里。详见 `simple_live_app/docs/windows.md`。
- Android 构建需要签名：CI 用 secrets 生成 `android/key.properties`；本地调试构建一般用 debug 签名即可。
- 代码注释和 UI 文案是中文，新代码沿用中文注释风格。
- 提交信息习惯用中文（git log 中 `feat:` / `fix:` / `ci:` 前缀 + 中文描述）。
