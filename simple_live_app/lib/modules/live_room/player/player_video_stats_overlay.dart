import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_video_stats.dart';

class PlayerVideoStatsOverlay extends StatelessWidget {
  final Rxn<PlayerVideoStats> stats;
  final EdgeInsets padding;

  const PlayerVideoStatsOverlay({
    required this.stats,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AppSettingsController.instance.showPlayerVideoStats.value) {
        return const SizedBox.shrink();
      }
      final value = stats.value;
      if (value == null || !value.hasSource) {
        return const SizedBox.shrink();
      }
      final srLabel = value.superResolutionLabel;
      final srValues = value.superResolutionValues;
      return Positioned(
        left: padding.left + 12,
        top: padding.top + 12,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {
                    1: FixedColumnWidth(8),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _statsRow(value.sourceLabel, value.sourceValues),
                    if (srLabel != null && srValues != null)
                      _statsRow(srLabel, srValues),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  TableRow _statsRow(String label, String values) {
    return TableRow(
      children: [
        Text(label),
        const SizedBox.shrink(),
        Text(values),
      ],
    );
  }
}
