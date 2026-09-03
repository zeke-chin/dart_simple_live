import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_safe_area.dart';

void main() {
  test('fullscreen keeps display cutout insets after system UI is hidden', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.fromLTRB(59, 0, 21, 21),
    );

    expect(
      resolvePlayerSafeAreaPadding(mediaQuery, fullScreen: true),
      mediaQuery.viewPadding,
    );
  });

  test('fullscreen prefers the larger native UIKit safe area', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.fromLTRB(0, 25, 0, 20),
    );

    expect(
      resolvePlayerSafeAreaPadding(
        mediaQuery,
        fullScreen: true,
        nativeInsets: const EdgeInsets.fromLTRB(62, 0, 62, 21),
      ),
      const EdgeInsets.fromLTRB(62, 25, 62, 21),
    );
  });

  test('embedded player does not apply the page safe area twice', () {
    const mediaQuery = MediaQueryData(
      padding: EdgeInsets.fromLTRB(0, 47, 0, 34),
      viewPadding: EdgeInsets.fromLTRB(0, 47, 0, 34),
    );

    expect(
      resolvePlayerSafeAreaPadding(mediaQuery, fullScreen: false),
      EdgeInsets.zero,
    );
  });
}
