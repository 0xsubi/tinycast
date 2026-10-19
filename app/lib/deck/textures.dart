import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

// Small bitmap textures generated once at startup and tiled as image shaders.
// They stand in for the SVG version's pattern fills and feTurbulence noise.

class Textures {
  Textures._();

  /// Isotropic monochrome grain, mid-grey centred.
  static late final ui.Image grain;

  /// Horizontal brushed-aluminium streaks.
  static late final ui.Image brushed;

  /// Softer fine noise for the leatherette panel.
  static late final ui.Image panelGrain;

  /// Large-scale mottling; stretched over the whole panel.
  static late final ui.Image mottle;

  /// Soft, fine, roughly Gaussian speckle: bead-blasted aluminium.
  static late final ui.Image bead;

  static Future<void> load() async {
    final rnd = math.Random();
    final results = await Future.wait([
      _render(256, 256, (x, y) => 128 + (rnd.nextDouble() - 0.5) * 255),
      _brushed(rnd),
      // feTurbulence noise is generated in linear RGB, so it lands lighter
      // than mid-grey once converted to sRGB.
      _render(256, 256, (x, y) => 188 + (rnd.nextDouble() - 0.5) * 120),
      _mottle(rnd),
      // Sum of uniforms ≈ Gaussian, so the speckle has no hard extremes.
      _render(256, 256, (x, y) => 128 + (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) * 70),
    ]);
    grain = results[0];
    brushed = results[1];
    panelGrain = results[2];
    mottle = results[3];
    bead = results[4];
  }

  static Future<ui.Image> _render(int w, int h, double Function(int x, int y) value) {
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final v = value(x, y).round().clamp(0, 255);
        px[i] = px[i + 1] = px[i + 2] = v;
        px[i + 3] = 255;
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  static Future<ui.Image> _brushed(math.Random rnd) {
    const w = 512;
    const h = 128;
    final rows = List.generate(h, (_) {
      final row = Float32List(w);
      final base = 150 + (rnd.nextDouble() - 0.5) * 70;
      for (var x = 0; x < w; x++) {
        row[x] = base + (rnd.nextDouble() - 0.5) * 90;
      }
      // Smear along x so streaks read as brushed metal. Wrapping around the
      // row keeps the tile seamless.
      for (var pass = 0; pass < 3; pass++) {
        for (var x = 0; x < w * 2; x++) {
          final i = x % w;
          row[i] = row[i] * 0.18 + row[(i + w - 1) % w] * 0.82;
        }
      }
      return row;
    });
    return _render(w, h, (x, y) => rows[y][x]);
  }

  /// Two octaves of smooth value noise, about 167 view-box units per cell.
  static Future<ui.Image> _mottle(math.Random rnd) {
    const w = 250; // 8 view-box units per texel
    const h = 158;
    final lattices = [21.0, 10.5].map((cell) {
      final cols = (w / cell).ceil() + 2;
      final rows = (h / cell).ceil() + 2;
      return (cell: cell, cols: cols, v: List.generate(cols * rows, (_) => rnd.nextDouble() * 2 - 1));
    }).toList();

    double sample(({double cell, int cols, List<double> v}) l, int x, int y) {
      final fx = x / l.cell;
      final fy = y / l.cell;
      final ix = fx.floor();
      final iy = fy.floor();
      double s(double t) => t * t * (3 - 2 * t);
      final tx = s(fx - ix);
      final ty = s(fy - iy);
      double at(int cx, int cy) => l.v[cy * l.cols + cx];
      final top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx;
      final bottom = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx;
      return top + (bottom - top) * ty;
    }

    return _render(w, h, (x, y) {
      final n = sample(lattices[0], x, y) + 0.5 * sample(lattices[1], x, y);
      return 188 + n / 1.5 * 70;
    });
  }
}
