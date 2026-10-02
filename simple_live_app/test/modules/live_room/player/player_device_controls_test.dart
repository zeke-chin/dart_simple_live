import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/custom_throttle.dart';
import 'package:simple_live_app/modules/live_room/player/player_device_controls.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const brightnessChannel =
      MethodChannel('github.com/aaassseee/screen_brightness');
  const volumeChannel =
      MethodChannel('com.kurenai7968.volume_controller.method');
  final calls = <MethodCall>[];
  final errors = <Object>[];
  var currentBrightness = 0.4;
  var currentVolume = 0.3;

  PlayerDeviceControls controls(TargetPlatform platform) =>
      PlayerDeviceControls(
        platform: platform,
        onError: errors.add,
      );

  setUp(() {
    calls.clear();
    errors.clear();
    currentBrightness = 0.4;
    currentVolume = 0.3;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(brightnessChannel,
        (call) async {
      calls.add(call);
      if (call.method == 'getApplicationScreenBrightness') {
        return currentBrightness;
      }
      // 故意与实际屏幕值不同，防止误用 iOS 插件缓存的系统亮度。
      if (call.method == 'getSystemScreenBrightness') return 0.9;
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(volumeChannel,
        (call) async {
      calls.add(call);
      if (call.method == 'getVolume') return currentVolume;
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(brightnessChannel, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(volumeChannel, null);
  });

  test('iOS 调亮度不建立应用内覆盖，离开直播间也不恢复旧值', () async {
    final device = controls(TargetPlatform.iOS);
    await device.setBrightness(0.7);
    await device.resetBrightness();
    expect(calls.map((call) => call.method), ['setSystemScreenBrightness']);
    expect(calls.single.arguments, {'brightness': 0.7});
    expect(errors, isEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    test('$platform 保留应用亮度及退出重置行为', () async {
      final device = controls(platform);
      await device.setBrightness(0.6);
      await device.resetBrightness();
      expect(calls.map((call) => call.method), [
        'setApplicationScreenBrightness',
        'resetApplicationScreenBrightness',
      ]);
    });
  }

  test('Windows 和 Linux 退出时不调用亮度插件', () async {
    await controls(TargetPlatform.windows).resetBrightness();
    await controls(TargetPlatform.linux).resetBrightness();
    expect(calls, isEmpty);
  });

  test('控制中心调整后读取当前亮度和音量，不复用缓存', () async {
    final device = controls(TargetPlatform.iOS);
    expect(await device.readBrightness(), 0.4);
    expect(await device.readVolume(), 0.3);
    currentBrightness = 0.8;
    currentVolume = 0.6;
    expect(await device.readBrightness(), 0.8);
    expect(await device.readVolume(), 0.6);
  });

  test('iOS 播放器保持原始增益，其他平台保留独立音量', () {
    expect(controls(TargetPlatform.iOS).playerVolume(25), 100);
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows
    ]) {
      expect(controls(platform).playerVolume(25), 25);
    }
    expect(calls, isEmpty); // 初始化播放器增益不会修改系统音量。
  });

  test('音量手势调用系统音量，包含静音和最大音量', () async {
    final device = controls(TargetPlatform.iOS);
    for (final value in [0.0, 0.65, 1.0]) {
      await device.setVolume(value);
    }
    expect(calls.map((call) => call.method), everyElement('setVolume'));
    expect(calls.map((call) => call.arguments['volume']), [0.0, 0.65, 1.0]);
  });

  test('亮度写入失败被记录，后续调节仍可执行', () async {
    var fail = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(brightnessChannel,
        (call) async {
      if (fail) {
        throw PlatformException(
            code: '-1', message: 'Unable to change system screen brightness');
      }
      calls.add(call);
      return null;
    });
    final device = controls(TargetPlatform.iOS);
    await device.setBrightness(0.5);
    expect(errors.single, isA<PlatformException>());
    fail = false;
    await device.setBrightness(0.8);
    expect(calls.single.arguments, {'brightness': 0.8});
  });

  test('桌面亮度重置失败被记录，不中断后续资源清理', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(brightnessChannel,
        (_) async {
      throw PlatformException(
          code: '-1', message: 'Unable to reset screen brightness');
    });
    await expectLater(
        controls(TargetPlatform.macOS).resetBrightness(), completes);
    expect(errors.single, isA<PlatformException>());
  });

  test('读取插件失败返回空值，不伪造亮度或音量起点', () async {
    for (final channel in [brightnessChannel, volumeChannel]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (_) async {
        throw PlatformException(code: '-9', message: 'value returns null');
      });
    }
    final device = controls(TargetPlatform.iOS);
    expect(await device.readBrightness(), isNull);
    expect(await device.readVolume(), isNull);
    expect(errors, hasLength(2));
  });

  testWidgets('音量插件异常后节流器仍能执行后续调整', (tester) async {
    var attempts = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(volumeChannel,
        (call) async {
      if (++attempts == 1) throw PlatformException(code: 'audio_session_error');
      calls.add(call);
      return null;
    });
    final device = controls(TargetPlatform.iOS);
    final throttle = DelayedThrottle(200);
    throttle.invoke(() => device.setVolume(0.2));
    throttle.invoke(() => device.setVolume(0.7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(errors.single, isA<PlatformException>());
    expect(calls.single.arguments['volume'], 0.7);
    expect(throttle.isInvoking, isFalse);
  });
}
