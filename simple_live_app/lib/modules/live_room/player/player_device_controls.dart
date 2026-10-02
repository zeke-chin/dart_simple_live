import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

/// 播放器与设备亮度、媒体音量之间的边界，集中处理平台差异和插件异常。
class PlayerDeviceControls {
  PlayerDeviceControls({required this.platform, required this.onError});

  final TargetPlatform platform;
  final void Function(Object error) onError;

  double playerVolume(double savedVolume) =>
      platform == TargetPlatform.iOS ? 100.0 : savedVolume;

  /// iOS 的 system getter 是插件缓存；application getter 才读取当前屏幕。
  Future<double?> readBrightness() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (error) {
      onError(error);
      return null;
    }
  }

  Future<double?> readVolume() async {
    try {
      return await VolumeController.instance.getVolume();
    } catch (error) {
      onError(error);
      return null;
    }
  }

  Future<void> setBrightness(double brightness) async {
    try {
      if (platform == TargetPlatform.iOS) {
        // 不设置应用内覆盖值，避免从控制中心返回后重新应用旧亮度。
        // 底层仍是 UIScreen.brightness，不代表永久修改系统设置。
        await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
      } else {
        await ScreenBrightness.instance
            .setApplicationScreenBrightness(brightness);
      }
    } catch (error) {
      onError(error);
    }
  }

  Future<void> resetBrightness() async {
    // iOS 保留用户的调整，Windows/Linux 不调用不适用的亮度重置接口。
    if (platform != TargetPlatform.android &&
        platform != TargetPlatform.macOS) {
      return;
    }
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (error) {
      onError(error);
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await VolumeController.instance.setVolume(volume);
    } catch (error) {
      // 必须正常结束 Future，否则节流器会一直停留在调用中。
      onError(error);
    }
  }
}
