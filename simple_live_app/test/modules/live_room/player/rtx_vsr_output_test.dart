import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/rtx_vsr_output.dart';

void main() {
  group('calculateRtxVsrOutput', () {
    test('matches a fractional contain viewport without a second resize', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 960,
        sourceHeight: 540,
        viewportWidth: 1280,
        viewportHeight: 720,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 1.3333);
      expect(output?.width, 1280);
      expect(output?.height, 720);
    });

    test('uses the letterboxed content size for contain', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 960,
        sourceHeight: 720,
        viewportWidth: 1920,
        viewportHeight: 1080,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 1.5);
      expect(output?.width, 1440);
      expect(output?.height, 1080);
    });

    test('uses the cropped content size for cover', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 960,
        sourceHeight: 720,
        viewportWidth: 1920,
        viewportHeight: 1080,
        fit: BoxFit.cover,
      );

      expect(output?.scale, 2.0);
      expect(output?.width, 1920);
      expect(output?.height, 1440);
    });

    test('downscales sources to the window viewport', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 1920,
        sourceHeight: 1080,
        viewportWidth: 1280,
        viewportHeight: 720,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 0.6667);
      expect(output?.width, 1280);
      expect(output?.height, 720);
    });

    test('uses the letterboxed window content size when downscaling', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 1920,
        sourceHeight: 1440,
        viewportWidth: 1280,
        viewportHeight: 720,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 0.5);
      expect(output?.width, 960);
      expect(output?.height, 720);
    });

    test('limits upscaling to two times', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 640,
        sourceHeight: 360,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 2.0);
      expect(output?.width, 1280);
      expect(output?.height, 720);
    });

    test('rejects invalid dimensions', () {
      final output = calculateRtxVsrOutput(
        sourceWidth: 0,
        sourceHeight: 540,
        viewportWidth: 1280,
        viewportHeight: 720,
        fit: BoxFit.contain,
      );

      expect(output, isNull);
    });
  });
}
