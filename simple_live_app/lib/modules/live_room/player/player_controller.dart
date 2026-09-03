import 'dart:async';
import 'dart:io';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/player/metal_fx_spatial_output.dart';
import 'package:simple_live_app/modules/live_room/player/player_resource_usage.dart';
import 'package:simple_live_app/modules/live_room/player/player_video_stats.dart';
import 'package:simple_live_app/modules/live_room/player/rtx_vsr_output.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

mixin PlayerMixin {
  static const _rtxVsrFilterPrefix =
      'd3d11vpp=format=nv12:scaling-mode=nvidia:scale=';
  static const _rtxVsrPreScaleFilterPrefix =
      'd3d11vpp=format=nv12:scaling-mode=standard:scale=';

  GlobalKey<VideoState> globalPlayerKey = GlobalKey<VideoState>();
  GlobalKey globalDanmuKey = GlobalKey();

  Timer? _rtxVsrResizeTimer;
  Size? _rtxVsrViewportSize;
  BoxFit _rtxVsrFit = BoxFit.contain;
  String? _lastRtxVsrFilter;
  Size? _lastRtxVsrOutputSize;
  RtxVsrOutput? _lastRtxVsrOutput;
  int _rtxVsrUpdateGeneration = 0;
  Timer? _videoStatsTimer;
  bool _videoStatsRefreshing = false;
  final videoStats = Rxn<PlayerVideoStats>();
  final _resourceUsageSampler = PlayerResourceUsageSampler();

  Timer? _metalFxSpatialResizeTimer;
  Size? _metalFxSpatialViewportSize;
  BoxFit _metalFxSpatialFit = BoxFit.contain;
  Size? _lastMetalFxSpatialOutputSize;
  MetalFxSpatialOutput? _lastMetalFxSpatialOutput;
  int _metalFxSpatialUpdateGeneration = 0;
  bool? _metalFxSpatialSupported;
  bool _metalFxSpatialNativeEnabled = false;

  bool get _rtxVsrEnabled =>
      Platform.isWindows && AppSettingsController.instance.rtxVsr.value;

  bool get _metalFxSpatialEnabled =>
      (Platform.isMacOS || Platform.isIOS) &&
      AppSettingsController.instance.metalFxSpatial.value;

  /// 播放器实例
  late final player = Player(
    configuration: PlayerConfiguration(
      title: "Simple Live Player",
      logLevel: AppSettingsController.instance.logEnable.value
          ? MPVLogLevel.info
          : MPVLogLevel.error,
    ),
  );

  /// 初始化播放器并设置 ao 参数
  Future<void> initializePlayer() async {
    var pp = player.platform as NativePlayer;
    if (_rtxVsrEnabled) {
      _resetRtxVsrOutputState();
      await pp.setProperty('hwdec', 'd3d11va');
      const filter = '${_rtxVsrFilterPrefix}1.0000';
      await pp.setProperty(
        'vf',
        filter,
      );
      _lastRtxVsrFilter = filter;
    }
    if (_metalFxSpatialEnabled) {
      _metalFxSpatialSupported =
          await videoController.isMetalFxSpatialSupported();
      Log.d('MetalFX Spatial supported: $_metalFxSpatialSupported');
      if (_metalFxSpatialSupported != true) {
        AppSettingsController.instance.setMetalFxSpatial(false);
      }
    }
    // 设置音频输出驱动
    if (AppSettingsController.instance.customPlayerOutput.value) {
      if (player.platform is NativePlayer) {
        await (player.platform as dynamic).setProperty(
          'ao',
          AppSettingsController.instance.audioOutputDriver.value,
        );
      }
    }
    // media_kit 仓库更新导致的问题，临时解决办法
    if (Platform.isAndroid) {
      await pp.setProperty('force-seekable', 'yes');
    }
  }

  Future<void> setRtxVsrEnabled(bool enabled) async {
    if (!Platform.isWindows ||
        AppSettingsController.instance.rtxVsr.value == enabled) {
      return;
    }

    AppSettingsController.instance.setRtxVsr(enabled);
    _resetRtxVsrOutputState();
    try {
      final pp = player.platform as NativePlayer;
      if (enabled) {
        await pp.setProperty('hwdec', 'd3d11va');
        const filter = '${_rtxVsrFilterPrefix}1.0000';
        await pp.setProperty('vf', filter);
        _lastRtxVsrFilter = filter;
        scheduleRtxVsrOutputUpdate();
      } else {
        await pp.setProperty('vf', '');
        await videoController.setSize();
      }
    } catch (e) {
      Log.w('切换 RTX VSR 失败：$e');
      SmartDialog.showToast('切换 RTX VSR 失败，请重新进入直播间');
    }
  }

  void updateRtxVsrViewport({
    required Size logicalSize,
    required double devicePixelRatio,
    required BoxFit fit,
  }) {
    if (logicalSize.isEmpty ||
        !logicalSize.width.isFinite ||
        !logicalSize.height.isFinite ||
        devicePixelRatio <= 0) {
      return;
    }

    final viewportSize = Size(
      (logicalSize.width * devicePixelRatio).roundToDouble(),
      (logicalSize.height * devicePixelRatio).roundToDouble(),
    );
    if (_rtxVsrViewportSize == viewportSize && _rtxVsrFit == fit) {
      return;
    }

    _rtxVsrViewportSize = viewportSize;
    _rtxVsrFit = fit;
    if (_rtxVsrEnabled) {
      scheduleRtxVsrOutputUpdate();
    }
  }

  void scheduleRtxVsrOutputUpdate() {
    if (!_rtxVsrEnabled || _rtxVsrViewportSize == null) {
      return;
    }
    _rtxVsrResizeTimer?.cancel();
    final generation = ++_rtxVsrUpdateGeneration;
    _rtxVsrResizeTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(_updateRtxVsrOutput(generation));
    });
  }

  Future<void> _updateRtxVsrOutput(int generation) async {
    final viewportSize = _rtxVsrViewportSize;
    if (!_rtxVsrEnabled || viewportSize == null) {
      return;
    }

    try {
      final pp = player.platform as NativePlayer;
      final dimensions = await Future.wait([
        pp.getProperty('video-dec-params/w'),
        pp.getProperty('video-dec-params/h'),
      ]);
      if (generation != _rtxVsrUpdateGeneration) {
        return;
      }

      final sourceWidth = int.tryParse(dimensions[0]);
      final sourceHeight = int.tryParse(dimensions[1]);
      if (sourceWidth == null || sourceHeight == null) {
        return;
      }

      final output = calculateRtxVsrOutput(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        viewportWidth: viewportSize.width.toInt(),
        viewportHeight: viewportSize.height.toInt(),
        fit: _rtxVsrFit,
      );
      if (output == null) {
        return;
      }

      final filter = _buildRtxVsrFilter(output);
      final outputSize =
          Size(output.width.toDouble(), output.height.toDouble());
      if (_lastRtxVsrFilter == filter && _lastRtxVsrOutputSize == outputSize) {
        return;
      }

      if (_lastRtxVsrFilter != filter) {
        await pp.setProperty('vf', filter);
        _lastRtxVsrFilter = filter;
      }
      if (_lastRtxVsrOutputSize != outputSize) {
        await videoController.setSize(
          width: output.width,
          height: output.height,
        );
        _lastRtxVsrOutputSize = outputSize;
      }
      _lastRtxVsrOutput = output;
      Log.d(
        'RTX VSR: source=${sourceWidth}x$sourceHeight, '
        'viewport=${viewportSize.width.toInt()}x${viewportSize.height.toInt()}, '
        'preScale=${output.preScale?.toStringAsFixed(4) ?? '-'}, '
        'vsrScale=${output.scale.toStringAsFixed(4)}, '
        'output=${output.width}x${output.height}',
      );
    } catch (e) {
      Log.w('更新 RTX VSR 输出尺寸失败：$e');
    }
  }

  void disposeRtxVsrOutput() {
    _resetRtxVsrOutputState();
  }

  void _resetRtxVsrOutputState() {
    _rtxVsrResizeTimer?.cancel();
    _rtxVsrResizeTimer = null;
    _lastRtxVsrFilter = null;
    _lastRtxVsrOutputSize = null;
    _lastRtxVsrOutput = null;
    _rtxVsrUpdateGeneration++;
  }

  Future<void> setMetalFxSpatialEnabled(bool enabled) async {
    if ((!Platform.isMacOS && !Platform.isIOS) ||
        AppSettingsController.instance.metalFxSpatial.value == enabled) {
      return;
    }

    if (enabled) {
      try {
        final supported = await videoController.isMetalFxSpatialSupported();
        _metalFxSpatialSupported = supported;
        if (!supported) {
          SmartDialog.showToast('当前设备不支持 Apple MetalFX 视频增强');
          return;
        }
      } catch (e) {
        Log.w('查询 MetalFX Spatial 支持失败：$e');
        SmartDialog.showToast('无法启用 Apple MetalFX 视频增强');
        return;
      }
    }

    AppSettingsController.instance.setMetalFxSpatial(enabled);
    _resetMetalFxSpatialOutputState();
    if (enabled) {
      scheduleMetalFxSpatialOutputUpdate();
      return;
    }

    try {
      await videoController.setMetalFxSpatial(enabled: false);
      _metalFxSpatialNativeEnabled = false;
    } catch (e) {
      Log.w('关闭 MetalFX Spatial 失败：$e');
    }
  }

  void updateMetalFxSpatialViewport({
    required Size logicalSize,
    required double devicePixelRatio,
    required BoxFit fit,
  }) {
    if (logicalSize.isEmpty ||
        !logicalSize.width.isFinite ||
        !logicalSize.height.isFinite ||
        devicePixelRatio <= 0) {
      return;
    }

    final viewportSize = Size(
      (logicalSize.width * devicePixelRatio).roundToDouble(),
      (logicalSize.height * devicePixelRatio).roundToDouble(),
    );
    if (_metalFxSpatialViewportSize == viewportSize &&
        _metalFxSpatialFit == fit) {
      return;
    }

    _metalFxSpatialViewportSize = viewportSize;
    _metalFxSpatialFit = fit;
    if (_metalFxSpatialEnabled) {
      scheduleMetalFxSpatialOutputUpdate();
    }
  }

  void scheduleMetalFxSpatialOutputUpdate() {
    if (!_metalFxSpatialEnabled ||
        _metalFxSpatialViewportSize == null ||
        _metalFxSpatialSupported == false) {
      return;
    }
    _metalFxSpatialResizeTimer?.cancel();
    final generation = ++_metalFxSpatialUpdateGeneration;
    _metalFxSpatialResizeTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(_updateMetalFxSpatialOutput(generation));
    });
  }

  Future<void> _updateMetalFxSpatialOutput(int generation) async {
    final viewportSize = _metalFxSpatialViewportSize;
    if (!_metalFxSpatialEnabled || viewportSize == null) {
      return;
    }

    try {
      _metalFxSpatialSupported ??=
          await videoController.isMetalFxSpatialSupported();
      if (_metalFxSpatialSupported != true ||
          generation != _metalFxSpatialUpdateGeneration) {
        return;
      }

      final pp = player.platform as NativePlayer;
      final dimensions = await Future.wait([
        pp.getProperty('video-dec-params/w'),
        pp.getProperty('video-dec-params/h'),
      ]);
      if (generation != _metalFxSpatialUpdateGeneration) {
        return;
      }

      final sourceWidth = int.tryParse(dimensions[0]);
      final sourceHeight = int.tryParse(dimensions[1]);
      if (sourceWidth == null || sourceHeight == null) {
        return;
      }

      final output = calculateMetalFxSpatialOutput(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        viewportWidth: viewportSize.width.toInt(),
        viewportHeight: viewportSize.height.toInt(),
        fit: _metalFxSpatialFit,
      );
      if (output == null) {
        if (_metalFxSpatialNativeEnabled) {
          await videoController.setMetalFxSpatial(enabled: false);
          _metalFxSpatialNativeEnabled = false;
          _lastMetalFxSpatialOutputSize = null;
          _lastMetalFxSpatialOutput = null;
        }
        return;
      }

      final outputSize = Size(
        output.width.toDouble(),
        output.height.toDouble(),
      );
      if (_lastMetalFxSpatialOutputSize == outputSize &&
          _metalFxSpatialNativeEnabled) {
        return;
      }

      await videoController.setMetalFxSpatial(
        enabled: true,
        width: output.width,
        height: output.height,
      );
      _metalFxSpatialNativeEnabled = true;
      _lastMetalFxSpatialOutputSize = outputSize;
      _lastMetalFxSpatialOutput = output;
      Log.d(
        'MetalFX Spatial: source=${sourceWidth}x$sourceHeight, '
        'viewport=${viewportSize.width.toInt()}x${viewportSize.height.toInt()}, '
        'scale=${output.scale.toStringAsFixed(4)}, '
        'output=${output.width}x${output.height}',
      );
    } catch (e) {
      Log.w('更新 MetalFX Spatial 输出尺寸失败：$e');
      _metalFxSpatialNativeEnabled = false;
      _lastMetalFxSpatialOutputSize = null;
      _lastMetalFxSpatialOutput = null;
      try {
        await videoController.setMetalFxSpatial(enabled: false);
      } catch (_) {}
    }
  }

  void disposeMetalFxSpatialOutput() {
    _resetMetalFxSpatialOutputState();
  }

  void _resetMetalFxSpatialOutputState() {
    _metalFxSpatialResizeTimer?.cancel();
    _metalFxSpatialResizeTimer = null;
    _lastMetalFxSpatialOutputSize = null;
    _lastMetalFxSpatialOutput = null;
    _metalFxSpatialNativeEnabled = false;
    _metalFxSpatialUpdateGeneration++;
  }

  SuperResolutionStats? currentSuperResolutionStats() {
    final nvidia = nvidiaRtxVsrStats(
      enabled: _rtxVsrEnabled,
      outputWidth: _lastRtxVsrOutput?.width,
      outputHeight: _lastRtxVsrOutput?.height,
      scale: _lastRtxVsrOutput?.scale,
    );
    if (nvidia != null) {
      return nvidia;
    }
    return appleMetalFxSpatialStats(
      enabled: _metalFxSpatialEnabled,
      active: _metalFxSpatialNativeEnabled,
      outputWidth: _lastMetalFxSpatialOutput?.width,
      outputHeight: _lastMetalFxSpatialOutput?.height,
      scale: _lastMetalFxSpatialOutput?.scale,
    );
  }

  void startVideoStatsPolling() {
    _videoStatsTimer?.cancel();
    _videoStatsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshVideoStats());
    });
    unawaited(_refreshVideoStats());
  }

  void disposeVideoStatsPolling() {
    _videoStatsTimer?.cancel();
    _videoStatsTimer = null;
    videoStats.value = null;
    _resourceUsageSampler.reset();
  }

  Future<void> _refreshVideoStats() async {
    if (_videoStatsRefreshing) {
      return;
    }
    if (!AppSettingsController.instance.showPlayerVideoStats.value) {
      if (videoStats.value != null) {
        videoStats.value = null;
      }
      return;
    }
    if (player.platform is! NativePlayer) {
      return;
    }

    _videoStatsRefreshing = true;
    try {
      final resourceUsageFuture = _resourceUsageSampler.sample(videoController);
      final pp = player.platform as NativePlayer;
      final values = await Future.wait([
        pp.getProperty('video-dec-params/w'),
        pp.getProperty('video-dec-params/h'),
        pp.getProperty('packet-video-bitrate'),
        pp.getProperty('video-bitrate'),
        pp.getProperty('estimated-vf-fps'),
        pp.getProperty('container-fps'),
        pp.getProperty('hwdec-current'),
      ]);
      final resourceUsage = await resourceUsageFuture;
      videoStats.value = playerVideoStatsFromMpv(
        decWidth: values[0],
        decHeight: values[1],
        packetBitrate: values[2],
        videoBitrate: values[3],
        estimatedFps: values[4],
        containerFps: values[5],
        hwdec: values[6],
        superResolution: currentSuperResolutionStats(),
        resourceUsage: resourceUsage,
      );
    } catch (e) {
      Log.d('刷新播放信息失败：$e');
    } finally {
      _videoStatsRefreshing = false;
    }
  }

  String _buildRtxVsrFilter(RtxVsrOutput output) {
    final vsrFilter = '$_rtxVsrFilterPrefix${output.scale.toStringAsFixed(4)}';
    final preScale = output.preScale;
    if (preScale == null) {
      return vsrFilter;
    }
    return '$_rtxVsrPreScaleFilterPrefix${preScale.toStringAsFixed(4)},'
        '$vsrFilter';
  }

  /// 视频控制器
  late final videoController = VideoController(
    player,
    configuration: Platform.isWindows &&
            AppSettingsController.instance.rtxVsr.value
        ? const VideoControllerConfiguration(
            vo: 'libmpv',
            hwdec: 'd3d11va',
          )
        : AppSettingsController.instance.customPlayerOutput.value
            ? VideoControllerConfiguration(
                vo: AppSettingsController.instance.videoOutputDriver.value,
                hwdec:
                    AppSettingsController.instance.videoHardwareDecoder.value,
              )
            : AppSettingsController.instance.playerCompatMode.value
                ? const VideoControllerConfiguration(
                    vo: 'mediacodec_embed',
                    hwdec: 'mediacodec',
                  )
                : VideoControllerConfiguration(
                    enableHardwareAcceleration: _metalFxSpatialEnabled ||
                        AppSettingsController.instance.hardwareDecode.value,
                    androidAttachSurfaceAfterVideoParameters: false,
                  ),
  );
}

mixin PlayerStateMixin on PlayerMixin {
  ///音量控制条计时器
  Timer? hidevolumeTimer;

  /// 是否进入桌面端小窗
  RxBool smallWindowState = false.obs;

  /// 是否显示弹幕
  RxBool showDanmakuState = false.obs;

  /// 是否显示控制器
  RxBool showControlsState = false.obs;

  /// 是否显示设置窗口
  RxBool showSettingState = false.obs;

  /// 是否显示弹幕设置窗口
  RxBool showDanmakuSettingState = false.obs;

  /// 是否处于锁定控制器状态
  RxBool lockControlsState = false.obs;

  /// 是否处于全屏状态
  RxBool fullScreenState = false.obs;

  /// 显示手势Tip
  RxBool showGestureTip = false.obs;

  /// 手势Tip文本
  RxString gestureTipText = "".obs;

  /// 显示提示底部Tip
  RxBool showBottomTip = false.obs;

  /// 提示底部Tip文本
  RxString bottomTipText = "".obs;

  /// 自动隐藏控制器计时器
  Timer? hideControlsTimer;

  /// 自动隐藏提示计时器
  Timer? hideSeekTipTimer;

  /// 是否为竖屏直播间
  var isVertical = false.obs;

  Widget? danmakuView;

  var showQualites = false.obs;
  var showLines = false.obs;

  /// 隐藏控制器
  void hideControls() {
    showControlsState.value = false;
    hideControlsTimer?.cancel();
  }

  void setLockState() {
    lockControlsState.value = !lockControlsState.value;
    if (lockControlsState.value) {
      showControlsState.value = false;
    } else {
      showControlsState.value = true;
    }
  }

  /// 显示控制器
  void showControls() {
    showControlsState.value = true;
    resetHideControlsTimer();
  }

  /// 开始隐藏控制器计时
  /// - 当点击控制器上时功能时需要重新计时
  void resetHideControlsTimer() {
    hideControlsTimer?.cancel();

    hideControlsTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      hideControls,
    );
  }

  void updateScaleMode() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (player.state.width != null && player.state.height != null) {
      aspectRatio = player.state.width! / player.state.height!;
    }

    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    globalPlayerKey.currentState?.update(
      aspectRatio: aspectRatio,
      fit: boxFit,
    );
  }
}
mixin PlayerDanmakuMixin on PlayerStateMixin {
  /// 弹幕控制器
  DanmakuController? danmakuController;

  void initDanmakuController(DanmakuController e) {
    danmakuController = e;
    // danmakuController?.updateOption(
    //   DanmakuOption(
    //     fontSize: AppSettingsController.instance.danmuSize.value,
    //     area: AppSettingsController.instance.danmuArea.value,
    //     duration: AppSettingsController.instance.danmuSpeed.value,
    //     opacity: AppSettingsController.instance.danmuOpacity.value,
    //     strokeWidth: AppSettingsController.instance.danmuStrokeWidth.value,
    //     fontWeight: FontWeight
    //         .values[AppSettingsController.instance.danmuFontWeight.value],
    //   ),
    // );
  }

  void updateDanmuOption(DanmakuOption? option) {
    if (danmakuController == null || option == null) return;
    danmakuController!.updateOption(option);
  }

  void disposeDanmakuController() {
    danmakuController?.clear();
  }

  void addDanmaku(List<DanmakuContentItem> items) {
    if (!showDanmakuState.value) {
      return;
    }
    for (var item in items) {
      danmakuController?.addDanmaku(item);
    }
  }
}
mixin PlayerSystemMixin on PlayerMixin, PlayerStateMixin, PlayerDanmakuMixin {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  final pip = Floating();
  StreamSubscription<PiPStatus>? _pipSubscription;
  bool _desktopWindowWasFullScreen = false;
  bool _desktopWindowWasMaximized = false;
  bool _desktopFullScreenTransitioning = false;

  //final VolumeController volumeController = VolumeController();

  /// 初始化一些系统状态
  void initSystem() async {
    if (Platform.isAndroid || Platform.isIOS) {
      VolumeController.instance.showSystemUI = false;
    }

    // 屏幕常亮
    //WakelockPlus.enable();

    // 开始隐藏计时
    resetHideControlsTimer();

    // 进入全屏模式
    if (AppSettingsController.instance.autoFullScreen.value) {
      enterFullScreen();
    }
  }

  /// 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    //pip.dispose();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    await setPortraitOrientation();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (e) {
        Log.logPrint(e);
      }
    }

    await WakelockPlus.disable();
  }

  /// 进入全屏
  Future<void> enterFullScreen() async {
    if (fullScreenState.value || _desktopFullScreenTransitioning) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      fullScreenState.value = true;
      //全屏
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      if (!isVertical.value) {
        //横屏
        await setLandscapeOrientation();
      }
      return;
    }

    _desktopFullScreenTransitioning = true;
    try {
      _desktopWindowWasFullScreen = await windowManager.isFullScreen();
      _desktopWindowWasMaximized =
          !_desktopWindowWasFullScreen && await windowManager.isMaximized();
      if (_desktopWindowWasMaximized) {
        // window_manager 0.5.2 does not switch a maximized window to
        // frameless before fullscreen. Hidden title-bar mode makes its
        // WM_NCCALCSIZE handler use the whole monitor client area.
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      if (!_desktopWindowWasFullScreen) {
        await windowManager.setFullScreen(true);
      }
      fullScreenState.value = true;
    } catch (e) {
      if (_desktopWindowWasMaximized) {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      _desktopWindowWasFullScreen = false;
      _desktopWindowWasMaximized = false;
      Log.w('进入直播全屏失败：$e');
      SmartDialog.showToast('进入直播全屏失败');
    } finally {
      _desktopFullScreenTransitioning = false;
    }
    //danmakuController?.clear();
  }

  /// 退出全屏
  Future<void> exitFull() async {
    if (!fullScreenState.value || _desktopFullScreenTransitioning) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      await setPortraitOrientation();
      fullScreenState.value = false;
      return;
    }

    _desktopFullScreenTransitioning = true;
    try {
      if (!_desktopWindowWasFullScreen) {
        await windowManager.setFullScreen(false);
        if (_desktopWindowWasMaximized) {
          await windowManager.setTitleBarStyle(TitleBarStyle.normal);
          await windowManager.maximize();
        }
      }
      fullScreenState.value = false;
      _desktopWindowWasFullScreen = false;
      _desktopWindowWasMaximized = false;
    } finally {
      _desktopFullScreenTransitioning = false;
    }

    //danmakuController?.clear();
  }

  Size? _lastWindowSize;
  Offset? _lastWindowPosition;

  ///小窗模式()
  void enterSmallWindow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = true;
      smallWindowState.value = true;

      // 读取窗口大小
      _lastWindowSize = await windowManager.getSize();
      _lastWindowPosition = await windowManager.getPosition();

      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      // 获取视频窗口大小
      var width = player.state.width ?? 16;
      var height = player.state.height ?? 9;

      // 横屏还是竖屏
      if (height > width) {
        var aspectRatio = width / height;
        windowManager.setSize(Size(400, 400 / aspectRatio));
      } else {
        var aspectRatio = height / width;
        windowManager.setSize(Size(280 / aspectRatio, 280));
      }

      windowManager.setAlwaysOnTop(true);
    }
  }

  ///退出小窗模式()
  void exitSmallWindow() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      fullScreenState.value = false;
      smallWindowState.value = false;
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
      windowManager.setSize(_lastWindowSize!);
      windowManager.setPosition(_lastWindowPosition!);
      windowManager.setAlwaysOnTop(false);
      //windowManager.setAlignment(Alignment.center);
    }
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.landscapeAutoMode();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    if (await beforeIOS16()) {
      AutoOrientation.portraitAutoMode();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// 是否是IOS16以下
  Future<bool> beforeIOS16() async {
    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      var version = info.systemVersion;
      var versionInt = int.tryParse(version.split('.').first) ?? 0;
      return versionInt < 16;
    } else {
      return false;
    }
  }

  Future saveScreenshot() async {
    try {
      SmartDialog.showLoading(msg: "正在保存截图");
      //检查相册权限,仅iOS需要
      var permission = await Utils.checkPhotoPermission();
      if (!permission) {
        SmartDialog.showToast("没有相册权限");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      var imageData = await player.screenshot();
      if (imageData == null) {
        SmartDialog.showToast("截图失败,数据为空");
        SmartDialog.dismiss(status: SmartStatus.loading);
        return;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await ImageGallerySaverPlus.saveImage(
          imageData,
        );
        SmartDialog.showToast("已保存截图至相册");
      } else {
        //选择保存文件夹
        var path = await FilePicker.platform.saveFile(
          allowedExtensions: ["jpg"],
          type: FileType.image,
          fileName: "${DateTime.now().millisecondsSinceEpoch}.jpg",
        );
        if (path == null) {
          SmartDialog.showToast("取消保存");
          SmartDialog.dismiss(status: SmartStatus.loading);
          return;
        }
        var file = File(path);
        await file.writeAsBytes(imageData);
        SmartDialog.showToast("已保存截图至${file.path}");
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("截图失败");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  /// 开启小窗播放前弹幕状态
  bool danmakuStateBeforePIP = false;

  Future enablePIP() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (await pip.isPipAvailable == false) {
      SmartDialog.showToast("设备不支持小窗播放");
      return;
    }
    danmakuStateBeforePIP = showDanmakuState.value;
    //关闭并清除弹幕
    if (AppSettingsController.instance.pipHideDanmu.value &&
        danmakuStateBeforePIP) {
      showDanmakuState.value = false;
    }
    danmakuController?.clear();
    //关闭控制器
    showControlsState.value = false;

    //监听事件
    var width = player.state.width ?? 0;
    var height = player.state.height ?? 0;
    Rational ratio = const Rational.landscape();
    if (height > width) {
      ratio = const Rational.vertical();
    } else {
      ratio = const Rational.landscape();
    }
    await pip.enable(
      ImmediatePiP(
        aspectRatio: ratio,
      ),
    );

    _pipSubscription ??= pip.pipStatusStream.listen((event) {
      if (event == PiPStatus.disabled) {
        danmakuController?.clear();
        showDanmakuState.value = danmakuStateBeforePIP;
      }
      Log.w(event.toString());
    });
  }
}
mixin PlayerGestureControlMixin
    on PlayerStateMixin, PlayerMixin, PlayerSystemMixin {
  /// 单击显示/隐藏控制器
  void onTap() {
    if (showControlsState.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  //桌面端操控
  void onEnter(PointerEnterEvent event) {
    if (!showControlsState.value) {
      showControls();
    }
  }

  void onExit(PointerExitEvent event) {
    if (showControlsState.value) {
      hideControls();
    }
  }

  void onHover(PointerHoverEvent event, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetPosition = screenHeight * 0.25; // 计算屏幕顶部25%的位置
    if (event.position.dy <= targetPosition ||
        event.position.dy >= targetPosition * 3) {
      if (!showControlsState.value) {
        showControls();
      }
    }
  }

  /// 双击全屏/退出全屏
  void onDoubleTap(TapDownDetails details) {
    if (lockControlsState.value) {
      return;
    }
    if (fullScreenState.value) {
      exitFull();
    } else {
      enterFullScreen();
    }
  }

  bool verticalDragging = false;
  bool leftVerticalDrag = false;
  var _currentVolume = 0.0;
  var _currentBrightness = 1.0;
  var verStartPosition = 0.0;

  DelayedThrottle? throttle;

  /// 竖向手势开始
  void onVerticalDragStart(DragStartDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }

    final dy = details.globalPosition.dy;
    // 开始位置必须是中间2/4的位置
    if (dy < Get.height * 0.25 || dy > Get.height * 0.75) {
      return;
    }

    verStartPosition = dy;
    leftVerticalDrag = details.globalPosition.dx < Get.width / 2;

    throttle = DelayedThrottle(200);

    verticalDragging = true;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      showGestureTip.value = true;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _currentVolume = await VolumeController.instance.getVolume();
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _currentBrightness = await ScreenBrightness.instance.application;
    }
  }

  /// 竖向手势更新
  void onVerticalDragUpdate(DragUpdateDetails e) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    if (verticalDragging == false) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    //String text = "";
    //double value = 0.0;

    Log.logPrint("$verStartPosition/${e.globalPosition.dy}");

    if (leftVerticalDrag) {
      setGestureBrightness(e.globalPosition.dy);
    } else {
      setGestureVolume(e.globalPosition.dy);
    }
  }

  int lastVolume = -1; // it's ok to be -1

  void setGestureVolume(double dy) {
    double value = 0.0;
    double seek;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      seek = _currentVolume - value;
      if (seek < 0) {
        seek = 0;
      }
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      seek = value.abs() + _currentVolume;
      if (seek > 1) {
        seek = 1;
      }
    }
    int volume = _convertVolume((seek * 100).round());
    if (volume == lastVolume) {
      return;
    }
    lastVolume = volume;
    // update UI outside throttle to make it more fluent
    gestureTipText.value = "音量 $volume%";
    throttle?.invoke(() async => await _realSetVolume(volume));
  }

  // 0 to 100, 5 step each
  int _convertVolume(int volume) {
    return (volume / 5).round() * 5;
  }

  Future _realSetVolume(int volume) async {
    Log.logPrint(volume);
    VolumeController.instance.setVolume(volume / 100);
  }

  void setGestureBrightness(double dy) {
    double value = 0.0;
    if (dy > verStartPosition) {
      value = ((dy - verStartPosition) / (Get.height * 0.5));

      var seek = _currentBrightness - value;
      if (seek < 0) {
        seek = 0;
      }
      ScreenBrightness.instance.setApplicationScreenBrightness(seek);

      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    } else {
      value = ((dy - verStartPosition) / (Get.height * 0.5));
      var seek = value.abs() + _currentBrightness;
      if (seek > 1) {
        seek = 1;
      }

      ScreenBrightness.instance.setApplicationScreenBrightness(seek);
      gestureTipText.value = "亮度 ${(seek * 100).toInt()}%";
      Log.logPrint(value);
    }
  }

  /// 竖向手势完成
  void onVerticalDragEnd(DragEndDetails details) async {
    if (lockControlsState.value && fullScreenState.value) {
      return;
    }
    throttle = null;
    verticalDragging = false;
    leftVerticalDrag = false;
    showGestureTip.value = false;
  }
}

class PlayerController extends BaseController
    with
        PlayerMixin,
        PlayerStateMixin,
        PlayerDanmakuMixin,
        PlayerSystemMixin,
        PlayerGestureControlMixin {
  @override
  void onInit() {
    initSystem();
    initStream();
    startVideoStatsPolling();
    //设置音量
    player.setVolume(AppSettingsController.instance.playerVolume.value);
    super.onInit();
  }

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _playingSubscription;

  void initStream() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d("播放器错误：$event");
      // 跳过无音频输出的错误
      // Could not open/initialize audio device -> no sound.
      if (event.contains('no sound.')) {
        return;
      }
      //SmartDialog.showToast(event);
      mediaError(event);
    });

    _playingSubscription = player.stream.playing.listen((event) {
      if (event) {
        WakelockPlus.enable();
        Log.d("Playing");
        scheduleRtxVsrOutputUpdate();
        scheduleMetalFxSpatialOutputUpdate();
      }
    });

    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        mediaEnd();
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("播放器日志：$event");
    });
    _widthSubscription = player.stream.width.listen((event) {
      Log.d(
          'width:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      scheduleRtxVsrOutputUpdate();
      scheduleMetalFxSpatialOutputUpdate();
    });
    _heightSubscription = player.stream.height.listen((event) {
      Log.d(
          'height:$event  W:${(player.state.width)}  H:${(player.state.height)}');
      isVertical.value =
          (player.state.height ?? 9) > (player.state.width ?? 16);
      scheduleRtxVsrOutputUpdate();
      scheduleMetalFxSpatialOutputUpdate();
    });
  }

  void disposeStream() {
    _errorSubscription?.cancel();
    _completedSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _logSubscription?.cancel();
    _pipSubscription?.cancel();
    _playingSubscription?.cancel();
    disposeRtxVsrOutput();
    disposeMetalFxSpatialOutput();
    disposeVideoStatsPolling();
  }

  void mediaEnd() {
    WakelockPlus.disable();
  }

  void mediaError(String error) {
    WakelockPlus.disable();
  }

  void showDebugInfo() {
    Utils.showBottomSheet(
      title: "播放信息",
      child: ListView(
        children: [
          ListTile(
            title: const Text("Resolution"),
            subtitle: Text('${player.state.width}x${player.state.height}'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Resolution\n${player.state.width}x${player.state.height}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoParams"),
            subtitle: Text(player.state.videoParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoParams\n${player.state.videoParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioParams"),
            subtitle: Text(player.state.audioParams.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioParams\n${player.state.audioParams}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Media"),
            subtitle: Text(player.state.playlist.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Media\n${player.state.playlist}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioTrack"),
            subtitle: Text(player.state.track.audio.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoTrack"),
            subtitle: Text(player.state.track.video.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "VideoTrack\n${player.state.track.audio}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioBitrate"),
            subtitle: Text(player.state.audioBitrate.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "AudioBitrate\n${player.state.audioBitrate}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Volume"),
            subtitle: Text(player.state.volume.toString()),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: "Volume\n${player.state.volume}",
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void onClose() async {
    Log.w("播放器关闭");
    if (smallWindowState.value) {
      exitSmallWindow();
    }
    disposeStream();
    disposeDanmakuController();
    await resetSystem();
    await player.dispose();
    super.onClose();
  }
}
