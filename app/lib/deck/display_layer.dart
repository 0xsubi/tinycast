import 'package:flutter/painting.dart';

import '../ui/style.dart' show accent;
import 'frame.dart';
import 'label_layer.dart';
import 'metal.dart';
import 'paint_kit.dart';

/// The OLED window in the top band.
const Rect _oled = Rect.fromLTWH(1556, 16, 388, 86);

/// The round load button on the label strip.
const Offset _loadCentre = Offset(150, 846);
const double _loadR = 44;

/// Whether view-box point [p] is on the load button.
bool hitLoad(Offset p) => (p - _loadCentre).distance <= _loadR + 6;

/// Parts that change every frame or on input: the display, the status lamp
/// and the load button.
class DisplayPainter extends DeckPainter {
  DisplayPainter(this.frame, this.episode) : super(repaint: frame);

  final DeckFrame frame;
  final Episode episode;

  @override
  void paintDeck(Canvas canvas) {
    _display(canvas);
    _lamp(canvas);
    _loadButton(canvas);
  }

  /// White-on-black OLED: a big status word, the elapsed time, and the
  /// episode number in an inverted box — like the TP-7's.
  void _display(Canvas canvas) {
    const r = _oled;
    final glass = RRect.fromRectAndRadius(r, const Radius.circular(14));
    canvas
      // Bezel: the window is set into the band.
      ..drawRRect(glass.inflate(3), fill(rgb(0x9a9a98)))
      ..drawRRect(glass.inflate(3).shift(const Offset(0, 2)), fill(white.withValues(alpha: 0.6)))
      ..drawRRect(glass.inflate(1.5), fill(rgb(0x9a9a98)))
      ..drawRRect(glass, fill(rgb(0x050505)));

    final pixel = white.withValues(alpha: 0.94);
    drawString(
      canvas,
      frame.headline,
      helvetica(size: 46, weight: FontWeight.w800, spacing: 1, color: pixel),
      r.left + 22,
      r.top + 46,
    );
    drawString(
      canvas,
      frame.readout,
      helvetica(size: 23, weight: FontWeight.w600, spacing: 1.5, color: pixel),
      r.left + 22,
      r.bottom - 12,
    );

    // Episode number, inverted, bottom right.
    final tag = _shortTag(episode.tag);
    if (tag.isNotEmpty) {
      final style = helvetica(size: 21, weight: FontWeight.w800, spacing: 0.5, color: black);
      final w = measureString(tag, style) + 14;
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(r.right - 18 - w, r.bottom - 36, w, 26),
        const Radius.circular(5),
      );
      canvas.drawRRect(box, fill(pixel));
      drawString(canvas, tag, style, box.center.dx, box.bottom - 6, anchor: Anchor.middle);
    }
    // Faint glare across the glass.
    canvas.drawRRect(
      glass,
      shaded(boxLinear(r, 0, 0, 0.6, 1, [(0, white.withValues(alpha: 0.07)), (0.5, white.withValues(alpha: 0))])),
    );
  }

  void _lamp(Canvas canvas) {
    const c = Offset(800, 58);
    final lit = frame.lamp;
    canvas
      ..drawCircle(c + const Offset(0, 1.5), 8, fill(white.withValues(alpha: 0.8)))
      ..drawCircle(c, 7.5, fill(Color.lerp(rgb(0x6b4a3e), accent, lit)!));
    if (lit > 0.01) {
      canvas
        ..drawCircle(c, 26, blurred(accent.withValues(alpha: 0.45 * lit), 10))
        ..drawCircle(c - const Offset(2, 2), 2.5, fill(white.withValues(alpha: 0.6 * lit)));
    }
  }

  /// A plain round button set in a recess, like the TP-7's grey disc.
  void _loadButton(Canvas canvas) {
    const c = _loadCentre;
    final t = frame.loadTravel;
    final face = Rect.fromCircle(center: c + Offset(0, 2.5 * t), radius: _loadR - 4);
    canvas
      // The recess: dark ring with a lit lower lip.
      ..drawCircle(c + const Offset(0, 2), _loadR + 1, fill(white.withValues(alpha: 0.8)))
      ..drawCircle(c, _loadR, fill(gap))
      ..drawCircle(face.center + Offset(0, 3 - 2 * t), face.width / 2, blurred(black.withValues(alpha: 0.5), 3))
      ..drawCircle(
        face.center,
        face.width / 2,
        shaded(
          boxRadial(face, 0.4, 0.3, 0.8, [
            (0, Color.lerp(rgb(0xc9c9c7), rgb(0xb5b5b3), t)!),
            (1, Color.lerp(rgb(0xa9a9a7), rgb(0x999997), t)!),
          ]),
        ),
      )
      ..drawCircle(face.center, face.width / 2 - 1, stroke(white.withValues(alpha: 0.45 * (1 - t)), 1.5));
    engraveText(
      canvas,
      'LOAD',
      panelType(size: 15, weight: FontWeight.w500, spacing: 3),
      c.dx,
      c.dy + _loadR + 34,
      anchor: Anchor.middle,
      unit: 1.2,
    );
  }

  @override
  bool shouldRepaint(DisplayPainter oldDelegate) => oldDelegate.frame != frame || oldDelegate.episode != episode;
}

/// "EP. 375" → "375"; dates and words are kept short.
String _shortTag(String tag) {
  final t = tag.startsWith('EP. ') ? tag.substring(4) : tag;
  return t.length > 7 ? t.substring(0, 7) : t;
}
