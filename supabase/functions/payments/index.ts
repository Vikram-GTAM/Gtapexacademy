// Payments Edge Function: the only place the Razorpay secret is used (moved from the retired FastAPI backend).
//
// The website calls supabase.functions.invoke("payments", { body: { action, ... } }):
//   config        -> { configured, key_id, mode }               (no sign-in needed; only the PUBLIC key id)
//   create-order  -> { order_id, amount, currency, key_id, course_title }   body: { course_id, learning_mode: "online" | "offline" }
//   verify        -> { status: "paid", course_id }               body: razorpay_order_id, razorpay_payment_id, razorpay_signature
//
// Secrets (set with `supabase secrets set`): RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET.
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { createOrder, verifyPaymentSignature } from "../_shared/razorpay.ts";

const KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
// Same error shape the website already understands: { error: { code, message } }
const fail = (status: number, code: string, message: string) => json({ error: { code, message } }, status);

// Errors raised by the database functions carry the app code in `hint` (see private.err).
const dbFail = (e: { hint?: string | null; message: string }) => {
  const code = e.hint ?? "error";
  const status = code === "not_found" ? 404 : code === "forbidden" ? 403 : code === "already_enrolled" ? 409 : 400;
  return fail(status, code, e.message);
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "Use POST");

  let body: Record<string, string>;
  try {
    body = await req.json();
  } catch {
    return fail(400, "bad_request", "Send a JSON body");
  }

  const configured = Boolean(KEY_ID && KEY_SECRET);
  if (body.action === "config") {
    return json({ configured, key_id: KEY_ID, mode: KEY_ID.startsWith("rzp_test_") ? "test" : KEY_ID ? "live" : "not configured" });
  }

  // Everything else needs a signed-in user.
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return fail(401, "unauthorized", "Authentication required");
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  if (!configured) return fail(503, "payments_not_configured", "Payments are not configured. Set RAZORPAY_KEY_ID/SECRET.");

  if (body.action === "create-order") {
    const prep = await admin.rpc("payment_prepare", { p_user_id: user.id, p_course_id: body.course_id, p_mode: body.learning_mode ?? "online" });
    if (prep.error) return dbFail(prep.error);
    const course = prep.data as { course_id: string; title: string; price: number; learning_mode: string };
    const amountPaise = Math.round(course.price * 100);
    let order: { id: string };
    try {
      order = await createOrder(KEY_ID, KEY_SECRET, amountPaise, `c${course.course_id.slice(0, 8)}u${user.id.slice(0, 8)}`,
        { course_id: course.course_id, learning_mode: course.learning_mode, user_id: user.id });
    } catch {
      return fail(502, "payment_failed", "Could not start the payment. Please try again.");
    }
    const rec = await admin.rpc("payment_record_order", {
      p_user_id: user.id, p_course_id: course.course_id, p_amount: course.price, p_order_id: order.id, p_mode: course.learning_mode,
    });
    if (rec.error) return dbFail(rec.error);
    return json({ order_id: order.id, amount: amountPaise, currency: "INR", key_id: KEY_ID, course_title: course.title });
  }

  if (body.action === "verify") {
    const { razorpay_order_id: orderId, razorpay_payment_id: paymentId, razorpay_signature: signature } = body;
    if (!orderId || !paymentId || !signature) return fail(400, "bad_request", "Missing payment details");
    if (!(await verifyPaymentSignature(orderId, paymentId, signature, KEY_SECRET))) {
      await admin.rpc("payment_mark_failed", { p_order_id: orderId, p_user_id: user.id });
      return fail(400, "payment_failed", "Payment verification failed. If money was deducted, contact support.");
    }
    const paid = await admin.rpc("payment_mark_paid", {
      p_order_id: orderId, p_payment_id: paymentId, p_signature: signature, p_user_id: user.id,
    });
    if (paid.error) return dbFail(paid.error);
    return json(paid.data);
  }

  return fail(400, "bad_request", "Unknown action");
});
