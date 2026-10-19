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

/// [style] with its type shrunk, no smaller than [minSize], to fit [text] in [width].
TextStyle _shrink(String text, TextStyle style, double width, double minSize) {
  final natural = measureString(text, style);
  if (natural <= width) return style;
  final size = style.fontSize!;
  return style.copyWith(fontSize: (size * width / natural).clamp(minSize, size).toDouble());
}

/// Sets [text] in [style] within [width]: shrinks the type down to [minSize],
/// then cuts the text short with an ellipsis if it still does not fit.
(String, TextStyle) _fit(String text, TextStyle style, double width, double minSize) {
  final fitted = _shrink(text, style, width, minSize);
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

/// Title type shrinks to this before it scrolls instead.
const double _titleMinSize = 30;

/// The marquee: a pause with the title's start showing, then a slow crawl
/// left (view-box units a second) until the next copy, [_marqueeGap] behind,
/// has taken the first one's place.
const double _marqueeHold = 2.5;
const double _marqueeSpeed = 45;
const double _marqueeGap = 90;

/// Where a title [textWidth] wide is drawn, relative to where it rests, [t]
/// seconds into its marquee in a space [room] wide. A title that fits stays put.
double marqueeOffset(double textWidth, double room, double t) {
  if (textWidth <= room) return 0;
  final travel = textWidth + _marqueeGap;
  final s = t % (_marqueeHold + travel / _marqueeSpeed);
  return s < _marqueeHold ? 0 : -(s - _marqueeHold) * _marqueeSpeed;
}

TextStyle _titleStyle(String title) =>
    _shrink(title, typewriter(size: 36, color: rgb(0x251f17)), _labelText, _titleMinSize);

/// Whether [title] is too long for the label, so it scrolls.
bool titleScrolls(String title) => measureString(title, _titleStyle(title)) > _labelText;

/// The label's typed title. One too long for the label scrolls through it,
/// marquee style, fading in and out at the paper's edges.
class LabelTitlePainter extends DeckPainter {
  LabelTitlePainter(super.placement, this.frame, this.episode) : super(repaint: frame.title);

  final DeckFrame frame;
  final Episode episode;

  @override
  void paintDeck(Canvas canvas, Size view) {
    final r = labelRect(view.width);
    final title = episode.title;
    final style = _titleStyle(title);
    final width = measureString(title, style);
    final x = r.left + 24;
    const baseline = 77.0;
    canvas.save();
    rotateAbout(canvas, _labelTilt, r.center.dx, r.center.dy);
    if (width <= _labelText) {
      drawString(canvas, title, style, x, r.top + baseline);
      canvas.restore();
      return;
    }
    final offset = marqueeOffset(width, _labelText, frame.clock - frame.titleSince);
    // Between the red rule and the blue one, nearly to the paper's edges.
    final window = Rect.fromLTRB(r.left + 3, r.top + 42, r.right - 3, r.top + 83);
    const fade = 22.0;
    canvas
      ..clipRect(window)
      ..saveLayer(window, Paint());
    drawString(canvas, title, style, x + offset, r.top + baseline);
    drawString(canvas, title, style, x + offset + width + _marqueeGap, r.top + baseline);
    final f = fade / window.width;
    canvas
      ..drawRect(
        window,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = boxLinear(window, 0, 0, 1, 0, [
            (0, black.withValues(alpha: 0)),
            (f, black),
            (1 - f, black),
            (1, black.withValues(alpha: 0)),
          ]),
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(LabelTitlePainter oldDelegate) =>
      oldDelegate.placement != placement || oldDelegate.frame != frame || oldDelegate.episode != episode;
}

/// The label's "load episode" hint, which brightens on hover.
class LabelHintPainter extends DeckPainter {
  LabelHintPainter(super.placement, this.frame) : super(repaint: frame.hint);

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
