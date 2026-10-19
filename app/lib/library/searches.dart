import 'dart:convert';

import 'library.dart';

/// The library setting holding recent search terms, as a JSON list, most
/// recent first.
const String recentSearchesSetting = 'recent-searches';

/// Most terms kept.
const int _kept = 8;

/// The terms the user searched for, most recent first.
List<String> recentSearches(Library library) {
  final value = library.setting(recentSearchesSetting);
  if (value == null) return const [];
  try {
    return (jsonDecode(value) as List).whereType<String>().toList();
  } on FormatException {
    return const [];
  }
}

/// Puts [term] first among the recent searches, once, whatever its case.
Future<void> rememberSearch(Library library, String term) async {
  final t = term.trim();
  if (t.isEmpty) return;
  final rest = recentSearches(library).where((s) => s.toLowerCase() != t.toLowerCase());
  final next = [t, ...rest].take(_kept).toList();
  if (next.join('\n') == recentSearches(library).join('\n')) return;
  await library.setSetting(recentSearchesSetting, jsonEncode(next));
}

Future<void> clearRecentSearches(Library library) => library.setSetting(recentSearchesSetting, null);
