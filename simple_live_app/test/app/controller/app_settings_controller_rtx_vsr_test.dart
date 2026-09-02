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
      'simple_live_rtx_vsr_test_',
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

  test('RTX VSR defaults to enabled and persists changes', () async {
    expect(controller.rtxVsr.value, isTrue);

    controller.setRtxVsr(false);
    await Get.delete<AppSettingsController>();
    final reloaded = Get.put(AppSettingsController());

    expect(reloaded.rtxVsr.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kRtxVsr, true),
      isFalse,
    );
  });

  test('RTX VSR and custom player output are mutually exclusive', () {
    controller.setCustomPlayerOutput(true);

    expect(controller.customPlayerOutput.value, isTrue);
    expect(controller.rtxVsr.value, isFalse);

    controller.setRtxVsr(true);

    expect(controller.rtxVsr.value, isTrue);
    expect(controller.customPlayerOutput.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kCustomPlayerOutput, true),
      isFalse,
    );
  });

  test('existing custom player output wins during settings migration',
      () async {
    await Get.delete<AppSettingsController>();
    await storage.setValue(LocalStorageService.kRtxVsr, true);
    await storage.setValue(LocalStorageService.kCustomPlayerOutput, true);

    final reloaded = Get.put(AppSettingsController());

    expect(reloaded.customPlayerOutput.value, isTrue);
    expect(reloaded.rtxVsr.value, isFalse);
    expect(
      storage.getValue(LocalStorageService.kRtxVsr, true),
      isFalse,
    );
  });
}
