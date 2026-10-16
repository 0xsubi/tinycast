import 'package:flutter/painting.dart';

import 'geometry.dart';
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

/// Static front layer: reel lips, head assembly, guide rollers, smoked lid,
/// panel screws.
class FrontPainter extends DeckPainter {
  @override
  void paintDeck(Canvas canvas) {
    for (final s in Side.values) {
      _lip(canvas, reels[s]!.centre);
    }
    _headAssembly(canvas);
    _lid(canvas);
    _screw(canvas, 40, 688, 18);
    _screw(canvas, 1964, 688, 62);
    _screw(canvas, 40, 1222, -34);
    _screw(canvas, 1964, 1222, 8);
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

  void _lid(Canvas canvas) {
    // Lid casts a soft shadow over the reels
    const shadow = Rect.fromLTWH(0, 116, viewW, 34);
    canvas.drawRect(
      shadow,
      shaded(boxLinear(shadow, 0, 0, 0, 1, [(0, black.withValues(alpha: 0.6)), (1, black.withValues(alpha: 0))])),
    );

    // Smoked glass: reels and hubs remain faintly visible through it
    const lid = Rect.fromLTWH(0, 0, viewW, 116);
    canvas
      ..drawRect(
        lid,
        shaded(
          boxLinear(lid, 0, 0, 0, 1, [
            (0, rgb(0x050505, 0.97)),
            (0.35, rgb(0x0b0b0b, 0.9)),
            (0.85, rgb(0x111111, 0.84)),
            (1, rgb(0x161616, 0.82)),
          ]),
        ),
      )
      ..drawRect(
        lid,
        shaded(
          boxLinear(lid, 0, 0, 1, 0, [
            (0, white.withValues(alpha: 0)),
            (0.3, white.withValues(alpha: 0.035)),
            (0.55, white.withValues(alpha: 0)),
            (0.8, white.withValues(alpha: 0.025)),
            (1, white.withValues(alpha: 0)),
          ]),
        ),
      )
      ..drawRect(const Rect.fromLTWH(0, 0, viewW, 7), fill(rgb(0x080808)))
      ..drawRect(const Rect.fromLTWH(0, 7, viewW, 1.5), fill(white.withValues(alpha: 0.07)));

    // Brushed silver lid handle
    const handle = Rect.fromLTWH(515, 10, 977, 27);
    canvas
      ..drawRect(const Rect.fromLTWH(515, 39, 977, 4), blurred(black.withValues(alpha: 0.5), 2.5))
      ..drawRect(
        handle,
        shaded(boxLinear(handle, 0, 0, 0, 1, [(0, rgb(0xdedede)), (0.5, rgb(0xc4c4c4)), (1, rgb(0xa2a2a2))])),
      )
      ..drawRect(
        handle,
        shaded(
          boxLinear(handle, 0, 0, 1, 0, [
            (0, black.withValues(alpha: 0.18)),
            (0.04, black.withValues(alpha: 0)),
            (0.96, black.withValues(alpha: 0)),
            (1, black.withValues(alpha: 0.18)),
          ]),
        ),
      )
      ..drawRect(const Rect.fromLTWH(515, 10, 977, 1.5), fill(white.withValues(alpha: 0.8)))
      ..drawRect(const Rect.fromLTWH(515, 35.5, 977, 1.5), fill(black.withValues(alpha: 0.35)));

    // Lower edge of the lid: a lit chamfer then a hard dark line
    canvas
      ..drawRect(const Rect.fromLTWH(0, 109, viewW, 2.5), fill(white.withValues(alpha: 0.075)))
      ..drawRect(const Rect.fromLTWH(0, 113, viewW, 3), fill(rgb(0x040404)));
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

  void _screw(Canvas canvas, double x, double y, double angle) {
    final slot = stroke(rgb(0x060606), 2.6, cap: StrokeCap.round);
    canvas
      ..save()
      ..translate(x, y)
      ..drawCircle(const Offset(0, 1.6), 10, fill(white.withValues(alpha: 0.07)))
      ..drawCircle(Offset.zero, 10, fill(rgb(0x161616)))
      ..drawCircle(Offset.zero, 8, fill(rgb(0x1f1f1f)))
      ..rotate(rad(angle))
      ..drawLine(const Offset(-5, 0), const Offset(5, 0), slot)
      ..drawLine(const Offset(0, -5), const Offset(0, 5), slot)
      ..restore();
  }

  @override
  bool shouldRepaint(FrontPainter oldDelegate) => false;
}
