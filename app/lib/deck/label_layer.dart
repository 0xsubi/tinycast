import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'frame.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'textures.dart';
import 'transport.dart';

class Episode {
  const Episode({required this.show, required this.tag, required this.title, this.artwork});
  final String show;

  /// Typed in the label's top-right corner, e.g. "EP. 042".
  final String tag;
  final String title;

  /// The episode's (or its show's) artwork, pasted on the label's left end.
  final String? artwork;
}

const double _labelTop = 784;
const double _labelH = 124;

/// The label's full width, on a strip with room for it.
const double _labelW = 700;
const double labelTilt = -0.35;

/// What the sleep button keeps clear of the label: out to its far edge, plus
/// a margin. The label keeps the same clearance on the left, so it stays
/// centred.
const double _buttonsClear = 224;

/// The artwork's inset from the paper's edges.
const double _artInset = 12;

/// The artwork on a label [label]: a square filling the paper's height, less
/// its inset, at the left end.
Rect artRect(Rect label) =>
    Rect.fromLTWH(label.left + _artInset, label.top + _artInset, _labelH - 2 * _artInset, _labelH - 2 * _artInset);

/// Where the label's typing starts: after the artwork, when there is some.
double _textLeft(Rect label, Episode episode) => episode.artwork == null ? label.left + 24 : artRect(label).right + 20;

/// Room for text between where typing starts and the right-hand margin.
double _textRoom(Rect label, Episode episode) => label.right - 24 - _textLeft(label, episode);

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

/// The label on a strip [width] view-box units wide: centred, clear of the
/// sleep button, and narrower when there is not room for all of it.
Rect labelRect(double width) {
  final w = math.min(_labelW, width - 2 * _buttonsClear);
  return Rect.fromLTWH((width - w) / 2, _labelTop, w, _labelH);
}

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
      _textRoom(r, episode) - measureString(episode.tag, tagStyle) - 24,
      16,
    );
    final left = _textLeft(r, episode);
    canvas.save();
    rotateAbout(canvas, labelTilt, r.center.dx, r.center.dy);
    final paper = RRect.fromRectAndRadius(r, const Radius.circular(2));
    canvas
      ..drawRect(r.shift(const Offset(4, 7)), blurred(black.withValues(alpha: 0.55), 4))
      ..drawRRect(paper, shaded(boxLinear(r, 0, 0, 0.2, 1, [(0, rgb(0xefe8d4)), (1, rgb(0xddd2b6))])))
      ..drawRRect(paper, pattern(Textures.grain, 0.06))
      ..drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1.5), fill(white.withValues(alpha: 0.6)))
      ..drawLine(Offset(r.left, r.top + 40), Offset(r.right, r.top + 40), stroke(rgb(0xc55a4c, 0.8), 1.6))
      ..drawLine(Offset(r.left, r.top + 84), Offset(r.right, r.top + 84), stroke(rgb(0x8fa9c0, 0.55), 1.2))
      ..drawLine(Offset(r.left, r.top + 112), Offset(r.right, r.top + 112), stroke(rgb(0x8fa9c0, 0.55), 1.2));
    // The artwork, drawn over this by the deck, casts a little shadow on the paper.
    if (episode.artwork != null) {
      final art = RRect.fromRectAndRadius(artRect(r), const Radius.circular(artRadius));
      canvas.drawRRect(art.shift(const Offset(1.5, 3)), blurred(black.withValues(alpha: 0.35), 3));
    }

    drawString(canvas, show, showStyle, left, r.top + 29);
    drawString(canvas, episode.tag, tagStyle, r.right - 24, r.top + 29, anchor: Anchor.end);
    drawString(
      canvas,
      'STEREO · 7½ IPS · ${formatTime(transport.duration)}',
      typewriter(size: 17, spacing: 1.5, color: rgb(0x6d604d)),
      left,
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

/// Corner radius of the label's artwork.
const double artRadius = 4;

/// The marquee: a pause with the title's start showing, then a slow crawl
/// left (view-box units a second) until the next copy, [_marqueeGap] behind,
/// has taken the first one's place.
const double _marqueeHold = 2.5;
const double _marqueeSpeed = 45;
const double _marqueeGap = 90;

/// Where a title [textWidth] wide is drawn, relative to where it rests, [t]
/// seconds into its marquee in a space [room] wide. A title that fits stays
/// put. [speed] and [gap] default to the label's, in view-box units.
double marqueeOffset(
  double textWidth,
  double room,
  double t, {
  double speed = _marqueeSpeed,
  double gap = _marqueeGap,
}) {
  if (textWidth <= room) return 0;
  final travel = textWidth + gap;
  final s = t % (_marqueeHold + travel / speed);
  return s < _marqueeHold ? 0 : -(s - _marqueeHold) * speed;
}

TextStyle _titleStyle(String title, double room) =>
    _shrink(title, typewriter(size: 36, color: rgb(0x251f17)), room, _titleMinSize);

/// Whether [episode]'s title is too long for the label on a strip [width]
/// wide, so it scrolls.
bool titleScrolls(Episode episode, double width) {
  final room = _textRoom(labelRect(width), episode);
  return measureString(episode.title, _titleStyle(episode.title, room)) > room;
}

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
    final room = _textRoom(r, episode);
    final style = _titleStyle(title, room);
    final width = measureString(title, style);
    final x = _textLeft(r, episode);
    const baseline = 77.0;
    canvas.save();
    rotateAbout(canvas, labelTilt, r.center.dx, r.center.dy);
    if (width <= room) {
      drawString(canvas, title, style, x, r.top + baseline);
      canvas.restore();
      return;
    }
    final offset = marqueeOffset(width, room, frame.clock - frame.titleSince);
    // Between the red rule and the blue one, from the artwork (or nearly the
    // paper's edge) to nearly the paper's other edge.
    final window = Rect.fromLTRB(x - 21, r.top + 42, r.right - 3, r.top + 83);
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
