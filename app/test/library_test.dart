import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinycast/library/downloads.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/podcast/models.dart';

final Podcast _show = Podcast(
  title: 'Gadget Hour',
  author: 'Two Nerds',
  feed: Uri.parse('https://example.com/feed.xml'),
  artwork: 'https://example.com/art.jpg',
);

PodcastEpisode _episode(String id, {Uri? audio, int? bytes}) => PodcastEpisode(
  id: id,
  title: 'Episode $id: phones/laptops?',
  audio: audio ?? Uri.parse('https://example.com/$id.mp3'),
  description: 'Notes for $id',
  published: DateTime.utc(2026, 10, 9, 8),
  duration: 3725,
  number: 12,
  explicit: false,
  mimeType: 'audio/mpeg',
  bytes: bytes,
);

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tinycast_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<Library> open() => Library.open(factory: databaseFactoryFfiNoIsolate, path: p.join(temp.path, 'library.db'));

  test('subscriptions persist, newest first', () async {
    final other = Podcast(title: 'Other', feed: Uri.parse('https://example.com/other.xml'));
    var library = await open();
    await library.subscribe(_show);
    await library.subscribe(other);
    expect(library.subscriptions.map((s) => s.title), ['Other', 'Gadget Hour']);
    await library.close();

    library = await open();
    expect(library.subscriptions.map((s) => s.title), ['Other', 'Gadget Hour']);
    expect(library.isSubscribed(_show), isTrue);
    expect(library.subscriptions.last.artwork, 'https://example.com/art.jpg');
    await library.unsubscribe(_show);
    await library.close();

    library = await open();
    expect(library.isSubscribed(_show), isFalse);
    expect(library.subscriptions, hasLength(1));
    await library.close();
  });

  test('favorites keep a full copy of the episode and survive a restart', () async {
    var library = await open();
    await library.favorite(_show, _episode('a'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await library.favorite(_show, _episode('b'));
    expect(library.favorites.map((f) => f.episode.id), ['b', 'a']);
    await library.close();

    library = await open();
    final saved = library.favorites.last;
    expect(saved.podcast.title, 'Gadget Hour');
    expect(saved.podcast.artwork, 'https://example.com/art.jpg');
    expect(saved.episode.title, 'Episode a: phones/laptops?');
    expect(saved.episode.published, DateTime.utc(2026, 10, 9, 8));
    expect(saved.episode.duration, 3725);
    expect(saved.episode.number, 12);
    expect(saved.episode.explicit, isFalse);
    expect(saved.episode.audio, Uri.parse('https://example.com/a.mp3'));

    await library.unfavorite(_show, _episode('a'));
    expect(library.isFavorite(_show, _episode('a')), isFalse);
    expect(library.saved(_show, _episode('a')), isNull);
    await library.close();
  });

  test('an episode stays saved while it is a favorite or a download', () async {
    final library = await open();
    final e = _episode('a');
    await library.favorite(_show, e);
    await library.recordDownload(_show, e, '/tmp/a.mp3');
    await library.unfavorite(_show, e);
    expect(library.downloadPath(_show, e), '/tmp/a.mp3');
    expect(library.favorites, isEmpty);
    await library.forgetDownload(_show, e);
    expect(library.saved(_show, e), isNull);
    await library.close();
  });

  test('settings', () async {
    final library = await open();
    expect(library.setting(downloadFolderSetting), isNull);
    await library.setSetting(downloadFolderSetting, '/Volumes/Podcasts');
    expect(library.setting(downloadFolderSetting), '/Volumes/Podcasts');
    await library.setSetting(downloadFolderSetting, null);
    expect(library.setting(downloadFolderSetting), isNull);
    await library.close();
  });

  test('listening progress survives a restart', () async {
    var library = await open();
    final episode = _episode('a');
    expect(library.progress(_show, episode), isNull);
    await library.setProgress(_show, episode, 754.5);
    await library.close();

    library = await open();
    expect(library.progress(_show, episode), 754.5);
    await library.setProgress(_show, episode, null);
    await library.close();

    library = await open();
    expect(library.progress(_show, episode), isNull);
    await library.close();
  });

  test('a version 1 library gains listening progress', () async {
    final path = p.join(temp.path, 'library.db');
    var library = await open();
    await library.subscribe(_show);
    await library.close();
    // Roll the file back to the first schema.
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await db.execute('DROP TABLE progress');
    await db.setVersion(1);
    await db.close();

    library = await open();
    expect(library.isSubscribed(_show), isTrue);
    await library.setProgress(_show, _episode('a'), 60);
    expect(library.progress(_show, _episode('a')), 60);
    await library.close();
  });

  test('episodes left part-way are listed with a copy of each, most recent first', () async {
    var library = await open();
    final changes = <void>[];
    library.progressChanges.addListener(() => changes.add(null));
    await library.setProgress(_show, _episode('a'), 600, length: 4000);
    await library.setProgress(_show, _episode('b'), 120);
    expect(changes, hasLength(2));
    await library.close();

    library = await open();
    final listening = library.listening;
    expect([for (final l in listening) l.episode.id], ['b', 'a']);
    final a = listening.last;
    expect(a.podcast.title, 'Gadget Hour');
    expect(a.podcast.artwork, 'https://example.com/art.jpg');
    expect(a.episode.title, 'Episode a: phones/laptops?');
    expect(a.episode.description, 'Notes for a');
    // The length the player found wins over the feed's.
    expect(a.total, 4000);
    expect(a.fraction, closeTo(0.15, 1e-9));
    expect(listening.first.total, 3725);

    // A later save without a length keeps the one already known.
    await library.setProgress(_show, _episode('a'), 700);
    expect(library.listeningTo(_show, _episode('a'))!.total, 4000);
    expect(library.listening.first.episode.id, 'a');

    await library.setProgress(_show, _episode('a'), null);
    expect([for (final l in library.listening) l.episode.id], ['b']);
    await library.close();
  });

  test('a version 2 library keeps its progress and lists it once replayed', () async {
    final path = p.join(temp.path, 'library.db');
    var library = await open();
    await library.close();
    // Roll the file back to the second schema, with a bare progress row.
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await db.execute('DROP TABLE progress');
    await db.execute('''
      CREATE TABLE progress (
        feed TEXT NOT NULL,
        id TEXT NOT NULL,
        position REAL NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (feed, id)
      )''');
    await db.insert('progress', {'feed': _show.feed.toString(), 'id': 'a', 'position': 90, 'updated_at': 0});
    await db.setVersion(2);
    await db.close();

    library = await open();
    expect(library.progress(_show, _episode('a')), 90);
    // Nothing to show it with until it is played again.
    expect(library.listening, isEmpty);
    await library.setProgress(_show, _episode('a'), 95);
    expect(library.listening.single.episode.title, 'Episode a: phones/laptops?');
    await library.close();
  });

  group('downloads', () {
    late HttpServer server;
    final audio = List<int>.generate(200000, (i) => i % 256);
    Completer<void>? hold;

    setUp(() async {
      hold = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final r = request.response;
        switch (request.uri.path) {
          case '/redirect.mp3':
            await r.redirect(Uri.parse('http://127.0.0.1:${server.port}/a.mp3'));
          case '/a.mp3':
            r.contentLength = audio.length;
            // Enough to get past the server's output buffer before pausing.
            r.add(audio.sublist(0, 100000));
            await r.flush();
            await hold?.future;
            r.add(audio.sublist(100000));
            await r.close();
          default:
            r.statusCode = HttpStatus.notFound;
            await r.close();
        }
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    test('saves into <folder>/<show>/<title> and can be deleted', () async {
      final library = await open();
      final downloads = Downloads(library, defaultFolder: () async => p.join(temp.path, '.tinycast', 'downloads'));
      final e = _episode('a', audio: url('/redirect.mp3'));
      final progress = <double?>[];
      downloads.addListener(() => progress.add(downloads.progress(_show, e)));

      await downloads.start(_show, e);
      final path = downloads.localFile(_show, e)!;
      expect(path, p.join(temp.path, '.tinycast', 'downloads', 'Gadget Hour', 'Episode a phones laptops.mp3'));
      expect(await File(path).readAsBytes(), audio);
      expect(progress.whereType<double>().last, 1.0);
      expect(downloads.isDownloading(_show, e), isFalse);

      await downloads.delete(_show, e);
      expect(File(path).existsSync(), isFalse);
      expect(downloads.localFile(_show, e), isNull);
      expect(library.saved(_show, e), isNull);
      await library.close();
    });

    test('uses the folder the user picked', () async {
      final library = await open();
      final downloads = Downloads(library, defaultFolder: () async => p.join(temp.path, 'default'));
      await downloads.setFolder(p.join(temp.path, 'picked'));
      final e = _episode('a', audio: url('/a.mp3'));
      await downloads.start(_show, e);
      expect(p.isWithin(p.join(temp.path, 'picked'), downloads.localFile(_show, e)!), isTrue);
      await library.close();
    });

    test('cancelling leaves nothing behind', () async {
      final library = await open();
      final downloads = Downloads(library, defaultFolder: () async => temp.path);
      final e = _episode('a', audio: url('/a.mp3'));
      hold = Completer<void>();
      final running = downloads.start(_show, e);
      while (downloads.progress(_show, e) == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(downloads.isDownloading(_show, e), isTrue);
      downloads.cancel(_show, e);
      expect(downloads.isDownloading(_show, e), isFalse);
      await running;
      hold!.complete();
      expect(downloads.localFile(_show, e), isNull);
      expect(downloads.error(_show, e), isNull);
      final leftovers = temp
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !p.basename(f.path).startsWith('library.db'));
      expect(leftovers, isEmpty);
      await library.close();
    });

    test('a failed download is reported and not recorded', () async {
      final library = await open();
      final downloads = Downloads(library, defaultFolder: () async => temp.path);
      final e = _episode('a', audio: url('/missing.mp3'));
      await downloads.start(_show, e);
      expect(downloads.error(_show, e), 'Download failed');
      expect(downloads.localFile(_show, e), isNull);
      await library.close();
    });

    test('a file deleted behind the app’s back is forgotten', () async {
      final library = await open();
      final downloads = Downloads(library, defaultFolder: () async => temp.path);
      final e = _episode('a', audio: url('/a.mp3'));
      await downloads.start(_show, e);
      await File(downloads.localFile(_show, e)!).delete();
      expect(downloads.localFile(_show, e), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(library.saved(_show, e), isNull);
      await library.close();
    });
  });
}
