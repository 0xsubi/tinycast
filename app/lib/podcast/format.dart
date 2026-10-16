const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const Map<String, int> _zones = {
  'UT': 0,
  'UTC': 0,
  'GMT': 0,
  'Z': 0,
  'EST': -5,
  'EDT': -4,
  'CST': -6,
  'CDT': -5,
  'MST': -7,
  'MDT': -6,
  'PST': -8,
  'PDT': -7,
};

final RegExp _rfc822 = RegExp(
  r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]+)?',
);

/// RSS `pubDate` ("Fri, 09 Oct 2026 08:00:00 -0000"), in UTC.
DateTime? parseRfc822(String? value) {
  final m = _rfc822.firstMatch(value ?? '');
  if (m == null) return null;
  final month = _months.indexWhere((s) => s.toLowerCase() == m.group(2)!.toLowerCase());
  if (month < 0) return null;
  var year = int.parse(m.group(3)!);
  if (year < 100) year += 2000;
  final zone = m.group(7);
  var offset = Duration.zero;
  if (zone != null && (zone.startsWith('+') || zone.startsWith('-'))) {
    final sign = zone.startsWith('-') ? -1 : 1;
    offset = Duration(hours: int.parse(zone.substring(1, 3)), minutes: int.parse(zone.substring(3))) * sign;
  } else if (zone != null) {
    offset = Duration(hours: _zones[zone.toUpperCase()] ?? 0);
  }
  return DateTime.utc(
    year,
    month + 1,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6) ?? '0'),
  ).subtract(offset);
}

/// `itunes:duration` is either plain seconds or `[hh:]mm:ss`.
double? parseDuration(String? value) {
  if (value == null) return null;
  var seconds = 0.0;
  for (final part in value.trim().split(':')) {
    final n = double.tryParse(part);
    if (n == null) return null;
    seconds = seconds * 60 + n;
  }
  return seconds > 0 ? seconds : null;
}

/// "Oct 9, 2026"
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "1 hr 50 min", "42 min"
String formatLength(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

/// "163 MB"
String formatBytes(int bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).round()} MB';
  return '${(bytes / 1e3).round()} KB';
}

const Map<String, String> _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'bull': '•',
  'middot': '·',
  'copy': '©',
  'reg': '®',
  'trade': '™',
};

/// Flattens show-notes HTML into readable plain text: paragraphs and line
/// breaks survive, tags go, entities are decoded.
String plainText(String html) {
  var s = html
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*/\s*(p|div|h[1-6]|ul|ol)\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  s = s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final e = m.group(1)!;
    if (e.startsWith('#x') || e.startsWith('#X')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
    if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
    return _entities[e.toLowerCase()] ?? m.group(0)!;
  });
  return s
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t ⁠]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
