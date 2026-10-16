import 'dart:math' as math;
import 'dart:ui';

// All deck coordinates live in a single 2000 × 1260 view box. The upper 815
// units reproduce the reference photo's framing; the rest is the control strip.
const double viewW = 2000;
const double viewH = 1260;

enum Side { l, r }

/// Outer radius of a reel flange.
const double reelR = 556;

class Reel {
  const Reel(this.cx, this.cy, this.base);
  final double cx;
  final double cy;

  /// Starting rotation in degrees.
  final double base;

  Offset get centre => Offset(cx, cy);
}

// Reel centres sit just under the smoked lid, as in the reference.
const Map<Side, Reel> reels = {Side.l: Reel(372, -26, 0), Side.r: Reel(1618, -26, 14)};

const double hubR = 0.25 * reelR;
const double packMinR = 0.27 * reelR; // bare tape core
const double packMaxR = 0.925 * reelR; // fully wound
const double flangeR = 0.955 * reelR;
const double lipR = 0.94 * reelR;

// Spoke windows: three rounded sectors between spokes.
const double _winIn = 0.27 * reelR;
const double _winOut = 0.68 * reelR;
const double _winHalf = 0.115 * reelR;
const double _winFillet = 0.075 * reelR;
final List<double> _spokes = [90, 210, 330].map((d) => d * math.pi / 180).toList();

// Tape path anchor points (guide pin, left guide roller, right guide roller).
const Offset _tapeA = Offset(531, 632);
const Offset _tapeB = Offset(596, 654);
const Offset _tapeC = Offset(1446, 654);

/// Tape linear speed in view-box units per second of playback.
const double tapeSpeed = 600;

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));
Offset _perp(double a) => Offset(-math.sin(a), math.cos(a));

double clamp01(double n) => n.clamp(0.0, 1.0).toDouble();

double deg(double radians) => radians * 180 / math.pi;
double rad(double degrees) => degrees * math.pi / 180;

/// Fillet between a spoke edge (a line parallel to the spoke at offset
/// `side * w`) and a circle of radius [r]. Returns the tangent points on both.
({Offset onLine, Offset onCircle}) _fillet(double a, int side, double r, bool outer) {
  const w = _winHalf;
  const rc = _winFillet;
  final centreDist = outer ? r - rc : r + rc;
  const off = w + rc;
  final t = math.sqrt(centreDist * centreDist - off * off);
  final c = _dir(a) * t + _perp(a) * (side * off);
  return (onLine: _dir(a) * t + _perp(a) * (side * w), onCircle: c * (r / centreDist));
}

/// One window between spokes at angles a1 → a2 (radians, clockwise on screen).
void _addWindow(Path p, double a1, double a2) {
  const fr = Radius.circular(_winFillet);
  final o1 = _fillet(a1, 1, _winOut, true);
  final i1 = _fillet(a1, 1, _winIn, false);
  final o2 = _fillet(a2, -1, _winOut, true);
  final i2 = _fillet(a2, -1, _winIn, false);
  p
    ..moveTo(i1.onLine.dx, i1.onLine.dy)
    ..lineTo(o1.onLine.dx, o1.onLine.dy)
    ..arcToPoint(o1.onCircle, radius: fr)
    ..arcToPoint(o2.onCircle, radius: const Radius.circular(_winOut))
    ..arcToPoint(o2.onLine, radius: fr)
    ..lineTo(i2.onLine.dx, i2.onLine.dy)
    ..arcToPoint(i2.onCircle, radius: fr)
    ..arcToPoint(i1.onCircle, radius: const Radius.circular(_winIn), clockwise: false)
    ..arcToPoint(i1.onLine, radius: fr)
    ..close();
}

Path circlePath(double r, [Offset c = Offset.zero]) => Path()..addOval(Rect.fromCircle(center: c, radius: r));

/// The three spoke windows, in reel-local coordinates.
final Path windowsPath = () {
  final p = Path();
  for (var i = 0; i < 3; i++) {
    _addWindow(p, _spokes[i], _spokes[(i + 1) % 3] + (i == 2 ? 2 * math.pi : 0));
  }
  return p;
}();

/// Flange disc with the three windows punched out.
final Path flangePath = Path()
  ..fillType = PathFillType.evenOdd
  ..addPath(circlePath(flangeR), Offset.zero)
  ..addPath(windowsPath, Offset.zero);

/// Radius of a tape pack holding [fill] (0–1) of the tape. Area is linear in tape length.
double packRadius(double fill) {
  final f = clamp01(fill);
  return math.sqrt(packMinR * packMinR + f * (packMaxR * packMaxR - packMinR * packMinR));
}

/// Tangent point on the reel's pack circle of radius [r] as seen from [p].
/// [which] picks which of the two.
Offset _tangent(Offset p, Side side, double r, int which) {
  final reel = reels[side]!;
  final dx = p.dx - reel.cx;
  final dy = p.dy - reel.cy;
  final d = math.sqrt(dx * dx + dy * dy);
  final a = math.atan2(dy, dx) + which * math.acos(math.min(1, r / d));
  return Offset(reel.cx + r * math.cos(a), reel.cy + r * math.sin(a));
}

/// Tape threaded from the supply pack, around the guides, onto the take-up pack.
Path tapePath(double rL, double rR) {
  final tl = _tangent(_tapeA, Side.l, rL, 1);
  final tr = _tangent(_tapeC, Side.r, rR, -1);
  return Path()
    ..moveTo(tl.dx, tl.dy)
    ..lineTo(_tapeA.dx, _tapeA.dy)
    ..lineTo(_tapeB.dx, _tapeB.dy)
    ..lineTo(_tapeC.dx, _tapeC.dy)
    ..lineTo(tr.dx, tr.dy);
}

String formatTime(double seconds) {
  final s = seconds.isFinite ? math.max(0, seconds.floor()) : 0;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}
