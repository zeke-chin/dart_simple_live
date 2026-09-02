import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  const mediaUrl = String.fromEnvironment(
    'METAL_FX_SMOKE_URL',
    defaultValue:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  );
  const sourceWidth = int.fromEnvironment(
    'METAL_FX_SMOKE_SOURCE_WIDTH',
    defaultValue: 1280,
  );
  const sourceHeight = int.fromEnvironment(
    'METAL_FX_SMOKE_SOURCE_HEIGHT',
    defaultValue: 720,
  );
  const outputWidth = int.fromEnvironment(
    'METAL_FX_SMOKE_OUTPUT_WIDTH',
    defaultValue: 1920,
  );
  const outputHeight = int.fromEnvironment(
    'METAL_FX_SMOKE_OUTPUT_HEIGHT',
    defaultValue: 1080,
  );

  testWidgets(
    'macOS MetalFX Spatial renders into the requested texture size',
    (tester) async {
      final player = Player();
      final controller = VideoController(player);
      addTearDown(player.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Video(
              controller: controller,
              controls: NoVideoControls,
            ),
          ),
        ),
      );

      expect(await controller.isMetalFxSpatialSupported(), isTrue);

      final mediaFile = await _downloadTestMedia(mediaUrl);
      addTearDown(() async {
        if (await mediaFile.exists()) {
          await mediaFile.delete();
        }
      });
      await player.setAudioTrack(AudioTrack.no());
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.open(Media(mediaFile.path));
      await controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 30),
      );
      await _waitForTextureSize(
        tester,
        controller,
        width: sourceWidth.toDouble(),
        height: sourceHeight.toDouble(),
      );

      await controller.setMetalFxSpatial(
        enabled: true,
        width: outputWidth,
        height: outputHeight,
      );
      await _waitForTextureSize(
        tester,
        controller,
        width: outputWidth.toDouble(),
        height: outputHeight.toDouble(),
      );

      // Keep enough frames flowing to exercise buffer reuse and metrics.
      await tester.pump(const Duration(seconds: 5));
      expect(player.state.playing, isTrue);

      await controller.setMetalFxSpatial(enabled: false);
      await _waitForTextureSize(
        tester,
        controller,
        width: sourceWidth.toDouble(),
        height: sourceHeight.toDouble(),
      );
    },
    skip: !Platform.isMacOS,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<File> _downloadTestMedia(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to download smoke media: ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    final file = File(
      '${Directory.systemTemp.path}/metal-fx-smoke-${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await response.pipe(file.openWrite());
    return file;
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForTextureSize(
  WidgetTester tester,
  VideoController controller, {
  required double width,
  required double height,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 20)) {
    final rect = controller.rect.value;
    if (rect?.width == width && rect?.height == height) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  fail(
    'Timed out waiting for texture ${width}x$height; '
    'last rect=${controller.rect.value}',
  );
}
