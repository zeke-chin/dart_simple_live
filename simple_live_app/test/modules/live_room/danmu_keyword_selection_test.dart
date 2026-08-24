import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmu_keyword_selection.dart';

void main() {
  test('defaults to the full message as an exact match', () {
    final selection = DanmuKeywordSelection('主播今天真好看');

    expect(selection.isExact, isTrue);
    expect(selection.keyword, '主播今天真好看');
    expect(selection.prefix, isEmpty);
    expect(selection.suffix, isEmpty);
  });

  test('a shorter range becomes a contains keyword', () {
    final selection = DanmuKeywordSelection('加微信abc123');
    selection.updateRange(0, 3);

    expect(selection.isExact, isFalse);
    expect(selection.keyword, '加微信');
    expect(selection.prefix, isEmpty);
    expect(selection.suffix, 'abc123');
  });

  test('counts emoji as a single character', () {
    final selection = DanmuKeywordSelection('👍666');
    expect(selection.length, 4);

    selection.updateRange(0, 1);
    expect(selection.keyword, '👍');
    expect(selection.suffix, '666');
  });

  test('keeps at least one character selected', () {
    final selection = DanmuKeywordSelection('弹幕');
    selection.updateRange(1, 1);

    expect(selection.keyword.length, 1);
    expect(selection.start < selection.end, isTrue);
  });
}
