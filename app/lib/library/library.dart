import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../podcast/models.dart';

/// An episode the user has kept: favorited, downloaded or both. Holds a full
/// copy of the episode so it can be shown and played without its feed.
class SavedEpisode {
  const SavedEpisode({
    required this.podcast,
    required this.episode,
    this.favoritedAt,
    this.downloadPath,
    this.downloadedAt,
  });

  final Podcast podcast;
  final PodcastEpisode episode;
  final DateTime? favoritedAt;
  final String? downloadPath;
  final DateTime? downloadedAt;

  bool get isFavorite => favoritedAt != null;
  bool get isDownloaded => downloadPath != null;

  SavedEpisode copyWith({
    Podcast? podcast,
    PodcastEpisode? episode,
    ValueGetter<DateTime?>? favoritedAt,
    ValueGetter<String?>? downloadPath,
    ValueGetter<DateTime?>? downloadedAt,
  }) => SavedEpisode(
    podcast: podcast ?? this.podcast,
    episode: episode ?? this.episode,
    favoritedAt: favoritedAt != null ? favoritedAt() : this.favoritedAt,
    downloadPath: downloadPath != null ? downloadPath() : this.downloadPath,
    downloadedAt: downloadedAt != null ? downloadedAt() : this.downloadedAt,
  );
}

/// The user's library — subscriptions, favorites, downloads, listening
/// progress and settings — kept in SQLite and mirrored in memory so pages can
/// read it synchronously.
class Library extends ChangeNotifier {
  Library._(this._db, this._subscriptions, this._episodes, this._progress, this._settings);

  final Database _db;
  final List<_Subscription> _subscriptions;
  final Map<String, SavedEpisode> _episodes;
  final Map<String, double> _progress;
  final Map<String, String> _settings;

  static const int _version = 2;

  /// Opens (creating if needed) the library database. Tests pass an FFI
  /// [factory] and [inMemoryDatabasePath].
  static Future<Library> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join((await getApplicationSupportDirectory()).path, 'tinycast.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: _version, onCreate: _create, onUpgrade: _upgrade),
    );
    final subscriptions = [
      for (final row in await db.query('subscriptions', orderBy: 'subscribed_at DESC'))
        _Subscription(_podcastFromRow(row, ''), DateTime.fromMillisecondsSinceEpoch(row['subscribed_at']! as int)),
    ];
    final episodes = {
      for (final row in await db.query('episodes'))
        _key(row['feed']! as String, row['id']! as String): _savedFromRow(row),
    };
    final progress = {
      for (final row in await db.query('progress'))
        _key(row['feed']! as String, row['id']! as String): (row['position']! as num).toDouble(),
    };
    final settings = {for (final row in await db.query('settings')) row['key']! as String: row['value']! as String};
    return Library._(db, subscriptions, episodes, progress, settings);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE subscriptions (
          feed TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT,
          artwork TEXT,
          genre TEXT,
          subscribed_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE episodes (
          feed TEXT NOT NULL,
          id TEXT NOT NULL,
          podcast_title TEXT NOT NULL,
          podcast_author TEXT,
          podcast_artwork TEXT,
          podcast_genre TEXT,
          title TEXT NOT NULL,
          audio TEXT NOT NULL,
          description TEXT,
          published INTEGER,
          duration REAL,
          number INTEGER,
          season INTEGER,
          type TEXT,
          explicit INTEGER,
          artwork TEXT,
          mime_type TEXT,
          bytes INTEGER,
          link TEXT,
          favorited_at INTEGER,
          download_path TEXT,
          downloaded_at INTEGER,
          PRIMARY KEY (feed, id)
        )''')
      ..execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    _createProgress(batch);
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    final batch = db.batch();
    if (from < 2) _createProgress(batch);
    await batch.commit(noResult: true);
  }

  static void _createProgress(Batch batch) => batch.execute('''
    CREATE TABLE progress (
      feed TEXT NOT NULL,
      id TEXT NOT NULL,
      position REAL NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (feed, id)
    )''');

  Future<void> close() => _db.close();

  /* --------------------------------------------------------- subscriptions -- */

  /// Most recently subscribed first.
  List<Podcast> get subscriptions => [for (final s in _subscriptions) s.podcast];

  bool isSubscribed(Podcast podcast) => _subscriptions.any((s) => s.podcast.feed == podcast.feed);

  Future<void> subscribe(Podcast podcast) async {
    if (isSubscribed(podcast)) return;
    final now = DateTime.now();
    _subscriptions.insert(0, _Subscription(podcast, now));
    notifyListeners();
    await _db.insert('subscriptions', {
      'feed': podcast.feed.toString(),
      'title': podcast.title,
      'author': podcast.author,
      'artwork': podcast.artwork,
      'genre': podcast.genre,
      'subscribed_at': now.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unsubscribe(Podcast podcast) async {
    _subscriptions.removeWhere((s) => s.podcast.feed == podcast.feed);
    notifyListeners();
    await _db.delete('subscriptions', where: 'feed = ?', whereArgs: [podcast.feed.toString()]);
  }

  /* ------------------------------------------------------------- episodes -- */

  SavedEpisode? saved(Podcast podcast, PodcastEpisode episode) => _episodes[_key(podcast.feed.toString(), episode.id)];

  /// Favorites, most recently added first.
  List<SavedEpisode> get favorites =>
      _episodes.values.where((e) => e.isFavorite).toList()..sort((a, b) => b.favoritedAt!.compareTo(a.favoritedAt!));

  /// Downloads, most recently downloaded first.
  List<SavedEpisode> get downloaded =>
      _episodes.values.where((e) => e.isDownloaded).toList()
        ..sort((a, b) => (b.downloadedAt ?? DateTime(0)).compareTo(a.downloadedAt ?? DateTime(0)));

  bool isFavorite(Podcast podcast, PodcastEpisode episode) => saved(podcast, episode)?.isFavorite ?? false;

  Future<void> favorite(Podcast podcast, PodcastEpisode episode) =>
      _update(podcast, episode, (s) => s.copyWith(favoritedAt: () => s.favoritedAt ?? DateTime.now()));

  Future<void> unfavorite(Podcast podcast, PodcastEpisode episode) =>
      _update(podcast, episode, (s) => s.copyWith(favoritedAt: () => null));

  /// Where [episode] was downloaded to, if it was.
  String? downloadPath(Podcast podcast, PodcastEpisode episode) => saved(podcast, episode)?.downloadPath;

  Future<void> recordDownload(Podcast podcast, PodcastEpisode episode, String path) =>
      _update(podcast, episode, (s) => s.copyWith(downloadPath: () => path, downloadedAt: () => DateTime.now()));

  Future<void> forgetDownload(Podcast podcast, PodcastEpisode episode) =>
      _update(podcast, episode, (s) => s.copyWith(downloadPath: () => null, downloadedAt: () => null));

  /// Applies [change] to the saved copy of [episode] (refreshing its details),
  /// dropping the row once it is neither a favorite nor a download.
  Future<void> _update(Podcast podcast, PodcastEpisode episode, SavedEpisode Function(SavedEpisode) change) async {
    final feed = podcast.feed.toString();
    final key = _key(feed, episode.id);
    final current = _episodes[key] ?? SavedEpisode(podcast: podcast, episode: episode);
    final next = change(current.copyWith(podcast: podcast, episode: episode));
    if (!next.isFavorite && !next.isDownloaded) {
      if (_episodes.remove(key) == null) return;
      notifyListeners();
      await _db.delete('episodes', where: 'feed = ? AND id = ?', whereArgs: [feed, episode.id]);
      return;
    }
    _episodes[key] = next;
    notifyListeners();
    await _db.insert('episodes', _savedToRow(next), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /* ------------------------------------------------------------- progress -- */

  /// How far into [episode] the user got, in seconds, if they left it part-way.
  double? progress(Podcast podcast, PodcastEpisode episode) => _progress[_key(podcast.feed.toString(), episode.id)];

  /// Records how far into [episode] the user got; null forgets it. Not
  /// notified, since it changes every few seconds while a tape plays.
  Future<void> setProgress(Podcast podcast, PodcastEpisode episode, double? position) async {
    final feed = podcast.feed.toString();
    final key = _key(feed, episode.id);
    if (position == null) {
      if (_progress.remove(key) == null) return;
      await _db.delete('progress', where: 'feed = ? AND id = ?', whereArgs: [feed, episode.id]);
      return;
    }
    if (_progress[key] == position) return;
    _progress[key] = position;
    await _db.insert('progress', {
      'feed': feed,
      'id': episode.id,
      'position': position,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /* ------------------------------------------------------------- settings -- */

  String? setting(String key) => _settings[key];

  /// Stores [value] under [key]; null removes it.
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
      notifyListeners();
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      _settings[key] = value;
      notifyListeners();
      await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

class _Subscription {
  const _Subscription(this.podcast, this.subscribedAt);
  final Podcast podcast;
  final DateTime subscribedAt;
}

String _key(String feed, String id) => '$feed\n$id';

DateTime? _time(Object? millis) => millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);

/// Reads a podcast from a row; [prefix] is '' for subscriptions, 'podcast_' for episodes.
Podcast _podcastFromRow(Map<String, Object?> row, String prefix) => Podcast(
  title: row['${prefix}title']! as String,
  feed: Uri.parse(row['feed']! as String),
  author: row['${prefix}author'] as String?,
  artwork: row['${prefix}artwork'] as String?,
  genre: row['${prefix}genre'] as String?,
);

SavedEpisode _savedFromRow(Map<String, Object?> row) => SavedEpisode(
  podcast: _podcastFromRow(row, 'podcast_'),
  episode: PodcastEpisode(
    id: row['id']! as String,
    title: row['title']! as String,
    audio: Uri.parse(row['audio']! as String),
    description: row['description'] as String?,
    published: _time(row['published'])?.toUtc(),
    duration: (row['duration'] as num?)?.toDouble(),
    number: row['number'] as int?,
    season: row['season'] as int?,
    type: row['type'] as String?,
    explicit: switch (row['explicit']) {
      null => null,
      final v => v == 1,
    },
    artwork: row['artwork'] as String?,
    mimeType: row['mime_type'] as String?,
    bytes: row['bytes'] as int?,
    link: switch (row['link']) {
      final String l => Uri.tryParse(l),
      _ => null,
    },
  ),
  favoritedAt: _time(row['favorited_at']),
  downloadPath: row['download_path'] as String?,
  downloadedAt: _time(row['downloaded_at']),
);

Map<String, Object?> _savedToRow(SavedEpisode s) {
  final e = s.episode;
  return {
    'feed': s.podcast.feed.toString(),
    'id': e.id,
    'podcast_title': s.podcast.title,
    'podcast_author': s.podcast.author,
    'podcast_artwork': s.podcast.artwork,
    'podcast_genre': s.podcast.genre,
    'title': e.title,
    'audio': e.audio.toString(),
    'description': e.description,
    'published': e.published?.millisecondsSinceEpoch,
    'duration': e.duration,
    'number': e.number,
    'season': e.season,
    'type': e.type,
    'explicit': switch (e.explicit) {
      null => null,
      true => 1,
      false => 0,
    },
    'artwork': e.artwork,
    'mime_type': e.mimeType,
    'bytes': e.bytes,
    'link': e.link?.toString(),
    'favorited_at': s.favoritedAt?.millisecondsSinceEpoch,
    'download_path': s.downloadPath,
    'downloaded_at': s.downloadedAt?.millisecondsSinceEpoch,
  };
}
