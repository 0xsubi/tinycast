import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'frame.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'textures.dart';
import 'transport.dart';

class Episode {
  const Episode({required this.show, required this.number, required this.title});
  final String show;
  final String number;
  final String title;
}

// Layout constants (view-box units)
const double _knobX = 330;
const double _knobY = 905;
const double _knobR = 92;
const double _capR = 74;

const double _keyW = 150;
const double _keyH = 92;
const double _keyGap = 22;
const double _keyY = 962;
const double _keyFaceH = _keyH - 6;
const double keyTravelDown = 11;
const int keyCount = 4;
const double _keysX0 = 1000 - (keyCount * _keyW + (keyCount - 1) * _keyGap) / 2;
double _keyX(int i) => _keysX0 + i * (_keyW + _keyGap);

const double _counterX = 1670;
const double _counterY = 842;
const double _drumW = 46;
const double drumH = 66;
const double _colonW = 16;
const double _counterGap = 4;
const double _counterWidth = 5 * _drumW + 2 * _colonW + 6 * _counterGap;
const double _counterX0 = _counterX - _counterWidth / 2;
const double _counterY0 = _counterY - drumH / 2;

const double sliderX0 = 420;
const double sliderX1 = 1580;
const double _sliderY = 1170;

const Rect _label = Rect.fromLTWH(650, 784, 700, 124);
const double _labelTilt = -0.35;

/// Odometer drums, seconds-ones first.
const List<int> drumRadix = [10, 6, 10, 6, 10];

/// Left-to-right slots of the counter window: a drum's odometer index, or null for a colon.
const List<int?> _counterSlots = [4, null, 3, 2, null, 1, 0];

final List<double> _slotX = () {
  final xs = <double>[];
  var cursor = _counterX0;
  for (final s in _counterSlots) {
    xs.add(cursor);
    cursor += (s == null ? _colonW : _drumW) + _counterGap;
  }
  return xs;
}();

/* ----------------------------------------------------------- hit testing -- */

enum Control { none, knob, key, label, slider }

/// Which control sits under view-box point [p]; [key] is the key index for [Control.key].
({Control control, int key}) hitControl(Offset p) {
  if (p.dx >= sliderX0 - 40 && p.dx <= sliderX1 + 40 && (p.dy - _sliderY).abs() <= 30) {
    return (control: Control.slider, key: -1);
  }
  for (var i = 0; i < keyCount; i++) {
    final x = _keyX(i);
    if (p.dx >= x - 8 && p.dx <= x + _keyW + 8 && p.dy >= _keyY - 8 && p.dy <= _keyY + _keyH + 18) {
      return (control: Control.key, key: i);
    }
  }
  final k = p - const Offset(_knobX, _knobY);
  if (k.distance <= _knobR + 4 || (k - const Offset(0, 12)).distance <= _knobR + 4) {
    return (control: Control.knob, key: -1);
  }
  if (_label.inflate(4).contains(p)) return (control: Control.label, key: -1);
  return (control: Control.none, key: -1);
}

/// Volume for a pointer at [p] while dragging the knob. Snaps into the valid
/// arc instead of jumping across the dead zone.
double knobVolumeAt(Offset p) {
  final a = deg(math.atan2(p.dx - _knobX, -(p.dy - _knobY))).clamp(-135.0, 135.0);
  return (a + 135) / 270;
}

double sliderFractionAt(Offset p) => clamp01((p.dx - sliderX0) / (sliderX1 - sliderX0));

/* ---------------------------------------------------------------- shared -- */

Paint _brushed(double opacity) => pattern(Textures.brushed, opacity, blend: BlendMode.multiply);

/* --------------------------------------------------------- static layer -- */

/// Controls that change only on discrete events: episode label, volume knob,
/// key wells, panel lettering and bezels.
class ControlsPainter extends DeckPainter {
  ControlsPainter({required this.transport, required this.episode}) : super(repaint: transport);

  final Transport transport;
  final Episode episode;

  @override
  void paintDeck(Canvas canvas) {
    _episodeLabel(canvas);
    _volumeKnob(canvas, transport.volume);
    _keyWells(canvas);
    _counterBezel(canvas);
    _sliderTrack(canvas, transport.duration);
  }

  void _episodeLabel(Canvas canvas) {
    final r = _label;
    final title = episode.title.length > 34 ? '${episode.title.substring(0, 33)}…' : episode.title;
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

    drawString(
      canvas,
      episode.show.toUpperCase(),
      typewriter(size: 21, spacing: 3, color: rgb(0x4d4232)),
      r.left + 24,
      r.top + 29,
    );
    drawString(
      canvas,
      'EP. ${episode.number}',
      typewriter(size: 21, spacing: 2, color: rgb(0x4d4232)),
      r.right - 24,
      r.top + 29,
      anchor: Anchor.end,
    );
    drawString(canvas, title, typewriter(size: 36, color: rgb(0x251f17)), r.left + 24, r.top + 77);
    drawString(
      canvas,
      'STEREO · 7½ IPS · ${formatTime(transport.duration)}',
      typewriter(size: 17, spacing: 1.5, color: rgb(0x6d604d)),
      r.left + 24,
      r.top + 106,
    );
    canvas.restore();
  }

  void _volumeKnob(Canvas canvas, double volume) {
    final angle = rad(-135 + volume * 270);
    canvas
      ..save()
      ..translate(_knobX, _knobY);

    for (var i = 0; i < _ticks.length; i++) {
      final major = i % 5 == 0;
      canvas
        ..save()
        ..rotate(rad(_ticks[i]))
        ..drawLine(const Offset(0, -112), Offset(0, major ? -130 : -122), stroke(rgb(0x8a8a8a), major ? 3 : 2))
        ..restore();
    }
    drawString(canvas, 'MIN', printed(size: 14, spacing: 3), -118, 124, anchor: Anchor.middle);
    drawString(canvas, 'MAX', printed(size: 14, spacing: 3), 118, 124, anchor: Anchor.middle);
    drawString(canvas, 'VOLUME', printed(), 0, 150, anchor: Anchor.middle);

    canvas.drawCircle(const Offset(0, 12), _knobR + 4, blurred(black.withValues(alpha: 0.6), 8));

    // Knurled skirt turns with the knob
    final knurl = stroke(rgb(0x3d3d3d), 2.6);
    canvas
      ..save()
      ..rotate(angle)
      ..drawCircle(Offset.zero, _knobR, fill(rgb(0x1d1d1d)));
    for (var k = 0; k < 64; k++) {
      canvas
        ..save()
        ..rotate(k / 64 * 2 * math.pi)
        ..drawLine(const Offset(0, -_knobR + 0.5), const Offset(0, -_capR - 6), knurl)
        ..restore();
    }
    canvas.restore();

    final skirt = Rect.fromCircle(center: Offset.zero, radius: _knobR);
    canvas
      ..drawCircle(
        Offset.zero,
        _knobR,
        shaded(
          boxLinear(skirt, 0.2, 0, 0.5, 1, [
            (0, white.withValues(alpha: 0.16)),
            (0.5, white.withValues(alpha: 0)),
            (1, black.withValues(alpha: 0.35)),
          ]),
        ),
      )
      ..drawCircle(Offset.zero, _knobR - 0.8, stroke(black.withValues(alpha: 0.6), 1.6))
      ..drawCircle(Offset.zero, _capR + 3, fill(rgb(0x0d0d0d)));

    // Machined cap: lit statically, only the indicator turns
    for (final w in _capWedges) {
      canvas.drawPath(w.path, fill(w.color));
    }
    canvas
      ..drawCircle(
        Offset.zero,
        _capR,
        shaded(
          userRadial(
            Offset.zero,
            2.2,
            fade([
              (0, white.withValues(alpha: 0.5)),
              (0.5, black.withValues(alpha: 0.4)),
              (1, white.withValues(alpha: 0.5)),
            ], 0.14),
            repeat: true,
          ),
        ),
      )
      ..drawCircle(Offset.zero, _capR - 1, stroke(white.withValues(alpha: 0.65), 1.5))
      ..drawCircle(Offset.zero, _capR, stroke(black.withValues(alpha: 0.4), 1))
      ..drawCircle(Offset.zero, 5, fill(black.withValues(alpha: 0.18)))
      ..save()
      ..rotate(angle)
      ..drawPath(rrectPath(-3.5, -_capR + 9 + 1.4, 7, 24, 3.5), fill(white.withValues(alpha: 0.7)))
      ..drawPath(rrectPath(-3.5, -_capR + 9, 7, 24, 3.5), fill(rgb(0x2a2a2a)))
      ..restore()
      ..restore();
  }

  void _keyWells(Canvas canvas) {
    for (var i = 0; i < keyCount; i++) {
      final x = _keyX(i);
      drawString(
        canvas,
        _keyLabels[i],
        printed(size: 14, spacing: 3),
        x + _keyW / 2,
        _keyY + _keyH + 46,
        anchor: Anchor.middle,
      );
      final front = Rect.fromLTWH(x + 2, _keyY + _keyH - 22, _keyW - 4, 34);
      canvas
        ..drawPath(rrectPath(x - 8, _keyY - 8, _keyW + 16, _keyH + 26, 8), fill(rgb(0x090909)))
        ..drawRect(Rect.fromLTWH(x - 6, _keyY + _keyH + 18, _keyW + 12, 1.5), fill(white.withValues(alpha: 0.06)))
        // Key front face, revealed when the key is up
        ..drawRRect(
          RRect.fromRectAndRadius(front, const Radius.circular(6)),
          shaded(boxLinear(front, 0, 0, 0, 1, [(0, rgb(0x7c7c7c)), (1, rgb(0x2c2c2c))])),
        );
    }
  }

  void _counterBezel(Canvas canvas) {
    const x0 = _counterX0;
    const y0 = _counterY0;
    const w = _counterWidth;
    drawString(canvas, 'TAPE COUNTER', printed(), _counterX, y0 - 26, anchor: Anchor.middle);
    canvas
      ..drawPath(rrectPath(x0 - 16, y0 - 12, w + 32, drumH + 28, 8), fill(white.withValues(alpha: 0.06)))
      ..drawPath(rrectPath(x0 - 16, y0 - 14, w + 32, drumH + 28, 8), fill(rgb(0x0a0a0a)))
      ..drawPath(rrectPath(x0 - 8, y0 - 6, w + 16, drumH + 12, 4), fill(black));
    for (var i = 0; i < _counterSlots.length; i++) {
      final x = _slotX[i];
      if (_counterSlots[i] == null) {
        canvas
          ..drawCircle(Offset(x + _colonW / 2, _counterY - 11), 3.6, fill(rgb(0xd8d8d8)))
          ..drawCircle(Offset(x + _colonW / 2, _counterY + 11), 3.6, fill(rgb(0xd8d8d8)));
      } else {
        canvas.drawRect(Rect.fromLTWH(x, y0, _drumW, drumH), fill(rgb(0x151515)));
      }
    }
  }

  void _sliderTrack(Canvas canvas, double duration) {
    const x0 = sliderX0;
    const x1 = sliderX1;
    const y = _sliderY;
    drawString(canvas, 'TAPE POSITION', printed(), x0 - 10, y - 46);
    for (var i = 0; i <= 20; i++) {
      final h = i % 10 == 0 ? 14.0 : (i % 2 == 0 ? 10.0 : 7.0);
      final top = y - (i % 10 == 0 ? 34 : (i % 2 == 0 ? 30 : 27));
      canvas.drawRect(Rect.fromLTWH(x0 + i * (x1 - x0) / 20 - 1, top, 2, h), fill(rgb(0x8a8a8a, i.isEven ? 0.9 : 0.6)));
    }
    drawString(canvas, '0:00', printed(size: 15, spacing: 2), x0 - 44, y + 6, anchor: Anchor.end);
    drawString(canvas, formatTime(duration), printed(size: 15, spacing: 2), x1 + 44, y + 6);

    // Slot
    canvas
      ..drawPath(rrectPath(x0 - 12, y - 6, x1 - x0 + 24, 16, 8), fill(white.withValues(alpha: 0.07)))
      ..drawPath(rrectPath(x0 - 12, y - 8, x1 - x0 + 24, 16, 8), fill(rgb(0x060606)));
  }

  @override
  bool shouldRepaint(ControlsPainter oldDelegate) =>
      oldDelegate.transport != transport || oldDelegate.episode != episode;
}

const List<String> _keyLabels = ['REW 15', 'PLAY', 'PAUSE', 'FF 30'];
final List<double> _ticks = List.generate(11, (i) => -135.0 + i * 27);

// Spun-metal cap: a "conic gradient" built from thin wedges.
final List<({Path path, Color color})> _capWedges = List.generate(96, (i) {
  final a0 = i / 96 * math.pi * 2;
  final a1 = (i + 1) / 96 * math.pi * 2 + 0.004;
  final mid = (a0 + a1) / 2;
  final v = 0.66 + 0.2 * math.cos(2 * (mid + 0.7)) + 0.07 * math.cos(6 * mid + 1.3);
  final g = (255 * clamp01(v)).round();
  final path = Path()
    ..moveTo(0, 0)
    ..lineTo(_capR * math.cos(a0), _capR * math.sin(a0))
    ..arcToPoint(Offset(_capR * math.cos(a1), _capR * math.sin(a1)), radius: const Radius.circular(_capR))
    ..close();
  return (path: path, color: Color.fromARGB(255, g, g, g));
});

/* -------------------------------------------------------- animated layer -- */

enum _Icon { rew, play, pause, ff }

final Map<_Icon, Path> _icons = {
  _Icon.play: Path()
    ..moveTo(-9, -15)
    ..lineTo(15, 0)
    ..lineTo(-9, 15)
    ..close(),
  _Icon.pause: Path()
    ..addRect(const Rect.fromLTWH(-13, -14, 9, 28))
    ..addRect(const Rect.fromLTWH(4, -14, 9, 28)),
  _Icon.rew: Path()
    ..moveTo(-1, -13)
    ..lineTo(-20, 0)
    ..lineTo(-1, 13)
    ..close()
    ..moveTo(19, -13)
    ..lineTo(0, 0)
    ..lineTo(19, 13)
    ..close(),
  _Icon.ff: Path()
    ..moveTo(1, -13)
    ..lineTo(20, 0)
    ..lineTo(1, 13)
    ..close()
    ..moveTo(-19, -13)
    ..lineTo(0, 0)
    ..lineTo(-19, 13)
    ..close(),
};

const List<_Icon> _keyIcons = [_Icon.rew, _Icon.play, _Icon.pause, _Icon.ff];

/// Controls redrawn every frame: key travel, odometer drums, lamps, fader.
class ControlsMotionPainter extends DeckPainter {
  ControlsMotionPainter(this.frame) : super(repaint: frame);

  final DeckFrame frame;

  @override
  void paintDeck(Canvas canvas) {
    _labelHint(canvas);
    for (var i = 0; i < keyCount; i++) {
      _keyTop(canvas, i);
    }
    _counterDrums(canvas);
    _lamp(canvas, 1590, 1005, rgb(0x7dff6a), rgb(0x1f3a1c), 'PLAY', frame.playLamp);
    _lamp(canvas, 1750, 1005, rgb(0xffb347), rgb(0x3b2a14), 'WIND', frame.windLamp);
    _fader(canvas);
  }

  void _labelHint(Canvas canvas) {
    final r = _label;
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

  void _keyTop(Canvas canvas, int i) {
    final x = _keyX(i);
    final top = Rect.fromLTWH(x, _keyY, _keyW, _keyFaceH);
    final face = RRect.fromRectAndRadius(top, const Radius.circular(6));
    final down = frame.keyDown[i];
    final latchedPlay = _keyIcons[i] == _Icon.play && frame.playLatched;
    final icon = _icons[_keyIcons[i]]!;
    canvas
      ..save()
      ..translate(0, frame.keyTravel[i])
      ..drawRRect(
        face,
        shaded(boxLinear(top, 0, 0, 0, 1, [(0, rgb(0xececec)), (0.55, rgb(0xcfcfcf)), (1, rgb(0xababab))])),
      )
      ..drawRRect(face, _brushed(0.45))
      ..drawPath(rrectPath(x + 3, _keyY + 1, _keyW - 6, 2, 1), fill(white.withValues(alpha: 0.85)))
      ..drawRRect(face, stroke(black.withValues(alpha: 0.35), 1.2));
    if (down) canvas.drawRRect(face, fill(black.withValues(alpha: 0.12)));
    canvas
      ..translate(x + _keyW / 2, _keyY + _keyFaceH / 2)
      ..drawPath(icon.shift(const Offset(0, 1.5)), fill(white.withValues(alpha: 0.75)))
      ..drawPath(icon, fill(latchedPlay ? rgb(0x2f6b26) : rgb(0x3a3a3a)))
      ..restore();
  }

  void _counterDrums(Canvas canvas) {
    const y0 = _counterY0;
    final digit = helvetica(size: 48, weight: FontWeight.w500, color: rgb(0xefefef));
    final overlay = [
      (0.0, black.withValues(alpha: 0.85)),
      (0.22, black.withValues(alpha: 0.15)),
      (0.5, white.withValues(alpha: 0.06)),
      (0.78, black.withValues(alpha: 0.15)),
      (1.0, black.withValues(alpha: 0.85)),
    ];
    for (var i = 0; i < _counterSlots.length; i++) {
      final index = _counterSlots[i];
      if (index == null) continue;
      final x = _slotX[i];
      final window = Rect.fromLTWH(x, y0, _drumW, drumH);
      final radix = drumRadix[index];
      final roll = frame.drums[index];
      canvas
        ..save()
        ..clipRect(window)
        ..translate(0, -roll * drumH);
      // Only the digits near the window are visible.
      final first = roll.floor();
      for (var d = first; d <= math.min(radix, first + 1); d++) {
        drawString(canvas, '${d % radix}', digit, x + _drumW / 2, y0 + d * drumH + drumH * 0.74, anchor: Anchor.middle);
      }
      canvas
        ..restore()
        ..drawRect(window, shaded(boxLinear(window, 0, 0, 0, 1, overlay)));
    }
    // Glass glare over the window
    canvas.drawPath(
      rrectPath(_counterX0 - 8, y0 - 6, _counterWidth + 16, (drumH + 12) * 0.45, 4),
      fill(white.withValues(alpha: 0.04)),
    );

    final label = printed(size: 15, spacing: 3);
    drawText(
      canvas,
      TextSpan(
        text: 'REMAINING ',
        style: label,
        children: [
          TextSpan(
            text: frame.remaining,
            style: label.copyWith(color: rgb(0xc9c9c9), letterSpacing: 2),
          ),
        ],
      ),
      _counterX,
      y0 + drumH + 50,
      anchor: Anchor.middle,
    );
  }

  void _lamp(Canvas canvas, double x, double y, Color on, Color off, String label, double lit) {
    const glowBox = Rect.fromLTWH(-90, -90, 180, 180);
    const lens = Rect.fromLTWH(-17.5, -17.5, 35, 35);
    canvas
      ..save()
      ..translate(x, y);
    if (lit > 0.001) {
      canvas.drawCircle(
        Offset.zero,
        90,
        shaded(
          boxRadial(
            glowBox,
            0.5,
            0.5,
            0.5,
            fade([
              (0, on.withValues(alpha: 0.5)),
              (0.35, on.withValues(alpha: 0.16)),
              (1, on.withValues(alpha: 0)),
            ], lit),
          ),
        )..blendMode = BlendMode.screen,
      );
    }
    canvas
      ..drawCircle(const Offset(0, 3), 28, blurred(black.withValues(alpha: 0.6), 4))
      ..drawCircle(
        Offset.zero,
        27,
        shaded(
          boxRadial(const Rect.fromLTWH(-27, -27, 54, 54), 0.4, 0.3, 0.8, [
            (0, rgb(0xf2f2f2)),
            (0.55, rgb(0x9c9c9c)),
            (1, rgb(0x3e3e3e)),
          ]),
        ),
      )
      ..drawCircle(Offset.zero, 20.5, fill(rgb(0x050505)))
      ..drawCircle(Offset.zero, 17.5, shaded(boxRadial(lens, 0.45, 0.4, 0.7, [(0, off), (1, rgb(0x070707))])));
    if (lit > 0.001) {
      canvas.drawCircle(
        Offset.zero,
        17.5,
        shaded(boxRadial(lens, 0.45, 0.4, 0.65, fade([(0, white), (0.3, on), (1, on.withValues(alpha: 0.55))], lit))),
      );
    }
    canvas.drawPath(ellipsePath(-5, -7, 7, 4.5), fill(white.withValues(alpha: 0.32)));
    drawString(canvas, label, printed(size: 14, spacing: 3), 0, 64, anchor: Anchor.middle);
    canvas.restore();
  }

  void _fader(Canvas canvas) {
    const y = _sliderY;
    final tx = sliderX0 + frame.thumb * (sliderX1 - sliderX0);
    final progress = math.max(0.0, tx - sliderX0 + 6);
    if (progress > 0) {
      canvas.drawPath(rrectPath(sliderX0 - 6, y - 3, progress, 6, math.min(3, progress / 2)), fill(rgb(0x5b3d27, 0.9)));
    }

    const cap = Rect.fromLTWH(-28, -24, 56, 42);
    final capFace = RRect.fromRectAndRadius(cap, const Radius.circular(5));
    canvas
      ..save()
      ..translate(tx, y)
      ..drawPath(rrectPath(-30, -20, 60, 48, 6), blurred(black.withValues(alpha: 0.55), 4))
      ..drawPath(rrectPath(-30, -24, 60, 48, 6), fill(rgb(0x151515)))
      ..drawRRect(
        capFace,
        shaded(boxLinear(cap, 0, 0, 0, 1, [(0, rgb(0xe9e9e9)), (0.5, rgb(0xbdbdbd)), (1, rgb(0x8a8a8a))])),
      )
      ..drawRRect(capFace, _brushed(0.4))
      ..drawPath(rrectPath(-26, -23, 52, 1.6, 0.8), fill(white.withValues(alpha: 0.9)));
    for (final gx in const [-14.0, -7.0, 7.0, 14.0]) {
      canvas.drawRect(Rect.fromLTWH(gx - 1, -17, 2, 28), fill(black.withValues(alpha: 0.22)));
    }
    canvas
      ..drawRect(const Rect.fromLTWH(-1.5, -21, 3, 36), fill(rgb(0x2a2a2a)))
      ..restore();
  }

  @override
  bool shouldRepaint(ControlsMotionPainter oldDelegate) => oldDelegate.frame != frame;
}
