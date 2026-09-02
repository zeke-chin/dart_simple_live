import 'dart:math' as math;

import 'package:flutter/painting.dart';

class MetalFxSpatialOutput {
  final double scale;
  final int width;
  final int height;

  const MetalFxSpatialOutput({
    required this.scale,
    required this.width,
    required this.height,
  });
}

MetalFxSpatialOutput? calculateMetalFxSpatialOutput({
  required int sourceWidth,
  required int sourceHeight,
  required int viewportWidth,
  required int viewportHeight,
  required BoxFit fit,
  double maximumScale = 2.0,
}) {
  if (sourceWidth <= 0 ||
      sourceHeight <= 0 ||
      viewportWidth <= 0 ||
      viewportHeight <= 0 ||
      maximumScale <= 1.0) {
    return null;
  }

  final widthScale = viewportWidth / sourceWidth;
  final heightScale = viewportHeight / sourceHeight;
  final requestedScale = switch (fit) {
    BoxFit.contain || BoxFit.fill => math.min(widthScale, heightScale),
    BoxFit.cover => math.max(widthScale, heightScale),
    BoxFit.fitWidth => widthScale,
    BoxFit.fitHeight => heightScale,
    BoxFit.none || BoxFit.scaleDown => 1.0,
  };
  final scale = math.min(requestedScale, maximumScale);
  if (scale <= 1.0) {
    return null;
  }

  final width = (sourceWidth * scale).round();
  final height = (sourceHeight * scale).round();
  if (width <= sourceWidth || height <= sourceHeight) {
    return null;
  }

  return MetalFxSpatialOutput(
    scale: scale,
    width: width,
    height: height,
  );
}
