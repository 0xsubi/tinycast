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

  /// Opacity of the label's "load episode" hint (brightens on hover).
  double labelHint = 0.55;

  void changed() => notifyListeners();
}
