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
      'simple_live_shield_test_',
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

  test('manual exact shield persists separately from contains keywords',
      () async {
    controller.addExactShield(' 全匹配弹幕 ');
    controller.addShieldList('包含关键词');
    await Future<void>.delayed(Duration.zero);

    expect(controller.exactShieldList, contains('全匹配弹幕'));
    expect(controller.shieldList, contains('全匹配弹幕'));
    expect(controller.shieldList, contains('包含关键词'));

    controller.removeShieldList('全匹配弹幕');
    await Future<void>.delayed(Duration.zero);

    expect(controller.exactShieldList, isNot(contains('全匹配弹幕')));
    expect(controller.shieldList, isNot(contains('全匹配弹幕')));
    expect(controller.shieldList, contains('包含关键词'));
  });

  test('migrates leftover automatic shield words into exact matches', () async {
    await storage.setValue(
      LocalStorageService.kAutoDanmuShieldList,
      <String>['自动屏蔽'],
    );
    await storage.setValue(
      LocalStorageService.kAutoDanmuShieldIgnoreList,
      <String>['永不加入'],
    );

    await Get.delete<AppSettingsController>();
    final reloaded = Get.put(AppSettingsController());
    await Future<void>.delayed(Duration.zero);

    expect(reloaded.exactShieldList, contains('自动屏蔽'));
    expect(reloaded.shieldList, contains('自动屏蔽'));
    expect(
      storage.getValue<List<dynamic>>(
        LocalStorageService.kAutoDanmuShieldList,
        <dynamic>[],
      ),
      isEmpty,
    );
    expect(
      storage.getValue<List<dynamic>>(
        LocalStorageService.kAutoDanmuShieldIgnoreList,
        <dynamic>[],
      ),
      isEmpty,
    );
  });
}
