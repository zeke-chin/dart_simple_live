import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_shutdown.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('退出请求等待播放器释放完成', () async {
    final released = Completer<void>();
    var calls = 0;
    final shutdown = PlayerShutdown(
      listenForAppExit: true,
      release: () {
        calls++;
        return released.future;
      },
    );
    addTearDown(() => binding.removeObserver(shutdown));

    var exited = false;
    final exit = binding.handleRequestAppExit().then((response) {
      exited = true;
      return response;
    });
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(exited, isFalse);

    released.complete();
    expect(await exit, AppExitResponse.exit);
  });

  test('关闭页面后立即退出仍等待同一次释放，连续退出不重复释放', () async {
    final released = Completer<void>();
    var calls = 0;
    final shutdown = PlayerShutdown(
      listenForAppExit: true,
      release: () {
        calls++;
        return released.future;
      },
    );
    addTearDown(() => binding.removeObserver(shutdown));

    final pageClose = shutdown.dispose();
    expect(identical(shutdown.dispose(), pageClose), isTrue);
    var completedExits = 0;
    Future<AppExitResponse> requestExit() async {
      final response = await binding.handleRequestAppExit();
      completedExits++;
      return response;
    }

    final firstExit = requestExit();
    final secondExit = requestExit();
    await Future<void>.delayed(Duration.zero);
    expect(completedExits, 0);
    expect(calls, 1);

    released.complete();
    await pageClose;
    expect(await firstExit, AppExitResponse.exit);
    expect(await secondExit, AppExitResponse.exit);
    await shutdown.dispose();
    expect(calls, 1);
  });

  test('未启用退出监听的平台只在页面关闭时释放', () async {
    var calls = 0;
    final shutdown = PlayerShutdown(release: () async => calls++);
    expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
    expect(calls, 0);
    await shutdown.dispose();
    expect(calls, 1);
  });

  test('原生资源释放失败时取消退出并报告错误', () async {
    final error = StateError('释放失败');
    final shutdown = PlayerShutdown(
      listenForAppExit: true,
      release: () => throw error,
    );
    addTearDown(() => binding.removeObserver(shutdown));
    final previousHandler = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousHandler);

    expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
    expect(errors.single.exception, same(error));
    // 失败后保留监听，下一次退出也不能绕过尚未完成的释放。
    expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
    expect(errors, hasLength(2));
  });
}
