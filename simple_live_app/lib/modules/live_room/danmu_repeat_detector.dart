import 'dart:collection';

/// Detects repeated danmaku text within a sliding time window.
///
/// A continuously repeated message only triggers once. It becomes eligible to
/// trigger again after it has not appeared for a full [window].
class DanmuRepeatDetector {
  DanmuRepeatDetector({
    this.window = const Duration(seconds: 5),
    this.threshold = 5,
  }) : assert(threshold > 1);

  final Duration window;
  final int threshold;

  final Map<String, ListQueue<DateTime>> _occurrences = {};
  final Set<String> _activeBursts = {};
  DateTime? _lastCleanupAt;

  /// Returns the normalized danmaku text when it reaches the threshold.
  String? add(String message, {DateTime? now}) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final current = now ?? DateTime.now();
    _cleanupIfNeeded(current);

    final timestamps = _occurrences.putIfAbsent(
      normalized,
      ListQueue<DateTime>.new,
    );
    _removeExpired(timestamps, current);

    if (timestamps.isEmpty) {
      _activeBursts.remove(normalized);
    }

    timestamps.addLast(current);
    if (_activeBursts.contains(normalized) || timestamps.length < threshold) {
      return null;
    }

    _activeBursts.add(normalized);
    return normalized;
  }

  void clear() {
    _occurrences.clear();
    _activeBursts.clear();
    _lastCleanupAt = null;
  }

  void _cleanupIfNeeded(DateTime now) {
    final lastCleanupAt = _lastCleanupAt;
    if (lastCleanupAt != null && now.difference(lastCleanupAt) < window) {
      return;
    }

    _lastCleanupAt = now;
    _occurrences.removeWhere((message, timestamps) {
      _removeExpired(timestamps, now);
      if (timestamps.isNotEmpty) {
        return false;
      }
      _activeBursts.remove(message);
      return true;
    });
  }

  void _removeExpired(ListQueue<DateTime> timestamps, DateTime now) {
    while (timestamps.isNotEmpty && now.difference(timestamps.first) > window) {
      timestamps.removeFirst();
    }
  }
}
