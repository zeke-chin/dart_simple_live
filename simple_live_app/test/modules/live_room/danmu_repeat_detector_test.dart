import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/danmu_repeat_detector.dart';

void main() {
  group('DanmuRepeatDetector', () {
    test(
        'triggers when the same danmaku appears five times within five seconds',
        () {
      final detector = DanmuRepeatDetector();
      final start = DateTime(2026);

      for (var i = 0; i < 4; i++) {
        expect(
          detector.add('重复弹幕', now: start.add(Duration(seconds: i))),
          isNull,
        );
      }

      expect(
        detector.add('重复弹幕', now: start.add(const Duration(seconds: 4))),
        '重复弹幕',
      );
    });

    test('does not count occurrences outside the time window', () {
      final detector = DanmuRepeatDetector();
      final start = DateTime(2026);

      for (var i = 0; i < 4; i++) {
        detector.add('重复弹幕', now: start.add(Duration(seconds: i)));
      }

      expect(
        detector.add('重复弹幕', now: start.add(const Duration(seconds: 9))),
        isNull,
      );
    });

    test('only triggers once during a continuous burst', () {
      final detector = DanmuRepeatDetector();
      final start = DateTime(2026);

      for (var i = 0; i < 5; i++) {
        detector.add('重复弹幕', now: start.add(Duration(milliseconds: i * 500)));
      }

      for (var i = 5; i < 15; i++) {
        expect(
          detector.add(
            '重复弹幕',
            now: start.add(Duration(milliseconds: i * 500)),
          ),
          isNull,
        );
      }
    });

    test('can trigger again after the previous burst stops', () {
      final detector = DanmuRepeatDetector();
      final start = DateTime(2026);

      for (var i = 0; i < 5; i++) {
        detector.add('重复弹幕', now: start.add(Duration(milliseconds: i * 500)));
      }

      final secondBurst = start.add(const Duration(seconds: 10));
      for (var i = 0; i < 4; i++) {
        expect(
          detector.add(
            '重复弹幕',
            now: secondBurst.add(Duration(milliseconds: i * 500)),
          ),
          isNull,
        );
      }
      expect(
        detector.add(
          '重复弹幕',
          now: secondBurst.add(const Duration(seconds: 2)),
        ),
        '重复弹幕',
      );
    });
  });
}
