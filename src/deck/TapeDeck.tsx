import { memo, useEffect, useRef, useState, type DragEvent, type RefObject } from 'react';
import { Backplate } from './Backplate';
import { ControlsLayer, DRUM_H, DRUM_RADIX, SLIDER, type Episode } from './ControlsLayer';
import { FrontLayer } from './FrontLayer';
import { REELS, SIDES, TAPE_SPEED, clamp01, formatTime, packRadius, tapePath, type Side } from './geometry';
import { ReelsLayer, localOffset } from './ReelsLayer';
import type { Transport } from './transport';

/** Max reel angular speed while winding (rad/s); kept well below wagon-wheel aliasing. */
const MAX_OMEGA = 22;
/** Position differences larger than this (s) are animated as a fast wind. */
const SNAP = 0.75;
const WIND_RATE = 3;
/** Motor spin-up / spin-down rate. */
const MOTOR_RATE = 5;
/** Seconds the odometer takes to roll one digit. */
const ROLL = 0.18;

// Static layers never need to re-render.
const StaticBack = memo(Backplate);
const StaticFront = memo(FrontLayer);
const Reels = memo(ReelsLayer);

interface Props {
  transport: Transport;
  episode: Episode;
  onLoadFile: (file: File) => void;
}

export function TapeDeck({ transport, episode, onLoadFile }: Props) {
  const rootRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [initialProgress] = useState(() => clamp01(transport.time / transport.duration));
  const [dragOver, setDragOver] = useState(false);

  useDeckAnimation(rootRef, transport);

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = Array.from(e.dataTransfer.files).find((f) => f.type.startsWith('audio/'));
    if (file) onLoadFile(file);
  };

  return (
    <div
      ref={rootRef}
      className={`deck${dragOver ? ' deck--drop' : ''}`}
      onDragOver={(e) => {
        e.preventDefault();
        setDragOver(true);
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={onDrop}
    >
      <StaticBack />
      <Reels progress={initialProgress} />
      <StaticFront />
      <ControlsLayer transport={transport} episode={episode} onPickFile={() => fileRef.current?.click()} />
      <input
        ref={fileRef}
        type="file"
        accept="audio/*"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) onLoadFile(file);
          e.target.value = '';
        }}
      />
    </div>
  );
}

/**
 * Per-frame animation, applied straight to the DOM so React never re-renders
 * at 60fps. Tape moves at constant linear speed, so each reel's angular
 * speed is v / r — the nearly-empty reel spins visibly faster.
 */
function useDeckAnimation(rootRef: RefObject<HTMLDivElement | null>, transport: Transport) {
  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const all = <T extends Element>(sel: string) => Array.from(root.querySelectorAll<T>(sel));
    const bySide = <T extends Element>(attr: string) => ({ L: all<T>(`[${attr}="L"]`), R: all<T>(`[${attr}="R"]`) });

    const els = {
      rot: bySide<SVGGElement>('data-rot'),
      crot: bySide<SVGGradientElement>('data-crot'),
      off: {
        L: all<SVGElement>('[data-off="L"]').map((el) => ({ el, ox: Number(el.dataset.ox), oy: Number(el.dataset.oy) })),
        R: all<SVGElement>('[data-off="R"]').map((el) => ({ el, ox: Number(el.dataset.ox), oy: Number(el.dataset.oy) })),
      },
      pack: bySide<SVGCircleElement>('data-pack'),
      tape: all<SVGPathElement>('[data-tape]'),
      drums: all<SVGGElement>('[data-drum]').reduce<SVGGElement[]>((acc, el) => {
        acc[Number(el.dataset.drum)] = el;
        return acc;
      }, []),
      thumb: all<SVGGElement>('[data-thumb]')[0],
      progress: all<SVGRectElement>('[data-progress]')[0],
      wind: all<SVGElement>('[data-lamp="wind"]'),
      remaining: all<SVGTSpanElement>('[data-remaining]')[0],
    };

    const st = {
      display: transport.time,
      motor: 0,
      angle: { L: (REELS.L.base * Math.PI) / 180, R: (REELS.R.base * Math.PI) / 180 } as Record<Side, number>,
      r: { L: -1, R: -1 } as Record<Side, number>,
      wind: 0,
      remaining: '',
    };

    const applyRotation = (side: Side) => {
      const a = st.angle[side];
      const deg = (a * 180) / Math.PI;
      const { cx, cy } = REELS[side];
      els.rot[side].forEach((g) => g.setAttribute('transform', `translate(${cx} ${cy}) rotate(${deg.toFixed(3)})`));
      els.crot[side].forEach((g) => g.setAttribute('gradientTransform', `rotate(${(-deg).toFixed(3)})`));
      for (const { el, ox, oy } of els.off[side]) {
        const [lx, ly] = localOffset(ox, oy, a);
        el.setAttribute('transform', `translate(${lx.toFixed(2)} ${ly.toFixed(2)})`);
      }
    };

    const applyCounter = (t: number) => {
      let unit = 1;
      DRUM_RADIX.forEach((radix, i) => {
        const whole = Math.floor(t / unit) % radix;
        const lower = t % unit;
        // A drum rolls only while every drum below it is rolling over.
        let frac = clamp01((lower - (unit - ROLL)) / ROLL);
        frac = frac * frac * (3 - 2 * frac);
        els.drums[i]?.setAttribute('transform', `translate(0 ${(-(whole + frac) * DRUM_H).toFixed(2)})`);
        unit *= radix;
      });
    };

    let raf = 0;
    let last = performance.now();
    const frame = (now: number) => {
      const gap = (now - last) / 1000;
      const dt = Math.min(0.05, Math.max(0, gap));
      last = now;
      transport.tick();

      const dur = Math.max(1, transport.duration);
      const actual = Math.min(transport.time, dur);
      // After a long stall (background tab) just catch up instead of fast-winding.
      if (gap > 0.25) st.display = actual;
      st.motor += ((transport.playing ? 1 : 0) - st.motor) * (1 - Math.exp(-dt * MOTOR_RATE));

      // Tape travel this frame, in viewBox units (positive = forward).
      let travel: number;
      const diff = actual - st.display;
      const winding = Math.abs(diff) > SNAP;
      if (winding) {
        const step = diff * (1 - Math.exp(-dt * WIND_RATE));
        st.display += step;
        travel = step * TAPE_SPEED;
      } else {
        st.display = actual;
        travel = st.motor * TAPE_SPEED * dt;
      }

      const p = clamp01(st.display / dur);
      const radius = { L: packRadius(1 - p), R: packRadius(p) };
      const limit = MAX_OMEGA * dt * Math.min(radius.L, radius.R);
      travel = Math.max(-limit, Math.min(limit, travel));

      for (const side of SIDES) {
        // Both reels turn counter-clockwise when the tape runs forward.
        st.angle[side] = (st.angle[side] - travel / radius[side]) % (Math.PI * 2);
        applyRotation(side);
      }

      if (Math.abs(radius.L - st.r.L) > 0.25 || Math.abs(radius.R - st.r.R) > 0.25) {
        for (const side of SIDES) {
          st.r[side] = radius[side];
          els.pack[side].forEach((c) => c.setAttribute('r', radius[side].toFixed(2)));
        }
        const d = tapePath(radius.L, radius.R);
        els.tape.forEach((t) => t.setAttribute('d', d));
      }

      applyCounter(st.display);

      // The fader follows the real position so dragging feels direct.
      const pActual = clamp01(actual / dur);
      const tx = SLIDER.x0 + pActual * (SLIDER.x1 - SLIDER.x0);
      els.thumb?.setAttribute('transform', `translate(${tx.toFixed(2)} ${SLIDER.y})`);
      els.progress?.setAttribute('width', Math.max(0, tx - SLIDER.x0 + 6).toFixed(2));

      st.wind += ((winding ? 1 : 0) - st.wind) * (1 - Math.exp(-dt * 12));
      els.wind.forEach((el) => el.setAttribute('opacity', st.wind.toFixed(3)));

      const remaining = `-${formatTime(dur - actual)}`;
      if (remaining !== st.remaining && els.remaining) {
        st.remaining = remaining;
        els.remaining.textContent = remaining;
      }

      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [rootRef, transport]);
}
