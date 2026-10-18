import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'frame.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'textures.dart';
import 'transport.dart';

class Episode {
  const Episode({required this.show, required this.tag, required this.title});
  final String show;

  /// Typed in the label's top-right corner, e.g. "EP. 042".
  final String tag;
  final String title;
}

const Rect _label = Rect.fromLTWH(650, 784, 700, 124);
const double _labelTilt = -0.35;

/// Room for text between the label's 24-unit margins.
const double _labelText = 700 - 48;

/// Sets [text] in [style] within [width]: shrinks the type down to [minSize],
/// then cuts the text short with an ellipsis if it still does not fit.
(String, TextStyle) _fit(String text, TextStyle style, double width, double minSize) {
  final natural = measureString(text, style);
  if (natural <= width) return (text, style);
  final size = style.fontSize!;
  final fitted = style.copyWith(fontSize: (size * width / natural).clamp(minSize, size).toDouble());
  var cut = text;
  while (cut.isNotEmpty && measureString(cut == text ? cut : '$cut…', fitted) > width) {
    cut = cut.substring(0, cut.length - 1).trimRight();
  }
  return (cut == text ? cut : '$cut…', fitted);
}

/// The label's centre stays clear of the load button on a narrow strip.
const double _minCentre = 610;

/// The label on a strip [width] view-box units wide: centred, unless that
/// would run it into the load button.
Rect labelRect(double width) => _label.shift(Offset(math.max(width / 2, _minCentre) - viewW / 2, 0));

/// Whether view-box point [p] is on the episode label of a strip [width] wide.
bool hitLabel(Offset p, double width) => labelRect(width).inflate(4).contains(p);

/// The typewritten paper strip naming the loaded episode.
class LabelPainter extends DeckPainter {
  LabelPainter(super.placement, {required this.transport, required this.episode}) : super(repaint: transport);

  final Transport transport;
  final Episode episode;

  @override
  void paintDeck(Canvas canvas, Size view) {
    final r = labelRect(view.width);
    final tagStyle = typewriter(size: 21, spacing: 2, color: rgb(0x4d4232));
    final (show, showStyle) = _fit(
      episode.show.toUpperCase(),
      typewriter(size: 21, spacing: 3, color: rgb(0x4d4232)),
      _labelText - measureString(episode.tag, tagStyle) - 24,
      16,
    );
    final (title, titleStyle) = _fit(episode.title, typewriter(size: 36, color: rgb(0x251f17)), _labelText, 26);
    canvas.save();
    rotateAbout(canvas, _labelTilt, r.center.dx, r.center.dy);
    final paper = RRect.fromRectAndRadius(r, const Radius.circular(2));
    canvas
      ..drawRect(r.shift(const Offset(4, 7)), blurred(black.withValues(alpha: 0.55), 4))
      ..drawRRect(paper, shaded(boxLinear(r, 0, 0, 0.2, 1, [(0, rgb(0xefe8d4)), (1, rgb(0xddd2b6))])))
      ..drawRRect(paper, pattern(Textures.grain, 0.06))
      ..drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1.5), fill(white.withValues(alpha: 0.6)))
      ..drawLine(Offset(r.left, r.top + 40), Offset(r.right, r.top + 40), stroke(rgb(0xc55a4c, 0.8), 1.6))
      ..drawLine(Offset(r.left, r.top + 84), Offset(r.right, r.top + 84), stroke(rgb(0x8fa9c0, 0.55), 1.2))
      ..drawLine(Offset(r.left, r.top + 112), Offset(r.right, r.top + 112), stroke(rgb(0x8fa9c0, 0.55), 1.2));

    drawString(canvas, show, showStyle, r.left + 24, r.top + 29);
    drawString(canvas, episode.tag, tagStyle, r.right - 24, r.top + 29, anchor: Anchor.end);
    drawString(canvas, title, titleStyle, r.left + 24, r.top + 77);
    drawString(
      canvas,
      'STEREO · 7½ IPS · ${formatTime(transport.duration)}',
      typewriter(size: 17, spacing: 1.5, color: rgb(0x6d604d)),
      r.left + 24,
      r.top + 106,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LabelPainter oldDelegate) =>
      oldDelegate.placement != placement || oldDelegate.transport != transport || oldDelegate.episode != episode;
}

/// The label's "load episode" hint, which brightens on hover.
class LabelHintPainter extends DeckPainter {
  LabelHintPainter(super.placement, this.frame) : super(repaint: frame);

  final DeckFrame frame;

  @override
  void paintDeck(Canvas canvas, Size view) {
    final r = labelRect(view.width);
    canvas.save();
    rotateAbout(canvas, _labelTilt, r.center.dx, r.center.dy);
    drawString(
      canvas,
      '⏏ load episode',
      typewriter(size: 16, color: rgb(0x8d7f69, frame.labelHint)),
      r.right - 24,
      r.top + 106,
      anchor: Anchor.end,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LabelHintPainter oldDelegate) => oldDelegate.placement != placement || oldDelegate.frame != frame;
}
