import 'package:flutter/painting.dart';

import 'geometry.dart';
import 'metal.dart';
import 'paint_kit.dart';

/// Static rear layer, drawn over the device's aluminium: the grooves the reels
/// sit in and the shadows they cast.
class BackplatePainter extends DeckPainter {
  static const Rect _all = Rect.fromLTWH(0, 0, viewW, viewH);

  @override
  void paintDeck(Canvas canvas) {
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

    // Hairline between the transport and the label strip
    engraveLine(canvas, const Offset(60, 756), const Offset(viewW - 60, 756), width: 2, unit: 2);
  }

  @override
  bool shouldRepaint(BackplatePainter oldDelegate) => false;
}
