import { VideoOff } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

function embedUrl(src: string): string | null {
  const yt = src.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([\w-]{11})/);
  if (yt) return `https://www.youtube.com/embed/${yt[1]}?rel=0&modestbranding=1`;
  const vm = src.match(/vimeo\.com\/(?:video\/)?(\d+)/);
  if (vm) return `https://player.vimeo.com/video/${vm[1]}`;
  return null;
}

export function VideoPlayer({ src, title, onEnded }: { src?: string | null; title: string; onEnded?: () => void }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  const embed = useMemo(() => (src ? embedUrl(src) : null), [src]);

  return (
    <div className="aspect-video w-full overflow-hidden rounded-2xl bg-black shadow-lg">
      {!src || failed ? (
        <div className="flex h-full flex-col items-center justify-center gap-3 p-6 text-center text-slate-500">
          <VideoOff className="h-10 w-10 text-slate-500" />
          <p className="text-sm">{!src ? "No video has been added to this lesson yet." : "This video couldn't be loaded. Try refreshing the page."}</p>
        </div>
      ) : embed ? (
        <iframe key={embed} src={embed} title={title} className="h-full w-full" allow="accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen" allowFullScreen />
      ) : (
        <video key={src} src={src} controls controlsList="nodownload" preload="metadata" className="h-full w-full" onEnded={onEnded} onError={() => setFailed(true)} aria-label={title}>
          Your browser does not support video playback.
        </video>
      )}
    </div>
  );
}
