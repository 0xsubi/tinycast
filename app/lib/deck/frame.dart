import 'package:flutter/foundation.dart';

import 'geometry.dart';

/// Everything that moves on the deck, recomputed once per frame by the
/// animation loop. Each animated painter repaints off the signal for the parts
/// it draws, fired only when those parts changed, so nothing in the widget
/// tree rebuilds at 60fps and nothing repaints while the deck is still.
class DeckFrame {
  DeckFrame(double progress)
    : angle = {for (final s in Side.values) s: rad(reels[s]!.base)},
      radius = {Side.l: packRadius(1 - progress), Side.r: packRadius(progress)};

  /// Reel rotation in radians.
  final Map<Side, double> angle;

  /// Tape pack radius.
  final Map<Side, double> radius;

  /// Opacity of the label's "load episode" hint (brightens on hover).
  double labelHint = 0.55;

  /// Status lamp brightness, 0–1.
  double lamp = 0;

  /// How far the load button is pushed in, 0–1.
  double loadTravel = 0;

  /// Seconds since the deck started animating.
  double clock = 0;

  /// [clock] when the label's title last changed; its marquee runs from here.
  double titleSince = 0;

  /// The display's big line (PLAY, PAUSE, WIND…) and its small readout.
  String headline = 'PAUSE';
  String readout = '0.00.00';

  /// The reels turned.
  final Signal spin = Signal();

  /// The display's text or the lamp changed.
  final Signal display = Signal();

  /// The load button moved.
  final Signal strip = Signal();

  /// The label's title scrolled.
  final Signal title = Signal();

  /// The label's hint faded.
  final Signal hint = Signal();

  void dispose() {
    for (final s in [spin, display, strip, title, hint]) {
      s.dispose();
    }
  }
}

/// A repaint trigger.
class Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
