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
import 'package:tinycast/player/controls.dart';

import 'test_library.dart';

const _episode = Episode(show: 'Test', tag: 'EP. 001', title: 'Episode');

/// Pumps a bare deck and returns a mapper from view-box to global coordinates.
Future<Offset Function(double, double)> _pumpDeck(
  WidgetTester tester,
  Transport transport, {
  VoidCallback? onPickFile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: TapeDeck(transport: transport, episode: _episode, onPickFile: onPickFile ?? () {}, onDropFiles: (_) {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  final rect = tester.getRect(find.byType(TapeDeck));
  final k = rect.width / viewW;
  return (x, y) => rect.topLeft + Offset(x * k, y * k);
}

Future<void> _pumpControls(WidgetTester tester, Transport transport, {VoidCallback? onLoad}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 800,
          child: PlayerControls(transport: transport, onLoad: onLoad ?? () {}),
        ),
      ),
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

  testWidgets('the glass keys drive the transport', (tester) async {
    final transport = Transport(600, startAt: 100);
    await _pumpControls(tester, transport);

    await tester.tap(find.byKey(const Key('play')));
    expect(transport.playing, isTrue);
    await tester.pump();
    await tester.tap(find.byKey(const Key('play')));
    expect(transport.playing, isFalse);

    // The simulated clock ran on wall time while playing, so skips are relative.
    final start = transport.time;
    await tester.tap(find.byKey(const Key('rew')));
    expect(transport.time, closeTo(start - 15, 0.01));
    await tester.tap(find.byKey(const Key('ff')));
    expect(transport.time, closeTo(start + 15, 0.01));
  });

  testWidgets('dragging the seek bar seeks', (tester) async {
    final transport = Transport(600);
    await _pumpControls(tester, transport);

    final bar = tester.getRect(find.byKey(const Key('seek')));
    final gesture = await tester.startGesture(bar.centerLeft + const Offset(20, 0));
    await gesture.moveTo(bar.center);
    await tester.pump();
    expect(transport.time, closeTo(300, 20));
    await gesture.moveTo(bar.centerRight + const Offset(40, 0));
    await tester.pump();
    expect(transport.time, closeTo(600, 0.01));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('-0:00'), findsOneWidget);
  });

  testWidgets('the volume slider sets the volume', (tester) async {
    final transport = Transport(600);
    await _pumpControls(tester, transport);

    final bar = tester.getRect(find.byKey(const Key('volume')));
    final gesture = await tester.startGesture(bar.center);
    await gesture.moveTo(bar.centerLeft - const Offset(40, 0));
    await tester.pump();
    expect(transport.volume, 0);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the load chip asks for a file', (tester) async {
    var picks = 0;
    await _pumpControls(tester, Transport(600), onLoad: () => picks++);

    await tester.tap(find.byKey(const Key('load')));
    expect(picks, 1);
  });

  testWidgets('clicking the label asks for a file', (tester) async {
    var picks = 0;
    final at = await _pumpDeck(tester, Transport(600), onPickFile: () => picks++);

    await tester.tapAt(at(1000, 846));
    expect(picks, 1);
    // Pressing on the label and releasing elsewhere is not a click.
    final gesture = await tester.startGesture(at(1000, 846));
    await gesture.moveTo(at(1000, 400));
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

  testWidgets('the player lays out on a phone-sized screen', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    addTearDown(view.resetPhysicalSize);
    await tester.pumpWidget(_player(Transport(600, startAt: 100)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('load')), findsOneWidget);
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
