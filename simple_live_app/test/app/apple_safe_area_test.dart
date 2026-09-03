import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/apple_safe_area.dart';

void main() {
  test('native UIKit insets fill gaps in Flutter viewport metrics', () {
    const framework = EdgeInsets.fromLTRB(0, 25, 0, 35);
    const native = EdgeInsets.fromLTRB(0, 62, 0, 34);

    expect(
      mergeSafeAreaInsets(framework, native),
      const EdgeInsets.fromLTRB(0, 62, 0, 35),
    );
  });

  test('keeps the larger inset independently on every edge', () {
    const framework = EdgeInsets.fromLTRB(59, 0, 21, 20);
    const native = EdgeInsets.fromLTRB(62, 0, 62, 21);

    expect(
      mergeSafeAreaInsets(framework, native),
      const EdgeInsets.fromLTRB(62, 0, 62, 21),
    );
  });

  test('applies native UIKit insets to the app MediaQuery', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.fromLTRB(0, 25, 0, 35),
      viewPadding: EdgeInsets.fromLTRB(0, 25, 0, 35),
    );

    final resolved = resolveAppMediaQueryData(
      mediaQuery,
      applyAndroidWindowedModeWorkaround: false,
      nativeInsets: const EdgeInsets.fromLTRB(0, 62, 0, 34),
    );

    expect(resolved.viewPadding, const EdgeInsets.fromLTRB(0, 62, 0, 35));
    expect(resolved.padding, const EdgeInsets.fromLTRB(0, 62, 0, 35));
    expect(resolved.textScaler, const TextScaler.linear(1));
  });

  test('does not restore bottom padding while the keyboard covers it', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.fromLTRB(0, 25, 0, 0),
      viewPadding: EdgeInsets.fromLTRB(0, 25, 0, 35),
      viewInsets: EdgeInsets.only(bottom: 300),
    );

    final resolved = resolveAppMediaQueryData(
      mediaQuery,
      applyAndroidWindowedModeWorkaround: false,
      nativeInsets: const EdgeInsets.fromLTRB(0, 62, 0, 34),
    );

    expect(resolved.padding, const EdgeInsets.fromLTRB(0, 62, 0, 0));
  });

  test('limits the HyperOS workaround to Android', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.fromLTRB(0, 62, 0, 34),
      viewPadding: EdgeInsets.fromLTRB(0, 62, 0, 34),
    );

    final iosResult = resolveAppMediaQueryData(
      mediaQuery,
      applyAndroidWindowedModeWorkaround: false,
      nativeInsets: const EdgeInsets.fromLTRB(0, 62, 0, 34),
    );
    final androidResult = resolveAppMediaQueryData(
      mediaQuery,
      applyAndroidWindowedModeWorkaround: true,
    );

    expect(iosResult.viewPadding.top, 62);
    expect(
      androidResult.viewPadding,
      const EdgeInsets.only(top: 25, bottom: 35),
    );
  });
}
