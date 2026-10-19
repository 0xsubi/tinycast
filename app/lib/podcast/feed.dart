import 'package:xml/xml.dart';

import 'format.dart';
import 'models.dart';

class FeedError implements Exception {
  const FeedError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parses a podcast RSS document.
PodcastFeed parseFeed(String rss) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(rss);
  } on XmlException {
    throw const FeedError('This show’s feed is not valid RSS');
  }
  final channel = doc.findAllElements('channel').firstOrNull;
  if (channel == null) throw const FeedError('This show’s feed is not valid RSS');

  final episodes = <PodcastEpisode>[];
  for (final item in channel.findElements('item')) {
    final enclosure = item.getElement('enclosure');
    final audio = Uri.tryParse(enclosure?.getAttribute('url')?.trim() ?? '');
    if (audio == null || !audio.hasScheme) continue;
    episodes.add(
      PodcastEpisode(
        id: _text(item, 'guid') ?? audio.toString(),
        title: _text(item, 'title') ?? 'Untitled episode',
        audio: audio,
        description: _description(item),
        published: parseRfc822(_text(item, 'pubDate')),
        duration: parseDuration(_text(item, 'itunes:duration')),
        number: int.tryParse(_text(item, 'itunes:episode') ?? ''),
        season: int.tryParse(_text(item, 'itunes:season') ?? ''),
        type: _text(item, 'itunes:episodeType')?.toLowerCase(),
        explicit: _flag(_text(item, 'itunes:explicit')),
        artwork: _image(item),
        mimeType: enclosure?.getAttribute('type'),
        bytes: switch (int.tryParse(enclosure?.getAttribute('length') ?? '')) {
          final n? when n > 0 => n,
          _ => null,
        },
        link: Uri.tryParse(_text(item, 'link') ?? ''),
      ),
    );
  }

  return PodcastFeed(
    title: _text(channel, 'title') ?? 'Untitled podcast',
    author: _text(channel, 'itunes:author') ?? _text(channel, 'managingEditor'),
    description: _description(channel),
    artwork: _image(channel) ?? _text(channel.getElement('image'), 'url'),
    link: Uri.tryParse(_text(channel, 'link') ?? ''),
    categories: [
      for (final c in channel.findElements('itunes:category'))
        if (c.getAttribute('text') case final t? when t.isNotEmpty) t,
    ],
    explicit: _flag(_text(channel, 'itunes:explicit')) ?? false,
    episodes: episodes,
  );
}

String? _text(XmlElement? parent, String name) {
  final text = parent?.getElement(name)?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

String? _description(XmlElement e) {
  final raw = _text(e, 'description') ?? _text(e, 'itunes:summary') ?? _text(e, 'content:encoded');
  if (raw == null) return null;
  final text = plainText(raw);
  return text.isEmpty ? null : text;
}

String? _image(XmlElement e) {
  final href = e.getElement('itunes:image')?.getAttribute('href')?.trim();
  return href == null || href.isEmpty ? null : href;
}

bool? _flag(String? value) => switch (value?.toLowerCase()) {
  'yes' || 'true' || 'explicit' => true,
  'no' || 'false' || 'clean' => false,
  _ => null,
};
