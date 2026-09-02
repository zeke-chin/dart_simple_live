import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/metal_fx_spatial_output.dart';

void main() {
  group('calculateMetalFxSpatialOutput', () {
    test('matches the external 4K viewport for 1080p', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1920,
        sourceHeight: 1080,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 2.0);
      expect(output?.width, 3840);
      expect(output?.height, 2160);
    });

    test('matches the Mac Retina 16:9 content area', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1920,
        sourceHeight: 1080,
        viewportWidth: 3024,
        viewportHeight: 1964,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 1.575);
      expect(output?.width, 3024);
      expect(output?.height, 1701);
    });

    test('uses the Retina content area on an iPad viewport', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1920,
        sourceHeight: 1080,
        viewportWidth: 2360,
        viewportHeight: 1640,
        fit: BoxFit.contain,
      );

      expect(output?.scale, closeTo(2360 / 1920, 0.000001));
      expect(output?.width, 2360);
      expect(output?.height, 1328);
    });

    test('caps 720p output at two times on a 4K viewport', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1280,
        sourceHeight: 720,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.contain,
      );

      expect(output?.scale, 2.0);
      expect(output?.width, 2560);
      expect(output?.height, 1440);
    });

    test('uses the cropped content size for cover', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1280,
        sourceHeight: 960,
        viewportWidth: 1920,
        viewportHeight: 1080,
        fit: BoxFit.cover,
      );

      expect(output?.scale, 1.5);
      expect(output?.width, 1920);
      expect(output?.height, 1440);
    });

    test('does not run when the source already covers the viewport', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 1920,
        sourceHeight: 1080,
        viewportWidth: 1280,
        viewportHeight: 720,
        fit: BoxFit.contain,
      );

      expect(output, isNull);
    });

    test('does not run for BoxFit.none or scaleDown', () {
      final none = calculateMetalFxSpatialOutput(
        sourceWidth: 1280,
        sourceHeight: 720,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.none,
      );
      final scaleDown = calculateMetalFxSpatialOutput(
        sourceWidth: 1280,
        sourceHeight: 720,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.scaleDown,
      );

      expect(none, isNull);
      expect(scaleDown, isNull);
    });

    test('rejects invalid dimensions', () {
      final output = calculateMetalFxSpatialOutput(
        sourceWidth: 0,
        sourceHeight: 1080,
        viewportWidth: 3840,
        viewportHeight: 2160,
        fit: BoxFit.contain,
      );

      expect(output, isNull);
    });
  });
}
