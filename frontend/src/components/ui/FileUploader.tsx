import { CheckCircle2, FileText, Loader2, UploadCloud, X } from "lucide-react";
import { useRef, useState, type DragEvent } from "react";
import { getErrorMessage } from "../../services/api";
import { cx } from "../../utils/format";

interface Props {
  label?: string; accept?: string; maxMB?: number; hint?: string;
  /** Upload mode: performs the upload and returns a stored URL. */
  onUpload?: (file: File) => Promise<string>;
  /** Select mode (no upload): receives the raw file, e.g. for form submission. */
  onSelect?: (file: File | null) => void;
  value?: string | null; onChange?: (url: string | null) => void; image?: boolean;
  fileName?: string | null;
}

export function FileUploader({ label, accept, maxMB = 25, hint, onUpload, onSelect, value, onChange, image, fileName }: Props) {
  const input = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);
  const [picked, setPicked] = useState<string | null>(null);

  async function handle(file: File | undefined) {
    if (!file) return;
    setError(null);
    if (file.size > maxMB * 1024 * 1024) { setError(`File is too large. Maximum size is ${maxMB} MB.`); return; }
    if (onSelect) { setPicked(file.name); onSelect(file); return; }
    if (!onUpload) return;
    setBusy(true);
    try { onChange?.(await onUpload(file)); } catch (e) { setError(getErrorMessage(e, "Upload failed")); } finally { setBusy(false); }
  }
  const drop = (e: DragEvent) => { e.preventDefault(); setDrag(false); handle(e.dataTransfer.files?.[0]); };
  const current = onSelect ? picked : value ? (fileName ?? value.split("/").pop() ?? "File") : null;
  const clear = () => { setPicked(null); setError(null); if (input.current) input.current.value = ""; onSelect ? onSelect(null) : onChange?.(null); };

  return (
    <div>
      {label && <span className="mb-1.5 block text-sm font-medium text-slate-700">{label}</span>}
      {image && value && !onSelect && <img src={value} alt="Preview" className="mb-2 h-32 w-full rounded-xl border border-slate-200 object-cover" />}
      <div
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)} onDrop={drop}
        className={cx("flex items-center gap-3 rounded-xl border-2 border-dashed px-4 py-3.5 transition", drag ? "border-brand-500 bg-brand-50" : "border-slate-300 bg-white/[0.02] hover:border-brand-500/60")}>
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
          {busy ? <Loader2 className="h-5 w-5 animate-spin text-brand-600" /> : current ? <CheckCircle2 className="h-5 w-5 text-brand-500" /> : <UploadCloud className="h-5 w-5" />}
        </div>
        <div className="min-w-0 flex-1">
          {current ? <p className="flex items-center gap-1.5 truncate text-sm font-medium text-slate-800"><FileText className="h-4 w-4 shrink-0 text-slate-400" /><span className="truncate">{current}</span></p>
            : <p className="text-sm text-slate-600"><button type="button" className="font-semibold text-brand-600 hover:underline" onClick={() => input.current?.click()}>Choose a file</button> or drag it here</p>}
          <p className="text-xs text-slate-400">{hint ?? `Max ${maxMB} MB`}</p>
        </div>
        {current && !busy && <button type="button" onClick={clear} aria-label="Remove file" className="rounded-lg p-1.5 text-slate-400 hover:bg-white/10 hover:text-slate-600"><X className="h-4 w-4" /></button>}
        <input ref={input} type="file" accept={accept} className="sr-only" onChange={(e) => handle(e.target.files?.[0])} />
      </div>
      {error && <p className="mt-1.5 text-xs text-rose-600" role="alert">{error}</p>}
    </div>
  );
}
