import 'package:flutter/painting.dart';

import 'geometry.dart';
import 'metal.dart';
import 'paint_kit.dart';

/// Static rear layer, drawn over the device's aluminium: the grooves the reels
/// sit in and the shadows they cast.
class BackplatePainter extends DeckPainter {
  BackplatePainter(super.placement);

  /// Everywhere the mechanism might be seen, however it is framed.
  static const Rect _all = Rect.fromLTRB(-viewW, -viewW, 2 * viewW, 2 * viewW);

  @override
  void paintDeck(Canvas canvas, Size view) {
    // A machined groove around each reel, like the TP-7's platter.
    for (final s in Side.values) {
      engraveCircle(canvas, reels[s]!.centre, reelR + 22, width: 2, unit: 2);
    }

    // Reel shadows on the panel. They fall outside the reels only; the panel
    // seen through the windows stays lit.
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(_all);
    for (final s in Side.values) {
      outside.addOval(Rect.fromCircle(center: reels[s]!.centre, radius: reelR - 6));
    }
    canvas
      ..save()
      ..clipPath(outside);
    for (final s in Side.values) {
      final c = reels[s]!.centre;
      canvas
        ..drawCircle(c + const Offset(8, 22), reelR, blurred(black.withValues(alpha: 0.22), 22))
        ..drawCircle(c + const Offset(2, 5), reelR, blurred(black.withValues(alpha: 0.28), 5));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BackplatePainter oldDelegate) => oldDelegate.placement != placement;
}
