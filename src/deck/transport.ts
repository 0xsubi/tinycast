import { useState, useSyncExternalStore } from 'react';

/**
 * Playback clock for the deck. Drives a real <audio> element once a file is
 * loaded; until then it runs a silent simulated clock so the deck still plays.
 * Time is read every animation frame, so it is exposed as a getter rather than
 * as React state; only discrete changes (play/pause/volume/duration) emit.
 */
export class Transport {
  playing = false;
  duration: number;
  volume = 0.72;

  private audio: HTMLAudioElement | null = null;
  private simTime: number;
  private simAnchor = 0;
  private version = 0;
  private listeners = new Set<() => void>();

  constructor(duration: number, startAt = 0) {
    this.duration = duration;
    this.simTime = startAt;
  }

  subscribe = (fn: () => void) => {
    this.listeners.add(fn);
    return () => {
      this.listeners.delete(fn);
    };
  };

  getSnapshot = () => this.version;

  private emit() {
    this.version++;
    this.listeners.forEach((fn) => fn());
  }

  get time(): number {
    if (this.audio) return this.audio.currentTime || 0;
    if (!this.playing) return this.simTime;
    return Math.min(this.duration, this.simTime + (performance.now() - this.simAnchor) / 1000);
  }

  /** Called once per frame; stops the simulated clock at the end of the tape. */
  tick() {
    if (!this.audio && this.playing && this.time >= this.duration) {
      this.simTime = this.duration;
      this.playing = false;
      this.emit();
    }
  }

  play() {
    if (this.playing) return;
    if (this.time >= this.duration - 0.25) this.seek(0);
    if (this.audio) {
      // State follows the element's play/pause events.
      this.audio.play().catch(() => {});
      return;
    }
    this.simAnchor = performance.now();
    this.playing = true;
    this.emit();
  }

  pause() {
    if (!this.playing) return;
    if (this.audio) {
      this.audio.pause();
      return;
    }
    this.simTime = this.time;
    this.playing = false;
    this.emit();
  }

  toggle() {
    if (this.playing) this.pause();
    else this.play();
  }

  seek(t: number) {
    const c = Math.max(0, Math.min(this.duration, t));
    if (this.audio) {
      this.audio.currentTime = c;
    } else {
      this.simTime = c;
      this.simAnchor = performance.now();
    }
  }

  skip(delta: number) {
    this.seek(this.time + delta);
  }

  setVolume(v: number) {
    this.volume = Math.max(0, Math.min(1, v));
    if (this.audio) this.audio.volume = this.volume;
    this.emit();
  }

  /** Thread a new audio source. Resolves with its duration in seconds. */
  load(src: string): Promise<number> {
    this.unload();
    const audio = new Audio();
    audio.preload = 'auto';
    audio.volume = this.volume;
    const sync = (playing: boolean) => () => {
      if (this.audio !== audio) return;
      this.playing = playing;
      this.emit();
    };
    audio.addEventListener('play', sync(true));
    audio.addEventListener('pause', sync(false));
    audio.addEventListener('ended', sync(false));
    audio.src = src;
    this.audio = audio;
    this.playing = false;
    this.emit();

    return new Promise((resolve, reject) => {
      audio.addEventListener(
        'loadedmetadata',
        () => {
          this.duration = Number.isFinite(audio.duration) ? audio.duration : 0;
          this.emit();
          resolve(this.duration);
        },
        { once: true },
      );
      audio.addEventListener('error', () => reject(new Error('Could not load that audio file')), { once: true });
    });
  }

  private unload() {
    if (!this.audio) return;
    const old = this.audio;
    this.audio = null;
    old.pause();
    old.removeAttribute('src');
    old.load();
  }
}

export function useTransport(duration: number, startAt = 0): Transport {
  const [transport] = useState(() => new Transport(duration, startAt));
  useSyncExternalStore(transport.subscribe, transport.getSnapshot);
  return transport;
}
