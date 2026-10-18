import 'package:flutter/painting.dart';

import 'geometry.dart';
import 'metal.dart';
import 'paint_kit.dart';
import 'textures.dart';

const Rect _plate = Rect.fromLTWH(648, 517, 745, 140);
const List<double> _holesTop = [672, 778, 940, 1101, 1263, 1372];
const List<double> _holesBottom = [735, 813, 860, 1013, 1058, 1160, 1252, 1317];

final Stops _chrome = [
  (0, rgb(0xffffff)),
  (0.28, rgb(0xececec)),
  (0.62, rgb(0xb9b9b9)),
  (0.88, rgb(0x7a7a7a)),
  (1, rgb(0x575757)),
];
final Stops _chromePin = [(0, rgb(0xf4f4f4)), (0.5, rgb(0xa6a6a6)), (1, rgb(0x4a4a4a))];
final Stops _spec = [(0, white.withValues(alpha: 0.95)), (1, white.withValues(alpha: 0))];

/// Static front layer of the mechanism: reel lips, head assembly and guide rollers.
class FrontPainter extends DeckPainter {
  FrontPainter(super.placement);

  @override
  void paintDeck(Canvas canvas, Size view) {
    for (final s in Side.values) {
      _lip(canvas, reels[s]!.centre);
    }
    _headAssembly(canvas);
  }

  /// Raised outer rim. Circular, so it is lit statically on top of the spinning flange.
  void _lip(Canvas canvas, Offset c) {
    canvas
      ..save()
      ..translate(c.dx, c.dy);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(circlePath(reelR), Offset.zero)
      ..addPath(circlePath(lipR), Offset.zero);
    final box = Rect.fromCircle(center: Offset.zero, radius: reelR);
    canvas
      ..drawPath(
        ring,
        shaded(boxLinear(box, 0.15, 0, 0.6, 1, [(0, rgb(0x3b3b3e)), (0.5, rgb(0x2c2c2e)), (1, rgb(0x232325))])),
      )
      ..drawPath(ring, pattern(Textures.grain, 0.04))
      ..drawCircle(
        Offset.zero,
        reelR - 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..shader = boxLinear(Rect.fromCircle(center: Offset.zero, radius: reelR - 1.5), 0, 0, 0.4, 1, [
            (0, white.withValues(alpha: 0.22)),
            (0.6, white.withValues(alpha: 0.07)),
            (1, white.withValues(alpha: 0.1)),
          ]),
      )
      ..drawCircle(Offset.zero, lipR, stroke(black.withValues(alpha: 0.55), 2.5))
      ..drawCircle(Offset.zero, lipR + 2.5, stroke(white.withValues(alpha: 0.05), 1.5))
      ..restore();
  }

  void _headAssembly(Canvas canvas) {
    // Mounting bracket below the plate
    final bracket = rrectPath(853, 640, 182, 57, 4);
    dropSmall(canvas, bracket);
    canvas
      ..drawPath(bracket, fill(rgb(0x252525)))
      ..drawPath(rrectPath(876, 660, 138, 20, 4), fill(rgb(0x0e0e0e)))
      ..drawRect(const Rect.fromLTWH(876, 680, 138, 1.5), fill(white.withValues(alpha: 0.07)));

    // Head cover plate
    const p = _plate;
    final plate = rrectPath(p.left, p.top, p.width, p.height, 7);
    dropLarge(canvas, plate);
    canvas
      ..drawPath(plate, shaded(boxLinear(p, 0, 0, 0, 1, [(0, rgb(0x323232)), (1, rgb(0x282828))])))
      ..drawPath(rrectPath(p.left + 5, p.top + 0.5, p.width - 10, 1.6, 0.8), fill(white.withValues(alpha: 0.1)))
      ..drawRect(Rect.fromLTWH(p.left + 5, p.bottom - 2, p.width - 10, 1.6), fill(black.withValues(alpha: 0.35)));
    for (final hx in _holesTop) {
      _hole(canvas, hx, 540);
    }
    for (final hx in _holesBottom) {
      _hole(canvas, hx, 632);
    }

    // Slanted tension-arm slot with its guide pin
    canvas
      ..save()
      ..translate(528, 621)
      ..rotate(rad(-48.5))
      ..drawPath(rrectPath(-60, -12, 120, 28, 14), fill(white.withValues(alpha: 0.06)))
      ..drawPath(rrectPath(-60, -14, 120, 28, 14), fill(rgb(0x0a0a0a)))
      ..drawPath(rrectPath(-56, -12, 112, 9, 4.5), fill(black.withValues(alpha: 0.6)))
      ..restore();
    final pin = circlePath(10, const Offset(530, 622));
    dropSmall(canvas, pin);
    const post = Rect.fromLTWH(526.5, 607, 7, 15);
    canvas
      ..drawPath(pin, shaded(boxRadial(pin.getBounds(), 0.35, 0.3, 0.8, _chromePin)))
      ..drawPath(
        rrectPath(post.left, post.top, post.width, post.height, 3.5),
        shaded(boxRadial(post, 0.35, 0.3, 0.8, _chromePin)),
      )
      ..drawPath(ellipsePath(528, 611, 2, 4), fill(white.withValues(alpha: 0.8)));

    // Chrome guide rollers and flat-head guide screws
    _chromeRoller(canvas, 668, 625, 31);
    _chromeRoller(canvas, 1373, 625, 31);
    _slotScrew(canvas, 613, 650, 19, -32);
    _slotScrew(canvas, 1428, 650, 19, -28);

    _lever(canvas);
  }

  void _hole(Canvas canvas, double x, double y) {
    canvas
      ..drawCircle(Offset(x, y + 1.6), 8.6, fill(white.withValues(alpha: 0.09)))
      ..drawCircle(Offset(x, y), 8.3, fill(rgb(0x0b0b0b)))
      ..drawCircle(Offset(x - 1, y - 1.6), 5.5, fill(black.withValues(alpha: 0.7)));
  }

  void _specular(Canvas canvas, double cx, double cy, double rx, double ry) {
    final e = ellipsePath(cx, cy, rx, ry);
    canvas.drawPath(e, shaded(boxRadial(e.getBounds(), 0.5, 0.5, 0.5, _spec)));
  }

  void _chromeRoller(Canvas canvas, double x, double y, double r) {
    final c = Offset(x, y);
    final disc = circlePath(r, c);
    dropSmall(canvas, disc);
    canvas
      ..drawPath(disc, shaded(boxRadial(disc.getBounds(), 0.4, 0.34, 0.72, _chrome)))
      ..drawCircle(c, r - 0.8, stroke(black.withValues(alpha: 0.35), 1.6))
      ..drawCircle(c, r * 0.62, stroke(white.withValues(alpha: 0.35), 1.2));
    _specular(canvas, x - r * 0.28, y - r * 0.34, r * 0.42, r * 0.3);
  }

  void _slotScrew(Canvas canvas, double x, double y, double r, double angle) {
    final c = Offset(x, y);
    final disc = circlePath(r, c);
    dropSmall(canvas, disc);
    canvas
      ..drawPath(disc, shaded(boxRadial(disc.getBounds(), 0.4, 0.34, 0.72, _chrome)))
      ..drawCircle(c, r - 0.6, stroke(black.withValues(alpha: 0.4), 1.2))
      ..save()
      ..translate(x, y)
      ..rotate(rad(angle))
      ..drawPath(rrectPath(-r * 0.8, 0.4, r * 1.6, 4, 2), fill(white.withValues(alpha: 0.6)))
      ..drawPath(rrectPath(-r * 0.8, -2.6, r * 1.6, 4.4, 2), fill(rgb(0x4a4a4a)))
      ..restore();
    _specular(canvas, x - r * 0.35, y - r * 0.42, r * 0.3, r * 0.2);
  }

  void _lever(Canvas canvas) {
    final d = Path()
      ..moveTo(718, 679)
      ..lineTo(1052, 686)
      ..lineTo(1188, 664)
      ..arcToPoint(const Offset(1203, 715), radius: const Radius.circular(26))
      ..lineTo(1062, 728)
      ..lineTo(718, 725)
      ..arcToPoint(const Offset(718, 679), radius: const Radius.circular(23))
      ..close();
    dropLarge(canvas, d);
    canvas
      ..drawPath(d, shaded(boxLinear(d.getBounds(), 0, 0, 0, 1, [(0, rgb(0x2f2f2f)), (1, rgb(0x1e1e1e))])))
      ..drawPath(
        Path()
          ..moveTo(718, 680.5)
          ..lineTo(1052, 687.5)
          ..lineTo(1188, 665.5),
        stroke(white.withValues(alpha: 0.1), 1.6),
      )
      ..drawPath(d, stroke(black.withValues(alpha: 0.4), 1.2))
      // Pivot screw
      ..drawCircle(const Offset(718, 703), 7, fill(rgb(0x0d0d0d)))
      ..drawCircle(const Offset(718, 704.5), 7, stroke(white.withValues(alpha: 0.08), 1))
      ..drawCircle(const Offset(718, 703), 2.4, fill(rgb(0x2a2a2a)))
      // Roller post
      ..drawCircle(const Offset(1195, 690), 13, fill(black.withValues(alpha: 0.25)))
      ..drawCircle(const Offset(1194, 689), 5.5, fill(rgb(0xdcdcdc)))
      ..drawCircle(const Offset(1193, 687.6), 2, fill(white));
  }

  @override
  bool shouldRepaint(FrontPainter oldDelegate) => oldDelegate.placement != placement;
}

/// Height of the band's shadow on the mechanism below it.
const double bandShadow = 40;

/// The aluminium plate across the top, in place of a smoked lid: wordmark,
/// microphone hole, and room for the display. It runs the width of the
/// device and stands proud of the mechanism, shading it.
class BandPainter extends DeckPainter {
  BandPainter(super.placement, {this.inset = 70});

  /// Where the wordmark starts, leaving room for a button before it.
  final double inset;

  @override
  void paintDeck(Canvas canvas, Size view) {
    final w = view.width;
    final shadow = Rect.fromLTWH(0, bandH, w, bandShadow);
    canvas.drawRect(
      shadow,
      shaded(boxLinear(shadow, 0, 0, 0, 1, [(0, black.withValues(alpha: 0.38)), (1, black.withValues(alpha: 0))])),
    );
    fillAluminium(canvas, Rect.fromLTWH(0, 0, w, bandH), texel: pixel);
    canvas
      // Chamfered lower edge catching the light, then the dark seam.
      ..drawRect(Rect.fromLTWH(0, bandH - 5, w, 3), fill(white.withValues(alpha: 0.55)))
      ..drawRect(Rect.fromLTWH(0, bandH - 2, w, 3), fill(black.withValues(alpha: 0.45)));

    engraveText(canvas, 'tinycast', panelType(size: 58, spacing: -0.5), inset, 80, unit: 1.5);
    // Microphone hole, beside the status lamp (display layer).
    final mic = Offset(w * lampAt + 60, 58);
    canvas
      ..drawCircle(mic + const Offset(0, 1.5), 8, fill(white.withValues(alpha: 0.8)))
      ..drawCircle(mic, 7.5, fill(rgb(0x1c1c1c)));
  }

  @override
  bool shouldRepaint(BandPainter oldDelegate) => oldDelegate.placement != placement || oldDelegate.inset != inset;
}
