import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/pages/library_page.dart' show importSummary;
import 'package:tinycast/podcast/models.dart';

import 'test_library.dart';

final Podcast _show = Podcast(
  title: 'Gadget Hour',
  author: 'Two Nerds',
  feed: Uri.parse('https://example.com/feed.xml'),
  artwork: 'https://example.com/art.jpg',
);
final Podcast _other = Podcast(title: 'Other', feed: Uri.parse('https://example.com/other.xml'));

PodcastEpisode _episode(String id) => PodcastEpisode(
  id: id,
  title: 'Episode $id',
  audio: Uri.parse('https://example.com/$id.mp3'),
  published: DateTime.utc(2026, 10, 9, 8),
  duration: 3725,
  number: 12,
);

/// An export as it comes back out of a file.
Object? _throughFile(Library library) => jsonDecode(jsonEncode(library.export()));

/// Lets the clock move on, so later writes are newer.
Future<void> _later() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('two devices swap libraries, each keeping what is newer', () async {
    final phone = await openTestLibrary();
    final mac = await openTestLibrary();
    final one = _episode('1');
    final two = _episode('2');
    final three = _episode('3');

    await phone.subscribe(_show);
    await phone.favorite(_show, one);
    await phone.recordDownload(_show, one, '/phone/1.mp3');
    await phone.setProgress(_show, two, 100, length: 3700);
    await _later();
    await mac.subscribe(_other);
    await mac.setProgress(_show, two, 300);
    await mac.setProgress(_show, three, 50);

    // Phone → Mac: the show and the favorite come over; the Mac's own
    // position in episode 2 is newer, so it stays.
    var result = await mac.import(_throughFile(phone));
    expect((result.subscriptions, result.favorites, result.progress), (1, 1, 0));
    expect(mac.subscriptions.map((s) => s.title), ['Other', 'Gadget Hour']);
    expect(mac.isFavorite(_show, one), isTrue);
    // Downloads are the phone's own.
    expect(mac.downloadPath(_show, one), isNull);
    expect(mac.progress(_show, two), 300);

    // Mac → Phone: the other show, and both of the Mac's newer positions.
    result = await phone.import(_throughFile(mac));
    expect((result.subscriptions, result.favorites, result.progress), (1, 0, 2));
    expect(phone.subscriptions.map((s) => s.title), ['Other', 'Gadget Hour']);
    expect(phone.downloadPath(_show, one), '/phone/1.mp3');
    expect(phone.progress(_show, two), 300);
    expect(phone.progress(_show, three), 50);
    expect(phone.listening.map((l) => l.episode.title), containsAll(['Episode 2', 'Episode 3']));

    // Again: nothing new either way.
    expect((await mac.import(_throughFile(phone))).isEmpty, isTrue);
    expect((await phone.import(_throughFile(mac))).isEmpty, isTrue);
    await phone.close();
    await mac.close();
  });

  test('an import is saved', () async {
    final phone = await openTestLibrary();
    await phone.subscribe(_show);
    await phone.favorite(_show, _episode('1'));
    await phone.setProgress(_show, _episode('2'), 100);
    final file = _throughFile(phone);

    final dir = await Directory.systemTemp.createTemp('tinycast_test');
    final path = p.join(dir.path, 'library.db');
    var mac = await Library.open(factory: databaseFactoryFfiNoIsolate, path: path);
    await mac.import(file);
    await mac.close();

    mac = await Library.open(factory: databaseFactoryFfiNoIsolate, path: path);
    expect(mac.isSubscribed(_show), isTrue);
    expect(mac.isFavorite(_show, _episode('1')), isTrue);
    expect(mac.listening.single.position, 100);
    expect((await mac.import(file)).isEmpty, isTrue);
    await phone.close();
    await mac.close();
  });

  test('files that are not a library export are refused, the library untouched', () async {
    final library = await openTestLibrary();
    Future<String> refusal(Object? data) async {
      try {
        await library.import(data);
      } on FormatException catch (e) {
        return e.message;
      }
      return 'accepted';
    }

    expect(await refusal([1, 2]), 'Not a tinycast library file');
    expect(await refusal({'app': 'other', 'format': 1}), 'Not a tinycast library file');
    expect(await refusal({'app': 'tinycast', 'format': 99}), contains('newer version'));
    expect(
      await refusal({
        'app': 'tinycast',
        'format': 1,
        'subscriptions': [
          {'feed': 'https://example.com/ok.xml', 'title': 'Fine', 'subscribed_at': 1},
          {'feed': 'https://example.com/bad.xml'},
        ],
      }),
      'This library file is damaged',
    );
    expect(library.subscriptions, isEmpty);
    await library.close();
  });

  test('the import summary', () {
    LibraryImport r(int s, int f, int p) => LibraryImport(subscriptions: s, favorites: f, progress: p);
    expect(importSummary(r(0, 0, 0)), startsWith('Already up to date'));
    expect(importSummary(r(1, 0, 0)), 'Added 1 show.');
    expect(importSummary(r(2, 1, 0)), 'Added 2 shows and 1 favorite.');
    expect(importSummary(r(2, 1, 5)), 'Added 2 shows, 1 favorite and 5 listening positions.');
  });
}
