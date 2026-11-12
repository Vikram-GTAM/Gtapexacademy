// Razorpay webhook: Razorpay calls this directly when a payment is captured, so a student is still enrolled
// if they close the browser before the website's own "verify" step runs. Safe to receive more than once.
//
// In the Razorpay dashboard add a webhook to https://<project>.supabase.co/functions/v1/razorpay-webhook
// for the events payment.captured and order.paid, with a secret, and store that secret as RAZORPAY_WEBHOOK_SECRET.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { verifyWebhookSignature } from "../_shared/razorpay.ts";

const WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  if (!WEBHOOK_SECRET) return new Response("Webhook secret not configured", { status: 503 });

  const raw = await req.text();
  const signature = req.headers.get("X-Razorpay-Signature") ?? "";
  if (!(await verifyWebhookSignature(raw, signature, WEBHOOK_SECRET))) return new Response("Bad signature", { status: 401 });

  const event = JSON.parse(raw);
  if (event.event !== "payment.captured" && event.event !== "order.paid") return new Response("ignored");

  const payment = event.payload?.payment?.entity;
  if (!payment?.order_id || !payment?.id) return new Response("ignored");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { error } = await admin.rpc("payment_mark_paid", { p_order_id: payment.order_id, p_payment_id: payment.id });
  // An order we never created (e.g. from another app on the same Razorpay account) is acknowledged and skipped.
  if (error && error.hint !== "not_found") return new Response("Database error", { status: 500 });
  return new Response("ok");
});
