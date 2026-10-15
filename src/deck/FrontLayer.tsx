import { VIEW_H, VIEW_W } from './geometry';

const PLATE = { x: 648, y: 517, w: 745, h: 140 };
const HOLES_TOP = [672, 778, 940, 1101, 1263, 1372];
const HOLES_BOTTOM = [735, 813, 860, 1013, 1058, 1160, 1252, 1317];

/** Static front layer: head assembly, guide rollers, smoked lid, panel screws. */
export function FrontLayer() {
  return (
    <svg className="layer layer--passive" viewBox={`0 0 ${VIEW_W} ${VIEW_H}`} aria-hidden="true">
      <defs>
        <filter id="fl-drop" x="-10%" y="-20%" width="120%" height="160%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="6" />
          <feOffset dx="3" dy="8" result="blur" />
          <feComponentTransfer>
            <feFuncA type="linear" slope="0.65" />
          </feComponentTransfer>
          <feMerge>
            <feMergeNode />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <filter id="fl-drop-sm" x="-40%" y="-40%" width="180%" height="190%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="3" />
          <feOffset dx="2" dy="5" result="blur" />
          <feComponentTransfer>
            <feFuncA type="linear" slope="0.75" />
          </feComponentTransfer>
          <feMerge>
            <feMergeNode />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <filter id="fl-soft" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.5" />
        </filter>

        <linearGradient id="fl-plate" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#323232" />
          <stop offset="1" stopColor="#282828" />
        </linearGradient>
        <linearGradient id="fl-lever" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#2f2f2f" />
          <stop offset="1" stopColor="#1e1e1e" />
        </linearGradient>
        <radialGradient id="fl-chrome" cx="0.4" cy="0.34" r="0.72">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset="0.28" stopColor="#ececec" />
          <stop offset="0.62" stopColor="#b9b9b9" />
          <stop offset="0.88" stopColor="#7a7a7a" />
          <stop offset="1" stopColor="#575757" />
        </radialGradient>
        <radialGradient id="fl-chrome-pin" cx="0.35" cy="0.3" r="0.8">
          <stop offset="0" stopColor="#f4f4f4" />
          <stop offset="0.5" stopColor="#a6a6a6" />
          <stop offset="1" stopColor="#4a4a4a" />
        </radialGradient>
        <radialGradient id="fl-spec" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="#fff" stopOpacity="0.95" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>

        <linearGradient id="fl-lid" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#050505" stopOpacity="0.97" />
          <stop offset="0.35" stopColor="#0b0b0b" stopOpacity="0.9" />
          <stop offset="0.85" stopColor="#111" stopOpacity="0.84" />
          <stop offset="1" stopColor="#161616" stopOpacity="0.82" />
        </linearGradient>
        <linearGradient id="fl-lid-glare" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#fff" stopOpacity="0" />
          <stop offset="0.3" stopColor="#fff" stopOpacity="0.035" />
          <stop offset="0.55" stopColor="#fff" stopOpacity="0" />
          <stop offset="0.8" stopColor="#fff" stopOpacity="0.025" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <linearGradient id="fl-lid-shadow" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#000" stopOpacity="0.6" />
          <stop offset="1" stopColor="#000" stopOpacity="0" />
        </linearGradient>
        <linearGradient id="fl-silver" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#dedede" />
          <stop offset="0.5" stopColor="#c4c4c4" />
          <stop offset="1" stopColor="#a2a2a2" />
        </linearGradient>
        <linearGradient id="fl-silver-ends" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#000" stopOpacity="0.18" />
          <stop offset="0.04" stopColor="#000" stopOpacity="0" />
          <stop offset="0.96" stopColor="#000" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity="0.18" />
        </linearGradient>
      </defs>

      <HeadAssembly />
      <Lid />

      <Screw x={40} y={688} angle={18} />
      <Screw x={1964} y={688} angle={62} />
      <Screw x={40} y={1222} angle={-34} />
      <Screw x={1964} y={1222} angle={8} />
    </svg>
  );
}

function Lid() {
  return (
    <g>
      {/* Lid casts a soft shadow over the reels */}
      <rect y="116" width={VIEW_W} height="34" fill="url(#fl-lid-shadow)" />
      {/* Smoked glass: reels and hubs remain faintly visible through it */}
      <rect width={VIEW_W} height="116" fill="url(#fl-lid)" />
      <rect width={VIEW_W} height="116" fill="url(#fl-lid-glare)" />
      <rect width={VIEW_W} height="7" fill="#080808" />
      <rect y="7" width={VIEW_W} height="1.5" fill="#fff" opacity="0.07" />

      {/* Brushed silver lid handle */}
      <rect x="515" y="39" width="977" height="4" fill="#000" opacity="0.5" filter="url(#fl-soft)" />
      <rect x="515" y="10" width="977" height="27" fill="url(#fl-silver)" />
      <rect x="515" y="10" width="977" height="27" fill="url(#fl-silver-ends)" />
      <rect x="515" y="10" width="977" height="1.5" fill="#fff" opacity="0.8" />
      <rect x="515" y="35.5" width="977" height="1.5" fill="#000" opacity="0.35" />

      {/* Lower edge of the lid: a lit chamfer then a hard dark line */}
      <rect y="109" width={VIEW_W} height="2.5" fill="#fff" opacity="0.075" />
      <rect y="113" width={VIEW_W} height="3" fill="#040404" />
    </g>
  );
}

function HeadAssembly() {
  const { x, y, w, h } = PLATE;
  return (
    <g>
      {/* Mounting bracket below the plate */}
      <g filter="url(#fl-drop-sm)">
        <rect x="853" y="640" width="182" height="57" rx="4" fill="#252525" />
      </g>
      <rect x="876" y="660" width="138" height="20" rx="4" fill="#0e0e0e" />
      <rect x="876" y="680" width="138" height="1.5" fill="#fff" opacity="0.07" />

      {/* Head cover plate */}
      <g filter="url(#fl-drop)">
        <rect x={x} y={y} width={w} height={h} rx="7" fill="url(#fl-plate)" />
      </g>
      <rect x={x + 5} y={y + 0.5} width={w - 10} height="1.6" rx="0.8" fill="#fff" opacity="0.1" />
      <rect x={x + 5} y={y + h - 2} width={w - 10} height="1.6" fill="#000" opacity="0.35" />
      {HOLES_TOP.map((hx) => (
        <Hole key={`t${hx}`} x={hx} y={540} />
      ))}
      {HOLES_BOTTOM.map((hx) => (
        <Hole key={`b${hx}`} x={hx} y={632} />
      ))}

      {/* Slanted tension-arm slot with its guide pin */}
      <g transform="translate(528 621) rotate(-48.5)">
        <rect x="-60" y="-14" width="120" height="28" rx="14" fill="#fff" opacity="0.06" transform="translate(0 2)" />
        <rect x="-60" y="-14" width="120" height="28" rx="14" fill="#0a0a0a" />
        <rect x="-56" y="-12" width="112" height="9" rx="4.5" fill="#000" opacity="0.6" />
      </g>
      <g filter="url(#fl-drop-sm)">
        <circle cx="530" cy="622" r="10" fill="url(#fl-chrome-pin)" />
      </g>
      <rect x="526.5" y="607" width="7" height="15" rx="3.5" fill="url(#fl-chrome-pin)" />
      <ellipse cx="528" cy="611" rx="2" ry="4" fill="#fff" opacity="0.8" />

      {/* Chrome guide rollers and flat-head guide screws */}
      <ChromeRoller x={668} y={625} r={31} />
      <ChromeRoller x={1373} y={625} r={31} />
      <SlotScrew x={613} y={650} r={19} angle={-32} />
      <SlotScrew x={1428} y={650} r={19} angle={-28} />

      <Lever />
    </g>
  );
}

function Hole({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <circle cx={x} cy={y + 1.6} r="8.6" fill="#fff" opacity="0.09" />
      <circle cx={x} cy={y} r="8.3" fill="#0b0b0b" />
      <circle cx={x - 1} cy={y - 1.6} r="5.5" fill="#000" opacity="0.7" />
    </g>
  );
}

function ChromeRoller({ x, y, r }: { x: number; y: number; r: number }) {
  return (
    <g>
      <g filter="url(#fl-drop-sm)">
        <circle cx={x} cy={y} r={r} fill="url(#fl-chrome)" />
      </g>
      <circle cx={x} cy={y} r={r - 0.8} fill="none" stroke="#000" strokeOpacity="0.35" strokeWidth="1.6" />
      <circle cx={x} cy={y} r={r * 0.62} fill="none" stroke="#fff" strokeOpacity="0.35" strokeWidth="1.2" />
      <ellipse cx={x - r * 0.28} cy={y - r * 0.34} rx={r * 0.42} ry={r * 0.3} fill="url(#fl-spec)" />
    </g>
  );
}

function SlotScrew({ x, y, r, angle }: { x: number; y: number; r: number; angle: number }) {
  return (
    <g>
      <g filter="url(#fl-drop-sm)">
        <circle cx={x} cy={y} r={r} fill="url(#fl-chrome)" />
      </g>
      <circle cx={x} cy={y} r={r - 0.6} fill="none" stroke="#000" strokeOpacity="0.4" strokeWidth="1.2" />
      <g transform={`translate(${x} ${y}) rotate(${angle})`}>
        <rect x={-r * 0.8} y="0.4" width={r * 1.6} height="4" rx="2" fill="#fff" opacity="0.6" />
        <rect x={-r * 0.8} y="-2.6" width={r * 1.6} height="4.4" rx="2" fill="#4a4a4a" />
      </g>
      <ellipse cx={x - r * 0.35} cy={y - r * 0.42} rx={r * 0.3} ry={r * 0.2} fill="url(#fl-spec)" />
    </g>
  );
}

function Lever() {
  const d = 'M 718 679 L 1052 686 L 1188 664 A 26 26 0 0 1 1203 715 L 1062 728 L 718 725 A 23 23 0 0 1 718 679 Z';
  return (
    <g>
      <g filter="url(#fl-drop)">
        <path d={d} fill="url(#fl-lever)" />
      </g>
      <path d="M 718 680.5 L 1052 687.5 L 1188 665.5" fill="none" stroke="#fff" strokeOpacity="0.1" strokeWidth="1.6" />
      <path d={d} fill="none" stroke="#000" strokeOpacity="0.4" strokeWidth="1.2" />
      {/* Pivot screw */}
      <circle cx="718" cy="703" r="7" fill="#0d0d0d" />
      <circle cx="718" cy="704.5" r="7" fill="none" stroke="#fff" strokeOpacity="0.08" strokeWidth="1" />
      <circle cx="718" cy="703" r="2.4" fill="#2a2a2a" />
      {/* Roller post */}
      <circle cx="1195" cy="690" r="13" fill="#000" opacity="0.25" />
      <circle cx="1194" cy="689" r="5.5" fill="#dcdcdc" />
      <circle cx="1193" cy="687.6" r="2" fill="#fff" />
    </g>
  );
}

function Screw({ x, y, angle }: { x: number; y: number; angle: number }) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle cy="1.6" r="10" fill="#fff" opacity="0.07" />
      <circle r="10" fill="#161616" />
      <circle r="8" fill="#1f1f1f" />
      <g transform={`rotate(${angle})`} stroke="#060606" strokeWidth="2.6" strokeLinecap="round">
        <line x1="-5" y1="0" x2="5" y2="0" />
        <line x1="0" y1="-5" x2="0" y2="5" />
      </g>
    </g>
  );
}
