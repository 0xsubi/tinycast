import 'package:flutter/cupertino.dart';

import '../deck/paint_kit.dart';
import '../deck/metal.dart';

/// The app accent: signal orange, for lit lamps, glyphs and the primary cap.
const Color accent = Color(0xFFF05A24);

/// The accent deepened enough to read as lettering on the aluminium.
const Color accentInk = Color(0xFFC2410C);

/// Destructive actions.
const Color danger = Color(0xFFB3261E);

/// Engraved lettering and icons on the aluminium.
const Color ink = Color(0xFF1C1C1B);

/// The body behind everything, before its texture is painted.
const Color stage = Color(0xFFD4D4D2);

Color inkAt(double alpha) => ink.withValues(alpha: alpha);

/// Text in [ink] by default, engraved into the metal: a light lower lip
/// under each letter. Its [alpha] is lifted a little so quiet text stays
/// legible on the pale metal.
TextStyle textStyle({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  double alpha = 0.9,
  double height = 1.35,
  double spacing = 0,
  Color? color,
}) => TextStyle(
  fontFamily: urbanist,
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: spacing,
  color: color ?? inkAt(0.25 + 0.75 * alpha),
  shadows: color == null ? const [Shadow(color: Color(0x99FFFFFF), offset: Offset(0, 1))] : null,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Small uppercase section label.
TextStyle eyebrow({Color? color}) =>
    textStyle(size: 11.5, weight: FontWeight.w600, spacing: 1.4, alpha: 0.5, color: color);

/// Text whose digits each sit in a fixed-width slot, for numbers that tick
/// (times, percentages). Urbanist has no tabular figures; see [digitCell].
class TabularText extends StatelessWidget {
  const TabularText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = DefaultTextStyle.of(context).style.merge(style);
    final cell = digitCell(s.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(s.fontSize ?? 14)));
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final c in text.split(''))
              c.codeUnitAt(0) ^ 0x30 <= 9
                  ? SizedBox(
                      width: cell,
                      child: Text(c, style: s, textAlign: TextAlign.center),
                    )
                  : Text(c, style: s),
          ],
        ),
      ),
    );
  }
}

/// Square podcast or episode artwork with rounded corners, set into the
/// metal like the deck's display (unless [shadow] is off), with a
/// placeholder while (or if) the image cannot load.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.url, required this.size, this.radius, this.shadow = true});

  final String? url;
  final double size;
  final double? radius;

  /// Set the artwork into a recess.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final corner = radius ?? size * 0.12;
    final r = BorderRadius.circular(corner);
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF26B3A), Color(0xFF3A2620)],
        ),
      ),
      child: Center(
        child: Icon(CupertinoIcons.waveform, size: size * 0.4, color: white.withValues(alpha: 0.75)),
      ),
    );
    final u = url;
    final image = ClipRRect(
      borderRadius: r,
      child: u == null
          ? placeholder
          : Image.network(
              u,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (context, child, frame, sync) => sync
                  ? child
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: frame == null ? placeholder : child,
                    ),
            ),
    );
    return SizedBox.square(
      dimension: size,
      child: shadow ? CustomPaint(painter: _ArtRecess(corner), child: image) : image,
    );
  }
}

/// The pocket artwork sits in: a dark rim with light on its lower lip.
class _ArtRecess extends CustomPainter {
  const _ArtRecess(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).inflate(1.5), Radius.circular(radius + 1.5));
    canvas
      ..drawRRect(r.shift(const Offset(0, 1.2)), fill(white.withValues(alpha: 0.8)))
      ..drawRRect(r, fill(gap));
  }

  @override
  bool shouldRepaint(_ArtRecess oldDelegate) => oldDelegate.radius != radius;
}
