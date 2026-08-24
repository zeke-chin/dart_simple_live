import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/widgets/danmu_block_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    required String message,
    required void Function(String keyword, {required bool exact}) onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => DanmuBlockDialog(
                    userName: '测试用户',
                    message: message,
                    onConfirm: onConfirm,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirms the full message as an exact match', (tester) async {
    String? keyword;
    bool? isExact;

    await openDialog(
      tester,
      message: '关注主播谢谢',
      onConfirm: (value, {required bool exact}) {
        keyword = value;
        isExact = exact;
      },
    );

    expect(find.text('全匹配：只屏蔽完全相同的弹幕'), findsOneWidget);
    await tester.tap(find.text('屏蔽'));
    await tester.pumpAndSettle();

    expect(keyword, '关注主播谢谢');
    expect(isExact, isTrue);
  });

  testWidgets('sliding the range switches to contains matching', (tester) async {
    String? keyword;
    bool? isExact;

    await openDialog(
      tester,
      message: '加微信abc',
      onConfirm: (value, {required bool exact}) {
        keyword = value;
        isExact = exact;
      },
    );

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    slider.onChanged!(const RangeValues(0, 3));
    await tester.pump();

    expect(find.textContaining('包含：屏蔽所有含「加微信」的弹幕'), findsOneWidget);
    await tester.tap(find.text('屏蔽'));
    await tester.pumpAndSettle();

    expect(keyword, '加微信');
    expect(isExact, isFalse);
  });
}
