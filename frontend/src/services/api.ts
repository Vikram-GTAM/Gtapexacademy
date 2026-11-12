/** Errors from Supabase (database functions, Auth, Storage, Edge Functions) normalised to { code, message }. */
export class ApiError extends Error {
  constructor(message: string, public code?: string) {
    super(message);
    this.name = "ApiError";
  }
}

const OFFLINE = "Can't reach the server. Check your internet connection and try again.";
const SESSION_CODES = new Set(["unauthorized", "invalid_token"]);

interface SupabaseLikeError { message?: string; hint?: string | null; code?: string | number; status?: number }

/** Database functions put the app error code in `hint` (see private.err in supabase/migrations). */
export function toApiError(err: unknown): ApiError {
  if (err instanceof ApiError) return err;
  const e = (err ?? {}) as SupabaseLikeError;
  const msg = e.message ?? "";
  if (/failed to fetch|networkerror|fetch failed|load failed/i.test(msg)) return new ApiError(OFFLINE, "network");
  // 42501 = the database refused the call outright: the session has expired or this account cannot use it.
  if (e.code === "42501" || e.code === "PGRST301") return new ApiError("Your session has expired. Please log in again.", "unauthorized");
  return new ApiError(msg || "Something went wrong. Please try again.", e.hint || (typeof e.code === "string" ? e.code : undefined));
}

/** Throws the normalised error, and signs the user out in the UI when the session is no longer valid. */
export function raise(err: unknown): never {
  const e = toApiError(err);
  if (e.code && SESSION_CODES.has(e.code)) window.dispatchEvent(new Event("lms:unauthorized"));
  throw e;
}

export function getErrorMessage(err: unknown, fallback = "Something went wrong. Please try again."): string {
  if (err instanceof ApiError) return err.message || fallback;
  if (err instanceof TypeError && /fetch/i.test(err.message)) return OFFLINE;
  return fallback;
}
export function getErrorCode(err: unknown): string | undefined {
  return err instanceof ApiError ? err.code : undefined;
}

/** Allows web links and paths on this site only, so a stored javascript: link can never run when clicked. */
export function safeUrl(url?: string | null): string {
  const value = (url ?? "").trim();
  return /^(https?:\/\/|\/(?!\/))/i.test(value) ? value : "";
}

/** True for a lesson video stored in our own Supabase Storage, rather than an outside link. */
export const isUploadedVideo = (url?: string | null): boolean => /\/storage\/v1\/object\/public\/course-files\//.test(url ?? "");

/** Uploaded files are stored as full public URLs in Supabase Storage. */
export const assetUrl = safeUrl;
