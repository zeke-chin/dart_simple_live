import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';

class _RedirectParseController extends ParseController {
  @override
  Future<String> getLocation(String url) async =>
      'https://www.douyin.com/follow/live/55565871642?anchor_id=99415882732555';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ParseController controller;
  setUp(() => controller = ParseController());
  tearDown(() {
    controller.roomJumpToController.dispose();
    controller.getUrlController.dispose();
  });

  const links = [
    'https://www.douyin.com/follow/live/55565871642?anchor_id=99415882732555',
    'https://live.douyin.com/55565871642?anchor_id=99415882732555',
    'https://www.douyin.com/follow/live/55565871642',
    'https://live.douyin.com/55565871642',
    'https://www.douyin.com/follow/live/55565871642/?anchor_id=99415882732555',
    'https://www.douyin.com/follow/live/55565871642#live',
    '来看看这个直播间 https://www.douyin.com/follow/live/55565871642?anchor_id=99415882732555 一起看直播',
  ];
  for (final link in links) {
    test('提取抖音 webRid，忽略查询参数：$link', () async {
      expect(await controller.parse(link), [
        '55565871642',
        Sites.allSites[Constant.kDouyin],
      ]);
    });
  }

  test('短链接重定向到关注列表后仍可解析', () async {
    final redirectController = _RedirectParseController();
    addTearDown(() {
      redirectController.roomJumpToController.dispose();
      redirectController.getUrlController.dispose();
    });
    expect(await redirectController.parse('https://v.douyin.com/abc123/'), [
      '55565871642',
      Sites.allSites[Constant.kDouyin],
    ]);
  });

  for (final link in [
    'https://www.douyin.com/follow/live/',
    'https://www.douyin.com/follow/live/?anchor_id=99415882732555',
    'https://www.douyin.com/follow/live/555abc',
    'https://www.douyin.com/follow',
  ]) {
    test('缺少有效房间号时不把 anchor_id 或路径当成房间号：$link', () async {
      expect(await controller.parse(link), isEmpty);
    });
  }
}
