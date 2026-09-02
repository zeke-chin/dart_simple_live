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
      'simple_live_metal_fx_test_',
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

  test('MetalFX defaults to disabled and persists changes', () async {
    expect(controller.metalFxSpatial.value, isFalse);

    controller.setMetalFxSpatial(true);
    await Get.delete<AppSettingsController>();
    final reloaded = Get.put(AppSettingsController());

    expect(reloaded.metalFxSpatial.value, isTrue);
    expect(
      storage.getValue(LocalStorageService.kMetalFxSpatial, false),
      isTrue,
    );
  });

  test('MetalFX and custom player output are mutually exclusive', () {
    controller.setMetalFxSpatial(true);
    controller.setCustomPlayerOutput(true);

    expect(controller.customPlayerOutput.value, isTrue);
    expect(controller.metalFxSpatial.value, isFalse);

    controller.setMetalFxSpatial(true);

    expect(controller.metalFxSpatial.value, isTrue);
    expect(controller.customPlayerOutput.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kCustomPlayerOutput, true),
      isFalse,
    );
  });

  test('existing custom player output wins during settings migration',
      () async {
    await Get.delete<AppSettingsController>();
    await storage.setValue(LocalStorageService.kMetalFxSpatial, true);
    await storage.setValue(LocalStorageService.kCustomPlayerOutput, true);

    final reloaded = Get.put(AppSettingsController());

    expect(reloaded.customPlayerOutput.value, isTrue);
    expect(reloaded.metalFxSpatial.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kMetalFxSpatial, true),
      isFalse,
    );
  });
}
