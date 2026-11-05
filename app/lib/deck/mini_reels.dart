import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'backplate.dart';
import 'front_layer.dart';
import 'geometry.dart';
import 'paint_kit.dart';
import 'reels_layer.dart';
import 'transport.dart';

/// The whole mechanism in view-box units: both reels in their grooves, and
/// the head assembly below them, down to the pinch arm.
const Rect _view = Rect.fromLTRB(-210, -26 - reelR - 26, 2200, 734);

/// The deck's tape mechanism in miniature: the reels, the tape threaded past
/// the heads, and the head assembly, wound as far as [transport] has played
/// and turning while it plays. [height] logical pixels tall.
class MiniReels extends StatefulWidget {
  const MiniReels({super.key, required this.transport, required this.height});

  final Transport transport;
  final double height;

  /// Its width at [height].
  static double widthFor(double height) => height * _view.width / _view.height;

  @override
  State<MiniReels> createState() => _MiniReelsState();
}

class _MiniReelsState extends State<MiniReels> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _Turn _turn = _Turn();
  Duration? _last;

  @override
  void initState() {
    super.initState();
    widget.transport.addListener(_onTransport);
    _onTransport();
  }

  @override
  void didUpdateWidget(MiniReels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      oldWidget.transport.removeListener(_onTransport);
      widget.transport.addListener(_onTransport);
      _onTransport();
    }
  }

  @override
  void dispose() {
    widget.transport.removeListener(_onTransport);
    _ticker.dispose();
    _turn.dispose();
    super.dispose();
  }

  bool get _running => widget.transport.playing && !widget.transport.buffering;

  /// Packs follow the tape's position; the reels turn only while it runs.
  void _onTransport() {
    _turn.wind(widget.transport);
    if (_running && !_ticker.isActive) {
      _ticker.start();
    } else if (!_running && _ticker.isActive) {
      _ticker.stop();
      _last = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == null ? 0.0 : ((elapsed - _last!).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _turn.wind(widget.transport);
    _turn.spin(tapeSpeed * dt);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.height / _view.height;
    return SizedBox(
      width: MiniReels.widthFor(widget.height),
      height: widget.height,
      child: RepaintBoundary(
        child: CustomPaint(painter: _MiniReelsPainter(Placement(scale, offset: -_view.topLeft * scale), _turn)),
      ),
    );
  }
}

/// The reels' state: how far each has turned and how much tape it holds.
class _Turn extends ChangeNotifier {
  double angleL = rad(reels[Side.l]!.base);
  double angleR = rad(reels[Side.r]!.base);
  double radiusL = packRadius(1);
  double radiusR = packRadius(0);

  void wind(Transport t) {
    final p = clamp01(t.time / math.max(1, t.duration));
    final l = packRadius(1 - p);
    final r = packRadius(p);
    if (l == radiusL && r == radiusR) return;
    radiusL = l;
    radiusR = r;
    notifyListeners();
  }

  /// Runs [travel] view-box units of tape across; both reels turn
  /// counter-clockwise, the emptier one faster.
  void spin(double travel) {
    if (travel == 0) return;
    angleL = (angleL - travel / radiusL) % (math.pi * 2);
    angleR = (angleR - travel / radiusR) % (math.pi * 2);
    notifyListeners();
  }
}

class _MiniReelsPainter extends DeckPainter {
  _MiniReelsPainter(super.placement, this.turn)
    : _back = BackplatePainter(placement),
      _front = FrontPainter(placement),
      super(repaint: turn);

  final _Turn turn;
  final BackplatePainter _back;
  final FrontPainter _front;

  @override
  void paint(Canvas canvas, Size size) {
    _back.paint(canvas, size);
    super.paint(canvas, size);
    _front.paint(canvas, size);
  }

  /// The moving parts, as the deck's [ReelsPainter] draws them.
  @override
  void paintDeck(Canvas canvas, Size view) {
    final l = reels[Side.l]!.centre;
    final r = reels[Side.r]!.centre;
    paintTapePack(canvas, l, turn.radiusL);
    paintTapePack(canvas, r, turn.radiusR);
    canvas.drawPath(
      tapePath(turn.radiusL, turn.radiusR),
      stroke(rgb(0x5b3d27, 0.9), 0.8 * pixel)..strokeJoin = StrokeJoin.round,
    );
    paintFlange(canvas, l, turn.angleL);
    paintFlange(canvas, r, turn.angleR);
  }

  @override
  bool shouldRepaint(_MiniReelsPainter oldDelegate) => oldDelegate.placement != placement || oldDelegate.turn != turn;
}
