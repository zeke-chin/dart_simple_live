import 'package:simple_live_app/modules/live_room/player/player_resource_usage.dart';

/// 超分后端。Windows 使用 RTX VSR；Apple 平台使用 MetalFX Spatial。
enum SuperResolutionBackend {
  nvidiaRtxVsr,
  appleMetalFxSpatial,
}

extension SuperResolutionBackendLabel on SuperResolutionBackend {
  String get label => switch (this) {
        SuperResolutionBackend.nvidiaRtxVsr => 'RTX VSR',
        SuperResolutionBackend.appleMetalFxSpatial => 'MetalFX Spatial',
      };
}

class SuperResolutionStats {
  final SuperResolutionBackend backend;
  final bool enabled;
  final bool active;
  final int? outputWidth;
  final int? outputHeight;
  final double? scale;
  final double? latencyMs;

  const SuperResolutionStats({
    required this.backend,
    required this.enabled,
    required this.active,
    this.outputWidth,
    this.outputHeight,
    this.scale,
    this.latencyMs,
  });

  String get name => backend.label;
}

class PlayerVideoStats {
  final int? sourceWidth;
  final int? sourceHeight;
  final double? bitrateBps;
  final double? fps;
  final String? hwdec;
  final SuperResolutionStats? superResolution;
  final PlayerResourceUsage? resourceUsage;

  const PlayerVideoStats({
    this.sourceWidth,
    this.sourceHeight,
    this.bitrateBps,
    this.fps,
    this.hwdec,
    this.superResolution,
    this.resourceUsage,
  });

  bool get hasSource => (sourceWidth ?? 0) > 0 && (sourceHeight ?? 0) > 0;

  String get sourceLabel => 'SRC';

  String get sourceValues {
    final parts = <String>[
      formatResolution(sourceWidth, sourceHeight),
      formatBitrate(bitrateBps),
      formatFps(fps),
    ];
    final decoder = hwdec?.trim();
    if (decoder != null && decoder.isNotEmpty && decoder != 'no') {
      parts.add(decoder);
    }
    return parts.join('   ');
  }

  String? get superResolutionLabel {
    final sr = superResolution;
    if (sr == null || !sr.enabled) {
      return null;
    }
    return 'SR';
  }

  String? get superResolutionValues {
    final sr = superResolution;
    if (sr == null || !sr.enabled) {
      return null;
    }
    final parts = <String>[
      sr.active ? formatResolution(sr.outputWidth, sr.outputHeight) : '--',
      sr.name,
    ];
    final scale = formatScale(sr.scale);
    if (scale.isNotEmpty) {
      parts.add(scale);
    }
    final latency = formatLatency(sr.latencyMs);
    if (latency.isNotEmpty) {
      parts.add(latency);
    }
    return parts.join('   ');
  }

  String? get resourceUsageLabel => resourceUsage == null ? null : 'RES';

  String? get resourceUsageValues => resourceUsage?.values;
}

int? parseMpInt(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return int.tryParse(value) ?? double.tryParse(value)?.round();
}

double? parseMpDouble(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return double.tryParse(value);
}

String formatResolution(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return '--';
  }
  return '$width×$height';
}

String formatBitrate(double? bitsPerSecond) {
  if (bitsPerSecond == null || bitsPerSecond <= 0) {
    return '--';
  }
  if (bitsPerSecond >= 1000 * 1000) {
    return '${(bitsPerSecond / (1000 * 1000)).toStringAsFixed(1)} Mbps';
  }
  if (bitsPerSecond >= 1000) {
    return '${(bitsPerSecond / 1000).toStringAsFixed(0)} kbps';
  }
  return '${bitsPerSecond.toStringAsFixed(0)} bps';
}

String formatFps(double? fps) {
  if (fps == null || fps <= 0) {
    return '--';
  }
  if ((fps - fps.round()).abs() < 0.05) {
    return '${fps.round()} fps';
  }
  return '${fps.toStringAsFixed(1)} fps';
}

String formatScale(double? scale) {
  if (scale == null || scale <= 0) {
    return '';
  }
  return '${scale.toStringAsFixed(2)}×';
}

String formatLatency(double? latencyMs) {
  if (latencyMs == null || latencyMs < 0) {
    return '';
  }
  if (latencyMs < 10) {
    return '${latencyMs.toStringAsFixed(1)} ms';
  }
  return '${latencyMs.toStringAsFixed(0)} ms';
}

SuperResolutionStats? nvidiaRtxVsrStats({
  required bool enabled,
  int? outputWidth,
  int? outputHeight,
  double? scale,
}) {
  if (!enabled) {
    return null;
  }
  return SuperResolutionStats(
    backend: SuperResolutionBackend.nvidiaRtxVsr,
    enabled: true,
    active: (outputWidth ?? 0) > 0 && (outputHeight ?? 0) > 0,
    outputWidth: outputWidth,
    outputHeight: outputHeight,
    scale: scale,
  );
}

SuperResolutionStats? appleMetalFxSpatialStats({
  bool enabled = false,
  bool active = false,
  int? outputWidth,
  int? outputHeight,
  double? scale,
}) {
  if (!enabled) {
    return null;
  }
  return SuperResolutionStats(
    backend: SuperResolutionBackend.appleMetalFxSpatial,
    enabled: true,
    active: active && (outputWidth ?? 0) > 0 && (outputHeight ?? 0) > 0,
    outputWidth: outputWidth,
    outputHeight: outputHeight,
    scale: scale,
  );
}

PlayerVideoStats playerVideoStatsFromMpv({
  required String decWidth,
  required String decHeight,
  required String packetBitrate,
  required String videoBitrate,
  required String estimatedFps,
  required String containerFps,
  required String hwdec,
  SuperResolutionStats? superResolution,
  PlayerResourceUsage? resourceUsage,
}) {
  return PlayerVideoStats(
    sourceWidth: parseMpInt(decWidth),
    sourceHeight: parseMpInt(decHeight),
    bitrateBps: parseMpDouble(packetBitrate) ?? parseMpDouble(videoBitrate),
    fps: parseMpDouble(estimatedFps) ?? parseMpDouble(containerFps),
    hwdec: hwdec.trim().isEmpty ? null : hwdec.trim(),
    superResolution: superResolution,
    resourceUsage: resourceUsage,
  );
}
