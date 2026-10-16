/// A show, as found in the directory or opened from its feed.
class Podcast {
  const Podcast({required this.title, required this.feed, this.author, this.artwork, this.genre, this.episodeCount});

  final String title;
  final Uri feed;
  final String? author;
  final String? artwork;
  final String? genre;
  final int? episodeCount;

  /// This show with gaps (artwork, author) filled in from its [feed].
  Podcast withFeed(PodcastFeed feed) => Podcast(
    title: title,
    feed: this.feed,
    author: author ?? feed.author,
    artwork: artwork ?? feed.artwork,
    genre: genre ?? feed.categories.firstOrNull,
    episodeCount: episodeCount ?? feed.episodes.length,
  );

  @override
  bool operator ==(Object other) => other is Podcast && other.feed == feed;

  @override
  int get hashCode => feed.hashCode;
}

/// Everything read from a podcast's RSS feed.
class PodcastFeed {
  const PodcastFeed({
    required this.title,
    required this.episodes,
    this.author,
    this.description,
    this.artwork,
    this.link,
    this.categories = const [],
    this.explicit = false,
  });

  final String title;
  final String? author;
  final String? description;
  final String? artwork;
  final Uri? link;
  final List<String> categories;
  final bool explicit;

  /// Newest first, as the feed lists them; only items with audio.
  final List<PodcastEpisode> episodes;
}

class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.audio,
    this.description,
    this.published,
    this.duration,
    this.number,
    this.season,
    this.type,
    this.explicit,
    this.artwork,
    this.mimeType,
    this.bytes,
    this.link,
  });

  /// The item's guid, or its audio URL when it has none.
  final String id;
  final String title;
  final Uri audio;

  /// Plain text; HTML in the feed is flattened.
  final String? description;
  final DateTime? published;

  /// Seconds.
  final double? duration;
  final int? number;
  final int? season;

  /// `itunes:episodeType`: full, trailer or bonus.
  final String? type;
  final bool? explicit;

  /// The episode's own artwork, when it has one.
  final String? artwork;
  final String? mimeType;
  final int? bytes;
  final Uri? link;
}
