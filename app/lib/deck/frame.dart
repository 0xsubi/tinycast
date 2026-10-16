import 'package:flutter/foundation.dart';

import 'geometry.dart';

/// Everything that moves on the deck, recomputed once per frame by the
/// animation loop. Painters that animate repaint off this notifier, so
/// nothing in the widget tree rebuilds at 60fps.
class DeckFrame extends ChangeNotifier {
  DeckFrame(double progress)
    : angle = {for (final s in Side.values) s: rad(reels[s]!.base)},
      radius = {Side.l: packRadius(1 - progress), Side.r: packRadius(progress)};

  /// Reel rotation in radians.
  final Map<Side, double> angle;

  /// Tape pack radius.
  final Map<Side, double> radius;

  /// Odometer drum positions in digits (seconds-ones first). Fractions are
  /// mid-roll.
  final List<double> drums = List.filled(5, 0);

  /// Fader position, 0–1, following the real playback position.
  double thumb = 0;

  /// Lamp brightness, 0–1.
  double windLamp = 0;
  double playLamp = 0;

  /// How far each transport key is pushed in (view-box units).
  final List<double> keyTravel = List.filled(4, 0);

  /// Keys held by a pointer or latched (PLAY while playing).
  final List<bool> keyDown = List.filled(4, false);
  bool playLatched = false;

  /// Opacity of the label's "load episode" hint (brightens on hover).
  double labelHint = 0.55;

  String remaining = '-0:00';

  void changed() => notifyListeners();
}
