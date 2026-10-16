import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'frame.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'textures.dart';

/// Light comes from the upper left and must stay fixed while the reels turn.
/// Window bevels are faked with copies of the flange shifted in *screen*
/// space and clipped to the windows; each frame converts these screen offsets
/// into the reel's rotating frame.
const List<({double ox, double oy, Color color})> _bevels = [
  (ox: 2.5, oy: 5, color: Color(0x4D000000)), // 0.3
  (ox: 5, oy: 11, color: Color(0x33000000)), // 0.2
  (ox: 9, oy: 20, color: Color(0x24000000)), // 0.14
  (ox: -1.3, oy: -3.4, color: Color(0x8CD8D8D8)), // 0.55
];

Offset _localOffset(double ox, double oy, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  return Offset(ox * c + oy * s, -ox * s + oy * c);
}

final Stops _rings = [(0, rgb(0x3e2a1c)), (0.5, rgb(0x33231a)), (0.75, rgb(0x412d1f)), (1, rgb(0x3e2a1c))];
final Stops _bands = [
  (0, black.withValues(alpha: 0)),
  (0.3, black.withValues(alpha: 0.16)),
  (0.42, black.withValues(alpha: 0.02)),
  (0.7, rgb(0xffd2a8, 0.04)),
  (1, black.withValues(alpha: 0)),
];
final Stops _sheen = [(0.5, rgb(0xffc896, 0)), (0.68, rgb(0xffc896, 0.11)), (0.86, rgb(0xffc896, 0))];
final Stops _packEdge = [
  (0.82, black.withValues(alpha: 0)),
  (0.97, black.withValues(alpha: 0.32)),
  (1, black.withValues(alpha: 0.6)),
];
final Stops _flangeTint = [(0, rgb(0x3a3a3d, 0.62)), (0.5, rgb(0x29292b, 0.66)), (1, rgb(0x1f1f21, 0.74))];
final Stops _spindle = [(0, rgb(0xbdbdbd)), (0.5, rgb(0x6e6e6e)), (1, rgb(0x2e2e2e))];

/// Moving reels: tape packs, the threaded tape and the spinning flanges.
class ReelsPainter extends DeckPainter {
  ReelsPainter(this.frame) : super(repaint: frame);

  final DeckFrame frame;

  @override
  void paintDeck(Canvas canvas) {
    for (final s in Side.values) {
      _tapePack(canvas, s, frame.radius[s]!);
    }
    canvas.drawPath(
      tapePath(frame.radius[Side.l]!, frame.radius[Side.r]!),
      stroke(rgb(0x5b3d27, 0.9), 2.2)..strokeJoin = StrokeJoin.round,
    );
    for (final s in Side.values) {
      _flange(canvas, s, frame.angle[s]!);
    }
  }

  /// Wound tape. Rotationally symmetric, so it never rotates; only its radius changes.
  void _tapePack(Canvas canvas, Side side, double r) {
    final c = reels[side]!.centre;
    final box = Rect.fromCircle(center: c, radius: r);
    canvas
      // Fine concentric winding lines + broader density bands
      ..drawCircle(c, r, shaded(userRadial(c, 5.5, _rings, repeat: true)))
      ..drawCircle(c, r, shaded(userRadial(c, 47, _bands, repeat: true)))
      ..drawCircle(c, r, shaded(boxLinear(box, 0, 0, 1, 1, _sheen)))
      ..drawCircle(c, r, shaded(boxRadial(box, 0.5, 0.5, 0.5, _packEdge)))
      ..drawCircle(c, r, stroke(black.withValues(alpha: 0.55), 2));
  }

  /// Smoked translucent flange with spoke windows. This is the part that visibly spins.
  void _flange(Canvas canvas, Side side, double a) {
    final reel = reels[side]!;
    canvas
      ..save()
      ..translate(reel.cx, reel.cy)
      ..rotate(a);

    // Tint counter-rotated so the light stays put.
    Offset unrotate(double x, double y) =>
        Offset(x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a));
    canvas
      ..drawPath(
        flangePath,
        shaded(userLinear(unrotate(-reelR, -reelR * 0.4), unrotate(reelR * 0.5, reelR), _flangeTint)),
      )
      ..drawPath(flangePath, pattern(Textures.grain, 0.045));

    // Bevel: shadow under the upper window walls, light on the lower walls
    canvas
      ..save()
      ..clipPath(windowsPath);
    for (final b in _bevels) {
      canvas.drawPath(flangePath.shift(_localOffset(b.ox, b.oy, a)), fill(b.color));
    }
    canvas
      ..restore()
      ..drawPath(windowsPath, stroke(black.withValues(alpha: 0.5), 1.4));

    // Hub — mostly hidden under the smoked lid
    canvas
      ..drawCircle(Offset.zero, hubR * 0.85, fill(rgb(0x232325)))
      ..drawCircle(Offset.zero, hubR * 0.85, stroke(white.withValues(alpha: 0.07), 3))
      ..drawCircle(Offset.zero, hubR * 0.6, stroke(black.withValues(alpha: 0.4), 2))
      ..drawCircle(
        Offset.zero,
        hubR * 0.32,
        shaded(boxRadial(Rect.fromCircle(center: Offset.zero, radius: hubR * 0.32), 0.38, 0.32, 0.75, _spindle)),
      );
    for (final d in const [0.0, 120.0, 240.0]) {
      canvas
        ..save()
        ..rotate(rad(d))
        ..drawRRect(
          RRect.fromLTRBR(hubR * 0.28, -8, hubR * 0.28 + 22, 8, const Radius.circular(3)),
          fill(rgb(0x161617)),
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ReelsPainter oldDelegate) => oldDelegate.frame != frame;
}
