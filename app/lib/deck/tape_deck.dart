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

/// Eased values this close to their target are taken to have arrived.
const double _settle = 1e-3;

/// How long the deck keeps animating after anything wakes it, in seconds:
/// long enough for the player to report where a seek landed.
const double _linger = 0.5;

/// The upright mechanism is framed from the far edge of the reels' grooves
/// to the seam, so whole reels show beside the heads.
const double _reelEdge = -26 - reelR - 22;

/// Where the deck's parts sit in a box of [size], at [unit] logical pixels
/// per view-box unit: the band across the top, the label strip along the
/// bottom, and the tape mechanism scaled to fill the room between, turned on
/// its side when the device stands [upright].
class DeckLayout {
  const DeckLayout(this.size, this.unit, {this.upright = false});

  final Size size;
  final double unit;
  final bool upright;

  /// Width of the band and the strip, in view-box units.
  double get width => size.width / unit;

  double get _stripTop => size.height - stripH * unit;

  /// The room between the band and the strip.
  Rect get mechanism => Rect.fromLTRB(0, bandH * unit, size.width, math.max(bandH * unit, _stripTop));

  Placement get band => Placement(unit);

  /// The strip keeps its view-box coordinates, with the seam at its top.
  Placement get strip => Placement(unit, offset: Offset(0, _stripTop - seamY * unit));

  /// The mechanism, relative to [mechanism]. Lying down it is framed as in
  /// the reference photo, the band cutting off the tops of the reels; stood
  /// up it turns a quarter clockwise, the supply reel on top.
  Placement get tape {
    final room = mechanism.size;
    final centre = room.center(Offset.zero);
    if (!upright) {
      final s = math.min(room.width / viewW, room.height / (seamY - bandH));
      return Placement(s, offset: centre - const Offset(viewW / 2, (bandH + seamY) / 2) * s);
    }
    final s = math.min(room.width / (seamY - _reelEdge), room.height / viewW);
    // Turned, view (x, y) lands at (-y, x).
    return Placement(s, offset: centre - const Offset(-(_reelEdge + seamY) / 2, viewW / 2) * s, turned: true);
  }

  /// [local] in the strip's view-box units.
  Offset toStrip(Offset local) => (local - strip.offset) / unit;
}

/// Size of a button set into the band, at [unit].
double bandButtonSize(double unit) => math.min(44, bandH * unit * 0.62);

class TapeDeck extends StatefulWidget {
  const TapeDeck({
    super.key,
    required this.transport,
    required this.episode,
    required this.onPickFile,
    required this.onDropFiles,
    this.unit = 0.5,
    this.upright = false,
    this.failed = false,
    this.leading,
    this.acceptsDrops = false,
  });

  final Transport transport;
  final Episode episode;
  final VoidCallback onPickFile;
  final ValueChanged<List<DropItem>> onDropFiles;

  /// Logical pixels per view-box unit for the band and the strip.
  final double unit;

  /// Stand the tape mechanism on its side, for a portrait screen.
  final bool upright;

  /// Playback failed; the display says so.
  final bool failed;

  /// A button set into the left of the band, before the wordmark.
  final Widget? leading;

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

  /// The deck animates until at least this [DeckFrame.clock] time.
  double _awakeUntil = 0;

  /// The episode's title is too long for the label and scrolls.
  late bool _scrolls;

  final Set<int> _labelPointers = {};
  final Set<int> _loadPointers = {};
  bool _labelHover = false;
  bool _loadHover = false;
  bool _dragOver = false;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    final t = _transport;
    _display = t.time;
    _frame = DeckFrame(clamp01(t.time / math.max(1, t.duration)))..lamp = t.playing ? 1 : 0;
    _scrolls = titleScrolls(widget.episode.title);
    _ticker = createTicker(_onTick);
    _listen(t);
    _wake();
  }

  @override
  void didUpdateWidget(TapeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      _unlisten(oldWidget.transport);
      _listen(widget.transport);
    }
    if (oldWidget.episode.title != widget.episode.title) {
      _frame.titleSince = _frame.clock;
      _scrolls = titleScrolls(widget.episode.title);
    }
    _wake();
  }

  @override
  void dispose() {
    _unlisten(_transport);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _listen(Transport t) {
    t.addListener(_wake);
    t.jumps.addListener(_wake);
  }

  void _unlisten(Transport t) {
    t.removeListener(_wake);
    t.jumps.removeListener(_wake);
  }

  /// Something may move: animate until the deck comes to rest again.
  void _wake() {
    _awakeUntil = _frame.clock + _linger;
    if (!_ticker.isActive) _ticker.start();
  }

  /// Per-frame animation. Tape moves at constant linear speed, so each reel's
  /// angular speed is v / r — the nearly-empty reel spins visibly faster.
  /// Repaints only the layers whose parts moved, and stops once the deck is
  /// at rest; [_wake] starts it again.
  void _onTick(Duration elapsed) {
    final t = _transport;
    final f = _frame;
    final gap = _last == null ? 0.0 : (elapsed - _last!).inMicroseconds / 1e6;
    final dt = gap.clamp(0.0, 0.05);
    _last = elapsed;
    f.clock += gap;
    t.tick();

    double ease(double tau) => 1 - math.exp(-dt / tau);
    double approach(double value, double target, double k) {
      final next = value + (target - value) * k;
      return (target - next).abs() < _settle ? target : next;
    }

    final running = t.playing && !t.buffering ? 1.0 : 0.0;
    final dur = math.max(1.0, t.duration);
    final actual = math.min(t.time, dur);
    // After a long stall (app in background) just catch up instead of fast-winding.
    if (gap > 0.25) _display = actual;
    _motor = approach(_motor, running, 1 - math.exp(-dt * _motorRate));

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
    if (t.winding != 0 && diff.abs() <= _snap) t.wound();

    final reels = (f.angle[Side.l], f.angle[Side.r], f.radius[Side.l], f.radius[Side.r]);
    final p = clamp01(_display / dur);
    f.radius[Side.l] = packRadius(1 - p);
    f.radius[Side.r] = packRadius(p);
    final limit = _maxOmega * dt * math.min(f.radius[Side.l]!, f.radius[Side.r]!);
    travel = travel.clamp(-limit, limit);
    for (final side in Side.values) {
      // Both reels turn counter-clockwise when the tape runs forward.
      f.angle[side] = (f.angle[side]! - travel / f.radius[side]!) % (math.pi * 2);
    }
    if (reels != (f.angle[Side.l], f.angle[Side.r], f.radius[Side.l], f.radius[Side.r])) f.spin.fire();

    final hint = f.labelHint;
    final hintTarget = _labelHover ? 1.0 : 0.55;
    f.labelHint = approach(f.labelHint, hintTarget, ease(_hintEase));
    if (f.labelHint != hint) f.hint.fire();

    final load = f.loadTravel;
    final loadTarget = _loadPointers.isNotEmpty ? 1.0 : 0.0;
    f.loadTravel = approach(f.loadTravel, loadTarget, ease(_buttonEase));
    if (f.loadTravel != load) f.strip.fire();

    // The display: the state of the tape and the elapsed time.
    final display = (f.headline, f.readout, f.lamp);
    f.lamp = approach(f.lamp, running, ease(_lampEase));
    f.headline = switch (t) {
      _ when widget.failed => 'ERROR',
      _ when t.buffering => 'LOAD',
      _ when diff.abs() > _snap => 'WIND',
      _ when t.playing => 'PLAY',
      _ => 'PAUSE',
    };
    f.readout = displayTime(actual);
    if (display != (f.headline, f.readout, f.lamp)) f.display.fire();

    if (_scrolls) f.title.fire();

    final resting =
        !t.playing &&
        t.winding == 0 &&
        _display == actual &&
        _motor == running &&
        f.lamp == running &&
        f.labelHint == hintTarget &&
        f.loadTravel == loadTarget &&
        !_scrolls &&
        f.clock >= _awakeUntil;
    if (resting) {
      _ticker.stop();
      _last = null;
    }
  }

  /* ---------------------------------------------------------------- input -- */

  DeckLayout get _layout => DeckLayout(context.size!, widget.unit, upright: widget.upright);

  bool _onLabel(Offset local) => hitLabel(_layout.toStrip(local), _layout.width);
  bool _onLoad(Offset local) => hitLoad(_layout.toStrip(local));

  void _onDown(PointerDownEvent e) {
    if (_onLabel(e.localPosition)) _labelPointers.add(e.pointer);
    if (_onLoad(e.localPosition)) _loadPointers.add(e.pointer);
    _wake();
  }

  void _onUp(PointerUpEvent e) {
    // A click: pressed and released on the label or the load button.
    final label = _labelPointers.remove(e.pointer) && _onLabel(e.localPosition);
    final load = _loadPointers.remove(e.pointer) && _onLoad(e.localPosition);
    _wake();
    if (label || load) widget.onPickFile();
  }

  void _onCancel(PointerCancelEvent e) {
    _labelPointers.remove(e.pointer);
    _loadPointers.remove(e.pointer);
    _wake();
  }

  void _onHover(PointerHoverEvent e) {
    final label = _onLabel(e.localPosition);
    final load = _onLoad(e.localPosition);
    if (label != _labelHover || load != _loadHover) {
      setState(() {
        _labelHover = label;
        _loadHover = load;
      });
      _wake();
    }
  }

  void _onExit(PointerExitEvent e) {
    if (_labelHover || _loadHover) {
      setState(() => _labelHover = _loadHover = false);
      _wake();
    }
  }

  /* --------------------------------------------------------------- layout -- */

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = DeckLayout(constraints.biggest, widget.unit, upright: widget.upright);
      Widget layer(CustomPainter painter, {bool still = false}) => Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: painter, isComplex: still, willChange: !still),
        ),
      );

      // Leave room in the band for the leading button: 16 px either side.
      final leadingSize = bandButtonSize(widget.unit);
      final inset = widget.leading == null ? 70.0 : (leadingSize + 32) / widget.unit;
      final tape = layout.tape;
      final band = layout.band;
      final strip = layout.strip;

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
              Positioned.fromRect(
                rect: layout.mechanism,
                child: ClipRect(
                  child: Stack(
                    children: [
                      layer(BackplatePainter(tape), still: true),
                      layer(ReelsPainter(tape, _frame)),
                      layer(FrontPainter(tape), still: true),
                    ],
                  ),
                ),
              ),
              layer(BandPainter(band, inset: inset), still: true),
              layer(DisplayPainter(band, _frame, widget.episode)),
              layer(StripPainter(strip, _frame)),
              layer(LabelPainter(strip, transport: _transport, episode: widget.episode)),
              layer(LabelTitlePainter(strip, _frame, widget.episode)),
              layer(LabelHintPainter(strip, _frame)),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _DropRim(dropping: _dragOver)),
                ),
              ),
              if (widget.leading != null)
                Positioned(
                  left: 16,
                  top: (bandH * widget.unit - leadingSize) / 2,
                  width: leadingSize,
                  height: leadingSize,
                  child: widget.leading!,
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
      return deck;
    },
  );
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
