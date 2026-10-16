import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'feed.dart';
import 'models.dart';

/// Shown before the first search.
final Podcast waveform = Podcast(
  title: 'Waveform: The MKBHD Podcast',
  author: 'MKBHD',
  feed: Uri.parse('https://feeds.megaphone.fm/STU4418364045'),
  artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Podcasts221/v4/92/dd/8e/92dd8eed-43ec-dc47-50ae-c1ec7c0a3353/mza_3861776104886813687.jpg/600x600bb.jpg',
  genre: 'Technology',
);

/// Finds shows and reads their feeds.
abstract class PodcastDirectory {
  Future<List<Podcast>> search(String term);
  Future<PodcastFeed> feed(Podcast podcast);
}

/// The Apple Podcasts directory (iTunes Search API, no key needed), with
/// feeds fetched directly and kept for the session.
class ITunesDirectory implements PodcastDirectory {
  final Map<Uri, Future<PodcastFeed>> _feeds = {};

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
  Future<PodcastFeed> feed(Podcast podcast) => _feeds.putIfAbsent(podcast.feed, () {
    final pending = _fetchFeed(podcast.feed);
    // Forget a failed fetch so it can be retried.
    pending.then<void>((_) {}, onError: (Object _) => _feeds.remove(podcast.feed));
    return pending;
  });

  Future<PodcastFeed> _fetchFeed(Uri uri) async {
    final rss = await _get(uri, 'Could not reach this show’s feed');
    // Big feeds (hundreds of episodes) take a while to parse; keep it off the UI thread.
    return Isolate.run(() => parseFeed(rss));
  }
}

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
List<Podcast> parseSearchResults(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const FeedError('Search returned something unexpected');
  }
  final results = json is Map<String, Object?> ? json['results'] : null;
  if (results is! List) return const [];
  return [
    for (final r in results.whereType<Map<String, Object?>>())
      if (Uri.tryParse(r['feedUrl'] as String? ?? '') case final feed? when feed.hasScheme)
        Podcast(
          title: r['collectionName'] as String? ?? r['trackName'] as String? ?? 'Untitled podcast',
          feed: feed,
          author: r['artistName'] as String?,
          artwork: (r['artworkUrl600'] ?? r['artworkUrl100']) as String?,
          genre: r['primaryGenreName'] as String?,
          episodeCount: (r['trackCount'] as num?)?.toInt(),
        ),
  ];
}
