import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../deck/metal.dart';
import '../deck/paint_kit.dart';
import '../deck/textures.dart';
import 'style.dart';

// The browse pages' hardware: the same bead-blasted aluminium, engraved
// lettering, sinking key caps and black display windows as the tape deck.
// Everything here is flat fills, hairlines and one tiled texture: no blurs,
// no backdrop sampling, so scrolling stays cheap.

/// Engraved lettering's light lower lip.
const List<Shadow> engravedShadow = [Shadow(color: Color(0xB3FFFFFF), offset: Offset(0, 1))];

/* ---------------------------------------------------------------- body -- */

/// The device body behind a page: aluminium lit from the top left. Painted
/// once and cached; content scrolls over it without repainting it.
class MetalBackground extends StatelessWidget {
  const MetalBackground({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
    child: CustomPaint(painter: _BodyPainter(), isComplex: true, child: SizedBox.expand()),
  );
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    fillAluminium(canvas, all);
    canvas.drawRect(
      all,
      shaded(boxRadial(all, 0.3, 0.05, 0.9, [(0, white.withValues(alpha: 0.16)), (1, white.withValues(alpha: 0))])),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) => false;
}

/// A strip of the body, for bands that sit above scrolling content: its own
/// aluminium, with a hairline seam cut along [seamTop] or the bottom edge.
class MetalBand extends StatelessWidget {
  const MetalBand({super.key, required this.child, this.seamTop = false});

  final Widget child;
  final bool seamTop;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BandPainter(seamTop: seamTop),
    child: child,
  );
}

class _BandPainter extends CustomPainter {
  const _BandPainter({required this.seamTop});

  final bool seamTop;

  @override
  void paint(Canvas canvas, Size size) {
    fillAluminium(canvas, Offset.zero & size);
    final y = seamTop ? 0.5 : size.height - 1.5;
    engraveLine(canvas, Offset(0, y), Offset(size.width, y), width: 1);
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) => oldDelegate.seamTop != seamTop;
}

/// A hairline cut across the metal.
class EngravedRule extends StatelessWidget {
  const EngravedRule({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 2, child: CustomPaint(painter: _RulePainter()));
}

class _RulePainter extends CustomPainter {
  const _RulePainter();

  @override
  void paint(Canvas canvas, Size size) => engraveLine(canvas, Offset.zero, Offset(size.width, 0), width: 1);

  @override
  bool shouldRepaint(_RulePainter oldDelegate) => false;
}

/* --------------------------------------------------------------- parts -- */

/// A pocket cut into the metal for [r]: light catching its lower lip, then the dark gap.
void paintRecess(Canvas canvas, RRect r, {double lip = 1.2}) {
  canvas
    ..drawRRect(r.shift(Offset(0, lip)), fill(white.withValues(alpha: 0.8)))
    ..drawRRect(r, fill(gap));
}

/// A machined face: [base] metal (key aluminium by default), lit along its
/// top chamfer, darkening a touch as it sinks [travel] (0–1) out of the light.
void paintFace(Canvas canvas, RRect face, {Color? base, double travel = 0}) {
  final rect = face.outerRect;
  final color = Color.lerp(base ?? keyAluminium, black, travel * 0.08)!;
  canvas
    ..save()
    ..clipRRect(face)
    ..drawRect(rect, fill(color))
    ..drawRect(rect, pattern(Textures.bead, 0.16, blend: BlendMode.overlay))
    ..drawRect(
      rect,
      shaded(
        boxLinear(rect, 0, 0, 0, 1, [
          (0, white.withValues(alpha: 0.35 * (1 - travel * 0.6))),
          (math.min(0.5, 14 / rect.height), white.withValues(alpha: 0.04)),
          (0.85, black.withValues(alpha: 0)),
          (1, black.withValues(alpha: 0.1)),
        ]),
      ),
    )
    ..drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 1.2), fill(white.withValues(alpha: 0.85 - travel * 0.4)))
    ..restore()
    ..drawRRect(face.deflate(0.5), stroke(black.withValues(alpha: 0.22), 1));
}

/// A plate fitted into the body: a lighter, separately finished part in a
/// thin dark seam. Tappable plates sink a little while held.
class MetalPlate extends StatefulWidget {
  const MetalPlate({super.key, required this.child, this.padding = EdgeInsets.zero, this.radius = 18, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  State<MetalPlate> createState() => _MetalPlateState();
}

class _MetalPlateState extends State<MetalPlate> {
  bool _held = false;

  void _hold(bool held) {
    if (held != _held) setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) {
    final plate = CustomPaint(
      painter: _PlatePainter(radius: widget.radius, travel: _held ? 1 : 0),
      child: Padding(padding: widget.padding, child: widget.child),
    );
    final onTap = widget.onTap;
    if (onTap == null) return plate;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _hold(true),
      onTapUp: (_) => _hold(false),
      onTapCancel: () => _hold(false),
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: plate),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.radius, required this.travel});

  final double radius;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final seam = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    paintRecess(canvas, seam, lip: 1);
    paintFace(canvas, seam.deflate(1.5), travel: travel);
  }

  @override
  bool shouldRepaint(_PlatePainter oldDelegate) => oldDelegate.radius != radius || oldDelegate.travel != travel;
}

/* ------------------------------------------------------------- buttons -- */

/// How far a latched key rests, of its full travel.
const double _latchedTravel = 0.6;

/// A key cap set in a recess: sinks when pressed and springs back with a
/// little overshoot, like the deck's transport keys. [accent] makes it the
/// orange cap for a page's one primary action; [latched] holds it part-way
/// down (a selected tab or chip) and [lit] lights its glyph.
class MetalButton extends StatefulWidget {
  const MetalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 44,
    this.width,
    this.radius,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.accent = false,
    this.latched = false,
    this.lit = false,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double height;

  /// Fixed width; by default as wide as [child] and [padding].
  final double? width;

  /// Corner radius; a pill by default.
  final double? radius;
  final EdgeInsetsGeometry padding;
  final bool accent;
  final bool latched;
  final bool lit;
  final String? semanticLabel;

  @override
  State<MetalButton> createState() => _MetalButtonState();
}

class _MetalButtonState extends State<MetalButton> with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(vsync: this, value: widget.latched ? _latchedTravel : 0);
  bool _held = false;

  @override
  void didUpdateWidget(MetalButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latched != widget.latched && !_held) _settle();
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  void _down() {
    _held = true;
    _travel.animateTo(1, duration: const Duration(milliseconds: 55), curve: Curves.easeIn);
    HapticFeedback.selectionClick();
  }

  void _up() {
    _held = false;
    _settle();
  }

  void _settle() => _travel.animateTo(
    widget.latched ? _latchedTravel : 0,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutBack,
  );

  @override
  Widget build(BuildContext context) {
    final accentCap = widget.accent;
    final glyph = accentCap ? white : (widget.lit ? accent : engraving);
    final shadows = accentCap || widget.lit ? null : engravedShadow;
    final radius = widget.radius ?? widget.height / 2;
    Widget content = IconTheme.merge(
      data: IconThemeData(color: glyph, size: 20, shadows: shadows),
      child: DefaultTextStyle.merge(
        style: textStyle(size: 15, weight: FontWeight.w600, color: glyph).copyWith(shadows: shadows),
        child: widget.child,
      ),
    );
    content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Padding(
        padding: widget.padding,
        child: Align(widthFactor: widget.width == null ? 1 : null, child: content),
      ),
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _travel,
            builder: (context, child) => CustomPaint(
              painter: _CapPainter(travel: _travel.value, radius: radius, orange: accentCap),
              child: Transform.translate(offset: Offset(0, _travel.value * 1.8), child: child),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _CapPainter extends CustomPainter {
  const _CapPainter({required this.travel, required this.radius, required this.orange});

  final double travel;
  final double radius;
  final bool orange;

  @override
  void paint(Canvas canvas, Size size) {
    final pocket = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    paintRecess(canvas, pocket);
    // The cap stands a little proud of the gap; its underside shows below
    // until it is pressed home.
    final face = RRect.fromRectAndRadius(
      Rect.fromLTRB(2.5, 2.5, size.width - 2.5, size.height - 3.5).shift(Offset(0, travel * 1.8)),
      Radius.circular(math.max(0, radius - 2.5)),
    );
    canvas.drawRRect(face.shift(Offset(0, 1.6 - travel * 1.2)), fill(black.withValues(alpha: 0.4)));
    paintFace(canvas, face, base: orange ? accent : null, travel: travel);
  }

  @override
  bool shouldRepaint(_CapPainter oldDelegate) =>
      oldDelegate.travel != travel || oldDelegate.radius != radius || oldDelegate.orange != orange;
}

/// A round key cap with an icon.
class MetalIconButton extends StatelessWidget {
  const MetalIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.iconSize = 20,
    this.lit = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final bool lit;

  @override
  Widget build(BuildContext context) => MetalButton(
    onPressed: onPressed,
    semanticLabel: semanticLabel,
    width: size,
    height: size,
    padding: EdgeInsets.zero,
    lit: lit,
    child: Icon(icon, size: iconSize),
  );
}

/// Keys side by side, one latched down: a choice of one.
class MetalSegments extends StatelessWidget {
  const MetalSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = 36,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, label) in labels.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: MetalButton(
            onPressed: () => onSelected(i),
            height: height,
            radius: 10,
            padding: EdgeInsets.zero,
            latched: i == selected,
            lit: i == selected,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    ],
  );
}

/// A small status light, lit or dark, like the deck's lamp.
class Lamp extends StatelessWidget {
  const Lamp({super.key, required this.on, this.size = 7});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LampPainter(on)),
  );
}

class _LampPainter extends CustomPainter {
  const _LampPainter(this.on);

  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas
      ..drawCircle(c + const Offset(0, 1), r, fill(white.withValues(alpha: 0.7)))
      ..drawCircle(c, r, fill(on ? accent : rgb(0x8f8a87)));
    if (on) canvas.drawCircle(c - Offset(r * 0.3, r * 0.3), r * 0.3, fill(white.withValues(alpha: 0.6)));
  }

  @override
  bool shouldRepaint(_LampPainter oldDelegate) => oldDelegate.on != on;
}

/* ------------------------------------------------------------- display -- */

/// The deck's OLED: a black window in a grey bezel set into the metal, for
/// live readouts and typing. Text on it is white.
class DisplayWindow extends StatelessWidget {
  const DisplayWindow({super.key, required this.child, this.padding = EdgeInsets.zero, this.radius = 14});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DisplayPainter(radius),
    foregroundPainter: _GlarePainter(radius),
    child: Padding(padding: padding, child: child),
  );
}

/// Colour of lettering on a [DisplayWindow].
const Color pixel = Color(0xF0FFFFFF);

class _DisplayPainter extends CustomPainter {
  const _DisplayPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final glass = RRect.fromRectAndRadius((Offset.zero & size).deflate(3), Radius.circular(radius));
    canvas
      ..drawRRect(glass.inflate(3).shift(const Offset(0, 1.5)), fill(white.withValues(alpha: 0.6)))
      ..drawRRect(glass.inflate(3), fill(rgb(0x9a9a98)))
      ..drawRRect(glass, fill(rgb(0x050505)));
  }

  @override
  bool shouldRepaint(_DisplayPainter oldDelegate) => oldDelegate.radius != radius;
}

class _GlarePainter extends CustomPainter {
  const _GlarePainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      shaded(boxLinear(r, 0, 0, 0.6, 1, [(0, white.withValues(alpha: 0.07)), (0.5, white.withValues(alpha: 0))])),
    );
  }

  @override
  bool shouldRepaint(_GlarePainter oldDelegate) => oldDelegate.radius != radius;
}

/// A text field in a [DisplayWindow], with a clear key once something is typed.
class DisplayField extends StatefulWidget {
  const DisplayField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.icon = CupertinoIcons.search,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData icon;

  @override
  State<DisplayField> createState() => _DisplayFieldState();
}

class _DisplayFieldState extends State<DisplayField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(DisplayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) => DisplayWindow(
    radius: 12,
    padding: const EdgeInsets.fromLTRB(16, 3, 6, 3),
    child: SizedBox(
      height: 46,
      child: Row(
        children: [
          Icon(widget.icon, size: 18, color: pixel.withValues(alpha: 0.55)),
          Expanded(
            child: CupertinoTextField(
              controller: widget.controller,
              placeholder: widget.placeholder,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              cursorColor: accent,
              style: textStyle(size: 16, weight: FontWeight.w500, color: pixel),
              placeholderStyle: textStyle(size: 16, weight: FontWeight.w500, color: pixel.withValues(alpha: 0.4)),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              key: const Key('clear-search'),
              behavior: HitTestBehavior.opaque,
              onTap: _clear,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: pixel.withValues(alpha: 0.5),
                    semanticLabel: 'Clear',
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/* ------------------------------------------------------------ progress -- */

/// A spinner in engraving grey, or, given [value], a ring filling with accent.
class MetalProgress extends StatelessWidget {
  const MetalProgress({super.key, this.value, this.size = 24, this.color});

  /// 0–1, or null while it is unknown.
  final double? value;
  final double size;

  /// The spinner's colour; engraving grey by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return CupertinoActivityIndicator(radius: size / 2, color: color ?? engraving);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RingPainter(v.clamp(0.0, 1.0))),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.max(2.0, size.shortestSide * 0.14);
    final r = (Offset.zero & size).deflate(w / 2);
    canvas
      ..drawOval(r, stroke(gap.withValues(alpha: 0.25), w))
      ..drawArc(r, -math.pi / 2, value * 2 * math.pi, false, stroke(accent, w, cap: StrokeCap.round));
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

/* -------------------------------------------------------------- dialog -- */

/// A button along the bottom of a [showMetalDialog].
class MetalDialogAction {
  const MetalDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// The orange cap.
  final bool isPrimary;

  /// Lettered in red.
  final bool isDestructive;
}

/// A plate over the page with a title, a [message] or [content], and keys
/// for its [actions].
Future<T?> showMetalDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<MetalDialogAction> actions = const [],
  double maxWidth = 340,
}) => showCupertinoDialog<T>(
  context: context,
  barrierDismissible: true,
  builder: (context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: MetalPlate(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textStyle(size: 18, weight: FontWeight.w700),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center, style: textStyle(size: 14, alpha: 0.65, height: 1.45)),
                ],
                ?content,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final (i, a) in actions.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: MetalButton(
                            onPressed: a.onPressed,
                            accent: a.isPrimary,
                            height: 44,
                            radius: 12,
                            padding: EdgeInsets.zero,
                            child: Text(
                              a.label,
                              style: a.isDestructive
                                  ? textStyle(size: 15, weight: FontWeight.w700, color: danger)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
