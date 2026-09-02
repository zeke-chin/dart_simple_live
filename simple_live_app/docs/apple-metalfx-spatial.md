# macOS / iPadOS MetalFX Spatial 视频增强方案

## 1. 目标

在 Simple Live 的 macOS 与 iPadOS 内置播放器中接入 Apple `MTLFXSpatialScaler`，把直播视频按当前视频视口的 Retina 物理像素尺寸实时放大，再交给 Flutter Texture 显示。

本方案是独立的新实现，不修改 `simple_live_work/docs/apple-vt-sr.md`。原文继续保留为 VideoToolbox 低延迟超分的调研记录。

范围：

- 第一阶段只开发、验证 macOS Apple Silicon。
- 第二阶段补齐 iPadOS 真机支持。
- Windows RTX VSR、Android、Linux 不改变。
- 不抬高 App 当前的 iOS 13 与 macOS 10.15 最低部署版本。
- MetalFX 不可用、初始化失败或处理失败时必须自动回退到现有 Flutter Texture。

非目标：

- 不把 MetalFX 宣传成与 NVIDIA RTX VSR 完全等价。
- 不接入需要下载模型、固定 4 倍输出的 `VTSuperResolutionScaler`。
- 不使用需要 motion vector、depth 和 jitter 的 `MTLFXTemporalScaler`。
- 第一阶段不叠加 `VTTemporalNoiseFilter`。

## 2. 技术结论

`MTLFXSpatialScaler` 是当前 Apple 原生平台中最适合实时解码视频的放大器：

- macOS 13、iPadOS 16 起提供。
- 每帧只需要一张颜色纹理。
- 不依赖前后帧、光流、深度或运动矢量。
- 输出尺寸由调用方指定，不要求固定 1.5、2 或 4 倍。
- Apple 官方将其定位为可逐帧实时运行的空间放大效果。

它与 RTX VSR 的差别是：MetalFX Spatial 主要根据当前帧的空间结构改善放大后的边缘和轮廓，不承诺专门清理直播压缩块、振铃和时域噪声。因此必须与现有 bilinear 和高质量 mpv scaler 做真实直播画面 A/B 对比后，才能决定是否默认开放。

官方资料：

- MetalFX：https://developer.apple.com/documentation/metalfx
- MTLFXSpatialScaler：https://developer.apple.com/documentation/metalfx/mtlfxspatialscaler
- 设备能力查询：https://developer.apple.com/documentation/metalfx/mtlfxspatialscalerdescriptor/supportsdevice(_:)
- WWDC22 MetalFX：https://developer.apple.com/videos/play/wwdc2022/10103/

## 3. Retina 输出尺寸

输出尺寸不能写死成 2 倍或 4 倍，也不应无条件生成 4K。目标是视频内容在当前窗口或全屏区域实际占用的物理像素：

```text
物理视口 = Flutter logical viewport × devicePixelRatio
目标视频区域 = 按 BoxFit 将片源宽高比映射到物理视口
MetalFX 输出 = min(目标视频区域, 片源每边最多 2 倍)
```

当前开发机的典型结果：

| 显示区域 | 1080p 输入目标 | 倍率 |
|---|---:|---:|
| 外接 4K 全屏 | 3840×2160 | 2.00 |
| Mac 内置 Retina 的 16:9 区域 | 3024×1701 | 约 1.575 |
| iPad 全屏 | 按真机 drawable 与留黑区域计算 | 通常约 1.2～1.4 |

第一版规则：

- 目标倍率小于等于 1 时关闭 MetalFX，不做缩小。
- 最大倍率限制为 2，避免 720p 在 4K 屏上生成过大的中间纹理。
- BGRA MetalFX 输出不假设宽高必须为偶数，按 Retina 视频区域取整；例如 Mac 内屏可直接输出 3024×1701。
- 窗口连续缩放时使用 200ms debounce，只在目标尺寸稳定后重建 scaler。
- `BoxFit.contain` 使用留黑后的实际视频区域；`BoxFit.cover` 使用裁剪前的完整视频区域。

## 4. 当前 Darwin 出帧链路

```text
VideoToolbox 硬件解码
  → libmpv OpenGL / OpenGL ES Render API
  → 32BGRA CVPixelBuffer 对应的 GL FBO
  → FlutterTexture.copyPixelBuffer()
  → Flutter 合成视频、弹幕和控件
```

关键文件：

- `media-kit/media_kit_video/common/darwin/Classes/plugin/VideoOutput.swift`
- `media-kit/media_kit_video/common/darwin/Classes/plugin/VideoOutputManager.swift`
- `media-kit/media_kit_video/common/darwin/Classes/plugin/MediaKitVideoPlugin.swift`
- `media-kit/media_kit_video/macos/media_kit_video/Sources/media_kit_video/plugin/TextureHW.swift`
- `media-kit/media_kit_video/ios/media_kit_video/Sources/media_kit_video/plugin/TextureHW.swift`

现有 GL FBO 背后的 PixelBuffer 已设置 `kCVPixelBufferMetalCompatibilityKey`，可以通过 `CVMetalTextureCache` 包装成 Metal 输入纹理，不需要 `glReadPixels`。

## 5. 目标链路

```text
libmpv 渲染源分辨率 BGRA CVPixelBuffer
  → GL 完成跨 API 同步
  → CVMetalTextureCache 包装成 Metal 输入纹理
  → MTLFXSpatialScaler 写入 private MTLTexture
  → Metal blit 到 Flutter 可返回的 BGRA CVPixelBuffer
  → FlutterTexture.copyPixelBuffer()
```

MetalFX 要求 `outputTexture.storageMode == .private`。Flutter 使用的 CVPixelBuffer 在当前 macOS 环境中包装为 `.managed` Metal texture，不能直接作为 MetalFX 输出，否则会触发断言。因此 private 输出纹理与 Flutter PixelBuffer 之间必须有一次 GPU blit。

这不是 CPU 像素拷贝，但会增加一次目标分辨率的 GPU 内存带宽。

### 5.1 缓冲策略

- 继续保留现有三缓冲源 GL PixelBuffer。
- MetalFX private 中间纹理只保留一张；首版同步等待 command buffer 完成，不存在并发写入。
- Flutter 输出 PixelBuffer 保留三张，避免 Flutter 读取与下一帧写入重叠。
- 配置变化时整体重建 MetalFX scaler、private texture 和输出池。

### 5.2 同步策略

OpenGL 与 Metal 共享 IOSurface 时需要明确保证 GL 已完成写入。首版为正确性使用：

```text
MetalFX 关闭：glFlush
MetalFX 开启：glFinish → Metal command buffer → waitUntilCompleted
```

这个实现会引入 GPU pipeline stall，但便于先验证正确性和真实性能。若耗时不可接受，再单独研究减少同步等待的方法；不能在没有证据时假设 `glFlush` 足以避免跨 API 读写竞争。

## 6. media-kit API

在 `VideoController` 增加 Darwin 视频增强接口：

```dart
Future<bool> isMetalFxSpatialSupported();

Future<void> setMetalFxSpatial({
  required bool enabled,
  int? width,
  int? height,
});
```

约束：

- 非 macOS/iOS 平台查询返回 `false`，设置操作安全 no-op。
- 原生侧使用 `MTLFXSpatialScalerDescriptor.supportsDevice(_:)`，不能根据芯片名称猜测。
- 开启时 width、height 必须同时存在且大于零。
- 设置接口只控制 MetalFX 的输出尺寸，不调用现有 `VideoController.setSize`，否则 libmpv 会直接按目标分辨率渲染，失去超分意义。

原生 MethodChannel：

```text
VideoOutputManager.IsMetalFxSpatialSupported
VideoOutputManager.SetMetalFxSpatial
```

## 7. App 行为

新增设置项：`Apple MetalFX 视频增强`。

- 仅在 macOS/iOS 显示。
- 默认关闭。
- 设置页修改后在下次进入直播间生效。
- 直播间控制面板支持即时开关。
- 开启时自动查询设备能力；不支持时提示并保持普通播放。
- 与自定义播放器输出互斥，因为 MetalFX 依赖 `vo=libmpv` 的 Flutter Texture 硬件链路。
- 启用 MetalFX 时强制使用硬件 Texture 输出；不改变其他平台行为。

窗口、全屏和横竖屏变化沿用 RTX VSR 已有的物理 viewport 计算思路，但 Apple 分支只把目标尺寸传给 MetalFX，不修改 mpv `vf`，也不修改 libmpv 的源渲染尺寸。

## 8. 监控与回退

原生日志至少包含：

```text
MetalFX Spatial: supported=<bool>, device=<name>
MetalFX Spatial: source=1920x1080, output=3024x1701
MetalFX Spatial: frames=120, avgWallMs=..., maxWallMs=..., avgGpuMs=...
MetalFX Spatial: fallback, reason=<reason>
```

遇到下列情况必须回退：

- 系统版本低于 macOS 13 / iPadOS 16。
- `MTLCreateSystemDefaultDevice()` 失败。
- `supportsDevice` 返回 false。
- scaler、private texture、CVMetalTexture 或 command buffer 创建失败。
- Metal command buffer 执行失败。
- 目标尺寸不大于片源尺寸。

回退只影响当前视频输出，不能销毁 Player 或中断直播。

## 9. 分阶段实现与提交

### 阶段 A：方案与本地开发依赖

- 新增本文档。
- App 将 media-kit 相关依赖临时切到 `../../media-kit` 相对路径。
- `fvm flutter pub get` 验证依赖解析。

建议提交：

```text
docs: 添加 Apple MetalFX 视频增强方案
build: App 接入本地 media-kit 开发依赖
```

### 阶段 B：media-kit macOS MetalFX 管线

- 增加 Dart API 和 MethodChannel。
- 增加原生 capability query。
- 实现 MetalFX processor、private 输出纹理、GPU blit 和三缓冲输出。
- 先完成 macOS 编译与能力验证。

建议提交：

```text
feat(macos): 添加 MetalFX Spatial 视频输出管线
```

### 阶段 C：App 开关与 Retina 目标计算

- 新增持久化设置和 UI。
- 新增 viewport/output 计算及单元测试。
- 接入播放开始、片源尺寸变化、窗口变化和即时开关。

建议提交：

```text
feat: 添加 Apple MetalFX 视频增强开关
test: 覆盖 MetalFX Retina 输出计算
```

### 阶段 D：iPadOS 兼容

- 复用公共 MetalFX processor。
- 真机查询 `supportsDevice`。
- 验证 OpenGL ES → Metal 同步、横竖屏和前后台切换。
- 不以模拟器结果作为真机验收依据。

建议提交：

```text
feat(ios): 接入 MetalFX Spatial 视频输出
```

### 阶段 E：验收与恢复发布依赖

- 对比 bilinear、mpv 高质量 scaler、MetalFX Spatial。
- 记录 720p、1080p、窗口、内屏全屏、外接 4K 的耗时和掉帧。
- 连续播放至少 10 分钟，观察温度、功耗和内存。
- App 依赖恢复为带 commit ref 的 git 依赖。
- 完整执行 `fvm flutter analyze` 与相关测试。

建议提交：

```text
build: media-kit 恢复为 git 发布依赖
```

## 10. 验收标准

macOS 首阶段通过条件：

1. M3 Max 上 `supportsDevice == true`。
2. 1080p 可分别输出到 3024×1701 与 3840×2160。
3. 开关过程中不重建 Player、不黑屏、不影响弹幕与控件。
4. 关闭或处理失败时恢复源分辨率 PixelBuffer。
5. 30fps 直播无持续掉帧；GPU/墙钟耗时有日志。
6. MetalFX 相比高质量传统 scaler 在真实低码率直播中有肉眼可见收益，否则不进入默认功能。

iPadOS 后续通过条件：

1. 必须在物理 iPad 上通过 `supportsDevice`。
2. 输出尺寸按实际 Retina 视频区域计算。
3. 横竖屏、分屏、前后台切换不会保留错误尺寸或旧帧。
4. 连续播放温度、内存和电量消耗可接受。
