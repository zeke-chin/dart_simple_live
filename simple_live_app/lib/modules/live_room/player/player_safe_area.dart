import 'package:flutter/widgets.dart';
import 'package:simple_live_app/app/apple_safe_area.dart';

EdgeInsets resolvePlayerSafeAreaPadding(
  MediaQueryData mediaQuery, {
  required bool fullScreen,
  EdgeInsets? nativeInsets,
}) {
  return fullScreen
      ? mergeSafeAreaInsets(mediaQuery.viewPadding, nativeInsets)
      : EdgeInsets.zero;
}
