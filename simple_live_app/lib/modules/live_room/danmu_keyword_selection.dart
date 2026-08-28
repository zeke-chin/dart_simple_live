import 'package:characters/characters.dart';

class DanmuSelectionRange {
  const DanmuSelectionRange(this.start, this.end);

  /// Inclusive start index in grapheme clusters.
  final int start;

  /// Exclusive end index in grapheme clusters.
  final int end;

  int get length => end - start;
}

/// Multi-range character selection over one danmaku.
///
/// - No selection: nothing to block.
/// - Full range: exact match.
/// - One shorter range: contains keyword.
/// - Multiple ranges: regex that matches the segments in order, e.g.
///   selecting `bc` and `ef` from `abcdef` yields `/bc.*ef/`.
class DanmuKeywordSelection {
  DanmuKeywordSelection(this.source) : glyphs = source.characters.toList();

  final String source;
  final List<String> glyphs;
  final List<DanmuSelectionRange> _ranges = [];

  int get length => glyphs.length;

  bool get hasSelection => _ranges.isNotEmpty;

  bool get isExact =>
      _ranges.length == 1 &&
      _ranges.first.start == 0 &&
      _ranges.first.end == length;

  bool get isRegex => _ranges.length > 1;

  List<DanmuSelectionRange> get ranges => List.unmodifiable(_ranges);

  bool isSelected(int index) {
    return _ranges.any((range) => index >= range.start && index < range.end);
  }

  String get keyword {
    if (!hasSelection) {
      return '';
    }
    if (isExact) {
      return source;
    }
    if (_ranges.length == 1) {
      return _slice(_ranges.first);
    }
    final pattern =
        _ranges.map((range) => RegExp.escape(_slice(range))).join('.*');
    return '/$pattern/';
  }

  int get shortestSegmentLength {
    if (_ranges.isEmpty) {
      return 0;
    }
    return _ranges
        .map((range) => range.length)
        .reduce((value, length) => value < length ? value : length);
  }

  void selectAll() {
    _ranges
      ..clear()
      ..add(DanmuSelectionRange(0, length));
  }

  void clear() {
    _ranges.clear();
  }

  void addRange(int newStart, int newEnd) {
    var start = newStart.clamp(0, length);
    var end = newEnd.clamp(0, length);
    if (end < start) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    if (start == end) {
      return;
    }
    _ranges.add(DanmuSelectionRange(start, end));
    _normalize();
  }

  void removeRangeContaining(int index) {
    _ranges.removeWhere((range) => index >= range.start && index < range.end);
  }

  String _slice(DanmuSelectionRange range) {
    return glyphs.sublist(range.start, range.end).join();
  }

  void _normalize() {
    if (_ranges.length <= 1) {
      return;
    }
    _ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <DanmuSelectionRange>[];
    var current = _ranges.first;
    for (var i = 1; i < _ranges.length; i++) {
      final next = _ranges[i];
      if (next.start <= current.end) {
        current = DanmuSelectionRange(
          current.start,
          next.end > current.end ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    _ranges
      ..clear()
      ..addAll(merged);
  }
}
