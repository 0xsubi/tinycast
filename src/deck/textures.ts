// Small bitmap textures generated once at runtime and used as SVG pattern
// fills. Patterns are far cheaper than feTurbulence on elements that animate.

const cache = new Map<string, string>();

function render(key: string, w: number, h: number, paint: (img: ImageData) => void): string {
  const hit = cache.get(key);
  if (hit) return hit;
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  if (!ctx) return '';
  const img = ctx.createImageData(w, h);
  paint(img);
  ctx.putImageData(img, 0, 0);
  const url = canvas.toDataURL('image/png');
  cache.set(key, url);
  return url;
}

/** Isotropic monochrome grain, mid-grey centred. */
export function grainTexture(): string {
  return render('grain', 256, 256, (img) => {
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      const v = 128 + (Math.random() - 0.5) * 255;
      d[i] = d[i + 1] = d[i + 2] = v;
      d[i + 3] = 255;
    }
  });
}

/** Horizontal brushed-aluminium streaks. */
export function brushedTexture(): string {
  const w = 512;
  const h = 128;
  return render('brushed', w, h, (img) => {
    const d = img.data;
    const row = new Float32Array(w);
    for (let y = 0; y < h; y++) {
      const base = 150 + (Math.random() - 0.5) * 70;
      for (let x = 0; x < w; x++) row[x] = base + (Math.random() - 0.5) * 90;
      // Smear along x so streaks read as brushed metal. Wrapping around the
      // row keeps the tile seamless.
      for (let pass = 0; pass < 3; pass++) {
        for (let x = 0; x < w * 2; x++) {
          const i = x % w;
          row[i] = row[i] * 0.18 + row[(i + w - 1) % w] * 0.82;
        }
      }
      for (let x = 0; x < w; x++) {
        const i = (y * w + x) * 4;
        d[i] = d[i + 1] = d[i + 2] = row[x];
        d[i + 3] = 255;
      }
    }
  });
}
