import 'package:flutter/painting.dart';

import 'geometry.dart';
import 'paint_kit.dart';
import 'textures.dart';

/// Static rear layer: textured deck panel and the shadows the reels cast on it.
class BackplatePainter extends DeckPainter {
  static const Rect _all = Rect.fromLTWH(0, 0, viewW, viewH);

  @override
  void paintDeck(Canvas canvas) {
    canvas.drawRect(
      _all,
      shaded(boxLinear(_all, 0, 0, 0, 1, [(0, rgb(0x2b2b2b)), (0.55, rgb(0x252525)), (1, rgb(0x1e1e1e))])),
    );

    // Leatherette grain + large-scale mottling
    canvas
      ..drawRect(_all, pattern(Textures.panelGrain, 0.085, blend: BlendMode.overlay))
      ..drawRect(_all, pattern(Textures.panelGrain, 0.035));
    final m = Textures.mottle;
    canvas.drawRect(
      _all,
      Paint()
        ..shader = ImageShader(
          m,
          TileMode.clamp,
          TileMode.clamp,
          scaleMatrix(viewW / m.width, viewH / m.height),
          filterQuality: FilterQuality.medium,
        )
        ..colorFilter = ColorFilter.mode(white.withValues(alpha: 0.05), BlendMode.modulate)
        ..blendMode = BlendMode.overlay,
    );

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
        ..drawCircle(c + const Offset(10, 26), reelR, blurred(black.withValues(alpha: 0.55), 22))
        ..drawCircle(c + const Offset(2, 6), reelR, blurred(black.withValues(alpha: 0.45), 5));
    }
    canvas.restore();

    // Seam between the transport deck and the control strip
    canvas
      ..drawRect(const Rect.fromLTWH(0, 752, viewW, 2.5), fill(rgb(0x0d0d0d)))
      ..drawRect(const Rect.fromLTWH(0, 754.5, viewW, 1.5), fill(white.withValues(alpha: 0.05)));

    canvas.drawRect(
      _all,
      shaded(
        boxRadial(_all, 0.5, 0.42, 0.75, [(0.55, black.withValues(alpha: 0)), (1, black.withValues(alpha: 0.45))]),
      ),
    );
  }

  @override
  bool shouldRepaint(BackplatePainter oldDelegate) => false;
}
