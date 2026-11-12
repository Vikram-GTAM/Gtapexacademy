import { Compass } from "lucide-react";
import { LinkButton } from "../../components/ui";

export default function NotFound() {
  return (
    <div className="mx-auto flex min-h-[60vh] max-w-md flex-col items-center justify-center px-4 text-center">
      <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-brand-50 text-brand-600"><Compass className="h-8 w-8" /></div>
      <h1 className="text-3xl font-extrabold text-slate-900">Page not found</h1>
      <p className="mt-2 text-slate-500">The page you're looking for doesn't exist or has moved.</p>
      <LinkButton to="/" className="mt-6">Back to home</LinkButton>
    </div>
  );
}
