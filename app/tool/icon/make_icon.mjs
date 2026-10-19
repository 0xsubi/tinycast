// Draws the tinycast app icon: the top of a transmission tower, in the
// iso-glow style — a monochrome hairline drawing on a dark panel where only
// what is live (the antenna tip, its broadcast rings, a few dishes and grilles)
// glows in the accent colour.
//
//   node make_icon.mjs [--small] [--bleed] > icon.svg
//
// --small  heavier strokes, for icons drawn at 64 px and below
// --bleed  fill the whole square (Android launcher) instead of the macOS tile

const small = process.argv.includes('--small');
const bleed = process.argv.includes('--bleed');

const W = 1024;
const AX = 512; // tower axis on screen

// Isometric projection (iso-figure kernel): a horizontal circle of radius r
// becomes an ellipse with these half-axes.
const C = Math.cos(Math.PI / 6), S = Math.sin(Math.PI / 6);
const RX = Math.SQRT2 * C, RY = Math.SQRT2 * S;

const ink = {
  panelTop: '#171514', panelBottom: '#0b0a0a',
  body: '#1b1a19', deck: '#262422', line: '#a8a29b', detail: '#5f5a55',
  accent: '#F05A24', accentHi: '#FF9466',
};
const k = small ? 2.6 : 1;
const LINE = 3.2 * k, DETAIL = 2 * k, GLOW = 4.2 * k;

const f = (n) => Math.round(n * 100) / 100;
const pts = (list) => list.map(([x, y], i) => `${i ? 'L' : 'M'}${f(x)} ${f(y)}`).join('') + 'Z';
const solid = (fill = ink.body) => `fill="${fill}" stroke="${ink.line}" stroke-width="${LINE}" stroke-linejoin="round"`;

/* ------------------------------------------------------------ primitives -- */

/** Ellipse of a horizontal circle of radius r around the axis, at screen height y. */
const ellipse = (y, r, attrs) => `<ellipse cx="${AX}" cy="${f(y)}" rx="${f(r * RX)}" ry="${f(r * RY)}" ${attrs}/>`;

/** Vertical cylinder around the axis: side wall, then the top. */
function cylinder(yTop, h, r, { side = ink.body, top = ink.deck } = {}) {
  const rx = f(r * RX), ry = f(r * RY);
  const wall = `M${f(AX - rx)} ${f(yTop)} A${rx} ${ry} 0 0 0 ${f(AX + rx)} ${f(yTop)} L${f(AX + rx)} ${f(yTop + h)} A${rx} ${ry} 0 0 1 ${f(AX - rx)} ${f(yTop + h)}Z`;
  return `<path d="${wall}" ${solid(side)}/>` + ellipse(yTop, r, solid(top));
}

/** A point on a cylinder's surface: screen angle t (0 = right, π/2 = nearest), height y. */
const onWall = (r, t, y) => [AX + r * RX * Math.cos(t), y + r * RY * Math.sin(t)];

/** Grille panel wrapped on a cylinder wall: outline and vertical slats. */
function grille(r, t0, t1, yA, yB, slats) {
  const steps = 16;
  const top = [], bottom = [];
  for (let i = 0; i <= steps; i++) {
    const t = t0 + (t1 - t0) * (i / steps);
    top.push(onWall(r, t, yA));
    bottom.unshift(onWall(r, t, yB));
  }
  let s = `<path d="${pts([...top, ...bottom])}" fill="${ink.accent}" fill-opacity="0.16" stroke="${ink.accent}" stroke-width="${GLOW * 0.8}" stroke-linejoin="round"/>`;
  for (let i = 1; i < slats; i++) {
    const t = t0 + (t1 - t0) * (i / slats);
    const [x, y] = onWall(r, t, yA);
    s += `<line x1="${f(x)}" y1="${f(y)}" x2="${f(x)}" y2="${f(y + (yB - yA))}" stroke="${ink.accent}" stroke-width="${GLOW * 0.7}"/>`;
  }
  return `<g filter="url(#glow)">${s}</g>`;
}

/**
 * A round dish antenna standing on a platform, facing straight out from the
 * axis at screen angle t. Drawn as a short stack of discs for its thickness.
 */
function dish({ y, R, t, r, lit = false, spokes = false }) {
  // Screen images of the dish's normal, its horizontal tangent and "up".
  const n = [RX * Math.cos(t), RY * Math.sin(t)];
  const tan = [-RX * Math.sin(t), RY * Math.cos(t)];
  const centre = onWall(R, t, y);
  const facing = Math.sin(t) > 0; // front half: we see its face
  const disc = (off, rad) => {
    const c = [centre[0] + n[0] * off, centre[1] + n[1] * off];
    const ring = [];
    for (let i = 0; i < 64; i++) {
      const a = (i / 64) * Math.PI * 2;
      ring.push([c[0] + rad * (Math.cos(a) * tan[0]), c[1] + rad * (Math.cos(a) * tan[1] - Math.sin(a))]);
    }
    return { c, ring };
  };
  const depth = r * 0.42;
  const layers = [0, depth * 0.5, depth].map((o) => disc(o, r));
  if (!facing) layers.reverse();
  const face = lit ? `fill="${ink.accent}" fill-opacity="0.92" stroke="${ink.accentHi}" stroke-width="${LINE}"` : solid();
  let s = layers.map((l) => `<path d="${pts(l.ring)}" ${face}/>`).join('');
  if (facing) {
    const front = layers[layers.length - 1];
    const inner = disc(depth, r * 0.74).ring;
    const detail = lit ? ink.accentHi : ink.detail;
    s += `<path d="${pts(inner)}" fill="none" stroke="${detail}" stroke-width="${DETAIL * 1.3}"/>`;
    if (spokes) {
      for (const a of [Math.PI / 4, (3 * Math.PI) / 4]) {
        const p = (sign) => [
          front.c[0] + sign * r * 0.74 * Math.cos(a) * tan[0],
          front.c[1] + sign * r * 0.74 * (Math.cos(a) * tan[1] - Math.sin(a)),
        ];
        const [a1, a2] = [p(1), p(-1)];
        s += `<line x1="${f(a1[0])}" y1="${f(a1[1])}" x2="${f(a2[0])}" y2="${f(a2[1])}" stroke="${detail}" stroke-width="${DETAIL * 1.3}"/>`;
      }
      s += `<circle cx="${f(front.c[0])}" cy="${f(front.c[1])}" r="${f(r * 0.1)}" fill="${detail}"/>`;
    }
  }
  return lit ? `<g filter="url(#glow)">${s}</g>` : s;
}

/** Small bolts along the near rim of a platform's top. */
function bolts(y, r) {
  let s = '';
  for (let i = 1; i < 12; i++) {
    const [x, yy] = onWall(r, (Math.PI * i) / 12, y);
    s += `<circle cx="${f(x)}" cy="${f(yy)}" r="${f(2.6 * Math.sqrt(k))}" fill="${ink.detail}"/>`;
  }
  return s;
}

/** Concentric broadcast ring around the tip: back half, or front half. */
function ringHalf(y, r, front, opacity) {
  const rx = f(r * RX), ry = f(r * RY);
  const d = front
    ? `M${f(AX - rx)} ${f(y)} A${rx} ${ry} 0 0 0 ${f(AX + rx)} ${f(y)}`
    : `M${f(AX - rx)} ${f(y)} A${rx} ${ry} 0 0 1 ${f(AX + rx)} ${f(y)}`;
  return `<path d="${d}" fill="none" stroke="${ink.accent}" stroke-opacity="${opacity}" stroke-width="${GLOW}" filter="url(#glow)"/>`;
}

/* ------------------------------------------------------------------ tower -- */

// Levels, top to bottom (screen y of each part's top).
const tipY = 236;
const ringY = tipY;
const capY = 336, capH = 34, capR = 30;
const roofY = capY + capH, roofH = 22, roofR = 96;
const drum1Y = roofY + roofH, drum1H = 128, drum1R = 68;
const plate1Y = drum1Y + drum1H, plateH = 18, plateR = 116;
const under1Y = plate1Y + plateH, underH = 12, underR = 104;
const drum2Y = under1Y + underH, drum2H = 118, drum2R = 54;
const plate2Y = drum2Y + drum2H;
const under2Y = plate2Y + plateH;
const shaftY = under2Y + underH, shaftR = 28;

const deg = (d) => (d * Math.PI) / 180;
// Dishes stand on their platform: lift is the height of the dish centre above it.
const stand = (plateY, r) => plateY - r - 8;
const level1 = [
  { y: stand(plate1Y, 26), R: 100, t: deg(205), r: 26 },
  { y: stand(plate1Y, 26), R: 100, t: deg(-25), r: 26 },
  { y: stand(plate1Y, 26), R: 102, t: deg(164), r: 26 },
  { y: stand(plate1Y, 34), R: 100, t: deg(124), r: 34, lit: true },
  { y: stand(plate1Y, 34), R: 100, t: deg(60), r: 34, spokes: true },
  { y: stand(plate1Y, 26), R: 102, t: deg(16), r: 26 },
];
const level2 = [
  { y: stand(plate2Y, 25), R: 96, t: deg(200), r: 25 },
  { y: stand(plate2Y, 25), R: 96, t: deg(-20), r: 25 },
  { y: stand(plate2Y, 24), R: 100, t: deg(168), r: 24, lit: true },
  { y: stand(plate2Y, 33), R: 96, t: deg(124), r: 33, lit: true, spokes: true },
  { y: stand(plate2Y, 30), R: 96, t: deg(66), r: 30 },
  { y: stand(plate2Y, 25), R: 100, t: deg(20), r: 25 },
];
const back = (l) => l.filter((d) => Math.sin(d.t) <= 0);
const front = (l) => l.filter((d) => Math.sin(d.t) > 0).sort((a, b) => Math.sin(a.t) - Math.sin(b.t));

let tower = '';
// Bottom up, so higher and nearer parts cover what they should.
tower += `<g mask="url(#fade)">${cylinder(shaftY, 400, shaftR)}</g>`;
tower += cylinder(under2Y, underH, underR);
tower += cylinder(plate2Y, plateH, plateR) + bolts(plate2Y, plateR * 0.9);
tower += back(level2).map(dish).join('');
tower += cylinder(drum2Y, drum2H, drum2R);
tower += cylinder(under1Y, underH, underR);
tower += cylinder(plate1Y, plateH, plateR) + bolts(plate1Y, plateR * 0.9);
tower += back(level1).map(dish).join('');
tower += cylinder(drum1Y, drum1H, drum1R);
tower += grille(drum1R, deg(112), deg(160), drum1Y + 14, drum1Y + 58, 7);
tower += grille(drum1R, deg(20), deg(68), drum1Y + 14, drum1Y + 58, 7);
tower += cylinder(roofY, roofH, roofR);
tower += cylinder(capY, capH, capR);
// Broadcast rings: back halves behind the mast, front halves in front.
tower += ringHalf(ringY, 124, false, 0.55) + ringHalf(ringY, 66, false, 1);
// Mast: a rod with a sleeve.
tower += `<rect x="${AX - 8}" y="${tipY + 8}" width="16" height="${capY - tipY - 8}" ${solid()}/>`;
tower += `<rect x="${AX - 13}" y="${capY - 46}" width="26" height="46" ${solid(ink.deck)}/>`;
for (const dy of [12, 22, 32]) {
  tower += `<line x1="${AX - 13}" y1="${capY - 46 + dy}" x2="${AX + 13}" y2="${capY - 46 + dy}" stroke="${ink.detail}" stroke-width="${DETAIL}"/>`;
}
tower += ringHalf(ringY, 124, true, 0.55) + ringHalf(ringY, 66, true, 1);
// The live tip.
tower += `<circle cx="${AX}" cy="${tipY}" r="40" fill="url(#tipHaze)"/>`;
tower += `<g filter="url(#glow)"><circle cx="${AX}" cy="${tipY}" r="${f(13 * Math.sqrt(k))}" fill="${ink.accent}"/>`;
tower += `<circle cx="${AX - 3}" cy="${tipY - 3}" r="${f(5 * Math.sqrt(k))}" fill="${ink.accentHi}"/></g>`;
tower += front(level2).map(dish).join('');
tower += front(level1).map(dish).join('');

/* ------------------------------------------------------------------- tile -- */

// macOS tiles sit in an 824 px rounded square inside the 1024 canvas.
const tile = bleed ? { x: 0, y: 0, w: W, r: 0 } : { x: 100, y: 100, w: 824, r: 185 };
const tileRect = `x="${tile.x}" y="${tile.y}" width="${tile.w}" height="${tile.w}" rx="${tile.r}"`;
// Fit the tower to the tile: centred, its base running off the bottom edge.
const scale = tile.w / 824;
const place = `translate(${f(tile.x + tile.w / 2 - AX * scale)} ${f(tile.y - 84 * scale)}) scale(${f(scale)})`;

process.stdout.write(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${W}" viewBox="0 0 ${W} ${W}">
  <defs>
    <linearGradient id="panel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${ink.panelTop}"/><stop offset="1" stop-color="${ink.panelBottom}"/>
    </linearGradient>
    <radialGradient id="haze" cx="0.5" cy="0.18" r="0.62">
      <stop offset="0" stop-color="${ink.accent}" stop-opacity="0.22"/><stop offset="1" stop-color="${ink.accent}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="tipHaze">
      <stop offset="0" stop-color="${ink.accent}" stop-opacity="0.55"/><stop offset="1" stop-color="${ink.accent}" stop-opacity="0"/>
    </radialGradient>
    <filter id="glow" filterUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${W}">
      <feGaussianBlur in="SourceGraphic" stdDeviation="${8 * k}" result="b1"/>
      <feGaussianBlur in="SourceGraphic" stdDeviation="${2.5 * k}" result="b2"/>
      <feMerge><feMergeNode in="b1"/><feMergeNode in="b1"/><feMergeNode in="b2"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="shadow" filterUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${W}">
      <feGaussianBlur stdDeviation="14"/>
    </filter>
    <clipPath id="tile"><rect ${tileRect}/></clipPath>
    <linearGradient id="fadeRamp" gradientUnits="userSpaceOnUse" x1="0" y1="${shaftY}" x2="0" y2="${shaftY + 230}">
      <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <mask id="fade" maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${W * 2}">
      <rect x="0" y="0" width="${W}" height="${W * 2}" fill="url(#fadeRamp)"/>
    </mask>
  </defs>
  ${bleed ? '' : `<rect ${tileRect} transform="translate(0 12)" fill="#000" fill-opacity="0.45" filter="url(#shadow)"/>`}
  <rect ${tileRect} fill="url(#panel)"/>
  <rect ${tileRect} fill="url(#haze)"/>
  <g clip-path="url(#tile)"><g transform="${place}">${tower}</g></g>
  ${bleed ? '' : `<rect x="${tile.x + 1.5}" y="${tile.y + 1.5}" width="${tile.w - 3}" height="${tile.w - 3}" rx="${tile.r - 1.5}" fill="none" stroke="#ffffff" stroke-opacity="0.09" stroke-width="3"/>`}
</svg>
`);
