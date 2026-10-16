import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../ui/style.dart';
import 'backplate.dart';
import 'label_layer.dart';
import 'frame.dart';
import 'front_layer.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'reels_layer.dart';
import 'transport.dart';

/// Max reel angular speed while winding (rad/s); kept well below wagon-wheel aliasing.
const double _maxOmega = 22;

/// Position differences larger than this (s) are animated as a fast wind.
const double _snap = 0.75;
const double _windRate = 3;

/// Motor spin-up / spin-down rate.
const double _motorRate = 5;

const double _hintEase = 0.045; // opacity 150ms

const double _radius = 28;

class TapeDeck extends StatefulWidget {
  const TapeDeck({
    super.key,
    required this.transport,
    required this.episode,
    required this.onPickFile,
    required this.onDropFiles,
    this.acceptsDrops = false,
  });

  final Transport transport;
  final Episode episode;
  final VoidCallback onPickFile;
  final ValueChanged<List<DropItem>> onDropFiles;
  final bool acceptsDrops;

  @override
  State<TapeDeck> createState() => _TapeDeckState();
}

class _TapeDeckState extends State<TapeDeck> with SingleTickerProviderStateMixin {
  late final DeckFrame _frame;
  late final Ticker _ticker;
  Duration? _last;

  late double _display;
  double _motor = 0;

  final Set<int> _labelPointers = {};
  bool _labelHover = false;
  bool _dragOver = false;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    final t = _transport;
    _display = t.time;
    _frame = DeckFrame(clamp01(t.time / math.max(1, t.duration)));
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Per-frame animation. Tape moves at constant linear speed, so each reel's
  /// angular speed is v / r — the nearly-empty reel spins visibly faster.
  void _onTick(Duration elapsed) {
    final t = _transport;
    final f = _frame;
    final gap = _last == null ? 0.0 : (elapsed - _last!).inMicroseconds / 1e6;
    final dt = gap.clamp(0.0, 0.05);
    _last = elapsed;
    t.tick();

    final dur = math.max(1.0, t.duration);
    final actual = math.min(t.time, dur);
    // After a long stall (app in background) just catch up instead of fast-winding.
    if (gap > 0.25) _display = actual;
    _motor += ((t.playing && !t.buffering ? 1 : 0) - _motor) * (1 - math.exp(-dt * _motorRate));

    // Tape travel this frame, in view-box units (positive = forward).
    double travel;
    final diff = actual - _display;
    if (diff.abs() > _snap) {
      final step = diff * (1 - math.exp(-dt * _windRate));
      _display += step;
      travel = step * tapeSpeed;
    } else {
      _display = actual;
      travel = _motor * tapeSpeed * dt;
    }

    final p = clamp01(_display / dur);
    f.radius[Side.l] = packRadius(1 - p);
    f.radius[Side.r] = packRadius(p);
    final limit = _maxOmega * dt * math.min(f.radius[Side.l]!, f.radius[Side.r]!);
    travel = travel.clamp(-limit, limit);
    for (final side in Side.values) {
      // Both reels turn counter-clockwise when the tape runs forward.
      f.angle[side] = (f.angle[side]! - travel / f.radius[side]!) % (math.pi * 2);
    }

    f.labelHint += ((_labelHover ? 1 : 0.55) - f.labelHint) * (1 - math.exp(-dt / _hintEase));
    f.changed();
  }

  /* ---------------------------------------------------------------- input -- */

  bool _onLabel(Offset local) {
    final box = context.findRenderObject()! as RenderBox;
    return hitLabel(local * (viewW / box.size.width));
  }

  void _onDown(PointerDownEvent e) {
    if (_onLabel(e.localPosition)) _labelPointers.add(e.pointer);
  }

  void _onUp(PointerUpEvent e) {
    // A click: pressed and released on the label.
    if (_labelPointers.remove(e.pointer) && _onLabel(e.localPosition)) widget.onPickFile();
  }

  void _onHover(PointerHoverEvent e) {
    final over = _onLabel(e.localPosition);
    if (over != _labelHover) setState(() => _labelHover = over);
  }

  void _onExit(PointerExitEvent e) {
    if (_labelHover) setState(() => _labelHover = false);
  }

  /* --------------------------------------------------------------- layout -- */

  @override
  Widget build(BuildContext context) {
    Widget layer(CustomPainter painter, {bool still = false}) => Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(painter: painter, isComplex: still, willChange: !still),
      ),
    );

    Widget deck = DecoratedBox(
      decoration: BoxDecoration(
        color: rgb(0x232323),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          cssShadow(black.withValues(alpha: 0.6), y: 40, blur: 80),
          cssShadow(black.withValues(alpha: 0.45), y: 10, blur: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: MouseRegion(
          cursor: _labelHover ? SystemMouseCursors.click : MouseCursor.defer,
          onHover: _onHover,
          onExit: _onExit,
          child: Listener(
            onPointerDown: _onDown,
            onPointerUp: _onUp,
            onPointerCancel: (e) => _labelPointers.remove(e.pointer),
            child: Stack(
              children: [
                layer(BackplatePainter(), still: true),
                layer(ReelsPainter(_frame)),
                layer(FrontPainter(), still: true),
                layer(LabelPainter(transport: _transport, episode: widget.episode)),
                layer(LabelHintPainter(_frame)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _Rim(dropping: _dragOver)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.acceptsDrops) {
      deck = DropTarget(
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        onDragDone: (d) {
          setState(() => _dragOver = false);
          widget.onDropFiles(d.files);
        },
        child: deck,
      );
    }

    return AspectRatio(aspectRatio: viewW / viewH, child: deck);
  }
}

/// CSS `box-shadow: 0 y blur color`. Flutter's blur radius maps to sigma
/// differently from CSS (sigma = blur / 2), so convert.
BoxShadow cssShadow(Color color, {double y = 0, required double blur}) =>
    BoxShadow(color: color, offset: Offset(0, y), blurRadius: (blur / 2 - 0.5) / 0.57735);

/// The deck's hairline edge and inset top highlight, plus the accent rim shown
/// while a file is dragged over it.
class _Rim extends CustomPainter {
  const _Rim({required this.dropping});

  final bool dropping;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius));
    canvas
      ..drawRRect(r.deflate(0.5), stroke(white.withValues(alpha: 0.09), 1))
      ..drawPath(
        Path.combine(PathOperation.difference, Path()..addRRect(r), Path()..addRRect(r.shift(const Offset(0, 1)))),
        fill(white.withValues(alpha: 0.08)),
      );
    if (dropping) canvas.drawRRect(r.deflate(1.5), stroke(accent.withValues(alpha: 0.7), 3));
  }

  @override
  bool shouldRepaint(_Rim oldDelegate) => oldDelegate.dropping != dropping;
}
