import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    final tooShort = _selection.hasSelection &&
        !exact &&
        _selection.shortestSegmentLength <= 2;

    return AlertDialog(
      title: const Text('屏蔽弹幕'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.userName,
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: !_selection.hasSelection
                      ? null
                      : () {
                          setState(_selection.clear);
                        },
                  child: const Text('清空'),
                ),
                TextButton(
                  onPressed: exact
                      ? null
                      : () {
                          setState(_selection.selectAll);
                        },
                  child: const Text('全选'),
                ),
              ],
            ),
            AppStyle.vGap8,
            _DanmuSelectableText(
              selection: _selection,
              onChanged: () => setState(() {}),
            ),
            AppStyle.vGap8,
            Text(
              '在文字上滑动选择，可多次选择不同片段',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            AppStyle.vGap8,
            Text(
              _description,
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

  String get _description {
    if (!_selection.hasSelection) {
      return '请选择要屏蔽的文字';
    }
    if (_selection.isExact) {
      return '全匹配：只屏蔽完全相同的弹幕';
    }
    if (_selection.isRegex) {
      return '正则：屏蔽匹配 ${_selection.keyword} 的弹幕';
    }
    return '包含：屏蔽所有含「${_selection.keyword}」的弹幕';
  }
}

class _DanmuSelectableText extends StatefulWidget {
  const _DanmuSelectableText({
    required this.selection,
    required this.onChanged,
  });

  final DanmuKeywordSelection selection;
  final VoidCallback onChanged;

  @override
  State<_DanmuSelectableText> createState() => _DanmuSelectableTextState();
}

class _DanmuSelectableTextState extends State<_DanmuSelectableText> {
  final GlobalKey _textKey = GlobalKey();
  int? _pointer;
  int? _anchor;
  int? _current;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final baseStyle = (textTheme.bodyLarge ?? textTheme.bodyMedium)!.copyWith(
      color: colorScheme.onSurface,
      height: 1.6,
    );
    final highlight = colorScheme.primary.withValues(alpha: 0.28);

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectionContainer.disabled(
            child: Text.rich(
              key: _textKey,
              TextSpan(
                style: baseStyle,
                children: _spans(baseStyle, highlight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _spans(TextStyle base, Color highlight) {
    final glyphs = widget.selection.glyphs;
    if (glyphs.isEmpty) {
      return const [];
    }

    final spans = <InlineSpan>[];
    var i = 0;
    while (i < glyphs.length) {
      final selected = _isHighlighted(i);
      final start = i;
      i++;
      while (i < glyphs.length && _isHighlighted(i) == selected) {
        i++;
      }
      spans.add(
        TextSpan(
          text: glyphs.sublist(start, i).join(),
          style: selected ? base.copyWith(backgroundColor: highlight) : base,
        ),
      );
    }
    return spans;
  }

  bool _isHighlighted(int index) {
    if (_anchor != null && _current != null) {
      final start = math.min(_anchor!, _current!);
      final end = math.max(_anchor!, _current!);
      if (index >= start && index <= end) {
        return true;
      }
    }
    return widget.selection.isSelected(index);
  }

  void _onPointerDown(PointerDownEvent event) {
    final index = _indexAt(event.position);
    if (index == null) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _anchor = index;
      _current = index;
      _moved = false;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final index = _indexAt(event.position) ?? _current;
    if (index == null || index == _current) {
      return;
    }
    setState(() {
      _current = index;
      _moved = true;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _commitSelection();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _resetDraft();
  }

  void _commitSelection() {
    final anchor = _anchor;
    final current = _current;
    if (anchor == null || current == null) {
      _resetDraft();
      return;
    }

    if (!_moved && widget.selection.isSelected(anchor)) {
      widget.selection.removeRangeContaining(anchor);
    } else {
      final start = math.min(anchor, current);
      final end = math.max(anchor, current);
      widget.selection.addRange(start, end + 1);
    }
    _resetDraft();
    widget.onChanged();
  }

  void _resetDraft() {
    if (!mounted) {
      return;
    }
    setState(() {
      _pointer = null;
      _anchor = null;
      _current = null;
      _moved = false;
    });
  }

  int? _indexAt(Offset globalPosition) {
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph || widget.selection.length == 0) {
      return null;
    }

    final local = renderObject.globalToLocal(globalPosition);
    final offset = renderObject.getPositionForOffset(local).offset;
    return _offsetToGlyphIndex(offset);
  }

  int _offsetToGlyphIndex(int utf16Offset) {
    if (utf16Offset <= 0) {
      return 0;
    }
    var consumed = 0;
    final glyphs = widget.selection.glyphs;
    for (var i = 0; i < glyphs.length; i++) {
      consumed += glyphs[i].length;
      if (utf16Offset <= consumed) {
        return i;
      }
    }
    return glyphs.length - 1;
  }
}
