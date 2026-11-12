import { createClient } from "@supabase/supabase-js";

// Both values are public by design (they ship in every visitor's browser). Security comes from the database
// functions and storage rules in supabase/migrations, never from hiding these.
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const supabaseConfigured = Boolean(url && anonKey);
if (!supabaseConfigured) console.error("Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in frontend/.env (see .env.example).");

export const supabase = createClient(url || "http://localhost:54321", anonKey || "missing-anon-key", {
  // Password-reset links are handled by the reset page itself (token in ?token=), not by parsing the URL here.
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
});
