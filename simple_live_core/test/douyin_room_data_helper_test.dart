import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/douyin_room_data_helper.dart';
import 'package:test/test.dart';

void main() {
  group('readDouyinUserUniqueId', () {
    test('reads the id from the full HTML state', () {
      final roomData = {
        'userStore': {
          'odin': {'user_unique_id': '123456789012'},
        },
      };

      expect(readDouyinUserUniqueId(roomData), '123456789012');
    });

    test('returns null when userStore is absent', () {
      expect(readDouyinUserUniqueId({'roomStore': {}}), isNull);
    });

    test('returns null when odin is absent', () {
      expect(
        readDouyinUserUniqueId({
          'userStore': {'userInfo': {}},
        }),
        isNull,
      );
    });

    test('returns null when the id is empty', () {
      expect(
        readDouyinUserUniqueId({
          'userStore': {
            'odin': {'user_unique_id': ''},
          },
        }),
        isNull,
      );
    });
  });

  test(
    'Douyin request headers are isolated between concurrent rooms',
    () async {
      final site = DouyinSite();
      final firstRoomHeaders = await site.getRequestHeaders();
      firstRoomHeaders['Referer'] = 'https://live.douyin.com/room-a';

      final secondRoomHeaders = await site.getRequestHeaders();

      expect(identical(firstRoomHeaders, secondRoomHeaders), isFalse);
      expect(secondRoomHeaders['Referer'], DouyinSite.kDefaultReferer);
    },
  );
}
