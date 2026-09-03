import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

EdgeInsets mergeSafeAreaInsets(
  EdgeInsets frameworkInsets,
  EdgeInsets? nativeInsets,
) {
  if (nativeInsets == null) {
    return frameworkInsets;
  }
  return EdgeInsets.fromLTRB(
    frameworkInsets.left > nativeInsets.left
        ? frameworkInsets.left
        : nativeInsets.left,
    frameworkInsets.top > nativeInsets.top
        ? frameworkInsets.top
        : nativeInsets.top,
    frameworkInsets.right > nativeInsets.right
        ? frameworkInsets.right
        : nativeInsets.right,
    frameworkInsets.bottom > nativeInsets.bottom
        ? frameworkInsets.bottom
        : nativeInsets.bottom,
  );
}

MediaQueryData resolveAppMediaQueryData(
  MediaQueryData mediaQuery, {
  required bool applyAndroidWindowedModeWorkaround,
  EdgeInsets? nativeInsets,
}) {
  const fallbackPadding = EdgeInsets.only(top: 25, bottom: 35);
  const maxNormalAndroidPadding = 50.0;

  if (applyAndroidWindowedModeWorkaround &&
      mediaQuery.viewPadding.top > maxNormalAndroidPadding) {
    return mediaQuery.copyWith(
      viewPadding: fallbackPadding,
      padding: fallbackPadding,
      textScaler: const TextScaler.linear(1),
    );
  }

  if (nativeInsets == null) {
    return mediaQuery.copyWith(textScaler: const TextScaler.linear(1));
  }

  final viewPadding = mergeSafeAreaInsets(
    mediaQuery.viewPadding,
    nativeInsets,
  );
  final viewInsets = mediaQuery.viewInsets;
  final padding = EdgeInsets.fromLTRB(
    _nonNegativeDifference(viewPadding.left, viewInsets.left),
    _nonNegativeDifference(viewPadding.top, viewInsets.top),
    _nonNegativeDifference(viewPadding.right, viewInsets.right),
    _nonNegativeDifference(viewPadding.bottom, viewInsets.bottom),
  );
  return mediaQuery.copyWith(
    viewPadding: viewPadding,
    padding: padding,
    textScaler: const TextScaler.linear(1),
  );
}

double _nonNegativeDifference(double value, double inset) {
  final difference = value - inset;
  return difference > 0 ? difference : 0;
}

class AppleSafeAreaInsets {
  static const _channel = MethodChannel('com.xycz.simple-live/safe_area');
  static EdgeInsets? cached;

  static Future<EdgeInsets?> read() async {
    if (!Platform.isIOS) {
      return null;
    }
    try {
      final values = await _channel.invokeMapMethod<Object?, Object?>('insets');
      if (values == null) {
        return cached;
      }
      cached = EdgeInsets.fromLTRB(
        (values['left'] as num?)?.toDouble() ?? 0,
        (values['top'] as num?)?.toDouble() ?? 0,
        (values['right'] as num?)?.toDouble() ?? 0,
        (values['bottom'] as num?)?.toDouble() ?? 0,
      );
      return cached;
    } on PlatformException {
      return cached;
    } on MissingPluginException {
      return cached;
    }
  }
}

typedef AppleSafeAreaWidgetBuilder = Widget Function(
  BuildContext context,
  EdgeInsets? nativeInsets,
);

class AppleSafeAreaBuilder extends StatefulWidget {
  final AppleSafeAreaWidgetBuilder builder;

  const AppleSafeAreaBuilder({
    required this.builder,
    super.key,
  });

  @override
  State<AppleSafeAreaBuilder> createState() => _AppleSafeAreaBuilderState();
}

class _AppleSafeAreaBuilderState extends State<AppleSafeAreaBuilder>
    with WidgetsBindingObserver {
  EdgeInsets? _nativeInsets = AppleSafeAreaInsets.cached;
  Timer? _settledMetricsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeMetrics() {
    _refresh();
    _settledMetricsTimer?.cancel();
    _settledMetricsTimer = Timer(
      const Duration(milliseconds: 250),
      _refresh,
    );
  }

  Future<void> _refresh() async {
    final value = await AppleSafeAreaInsets.read();
    if (mounted && value != _nativeInsets) {
      setState(() => _nativeInsets = value);
    }
  }

  @override
  void dispose() {
    _settledMetricsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _nativeInsets);
  }
}
