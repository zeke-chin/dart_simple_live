import 'dart:math' as math;

import 'package:flutter/painting.dart';

class RtxVsrOutput {
  final double? preScale;
  final double scale;
  final int width;
  final int height;

  const RtxVsrOutput({
    this.preScale,
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
  final minimumScale = math.max(2 / sourceWidth, 2 / sourceHeight);
  final scale = double.parse(
    requestedScale.clamp(minimumScale, 2.0).toStringAsFixed(4),
  );

  if (scale <= 1.0) {
    const windowVsrScale = 1.1;
    final preScale = double.parse(
      (scale / windowVsrScale).toStringAsFixed(4),
    );
    final preWidth = _scaledEvenDimension(sourceWidth, preScale);
    final preHeight = _scaledEvenDimension(sourceHeight, preScale);

    return RtxVsrOutput(
      preScale: preScale,
      scale: windowVsrScale,
      width: _scaledEvenDimension(preWidth, windowVsrScale),
      height: _scaledEvenDimension(preHeight, windowVsrScale),
    );
  }

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
