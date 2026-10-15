import { R, REELS, SIDES, VIEW_H, VIEW_W } from './geometry';

/** Static rear layer: textured deck panel and the shadows the reels cast on it. */
export function Backplate() {
  return (
    <svg className="layer layer--passive" viewBox={`0 0 ${VIEW_W} ${VIEW_H}`} aria-hidden="true">
      <defs>
        <linearGradient id="bp-base" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#2b2b2b" />
          <stop offset="0.55" stopColor="#252525" />
          <stop offset="1" stopColor="#1e1e1e" />
        </linearGradient>
        <radialGradient id="bp-vignette" cx="0.5" cy="0.42" r="0.75">
          <stop offset="0.55" stopColor="#000" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity="0.45" />
        </radialGradient>
        <filter id="bp-grain" x="0" y="0" width="100%" height="100%">
          <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="3" seed="7" stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
          <feComponentTransfer>
            <feFuncA type="linear" slope="0" intercept="1" />
          </feComponentTransfer>
        </filter>
        <filter id="bp-mottle" x="0" y="0" width="100%" height="100%">
          <feTurbulence type="fractalNoise" baseFrequency="0.006" numOctaves="2" seed="2" />
          <feColorMatrix type="saturate" values="0" />
          <feComponentTransfer>
            <feFuncA type="linear" slope="0" intercept="1" />
          </feComponentTransfer>
        </filter>
        <filter id="bp-shadow-wide" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="22" />
        </filter>
        {/* Shadows fall outside the reels only; the panel seen through the windows stays lit. */}
        <mask id="bp-outside-reels" maskUnits="userSpaceOnUse" x="0" y="0" width={VIEW_W} height={VIEW_H}>
          <rect width={VIEW_W} height={VIEW_H} fill="#fff" />
          {SIDES.map((s) => (
            <circle key={s} cx={REELS[s].cx} cy={REELS[s].cy} r={R - 6} fill="#000" />
          ))}
        </mask>
        <filter id="bp-shadow-tight" x="-10%" y="-10%" width="120%" height="120%">
          <feGaussianBlur stdDeviation="5" />
        </filter>
      </defs>

      <rect width={VIEW_W} height={VIEW_H} fill="url(#bp-base)" />
      {/* Leatherette grain + large-scale mottling */}
      <rect width={VIEW_W} height={VIEW_H} filter="url(#bp-grain)" opacity="0.085" style={{ mixBlendMode: 'overlay' }} />
      <rect width={VIEW_W} height={VIEW_H} filter="url(#bp-grain)" opacity="0.035" />
      <rect width={VIEW_W} height={VIEW_H} filter="url(#bp-mottle)" opacity="0.05" style={{ mixBlendMode: 'overlay' }} />

      {/* Reel shadows on the panel */}
      {SIDES.map((s) => (
        <g key={s} mask="url(#bp-outside-reels)">
          <circle cx={REELS[s].cx + 10} cy={REELS[s].cy + 26} r={R} fill="#000" opacity="0.55" filter="url(#bp-shadow-wide)" />
          <circle cx={REELS[s].cx + 2} cy={REELS[s].cy + 6} r={R} fill="#000" opacity="0.45" filter="url(#bp-shadow-tight)" />
        </g>
      ))}

      {/* Seam between the transport deck and the control strip */}
      <rect y="752" width={VIEW_W} height="2.5" fill="#0d0d0d" />
      <rect y="754.5" width={VIEW_W} height="1.5" fill="#fff" opacity="0.05" />

      <rect width={VIEW_W} height={VIEW_H} fill="url(#bp-vignette)" />
    </svg>
  );
}
