import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tinycast/deck/tape_deck.dart';
import 'package:tinycast/deck/textures.dart';
import 'package:tinycast/deck/transport.dart';
import 'package:tinycast/library/downloads.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/main.dart';
import 'package:tinycast/pages/episode_page.dart';
import 'package:tinycast/pages/player_page.dart';
import 'package:tinycast/pages/podcast_page.dart';
import 'package:tinycast/playback/playback.dart';
import 'package:tinycast/podcast/directory.dart';
import 'package:tinycast/podcast/models.dart';

import 'test_library.dart';

final Podcast _show = Podcast(
  title: 'Gadget Hour',
  author: 'Two Nerds',
  feed: Uri.parse('https://example.com/feed.xml'),
  genre: 'Technology',
);

final String _longNotes = List.filled(40, 'Phones, laptops and everything in between.').join(' ');

final PodcastFeed _feed = PodcastFeed(
  title: 'Gadget Hour',
  author: 'Two Nerds',
  description: 'A weekly hour about gadgets.',
  episodes: [
    PodcastEpisode(
      id: 'ep-12',
      title: 'Folding phones, revisited',
      audio: Uri.parse('https://example.com/12.mp3'),
      description: _longNotes,
      published: DateTime.utc(2026, 10, 9),
      duration: 3725,
      number: 12,
      season: 2,
      bytes: 59000000,
      mimeType: 'audio/mpeg',
    ),
    PodcastEpisode(
      id: 'ep-11',
      title: 'Laptops',
      audio: Uri.parse('https://example.com/11.mp3'),
      published: DateTime.utc(2026, 10, 2),
    ),
  ],
);

class _FakeDirectory implements PodcastDirectory {
  final List<String> searches = [];

  @override
  Future<List<Podcast>> search(String term) async {
    searches.add(term);
    return [_show];
  }

  @override
  Future<PodcastFeed> feed(Podcast podcast) async => _feed;
}

/// Threads sources instantly, without a real audio player.
class _FakeTransport extends Transport {
  _FakeTransport() : super(0);

  final List<AudioSource> loaded = [];

  @override
  Future<double> load(AudioSource source, {bool autoplay = false}) async {
    loaded.add(source);
    if (autoplay) play();
    return duration;
  }
}

/// "Downloads" by writing a small file, without the network.
class _FakeDownloads extends Downloads {
  _FakeDownloads(super.library, this.dir);

  final Directory dir;
  final List<String> started = [];

  @override
  Future<void> start(Podcast podcast, PodcastEpisode episode) async {
    started.add(episode.id);
    final file = File('${dir.path}/${episode.id}.mp3')..writeAsBytesSync([1, 2, 3]);
    await library.recordDownload(podcast, episode, file.path);
  }
}

void main() {
  late Library library;
  late Directory folder;

  setUpAll(() async {
    await Textures.load();
  });

  setUp(() async {
    library = await openTestLibrary();
    folder = Directory.systemTemp.createTempSync('tinycast_downloads');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1240, 880);
    view.devicePixelRatio = 1;
  });

  testWidgets('search → show → episode → play opens the deck', (tester) async {
    final directory = _FakeDirectory();
    final transport = _FakeTransport();
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: directory,
        playback: Playback(transport: transport),
      ),
    );
    await tester.pump();

    // Search, debounced while typing.
    await tester.enterText(find.byType(EditableText), 'gadgets');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(directory.searches, ['gadgets']);
    await tester.tap(find.text('Gadget Hour'));
    await tester.pumpAndSettle();

    // The show: description and episodes, long notes cut short.
    expect(find.byType(PodcastPage), findsOneWidget);
    expect(find.text('A weekly hour about gadgets.'), findsOneWidget);
    expect(find.text('2 EPISODES'), findsOneWidget);
    final notes = tester.widget<Text>(find.textContaining('Phones, laptops'));
    expect(notes.maxLines, 2);
    expect(notes.overflow, TextOverflow.ellipsis);

    await tester.tap(find.text('Folding phones, revisited'));
    await tester.pumpAndSettle();

    // The episode: artwork, metadata, full notes; nothing plays yet.
    expect(find.byType(EpisodePage), findsOneWidget);
    expect(find.byKey(const Key('episode-art')), findsOneWidget);
    for (final meta in ['Oct 9, 2026', '1 hr 2 min', 'Season 2', 'Episode 12', '59 MB', 'MP3']) {
      expect(find.text(meta), findsOneWidget, reason: meta);
    }
    expect(find.byType(PlayerPage), findsNothing);
    expect(transport.loaded, isEmpty);

    await tester.tap(find.byKey(const Key('play-episode')));
    // The deck animates every frame, so it never settles; let the route finish.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Play threads the episode and opens the deck with its label.
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(transport.loaded, hasLength(1));
    expect(transport.playing, isTrue);
    final deck = tester.widget<TapeDeck>(find.byType(TapeDeck));
    expect(deck.episode.title, 'Folding phones, revisited');
    expect(deck.episode.show, 'Gadget Hour');
    expect(deck.episode.tag, 'EP. 12');

    // Closing the deck keeps playing and offers a way back.
    await tester.tap(find.byKey(const Key('close-player')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PlayerPage), findsNothing);
    expect(transport.playing, isTrue);
    expect(find.text('Now playing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('now-playing-toggle')));
    await tester.pump();
    expect(transport.playing, isFalse);
    await tester.tap(find.byKey(const Key('now-playing')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PlayerPage), findsOneWidget);
  });

  testWidgets('the featured show opens before any search', (tester) async {
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: _FakeDirectory(),
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('featured')));
    await tester.pumpAndSettle();
    expect(find.byType(PodcastPage), findsOneWidget);
    expect(find.text(waveform.title), findsWidgets);
  });

  testWidgets('subscribe, sort, favorite and download', (tester) async {
    final downloads = _FakeDownloads(library, folder);
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        downloads: downloads,
        directory: _FakeDirectory(),
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();
    expect(find.text('Shows you subscribe to will appear here.'), findsOneWidget);
    expect(find.text('Tap the heart on an episode to keep it here.'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'gadgets');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Gadget Hour'));
    await tester.pumpAndSettle();

    // Subscribe.
    expect(find.text('Subscribe'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscribe')));
    await tester.pump();
    expect(find.text('Subscribed'), findsOneWidget);
    expect(library.isSubscribed(_show), isTrue);

    // Newest first by default; Oldest flips it.
    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(top('Folding phones, revisited'), lessThan(top('Laptops')));
    await tester.tap(find.text('Oldest'));
    await tester.pumpAndSettle();
    expect(top('Laptops'), lessThan(top('Folding phones, revisited')));
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(top('Folding phones, revisited'), lessThan(top('Laptops')));

    // Favorite and download from the episode page.
    await tester.tap(find.text('Folding phones, revisited'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite')));
    await tester.pump();
    expect(library.favorites.single.episode.id, 'ep-12');
    await tester.tap(find.byKey(const Key('download')));
    await tester.pumpAndSettle();
    expect(downloads.started, ['ep-12']);
    expect(find.byKey(const Key('delete-download')), findsOneWidget);
    expect(find.textContaining('Downloaded'), findsOneWidget);

    // Delete the download, after confirming.
    final file = File(library.downloadPath(_show, _feed.episodes.first)!);
    await tester.tap(find.byKey(const Key('delete-download')));
    await tester.pumpAndSettle();
    expect(find.text('Delete download?'), findsOneWidget);
    // The dialog's button, not the "Delete" link under the actions.
    await tester.tap(find.text('Delete').last);
    // Deleting is real file I/O, which fake time does not advance.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(file.existsSync(), isFalse);
    expect(find.byKey(const Key('download')), findsOneWidget);
    // Still a favorite.
    expect(library.isFavorite(_show, _feed.episodes.first), isTrue);

    // Home now lists the show and the episode.
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byKey(const Key('your-podcasts')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('your-podcasts')), matching: find.text('Gadget Hour')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('favorite-ep-12')), findsOneWidget);

    // Opening a favorite works without the feed.
    await tester.tap(find.text('Folding phones, revisited'));
    await tester.pumpAndSettle();
    expect(find.byType(EpisodePage), findsOneWidget);
    expect(find.text('Episode 12'), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    // Remove it from favorites right from the list.
    await tester.tap(find.byKey(const ValueKey('unfavorite-ep-12')));
    await tester.pump();
    expect(find.byKey(const ValueKey('favorite-ep-12')), findsNothing);
    expect(library.favorites, isEmpty);
  });
}
