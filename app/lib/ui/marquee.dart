import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../deck/label_layer.dart' show marqueeOffset;

/// The crawl, in logical pixels: about the deck label's pace on screen.
const double _speed = 24;
const double _gap = 44;

/// How far in from each edge the text fades.
const double _fade = 14;

/// One line of [text] that, when too long for its room, scrolls through it
/// like the deck's paper label: a pause at the start, a slow crawl left until
/// the next copy has taken its place, fading in and out at the edges.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _clock = ValueNotifier(0);

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new title starts from its beginning.
    if (oldWidget.text != widget.text) _clock.value = 0;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) => _clock.value = elapsed.inMicroseconds / 1e6;

  /// Runs the clock only while the text overflows.
  void _run(bool scrolls) {
    if (scrolls == _ticker.isActive) return;
    if (scrolls) {
      _ticker.start();
    } else {
      _ticker.stop();
      _clock.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      final room = constraints.maxWidth;
      final scrolls = width > room;
      // Not during build: starting a ticker schedules a frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(scrolls);
      });
      final line = Text(widget.text, maxLines: 1, softWrap: false, style: widget.style);
      if (!scrolls) return line;
      final f = _fade / room;
      return SizedBox(
        width: room,
        height: painter.height,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
            stops: [0, f, 1 - f, 1],
          ).createShader(bounds),
          child: ClipRect(
            child: ValueListenableBuilder<double>(
              valueListenable: _clock,
              builder: (context, t, child) {
                final x = marqueeOffset(width, room, t, speed: _speed, gap: _gap);
                return OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Transform.translate(offset: Offset(x, 0), child: child),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line,
                  const SizedBox(width: _gap),
                  line,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
