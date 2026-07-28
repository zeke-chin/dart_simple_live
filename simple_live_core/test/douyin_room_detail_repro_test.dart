import 'dart:io';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:test/test.dart';

void main() {
  const roomId = '252280097841';

  CoreLog.enableLog = true;
  CoreLog.requestLogType = RequestLogType.short;
  final skipLiveTests = Platform.environment['RUN_DOUYIN_LIVE_TESTS'] != 'true';

  test('loads the room through the HTML fallback', () async {
    final site = DouyinSite();
    final forceApiFailure = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/webcast/room/web/enter/')) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'forced API failure for fallback test',
            ),
          );
          return;
        }
        handler.next(options);
      },
    );
    HttpClient.instance.dio.interceptors.insert(0, forceApiFailure);

    try {
      final detail = await site.getRoomDetail(roomId: roomId);
      expect(detail.roomId, roomId);
      expect(detail.userName, isNotEmpty);
      expect((detail.danmakuData as DouyinDanmakuArgs).userId, isNotEmpty);
    } finally {
      HttpClient.instance.dio.interceptors.remove(forceApiFailure);
    }
  }, skip: skipLiveTests);

  test(
    'reproduce Douyin room detail from followed room',
    () async {
      final site = DouyinSite();

      for (var attempt = 1; attempt <= 5; attempt++) {
        print('[repro] attempt=$attempt roomId=$roomId');
        final detail = await site.getRoomDetail(roomId: roomId);
        print(
          '[repro] attempt=$attempt status=${detail.status} '
          'resolvedRoomId=${detail.roomId} user=${detail.userName}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: skipLiveTests,
  );

  test(
    'handles concurrent follow-style room loads',
    () async {
      final site = DouyinSite();
      final details = await Future.wait(
        List.generate(20, (_) => site.getRoomDetail(roomId: roomId)),
      );

      expect(details, hasLength(20));
      expect(details.every((detail) => detail.roomId == roomId), isTrue);
      expect(details.every((detail) => detail.userName.isNotEmpty), isTrue);
      expect(
        details.every(
          (detail) =>
              (detail.danmakuData as DouyinDanmakuArgs).userId.isNotEmpty,
        ),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: skipLiveTests,
  );
}
