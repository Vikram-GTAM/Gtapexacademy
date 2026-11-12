import { ArrowUp, X } from "lucide-react";
import { useCallback, useEffect, useId, useRef, useState, type FormEvent } from "react";
import { Link, useLocation } from "react-router-dom";
import { contactApi, courseApi } from "../services";
import type { CourseCard } from "../types";
import { cx } from "../utils/format";
import {
  answer, EMPTY_ENQUIRY, enquiryFailed, enquirySent, enquiryStep, ENQUIRY_START, GREETING_FIRST, GREETING_SECOND, PLACEHOLDERS, RETRY,
  STARTER_ACTIONS, startsEnquiry, typingDelay, type Enquiry, type KrishAction, type Stage,
} from "../utils/krish";

type Message = { id: number; from: "krish" | "you"; text: string; actions?: KrishAction[] };
type Mood = "idle" | "wave" | "happy" | "talking";

const BUBBLE_SEEN_KEY = "gt-krish-teaser";
const BUBBLE_DELAY = 7000;

/** Krish herself. She floats, breathes, blinks and glances around; her mood changes what she does. */
function KrishMascot({ size = 48, mood = "idle", className }: { size?: number; mood?: Mood; className?: string }) {
  const id = useId().replace(/:/g, "");
  return (
    <svg viewBox="0 0 120 120" width={size} height={size} aria-hidden="true" className={cx("krish-mascot", `krish-mascot--${mood}`, className)}>
      <defs>
        <radialGradient id={`${id}-body`} cx="38%" cy="30%" r="78%">
          <stop offset="0%" stopColor="#f7fbff" /><stop offset="50%" stopColor="#d9ecf9" /><stop offset="100%" stopColor="#afd3ee" />
        </radialGradient>
        <radialGradient id={`${id}-arm`} cx="40%" cy="35%" r="80%">
          <stop offset="0%" stopColor="#e8f4fd" /><stop offset="100%" stopColor="#b3d7f0" />
        </radialGradient>
        <radialGradient id={`${id}-shadow`}>
          <stop offset="0%" stopColor="#5b86ad" stopOpacity="0.35" /><stop offset="100%" stopColor="#5b86ad" stopOpacity="0" />
        </radialGradient>
      </defs>
      <ellipse className="krish-shadow" cx="60" cy="110" rx="36" ry="5" fill={`url(#${id}-shadow)`} />
      <g className="krish-float">
        <g className="krish-breathe">
          <g className="krish-arm-left"><ellipse cx="18" cy="76" rx="10" ry="13" transform="rotate(32 18 76)" fill={`url(#${id}-arm)`} /></g>
          <g className="krish-arm-right"><ellipse cx="102" cy="76" rx="10" ry="13" transform="rotate(-32 102 76)" fill={`url(#${id}-arm)`} /></g>
          <path d="M60 24C89 24 104 44 104 67c0 19-5 32-17 35-9 2-15-2-27-2s-18 4-27 2C21 99 16 86 16 67c0-23 15-43 44-43Z" fill={`url(#${id}-body)`} />
          <ellipse cx="45" cy="40" rx="17" ry="9" transform="rotate(-16 45 40)" fill="#fff" opacity="0.5" />
          <ellipse className="krish-cheek" cx="35" cy="72" rx="6" ry="3.5" fill="#ff9fb8" />
          <ellipse className="krish-cheek" cx="85" cy="72" rx="6" ry="3.5" fill="#ff9fb8" />
          <g className="krish-eyes">
            <g className="krish-eye"><ellipse cx="44" cy="62" rx="5" ry="6.5" fill="#2b3448" /><circle cx="45.5" cy="59.6" r="1.4" fill="#fff" opacity="0.9" /></g>
            <g className="krish-eye"><ellipse cx="76" cy="62" rx="5" ry="6.5" fill="#2b3448" /><circle cx="77.5" cy="59.6" r="1.4" fill="#fff" opacity="0.9" /></g>
          </g>
          <path className="krish-smile" d="M53 72q7 6 14 0" fill="none" stroke="#2b3448" strokeWidth="3" strokeLinecap="round" />
          <ellipse className="krish-talk" cx="60" cy="74" rx="4.5" ry="3.5" fill="#2b3448" />
        </g>
      </g>
    </svg>
  );
}

function ActionButton({ action, onQuick }: { action: KrishAction; onQuick: (text: string) => void }) {
  const link = "krish-link rounded-full px-3 py-1.5 text-xs font-medium transition-colors";
  if (!action.href) return <button type="button" onClick={() => onQuick(action.quick ?? action.label)} className="krish-option rounded-full px-3 py-1.5 text-xs font-medium transition-colors">{action.label}</button>;
  if (action.href.startsWith("/")) return <Link to={action.href} className={link}>{action.label} →</Link>;
  const opensTab = action.href.startsWith("http");
  return <a href={action.href} target={opensTab ? "_blank" : undefined} rel={opensTab ? "noopener noreferrer" : undefined} className={link}>{action.label} {opensTab ? "↗" : "→"}</a>;
}

/** The mascot, greeting bubble and chat window. It stays mounted across pages, so the conversation survives following a link. */
export function Krish() {
  const { pathname } = useLocation();
  const [open, setOpen] = useState(false);
  const [bubble, setBubble] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [typing, setTyping] = useState(false);
  const [stage, setStage] = useState<Stage>("chat");
  const [draft, setDraft] = useState("");
  const enquiry = useRef<Enquiry>(EMPTY_ENQUIRY);
  const courses = useRef<CourseCard[] | null>(null);
  const loading = useRef<Promise<void> | null>(null);
  const lastCourseId = useRef<string | undefined>();
  const nextId = useRef(0);
  const wasOpen = useRef(false);
  const launcher = useRef<HTMLButtonElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const log = useRef<HTMLDivElement>(null);

  const load = useCallback(() => {
    loading.current ??= courseApi.catalog()
      .then((page) => { courses.current = page.items; })
      .catch(() => { /* Krish says so when a question needs the list; the next load tries again. */ })
      .finally(() => { loading.current = null; });
    return loading.current;
  }, []);

  const add = useCallback((message: Omit<Message, "id">) => setMessages((m) => [...m, { ...message, id: nextId.current++ }]), []);

  /** Shows the typing dots, then the reply. */
  const reply = useCallback((text: string, actions?: KrishAction[]) => {
    setTyping(true);
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.setTimeout(() => { setTyping(false); add({ from: "krish", text, actions }); }, typingDelay(text, reduced));
  }, [add]);

  // The greeting bubble appears once per browser session.
  useEffect(() => {
    let seen = false;
    try { seen = sessionStorage.getItem(BUBBLE_SEEN_KEY) === "1"; } catch { /* Private windows can block storage. */ }
    if (seen) return;
    const timer = window.setTimeout(() => setBubble(true), BUBBLE_DELAY);
    return () => window.clearTimeout(timer);
  }, []);

  const hideBubble = () => {
    setBubble(false);
    try { sessionStorage.setItem(BUBBLE_SEEN_KEY, "1"); } catch { /* Same as above. */ }
  };

  const openChat = () => {
    hideBubble();
    setOpen(true);
    if (messages.length === 0) {
      add({ from: "krish", text: GREETING_FIRST });
      reply(GREETING_SECOND, STARTER_ACTIONS);
    }
  };

  useEffect(() => {
    if (open) {
      void load();
      const focus = window.setTimeout(() => input.current?.focus(), 50);
      const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
      document.addEventListener("keydown", onKey);
      wasOpen.current = true;
      return () => { window.clearTimeout(focus); document.removeEventListener("keydown", onKey); };
    }
    if (wasOpen.current) launcher.current?.focus();
    wasOpen.current = false;
  }, [open, load]);

  // Show the newest message from its first line. Short ones end up at the bottom, as the scroll can't go further.
  useEffect(() => {
    const newest = log.current?.lastElementChild;
    if (log.current && newest) log.current.scrollTop = newest.getBoundingClientRect().top - log.current.getBoundingClientRect().top + log.current.scrollTop - 12;
  }, [messages, typing, open]);

  const submitEnquiry = async () => {
    setStage("sending");
    const e = enquiry.current;
    try {
      await contactApi.chat({ name: e.name, contact: e.contact, interest: e.interest, message: e.message });
      setStage("done");
      const sent = enquirySent(e);
      reply(sent.text, sent.actions);
    } catch {
      setStage("message");
      const failed = enquiryFailed();
      reply(failed.text, failed.actions);
    }
  };

  const send = async (raw: string) => {
    const text = raw.trim();
    if (!text || typing || stage === "sending" || stage === "done") return;
    if (text === RETRY) return void submitEnquiry();
    add({ from: "you", text });
    setDraft("");

    if (stage !== "chat") {
      // A question in the middle of the enquiry gets answered, which can need the course list.
      setTyping(true);
      if (!courses.current && stage !== "message") await (loading.current ?? load());
      const next = enquiryStep(stage, enquiry.current, text, courses.current, lastCourseId.current);
      enquiry.current = next.enquiry;
      setStage(next.stage);
      if (next.reply?.courseId) lastCourseId.current = next.reply.courseId;
      if (next.submit) { setTyping(false); return void submitEnquiry(); }
      if (next.reply) reply(next.reply.text, next.reply.actions);
      else setTyping(false);
      return;
    }
    if (startsEnquiry(text)) {
      enquiry.current = EMPTY_ENQUIRY;
      setStage("name");
      reply(ENQUIRY_START.text, ENQUIRY_START.actions);
      return;
    }
    setTyping(true);
    if (!courses.current) await (loading.current ?? load());
    const answered = answer(text, courses.current, lastCourseId.current);
    if (answered.courseId) lastCourseId.current = answered.courseId;
    reply(answered.text, answered.actions);
  };

  const onSubmit = (e: FormEvent) => { e.preventDefault(); void send(draft); };

  if (pathname.startsWith("/admin") || pathname.startsWith("/app/learn")) return null;

  const latestId = messages.length ? messages[messages.length - 1].id : -1;
  const closed = stage === "sending" || stage === "done";

  return (
    <div className="krish">
      {bubble && !open && (
        <div className="krish-card krish-rise fixed bottom-24 right-5 z-40 flex max-w-[17rem] items-start gap-3 rounded-2xl p-3.5 pr-9 sm:right-6">
          <KrishMascot size={40} mood="wave" className="-my-1 shrink-0" />
          <button type="button" onClick={openChat} className="text-left text-sm leading-snug">
            <span className="block font-medium text-slate-900">Hi, I'm Krish 👋</span>
            <span className="text-slate-500">Need help choosing a course? Ask me anything.</span>
          </button>
          <button type="button" onClick={hideBubble} aria-label="Dismiss" className="absolute right-2 top-2 grid h-6 w-6 place-items-center rounded-full text-slate-500 transition-colors hover:text-slate-900"><X className="h-3.5 w-3.5" aria-hidden="true" /></button>
        </div>
      )}

      {open && (
        <div
          role="dialog" aria-label="Chat with Krish"
          className="krish-card krish-rise fixed inset-x-3 bottom-3 z-40 flex h-[min(38rem,calc(100dvh-1.5rem))] flex-col overflow-hidden rounded-2xl sm:inset-x-auto sm:bottom-24 sm:right-6 sm:h-[min(36rem,calc(100dvh-8rem))] sm:w-[23rem]"
        >
          <header className="krish-line-b flex items-center gap-3 px-4 py-3.5">
            <span className="relative shrink-0">
              <span className="krish-avatar grid h-11 w-11 place-items-center rounded-full"><KrishMascot size={38} mood={typing ? "talking" : "idle"} /></span>
              <span aria-hidden="true" className="krish-dot absolute bottom-0 right-0 h-3 w-3 rounded-full" />
            </span>
            <div className="min-w-0 flex-1 leading-tight">
              <p className="truncate font-medium text-slate-900">Krish <span className="font-normal text-slate-500">· GTapex assistant</span></p>
              <p className="mt-0.5 text-xs text-brand-600">Online · replies instantly</p>
            </div>
            <button type="button" onClick={() => setOpen(false)} aria-label="Close chat" className="grid h-9 w-9 place-items-center rounded-full text-slate-500 transition-colors hover:text-slate-900"><X className="h-5 w-5" aria-hidden="true" /></button>
          </header>

          <div ref={log} role="log" aria-live="polite" className="flex-1 space-y-3 overflow-y-auto px-4 py-5">
            {messages.map((m) => (
              <div key={m.id} className={cx("flex flex-col", m.from === "you" ? "items-end" : "items-start")}>
                <p className={cx("max-w-[85%] whitespace-pre-line break-words rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed", m.from === "you" ? "krish-you rounded-br-md" : "krish-bot rounded-bl-md")}>{m.text}</p>
                {m.id === latestId && !!m.actions?.length && (
                  <div className="mt-2.5 flex max-w-[95%] flex-wrap gap-2">
                    {m.actions.map((a) => <ActionButton key={a.label} action={a} onQuick={(t) => void send(t)} />)}
                  </div>
                )}
              </div>
            ))}
            {typing && (
              <div role="status" aria-label="Krish is typing" className="krish-bot flex w-fit items-center gap-1 rounded-2xl rounded-bl-md px-3.5 py-3">
                {[0, 1, 2].map((i) => <span key={i} className="krish-typing-dot h-1.5 w-1.5 rounded-full" style={{ animationDelay: `${160 * i}ms` }} />)}
              </div>
            )}
          </div>

          <form onSubmit={onSubmit} className="krish-line-t flex items-center gap-2 p-3">
            <input
              ref={input} value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={1000} disabled={closed}
              aria-label="Your question" placeholder={PLACEHOLDERS[stage]} autoComplete={stage === "name" ? "name" : stage === "contact" ? "email" : "off"}
              className="krish-input h-11 min-w-0 flex-1 rounded-full px-4 text-base text-slate-900 outline-none placeholder:text-slate-500 disabled:opacity-50 sm:text-sm"
            />
            <button type="submit" aria-label="Send" disabled={!draft.trim() || typing || closed} className="neon-btn grid h-11 w-11 shrink-0 place-items-center rounded-full transition-colors disabled:opacity-40"><ArrowUp className="h-5 w-5" strokeWidth={2.25} aria-hidden="true" /></button>
          </form>
        </div>
      )}

      <button
        ref={launcher} type="button" onClick={() => (open ? setOpen(false) : openChat())} onPointerEnter={() => void load()} onFocus={() => void load()}
        aria-label={open ? "Close chat" : "Chat with Krish"} aria-expanded={open}
        className={cx("krish-launcher fixed bottom-4 right-4 z-40 grid h-[4.5rem] w-[4.5rem] place-items-center rounded-full transition-[transform,opacity] duration-300 hover:scale-105 active:scale-95 sm:right-5", open && "max-sm:pointer-events-none max-sm:scale-75 max-sm:opacity-0")}
      >
        <span aria-hidden="true" className="absolute inset-1 rounded-full bg-[#9cc9ec]/30 blur-xl" />
        <KrishMascot size={68} mood={open ? "happy" : bubble ? "wave" : "idle"} className="relative drop-shadow-[0_6px_14px_rgba(43,52,72,0.18)]" />
        {open
          ? <span aria-hidden="true" className="krish-close absolute right-0.5 top-0.5 grid h-6 w-6 place-items-center rounded-full shadow-md"><X className="h-3.5 w-3.5" strokeWidth={2.75} /></span>
          : <span aria-hidden="true" className="krish-dot absolute right-2 top-2 h-3.5 w-3.5 rounded-full" />}
      </button>
    </div>
  );
}
