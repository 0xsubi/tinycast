import { useEffect, useState } from 'react';
import type { Episode } from './deck/ControlsLayer';
import { TapeDeck } from './deck/TapeDeck';
import { useTransport } from './deck/transport';

const DEMO_EPISODE: Episode = { show: 'Reel Talk', number: '042', title: 'The Warmth of Analog' };
const DEMO_DURATION = 47 * 60 + 32;
// Resume part-way in, so both reels carry tape like the reference.
const DEMO_RESUME_AT = 9 * 60 + 24;

export function App() {
  const transport = useTransport(DEMO_DURATION, DEMO_RESUME_AT);
  const [episode, setEpisode] = useState(DEMO_EPISODE);
  const [error, setError] = useState<string | null>(null);

  const loadFile = (file: File) => {
    setError(null);
    transport
      .load(URL.createObjectURL(file))
      .then(() => {
        setEpisode({ show: 'Local File', number: '001', title: file.name.replace(/\.[^.]+$/, '') });
        transport.play();
      })
      .catch((e: Error) => setError(e.message));
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement) return;
      if (e.code === 'Space') {
        e.preventDefault();
        transport.toggle();
      } else if (e.key === 'ArrowLeft') {
        transport.skip(-15);
      } else if (e.key === 'ArrowRight') {
        transport.skip(30);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [transport]);

  return (
    <main className="stage">
      <TapeDeck transport={transport} episode={episode} onLoadFile={loadFile} />
      <p className="hint">
        {error ?? 'Space play / pause · ← → skip · drop an audio file on the deck or click the label to load an episode'}
      </p>
    </main>
  );
}
