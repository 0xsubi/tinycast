import 'package:flutter/painting.dart';

import 'paint_kit.dart';
import 'textures.dart';

// Bead-blasted aluminium, after Teenage Engineering's TP-7: a flat, pale,
// finely speckled metal whose shape is read from crisp chamfer highlights
// and hairline engraving rather than from strong gradients.

/// Body aluminium.
final Color aluminium = rgb(0xd4d4d2);

/// Key caps are a touch lighter than the body, as separately finished parts.
final Color keyAluminium = rgb(0xdcdcda);

/// The dark gaps parts sit in.
final Color gap = rgb(0x2b2b2b);

/// Engraved lettering and glyphs.
final Color engraving = rgb(0x3c3c3c);

/// Fills [rect] with bead-blasted aluminium. [texel] is one screen pixel in
/// the current units, so the grain lines up between the deck canvas and the
/// widgets around it.
void fillAluminium(Canvas canvas, Rect rect, {Color? base, double texel = 1, Path? clip}) {
  void fill(Paint paint) => clip == null ? canvas.drawRect(rect, paint) : canvas.drawPath(clip, paint);
  fill(Paint()..color = base ?? aluminium);
  fill(pattern(Textures.bead, 0.16, blend: BlendMode.overlay, texel: texel));
  fill(pattern(Textures.bead, 0.035, texel: texel));
}

/// A hairline cut into the metal: a dark line with light catching its lower lip.
void engraveLine(Canvas canvas, Offset a, Offset b, {double width = 1.4, double unit = 1}) {
  canvas
    ..drawLine(a + Offset(0, unit), b + Offset(0, unit), stroke(white.withValues(alpha: 0.75), width))
    ..drawLine(a, b, stroke(black.withValues(alpha: 0.32), width));
}

/// A circle cut into the metal.
void engraveCircle(Canvas canvas, Offset c, double r, {double width = 1.4, double unit = 1}) {
  canvas
    ..drawCircle(c + Offset(0, unit), r, stroke(white.withValues(alpha: 0.75), width))
    ..drawCircle(c, r, stroke(black.withValues(alpha: 0.3), width));
}

/// Engraved lettering: dark fill with a light lower edge.
void engraveText(
  Canvas canvas,
  String text,
  TextStyle style,
  double x,
  double y, {
  Anchor anchor = Anchor.start,
  double unit = 1,
}) {
  drawString(canvas, text, style.copyWith(color: white.withValues(alpha: 0.7)), x, y + unit, anchor: anchor);
  drawString(canvas, text, style, x, y, anchor: anchor);
}

/// TP-7-style light grotesque for panel lettering.
TextStyle panelType({required double size, FontWeight weight = FontWeight.w300, double spacing = 0, Color? color}) =>
    helvetica(size: size, weight: weight, spacing: spacing, color: color ?? engraving);
