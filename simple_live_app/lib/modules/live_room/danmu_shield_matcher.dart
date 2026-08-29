/// Matches incoming danmaku against keyword, exact, and regex shield rules.
class DanmuShieldMatcher {
  const DanmuShieldMatcher();

  bool isBlocked(
    String message, {
    required Iterable<String> keywords,
    required Set<String> exactKeywords,
  }) {
    return matchedKeywords(
      message,
      keywords: keywords,
      exactKeywords: exactKeywords,
    ).isNotEmpty;
  }

  List<String> matchedKeywords(
    String message, {
    required Iterable<String> keywords,
    required Set<String> exactKeywords,
  }) {
    final matches = <String>[];
    final trimmed = message.trim();
    if (exactKeywords.contains(message)) {
      matches.add(message);
    } else if (trimmed.isNotEmpty && exactKeywords.contains(trimmed)) {
      matches.add(trimmed);
    }

    for (final keyword in keywords) {
      if (keyword.isEmpty || exactKeywords.contains(keyword)) {
        continue;
      }

      if (_isRegexFormat(keyword)) {
        try {
          if (message.contains(RegExp(_removeRegexFormat(keyword)))) {
            matches.add(keyword);
          }
        } catch (_) {
          continue;
        }
      } else if (message.contains(keyword)) {
        matches.add(keyword);
      }
    }

    return matches;
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
