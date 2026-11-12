// Sends a WhatsApp alert when Krish saves a new enquiry. A Supabase Database Webhook on contact_messages calls this
// after each insert, so an alert problem can never stop an enquiry being saved.
//
// Secrets (set with `supabase secrets set`):
//   ENQUIRY_ALERT_SECRET      a long random value, also sent by the webhook in the x-webhook-secret header
//   WHATSAPP_TOKEN            permanent access token from Meta
//   WHATSAPP_PHONE_NUMBER_ID  the ID of the number that sends the alerts
//   WHATSAPP_ALERT_TO         who receives them, digits with country code; separate several with commas
// Optional: WHATSAPP_TEMPLATE (default new_enquiry), WHATSAPP_TEMPLATE_LANGUAGE (default en),
//           WHATSAPP_API_VERSION (default v23.0), ALERT_HOURLY_LIMIT (default 30).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const env = (name: string, fallback = "") => Deno.env.get(name) ?? fallback;
const KRISH_SUBJECT = "Krish chat: ";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function sameSecret(a: string, b: string): boolean {
  if (!a || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// WhatsApp rejects template values that are empty or contain line breaks, tabs or long runs of spaces.
const clean = (value: unknown, fallback: string, max: number) => {
  const text = String(value ?? "").replace(/[\r\n\t]+/g, " ").replace(/ {2,}/g, " ").trim();
  return (text || fallback).slice(0, max);
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!sameSecret(req.headers.get("x-webhook-secret") ?? "", env("ENQUIRY_ALERT_SECRET"))) return json({ error: "Not allowed" }, 401);

  let payload: { type?: string; table?: string; record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Send a JSON body" }, 400);
  }
  const record = payload.record;
  if (payload.type !== "INSERT" || payload.table !== "contact_messages" || !record) return json({ skipped: "not a new message" });
  const subject = String(record.subject ?? "");
  if (!subject.startsWith(KRISH_SUBJECT)) return json({ skipped: "not from Krish" });

  const token = env("WHATSAPP_TOKEN");
  const phoneId = env("WHATSAPP_PHONE_NUMBER_ID");
  const recipients = env("WHATSAPP_ALERT_TO").split(",").map((n) => n.replace(/\D/g, "")).filter(Boolean);
  if (!token || !phoneId || !recipients.length) return json({ error: "WhatsApp is not configured" }, 503);

  // Each alert costs money, so a flood of fake enquiries must not become a flood of paid messages. They are still saved.
  const limit = Number(env("ALERT_HOURLY_LIMIT", "30")) || 30;
  const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });
  const { count, error } = await admin.from("contact_messages").select("id", { count: "exact", head: true })
    .like("subject", `${KRISH_SUBJECT}%`).gte("created_at", new Date(Date.now() - 3600_000).toISOString());
  if (!error && (count ?? 0) > limit) {
    console.warn(`Alert skipped: over ${limit} enquiries in the last hour`);
    return json({ skipped: "hourly limit reached" });
  }

  const parameters = [
    clean(record.name, "Not given", 120),
    clean(record.phone ?? record.email, "Not given", 255),
    clean(subject.slice(KRISH_SUBJECT.length), "Not sure yet", 80),
    clean(record.message, "None", 500),
  ].map((text) => ({ type: "text", text }));

  const url = `https://graph.facebook.com/${env("WHATSAPP_API_VERSION", "v23.0")}/${phoneId}/messages`;
  const failures: unknown[] = [];
  for (const to of recipients) {
    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to,
        type: "template",
        template: { name: env("WHATSAPP_TEMPLATE", "new_enquiry"), language: { code: env("WHATSAPP_TEMPLATE_LANGUAGE", "en") }, components: [{ type: "body", parameters }] },
      }),
    });
    if (!res.ok) {
      // Meta's error says what's wrong (expired token, template not approved); it holds no visitor details.
      const detail = await res.text();
      console.error(`WhatsApp alert failed with status ${res.status}: ${detail.slice(0, 500)}`);
      failures.push(res.status);
    }
  }
  return failures.length ? json({ error: "WhatsApp alert failed", failures }, 502) : json({ sent: recipients.length });
});
