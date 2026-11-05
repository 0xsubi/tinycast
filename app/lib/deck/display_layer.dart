import 'package:flutter/painting.dart';

import '../ui/style.dart' show accent;
import 'frame.dart';
import 'geometry.dart';
import 'label_layer.dart';
import 'metal.dart';
import 'paint_kit.dart';

/// The OLED window, at the right-hand end of the top band.
Rect _oled(double width) => Rect.fromLTWH(width - 444, 16, 388, 86);

/// The round sleep button at the right-hand end of the label strip, this far
/// in from the end.
const double _buttonInset = 150;
const double _buttonY = 846;
const double _buttonR = 44;

/// The sleep button, on a strip [width] wide.
Offset _sleepCentre(double width) => Offset(width - _buttonInset, _buttonY);

/// Whether view-box point [p] is on the sleep button of a strip [width] wide.
bool hitSleep(Offset p, double width) => (p - _sleepCentre(width)).distance <= _buttonR + 6;

/// The band's live parts: the display and the status lamp.
class DisplayPainter extends DeckPainter {
  DisplayPainter(super.placement, this.frame, this.episode) : super(repaint: frame.display);

  final DeckFrame frame;
  final Episode episode;

  @override
  void paintDeck(Canvas canvas, Size view) {
    _display(canvas, _oled(view.width));
    _lamp(canvas, Offset(view.width * lampAt, 58));
  }

  /// White-on-black OLED: a big status word, the elapsed time, and the
  /// episode number in an inverted box — like the TP-7's.
  void _display(Canvas canvas, Rect r) {
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
    drawTabular(
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

  void _lamp(Canvas canvas, Offset c) {
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

  @override
  bool shouldRepaint(DisplayPainter oldDelegate) =>
      oldDelegate.placement != placement || oldDelegate.frame != frame || oldDelegate.episode != episode;
}

/// The label strip's metal: the seam along its top and the sleep button,
/// captioned with the time left once the sleep timer is set.
class StripPainter extends DeckPainter {
  StripPainter(super.placement, this.frame, {this.sleep}) : super(repaint: frame.strip);

  final DeckFrame frame;

  /// The sleep timer's readout ("14:32", "END"); null when it is off.
  final String? sleep;

  @override
  void paintDeck(Canvas canvas, Size view) {
    engraveLine(canvas, const Offset(60, seamY), Offset(view.width - 60, seamY), width: 2, unit: 2);
    final caption = panelType(size: 15, weight: FontWeight.w500, spacing: 3);
    final c = _sleepCentre(view.width);
    final face = _disc(canvas, c, frame.sleepTravel);
    _moon(canvas, face.center);
    final readout = sleep;
    if (readout == null) {
      engraveText(canvas, 'SLEEP', caption, c.dx, c.dy + _buttonR + 34, anchor: Anchor.middle, unit: 1.2);
    } else {
      // Running: the time left, steady digits, with a lit lamp beside the button.
      final style = panelType(size: 17, weight: FontWeight.w600, spacing: 1.5);
      final y = c.dy + _buttonR + 35;
      drawTabular(
        canvas,
        readout,
        style.copyWith(color: white.withValues(alpha: 0.7)),
        c.dx,
        y + 1.2,
        anchor: Anchor.middle,
      );
      drawTabular(canvas, readout, style, c.dx, y, anchor: Anchor.middle);
      _lamp(canvas, c + const Offset(_buttonR + 18, -_buttonR + 8));
    }
  }

  /// A plain round button set in a recess, like the TP-7's grey disc,
  /// pushed [t] of the way in. Returns its face.
  Rect _disc(Canvas canvas, Offset c, double t) {
    final face = Rect.fromCircle(center: c + Offset(0, 2.5 * t), radius: _buttonR - 4);
    canvas
      // The recess: dark ring with a lit lower lip.
      ..drawCircle(c + const Offset(0, 2), _buttonR + 1, fill(white.withValues(alpha: 0.8)))
      ..drawCircle(c, _buttonR, fill(gap))
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
    return face;
  }

  /// A crescent moon with three z's rising off it, engraved into the face
  /// centred on [c].
  void _moon(Canvas canvas, Offset c) {
    final moonAt = c + const Offset(-7, 5);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonAt, radius: 15)),
      Path()..addOval(Rect.fromCircle(center: moonAt + const Offset(8, -7), radius: 13)),
    );
    canvas
      ..drawPath(crescent.shift(const Offset(0, 1.2)), fill(white.withValues(alpha: 0.7)))
      ..drawPath(crescent, fill(engraving));
    for (final (dx, dy, size) in const [(9.0, -1.0, 15.0), (17.0, -11.0, 12.0), (23.5, -20.0, 9.5)]) {
      engraveText(
        canvas,
        'z',
        panelType(size: size, weight: FontWeight.w700),
        c.dx + dx,
        c.dy + dy,
        anchor: Anchor.middle,
        unit: 1,
      );
    }
  }

  /// The sleep timer's status light, lit.
  void _lamp(Canvas canvas, Offset c) {
    canvas
      ..drawCircle(c + const Offset(0, 1.5), 7, fill(white.withValues(alpha: 0.8)))
      ..drawCircle(c, 6.5, fill(accent))
      ..drawCircle(c, 18, blurred(accent.withValues(alpha: 0.35), 7))
      ..drawCircle(c - const Offset(2, 2), 2, fill(white.withValues(alpha: 0.6)));
  }

  @override
  bool shouldRepaint(StripPainter oldDelegate) =>
      oldDelegate.placement != placement || oldDelegate.frame != frame || oldDelegate.sleep != sleep;
}

/// "EP. 375" → "375"; dates and words are kept short.
String _shortTag(String tag) {
  final t = tag.startsWith('EP. ') ? tag.substring(4) : tag;
  return t.length > 7 ? t.substring(0, 7) : t;
}
