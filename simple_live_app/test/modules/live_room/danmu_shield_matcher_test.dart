import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmu_shield_matcher.dart';

void main() {
  const matcher = DanmuShieldMatcher();

  test('blocks exact messages only', () {
    expect(
      matcher.isBlocked(
        '666',
        keywords: const [],
        exactKeywords: {'666'},
      ),
      isTrue,
    );
    expect(
      matcher.isBlocked(
        '6666',
        keywords: const [],
        exactKeywords: {'666'},
      ),
      isFalse,
    );
    expect(
      matcher.isBlocked(
        ' 666 ',
        keywords: const [],
        exactKeywords: {'666'},
      ),
      isTrue,
    );
  });

  test('does not use exact keywords as substring filters', () {
    expect(
      matcher.isBlocked(
        '冲666',
        keywords: const ['666'],
        exactKeywords: {'666'},
      ),
      isFalse,
    );
  });

  test('blocks messages containing a keyword', () {
    expect(
      matcher.isBlocked(
        '加微信abc',
        keywords: const ['加微信'],
        exactKeywords: const {},
      ),
      isTrue,
    );
    expect(
      matcher.isBlocked(
        '普通弹幕',
        keywords: const ['加微信'],
        exactKeywords: const {},
      ),
      isFalse,
    );
  });

  test('blocks messages matching a regex keyword', () {
    expect(
      matcher.isBlocked(
        '12345',
        keywords: const [r'/\d+/'],
        exactKeywords: const {},
      ),
      isTrue,
    );
    expect(
      matcher.isBlocked(
        'hello',
        keywords: const [r'/\d+/'],
        exactKeywords: const {},
      ),
      isFalse,
    );
  });

  test('lists every keyword that matches a message', () {
    expect(
      matcher.matchedKeywords(
        '加微信abc123',
        keywords: const ['加微信', r'/\d+/', '普通'],
        exactKeywords: const {},
      ),
      ['加微信', r'/\d+/'],
    );
    expect(
      matcher.matchedKeywords(
        '666',
        keywords: const ['666'],
        exactKeywords: {'666'},
      ),
      ['666'],
    );
  });
}
