import { useRef, useState, type PointerEvent as ReactPointerEvent, type RefObject } from 'react';
import { VIEW_H, VIEW_W, clamp01, formatTime } from './geometry';
import { brushedTexture, grainTexture } from './textures';
import type { Transport } from './transport';

export interface Episode {
  show: string;
  number: string;
  title: string;
}

interface Props {
  transport: Transport;
  episode: Episode;
  onPickFile: () => void;
}

// Layout constants (viewBox units)
const KNOB = { x: 330, y: 905, r: 92 };
const KEY = { w: 150, h: 92, gap: 22, y: 962 };
const COUNTER = { x: 1670, y: 842, dw: 46, dh: 66, colon: 16, gap: 4 };
export const SLIDER = { x0: 420, x1: 1580, y: 1170 };

function toSvg(svg: SVGSVGElement | null, e: { clientX: number; clientY: number }) {
  const m = svg?.getScreenCTM();
  if (!svg || !m) return { x: 0, y: 0 };
  return new DOMPoint(e.clientX, e.clientY).matrixTransform(m.inverse());
}

export function ControlsLayer({ transport, episode, onPickFile }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  return (
    <svg ref={svgRef} className="layer" viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}>
      <defs>
        <pattern id="cl-grain" patternUnits="userSpaceOnUse" width="256" height="256">
          <image href={grainTexture()} width="256" height="256" />
        </pattern>
        <pattern id="cl-brushed" patternUnits="userSpaceOnUse" width="512" height="128">
          <image href={brushedTexture()} width="512" height="128" />
        </pattern>
        <filter id="cl-blur4" x="-20%" y="-40%" width="140%" height="180%">
          <feGaussianBlur stdDeviation="4" />
        </filter>
        <filter id="cl-blur8" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="8" />
        </filter>

        <linearGradient id="cl-paper" x1="0" y1="0" x2="0.2" y2="1">
          <stop offset="0" stopColor="#efe8d4" />
          <stop offset="1" stopColor="#ddd2b6" />
        </linearGradient>
        <linearGradient id="cl-key-top" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ececec" />
          <stop offset="0.55" stopColor="#cfcfcf" />
          <stop offset="1" stopColor="#ababab" />
        </linearGradient>
        <linearGradient id="cl-key-front" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7c7c7c" />
          <stop offset="1" stopColor="#2c2c2c" />
        </linearGradient>
        <linearGradient id="cl-fader" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#e9e9e9" />
          <stop offset="0.5" stopColor="#bdbdbd" />
          <stop offset="1" stopColor="#8a8a8a" />
        </linearGradient>
        <linearGradient id="cl-skirt-light" x1="0.2" y1="0" x2="0.5" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.16" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity="0.35" />
        </linearGradient>
        <radialGradient id="cl-cap-rings" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="2.2" spreadMethod="repeat">
          <stop offset="0" stopColor="#fff" stopOpacity="0.5" />
          <stop offset="0.5" stopColor="#000" stopOpacity="0.4" />
          <stop offset="1" stopColor="#fff" stopOpacity="0.5" />
        </radialGradient>
        <linearGradient id="cl-drum" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#000" stopOpacity="0.85" />
          <stop offset="0.22" stopColor="#000" stopOpacity="0.15" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0.06" />
          <stop offset="0.78" stopColor="#000" stopOpacity="0.15" />
          <stop offset="1" stopColor="#000" stopOpacity="0.85" />
        </linearGradient>
        <radialGradient id="cl-bezel" cx="0.4" cy="0.3" r="0.8">
          <stop offset="0" stopColor="#f2f2f2" />
          <stop offset="0.55" stopColor="#9c9c9c" />
          <stop offset="1" stopColor="#3e3e3e" />
        </radialGradient>
        {(
          [
            ['green', '#7dff6a', '#1f3a1c'],
            ['amber', '#ffb347', '#3b2a14'],
          ] as const
        ).map(([name, on, off]) => (
          <g key={name}>
            <radialGradient id={`cl-glow-${name}`} cx="0.5" cy="0.5" r="0.5">
              <stop offset="0" stopColor={on} stopOpacity="0.5" />
              <stop offset="0.35" stopColor={on} stopOpacity="0.16" />
              <stop offset="1" stopColor={on} stopOpacity="0" />
            </radialGradient>
            <radialGradient id={`cl-lens-${name}-on`} cx="0.45" cy="0.4" r="0.65">
              <stop offset="0" stopColor="#ffffff" />
              <stop offset="0.3" stopColor={on} />
              <stop offset="1" stopColor={on} stopOpacity="0.55" />
            </radialGradient>
            <radialGradient id={`cl-lens-${name}-off`} cx="0.45" cy="0.4" r="0.7">
              <stop offset="0" stopColor={off} />
              <stop offset="1" stopColor="#070707" />
            </radialGradient>
          </g>
        ))}
      </defs>

      <EpisodeLabel episode={episode} duration={transport.duration} onClick={onPickFile} />
      <VolumeKnob svgRef={svgRef} transport={transport} />
      <TransportKeys transport={transport} />
      <TapeCounter />
      <Lamp x={1590} y={1005} color="green" label="PLAY" on={transport.playing} />
      <Lamp x={1750} y={1005} color="amber" label="WIND" dataKey="wind" />
      <PositionSlider svgRef={svgRef} transport={transport} />
    </svg>
  );
}

const PRINT = {
  fill: '#9a9a9a',
  fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif',
  fontWeight: 600,
  fontSize: 17,
  letterSpacing: 5,
} as const;

/* ---------------------------------------------------------------- label -- */

function EpisodeLabel({ episode, duration, onClick }: { episode: Episode; duration: number; onClick: () => void }) {
  const x = 650;
  const y = 784;
  const w = 700;
  const h = 124;
  const title = episode.title.length > 34 ? `${episode.title.slice(0, 33)}…` : episode.title;
  const type = { fontFamily: '"Special Elite", "Courier New", monospace' };
  return (
    <g
      className="label"
      transform={`rotate(-0.35 ${x + w / 2} ${y + h / 2})`}
      onClick={onClick}
      role="button"
      aria-label="Load an episode from an audio file"
    >
      <title>Click (or drop an audio file on the deck) to load an episode</title>
      <rect x={x + 4} y={y + 7} width={w} height={h} fill="#000" opacity="0.55" filter="url(#cl-blur4)" />
      <rect x={x} y={y} width={w} height={h} rx="2" fill="url(#cl-paper)" />
      <rect x={x} y={y} width={w} height={h} rx="2" fill="url(#cl-grain)" opacity="0.06" />
      <rect x={x} y={y} width={w} height="1.5" fill="#fff" opacity="0.6" />
      <line x1={x} x2={x + w} y1={y + 40} y2={y + 40} stroke="#c55a4c" strokeWidth="1.6" opacity="0.8" />
      <line x1={x} x2={x + w} y1={y + 84} y2={y + 84} stroke="#8fa9c0" strokeWidth="1.2" opacity="0.55" />
      <line x1={x} x2={x + w} y1={y + 112} y2={y + 112} stroke="#8fa9c0" strokeWidth="1.2" opacity="0.55" />

      <text x={x + 24} y={y + 29} fontSize="21" letterSpacing="3" fill="#4d4232" {...type}>
        {episode.show.toUpperCase()}
      </text>
      <text x={x + w - 24} y={y + 29} fontSize="21" letterSpacing="2" fill="#4d4232" textAnchor="end" {...type}>
        EP. {episode.number}
      </text>
      <text x={x + 24} y={y + 77} fontSize="36" fill="#251f17" {...type}>
        {title}
      </text>
      <text x={x + 24} y={y + 106} fontSize="17" letterSpacing="1.5" fill="#6d604d" {...type}>
        STEREO · 7½ IPS · {formatTime(duration)}
      </text>
      <text x={x + w - 24} y={y + 106} fontSize="16" fill="#8d7f69" textAnchor="end" className="label__hint" {...type}>
        ⏏ load episode
      </text>
    </g>
  );
}

/* ----------------------------------------------------------------- knob -- */

const CAP_R = 74;
// Spun-metal cap: a "conic gradient" built from thin wedges.
const CAP_WEDGES = Array.from({ length: 96 }, (_, i) => {
  const a0 = (i / 96) * Math.PI * 2;
  const a1 = ((i + 1) / 96) * Math.PI * 2 + 0.004;
  const mid = (a0 + a1) / 2;
  const v = 0.66 + 0.2 * Math.cos(2 * (mid + 0.7)) + 0.07 * Math.cos(6 * mid + 1.3);
  const g = Math.round(255 * clamp01(v));
  const p = (a: number) => `${(CAP_R * Math.cos(a)).toFixed(2)} ${(CAP_R * Math.sin(a)).toFixed(2)}`;
  return { d: `M 0 0 L ${p(a0)} A ${CAP_R} ${CAP_R} 0 0 1 ${p(a1)} Z`, fill: `rgb(${g},${g},${g})` };
});
const KNURLS = Array.from({ length: 64 }, (_, i) => (i / 64) * 360);
const TICKS = Array.from({ length: 11 }, (_, i) => -135 + i * 27);

function VolumeKnob({ svgRef, transport }: { svgRef: RefObject<SVGSVGElement | null>; transport: Transport }) {
  const angle = -135 + transport.volume * 270;
  const dragging = useRef(false);

  const setFromPointer = (e: ReactPointerEvent) => {
    const p = toSvg(svgRef.current, e);
    let a = (Math.atan2(p.x - KNOB.x, -(p.y - KNOB.y)) * 180) / Math.PI;
    // Snap into the valid arc instead of jumping across the dead zone.
    if (a > 135) a = 135;
    if (a < -135) a = -135;
    transport.setVolume((a + 135) / 270);
  };

  return (
    <g transform={`translate(${KNOB.x} ${KNOB.y})`}>
      {TICKS.map((t, i) => (
        <line
          key={t}
          x1="0"
          x2="0"
          y1={-112}
          y2={i % 5 === 0 ? -130 : -122}
          stroke="#8a8a8a"
          strokeWidth={i % 5 === 0 ? 3 : 2}
          transform={`rotate(${t})`}
        />
      ))}
      <text x={-118} y={124} textAnchor="middle" {...PRINT} fontSize={14} letterSpacing={3}>
        MIN
      </text>
      <text x={118} y={124} textAnchor="middle" {...PRINT} fontSize={14} letterSpacing={3}>
        MAX
      </text>
      <text y={150} textAnchor="middle" {...PRINT}>
        VOLUME
      </text>

      <g
        className="knob"
        role="slider"
        aria-label="Volume"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(transport.volume * 100)}
        onPointerDown={(e) => {
          dragging.current = true;
          (e.currentTarget as Element).setPointerCapture(e.pointerId);
          setFromPointer(e);
        }}
        onPointerMove={(e) => dragging.current && setFromPointer(e)}
        onPointerUp={() => (dragging.current = false)}
        onWheel={(e) => transport.setVolume(transport.volume - e.deltaY / 1500)}
      >
        <circle cy="12" r={KNOB.r + 4} fill="#000" opacity="0.6" filter="url(#cl-blur8)" />
        {/* Knurled skirt turns with the knob */}
        <g transform={`rotate(${angle})`}>
          <circle r={KNOB.r} fill="#1d1d1d" />
          {KNURLS.map((k) => (
            <line key={k} x1="0" x2="0" y1={-KNOB.r + 0.5} y2={-CAP_R - 6} stroke="#3d3d3d" strokeWidth="2.6" transform={`rotate(${k})`} />
          ))}
        </g>
        <circle r={KNOB.r} fill="url(#cl-skirt-light)" />
        <circle r={KNOB.r - 0.8} fill="none" stroke="#000" strokeOpacity="0.6" strokeWidth="1.6" />
        <circle r={CAP_R + 3} fill="#0d0d0d" />

        {/* Machined cap: lit statically, only the indicator turns */}
        {CAP_WEDGES.map((w, i) => (
          <path key={i} d={w.d} fill={w.fill} />
        ))}
        <circle r={CAP_R} fill="url(#cl-cap-rings)" opacity="0.14" />
        <circle r={CAP_R - 1} fill="none" stroke="#fff" strokeOpacity="0.65" strokeWidth="1.5" />
        <circle r={CAP_R} fill="none" stroke="#000" strokeOpacity="0.4" strokeWidth="1" />
        <circle r="5" fill="#000" opacity="0.18" />
        <g transform={`rotate(${angle})`}>
          <rect x="-3.5" y={-CAP_R + 9} width="7" height="24" rx="3.5" fill="#fff" opacity="0.7" transform="translate(0 1.4)" />
          <rect x="-3.5" y={-CAP_R + 9} width="7" height="24" rx="3.5" fill="#2a2a2a" />
        </g>
      </g>
    </g>
  );
}

/* ----------------------------------------------------------------- keys -- */

type Icon = 'rew' | 'play' | 'pause' | 'ff';
const ICONS: Record<Icon, string> = {
  play: 'M -9 -15 L 15 0 L -9 15 Z',
  pause: 'M -13 -14 h 9 v 28 h -9 Z M 4 -14 h 9 v 28 h -9 Z',
  rew: 'M -1 -13 L -20 0 L -1 13 Z M 19 -13 L 0 0 L 19 13 Z',
  ff: 'M 1 -13 L 20 0 L 1 13 Z M -19 -13 L 0 0 L -19 13 Z',
};

function TransportKeys({ transport }: { transport: Transport }) {
  const keys: { id: Icon; label: string; act: () => void; latched?: boolean }[] = [
    { id: 'rew', label: 'REW 15', act: () => transport.skip(-15) },
    { id: 'play', label: 'PLAY', act: () => transport.play(), latched: transport.playing },
    { id: 'pause', label: 'PAUSE', act: () => transport.pause() },
    { id: 'ff', label: 'FF 30', act: () => transport.skip(30) },
  ];
  const total = keys.length * KEY.w + (keys.length - 1) * KEY.gap;
  const x0 = 1000 - total / 2;
  return (
    <g>
      {keys.map((k, i) => (
        <PianoKey key={k.id} x={x0 + i * (KEY.w + KEY.gap)} icon={k.id} label={k.label} latched={!!k.latched} onPress={k.act} />
      ))}
    </g>
  );
}

function PianoKey({ x, icon, label, latched, onPress }: { x: number; icon: Icon; label: string; latched: boolean; onPress: () => void }) {
  const [held, setHeld] = useState(false);
  const down = held || latched;
  const { w, h, y } = KEY;
  const top = h - 6;
  return (
    <g>
      <text x={x + w / 2} y={y + h + 46} textAnchor="middle" {...PRINT} fontSize={14} letterSpacing={3}>
        {label}
      </text>
      <g
        className="key"
        role="button"
        aria-label={label}
        aria-pressed={latched || undefined}
        onPointerDown={(e) => {
          (e.currentTarget as Element).setPointerCapture(e.pointerId);
          setHeld(true);
          onPress();
        }}
        onPointerUp={() => setHeld(false)}
        onPointerCancel={() => setHeld(false)}
      >
        {/* Well */}
        <rect x={x - 8} y={y - 8} width={w + 16} height={h + 26} rx="8" fill="#090909" />
        <rect x={x - 6} y={y + h + 18} width={w + 12} height="1.5" fill="#fff" opacity="0.06" />
        {/* Key front face, revealed when the key is up */}
        <rect x={x + 2} y={y + h - 22} width={w - 4} height="34" rx="6" fill="url(#cl-key-front)" />
        <g style={{ transform: `translateY(${down ? 11 : 0}px)`, transition: 'transform 70ms ease-out' }}>
          <rect x={x} y={y} width={w} height={top} rx="6" fill="url(#cl-key-top)" />
          <rect x={x} y={y} width={w} height={top} rx="6" fill="url(#cl-brushed)" opacity="0.45" style={{ mixBlendMode: 'multiply' }} />
          <rect x={x + 3} y={y + 1} width={w - 6} height="2" rx="1" fill="#fff" opacity="0.85" />
          <rect x={x} y={y} width={w} height={top} rx="6" fill="none" stroke="#000" strokeOpacity="0.35" strokeWidth="1.2" />
          {down && <rect x={x} y={y} width={w} height={top} rx="6" fill="#000" opacity="0.12" />}
          <g transform={`translate(${x + w / 2} ${y + top / 2})`}>
            <path d={ICONS[icon]} fill="#fff" opacity="0.75" transform="translate(0 1.5)" />
            <path d={ICONS[icon]} fill={icon === 'play' && latched ? '#2f6b26' : '#3a3a3a'} />
          </g>
        </g>
      </g>
    </g>
  );
}

/* -------------------------------------------------------------- counter -- */

// Drum order left→right with their radix and index into the odometer (0 = seconds-ones).
const DRUMS: { radix: number; index: number }[] = [
  { radix: 10, index: 4 },
  { radix: 6, index: 3 },
  { radix: 10, index: 2 },
  { radix: 6, index: 1 },
  { radix: 10, index: 0 },
];
export const DRUM_RADIX = [10, 6, 10, 6, 10];
export const DRUM_H = COUNTER.dh;

function TapeCounter() {
  const { dw, dh, colon, gap } = COUNTER;
  const width = DRUMS.length * dw + 2 * colon + 6 * gap;
  const x0 = COUNTER.x - width / 2;
  const y0 = COUNTER.y - dh / 2;
  const slots: ({ kind: 'drum'; drum: (typeof DRUMS)[number] } | { kind: 'colon' })[] = [
    { kind: 'drum', drum: DRUMS[0] },
    { kind: 'colon' },
    { kind: 'drum', drum: DRUMS[1] },
    { kind: 'drum', drum: DRUMS[2] },
    { kind: 'colon' },
    { kind: 'drum', drum: DRUMS[3] },
    { kind: 'drum', drum: DRUMS[4] },
  ];
  let cursor = x0;

  return (
    <g>
      <text x={COUNTER.x} y={y0 - 26} textAnchor="middle" {...PRINT}>
        TAPE COUNTER
      </text>
      {/* Bezel */}
      <rect x={x0 - 16} y={y0 - 14} width={width + 32} height={dh + 28} rx="8" fill="#fff" opacity="0.06" transform="translate(0 2)" />
      <rect x={x0 - 16} y={y0 - 14} width={width + 32} height={dh + 28} rx="8" fill="#0a0a0a" />
      <rect x={x0 - 8} y={y0 - 6} width={width + 16} height={dh + 12} rx="4" fill="#000" />

      {slots.map((s, i) => {
        const x = cursor;
        cursor += (s.kind === 'drum' ? dw : colon) + gap;
        if (s.kind === 'colon') {
          return (
            <g key={i} fill="#d8d8d8">
              <circle cx={x + colon / 2} cy={COUNTER.y - 11} r="3.6" />
              <circle cx={x + colon / 2} cy={COUNTER.y + 11} r="3.6" />
            </g>
          );
        }
        const { radix, index } = s.drum;
        return (
          <g key={i}>
            <clipPath id={`cl-drum-${index}`}>
              <rect x={x} y={y0} width={dw} height={dh} />
            </clipPath>
            <rect x={x} y={y0} width={dw} height={dh} fill="#151515" />
            <g clipPath={`url(#cl-drum-${index})`}>
              <g data-drum={index} transform="translate(0 0)">
                {Array.from({ length: radix + 1 }, (_, d) => (
                  <text
                    key={d}
                    x={x + dw / 2}
                    y={y0 + d * dh + dh * 0.74}
                    textAnchor="middle"
                    fill="#efefef"
                    fontFamily='"Helvetica Neue", Helvetica, Arial, sans-serif'
                    fontWeight="500"
                    fontSize="48"
                  >
                    {d % radix}
                  </text>
                ))}
              </g>
            </g>
            <rect x={x} y={y0} width={dw} height={dh} fill="url(#cl-drum)" />
          </g>
        );
      })}
      {/* Glass glare over the window */}
      <rect x={x0 - 8} y={y0 - 6} width={width + 16} height={(dh + 12) * 0.45} rx="4" fill="#fff" opacity="0.04" />

      <text x={COUNTER.x} y={y0 + dh + 50} textAnchor="middle" {...PRINT} fontSize={15} letterSpacing={3}>
        REMAINING <tspan data-remaining="" fill="#c9c9c9" letterSpacing={2}>-0:00</tspan>
      </text>
    </g>
  );
}

/* ---------------------------------------------------------------- lamps -- */

function Lamp({ x, y, color, label, on, dataKey }: { x: number; y: number; color: 'green' | 'amber'; label: string; on?: boolean; dataKey?: string }) {
  const lit = on ? 1 : 0;
  const tag = dataKey ? { 'data-lamp': dataKey } : { className: 'lamp-fade' };
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle r="90" fill={`url(#cl-glow-${color})`} opacity={lit} style={{ mixBlendMode: 'screen' }} {...tag} />
      <circle cy="3" r="28" fill="#000" opacity="0.6" filter="url(#cl-blur4)" />
      <circle r="27" fill="url(#cl-bezel)" />
      <circle r="20.5" fill="#050505" />
      <circle r="17.5" fill={`url(#cl-lens-${color}-off)`} />
      <circle r="17.5" fill={`url(#cl-lens-${color}-on)`} opacity={lit} {...tag} />
      <ellipse cx="-5" cy="-7" rx="7" ry="4.5" fill="#fff" opacity="0.32" />
      <text y="64" textAnchor="middle" {...PRINT} fontSize={14} letterSpacing={3}>
        {label}
      </text>
    </g>
  );
}

/* --------------------------------------------------------------- slider -- */

function PositionSlider({ svgRef, transport }: { svgRef: RefObject<SVGSVGElement | null>; transport: Transport }) {
  const { x0, x1, y } = SLIDER;
  const dragging = useRef(false);
  const seekTo = (e: ReactPointerEvent) => {
    const p = toSvg(svgRef.current, e);
    transport.seek(clamp01((p.x - x0) / (x1 - x0)) * transport.duration);
  };
  return (
    <g>
      <text x={x0 - 10} y={y - 46} {...PRINT}>
        TAPE POSITION
      </text>
      {Array.from({ length: 21 }, (_, i) => (
        <rect
          key={i}
          x={x0 + (i * (x1 - x0)) / 20 - 1}
          y={y - (i % 10 === 0 ? 34 : i % 2 === 0 ? 30 : 27)}
          width="2"
          height={i % 10 === 0 ? 14 : i % 2 === 0 ? 10 : 7}
          fill="#8a8a8a"
          opacity={i % 2 === 0 ? 0.9 : 0.6}
        />
      ))}
      <text x={x0 - 44} y={y + 6} textAnchor="end" {...PRINT} fontSize={15} letterSpacing={2}>
        0:00
      </text>
      <text x={x1 + 44} y={y + 6} {...PRINT} fontSize={15} letterSpacing={2}>
        {formatTime(transport.duration)}
      </text>

      {/* Slot */}
      <rect x={x0 - 12} y={y - 8} width={x1 - x0 + 24} height="16" rx="8" fill="#fff" opacity="0.07" transform="translate(0 2)" />
      <rect x={x0 - 12} y={y - 8} width={x1 - x0 + 24} height="16" rx="8" fill="#060606" />
      <rect data-progress="" x={x0 - 6} y={y - 3} width="0" height="6" rx="3" fill="#5b3d27" opacity="0.9" />

      <rect
        className="slider-hit"
        x={x0 - 40}
        y={y - 30}
        width={x1 - x0 + 80}
        height="60"
        fill="transparent"
        role="slider"
        aria-label="Tape position"
        onPointerDown={(e) => {
          dragging.current = true;
          (e.currentTarget as Element).setPointerCapture(e.pointerId);
          seekTo(e);
        }}
        onPointerMove={(e) => dragging.current && seekTo(e)}
        onPointerUp={() => (dragging.current = false)}
      />

      {/* Fader cap; positioned by the animation loop */}
      <g data-thumb="" transform={`translate(${x0} ${y})`} pointerEvents="none">
        <rect x="-30" y="-20" width="60" height="48" rx="6" fill="#000" opacity="0.55" filter="url(#cl-blur4)" />
        <rect x="-30" y="-24" width="60" height="48" rx="6" fill="#151515" />
        <rect x="-28" y="-24" width="56" height="42" rx="5" fill="url(#cl-fader)" />
        <rect x="-28" y="-24" width="56" height="42" rx="5" fill="url(#cl-brushed)" opacity="0.4" style={{ mixBlendMode: 'multiply' }} />
        <rect x="-26" y="-23" width="52" height="1.6" rx="0.8" fill="#fff" opacity="0.9" />
        {[-14, -7, 7, 14].map((gx) => (
          <rect key={gx} x={gx - 1} y="-17" width="2" height="28" fill="#000" opacity="0.22" />
        ))}
        <rect x="-1.5" y="-21" width="3" height="36" fill="#2a2a2a" />
      </g>
    </g>
  );
}
