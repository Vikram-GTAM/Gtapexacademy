import { Award, Download } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { Button, Card, EmptyState, ErrorState, PageHeader, Skeleton } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { studentApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import { formatDate } from "../../utils/format";

export default function Certificates() {
  const toast = useToast();
  const certs = useAsync(studentApi.certificates);
  const courses = useAsync(studentApi.courses);
  const [busy, setBusy] = useState<string | null>(null);

  const issued = new Set((certs.data ?? []).map((c) => c.course_id));
  const eligible = (courses.data ?? []).filter((c) => c.is_completed && !issued.has(c.course.id));

  async function generate(courseId: string) {
    setBusy(courseId);
    try { await studentApi.generateCertificate(courseId); toast.success("Certificate generated"); certs.reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setBusy(null); }
  }
  async function download(id: string, code: string) {
    setBusy(id);
    try { await studentApi.downloadCertificate(id, code); } catch (e) { toast.error(getErrorMessage(e)); } finally { setBusy(null); }
  }

  const error = certs.error || courses.error;
  return (
    <div>
      <PageHeader title="Certificates" subtitle="Complete a course to earn a verifiable certificate." />
      {error ? <ErrorState message={error} onRetry={() => { certs.reloadWithSpinner(); courses.reloadWithSpinner(); }} /> : certs.loading || courses.loading ? (
        <div className="grid gap-4 md:grid-cols-2"><Skeleton className="h-36" /><Skeleton className="h-36" /></div>
      ) : (
        <div className="space-y-8">
          {eligible.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Ready to claim</h2>
              <div className="grid gap-4 md:grid-cols-2">
                {eligible.map((c) => (
                  <Card key={c.course.id} className="flex items-center justify-between gap-4 border-emerald-200 bg-emerald-50/40">
                    <div><p className="font-bold text-slate-900">{c.course.title}</p><p className="text-sm text-slate-500">Completed {c.completed_at ? formatDate(c.completed_at) : ""}</p></div>
                    <Button onClick={() => generate(c.course.id)} loading={busy === c.course.id} icon={<Award className="h-4 w-4" />}>Generate</Button>
                  </Card>
                ))}
              </div>
            </section>
          )}
          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Your certificates</h2>
            {(certs.data ?? []).length === 0 ? (
              <EmptyState icon={<Award className="h-7 w-7" />} title="No certificates yet" message="Finish all lessons in a course to unlock your certificate." action={<Link to="/app/courses" className="text-sm font-semibold text-brand-600 hover:underline">Go to my courses</Link>} />
            ) : (
              <div className="grid gap-4 md:grid-cols-2">
                {certs.data!.map((c) => (
                  <Card key={c.id}>
                    <div className="flex items-start gap-3">
                      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-amber-50 text-amber-600"><Award className="h-6 w-6" /></div>
                      <div className="min-w-0 flex-1">
                        <p className="font-bold text-slate-900">{c.course_title}</p>
                        <p className="text-sm text-slate-500">Issued {formatDate(c.issued_at)}</p>
                        <p className="mt-1 truncate font-mono text-xs text-slate-400">ID: {c.certificate_code}</p>
                      </div>
                    </div>
                    <Button className="mt-4 w-full" variant="outline" icon={<Download className="h-4 w-4" />} loading={busy === c.id} onClick={() => download(c.id, c.certificate_code)}>Download PDF</Button>
                  </Card>
                ))}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
