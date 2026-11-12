import { Search, SearchX, SlidersHorizontal } from "lucide-react";
import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { CourseCard } from "../../components/CourseCard";
import { Button, CardSkeleton, EmptyState, ErrorState, Input, Pagination, Select } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { useDebounce } from "../../hooks/useDebounce";
import { courseApi } from "../../services";

export default function Courses() {
  const [params, setParams] = useSearchParams();
  const [search, setSearch] = useState(params.get("search") ?? "");
  const debounced = useDebounce(search);
  const category = params.get("category") ?? "";
  const sort = params.get("sort") ?? "newest";
  const page = Number(params.get("page") ?? 1);
  const [showFilters, setShowFilters] = useState(false);

  const set = (k: string, v: string) => setParams((p) => { const n = new URLSearchParams(p); v ? n.set(k, v) : n.delete(k); if (k !== "page") n.delete("page"); return n; }, { replace: true });
  useEffect(() => { if ((params.get("search") ?? "") !== debounced) set("search", debounced); /* eslint-disable-next-line */ }, [debounced]);

  const cats = useAsync(() => courseApi.categories());
  const { data, loading, error, reloadWithSpinner } = useAsync(
    () => courseApi.list({ search: params.get("search") || undefined, category: category || undefined, sort, page, page_size: 9 }),
    [params.toString()],
  );
  const clear = () => { setSearch(""); setParams({}, { replace: true }); };
  const hasFilters = !!(debounced || category);

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
      <div className="mb-8"><h1 className="text-3xl font-extrabold tracking-tight text-slate-900">Explore courses</h1><p className="mt-2 text-slate-500">Find the course that fits your goals.</p></div>
      <div className="mb-6 flex flex-col gap-3 sm:flex-row">
        <div className="flex-1"><Input aria-label="Search courses" placeholder="Search by title, topic or keyword…" value={search} onChange={(e) => setSearch(e.target.value)} icon={<Search className="h-4 w-4" />} /></div>
        <Button variant="outline" className="h-11 sm:hidden" icon={<SlidersHorizontal className="h-4 w-4" />} onClick={() => setShowFilters((s) => !s)}>Filters</Button>
      </div>
      <div className={`mb-8 grid gap-4 rounded-2xl glass p-4 shadow-card sm:grid-cols-2 lg:grid-cols-3 ${showFilters ? "" : "hidden sm:grid"}`}>
        <Select label="Category" value={category} onChange={(e) => set("category", e.target.value)}><option value="">All categories</option>{(cats.data ?? []).map((c) => <option key={c.name} value={c.name}>{c.name} ({c.count})</option>)}</Select>
        <Select label="Sort by" value={sort} onChange={(e) => set("sort", e.target.value)}><option value="newest">Newest</option><option value="popular">Most popular</option><option value="title">Title (A–Z)</option></Select>
        <div className="flex items-end">{hasFilters && <Button variant="ghost" onClick={clear} className="h-11">Clear filters</Button>}</div>
      </div>

      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <>
          {!loading && data && <p className="mb-4 text-sm text-slate-500">{data.total} course{data.total === 1 ? "" : "s"} found</p>}
          {!loading && data && data.items.length === 0 ? (
            <EmptyState icon={<SearchX className="h-7 w-7" />} title="No courses match your filters" message="Try a different search term or clear the filters." action={<Button onClick={clear}>Clear filters</Button>} />
          ) : (
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {loading || !data ? Array.from({ length: 6 }).map((_, i) => <CardSkeleton key={i} />) : data.items.map((c) => <CourseCard key={c.id} course={c} />)}
            </div>
          )}
          {data && <Pagination page={data.page} pages={data.pages} onChange={(p) => { set("page", String(p)); window.scrollTo({ top: 0, behavior: "smooth" }); }} />}
        </>
      )}
    </div>
  );
}
