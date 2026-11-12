// Razorpay helpers shared by the payments and razorpay-webhook Edge Functions.
// Uses only Web Crypto and fetch, so it runs on Supabase Edge (Deno) and in Node 18+ for tests.

const enc = new TextEncoder();

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(message)));
  return Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
}

// Constant-time comparison so the check does not leak how many characters matched.
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Checkout signature: HMAC_SHA256(order_id + "|" + payment_id, key_secret). */
export async function verifyPaymentSignature(orderId: string, paymentId: string, signature: string, keySecret: string): Promise<boolean> {
  return safeEqual(await hmacSha256Hex(keySecret, `${orderId}|${paymentId}`), signature);
}

/** Webhook signature: HMAC_SHA256(raw request body, webhook secret). */
export async function verifyWebhookSignature(rawBody: string, signature: string, webhookSecret: string): Promise<boolean> {
  return safeEqual(await hmacSha256Hex(webhookSecret, rawBody), signature);
}

export async function createOrder(
  keyId: string, keySecret: string, amountPaise: number, receipt: string, notes: Record<string, string>,
): Promise<{ id: string }> {
  const res = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}` },
    body: JSON.stringify({ amount: amountPaise, currency: "INR", receipt, notes }),
  });
  if (!res.ok) throw new Error(`Razorpay order failed (${res.status})`);
  return await res.json();
}
