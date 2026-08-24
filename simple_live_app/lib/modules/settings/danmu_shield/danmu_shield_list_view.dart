import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

class DanmuShieldListView extends StatelessWidget {
  const DanmuShieldListView({
    super.key,
    required this.controller,
  });

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final autoItems = controller.autoShieldList.toList()..sort();
      final autoItemSet = autoItems.toSet();
      final exactItems = controller.exactShieldList
          .where((item) => !autoItemSet.contains(item))
          .toList()
        ..sort();
      final exactItemSet = controller.exactShieldList.toSet();
      final manualItems = controller.shieldList
          .where(
            (item) =>
                !autoItemSet.contains(item) && !exactItemSet.contains(item),
          )
          .toList()
        ..sort();
      final ignoredItems = controller.autoShieldIgnoreList.toList()..sort();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DanmuShieldSection(
            title: '手动加入的',
            items: manualItems,
            emptyText: '暂无手动添加的关键词',
            onRemove: controller.removeShieldList,
          ),
          const SizedBox(height: 20),
          _DanmuShieldSection(
            title: '全匹配',
            items: exactItems,
            emptyText: '暂无全匹配屏蔽',
            description: '只屏蔽文字完全相同的弹幕。',
            onRemove: controller.removeShieldList,
          ),
          const SizedBox(height: 20),
          _DanmuShieldSection(
            title: '自动加入的',
            items: autoItems,
            emptyText: '暂无自动加入的关键词',
            onRemove: controller.removeShieldList,
          ),
          const SizedBox(height: 20),
          _DanmuShieldSection(
            title: '被自动加入忽略的',
            items: ignoredItems,
            emptyText: '暂无永久忽略的弹幕',
            description: '移除后，这些弹幕再次高频出现时可以重新提示。',
            onRemove: controller.removeAutoShieldIgnore,
          ),
        ],
      );
    });
  }
}

class _DanmuShieldSection extends StatelessWidget {
  const _DanmuShieldSection({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.onRemove,
    this.description,
  });

  final String title;
  final List<String> items;
  final String emptyText;
  final String? description;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title（${items.length}）', style: textTheme.titleSmall),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            emptyText,
            style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
          )
        else
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: items
                .map(
                  (item) => ActionChip(
                    label: Text(item),
                    avatar: const Icon(Icons.close, size: 16),
                    tooltip: '点击移除',
                    onPressed: () => onRemove(item),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
