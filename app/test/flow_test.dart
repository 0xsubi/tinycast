import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tinycast/deck/tape_deck.dart';
import 'package:tinycast/deck/textures.dart';
import 'package:tinycast/deck/transport.dart';
import 'package:tinycast/library/downloads.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/library/searches.dart';
import 'package:tinycast/main.dart';
import 'package:tinycast/pages/episode_page.dart';
import 'package:tinycast/pages/interests_page.dart';
import 'package:tinycast/pages/player_page.dart';
import 'package:tinycast/pages/podcast_page.dart';
import 'package:tinycast/playback/playback.dart';
import 'package:tinycast/podcast/directory.dart';
import 'package:tinycast/podcast/interests.dart';
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
  Future<List<Podcast>> top(int genre) async {
    charts.add(genre);
    return [Podcast(title: 'Top show $genre', feed: Uri.parse('https://example.com/top-$genre.xml'), author: 'Charts')];
  }

  final List<int> charts = [];

  @override
  Future<PodcastFeed> feed(Podcast podcast) async => _feed;
}

/// Threads sources instantly, without a real audio player.
class _FakeTransport extends Transport {
  _FakeTransport() : super(0);

  final List<AudioSource> loaded = [];
  final List<double> startedAt = [];

  @override
  Future<double> load(AudioSource source, {bool autoplay = false, double startAt = 0}) async {
    loaded.add(source);
    startedAt.add(startAt);
    seek(startAt);
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

  /// Past onboarding, having skipped choosing interests.
  Future<void> onboarded() => chooseInterests(library, const []);

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text(label)).first);
    await tester.pumpAndSettle();
  }

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1240, 880);
    view.devicePixelRatio = 1;
  });

  testWidgets('search → show → episode → play opens the deck', (tester) async {
    await onboarded();
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
    await openTab(tester, 'Search');
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

  testWidgets('an episode left part-way resumes ten seconds back', (tester) async {
    final transport = _FakeTransport()..duration = 3725;
    final playback = Playback(transport: transport, library: library);
    final first = _feed.episodes[0];
    final second = _feed.episodes[1];

    await playback.playEpisode(_show, first);
    expect(transport.startedAt.last, 0);
    transport.seek(600);
    transport.pause();
    expect(library.progress(_show, first), closeTo(600, 0.01));

    // Saved every few seconds while playing, and on switching episodes.
    transport.play();
    transport.seek(900);
    await tester.pump(const Duration(seconds: 6));
    expect(library.progress(_show, first), closeTo(900, 0.5));
    transport.seek(1200);
    await playback.playEpisode(_show, second);
    expect(library.progress(_show, first), closeTo(1200, 0.01));

    await playback.playEpisode(_show, first);
    expect(transport.startedAt.last, closeTo(1190, 0.01));
    expect(transport.time, closeTo(1190, 0.01));

    // Stopping at the very end counts as finished.
    transport.seek(3720);
    transport.pause();
    expect(library.progress(_show, first), isNull);
    playback.dispose();
  });

  testWidgets('first run asks for interests, then shows their top shows', (tester) async {
    final directory = _FakeDirectory();
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: directory,
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();
    expect(find.byType(InterestsPage), findsOneWidget);
    expect(find.text('What do you like to listen to?'), findsOneWidget);

    // Nothing picked yet, so Continue does nothing.
    await tester.tap(find.byKey(const Key('save-interests')), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(InterestsPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('interest-1487'))); // History
    await tester.tap(find.byKey(const ValueKey('interest-1318'))); // Technology
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-interests')));
    await tester.pumpAndSettle();
    expect(chosenInterests(library)!.map((i) => i.name), ['History', 'Technology']);

    // Home: a row per interest, in the order picked.
    expect(find.byType(InterestsPage), findsNothing);
    expect(directory.charts, [1487, 1318]);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('TECHNOLOGY'), findsOneWidget);
    expect(tester.getTopLeft(find.text('HISTORY')).dy, lessThan(tester.getTopLeft(find.text('TECHNOLOGY')).dy));
    await tester.tap(find.text('Top show 1487'));
    await tester.pumpAndSettle();
    expect(find.byType(PodcastPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    // Edit: drop History, add Fashion.
    await tester.tap(find.byKey(const Key('edit-interests')));
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('interest-1487')));
    await tester.tap(find.byKey(const ValueKey('interest-1459')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-interests')));
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsNothing);
    expect(find.text('HISTORY'), findsNothing);
    expect(find.text('TECHNOLOGY'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('FASHION & BEAUTY'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('FASHION & BEAUTY'), findsOneWidget);
  });

  testWidgets('first run can be skipped', (tester) async {
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: _FakeDirectory(),
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('skip-interests')));
    await tester.pumpAndSettle();
    expect(find.byType(InterestsPage), findsNothing);
    expect(find.text('Pick a few topics to see their top shows here.'), findsOneWidget);
    expect(chosenInterests(library), isEmpty);
  });

  testWidgets('search lists recent searches before a search', (tester) async {
    await onboarded();
    final directory = _FakeDirectory();
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: directory,
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();

    // On a wide window the tab bar stays compact, centred.
    double x(String label) =>
        tester.getCenter(find.descendant(of: find.byKey(const Key('tab-bar')), matching: find.text(label)).first).dx;
    expect(x('Home'), greaterThan((1240 - 380) / 2));
    expect(x('Search'), lessThan((1240 + 380) / 2));
    expect((x('Home') + x('Search')) / 2, closeTo(1240 / 2, 1));

    await openTab(tester, 'Search');
    expect(find.text('Search millions of shows from the Apple Podcasts directory.'), findsOneWidget);
    expect(find.byKey(const Key('featured')), findsNothing);

    Future<void> type(String text) async {
      await tester.enterText(find.byType(EditableText), text);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    }

    // Typing alone searches but is not remembered…
    await type('gad');
    expect(directory.searches, ['gad']);
    expect(recentSearches(library), isEmpty);
    // …opening a show the search found is…
    await type('gadgets');
    await tester.tap(find.text('Gadget Hour'));
    await tester.pumpAndSettle();
    expect(find.byType(PodcastPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    // …and so is pressing Return, most recent first.
    await tester.enterText(find.byType(EditableText), 'Phones');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(recentSearches(library), ['Phones', 'gadgets']);

    await type('');
    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-Phones')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recent-gadgets')));
    await tester.pump();
    expect(directory.searches.last, 'gadgets');
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'gadgets');
    expect(recentSearches(library), ['gadgets', 'Phones']);
    await tester.pumpAndSettle();
    expect(find.text('Gadget Hour'), findsWidgets);

    await type('');
    await tester.tap(find.byKey(const Key('clear-searches')));
    await tester.pump();
    expect(recentSearches(library), isEmpty);
    expect(find.text('RECENT SEARCHES'), findsNothing);
  });

  testWidgets('an episode left part-way is on Home, and its pill shows how far', (tester) async {
    await onboarded();
    final first = _feed.episodes[0];
    await library.setProgress(_show, first, 600, length: 3725);
    await tester.pumpWidget(
      ReelPlayerApp(
        library: library,
        directory: _FakeDirectory(),
        playback: Playback(transport: _FakeTransport()),
      ),
    );
    await tester.pump();

    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsOneWidget);
    final card = find.byKey(ValueKey('continue-${first.id}'));
    expect(find.descendant(of: card, matching: find.text('10 min / 1 hr 2 min')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const Key('heard'))), findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(EpisodePage), findsOneWidget);
    final pill = find.byKey(const Key('play-episode'));
    expect(find.descendant(of: pill, matching: find.text('Resume')), findsOneWidget);
    final bar = find.descendant(of: pill, matching: find.byKey(const Key('resume-progress')));
    expect(bar, findsOneWidget);
    final fill = tester.widget<FractionallySizedBox>(
      find.descendant(of: bar, matching: find.byType(FractionallySizedBox)),
    );
    expect(fill.widthFactor, closeTo(600 / 3725, 1e-9));
    // The bar runs along the pill's bottom edge.
    expect(tester.getBottomLeft(bar).dy, closeTo(tester.getBottomLeft(pill).dy, 1));

    // Finished episodes leave the row.
    await library.setProgress(_show, first, null);
    await tester.pump();
    expect(find.descendant(of: pill, matching: find.text('Play')), findsOneWidget);
    expect(bar, findsNothing);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsNothing);
  });

  testWidgets('subscribe, sort, favorite and download', (tester) async {
    await onboarded();
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
    expect(find.text('Subscribe to shows to see their newest episodes here.'), findsOneWidget);
    expect(find.text('Shows you subscribe to will appear here.'), findsOneWidget);
    await openTab(tester, 'Library');
    await tester.tap(find.byKey(const Key('library-favorites')));
    await tester.pumpAndSettle();
    expect(find.text('Tap the heart on an episode to keep it here.'), findsOneWidget);

    await openTab(tester, 'Search');
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

    // The download is listed in the library; the Search tab keeps its place meanwhile.
    await openTab(tester, 'Library');
    await openTab(tester, 'Library'); // Again: back to the menu from Favorites.
    expect(find.descendant(of: find.byKey(const Key('library-downloads')), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-downloads')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('downloaded-ep-12')), findsOneWidget);
    await openTab(tester, 'Search');
    expect(find.byType(EpisodePage), findsOneWidget);

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

    // Home now lists the show and its newest episode, one per show.
    await openTab(tester, 'Home');
    expect(
      find.descendant(of: find.byKey(const Key('your-podcasts')), matching: find.text('Gadget Hour')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('latest-ep-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('latest-ep-11')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('latest-ep-12')));
    await tester.pumpAndSettle();
    expect(find.byType(EpisodePage), findsOneWidget);
    expect(find.text('Season 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    // The favorite is in the library.
    await openTab(tester, 'Library');
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-favorites')));
    await tester.pumpAndSettle();
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
