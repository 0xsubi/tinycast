import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'geometry.dart';

// Helpers that map the SVG vocabulary of the original deck (bounding-box
// gradients, group opacity, filters, baseline-anchored text) onto Canvas.

/// `#rrggbb` plus opacity.
Color rgb(int hex, [double opacity = 1]) => Color(0xFF000000 | hex).withValues(alpha: opacity);

const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);

typedef Stops = List<(double, Color)>;

Float64List _boxMatrix(Rect b) =>
    Float64List.fromList([b.width, 0, 0, 0, 0, b.height, 0, 0, 0, 0, 1, 0, b.left, b.top, 0, 1]);

/// SVG `linearGradient` in objectBoundingBox units over [box].
Shader boxLinear(Rect box, double x1, double y1, double x2, double y2, Stops stops) => ui.Gradient.linear(
  Offset(x1, y1),
  Offset(x2, y2),
  [for (final s in stops) s.$2],
  [for (final s in stops) s.$1],
  TileMode.clamp,
  _boxMatrix(box),
);

/// SVG `radialGradient` in objectBoundingBox units over [box]. A non-square
/// box makes the gradient elliptical, as in SVG.
Shader boxRadial(Rect box, double cx, double cy, double r, Stops stops) => ui.Gradient.radial(
  Offset(cx, cy),
  r,
  [for (final s in stops) s.$2],
  [for (final s in stops) s.$1],
  TileMode.clamp,
  _boxMatrix(box),
);

/// SVG `linearGradient` in userSpaceOnUse units.
Shader userLinear(Offset from, Offset to, Stops stops) =>
    ui.Gradient.linear(from, to, [for (final s in stops) s.$2], [for (final s in stops) s.$1]);

/// SVG `radialGradient` in userSpaceOnUse units; [repeat] is `spreadMethod="repeat"`.
Shader userRadial(Offset c, double r, Stops stops, {bool repeat = false}) => ui.Gradient.radial(
  c,
  r,
  [for (final s in stops) s.$2],
  [for (final s in stops) s.$1],
  repeat ? TileMode.repeated : TileMode.clamp,
);

/// Gradient stops with every opacity scaled by [k] (element `opacity` on a gradient fill).
Stops fade(Stops stops, double k) => [for (final s in stops) (s.$1, s.$2.withValues(alpha: s.$2.a * k))];

Paint fill(Color c) => Paint()..color = c;

Paint shaded(Shader s) => Paint()..shader = s;

Paint stroke(Color c, double width, {StrokeCap cap = StrokeCap.butt}) => Paint()
  ..style = PaintingStyle.stroke
  ..color = c
  ..strokeWidth = width
  ..strokeCap = cap;

/// Tiled bitmap, anchored at the current origin (an SVG userSpaceOnUse pattern).
/// Mipmapped so that, like the browser, minified grain averages out instead
/// of aliasing into harsh speckle.
Paint pattern(ui.Image image, double opacity, {BlendMode blend = BlendMode.srcOver}) => Paint()
  ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, identity, filterQuality: FilterQuality.medium)
  ..colorFilter = ColorFilter.mode(white.withValues(alpha: opacity), BlendMode.modulate)
  ..blendMode = blend;

Float64List scaleMatrix(double sx, double sy) =>
    Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

final Float64List identity = scaleMatrix(1, 1);

/// Gaussian-blurred solid fill (`feGaussianBlur` with `stdDeviation` [sigma]).
Paint blurred(Color c, double sigma) => Paint()
  ..color = c
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

/// The deck's drop-shadow filter: the shape's silhouette, blurred, offset and
/// faded, merged underneath the shape itself.
void dropShadow(
  Canvas canvas,
  Path shape, {
  required double dx,
  required double dy,
  required double sigma,
  required double alpha,
}) {
  canvas.drawPath(shape.shift(Offset(dx, dy)), blurred(black.withValues(alpha: alpha), sigma));
}

/// `filter="url(#fl-drop)"`
void dropLarge(Canvas canvas, Path shape) => dropShadow(canvas, shape, dx: 3, dy: 8, sigma: 6, alpha: 0.65);

/// `filter="url(#fl-drop-sm)"`
void dropSmall(Canvas canvas, Path shape) => dropShadow(canvas, shape, dx: 2, dy: 5, sigma: 3, alpha: 0.75);

Path rrectPath(double x, double y, double w, double h, double r) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));

Path ellipsePath(double cx, double cy, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

/// Rotate the canvas by [degrees] about ([cx], [cy]), like SVG `rotate(a cx cy)`.
void rotateAbout(Canvas canvas, double degrees, double cx, double cy) {
  canvas
    ..translate(cx, cy)
    ..rotate(rad(degrees))
    ..translate(-cx, -cy);
}

/* ------------------------------------------------------------------ text -- */

enum Anchor { start, middle, end }

const String _helvetica = 'Helvetica Neue';
const List<String> _helveticaFallback = ['Helvetica', 'Arial', 'Roboto'];

TextStyle helvetica({
  required double size,
  Color color = const Color(0xFF9A9A9A),
  FontWeight weight = FontWeight.w600,
  double spacing = 0,
}) => TextStyle(
  fontFamily: _helvetica,
  fontFamilyFallback: _helveticaFallback,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  color: color,
);

TextStyle typewriter({required double size, required Color color, double spacing = 0}) => TextStyle(
  fontFamily: 'Special Elite',
  fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
  fontSize: size,
  letterSpacing: spacing,
  color: color,
);

/// The silk-screened panel lettering (`PRINT` in the original).
TextStyle printed({double size = 17, double spacing = 5}) => helvetica(size: size, spacing: spacing);

final Map<InlineSpan, TextPainter> _textCache = {};

TextPainter _laidOut(InlineSpan span) {
  var tp = _textCache[span];
  if (tp == null) {
    if (_textCache.length > 256) _textCache.clear();
    tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    _textCache[span] = tp;
  }
  return tp;
}

/// Width of [text] set in [style].
double measureString(String text, TextStyle style) => _laidOut(TextSpan(text: text, style: style)).width;

/// Draw [span] with its alphabetic baseline at [y], anchored like SVG `text-anchor`.
void drawText(Canvas canvas, InlineSpan span, double x, double y, {Anchor anchor = Anchor.start}) {
  final tp = _laidOut(span);
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (anchor) {
    Anchor.start => 0.0,
    Anchor.middle => tp.width / 2,
    Anchor.end => tp.width,
  };
  tp.paint(canvas, Offset(x - dx, y - baseline));
}

void drawString(Canvas canvas, String text, TextStyle style, double x, double y, {Anchor anchor = Anchor.start}) =>
    drawText(
      canvas,
      TextSpan(text: text, style: style),
      x,
      y,
      anchor: anchor,
    );

/* --------------------------------------------------------------- painter -- */

/// A painter that draws in the deck's 2000 × 1260 view-box coordinates.
abstract class DeckPainter extends CustomPainter {
  DeckPainter({super.repaint});

  void paintDeck(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / viewW, size.height / viewH);
    paintDeck(canvas);
    canvas.restore();
  }
}
