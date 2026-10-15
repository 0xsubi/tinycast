// All deck coordinates live in a single 2000 × 1260 viewBox. The upper 815
// units reproduce the reference photo's framing; the rest is the control strip.
export const VIEW_W = 2000;
export const VIEW_H = 1260;

export type Side = 'L' | 'R';
export const SIDES: Side[] = ['L', 'R'];

/** Outer radius of a reel flange. */
export const R = 556;

// Reel centres sit just under the smoked lid, as in the reference.
// `base` is the starting rotation in degrees.
export const REELS: Record<Side, { cx: number; cy: number; base: number }> = {
  L: { cx: 372, cy: -26, base: 0 },
  R: { cx: 1618, cy: -26, base: 14 },
};

export const HUB_R = 0.25 * R;
export const PACK_MIN_R = 0.27 * R; // bare tape core
export const PACK_MAX_R = 0.925 * R; // fully wound
export const FLANGE_R = 0.955 * R;
export const LIP_R = 0.94 * R;

// Spoke windows: three rounded sectors between spokes.
export const WIN = { rIn: 0.27 * R, rOut: 0.68 * R, half: 0.115 * R, fillet: 0.075 * R };
const SPOKES = [90, 210, 330].map((d) => (d * Math.PI) / 180);

// Tape path anchor points (guide pin, left guide roller, right guide roller).
const TAPE_A: V = [531, 632];
const TAPE_B: V = [596, 654];
const TAPE_C: V = [1446, 654];

/** Tape linear speed in viewBox units per second of playback. */
export const TAPE_SPEED = 600;

type V = [number, number];
const add = (a: V, b: V): V => [a[0] + b[0], a[1] + b[1]];
const mul = (a: V, k: number): V => [a[0] * k, a[1] * k];
const dir = (a: number): V => [Math.cos(a), Math.sin(a)];
const perp = (a: number): V => [-Math.sin(a), Math.cos(a)];
const pt = (p: V) => `${p[0].toFixed(2)} ${p[1].toFixed(2)}`;

export const clamp01 = (n: number) => Math.min(1, Math.max(0, n));

export function circlePath(r: number): string {
  return `M ${r} 0 A ${r} ${r} 0 1 1 ${-r} 0 A ${r} ${r} 0 1 1 ${r} 0 Z`;
}

/**
 * Fillet between a spoke edge (a line parallel to the spoke at offset `side * w`)
 * and a circle of radius `rad`. Returns the tangent points on both.
 */
function fillet(a: number, side: 1 | -1, rad: number, outer: boolean) {
  const { half: w, fillet: rc } = WIN;
  const centreDist = outer ? rad - rc : rad + rc;
  const off = w + rc;
  const t = Math.sqrt(centreDist * centreDist - off * off);
  const c = add(mul(dir(a), t), mul(perp(a), side * off));
  return {
    onLine: add(mul(dir(a), t), mul(perp(a), side * w)),
    onCircle: mul(c, rad / centreDist),
  };
}

/** One window between spokes at angles a1 → a2 (radians, clockwise on screen). */
function windowPath(a1: number, a2: number): string {
  const { rIn, rOut, fillet: rc } = WIN;
  const o1 = fillet(a1, 1, rOut, true);
  const i1 = fillet(a1, 1, rIn, false);
  const o2 = fillet(a2, -1, rOut, true);
  const i2 = fillet(a2, -1, rIn, false);
  return [
    `M ${pt(i1.onLine)}`,
    `L ${pt(o1.onLine)}`,
    `A ${rc} ${rc} 0 0 1 ${pt(o1.onCircle)}`,
    `A ${rOut} ${rOut} 0 0 1 ${pt(o2.onCircle)}`,
    `A ${rc} ${rc} 0 0 1 ${pt(o2.onLine)}`,
    `L ${pt(i2.onLine)}`,
    `A ${rc} ${rc} 0 0 1 ${pt(i2.onCircle)}`,
    `A ${rIn} ${rIn} 0 0 0 ${pt(i1.onCircle)}`,
    `A ${rc} ${rc} 0 0 1 ${pt(i1.onLine)}`,
    'Z',
  ].join(' ');
}

export const WINDOWS_PATH = SPOKES.map((a, i) => windowPath(a, SPOKES[(i + 1) % 3] + (i === 2 ? 2 * Math.PI : 0))).join(' ');
/** Flange disc with the three windows punched out (use fill-rule evenodd). */
export const FLANGE_PATH = `${circlePath(FLANGE_R)} ${WINDOWS_PATH}`;

/** Radius of a tape pack holding `fill` (0–1) of the tape. Area is linear in tape length. */
export function packRadius(fill: number): number {
  const f = clamp01(fill);
  return Math.sqrt(PACK_MIN_R ** 2 + f * (PACK_MAX_R ** 2 - PACK_MIN_R ** 2));
}

/** Tangent point on circle (c, r) as seen from point p. `side` picks which of the two. */
function tangent(p: V, side: Side, r: number, which: 1 | -1): V {
  const { cx, cy } = REELS[side];
  const dx = p[0] - cx;
  const dy = p[1] - cy;
  const d = Math.hypot(dx, dy);
  const a = Math.atan2(dy, dx) + which * Math.acos(Math.min(1, r / d));
  return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
}

/** Tape threaded from the supply pack, around the guides, onto the take-up pack. */
export function tapePath(rL: number, rR: number): string {
  const tl = tangent(TAPE_A, 'L', rL, 1);
  const tr = tangent(TAPE_C, 'R', rR, -1);
  return `M ${pt(tl)} L ${pt(TAPE_A)} L ${pt(TAPE_B)} L ${pt(TAPE_C)} L ${pt(tr)}`;
}

export function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
}
