/// Matches incoming danmaku against keyword, exact, and regex shield rules.
class DanmuShieldMatcher {
  const DanmuShieldMatcher();

  bool isBlocked(
    String message, {
    required Iterable<String> keywords,
    required Set<String> exactKeywords,
  }) {
    final trimmed = message.trim();
    if (exactKeywords.contains(message) ||
        (trimmed.isNotEmpty && exactKeywords.contains(trimmed))) {
      return true;
    }

    for (final keyword in keywords) {
      if (keyword.isEmpty || exactKeywords.contains(keyword)) {
        continue;
      }

      if (_isRegexFormat(keyword)) {
        try {
          if (message.contains(RegExp(_removeRegexFormat(keyword)))) {
            return true;
          }
        } catch (_) {
          continue;
        }
      } else if (message.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  static bool _isRegexFormat(String keyword) {
    return keyword.startsWith('/') &&
        keyword.endsWith('/') &&
        keyword.length > 2;
  }

  static String _removeRegexFormat(String keyword) {
    return keyword.substring(1, keyword.length - 1);
  }
}
