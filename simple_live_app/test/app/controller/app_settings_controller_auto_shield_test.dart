import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

void main() {
  late Directory storageDirectory;
  late LocalStorageService storage;
  late AppSettingsController controller;

  setUp(() async {
    Get.testMode = true;
    storageDirectory = await Directory.systemTemp.createTemp(
      'simple_live_auto_shield_test_',
    );
    Hive.init(storageDirectory.path);
    storage = Get.put(LocalStorageService());
    await storage.init();
    controller = Get.put(AppSettingsController());
  });

  tearDown(() async {
    await Hive.close();
    Get.reset();
    await storageDirectory.delete(recursive: true);
  });

  test('persists automatically added and permanently ignored danmaku',
      () async {
    controller.addAutoShield(' 自动屏蔽 ');
    controller.ignoreAutoShield('永不加入');
    await Future<void>.delayed(Duration.zero);

    expect(controller.shieldList, contains('自动屏蔽'));
    expect(controller.autoShieldList, contains('自动屏蔽'));
    expect(controller.exactShieldList, contains('自动屏蔽'));
    expect(controller.autoShieldIgnoreList, contains('永不加入'));
    expect(storage.shieldBox.get('自动屏蔽'), '自动屏蔽');

    await Get.delete<AppSettingsController>();
    final reloaded = Get.put(AppSettingsController());

    expect(reloaded.shieldList, contains('自动屏蔽'));
    expect(reloaded.autoShieldList, contains('自动屏蔽'));
    expect(reloaded.exactShieldList, contains('自动屏蔽'));
    expect(reloaded.autoShieldIgnoreList, contains('永不加入'));
  });

  test('manual exact shield persists separately from contains keywords', () async {
    controller.addExactShield(' 全匹配弹幕 ');
    controller.addShieldList('包含关键词');
    await Future<void>.delayed(Duration.zero);

    expect(controller.exactShieldList, contains('全匹配弹幕'));
    expect(controller.shieldList, contains('全匹配弹幕'));
    expect(controller.shieldList, contains('包含关键词'));
    expect(controller.autoShieldList, isNot(contains('全匹配弹幕')));

    controller.removeShieldList('全匹配弹幕');
    await Future<void>.delayed(Duration.zero);

    expect(controller.exactShieldList, isNot(contains('全匹配弹幕')));
    expect(controller.shieldList, isNot(contains('全匹配弹幕')));
    expect(controller.shieldList, contains('包含关键词'));
  });

  test('manual changes keep automatic categories consistent', () async {
    controller.ignoreAutoShield('稍后手动屏蔽');
    controller.addShieldList('稍后手动屏蔽');
    controller.addAutoShield('自动屏蔽');
    await Future<void>.delayed(Duration.zero);

    expect(controller.autoShieldIgnoreList, isNot(contains('稍后手动屏蔽')));

    controller.removeShieldList('自动屏蔽');
    await Future<void>.delayed(Duration.zero);

    expect(controller.shieldList, isNot(contains('自动屏蔽')));
    expect(controller.autoShieldList, isNot(contains('自动屏蔽')));
    expect(storage.shieldBox.containsKey('自动屏蔽'), isFalse);
  });
}
