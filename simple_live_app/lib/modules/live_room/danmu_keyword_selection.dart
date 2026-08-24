import 'package:characters/characters.dart';

/// A sliding character-range selection over one danmaku.
///
/// The full range means exact match. A shorter range is used as a contains
/// keyword.
class DanmuKeywordSelection {
  DanmuKeywordSelection(this.source)
      : _chars = source.characters,
        start = 0,
        end = source.characters.length;

  final String source;
  final Characters _chars;
  int start;
  int end;

  int get length => _chars.length;

  bool get isExact => start <= 0 && end >= _chars.length;

  String get prefix => _chars.take(start).toString();

  String get selected {
    if (isExact) {
      return source;
    }
    return _chars.skip(start).take(end - start).toString();
  }

  String get suffix => _chars.skip(end).toString();

  String get keyword => selected;

  void updateRange(int newStart, int newEnd) {
    var nextStart = newStart.clamp(0, _chars.length);
    var nextEnd = newEnd.clamp(0, _chars.length);
    if (nextEnd < nextStart) {
      final tmp = nextStart;
      nextStart = nextEnd;
      nextEnd = tmp;
    }
    if (nextEnd == nextStart && _chars.isNotEmpty) {
      if (nextEnd < _chars.length) {
        nextEnd++;
      } else if (nextStart > 0) {
        nextStart--;
      }
    }
    start = nextStart;
    end = nextEnd;
  }
}
