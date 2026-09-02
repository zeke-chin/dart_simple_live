import 'dart:math' as math;

import 'package:flutter/painting.dart';

class RtxVsrOutput {
  final double scale;
  final int width;
  final int height;

  const RtxVsrOutput({
    required this.scale,
    required this.width,
    required this.height,
  });
}

RtxVsrOutput? calculateRtxVsrOutput({
  required int sourceWidth,
  required int sourceHeight,
  required int viewportWidth,
  required int viewportHeight,
  required BoxFit fit,
}) {
  if (sourceWidth <= 0 ||
      sourceHeight <= 0 ||
      viewportWidth <= 0 ||
      viewportHeight <= 0) {
    return null;
  }

  final widthScale = viewportWidth / sourceWidth;
  final heightScale = viewportHeight / sourceHeight;
  final requestedScale = switch (fit) {
    BoxFit.contain || BoxFit.fill => math.min(widthScale, heightScale),
    BoxFit.cover => math.max(widthScale, heightScale),
    BoxFit.fitWidth => widthScale,
    BoxFit.fitHeight => heightScale,
    BoxFit.none => 1.0,
    BoxFit.scaleDown => math.min(1.0, math.min(widthScale, heightScale)),
  };
  final scale = double.parse(
    requestedScale.clamp(1.0, 2.0).toStringAsFixed(4),
  );

  return RtxVsrOutput(
    scale: scale,
    width: _scaledEvenDimension(sourceWidth, scale),
    height: _scaledEvenDimension(sourceHeight, scale),
  );
}

int _scaledEvenDimension(int value, double scale) {
  final scaled = (value * scale).truncate();
  return scaled.isEven ? scaled : scaled + 1;
}
