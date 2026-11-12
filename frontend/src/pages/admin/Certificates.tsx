import { Award } from "lucide-react";
import { EmptyState, ErrorState, PageHeader, Table } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import type { AdminCertificate } from "../../types";
import { formatDate } from "../../utils/format";

export default function AdminCertificates() {
  const { data, loading, error, reloadWithSpinner } = useAsync(adminApi.certificates);
  return (
    <div>
      <PageHeader title="Certificates" subtitle="Certificates issued to students." />
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <Table<AdminCertificate> loading={loading} rows={data ?? []} rowKey={(c) => c.id}
          empty={<EmptyState icon={<Award className="h-7 w-7" />} title="No certificates issued" message="Certificates appear when students complete a course and generate one." />}
          columns={[
            { key: "c", header: "Certificate ID", render: (c) => <span className="font-mono text-xs">{c.certificate_code}</span> },
            { key: "s", header: "Student", render: (c) => <div><p className="font-semibold text-slate-900">{c.student_name}</p><p className="text-xs text-slate-500">{c.student_email}</p></div> },
            { key: "t", header: "Course", render: (c) => c.course_title, hideOnMobile: true },
            { key: "d", header: "Issued", render: (c) => formatDate(c.issued_at), hideOnMobile: true },
          ]} />
      )}
    </div>
  );
}
