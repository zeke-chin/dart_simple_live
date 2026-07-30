import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_shield/danmu_shield_list_view.dart';

class DanmuShieldPage extends GetView<DanmuShieldController> {
  const DanmuShieldPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("弹幕屏蔽"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          TextField(
            controller: controller.textEditingController,
            decoration: InputDecoration(
              contentPadding: AppStyle.edgeInsetsH12,
              border: const OutlineInputBorder(),
              hintText: "请输入关键词或正则表达式",
              suffixIcon: TextButton.icon(
                onPressed: controller.add,
                icon: const Icon(Icons.add),
                label: const Text("添加"),
              ),
            ),
            onSubmitted: (e) {
              controller.add();
            },
          ),
          AppStyle.vGap4,
          Text(
            '以"/"开头和结尾将视作正则表达式, 如"/\\d+/"表示屏蔽所有数字',
            style: Get.textTheme.bodySmall,
          ),
          AppStyle.vGap12,
          DanmuShieldListView(
            controller: controller.settingsController,
          ),
        ],
      ),
    );
  }
}
