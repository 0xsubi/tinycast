import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../deck/geometry.dart';
import '../deck/metal.dart';
import '../deck/paint_kit.dart';
import '../deck/textures.dart';
import '../deck/transport.dart';
import '../ui/style.dart' show TabularText, accent;

// Heights of the parts below the deck, in view-box units.
const double _seekH = 150;
const double _keysH = 300;

/// Logical pixels per view-box unit for a device filling [size]. The fixed
/// parts (band, label strip, seek slot, keys) take their size from the
/// window's long side, kept narrow enough for the band to fit across and
/// short enough to leave the tape mechanism room.
double deviceUnit(Size size) => math.min(
  math.min(size.width / 1000, math.max(size.width, size.height) / 2000),
  size.height / (bandH + stripH + _seekH + _keysH + 350),
);

/// The whole player as one aluminium object filling the window: the tape
/// deck on top, then the seek slot and the transport keys. After Teenage
/// Engineering's TP-7.
class MetalDevice extends StatelessWidget {
  const MetalDevice({super.key, required this.transport, required this.deck});

  final Transport transport;

  /// The tape deck, drawn straight onto the body's aluminium, given the
  /// device's unit and whether the window stands upright.
  final Widget Function(double unit, bool upright) deck;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _Body(),
      foregroundPainter: const _Rim(),
      // The keys run on below the bottom edge.
      child: ClipRect(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final unit = deviceUnit(size);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: deck(unit, size.height > size.width)),
                  SizedBox(
                    height: unit * _seekH,
                    child: SeekSlot(transport: transport),
                  ),
                  SizedBox(
                    height: unit * _keysH,
                    child: TransportKeys(transport: transport),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends CustomPainter {
  const _Body();

  @override
  void paint(Canvas canvas, Size size) => fillAluminium(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_Body oldDelegate) => false;
}

/// Light across the body and its machined edge: a bright chamfer along the
/// top and a darker one along the bottom.
class _Rim extends CustomPainter {
  const _Rim();

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final r = RRect.fromRectAndRadius(all, Radius.zero);
    canvas
      ..drawRect(
        all,
        shaded(boxRadial(all, 0.3, 0.1, 0.9, [(0, white.withValues(alpha: 0.16)), (1, white.withValues(alpha: 0))])),
      )
      ..drawRRect(
        r.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = boxLinear(all, 0, 0, 0, 1, [
            (0, white.withValues(alpha: 0.95)),
            (0.5, white.withValues(alpha: 0.35)),
            (1, black.withValues(alpha: 0.18)),
          ]),
      )
      ..drawRRect(r.deflate(0.25), stroke(black.withValues(alpha: 0.22), 0.5));
  }

  @override
  bool shouldRepaint(_Rim oldDelegate) => false;
}

/* ---------------------------------------------------------------- seek -- */

/// Engraved slot across the device with a metal thumb: drag or click to seek.
class SeekSlot extends StatefulWidget {
  const SeekSlot({super.key, required this.transport});

  final Transport transport;

  @override
  State<SeekSlot> createState() => _SeekSlotState();
}

class _SeekSlotState extends State<SeekSlot> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _fraction = 0;
  int _second = -1;
  double _duration = 0;
  double? _drag;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    _sample();
    _ticker = createTicker((_) {
      if (_sample()) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// True when the thumb would move visibly or a readout changes.
  bool _sample() {
    final t = _transport;
    final fraction = clamp01(t.time / math.max(1, t.duration));
    final second = t.time.floor();
    if ((fraction - _fraction).abs() < 5e-4 && second == _second && t.duration == _duration) return false;
    _fraction = fraction;
    _second = second;
    _duration = t.duration;
    return true;
  }

  void _seekTo(Offset local, double width, double inset) {
    final f = clamp01((local.dx - inset) / (width - 2 * inset));
    setState(() => _drag = f);
    _transport.seek(f * _transport.duration);
  }

  void _release() => setState(() => _drag = null);

  @override
  Widget build(BuildContext context) {
    final t = _transport;
    final fraction = _drag ?? _fraction;
    final time = fraction * t.duration;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final unit = constraints.maxHeight / _seekH;
        final inset = unit * _slotInset;
        final readout = TextStyle(
          fontSize: unit * 25,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
          color: engraving,
          shadows: [Shadow(color: white.withValues(alpha: 0.7), offset: const Offset(0, 1))],
        );
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('seek'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seekTo(d.localPosition, w, inset),
            onTapUp: (_) => _release(),
            onHorizontalDragStart: (d) => _seekTo(d.localPosition, w, inset),
            onHorizontalDragUpdate: (d) => _seekTo(d.localPosition, w, inset),
            onHorizontalDragEnd: (_) => _release(),
            onHorizontalDragCancel: _release,
            child: CustomPaint(
              painter: _SlotPainter(fraction),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Align(
                  alignment: const Alignment(0, 0.95),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TabularText(formatTime(time), key: const Key('elapsed'), style: readout),
                      TabularText('-${formatTime(t.duration - time)}', key: const Key('remaining'), style: readout),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The slot's ends, in from the sides, in view-box units.
const double _slotInset = 100;

class _SlotPainter extends CustomPainter {
  const _SlotPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    // Sized in view-box units, from the height, so the slot keeps its
    // proportions however wide the window is.
    final w = size.height / _seekH;
    final x0 = w * _slotInset;
    final x1 = size.width - x0;
    final y = size.height * 0.42;
    final slotH = w * 18;

    // Crosshair ticks through the slot at the quarters, as on the TP-7's faders.
    for (var i = 0; i <= 4; i++) {
      final x = x0 + (x1 - x0) * i / 4;
      final reach = i == 0 || i == 4 ? w * 32 : w * 22;
      engraveLine(canvas, Offset(x, y - reach), Offset(x, y + reach), width: 1);
    }

    // The slot: dark, with light catching its lower lip.
    final slot = RRect.fromLTRBR(x0 - slotH, y - slotH / 2, x1 + slotH, y + slotH / 2, Radius.circular(slotH / 2));
    canvas
      ..drawRRect(slot.shift(const Offset(0, 1.2)), fill(white.withValues(alpha: 0.85)))
      ..drawRRect(slot, fill(gap));

    // Played tape: a thin accent line inside the slot.
    final tx = x0 + (x1 - x0) * fraction;
    if (tx > x0) {
      canvas.drawRRect(
        RRect.fromLTRBR(x0 - slotH * 0.6, y - 1.25, tx, y + 1.25, const Radius.circular(1.25)),
        fill(accent),
      );
    }

    // Thumb: a small machined cap with a centre groove.
    final tw = w * 84;
    final th = w * 60;
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(tx, y), width: tw, height: th),
      Radius.circular(w * 10),
    );
    canvas
      ..drawRRect(cap.shift(const Offset(0, 3)), blurred(black.withValues(alpha: 0.35), 3))
      ..drawRRect(cap, fill(keyAluminium))
      ..save()
      ..clipRRect(cap)
      ..drawRect(cap.outerRect, pattern(Textures.bead, 0.16, blend: BlendMode.overlay))
      ..drawRect(
        cap.outerRect,
        shaded(
          boxLinear(cap.outerRect, 0, 0, 0, 1, [
            (0, white.withValues(alpha: 0.5)),
            (0.5, white.withValues(alpha: 0)),
            (1, black.withValues(alpha: 0.12)),
          ]),
        ),
      )
      ..restore()
      ..drawRRect(cap.deflate(0.5), stroke(black.withValues(alpha: 0.25), 1));
    engraveLine(canvas, Offset(tx, y - th * 0.3), Offset(tx, y + th * 0.3), width: 1.2);
  }

  @override
  bool shouldRepaint(_SlotPainter oldDelegate) => oldDelegate.fraction != fraction;
}

/* ---------------------------------------------------------------- keys -- */

/// REW 15 · PLAY · PAUSE · FF 30, as chunky aluminium keys. PLAY stays
/// latched down while the tape runs.
class TransportKeys extends StatelessWidget {
  const TransportKeys({super.key, required this.transport});

  final Transport transport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: transport,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetalKey(
              key: const Key('rew'),
              icon: CupertinoIcons.backward_fill,
              caption: '15',
              semanticLabel: 'Back 15 seconds',
              onPressed: () => transport.skip(-15),
            ),
          ),
          Expanded(
            child: MetalKey(
              key: const Key('play'),
              icon: CupertinoIcons.play_fill,
              iconColor: accent,
              semanticLabel: 'Play',
              latched: transport.playing,
              onPressed: transport.play,
            ),
          ),
          Expanded(
            child: MetalKey(
              key: const Key('pause'),
              icon: CupertinoIcons.pause_fill,
              semanticLabel: 'Pause',
              onPressed: transport.pause,
            ),
          ),
          Expanded(
            child: MetalKey(
              key: const Key('ff'),
              icon: CupertinoIcons.forward_fill,
              caption: '30',
              semanticLabel: 'Forward 30 seconds',
              onPressed: () => transport.skip(30),
            ),
          ),
        ],
      ),
    );
  }
}

/// A transport key that travels down when pressed and springs back, acting
/// the moment it bottoms out like a mechanical key.
class MetalKey extends StatefulWidget {
  const MetalKey({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.iconColor,
    this.caption,
    this.latched = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final Color? iconColor;

  /// Small engraved text under the icon ("15").
  final String? caption;

  /// Held part-way down, like a latching transport key.
  final bool latched;

  @override
  State<MetalKey> createState() => _MetalKeyState();
}

const double _latchedTravel = 0.6;

class _MetalKeyState extends State<MetalKey> with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(vsync: this, value: widget.latched ? _latchedTravel : 0);
  bool _held = false;

  @override
  void didUpdateWidget(MetalKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latched != widget.latched && !_held) _settle();
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  void _down() {
    _held = true;
    _travel.animateTo(1, duration: const Duration(milliseconds: 55), curve: Curves.easeIn);
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  void _up() {
    _held = false;
    _settle();
  }

  /// Spring back up (or to the latch), with a little overshoot.
  void _settle() => _travel.animateTo(
    widget.latched ? _latchedTravel : 0,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutBack,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final unit = size.height / 100;
              return AnimatedBuilder(
                animation: _travel,
                builder: (context, _) {
                  final t = _travel.value;
                  final iconSize = unit * 22;
                  Widget glyph(Color color, Offset shift) => Transform.translate(
                    offset: shift,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: iconSize, color: color),
                        if (widget.caption != null)
                          Text(
                            widget.caption!,
                            style: TextStyle(
                              fontSize: unit * 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: color,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  );
                  return CustomPaint(
                    painter: _KeyPainter(t),
                    child: Align(
                      alignment: Alignment(0, -0.12 + t * 0.09),
                      child: Stack(
                        children: [
                          // Engraved: light along the lower edge of each cut.
                          glyph(white.withValues(alpha: 0.75), const Offset(0, 1.2)),
                          glyph(widget.iconColor ?? engraving, Offset.zero),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KeyPainter extends CustomPainter {
  const _KeyPainter(this.travel);

  /// 0 = up, 1 = bottomed out.
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height / 100;
    final all = Offset.zero & size;
    final side = unit * 1.6;
    final top = unit * 2.4 + travel * unit * 4.5;
    final face = RRect.fromLTRBAndCorners(
      side,
      top,
      size.width - side,
      size.height + unit * 10,
      topLeft: Radius.circular(unit * 4),
      topRight: Radius.circular(unit * 4),
    );

    // The slot the key sits in.
    canvas
      ..drawRect(all, fill(gap))
      // Light spilling into the gap from above, so it reads as depth.
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, top),
        shaded(boxLinear(Rect.fromLTWH(0, 0, size.width, top), 0, 0, 0, 1, [(0, rgb(0x4a4a4a)), (1, gap)])),
      )
      ..save()
      ..clipRRect(face);

    // Face: aluminium, darkening slightly as it sinks out of the light.
    final faceRect = face.outerRect;
    canvas
      ..drawRect(faceRect, fill(Color.lerp(keyAluminium, rgb(0xc4c4c2), travel)!))
      ..drawRect(faceRect, pattern(Textures.bead, 0.16, blend: BlendMode.overlay))
      ..drawRect(faceRect, pattern(Textures.bead, 0.03))
      ..drawRect(
        faceRect,
        shaded(
          boxLinear(Rect.fromLTWH(0, top, size.width, size.height - top), 0, 0, 0, 1, [
            (0, white.withValues(alpha: 0.35 * (1 - travel * 0.6))),
            (0.12, white.withValues(alpha: 0.05)),
            (0.85, black.withValues(alpha: 0)),
            (1, black.withValues(alpha: 0.08)),
          ]),
        ),
      )
      // Chamfer along the top edge and down the left side catches the light;
      // the right side falls into shade.
      ..drawRect(
        Rect.fromLTWH(side, top, size.width - 2 * side, unit * 1.2),
        fill(white.withValues(alpha: 0.85 - travel * 0.4)),
      )
      ..drawRect(Rect.fromLTWH(side, top, unit * 0.8, size.height), fill(white.withValues(alpha: 0.45)))
      ..drawRect(
        Rect.fromLTWH(size.width - side - unit * 0.8, top, unit * 0.8, size.height),
        fill(black.withValues(alpha: 0.12)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_KeyPainter oldDelegate) => oldDelegate.travel != travel;
}
