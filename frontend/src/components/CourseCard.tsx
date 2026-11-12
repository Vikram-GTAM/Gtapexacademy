import { BookOpen, CalendarDays, Clock, GraduationCap, Users } from "lucide-react";
import { Link } from "react-router-dom";
import { assetUrl } from "../services/api";
import type { CourseCard as C } from "../types";
import { formatDuration } from "../utils/format";
import { CourseThumb } from "./Brand";

export function CourseCard({ course }: { course: C }) {
  return (
    <Link to={`/courses/${course.id}`} className="glass glass-hover group flex flex-col overflow-hidden rounded-2xl transition duration-200 hover:-translate-y-1">
      <CourseThumb title={course.title} src={assetUrl(course.thumbnail_url)} category={course.category} className="h-40 w-full transition duration-300 group-hover:scale-[1.02]" />
      <div className="flex flex-1 flex-col p-4">
        <span className="mb-2 text-xs font-medium text-slate-400">{course.category}</span>
        <h3 className="line-clamp-2 text-base font-bold leading-snug text-slate-900 group-hover:text-brand-600">{course.title}</h3>
        <p className="mt-1.5 line-clamp-2 flex-1 text-sm text-slate-500">{course.short_description}</p>
        <div className="mt-3 flex items-center gap-4 text-xs text-slate-500">
          {course.offline_only
            ? <span className="flex items-center gap-1"><GraduationCap className="h-3.5 w-3.5" />Classroom only</span>
            : course.lesson_count > 0 && <span className="flex items-center gap-1"><BookOpen className="h-3.5 w-3.5" />{course.lesson_count} lessons</span>}
          {course.duration_months
            ? <span className="flex items-center gap-1"><CalendarDays className="h-3.5 w-3.5" />{course.duration_months} months</span>
            : !course.offline_only && course.duration_seconds > 0 && <span className="flex items-center gap-1"><Clock className="h-3.5 w-3.5" />{formatDuration(course.duration_seconds)}</span>}
          {course.enrolled_count > 0 && <span className="flex items-center gap-1"><Users className="h-3.5 w-3.5" />{course.enrolled_count}</span>}
        </div>
        <div className="mt-4 flex items-center justify-end border-t border-slate-100 pt-3">
          <span className="text-sm font-semibold text-brand-600 group-hover:underline">View course →</span>
        </div>
      </div>
    </Link>
  );
}
