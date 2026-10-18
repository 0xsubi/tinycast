import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../ui/style.dart';
import 'backplate.dart';
import 'display_layer.dart';
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
const double _lampEase = 0.06;
const double _buttonEase = 0.025;

/// How long the display shows the volume after it changes (s).
const double _volumeShown = 1.4;

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
  final Set<int> _loadPointers = {};
  bool _labelHover = false;
  bool _loadHover = false;
  bool _dragOver = false;

  late double _volume;
  double _volumeAge = _volumeShown;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    final t = _transport;
    _display = t.time;
    _volume = t.volume;
    _frame = DeckFrame(clamp01(t.time / math.max(1, t.duration)))..lamp = t.playing ? 1 : 0;
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

    double ease(double tau) => 1 - math.exp(-dt / tau);
    f.labelHint += ((_labelHover ? 1 : 0.55) - f.labelHint) * ease(_hintEase);
    f.lamp += ((t.playing && !t.buffering ? 1 : 0) - f.lamp) * ease(_lampEase);
    f.loadTravel += ((_loadPointers.isNotEmpty ? 1 : 0) - f.loadTravel) * ease(_buttonEase);

    // The display: the volume briefly after it changes, otherwise the state
    // of the tape and the elapsed time.
    if (t.volume != _volume) {
      _volume = t.volume;
      _volumeAge = 0;
    }
    _volumeAge += dt;
    if (_volumeAge < _volumeShown) {
      f.headline = 'VOL';
      f.readout = '${(t.volume * 100).round()}';
    } else {
      f.headline = switch (t) {
        _ when t.buffering => 'LOAD',
        _ when diff.abs() > _snap => 'WIND',
        _ when t.playing => 'PLAY',
        _ => 'PAUSE',
      };
      f.readout = displayTime(actual);
    }
    f.changed();
  }

  /* ---------------------------------------------------------------- input -- */

  Offset _toView(Offset local) {
    final box = context.findRenderObject()! as RenderBox;
    return local * (viewW / box.size.width);
  }

  bool _onLabel(Offset local) => hitLabel(_toView(local));
  bool _onLoad(Offset local) => hitLoad(_toView(local));

  void _onDown(PointerDownEvent e) {
    if (_onLabel(e.localPosition)) _labelPointers.add(e.pointer);
    if (_onLoad(e.localPosition)) _loadPointers.add(e.pointer);
  }

  void _onUp(PointerUpEvent e) {
    // A click: pressed and released on the label or the load button.
    final label = _labelPointers.remove(e.pointer) && _onLabel(e.localPosition);
    final load = _loadPointers.remove(e.pointer) && _onLoad(e.localPosition);
    if (label || load) widget.onPickFile();
  }

  void _onCancel(PointerCancelEvent e) {
    _labelPointers.remove(e.pointer);
    _loadPointers.remove(e.pointer);
  }

  void _onHover(PointerHoverEvent e) {
    final label = _onLabel(e.localPosition);
    final load = _onLoad(e.localPosition);
    if (label != _labelHover || load != _loadHover) {
      setState(() {
        _labelHover = label;
        _loadHover = load;
      });
    }
  }

  void _onExit(PointerExitEvent e) {
    if (_labelHover || _loadHover) {
      setState(() => _labelHover = _loadHover = false);
    }
  }

  /* --------------------------------------------------------------- layout -- */

  @override
  Widget build(BuildContext context) {
    Widget layer(CustomPainter painter, {bool still = false}) => Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(painter: painter, isComplex: still, willChange: !still),
      ),
    );

    // The deck is drawn onto the device's aluminium; see the player's body.
    Widget deck = MouseRegion(
      cursor: _labelHover || _loadHover ? SystemMouseCursors.click : MouseCursor.defer,
      onHover: _onHover,
      onExit: _onExit,
      child: Listener(
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: Stack(
          children: [
            layer(BackplatePainter(), still: true),
            layer(ReelsPainter(_frame)),
            layer(FrontPainter(), still: true),
            layer(LabelPainter(transport: _transport, episode: widget.episode)),
            layer(LabelHintPainter(_frame)),
            layer(DisplayPainter(_frame, widget.episode)),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DropRim(dropping: _dragOver)),
              ),
            ),
          ],
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

/// Accent outline while a file is dragged over the deck.
class _DropRim extends CustomPainter {
  const _DropRim({required this.dropping});

  final bool dropping;

  @override
  void paint(Canvas canvas, Size size) {
    if (!dropping) return;
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(6), const Radius.circular(18));
    canvas.drawRRect(r, stroke(accent.withValues(alpha: 0.8), 3));
  }

  @override
  bool shouldRepaint(_DropRim oldDelegate) => oldDelegate.dropping != dropping;
}

/// TP-7-style clock: hours.minutes.seconds, "0.09.24".
String displayTime(double seconds) {
  final s = seconds.isFinite ? math.max(0, seconds.floor()) : 0;
  final h = s ~/ 3600;
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return '$h.$m.$ss';
}
