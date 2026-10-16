import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../deck/paint_kit.dart';
import '../deck/textures.dart';

/// The app accent: the orange-red of a tape deck's RECORD key.
const Color accent = Color(0xFFD13F26);

/// Warm off-white used for text and icons on the dark glass.
const Color ink = Color(0xFFF2EDE6);

const Color stage = Color(0xFF0B0A09);

/// Accent-tinted glass for the one primary action on a page (Play).
const LiquidGlassSettings accentGlass = LiquidGlassSettings(
  glassColor: Color(0xD9D13F26),
  thickness: 24,
  blur: 8,
  lightIntensity: 0.7,
  saturation: 1.4,
);

Color inkAt(double alpha) => ink.withValues(alpha: alpha);

TextStyle textStyle({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  double alpha = 0.9,
  double height = 1.35,
  double spacing = 0,
  Color? color,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: spacing,
  color: color ?? inkAt(alpha),
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Small uppercase section label.
TextStyle eyebrow({Color? color}) =>
    textStyle(size: 11.5, weight: FontWeight.w600, spacing: 1.4, alpha: 0.5, color: color);

/// Square podcast or episode artwork with rounded corners, a soft shadow and
/// a placeholder while (or if) the image cannot load.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.url, required this.size, this.radius, this.shadow = true});

  final String? url;
  final double size;
  final double? radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? size * 0.12);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.55), const Color(0xFF2A1712)],
        ),
      ),
      child: Center(
        child: Icon(CupertinoIcons.waveform, size: size * 0.4, color: inkAt(0.7)),
      ),
    );
    final u = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [BoxShadow(color: black.withValues(alpha: 0.45), blurRadius: size * 0.12, offset: Offset(0, size * 0.04))]
            : null,
      ),
      child: ClipRRect(
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
      ),
    );
  }
}

/// Backdrop for the browse pages: the artwork blown up and blurred into a
/// wash of colour when there is one, soft ambient light otherwise. Gives the
/// glass something to refract.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, this.artwork});

  final String? artwork;

  @override
  Widget build(BuildContext context) {
    final art = artwork;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _AmbientLight()),
        if (art != null)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.mirror),
            child: Opacity(
              opacity: 0.75,
              child: Image.network(
                art,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
        // Keep text readable over bright artwork.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                stage.withValues(alpha: art == null ? 0 : 0.45),
                stage.withValues(alpha: art == null ? 0.2 : 0.8),
              ],
            ),
          ),
        ),
        CustomPaint(painter: _Grain()),
      ],
    );
  }
}

class _AmbientLight extends CustomPainter {
  const _AmbientLight();

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final span = size.longestSide;
    void light(double x, double y, double r, Color c) {
      final centre = Offset(size.width * x, size.height * y);
      canvas.drawRect(
        all,
        shaded(
          userRadial(centre, span * r, [(0, c), (0.45, c.withValues(alpha: c.a * 0.4)), (1, c.withValues(alpha: 0))]),
        ),
      );
    }

    canvas.drawRect(all, fill(stage));
    light(0.18, 0.0, 0.6, accent.withValues(alpha: 0.22));
    light(0.95, 0.35, 0.5, rgb(0xff8f3f, 0.10));
    light(0.1, 1.0, 0.6, rgb(0x3f7cff, 0.16));
    light(0.9, 1.0, 0.5, rgb(0xb14fff, 0.10));
  }

  @override
  bool shouldRepaint(_AmbientLight oldDelegate) => false;
}

class _Grain extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, pattern(Textures.grain, 0.03));

  @override
  bool shouldRepaint(_Grain oldDelegate) => false;
}
