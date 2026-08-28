import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmu_keyword_selection.dart';
import 'package:simple_live_app/modules/live_room/danmu_shield_matcher.dart';

void main() {
  test('defaults to no selection', () {
    final selection = DanmuKeywordSelection('主播今天真好看');

    expect(selection.hasSelection, isFalse);
    expect(selection.isExact, isFalse);
    expect(selection.keyword, isEmpty);
  });

  test('selectAll uses the original message as an exact match', () {
    final selection = DanmuKeywordSelection('主播今天真好看');
    selection.selectAll();

    expect(selection.isExact, isTrue);
    expect(selection.keyword, '主播今天真好看');
  });

  test('a shorter range becomes a contains keyword', () {
    final selection = DanmuKeywordSelection('加微信abc123');
    selection.addRange(0, 3);

    expect(selection.isExact, isFalse);
    expect(selection.isRegex, isFalse);
    expect(selection.keyword, '加微信');
  });

  test('counts emoji as a single character', () {
    final selection = DanmuKeywordSelection('👍666');
    expect(selection.length, 4);

    selection.addRange(0, 1);
    expect(selection.keyword, '👍');
  });

  test('builds an ordered regex from multiple ranges', () {
    final selection = DanmuKeywordSelection('abcdef');
    selection.addRange(4, 6);
    selection.addRange(1, 3);

    expect(selection.isRegex, isTrue);
    expect(selection.isExact, isFalse);
    expect(selection.keyword, '/bc.*ef/');
  });

  test('merges overlapping and adjacent ranges', () {
    final selection = DanmuKeywordSelection('abcdef');
    selection.addRange(1, 3);
    selection.addRange(2, 4);

    expect(selection.keyword, 'bcd');
    expect(selection.isRegex, isFalse);

    selection.addRange(4, 6);
    expect(selection.keyword, 'bcdef');
  });

  test('escapes regex metacharacters in segments', () {
    final selection = DanmuKeywordSelection('a.b+c');
    selection.addRange(0, 2);
    selection.addRange(3, 5);

    expect(selection.keyword, r'/a\..*\+c/');
  });

  test('removeRangeContaining drops that span', () {
    final selection = DanmuKeywordSelection('abcdef');
    selection.addRange(1, 3);
    selection.addRange(4, 6);
    selection.removeRangeContaining(1);

    expect(selection.keyword, 'ef');
    expect(selection.isRegex, isFalse);
  });

  test('multi-range keyword matches fragments in order', () {
    final selection = DanmuKeywordSelection('abcdef');
    selection.addRange(1, 3);
    selection.addRange(4, 6);
    const matcher = DanmuShieldMatcher();

    expect(
      matcher.isBlocked(
        'xxbcxxefxx',
        keywords: [selection.keyword],
        exactKeywords: const {},
      ),
      isTrue,
    );
    expect(
      matcher.isBlocked(
        'xxefxxbcxx',
        keywords: [selection.keyword],
        exactKeywords: const {},
      ),
      isFalse,
    );
  });
}
