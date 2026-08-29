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
      'simple_live_chat_settings_test_',
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

  test('chat show shielded danmu defaults to on and persists', () async {
    expect(controller.chatShowShieldedDanmu.value, isTrue);

    controller.setChatShowShieldedDanmu(false);
    await Future<void>.delayed(Duration.zero);

    expect(controller.chatShowShieldedDanmu.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kChatShowShieldedDanmu, true),
      isFalse,
    );

    await Get.delete<AppSettingsController>();
    final reloaded = Get.put(AppSettingsController());
    await Future<void>.delayed(Duration.zero);

    expect(reloaded.chatShowShieldedDanmu.value, isFalse);
  });
}
