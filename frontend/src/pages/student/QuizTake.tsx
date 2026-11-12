import { ArrowLeft, CheckCircle2, Clock, XCircle } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Badge, Button, Card, ConfirmationModal, ErrorState, PageLoader, ProgressBar } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { quizApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { AttemptResult } from "../../types";
import { cx, formatClock } from "../../utils/format";

export default function QuizTake() {
  const { id = "" } = useParams();
  const toast = useToast();
  const { data: quiz, loading, error, reloadWithSpinner } = useAsync(() => quizApi.get(id), [id]);
  const [attemptId, setAttemptId] = useState<string | null>(null);
  const [answers, setAnswers] = useState<Record<string, string | null>>({});
  const [index, setIndex] = useState(0);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [result, setResult] = useState<AttemptResult | null>(null);
  const [starting, setStarting] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const deadline = useRef<number | null>(null);
  const submitted = useRef(false);

  const submit = useCallback(async (auto = false) => {
    if (!quiz || !attemptId || submitted.current) return;
    submitted.current = true;
    setSubmitting(true); setConfirm(false);
    try {
      const r = await quizApi.submit(quiz.id, {
        attempt_id: attemptId,
        answers: (quiz.questions ?? []).map((q) => ({ question_id: q.id, option_id: answers[q.id] ?? null })),
      });
      setResult(r);
      if (auto) toast.info("Time's up — your answers were submitted.");
    } catch (e) {
      submitted.current = false;
      toast.error(getErrorMessage(e));
    } finally { setSubmitting(false); }
  }, [quiz, attemptId, answers, toast]);

  // countdown
  useEffect(() => {
    if (remaining === null || result) return;
    const t = setInterval(() => {
      const left = Math.max(0, Math.round(((deadline.current ?? 0) - Date.now()) / 1000));
      setRemaining(left);
      if (left <= 0) { clearInterval(t); submit(true); }
    }, 500);
    return () => clearInterval(t);
  }, [remaining === null, result, submit]); // eslint-disable-line react-hooks/exhaustive-deps

  // warn on tab close mid-attempt
  useEffect(() => {
    if (!attemptId || result) return;
    const h = (e: BeforeUnloadEvent) => { e.preventDefault(); e.returnValue = ""; };
    window.addEventListener("beforeunload", h);
    return () => window.removeEventListener("beforeunload", h);
  }, [attemptId, result]);

  if (loading) return <PageLoader />;
  if (error || !quiz) return <ErrorState message={error ?? "Quiz not found"} onRetry={reloadWithSpinner} />;
  const questions = quiz.questions ?? [];

  async function start() {
    setStarting(true);
    try {
      const r = await quizApi.start(id);
      setAttemptId(r.attempt_id); setAnswers({}); setIndex(0); submitted.current = false;
      if (r.time_limit_minutes) {
        deadline.current = Date.now() + r.time_limit_minutes * 60_000;
        setRemaining(r.time_limit_minutes * 60);
      } else { deadline.current = null; setRemaining(null); }
    } catch (e) { toast.error(getErrorMessage(e)); } finally { setStarting(false); }
  }

  const back = <Link to="/app/quizzes" className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-slate-500 hover:text-slate-800"><ArrowLeft className="h-4 w-4" />All quizzes</Link>;

  // ---------- results ----------
  if (result) {
    const byQ = new Map((result.results ?? []).map((r) => [r.question_id, r]));
    const pass = result.percentage >= 60;
    return (
      <div className="mx-auto max-w-3xl">
        {back}
        <Card className="text-center">
          <div className={cx("mx-auto mb-3 flex h-16 w-16 items-center justify-center rounded-full", pass ? "bg-emerald-50 text-emerald-600" : "bg-amber-50 text-amber-600")}>{pass ? <CheckCircle2 className="h-9 w-9" /> : <XCircle className="h-9 w-9" />}</div>
          <h1 className="text-2xl font-bold text-slate-900">{pass ? "Nice work!" : "Keep practising"}</h1>
          <p className="mt-2 text-5xl font-extrabold text-slate-900">{result.score}<span className="text-2xl text-slate-400"> / {result.total_marks}</span></p>
          <p className="mt-1 text-slate-500">{result.percentage}% correct</p>
          <div className="mt-5 flex justify-center gap-3"><Button onClick={() => { setResult(null); setAttemptId(null); setRemaining(null); }}>Try again</Button><Link to="/app/quizzes" className="inline-flex h-10 items-center rounded-xl border border-slate-300 px-4 text-sm font-semibold text-slate-700 hover:bg-white/5">Back to quizzes</Link></div>
        </Card>
        {result.show_results && result.results ? (
          <div className="mt-6 space-y-4">
            <h2 className="text-lg font-bold text-slate-900">Review</h2>
            {questions.map((q, i) => {
              const r = byQ.get(q.id);
              return (
                <Card key={q.id}>
                  <div className="mb-3 flex items-start justify-between gap-3"><p className="font-semibold text-slate-900">{i + 1}. {q.text}</p>{r?.is_correct ? <Badge tone="green">Correct</Badge> : <Badge tone="red">{r?.selected_option_id ? "Incorrect" : "Skipped"}</Badge>}</div>
                  <ul className="space-y-2">
                    {q.options.map((o) => {
                      const isCorrect = o.id === r?.correct_option_id; const isPicked = o.id === r?.selected_option_id;
                      return <li key={o.id} className={cx("flex items-center justify-between rounded-lg border px-3 py-2 text-sm", isCorrect ? "border-emerald-300 bg-emerald-50 text-emerald-800" : isPicked ? "border-rose-300 bg-rose-50 text-rose-800" : "border-slate-200 text-slate-600")}><span>{o.text}</span>{isCorrect ? <span className="text-xs font-semibold">Correct answer</span> : isPicked ? <span className="text-xs font-semibold">Your answer</span> : null}</li>;
                    })}
                  </ul>
                </Card>
              );
            })}
          </div>
        ) : <p className="mt-6 text-center text-sm text-slate-500">Detailed answers are not shown for this quiz.</p>}
      </div>
    );
  }

  // ---------- intro ----------
  if (!attemptId) {
    return (
      <div className="mx-auto max-w-2xl">
        {back}
        <Card>
          <Badge tone="brand">{quiz.course_title}</Badge>
          <h1 className="mt-2 text-2xl font-bold text-slate-900">{quiz.title}</h1>
          {quiz.description && <p className="mt-2 text-slate-600">{quiz.description}</p>}
          <dl className="mt-5 grid grid-cols-3 gap-3 text-center">
            <div className="rounded-xl bg-slate-50 p-3"><dt className="text-xs text-slate-500">Questions</dt><dd className="text-lg font-bold">{quiz.question_count}</dd></div>
            <div className="rounded-xl bg-slate-50 p-3"><dt className="text-xs text-slate-500">Total marks</dt><dd className="text-lg font-bold">{quiz.total_marks}</dd></div>
            <div className="rounded-xl bg-slate-50 p-3"><dt className="text-xs text-slate-500">Time limit</dt><dd className="text-lg font-bold">{quiz.time_limit_minutes ? `${quiz.time_limit_minutes}m` : "None"}</dd></div>
          </dl>
          {quiz.time_limit_minutes > 0 && <p className="mt-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-800">The timer starts as soon as you begin and your answers are submitted automatically when time runs out.</p>}
          {quiz.last_attempt && <p className="mt-4 text-sm text-slate-500">Your last score: <strong>{quiz.last_attempt.score}/{quiz.last_attempt.total_marks}</strong></p>}
          <Button className="mt-6 w-full" size="lg" onClick={start} loading={starting} disabled={questions.length === 0}>{questions.length === 0 ? "No questions yet" : "Start quiz"}</Button>
        </Card>
      </div>
    );
  }

  // ---------- taking ----------
  const q = questions[index];
  const answered = questions.filter((x) => answers[x.id]).length;
  const low = remaining !== null && remaining <= 60;
  return (
    <div className="mx-auto max-w-3xl">
      <div className="sticky top-0 z-10 -mx-4 mb-4 border-b border-slate-200 bg-slate-50/95 px-4 py-3 backdrop-blur sm:mx-0 sm:rounded-xl sm:border">
        <div className="flex items-center justify-between gap-3">
          <p className="truncate text-sm font-semibold text-slate-700">{quiz.title}</p>
          {remaining !== null && <span className={cx("flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-bold tabular-nums", low ? "bg-rose-100 text-rose-700" : "bg-brand-50 text-brand-700")} aria-live="off"><Clock className="h-4 w-4" />{formatClock(remaining)}</span>}
        </div>
        <ProgressBar value={(answered / questions.length) * 100} size="sm" className="mt-2" />
      </div>
      <Card>
        <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Question {index + 1} of {questions.length} · {q.marks} {q.marks === 1 ? "mark" : "marks"}</p>
        <h2 className="mb-5 text-lg font-bold text-slate-900">{q.text}</h2>
        <div role="radiogroup" aria-label={q.text} className="space-y-3">
          {q.options.map((o) => {
            const on = answers[q.id] === o.id;
            return (
              <button key={o.id} type="button" role="radio" aria-checked={on} onClick={() => setAnswers((a) => ({ ...a, [q.id]: o.id }))}
                className={cx("flex w-full items-center gap-3 rounded-xl border-2 px-4 py-3 text-left text-sm transition", on ? "border-brand-600 bg-brand-50 text-white" : "border-slate-200 hover:border-slate-300 hover:bg-white/5")}>
                <span className={cx("flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2", on ? "border-brand-600" : "border-slate-300")}>{on && <span className="h-2.5 w-2.5 rounded-full bg-neon" />}</span>{o.text}
              </button>
            );
          })}
        </div>
        <div className="mt-6 flex items-center justify-between">
          <Button variant="outline" onClick={() => setIndex((i) => i - 1)} disabled={index === 0}>Previous</Button>
          {index < questions.length - 1 ? <Button onClick={() => setIndex((i) => i + 1)}>Next</Button> : <Button variant="success" onClick={() => setConfirm(true)} loading={submitting}>Submit quiz</Button>}
        </div>
      </Card>
      <div className="mt-4 flex flex-wrap gap-2" aria-label="Question navigator">
        {questions.map((x, i) => <button key={x.id} onClick={() => setIndex(i)} aria-label={`Go to question ${i + 1}`} className={cx("h-9 w-9 rounded-lg border text-sm font-semibold", i === index ? "border-brand-500 bg-neon text-brand-ink shadow-glow-sm" : answers[x.id] ? "border-brand-500/40 bg-brand-50 text-brand-600" : "border-slate-200 bg-white/[0.03] text-slate-500")}>{i + 1}</button>)}
      </div>
      <ConfirmationModal open={confirm} title="Submit quiz?" message={answered < questions.length ? `You have ${questions.length - answered} unanswered question(s). Submit anyway?` : "Once submitted you can't change your answers."} confirmLabel="Submit" loading={submitting} onConfirm={() => submit(false)} onCancel={() => setConfirm(false)} />
    </div>
  );
}
