import { Component, type ErrorInfo, type ReactNode } from "react";

const RELOADED_KEY = "gt-reloaded-for-update";

// After a new version goes live, a browser still on the old page asks for files that no longer exist.
const isStaleFiles = (error: unknown) => /dynamically imported module|Importing a module script failed|Loading chunk|Failed to fetch dynamically/i.test(String(error));

function reloadOnceForUpdate(): boolean {
  try {
    if (sessionStorage.getItem(RELOADED_KEY)) return false;
    sessionStorage.setItem(RELOADED_KEY, "1");
  } catch {
    return false;
  }
  window.location.reload();
  return true;
}

/** Shows a friendly message instead of a blank page if something on a page breaks. Changing page clears it. */
export class ErrorBoundary extends Component<{ children: ReactNode; resetKey: string }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error("Page error:", error, info.componentStack);
    if (isStaleFiles(error)) reloadOnceForUpdate();
  }

  componentDidUpdate(previous: { resetKey: string }) {
    if (this.state.failed && previous.resetKey !== this.props.resetKey) this.setState({ failed: false });
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div role="alert" className="mx-auto flex min-h-[60vh] max-w-lg flex-col items-center justify-center px-4 text-center">
        <h1 className="text-2xl font-extrabold text-slate-900">Something went wrong</h1>
        <p className="mt-3 text-slate-500">This page couldn't be shown. Your account and payments are safe. Please reload and try again.</p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <button type="button" onClick={() => window.location.reload()} className="neon-btn rounded-xl px-5 py-2.5 font-bold">Reload page</button>
          <a href="/" className="rounded-xl border border-slate-200 px-5 py-2.5 font-semibold text-slate-700 hover:text-slate-900">Go to home</a>
        </div>
      </div>
    );
  }
}
