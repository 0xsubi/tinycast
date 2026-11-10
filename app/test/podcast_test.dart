import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/podcast/directory.dart';
import 'package:tinycast/podcast/feed.dart';
import 'package:tinycast/podcast/format.dart';

const String _rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
     xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Waveform: The MKBHD Podcast</title>
    <itunes:author>MKBHD</itunes:author>
    <description>A tech podcast &amp;nbsp;for gadget lovers.</description>
    <itunes:image href="https://example.com/show.jpg"/>
    <itunes:category text="Technology"/>
    <itunes:explicit>no</itunes:explicit>
    <item><title>No audio, skipped</title></item>
    <item>
      <title>The 2026 Smartphone Awards Discussion Episode</title>
      <guid isPermaLink="false"><![CDATA[821b0dae]]></guid>
      <description><![CDATA[<p>This week the news is slow.</p><p>Links:<br/>The Verge &amp; more</p>]]></description>
      <pubDate>Fri, 09 Oct 2026 08:00:00 -0000</pubDate>
      <itunes:duration>6626</itunes:duration>
      <itunes:episodeType>full</itunes:episodeType>
      <enclosure url="https://example.com/latest.mp3" length="163061062" type="audio/mpeg"/>
    </item>
    <item>
      <title>Numbered</title>
      <itunes:episode>375</itunes:episode>
      <itunes:season>3</itunes:season>
      <itunes:duration>1:02:05</itunes:duration>
      <itunes:explicit>true</itunes:explicit>
      <itunes:image href="https://example.com/375.jpg"/>
      <pubDate>Tue, 06 Oct 2026 10:30:00 PDT</pubDate>
      <enclosure url="https://example.com/375.mp3" length="0" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

void main() {
  test('parses the show and its playable episodes', () {
    final feed = parseFeed(_rss);
    expect(feed.title, 'Waveform: The MKBHD Podcast');
    expect(feed.author, 'MKBHD');
    expect(feed.description, 'A tech podcast for gadget lovers.');
    expect(feed.artwork, 'https://example.com/show.jpg');
    expect(feed.categories, ['Technology']);
    expect(feed.explicit, isFalse);
    expect(feed.episodes.map((e) => e.title), ['The 2026 Smartphone Awards Discussion Episode', 'Numbered']);

    final latest = feed.episodes.first;
    expect(latest.id, '821b0dae');
    expect(latest.description, 'This week the news is slow.\n\nLinks:\nThe Verge & more');
    expect(latest.published, DateTime.utc(2026, 10, 9, 8));
    expect(latest.duration, 6626);
    expect(latest.number, isNull);
    expect(latest.type, 'full');
    expect(latest.bytes, 163061062);
    expect(latest.mimeType, 'audio/mpeg');
    expect(latest.audio, Uri.parse('https://example.com/latest.mp3'));
    expect(latest.artwork, isNull);

    final numbered = feed.episodes.last;
    expect(numbered.number, 375);
    expect(numbered.season, 3);
    expect(numbered.duration, 3725);
    expect(numbered.explicit, isTrue);
    expect(numbered.artwork, 'https://example.com/375.jpg');
    // PDT is UTC-7.
    expect(numbered.published, DateTime.utc(2026, 10, 6, 17, 30));
    // A zero length means "unknown".
    expect(numbered.bytes, isNull);
  });

  test('rejects documents that are not podcast feeds', () {
    expect(() => parseFeed('not xml'), throwsA(isA<FeedError>()));
    expect(() => parseFeed('<html></html>'), throwsA(isA<FeedError>()));
  });

  test('parses directory search results, skipping shows without a feed', () {
    final shows = parseSearchResults('''{"resultCount": 2, "results": [
      {"collectionName": "Waveform: The MKBHD Podcast", "artistName": "MKBHD",
       "feedUrl": "https://feeds.megaphone.fm/STU4418364045",
       "artworkUrl600": "https://example.com/600.jpg", "primaryGenreName": "Technology", "trackCount": 380},
      {"collectionName": "No feed"}
    ]}''');
    expect(shows, hasLength(1));
    expect(shows.single.title, 'Waveform: The MKBHD Podcast');
    expect(shows.single.author, 'MKBHD');
    expect(shows.single.feed, Uri.parse('https://feeds.megaphone.fm/STU4418364045'));
    expect(shows.single.artwork, 'https://example.com/600.jpg');
    expect(shows.single.episodeCount, 380);
    expect(() => parseSearchResults('<html>'), throwsA(isA<FeedError>()));
  });

  test('parses episode search results with their shows, skipping ones without audio or a feed', () {
    final found = parseEpisodeResults('''{"resultCount": 3, "results": [
      {"trackName": "Seinfeld", "collectionName": "Acquired", "episodeGuid": "9c3ce276",
       "feedUrl": "https://feeds.transistor.fm/acquired",
       "episodeUrl": "https://media.example.com/seinfeld.mp3", "episodeFileExtension": "mp3",
       "releaseDate": "2026-10-19T04:00:46Z", "trackTimeMillis": 13820000,
       "contentAdvisoryRating": "Clean", "description": "The <b>business</b> of &amp; nothing.",
       "artworkUrl600": "https://example.com/600.jpg", "genres": [{"name": "Technology", "id": "1318"}]},
      {"trackName": "No audio", "feedUrl": "https://example.com/feed.xml"},
      {"trackName": "No feed", "episodeUrl": "https://example.com/a.mp3"}
    ]}''');
    expect(found, hasLength(1));
    final (:podcast, :episode) = found.single;
    expect(podcast.title, 'Acquired');
    expect(podcast.feed, Uri.parse('https://feeds.transistor.fm/acquired'));
    expect(podcast.artwork, 'https://example.com/600.jpg');
    expect(podcast.genre, 'Technology');
    expect(episode.id, '9c3ce276');
    expect(episode.title, 'Seinfeld');
    expect(episode.audio, Uri.parse('https://media.example.com/seinfeld.mp3'));
    expect(episode.published, DateTime.utc(2026, 10, 19, 4, 0, 46));
    expect(episode.duration, 13820);
    expect(episode.explicit, isFalse);
    expect(episode.mimeType, 'audio/mpeg');
    expect(episode.description, 'The business of & nothing.');
    expect(() => parseEpisodeResults('<html>'), throwsA(isA<FeedError>()));
  });

  test('reads a genre chart and orders its lookup by rank', () {
    final ids = parseChart('''{"feed": {"entry": [
      {"im:name": {"label": "First"}, "id": {"label": "https://x", "attributes": {"im:id": "111"}}},
      {"im:name": {"label": "Second"}, "id": {"label": "https://y", "attributes": {"im:id": "222"}}},
      {"im:name": {"label": "Broken"}}
    ]}}''');
    expect(ids, ['111', '222']);
    // A chart of one is an object, not a list; an empty chart has no entries.
    expect(parseChart('{"feed": {"entry": {"id": {"attributes": {"im:id": "9"}}}}}'), ['9']);
    expect(parseChart('{"feed": {}}'), isEmpty);
    expect(() => parseChart('<html>'), throwsA(isA<FeedError>()));

    // The lookup answers in its own order.
    final shows = parseLookupResults('''{"results": [
      {"collectionId": 222, "collectionName": "Second", "feedUrl": "https://example.com/2.xml"},
      {"collectionId": 333, "collectionName": "No feed"},
      {"collectionId": 111, "collectionName": "First", "feedUrl": "https://example.com/1.xml"}
    ]}''', ids);
    expect(shows.map((s) => s.title), ['First', 'Second']);
  });

  test('flattens show-notes HTML', () {
    expect(plainText('<p>One&nbsp;two</p><ul><li>a</li><li>b &#8212; c</li></ul>'), 'One two\n\n• a\n• b — c');
  });

  test('keeps show-note links', () {
    expect(
      plainText('<p>Thanks to <a href="https://ex.com/sponsor?a=1&amp;b=2">our <b>sponsor</b></a>.</p>'),
      'Thanks to [our sponsor](https://ex.com/sponsor?a=1&b=2).',
    );
    // A link whose text is its address stays bare; other schemes keep just their text.
    expect(plainText('<a href="https://ex.com">https://ex.com</a>'), 'https://ex.com');
    expect(plainText("<a href='mailto:hi@ex.com'>Write in</a>"), 'Write in');
    // Brackets in the address are escaped so the link survives.
    expect(
      plainText('<a href="https://en.wikipedia.org/wiki/Java_(island)">Java</a>'),
      '[Java](https://en.wikipedia.org/wiki/Java_%28island%29)',
    );
  });

  test('splits show notes into text and links', () {
    final runs = noteRuns('See [the site](https://ex.com/a) or https://ex.com/b, (also https://ex.com/c).');
    expect(
      [for (final r in runs) (r.text, r.link?.toString())],
      [
        ('See ', null),
        ('the site', 'https://ex.com/a'),
        (' or ', null),
        ('https://ex.com/b', 'https://ex.com/b'),
        (', (also ', null),
        ('https://ex.com/c', 'https://ex.com/c'),
        (').', null),
      ],
    );
    // A bracket that belongs to the address stays.
    expect(noteRuns('https://ex.com/Java_(island)').single.link.toString(), 'https://ex.com/Java_(island)');
    expect(noteText('Hi [there](https://ex.com)!'), 'Hi there!');
    expect(noteRuns('No links here.').single, (text: 'No links here.', link: null));
  });

  test('formats lengths, dates and sizes', () {
    expect(formatLength(6626), '1 hr 50 min');
    expect(formatLength(3600), '1 hr');
    expect(formatLength(42 * 60 + 10), '42 min');
    expect(formatDate(DateTime.utc(2026, 10, 9)), 'Oct 9, 2026');
    expect(formatBytes(163061062), '163 MB');
    expect(parseDuration('45:30'), 2730);
    expect(parseDuration('n/a'), isNull);
  });
}
