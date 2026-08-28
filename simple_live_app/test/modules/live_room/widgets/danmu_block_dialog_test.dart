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

  testWidgets('select all confirms the full message as an exact match',
      (tester) async {
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

    expect(find.byType(RangeSlider), findsNothing);
    expect(find.text('请选择要屏蔽的文字'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '屏蔽'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('全选'));
    await tester.pump();

    expect(find.text('全匹配：只屏蔽完全相同的弹幕'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('请选择要屏蔽的文字'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pump();
    await tester.tap(find.text('屏蔽'));
    await tester.pumpAndSettle();

    expect(keyword, '关注主播谢谢');
    expect(isExact, isTrue);
  });
}
