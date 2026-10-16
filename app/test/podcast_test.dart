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

  test('flattens show-notes HTML', () {
    expect(plainText('<p>One&nbsp;two</p><ul><li>a</li><li>b &#8212; c</li></ul>'), 'One two\n\n• a\n• b — c');
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
