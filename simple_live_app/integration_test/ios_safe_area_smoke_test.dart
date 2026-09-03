import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simple_live_app/app/apple_safe_area.dart';
import 'package:simple_live_app/modules/live_room/player/player_safe_area.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS landscape keeps cutout insets while system UI is hidden',
    (tester) async {
      addTearDown(() async {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ColoredBox(color: Colors.black)),
        ),
      );
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      final mediaQuery = await _waitForLandscape(tester);
      final nativeInsets = await AppleSafeAreaInsets.read();
      final safePadding = resolvePlayerSafeAreaPadding(
        mediaQuery,
        fullScreen: true,
        nativeInsets: nativeInsets,
      );

      expect(mediaQuery.size.width, greaterThan(mediaQuery.size.height));
      expect(
        safePadding.left + safePadding.right,
        greaterThan(0),
        reason: 'A notched iPhone must expose a horizontal safe-area inset',
      );
      expect(nativeInsets, isNotNull);
      expect(
        safePadding,
        mergeSafeAreaInsets(mediaQuery.viewPadding, nativeInsets),
      );
    },
    skip: !Platform.isIOS,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<MediaQueryData> _waitForLandscape(WidgetTester tester) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 15)) {
    await tester.pump(const Duration(milliseconds: 100));
    final mediaQuery = MediaQueryData.fromView(tester.view);
    if (mediaQuery.size.width > mediaQuery.size.height) {
      return mediaQuery;
    }
  }
  return MediaQueryData.fromView(tester.view);
}
