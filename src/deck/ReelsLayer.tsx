import {
  FLANGE_PATH,
  HUB_R,
  LIP_R,
  R,
  REELS,
  SIDES,
  VIEW_H,
  VIEW_W,
  WINDOWS_PATH,
  circlePath,
  packRadius,
  tapePath,
  type Side,
} from './geometry';
import { grainTexture } from './textures';

/**
 * Light comes from the upper left and must stay fixed while the reels turn.
 * Window bevels are faked with copies of the flange shifted in *screen* space
 * and clipped to the windows; the animation loop converts these screen offsets
 * into the reel's rotating frame each frame (see `data-off`).
 */
export const BEVELS = [
  { ox: 2.5, oy: 5, fill: '#000', opacity: 0.3 },
  { ox: 5, oy: 11, fill: '#000', opacity: 0.2 },
  { ox: 9, oy: 20, fill: '#000', opacity: 0.14 },
  { ox: -1.3, oy: -3.4, fill: '#d8d8d8', opacity: 0.55 },
];

export function localOffset(ox: number, oy: number, angle: number): [number, number] {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  return [ox * c + oy * s, -ox * s + oy * c];
}

export function ReelsLayer({ progress }: { progress: number }) {
  const rL = packRadius(1 - progress);
  const rR = packRadius(progress);

  return (
    <svg className="layer layer--passive" viewBox={`0 0 ${VIEW_W} ${VIEW_H}`} aria-hidden="true">
      <defs>
        <pattern id="rl-grain" patternUnits="userSpaceOnUse" width="256" height="256">
          <image href={grainTexture()} width="256" height="256" />
        </pattern>
        <clipPath id="rl-windows">
          <path d={WINDOWS_PATH} />
        </clipPath>

        {SIDES.map((s) => (
          <g key={s}>
            {/* Fine concentric winding lines + broader density bands */}
            <radialGradient id={`rl-rings-${s}`} gradientUnits="userSpaceOnUse" cx={REELS[s].cx} cy={REELS[s].cy} r="5.5" spreadMethod="repeat">
              <stop offset="0" stopColor="#3e2a1c" />
              <stop offset="0.5" stopColor="#33231a" />
              <stop offset="0.75" stopColor="#412d1f" />
              <stop offset="1" stopColor="#3e2a1c" />
            </radialGradient>
            <radialGradient id={`rl-bands-${s}`} gradientUnits="userSpaceOnUse" cx={REELS[s].cx} cy={REELS[s].cy} r="47" spreadMethod="repeat">
              <stop offset="0" stopColor="#000" stopOpacity="0" />
              <stop offset="0.3" stopColor="#000" stopOpacity="0.16" />
              <stop offset="0.42" stopColor="#000" stopOpacity="0.02" />
              <stop offset="0.7" stopColor="#ffd2a8" stopOpacity="0.04" />
              <stop offset="1" stopColor="#000" stopOpacity="0" />
            </radialGradient>
            {/* Flange tint, counter-rotated each frame so the light stays put */}
            <linearGradient
              id={`rl-flange-${s}`}
              data-crot={s}
              gradientUnits="userSpaceOnUse"
              x1={-R}
              y1={-R * 0.4}
              x2={R * 0.5}
              y2={R}
              gradientTransform={`rotate(${-REELS[s].base})`}
            >
              <stop offset="0" stopColor="#3a3a3d" stopOpacity="0.62" />
              <stop offset="0.5" stopColor="#29292b" stopOpacity="0.66" />
              <stop offset="1" stopColor="#1f1f21" stopOpacity="0.74" />
            </linearGradient>
          </g>
        ))}

        <linearGradient id="rl-pack-sheen" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0.5" stopColor="#ffc896" stopOpacity="0" />
          <stop offset="0.68" stopColor="#ffc896" stopOpacity="0.11" />
          <stop offset="0.86" stopColor="#ffc896" stopOpacity="0" />
        </linearGradient>
        <radialGradient id="rl-pack-edge" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0.82" stopColor="#000" stopOpacity="0" />
          <stop offset="0.97" stopColor="#000" stopOpacity="0.32" />
          <stop offset="1" stopColor="#000" stopOpacity="0.6" />
        </radialGradient>
        <linearGradient id="rl-lip" x1="0.15" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#3b3b3e" />
          <stop offset="0.5" stopColor="#2c2c2e" />
          <stop offset="1" stopColor="#232325" />
        </linearGradient>
        <linearGradient id="rl-lip-edge" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.22" />
          <stop offset="0.6" stopColor="#fff" stopOpacity="0.07" />
          <stop offset="1" stopColor="#fff" stopOpacity="0.1" />
        </linearGradient>
        <radialGradient id="rl-spindle" cx="0.38" cy="0.32" r="0.75">
          <stop offset="0" stopColor="#bdbdbd" />
          <stop offset="0.5" stopColor="#6e6e6e" />
          <stop offset="1" stopColor="#2e2e2e" />
        </radialGradient>
      </defs>

      {SIDES.map((s) => (
        <TapePack key={s} side={s} r={s === 'L' ? rL : rR} />
      ))}

      <path
        data-tape=""
        d={tapePath(rL, rR)}
        fill="none"
        stroke="#5b3d27"
        strokeOpacity="0.9"
        strokeWidth="2.2"
        strokeLinejoin="round"
      />

      {SIDES.map((s) => (
        <Flange key={s} side={s} />
      ))}
      {SIDES.map((s) => (
        <Lip key={s} side={s} />
      ))}
    </svg>
  );
}

/** Wound tape. Rotationally symmetric, so it never rotates; only its radius changes. */
function TapePack({ side, r }: { side: Side; r: number }) {
  const { cx, cy } = REELS[side];
  return (
    <g>
      <circle data-pack={side} cx={cx} cy={cy} r={r} fill={`url(#rl-rings-${side})`} />
      <circle data-pack={side} cx={cx} cy={cy} r={r} fill={`url(#rl-bands-${side})`} />
      <circle data-pack={side} cx={cx} cy={cy} r={r} fill="url(#rl-pack-sheen)" />
      <circle data-pack={side} cx={cx} cy={cy} r={r} fill="url(#rl-pack-edge)" />
      <circle data-pack={side} cx={cx} cy={cy} r={r} fill="none" stroke="#000" strokeOpacity="0.55" strokeWidth="2" />
    </g>
  );
}

/** Smoked translucent flange with spoke windows. This is the part that visibly spins. */
function Flange({ side }: { side: Side }) {
  const { cx, cy, base } = REELS[side];
  const a = (base * Math.PI) / 180;
  return (
    <g data-rot={side} transform={`translate(${cx} ${cy}) rotate(${base})`}>
      <path d={FLANGE_PATH} fillRule="evenodd" fill={`url(#rl-flange-${side})`} />
      <path d={FLANGE_PATH} fillRule="evenodd" fill="url(#rl-grain)" opacity="0.045" />

      {/* Bevel: shadow under the upper window walls, light on the lower walls */}
      <g clipPath="url(#rl-windows)">
        {BEVELS.map((b, i) => {
          const [lx, ly] = localOffset(b.ox, b.oy, a);
          return (
            <path
              key={i}
              data-off={side}
              data-ox={b.ox}
              data-oy={b.oy}
              d={FLANGE_PATH}
              fillRule="evenodd"
              fill={b.fill}
              opacity={b.opacity}
              transform={`translate(${lx.toFixed(2)} ${ly.toFixed(2)})`}
            />
          );
        })}
      </g>
      <path d={WINDOWS_PATH} fill="none" stroke="#000" strokeOpacity="0.5" strokeWidth="1.4" />

      {/* Hub — mostly hidden under the smoked lid */}
      <circle r={HUB_R * 0.85} fill="#232325" stroke="#fff" strokeOpacity="0.07" strokeWidth="3" />
      <circle r={HUB_R * 0.6} fill="none" stroke="#000" strokeOpacity="0.4" strokeWidth="2" />
      <circle r={HUB_R * 0.32} fill="url(#rl-spindle)" />
      {[0, 120, 240].map((deg) => (
        <rect key={deg} x={HUB_R * 0.28} y="-8" width="22" height="16" rx="3" fill="#161617" transform={`rotate(${deg})`} />
      ))}
    </g>
  );
}

/** Raised outer rim. Circular, so it is lit statically on top of the spinning flange. */
function Lip({ side }: { side: Side }) {
  const { cx, cy } = REELS[side];
  return (
    <g transform={`translate(${cx} ${cy})`}>
      <path d={`${circlePath(R)} ${circlePath(LIP_R)}`} fillRule="evenodd" fill="url(#rl-lip)" />
      <path d={`${circlePath(R)} ${circlePath(LIP_R)}`} fillRule="evenodd" fill="url(#rl-grain)" opacity="0.04" />
      <circle r={R - 1.5} fill="none" stroke="url(#rl-lip-edge)" strokeWidth="2.5" />
      <circle r={LIP_R} fill="none" stroke="#000" strokeOpacity="0.55" strokeWidth="2.5" />
      <circle r={LIP_R + 2.5} fill="none" stroke="#fff" strokeOpacity="0.05" strokeWidth="1.5" />
    </g>
  );
}
