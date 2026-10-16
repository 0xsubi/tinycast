import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/deck/controls_layer.dart';
import 'package:tinycast/deck/geometry.dart';
import 'package:tinycast/deck/tape_deck.dart';
import 'package:tinycast/deck/textures.dart';
import 'package:tinycast/deck/transport.dart';
import 'package:tinycast/main.dart';

const _episode = Episode(show: 'Test', number: '001', title: 'Episode');

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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Textures.load();
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1240, 880);
    view.devicePixelRatio = 1;
  });

  testWidgets('PLAY and PAUSE keys drive the transport', (tester) async {
    final transport = Transport(600, startAt: 100);
    final at = await _pumpDeck(tester, transport);

    // Keys are 150 wide with a 22 gap, centred on x = 1000.
    await tester.tapAt(at(667 + 172 + 75, 1000));
    expect(transport.playing, isTrue);
    await tester.tapAt(at(667 + 2 * 172 + 75, 1000));
    expect(transport.playing, isFalse);
  });

  testWidgets('REW and FF keys skip', (tester) async {
    final transport = Transport(600, startAt: 100);
    final at = await _pumpDeck(tester, transport);

    await tester.tapAt(at(667 + 75, 1000));
    expect(transport.time, closeTo(85, 0.01));
    await tester.tapAt(at(667 + 3 * 172 + 75, 1000));
    expect(transport.time, closeTo(115, 0.01));
  });

  testWidgets('dragging the fader seeks', (tester) async {
    final transport = Transport(600);
    final at = await _pumpDeck(tester, transport);

    final gesture = await tester.startGesture(at(sliderX0, 1170));
    expect(transport.time, closeTo(0, 0.01));
    await gesture.moveTo(at((sliderX0 + sliderX1) / 2, 1170));
    expect(transport.time, closeTo(300, 0.01));
    await gesture.moveTo(at(sliderX1 + 30, 1170));
    expect(transport.time, closeTo(600, 0.01));
    await gesture.up();
  });

  testWidgets('turning the knob sets the volume and clamps at the stops', (tester) async {
    final transport = Transport(600);
    final at = await _pumpDeck(tester, transport);

    // Straight up is the middle of the 270° arc.
    final gesture = await tester.startGesture(at(330, 905 - 60));
    expect(transport.volume, closeTo(0.5, 0.001));
    // Pointer moves are relative to the knob centre, so leaving the knob still turns it.
    await gesture.moveTo(at(330 + 60, 905));
    expect(transport.volume, closeTo(225 / 270, 0.001));
    await gesture.moveTo(at(330 - 10, 905 + 300));
    expect(transport.volume, 0);
    await gesture.up();
  });

  testWidgets('scrolling over the knob changes the volume', (tester) async {
    final transport = Transport(600);
    final at = await _pumpDeck(tester, transport);

    final before = transport.volume;
    await tester.sendEventToBinding(PointerScrollEvent(position: at(330, 905), scrollDelta: const Offset(0, 150)));
    expect(transport.volume, closeTo(before - 0.1, 0.001));
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
    await tester.pumpWidget(const ReelPlayerApp());
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
