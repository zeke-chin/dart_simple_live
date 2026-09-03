import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_resource_usage.dart';
import 'package:simple_live_app/modules/live_room/player/player_video_stats.dart';

void main() {
  group('formatters', () {
    test('formats bitrate in Mbps and kbps', () {
      expect(formatBitrate(2.4 * 1000 * 1000), '2.4 Mbps');
      expect(formatBitrate(800 * 1000), '800 kbps');
      expect(formatBitrate(null), '--');
    });

    test('formats resolution, fps, scale and latency', () {
      expect(formatResolution(1280, 720), '1280×720');
      expect(formatFps(25), '25 fps');
      expect(formatFps(29.97), '30 fps');
      expect(formatFps(23.5), '23.5 fps');
      expect(formatScale(1.5), '1.50×');
      expect(formatLatency(8.3), '8.3 ms');
      expect(formatLatency(16), '16 ms');
      expect(formatLatency(null), isEmpty);
    });
  });

  group('super resolution backends', () {
    test('nvidia stats are omitted when disabled', () {
      expect(
        nvidiaRtxVsrStats(
            enabled: false, outputWidth: 1920, outputHeight: 1080),
        isNull,
      );
    });

    test('nvidia stats stay generic and have no latency', () {
      final stats = nvidiaRtxVsrStats(
        enabled: true,
        outputWidth: 1920,
        outputHeight: 1080,
        scale: 1.5,
      );

      expect(stats?.backend, SuperResolutionBackend.nvidiaRtxVsr);
      expect(stats?.name, 'RTX VSR');
      expect(stats?.active, isTrue);
      expect(stats?.latencyMs, isNull);
    });

    test('apple stats describe active MetalFX Spatial output', () {
      final stats = appleMetalFxSpatialStats(
        enabled: true,
        active: true,
        outputWidth: 2560,
        outputHeight: 1440,
        scale: 2,
      );

      expect(stats?.backend, SuperResolutionBackend.appleMetalFxSpatial);
      expect(stats?.name, 'MetalFX Spatial');
      expect(stats?.active, isTrue);
      expect(stats?.latencyMs, isNull);
    });

    test('apple stats stay inactive before native output is ready', () {
      final stats = appleMetalFxSpatialStats(
        enabled: true,
        outputWidth: 2560,
        outputHeight: 1440,
        scale: 2,
      );

      expect(stats?.active, isFalse);
    });
  });

  group('overlay lines', () {
    test('source line is before super-resolution line', () {
      final stats = PlayerVideoStats(
        sourceWidth: 1280,
        sourceHeight: 720,
        bitrateBps: 2.4 * 1000 * 1000,
        fps: 25,
        hwdec: 'd3d11va',
        superResolution: nvidiaRtxVsrStats(
          enabled: true,
          outputWidth: 1920,
          outputHeight: 1080,
          scale: 1.5,
        ),
      );

      expect(stats.sourceLabel, 'SRC');
      expect(stats.sourceValues, '1280×720   2.4 Mbps   25 fps   d3d11va');
      expect(stats.superResolutionLabel, 'SR');
      expect(stats.superResolutionValues, '1920×1080   RTX VSR   1.50×');
    });

    test('hides super-resolution line when SR is off', () {
      const stats = PlayerVideoStats(
        sourceWidth: 1280,
        sourceHeight: 720,
        bitrateBps: 1200 * 1000,
        fps: 30,
      );

      expect(stats.superResolutionLabel, isNull);
      expect(stats.superResolutionValues, isNull);
    });

    test('apple line shows MetalFX Spatial output and scale', () {
      final stats = PlayerVideoStats(
        sourceWidth: 1280,
        sourceHeight: 720,
        superResolution: appleMetalFxSpatialStats(
          enabled: true,
          active: true,
          outputWidth: 2560,
          outputHeight: 1440,
          scale: 2,
        ),
      );

      expect(stats.superResolutionLabel, 'SR');
      expect(
        stats.superResolutionValues,
        '2560×1440   MetalFX Spatial   2.00×',
      );
    });

    test('resource usage is shown on a separate line', () {
      const stats = PlayerVideoStats(
        sourceWidth: 1920,
        sourceHeight: 1080,
        resourceUsage: PlayerResourceUsage(
          cpuPercent: 42.5,
          metalFxGpuPercent: 6.2,
          memoryBytes: 512 * 1024 * 1024,
          downloadBytesPerSecond: 5 * 1024 * 1024,
          uploadBytesPerSecond: 100 * 1024,
        ),
      );

      expect(stats.resourceUsageLabel, 'RES');
      expect(
        stats.resourceUsageValues,
        'CPU 42.5%   MFX GPU 6.2%   MEM 512 MB   '
        'NET ↓5.0 MB/s ↑100 KB/s',
      );
    });
  });

  test('parses mpv property strings', () {
    final stats = playerVideoStatsFromMpv(
      decWidth: '1280',
      decHeight: '720',
      packetBitrate: '2400000',
      videoBitrate: '',
      estimatedFps: '25.000000',
      containerFps: '25',
      hwdec: 'd3d11va',
      superResolution: nvidiaRtxVsrStats(
        enabled: true,
        outputWidth: 1920,
        outputHeight: 1080,
        scale: 1.5,
      ),
    );

    expect(stats.sourceWidth, 1280);
    expect(stats.bitrateBps, 2400000);
    expect(stats.fps, 25);
    expect(stats.superResolution?.outputWidth, 1920);
  });
}
