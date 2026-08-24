import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/live_room/danmu_keyword_selection.dart';

class DanmuBlockDialog extends StatefulWidget {
  const DanmuBlockDialog({
    super.key,
    required this.userName,
    required this.message,
    required this.onConfirm,
  });

  final String userName;
  final String message;
  final void Function(String keyword, {required bool exact}) onConfirm;

  @override
  State<DanmuBlockDialog> createState() => _DanmuBlockDialogState();
}

class _DanmuBlockDialogState extends State<DanmuBlockDialog> {
  late final DanmuKeywordSelection _selection;

  @override
  void initState() {
    super.initState();
    _selection = DanmuKeywordSelection(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = _selection.keyword;
    final exact = _selection.isExact;
    final tooShort = !exact && selected.characters.length <= 2;

    return AlertDialog(
      title: const Text('屏蔽弹幕'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.userName,
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            AppStyle.vGap8,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _selection.prefix,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    TextSpan(
                      text: selected,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: _selection.suffix,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selection.length > 1) ...[
              AppStyle.vGap12,
              RangeSlider(
                values: RangeValues(
                  _selection.start.toDouble(),
                  _selection.end.toDouble(),
                ),
                min: 0,
                max: _selection.length.toDouble(),
                divisions: _selection.length,
                labels: RangeLabels(selected, selected),
                onChanged: (value) {
                  setState(() {
                    _selection.updateRange(
                      value.start.round(),
                      value.end.round(),
                    );
                  });
                },
              ),
              Text(
                '滑动两端选择要屏蔽的关键词',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
            AppStyle.vGap8,
            Text(
              exact
                  ? '全匹配：只屏蔽完全相同的弹幕'
                  : '包含：屏蔽所有含「$selected」的弹幕',
              style: textTheme.bodySmall,
            ),
            if (tooShort) ...[
              AppStyle.vGap4,
              Text(
                '关键词较短，可能会误伤其它弹幕',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: selected.trim().isEmpty
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onConfirm(selected, exact: exact);
                },
          child: const Text('屏蔽'),
        ),
      ],
    );
  }
}
