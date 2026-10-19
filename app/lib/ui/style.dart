import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../deck/paint_kit.dart';
import '../deck/textures.dart';

/// The app accent: signal orange.
const Color accent = Color(0xFFF05A24);

/// Warm off-white used for text and icons on the dark glass.
const Color ink = Color(0xFFF2EDE6);

const Color stage = Color(0xFF0B0A09);

/// Accent-tinted glass for the one primary action on a page (Play).
const LiquidGlassSettings accentGlass = LiquidGlassSettings(
  glassColor: Color(0xD9F05A24),
  thickness: 24,
  blur: 8,
  lightIntensity: 0.7,
  saturation: 1.4,
);

/// Glass for cards that scroll: a frosted blur without the refraction shader,
/// which would otherwise run once per visible card on every scroll frame.
const GlassQuality cardGlass = GlassQuality.minimal;

Color inkAt(double alpha) => ink.withValues(alpha: alpha);

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
  color: color ?? inkAt(alpha),
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
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _AmbientLight()),
          if (art != null) _Wash(art),
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
      ),
    );
  }
}

/// Width of an artwork wash in pixels, and its blur in those pixels: scaled
/// up to fill the screen, about the 70-point blur of the full-size artwork.
const int _washWidth = 32;
const double _washBlur = 2.4;

/// The artwork blurred into a small wash, made once per image and scaled up
/// to fill. Blurring it at screen size instead would cost a screen-sized blur
/// every time the glass above is drawn.
class _Wash extends StatefulWidget {
  const _Wash(this.url);

  final String url;

  @override
  State<_Wash> createState() => _WashState();
}

class _WashState extends State<_Wash> {
  ui.Image? _image;

  /// Bumped by every load, so a slow one never replaces a newer one.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Wash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    final load = ++_loads;
    final image = await _washOf(widget.url);
    if (!mounted || load != _loads) return image?.dispose();
    setState(() {
      _image?.dispose();
      _image = image;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawImage(
    image: _image,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.medium,
    opacity: const AlwaysStoppedAnimation(0.75),
  );
}

/// Recent washes by artwork URL, oldest first.
final Map<String, Future<ui.Image?>> _washes = {};
const int _keptWashes = 12;

/// A handle on the wash for [url], or null when the artwork cannot load.
/// The caller disposes it.
Future<ui.Image?> _washOf(String url) async {
  final wash = _washes.remove(url) ?? _makeWash(url);
  _washes[url] = wash;
  if (_washes.length > _keptWashes) {
    final oldest = _washes.keys.first;
    unawaited(_washes.remove(oldest)!.then((image) => image?.dispose()));
  }
  final image = await wash;
  if (image == null && identical(_washes[url], wash)) _washes.remove(url);
  return image?.clone();
}

Future<ui.Image?> _makeWash(String url) async {
  final ui.Image small;
  try {
    small = await _decode(ResizeImage(NetworkImage(url), width: _washWidth));
  } catch (_) {
    return null;
  }
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(
    small,
    Offset.zero,
    Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: _washBlur, sigmaY: _washBlur, tileMode: TileMode.mirror),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(small.width, small.height);
  } finally {
    picture.dispose();
    small.dispose();
  }
}

/// The first frame of [provider].
Future<ui.Image> _decode(ImageProvider provider) {
  final done = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      done.complete(info.image.clone());
      info.dispose();
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      done.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return done.future;
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
