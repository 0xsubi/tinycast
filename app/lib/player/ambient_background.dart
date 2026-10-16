import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../deck/paint_kit.dart';
import '../deck/textures.dart';
import '../deck/transport.dart';

/// The stage behind the deck: soft coloured light for the glass controls to
/// refract. The warm glow behind the deck swells while the tape is running.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.transport});

  final Transport transport;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: widget.transport.playing ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    widget.transport.addListener(_sync);
  }

  @override
  void didUpdateWidget(AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      oldWidget.transport.removeListener(_sync);
      widget.transport.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.transport.removeListener(_sync);
    _glow.dispose();
    super.dispose();
  }

  void _sync() => widget.transport.playing ? _glow.forward() : _glow.reverse();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _AmbientPainter(CurvedAnimation(parent: _glow, curve: Curves.easeInOut)),
      child: const SizedBox.expand(),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.glow) : super(repaint: glow);

  final Animation<double> glow;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final span = math.max(size.width, size.height);
    final g = glow.value;

    void light(double x, double y, double r, Color c) {
      final centre = Offset(size.width * x, size.height * y);
      canvas.drawRect(
        all,
        shaded(
          userRadial(centre, span * r, [(0, c), (0.45, c.withValues(alpha: c.a * 0.4)), (1, c.withValues(alpha: 0))]),
        ),
      );
    }

    canvas.drawRect(all, fill(rgb(0x0b0a09)));
    // Warm tape-coloured light behind the deck
    light(0.5, 0.34, 0.62, rgb(0xff6a3a, 0.13 + 0.11 * g));
    // Cool counter-light low on either side
    light(0.06, 1.0, 0.6, rgb(0x3f7cff, 0.2));
    light(0.96, 0.95, 0.5, rgb(0xb14fff, 0.13));
    canvas
      ..drawRect(all, pattern(Textures.grain, 0.035))
      ..drawRect(
        all,
        shaded(boxRadial(all, 0.5, 0.45, 0.8, [(0.6, black.withValues(alpha: 0)), (1, black.withValues(alpha: 0.5))])),
      );
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => oldDelegate.glow != glow;
}
