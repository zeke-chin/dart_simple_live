import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerResourceUsage {
  final double? cpuPercent;
  final double? metalFxGpuPercent;
  final int memoryBytes;
  final double? downloadBytesPerSecond;
  final double? uploadBytesPerSecond;

  const PlayerResourceUsage({
    this.cpuPercent,
    this.metalFxGpuPercent,
    required this.memoryBytes,
    this.downloadBytesPerSecond,
    this.uploadBytesPerSecond,
  });

  String get values => [
        'CPU ${formatUsagePercent(cpuPercent)}',
        'MFX GPU ${formatUsagePercent(metalFxGpuPercent)}',
        'MEM ${formatMemorySize(memoryBytes)}',
        'NET ↓${formatTransferRate(downloadBytesPerSecond)} '
            '↑${formatTransferRate(uploadBytesPerSecond)}',
      ].join('   ');
}

class PlayerResourceCounters {
  final int elapsedMicroseconds;
  final int cpuTimeMicroseconds;
  final int memoryBytes;
  final int networkReceiveBytes;
  final int networkTransmitBytes;
  final double? metalFxGpuMilliseconds;

  const PlayerResourceCounters({
    required this.elapsedMicroseconds,
    required this.cpuTimeMicroseconds,
    required this.memoryBytes,
    required this.networkReceiveBytes,
    required this.networkTransmitBytes,
    this.metalFxGpuMilliseconds,
  });
}

PlayerResourceUsage calculatePlayerResourceUsage({
  PlayerResourceCounters? previous,
  required PlayerResourceCounters current,
}) {
  if (previous == null) {
    return PlayerResourceUsage(memoryBytes: current.memoryBytes);
  }

  final elapsedMicroseconds =
      current.elapsedMicroseconds - previous.elapsedMicroseconds;
  if (elapsedMicroseconds <= 0) {
    return PlayerResourceUsage(memoryBytes: current.memoryBytes);
  }

  final elapsedSeconds = elapsedMicroseconds / Duration.microsecondsPerSecond;
  final cpuDelta = current.cpuTimeMicroseconds - previous.cpuTimeMicroseconds;
  final receiveDelta =
      current.networkReceiveBytes - previous.networkReceiveBytes;
  final transmitDelta =
      current.networkTransmitBytes - previous.networkTransmitBytes;
  final currentGpu = current.metalFxGpuMilliseconds;
  final previousGpu = previous.metalFxGpuMilliseconds;
  final gpuDelta = currentGpu != null && previousGpu != null
      ? currentGpu - previousGpu
      : null;

  return PlayerResourceUsage(
    cpuPercent: cpuDelta >= 0 ? cpuDelta / elapsedMicroseconds * 100 : null,
    metalFxGpuPercent: gpuDelta != null && gpuDelta >= 0
        ? (gpuDelta / (elapsedSeconds * 1000) * 100).clamp(0, 100)
        : null,
    memoryBytes: current.memoryBytes,
    downloadBytesPerSecond:
        receiveDelta >= 0 ? receiveDelta / elapsedSeconds : null,
    uploadBytesPerSecond:
        transmitDelta >= 0 ? transmitDelta / elapsedSeconds : null,
  );
}

String formatUsagePercent(double? percent) {
  if (percent == null || !percent.isFinite || percent < 0) {
    return '--';
  }
  if (percent >= 100) {
    return '${percent.toStringAsFixed(0)}%';
  }
  return '${percent.toStringAsFixed(1)}%';
}

String formatMemorySize(int bytes) {
  if (bytes <= 0) {
    return '--';
  }
  const gibibyte = 1024 * 1024 * 1024;
  const mebibyte = 1024 * 1024;
  if (bytes >= gibibyte) {
    return '${(bytes / gibibyte).toStringAsFixed(2)} GB';
  }
  return '${(bytes / mebibyte).toStringAsFixed(0)} MB';
}

String formatTransferRate(double? bytesPerSecond) {
  if (bytesPerSecond == null ||
      !bytesPerSecond.isFinite ||
      bytesPerSecond < 0) {
    return '--';
  }
  const mebibyte = 1024 * 1024;
  const kibibyte = 1024;
  if (bytesPerSecond >= mebibyte) {
    return '${(bytesPerSecond / mebibyte).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= kibibyte) {
    return '${(bytesPerSecond / kibibyte).toStringAsFixed(0)} KB/s';
  }
  return '${bytesPerSecond.toStringAsFixed(0)} B/s';
}

class PlayerResourceUsageSampler {
  static const _channel = MethodChannel('com.xycz.simple-live/resource_usage');

  final Stopwatch _clock = Stopwatch()..start();
  PlayerResourceCounters? _previous;

  Future<PlayerResourceUsage?> sample(VideoController videoController) async {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return null;
    }

    try {
      final values = await Future.wait<Object?>([
        _channel.invokeMethod<Map<Object?, Object?>>('sample'),
        videoController.getMetalFxSpatialMetrics(),
      ]);
      final native = values[0] as Map<Object?, Object?>?;
      final metalFx = values[1] as MetalFxSpatialMetrics?;
      if (native == null) {
        return null;
      }

      final current = PlayerResourceCounters(
        elapsedMicroseconds: _clock.elapsedMicroseconds,
        cpuTimeMicroseconds:
            (native['cpuTimeMicroseconds'] as num?)?.toInt() ?? 0,
        memoryBytes: ProcessInfo.currentRss,
        networkReceiveBytes:
            (native['networkReceiveBytes'] as num?)?.toInt() ?? 0,
        networkTransmitBytes:
            (native['networkTransmitBytes'] as num?)?.toInt() ?? 0,
        metalFxGpuMilliseconds: metalFx?.totalGpuMilliseconds,
      );
      final usage = calculatePlayerResourceUsage(
        previous: _previous,
        current: current,
      );
      _previous = current;
      return usage;
    } catch (error, stackTrace) {
      debugPrint('Failed to sample Apple resource usage: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  void reset() {
    _previous = null;
    _clock.reset();
  }
}
