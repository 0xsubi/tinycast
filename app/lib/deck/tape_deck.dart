import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'backplate.dart';
import 'controls_layer.dart';
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

/// Seconds the odometer takes to roll one digit.
const double _roll = 0.18;

// Easing time constants standing in for the original CSS transitions.
const double _keyEase = 0.022; // transform 70ms ease-out
const double _lampEase = 0.06; // opacity 220ms ease
const double _hintEase = 0.045; // opacity 150ms

const double _maxDeckWidth = 1400;
const double _radius = 14;

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

  final List<bool> _held = List.filled(keyCount, false);
  final Map<int, ({Control control, int key})> _pointers = {};
  bool _labelHover = false;
  bool _dragOver = false;
  MouseCursor _cursor = MouseCursor.defer;
  bool _panOverKnob = false;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    final t = _transport;
    _display = t.time;
    _frame = DeckFrame(clamp01(t.time / math.max(1, t.duration)))..playLamp = t.playing ? 1 : 0;
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
    double ease(double tau) => 1 - math.exp(-dt / tau);
    t.tick();

    final dur = math.max(1.0, t.duration);
    final actual = math.min(t.time, dur);
    // After a long stall (app in background) just catch up instead of fast-winding.
    if (gap > 0.25) _display = actual;
    _motor += ((t.playing ? 1 : 0) - _motor) * (1 - math.exp(-dt * _motorRate));

    // Tape travel this frame, in view-box units (positive = forward).
    double travel;
    final diff = actual - _display;
    final winding = diff.abs() > _snap;
    if (winding) {
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

    var unit = 1.0;
    for (var i = 0; i < drumRadix.length; i++) {
      final radix = drumRadix[i];
      final whole = (_display / unit).floor() % radix;
      final lower = _display % unit;
      // A drum rolls only while every drum below it is rolling over.
      var frac = clamp01((lower - (unit - _roll)) / _roll);
      frac = frac * frac * (3 - 2 * frac);
      f.drums[i] = whole + frac;
      unit *= radix;
    }

    // The fader follows the real position so dragging feels direct.
    f.thumb = clamp01(actual / dur);
    f.windLamp += ((winding ? 1 : 0) - f.windLamp) * (1 - math.exp(-dt * 12));
    f.playLamp += ((t.playing ? 1 : 0) - f.playLamp) * ease(_lampEase);
    f.playLatched = t.playing;
    for (var i = 0; i < keyCount; i++) {
      final down = _held[i] || (i == 1 && t.playing);
      f.keyDown[i] = down;
      f.keyTravel[i] += ((down ? keyTravelDown : 0) - f.keyTravel[i]) * ease(_keyEase);
    }
    f.labelHint += ((_labelHover ? 1 : 0.55) - f.labelHint) * ease(_hintEase);
    f.remaining = '-${formatTime(dur - actual)}';
    f.changed();
  }

  /* ---------------------------------------------------------------- input -- */

  Offset _toView(Offset local) {
    final box = context.findRenderObject()! as RenderBox;
    return local * (viewW / box.size.width);
  }

  void _press(int key) {
    final t = _transport;
    switch (key) {
      case 0:
        t.skip(-15);
      case 1:
        t.play();
      case 2:
        t.pause();
      case 3:
        t.skip(30);
    }
  }

  void _onDown(PointerDownEvent e) {
    final p = _toView(e.localPosition);
    final hit = hitControl(p);
    _pointers[e.pointer] = hit;
    switch (hit.control) {
      case Control.knob:
        _transport.setVolume(knobVolumeAt(p));
      case Control.key:
        _held[hit.key] = true;
        _press(hit.key);
      case Control.slider:
        _transport.seek(sliderFractionAt(p) * _transport.duration);
      case Control.label:
      case Control.none:
        break;
    }
  }

  void _onMove(PointerMoveEvent e) {
    final p = _toView(e.localPosition);
    switch (_pointers[e.pointer]?.control) {
      case Control.knob:
        _transport.setVolume(knobVolumeAt(p));
      case Control.slider:
        _transport.seek(sliderFractionAt(p) * _transport.duration);
      default:
        break;
    }
  }

  void _onUp(PointerUpEvent e) {
    final hit = _release(e.pointer);
    // A click: pressed and released on the label.
    if (hit?.control == Control.label && hitControl(_toView(e.localPosition)).control == Control.label) {
      widget.onPickFile();
    }
  }

  ({Control control, int key})? _release(int pointer) {
    final hit = _pointers.remove(pointer);
    if (hit?.control == Control.key) _held[hit!.key] = false;
    return hit;
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent && hitControl(_toView(e.localPosition)).control == Control.knob) {
      GestureBinding.instance.pointerSignalResolver.register(e, (_) {
        _transport.setVolume(_transport.volume - e.scrollDelta.dy / 1500);
      });
    }
  }

  // Trackpad two-finger scrolls arrive as pan/zoom gestures on desktop.
  void _onPanStart(PointerPanZoomStartEvent e) =>
      _panOverKnob = hitControl(_toView(e.localPosition)).control == Control.knob;

  void _onPanUpdate(PointerPanZoomUpdateEvent e) {
    if (_panOverKnob) _transport.setVolume(_transport.volume + e.panDelta.dy / 1500);
  }

  void _onHover(PointerHoverEvent e) {
    final control = hitControl(_toView(e.localPosition)).control;
    _labelHover = control == Control.label;
    final cursor = switch (control) {
      Control.knob => SystemMouseCursors.grab,
      Control.none => MouseCursor.defer,
      _ => SystemMouseCursors.click,
    };
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  void _onExit(PointerExitEvent e) {
    _labelHover = false;
    if (_cursor != MouseCursor.defer) setState(() => _cursor = MouseCursor.defer);
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
          cssShadow(black.withValues(alpha: 0.65), y: 50, blur: 90),
          cssShadow(black.withValues(alpha: 0.5), y: 12, blur: 24),
          BoxShadow(color: white.withValues(alpha: 0.05), spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: MouseRegion(
          cursor: _cursor,
          onHover: _onHover,
          onExit: _onExit,
          child: Listener(
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: (e) => _release(e.pointer),
            onPointerSignal: _onSignal,
            onPointerPanZoomStart: _onPanStart,
            onPointerPanZoomUpdate: _onPanUpdate,
            child: Stack(
              children: [
                layer(BackplatePainter(), still: true),
                layer(ReelsPainter(_frame)),
                layer(FrontPainter(), still: true),
                layer(ControlsPainter(transport: _transport, episode: widget.episode)),
                layer(ControlsMotionPainter(_frame)),
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxDeckWidth),
      child: AspectRatio(aspectRatio: viewW / viewH, child: deck),
    );
  }
}

/// CSS `box-shadow: 0 y blur color`. Flutter's blur radius maps to sigma
/// differently from CSS (sigma = blur / 2), so convert.
BoxShadow cssShadow(Color color, {double y = 0, required double blur}) =>
    BoxShadow(color: color, offset: Offset(0, y), blurRadius: (blur / 2 - 0.5) / 0.57735);

/// The deck's inset top highlight, plus the green rim shown while a file is
/// dragged over it.
class _Rim extends CustomPainter {
  const _Rim({required this.dropping});

  final bool dropping;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(r), Path()..addRRect(r.shift(const Offset(0, 1)))),
      fill(white.withValues(alpha: 0.06)),
    );
    if (dropping) canvas.drawRRect(r.deflate(1.5), stroke(rgb(0x7dff6a, 0.55), 3));
  }

  @override
  bool shouldRepaint(_Rim oldDelegate) => oldDelegate.dropping != dropping;
}
