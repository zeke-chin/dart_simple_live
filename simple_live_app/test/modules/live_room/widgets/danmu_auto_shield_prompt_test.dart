import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/widgets/danmu_auto_shield_prompt.dart';

void main() {
  Future<void> pumpPrompt(
    WidgetTester tester, {
    required VoidCallback onAccept,
    required VoidCallback onReject,
    required VoidCallback onIgnorePermanently,
    Duration countdown = const Duration(seconds: 5),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DanmuAutoShieldPrompt(
            key: UniqueKey(),
            message: '重复弹幕',
            countdown: countdown,
            onAccept: onAccept,
            onReject: onReject,
            onIgnorePermanently: onIgnorePermanently,
          ),
        ),
      ),
    );
  }

  testWidgets('accepts automatically when the countdown ends', (tester) async {
    var accepted = 0;
    await pumpPrompt(
      tester,
      countdown: const Duration(seconds: 2),
      onAccept: () => accepted += 1,
      onReject: () {},
      onIgnorePermanently: () {},
    );

    expect(find.text('同意（2s）'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('同意（1s）'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(accepted, 1);
  });

  testWidgets('exposes accept, reject and permanent ignore actions',
      (tester) async {
    var action = '';

    await pumpPrompt(
      tester,
      onAccept: () => action = 'accept',
      onReject: () => action = 'reject',
      onIgnorePermanently: () => action = 'ignore',
    );
    await tester.tap(find.text('拒绝'));
    expect(action, 'reject');

    await pumpPrompt(
      tester,
      onAccept: () => action = 'accept',
      onReject: () => action = 'reject',
      onIgnorePermanently: () => action = 'ignore',
    );
    await tester.tap(find.text('永不加入'));
    expect(action, 'ignore');

    await pumpPrompt(
      tester,
      onAccept: () => action = 'accept',
      onReject: () => action = 'reject',
      onIgnorePermanently: () => action = 'ignore',
    );
    await tester.tap(find.text('同意（5s）'));
    expect(action, 'accept');
  });
}
