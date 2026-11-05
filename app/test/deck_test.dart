import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/deck/geometry.dart';
import 'package:tinycast/deck/display_layer.dart' show hitSleep;
import 'package:tinycast/deck/label_layer.dart';
import 'package:tinycast/deck/tape_deck.dart';
import 'package:tinycast/deck/textures.dart';
import 'package:tinycast/deck/transport.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/main.dart';
import 'package:tinycast/pages/player_page.dart';
import 'package:tinycast/playback/playback.dart';
import 'package:tinycast/playback/sleep_timer.dart';
import 'package:tinycast/player/metal_controls.dart';
import 'package:tinycast/ui/style.dart' show Artwork, TabularText, accent;

import 'test_library.dart';

const _episode = Episode(show: 'Test', tag: 'EP. 001', title: 'Episode');

const _deckSize = Size(1000, 470);
const _unit = 0.5;

/// Pumps a bare deck and returns a mapper from the label strip's view-box
/// coordinates to global ones.
Future<Offset Function(double, double)> _pumpDeck(
  WidgetTester tester,
  Transport transport, {
  Episode episode = _episode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(
          size: _deckSize,
          child: TapeDeck(transport: transport, episode: episode, unit: _unit),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  final origin = tester.getTopLeft(find.byType(TapeDeck));
  final strip = const DeckLayout(_deckSize, _unit).strip;
  return (x, y) => origin + strip.offset + Offset(x, y) * _unit;
}

Future<void> _pumpControls(WidgetTester tester, Transport transport) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MetalDevice(transport: transport, deck: (_, _) => const SizedBox()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

late Library _library;

/// The app opened straight onto the deck, on a simulated tape.
Widget _player(Transport transport) => ReelPlayerApp(
  library: _library,
  playback: Playback(transport: transport),
  home: const PlayerPage(),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Textures.load();
    _library = await openTestLibrary();
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1240, 880);
    view.devicePixelRatio = 1;
  });

  testWidgets('the metal keys drive the transport', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpControls(tester, transport);

    await tester.tap(find.byKey(const Key('play')));
    expect(transport.playing, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('pause')));
    expect(transport.playing, isFalse);

    // The simulated clock ran on wall time while playing, so skips are relative.
    final start = transport.time;
    await tester.tap(find.byKey(const Key('rew')));
    expect(transport.time, closeTo(start - 15, 0.01));
    await tester.tap(find.byKey(const Key('ff')));
    expect(transport.time, closeTo(start + 15, 0.01));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('keys act on press and travel down', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpControls(tester, transport);

    final icon = find.descendant(of: find.byKey(const Key('ff')), matching: find.byType(Icon)).last;
    final rest = tester.getCenter(icon).dy;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('ff'))));
    // A mechanical key fires as it goes down, not on release.
    expect(transport.time, closeTo(130, 0.01));
    // An animation's clock starts on its first frame, so pump twice.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getCenter(icon).dy, greaterThan(rest));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(icon).dy, closeTo(rest, 0.01));
  });

  testWidgets('the active key is lit', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpControls(tester, transport);
    Future<List<String>> lit() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return [
        for (final key in ['rew', 'play', 'pause', 'ff'])
          if (tester.widget<Icon>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Icon)).last).color ==
              accent)
            key,
      ];
    }

    expect(await lit(), ['pause']);
    transport.play();
    expect(await lit(), ['play']);
    transport.skip(30);
    expect(await lit(), ['ff']);
    transport.wound();
    expect(await lit(), ['play']);
    transport.skip(-15);
    expect(await lit(), ['rew']);
    transport.wound();
    transport.pause();
    expect(await lit(), ['pause']);
  });

  testWidgets('a skip stays lit until the reels have wound', (tester) async {
    await tester.pumpWidget(_player(Transport(600, startAt: 100)));
    await tester.pump();
    final transport = (tester.widget<TapeDeck>(find.byType(TapeDeck))).transport;
    await tester.tap(find.byKey(const Key('ff')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(transport.winding, 1);
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(transport.winding, 0);
  });

  testWidgets('dragging the seek slot seeks', (tester) async {
    final transport = Transport(600);
    await _pumpControls(tester, transport);

    final slot = tester.getRect(find.byKey(const Key('seek')));
    final gesture = await tester.startGesture(slot.centerLeft + const Offset(10, 0));
    await tester.pump();
    expect(transport.time, 0);
    await gesture.moveTo(slot.center);
    await tester.pump();
    expect(transport.time, closeTo(300, 1));
    await gesture.moveTo(slot.centerRight + const Offset(40, 0));
    await tester.pump();
    expect(transport.time, closeTo(600, 0.01));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TabularText>(find.byKey(const Key('remaining'))).text, '-0:00');
  });

  testWidgets('tabular text gives every digit the same width', (tester) async {
    await tester.runAsync(
      () => (FontLoader('Urbanist')..addFont(rootBundle.load('assets/fonts/Urbanist-Regular.ttf'))).load(),
    );
    const style = TextStyle(fontFamily: 'Urbanist', fontSize: 20);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text('1:11', key: Key('plain-narrow'), style: style),
            Text('0:00', key: Key('plain-wide'), style: style),
            TabularText('1:11', key: Key('narrow'), style: style),
            TabularText('0:00', key: Key('wide'), style: style),
          ],
        ),
      ),
    );
    double width(String key) => tester.getSize(find.byKey(Key(key))).width;
    // Urbanist's own figures are proportional…
    expect(width('plain-narrow'), lessThan(width('plain-wide')));
    // …so TabularText evens them out.
    expect(width('narrow'), width('wide'));
  });

  testWidgets('the label carries the episode artwork, or none', (tester) async {
    await _pumpDeck(tester, Transport(600));
    expect(find.byType(Artwork), findsNothing);

    const art = Episode(show: 'Test', tag: 'EP. 001', title: 'Episode', artwork: 'https://example.com/a.jpg');
    await _pumpDeck(tester, Transport(600), episode: art);
    final artwork = find.byType(Artwork);
    expect(artwork, findsOneWidget);
    expect(tester.widget<Artwork>(artwork).url, art.artwork);
    // On the left end of the label, the type set after it.
    final strip = const DeckLayout(_deckSize, _unit);
    final label = labelRect(strip.width);
    final at = tester.getCenter(artwork) - tester.getTopLeft(find.byType(TapeDeck)) - strip.strip.offset;
    expect(at.dx / _unit, closeTo(artRect(label).center.dx, 2));
    expect(at.dx / _unit, lessThan(label.left + label.height));
    expect(titleScrolls(art, strip.width), isFalse);
  });

  /// Where the player's sleep button is, on screen.
  Offset sleepButton(WidgetTester tester) {
    final deck = tester.widget<TapeDeck>(find.byType(TapeDeck));
    final rect = tester.getRect(find.byType(TapeDeck));
    final layout = DeckLayout(rect.size, deck.unit, upright: deck.upright);
    return rect.topLeft + layout.strip.offset + Offset(layout.width - 150, 846) * deck.unit;
  }

  /// Lets a dialog open or close. The deck animates while the tape runs, so
  /// it never settles.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the sleep button sets a timer that pauses the tape', (tester) async {
    final transport = Transport(3600, startAt: 100);
    await tester.pumpWidget(_player(transport));
    await tester.pump();
    final sleep = tester
        .state<State>(find.byType(PlayerPage))
        .context
        .findAncestorWidgetOfExactType<AppScope>()!
        .playback
        .sleep;
    transport.play();
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).sleep, isNull);

    await tester.tapAt(sleepButton(tester));
    await settle(tester);
    expect(find.text('Sleep timer'), findsOneWidget);
    for (final label in ['5 min', '10 min', '15 min', '30 min', '1 hour', 'End of episode']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Turn off'), findsNothing);

    await tester.tap(find.byKey(const Key('sleep-5')));
    await settle(tester);
    expect(find.text('Sleep timer'), findsNothing);
    expect(sleep.length, const Duration(minutes: 5));
    // The readout under the button counts down from 5:00.
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).sleep, anyOf('5:00', '4:59'));

    await tester.pump(const Duration(minutes: 4, seconds: 50));
    expect(transport.playing, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(transport.playing, isFalse);
    expect(sleep.active, isFalse);
    await tester.pump();
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).sleep, isNull);
  });

  testWidgets('the sleep timer can wait for the end of the episode, or be turned off', (tester) async {
    final transport = Transport(600, startAt: 590);
    await tester.pumpWidget(_player(transport));
    await tester.pump();
    final sleep = tester
        .state<State>(find.byType(PlayerPage))
        .context
        .findAncestorWidgetOfExactType<AppScope>()!
        .playback
        .sleep;

    await tester.tapAt(sleepButton(tester));
    await settle(tester);
    await tester.tap(find.byKey(const Key('sleep-end')));
    await settle(tester);
    expect(sleep.endOfEpisode, isTrue);
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).sleep, 'END');

    // Pausing part-way keeps it set…
    transport.play();
    transport.pause();
    expect(sleep.active, isTrue);
    // …and it goes off by itself once the tape stops at its end.
    transport.seek(599.5);
    transport.play();
    // The simulated clock runs on wall time.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    transport.tick();
    expect(transport.playing, isFalse);
    expect(sleep.active, isFalse);

    // Turn off stops a countdown.
    sleep.start(const Duration(minutes: 30));
    await tester.pump();
    await tester.tapAt(sleepButton(tester));
    await settle(tester);
    expect(find.textContaining('Pausing in'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await settle(tester);
    expect(sleep.active, isFalse);
  });

  test('the label stays centred and clear of the sleep button on any strip', () {
    // The strip is never narrower than 1000 view-box units: the device's
    // unit is at most its width / 1000.
    for (var width = 1000.0; width <= 2600; width += 50) {
      final label = labelRect(width);
      final mid = label.center.dy;
      expect(label.width, greaterThanOrEqualTo(550), reason: '$width');
      expect(label.center.dx, closeTo(width / 2, 1e-9), reason: '$width');
      for (var x = label.left; x <= label.right; x += 5) {
        expect(hitSleep(Offset(x, mid), width), isFalse, reason: '$width at $x');
      }
      // The button is where it should be.
      expect(hitSleep(Offset(width - 150, 846), width), isTrue);
    }
    expect(labelRect(2000).width, 700);
  });

  test('the sleep readout', () {
    final t = SleepTimer(Transport(600));
    expect(sleepReadout(t), isNull);
    t.untilEndOfEpisode();
    expect(sleepReadout(t), 'END');
    t.start(const Duration(hours: 1));
    expect(sleepReadout(t), anyOf('1:00:00', '59:59'));
    t.dispose();
    expect(sleepLabel(const Duration(minutes: 15)), '15 min');
    expect(sleepLabel(const Duration(hours: 1)), '1 hour');
  });

  testWidgets('the simulated clock runs while playing', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpDeck(tester, transport);

    transport.play();
    // The simulated clock runs on wall time, so let some real time pass.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(transport.time, greaterThan(100.2));
    expect(transport.playing, isTrue);
    transport.pause();
    expect(transport.playing, isFalse);
  });

  testWidgets('keyboard shortcuts on the player screen', (tester) async {
    await tester.pumpWidget(_player(Transport(600, startAt: 100)));
    await tester.pump();
    final transport = (tester.widget<TapeDeck>(find.byType(TapeDeck))).transport;
    final start = transport.time;

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(transport.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(transport.playing, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(transport.time, closeTo(start - 15, 0.05));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(transport.time, closeTo(start + 15, 0.05));
  });

  testWidgets('the device fills the window, the tape lying down', (tester) async {
    await tester.pumpWidget(_player(Transport(600, startAt: 100)));
    await tester.pump();
    expect(tester.getRect(find.byType(MetalDevice)), Offset.zero & const Size(1240, 880));
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).upright, isFalse);
  });

  testWidgets('on a phone-sized screen the tape stands up', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    addTearDown(view.resetPhysicalSize);
    await tester.pumpWidget(_player(Transport(600, startAt: 100)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(MetalDevice)), Offset.zero & const Size(390, 844));
    expect(tester.widget<TapeDeck>(find.byType(TapeDeck)).upright, isTrue);
    // The keys stay the right way up, across the bottom.
    final play = tester.getRect(find.byKey(const Key('play')));
    final pause = tester.getRect(find.byKey(const Key('pause')));
    expect(pause.left, greaterThan(play.left));
    expect(play.bottom, closeTo(844, 1));
  });

  test('the mechanism fills the room between the band and the strip', () {
    // Lying down it spans the full width, framed as before.
    const flat = DeckLayout(Size(2000, 1200), 1);
    expect(flat.tape.turned, isFalse);
    expect(flat.tape.scale, 1);
    expect(flat.mechanism, const Rect.fromLTRB(0, bandH, 2000, 1200 - stripH));

    // Stood up it turns a quarter, the supply reel above the take-up reel,
    // filling the room's height.
    const tall = DeckLayout(Size(1500, 2300), 1, upright: true);
    final t = tall.tape;
    expect(t.turned, isTrue);
    Offset place(Offset p) => t.offset + Offset(-p.dy, p.dx) * t.scale;
    final supply = place(reels[Side.l]!.centre);
    final takeUp = place(reels[Side.r]!.centre);
    expect(supply.dx, closeTo(takeUp.dx, 1e-9));
    expect(supply.dy, lessThan(takeUp.dy));
    expect(place(const Offset(viewW, 0)).dy - place(Offset.zero).dy, closeTo(tall.mechanism.height, 1e-9));
  });

  testWidgets('a long title paints while it scrolls', (tester) async {
    const long = Episode(
      show: 'Fall of Civilizations Podcast',
      tag: 'EP. 21',
      title: '21. Majapahit – Empire of the Islands, and the long road from Java to the spice trade',
    );
    await _pumpDeck(tester, Transport(600), episode: long);
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a still deck stops asking for frames until the tape moves', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpDeck(tester, transport);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    // A seek winds the reels to the new spot, then the deck rests again.
    transport.seek(300);
    expect(tester.binding.hasScheduledFrame, isTrue);
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.binding.hasScheduledFrame, isFalse);

    transport.play();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    transport.pause();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('paused controls stop asking for frames', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpControls(tester, transport);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.byKey(const Key('play')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.byKey(const Key('pause')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('a title too long for the label scrolls through it and starts over', () {
    // Fits: never moves.
    expect(marqueeOffset(500, 652, 0), 0);
    expect(marqueeOffset(500, 652, 30), 0);

    // Too long: holds at the start, then crawls left at a steady pace…
    const width = 900.0;
    expect(marqueeOffset(width, 652, 1), 0);
    final a = marqueeOffset(width, 652, 4);
    final b = marqueeOffset(width, 652, 5);
    expect(a, lessThan(0));
    expect(b - a, closeTo(-45, 0.01));
    // …until the next copy, 90 behind, has taken its place; then it begins again.
    const cycle = 2.5 + (width + 90) / 45;
    expect(marqueeOffset(width, 652, cycle - 0.001), closeTo(-(width + 90), 0.1));
    expect(marqueeOffset(width, 652, cycle + 1), 0);
  });

  test('formatTime matches the web version', () {
    expect(formatTime(0), '0:00');
    expect(formatTime(564.9), '9:24');
    expect(formatTime(47 * 60 + 32), '47:32');
    expect(formatTime(3725), '1:02:05');
    expect(formatTime(-3), '0:00');
  });

  test('pack radii conserve tape area', () {
    expect(packRadius(0), closeTo(packMinR, 1e-9));
    expect(packRadius(1), closeTo(packMaxR, 1e-9));
    final a = packRadius(0.3);
    final b = packRadius(0.7);
    expect(a * a + b * b, closeTo(packMinR * packMinR + packMaxR * packMaxR, 1e-6));
  });
}
