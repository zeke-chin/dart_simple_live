import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

/// 在 macOS 销毁 Dart 引擎前等待播放器解绑原生回调。
class PlayerShutdown with WidgetsBindingObserver {
  PlayerShutdown({
    required Future<void> Function() release,
    bool listenForAppExit = false,
  }) : _release = release {
    if (listenForAppExit) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  final Future<void> Function() _release;
  Future<void>? _pending;

  /// 页面关闭和应用退出共享同一次释放；完成前保留退出监听。
  Future<void> dispose() => _pending ??= Future<void>.sync(_release).then((_) {
        WidgetsBinding.instance.removeObserver(this);
      });

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    try {
      await dispose();
      return AppExitResponse.exit;
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Simple Live',
        context: ErrorDescription('退出前释放播放器失败'),
      ));
      // 原生回调可能仍然存活，此时不能继续销毁 Dart 引擎。
      return AppExitResponse.cancel;
    }
  }
}
