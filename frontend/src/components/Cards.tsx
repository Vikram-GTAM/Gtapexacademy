import { CalendarDays, Clock, ExternalLink, Radio, Video } from "lucide-react";
import { Link } from "react-router-dom";
import { safeUrl } from "../services/api";
import type { Assignment, LiveClass } from "../types";
import { cx, formatDate, formatDateTime, formatTime } from "../utils/format";
import { Badge, Button, type Tone } from "./ui";

const liveTone: Record<string, { tone: Tone; label: string }> = { upcoming: { tone: "blue", label: "Upcoming" }, live: { tone: "red", label: "Live now" }, completed: { tone: "slate", label: "Completed" } };

export function LiveClassCard({ lc, compact }: { lc: LiveClass; compact?: boolean }) {
  const s = liveTone[lc.status];
  const joinable = lc.status !== "completed" && !!lc.meeting_url;
  return (
    <div className={cx("glass rounded-2xl p-4", lc.status === "live" && "!border-rose-300/70 shadow-[0_0_28px_rgba(244,63,94,.25)]")}>
      <div className="mb-2 flex items-start justify-between gap-2">
        <Badge tone={s.tone} dot>{lc.status === "live" && <Radio className="h-3 w-3 animate-pulse" />}{s.label}</Badge>
        <span className="flex items-center gap-1 text-xs text-slate-400"><Video className="h-3.5 w-3.5" />{lc.platform}</span>
      </div>
      <h3 className="font-bold leading-snug text-slate-900">{lc.title}</h3>
      <p className="mt-0.5 text-xs font-medium text-brand-600">{lc.course_title}</p>
      {!compact && lc.description && <p className="mt-2 line-clamp-2 text-sm text-slate-500">{lc.description}</p>}
      <div className="mt-3 space-y-1 text-sm text-slate-600">
        <p className="flex items-center gap-2"><CalendarDays className="h-4 w-4 text-slate-400" />{formatDate(lc.starts_at)}</p>
        <p className="flex items-center gap-2"><Clock className="h-4 w-4 text-slate-400" />{formatTime(lc.starts_at)} – {formatTime(lc.ends_at)} · {lc.duration_minutes} min</p>
      </div>
      {lc.status !== "completed" && (
        <div className="mt-4">
          {joinable ? (
            <a href={safeUrl(lc.meeting_url)} target="_blank" rel="noopener noreferrer" className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-xl bg-neon px-4 text-sm font-semibold text-brand-ink shadow-sm hover:bg-neon-dark">
              <ExternalLink className="h-4 w-4" />Join Live Class
            </a>
          ) : (
            <><Button className="w-full" disabled>Join Live Class</Button><p className="mt-1.5 text-center text-xs text-slate-400">Joining opens 15 minutes before the start time</p></>
          )}
        </div>
      )}
    </div>
  );
}

export function assignmentState(a: Assignment): { label: string; tone: Tone } {
  if (a.submission?.status === "reviewed") return { label: "Graded", tone: "green" };
  if (a.submission) return { label: "Submitted", tone: "blue" };
  if (a.is_past_deadline && !a.allow_late) return { label: "Missed", tone: "red" };
  if (a.is_past_deadline) return { label: "Late allowed", tone: "amber" };
  return { label: "Pending", tone: "amber" };
}

export function AssignmentRow({ a }: { a: Assignment }) {
  const st = assignmentState(a);
  return (
    <Link to={`/app/assignments/${a.id}`} className="flex flex-col gap-3 rounded-2xl glass p-4 shadow-card transition hover:border-brand-500/60 hover:shadow-md sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <p className="truncate font-semibold text-slate-900">{a.title}</p>
        <p className="mt-0.5 text-xs text-slate-500">{a.course_title} · Due {formatDateTime(a.deadline)} · {a.max_marks} marks</p>
      </div>
      <div className="flex items-center gap-3">
        {a.submission?.marks != null && <span className="text-sm font-bold text-emerald-600">{a.submission.marks}/{a.max_marks}</span>}
        <Badge tone={st.tone}>{st.label}</Badge>
      </div>
    </Link>
  );
}
