import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'feed.dart';
import 'format.dart';
import 'models.dart';

/// Finds shows and reads their feeds.
abstract class PodcastDirectory {
  Future<List<Podcast>> search(String term);

  /// Episodes whose title or notes match [term], each with its show.
  Future<List<FoundEpisode>> searchEpisodes(String term);

  /// The most popular shows in an Apple Podcasts [genre], most popular first.
  Future<List<Podcast>> top(int genre);

  Future<PodcastFeed> feed(Podcast podcast);
}

/// The Apple Podcasts directory (iTunes Search API, no key needed), with
/// feeds fetched directly and kept for the session.
class ITunesDirectory implements PodcastDirectory {
  ITunesDirectory({String? country}) : country = country ?? _storefront();

  /// The App Store storefront whose charts are shown, e.g. "us".
  final String country;

  final Map<Uri, Future<PodcastFeed>> _feeds = {};
  final Map<int, Future<List<Podcast>>> _charts = {};

  @override
  Future<List<Podcast>> search(String term) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'media': 'podcast',
      'entity': 'podcast',
      'limit': '40',
      'term': term,
    });
    return parseSearchResults(await _get(uri, 'Search is unavailable right now'));
  }

  @override
  Future<List<FoundEpisode>> searchEpisodes(String term) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'media': 'podcast',
      'entity': 'podcastEpisode',
      'limit': '30',
      'term': term,
    });
    return parseEpisodeResults(await _get(uri, 'Episode search is unavailable right now'));
  }

  /// Search can't filter by genre, so this reads the genre's top chart (an
  /// RSS feed of show ids) and looks the ids up for their feeds.
  @override
  Future<List<Podcast>> top(int genre) => _remember(_charts, genre, () async {
    const failure = 'Top shows are unavailable right now';
    final chart = Uri.https('itunes.apple.com', '/$country/rss/toppodcasts/limit=$_chartSize/genre=$genre/json');
    final ids = parseChart(await _get(chart, failure));
    if (ids.isEmpty) return const <Podcast>[];
    final lookup = Uri.https('itunes.apple.com', '/lookup', {'id': ids.join(','), 'country': country});
    return parseLookupResults(await _get(lookup, failure), ids);
  });

  @override
  Future<PodcastFeed> feed(Podcast podcast) => _remember(_feeds, podcast.feed, () => _fetchFeed(podcast.feed));

  Future<PodcastFeed> _fetchFeed(Uri uri) async {
    final rss = await _get(uri, 'Could not reach this show’s feed');
    // Big feeds (hundreds of episodes) take a while to parse; keep it off the UI thread.
    return Isolate.run(() => parseFeed(rss));
  }
}

/// Shows per genre chart.
const int _chartSize = 25;

/// The storefront for the device's region, else the US one.
String _storefront() {
  final region = RegExp(r'^[a-z]{2,3}[_-]([A-Z]{2})\b').firstMatch(Platform.localeName)?.group(1);
  return region?.toLowerCase() ?? 'us';
}

/// Caches [fetch]'s result under [key] for the session, forgetting a failure
/// so it can be retried.
Future<T> _remember<K, T>(Map<K, Future<T>> cache, K key, Future<T> Function() fetch) => cache.putIfAbsent(key, () {
  final pending = fetch();
  pending.then<void>((_) {}, onError: (Object _) => cache.remove(key));
  return pending;
});

Future<String> _get(Uri uri, String failure) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final response = await (await client.getUrl(uri)).close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) throw FeedError('$failure (HTTP ${response.statusCode})');
    return await response.transform(const Utf8Decoder(allowMalformed: true)).join();
  } on FeedError {
    rethrow;
  } on Exception {
    throw FeedError(failure);
  } finally {
    client.close();
  }
}

/// Parses an iTunes Search API response, keeping shows that have a feed.
List<Podcast> parseSearchResults(String body) => [
  for (final r in _results(body, 'Search returned something unexpected')) ?_podcast(r),
];

/// Parses an iTunes episode search, keeping episodes with audio and a show
/// feed. Each episode keeps the feed's guid as its id, so it is the same
/// episode (progress, downloads, favorites) as when opened from its show.
List<FoundEpisode> parseEpisodeResults(String body) => [
  for (final r in _results(body, 'Episode search returned something unexpected')) ?_foundEpisode(r),
];

FoundEpisode? _foundEpisode(Map<String, Object?> r) {
  final feed = Uri.tryParse(r['feedUrl'] as String? ?? '');
  final audio = Uri.tryParse(r['episodeUrl'] as String? ?? '');
  if (feed == null || !feed.hasScheme || audio == null || !audio.hasScheme) return null;
  final artwork = (r['artworkUrl600'] ?? r['artworkUrl160'] ?? r['artworkUrl100']) as String?;
  final description = r['description'] as String? ?? r['shortDescription'] as String?;
  final millis = (r['trackTimeMillis'] as num?)?.toDouble();
  final extension = r['episodeFileExtension'] as String?;
  return (
    podcast: Podcast(
      title: r['collectionName'] as String? ?? 'Untitled podcast',
      feed: feed,
      artwork: artwork,
      genre: switch (r['genres']) {
        [{'name': final String name}, ...] => name,
        _ => null,
      },
    ),
    episode: PodcastEpisode(
      id: r['episodeGuid'] as String? ?? audio.toString(),
      title: r['trackName'] as String? ?? 'Untitled episode',
      audio: audio,
      description: description == null ? null : plainText(description),
      published: DateTime.tryParse(r['releaseDate'] as String? ?? ''),
      duration: millis == null || millis <= 0 ? null : millis / 1000,
      explicit: switch (r['contentAdvisoryRating']) {
        'Explicit' => true,
        'Clean' => false,
        _ => null,
      },
      mimeType: switch (extension) {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        _ => null,
      },
      link: Uri.tryParse(r['trackViewUrl'] as String? ?? ''),
    ),
  );
}

/// Parses an iTunes lookup of the shows [ids], in that order, keeping shows
/// that have a feed.
List<Podcast> parseLookupResults(String body, List<String> ids) {
  final rank = {for (final (i, id) in ids.indexed) id: i};
  int rankOf(Map<String, Object?> r) => rank['${r['collectionId']}'] ?? ids.length;
  final results = _results(body, 'Top shows came back unexpected')..sort((a, b) => rankOf(a).compareTo(rankOf(b)));
  return [for (final r in results) ?_podcast(r)];
}

/// The show ids in an iTunes top-chart RSS feed (JSON), in chart order.
List<String> parseChart(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const FeedError('Top shows came back unexpected');
  }
  final feed = json is Map<String, Object?> ? json['feed'] : null;
  final entries = switch (feed is Map<String, Object?> ? feed['entry'] : null) {
    final List<Object?> list => list,
    // A chart of one is an object rather than a list.
    final Map<String, Object?> one => [one],
    _ => const <Object?>[],
  };
  return [
    for (final e in entries)
      if (e case {'id': {'attributes': {'im:id': final String id}}}) id,
  ];
}

List<Map<String, Object?>> _results(String body, String failure) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw FeedError(failure);
  }
  final results = json is Map<String, Object?> ? json['results'] : null;
  if (results is! List) return [];
  return results.whereType<Map<String, Object?>>().toList();
}

/// A search or lookup result as a show, if it has a feed.
Podcast? _podcast(Map<String, Object?> r) {
  final feed = Uri.tryParse(r['feedUrl'] as String? ?? '');
  if (feed == null || !feed.hasScheme) return null;
  return Podcast(
    title: r['collectionName'] as String? ?? r['trackName'] as String? ?? 'Untitled podcast',
    feed: feed,
    author: r['artistName'] as String?,
    artwork: (r['artworkUrl600'] ?? r['artworkUrl100']) as String?,
    genre: r['primaryGenreName'] as String?,
    episodeCount: (r['trackCount'] as num?)?.toInt(),
  );
}
