import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/deck/geometry.dart';
import 'package:tinycast/deck/label_layer.dart';
import 'package:tinycast/deck/tape_deck.dart';
import 'package:tinycast/deck/textures.dart';
import 'package:tinycast/deck/transport.dart';
import 'package:tinycast/library/library.dart';
import 'package:tinycast/main.dart';
import 'package:tinycast/pages/player_page.dart';
import 'package:tinycast/playback/playback.dart';
import 'package:tinycast/player/metal_controls.dart';
import 'package:tinycast/ui/style.dart' show TabularText;

import 'test_library.dart';

const _episode = Episode(show: 'Test', tag: 'EP. 001', title: 'Episode');

const _deckSize = Size(1000, 470);
const _unit = 0.5;

/// Pumps a bare deck and returns a mapper from the label strip's view-box
/// coordinates to global ones.
Future<Offset Function(double, double)> _pumpDeck(
  WidgetTester tester,
  Transport transport, {
  VoidCallback? onPickFile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(
          size: _deckSize,
          child: TapeDeck(
            transport: transport,
            episode: _episode,
            onPickFile: onPickFile ?? () {},
            onDropFiles: (_) {},
            unit: _unit,
          ),
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

  testWidgets('the load button asks for a file', (tester) async {
    var picks = 0;
    final at = await _pumpDeck(tester, Transport(600), onPickFile: () => picks++);

    await tester.tapAt(at(150, 846));
    expect(picks, 1);
  });

  testWidgets('clicking the label asks for a file', (tester) async {
    var picks = 0;
    final at = await _pumpDeck(tester, Transport(600), onPickFile: () => picks++);

    await tester.tapAt(at(1000, 846));
    expect(picks, 1);
    // Pressing on the label and releasing elsewhere is not a click.
    final gesture = await tester.startGesture(at(1000, 846));
    await gesture.moveTo(at(1000, 500));
    await gesture.up();
    expect(picks, 1);
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
