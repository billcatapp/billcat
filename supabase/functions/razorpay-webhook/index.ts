// Razorpay → BillCat licence webhook.
//
// Razorpay calls this when a payment succeeds. It is the ONLY thing that grants
// paid time: the app is never trusted to say it paid, because anyone can edit a
// client. Deploy with:
//   supabase functions deploy razorpay-webhook --no-verify-jwt
// and set the secrets:
//   supabase secrets set RAZORPAY_WEBHOOK_SECRET=... SERVICE_ROLE_KEY=...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

/** Constant-time compare so a signature can't be guessed by timing the reply. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  // Read the RAW body — the signature is over the exact bytes Razorpay sent, so
  // parsing first and re-serialising would change it and never match.
  const raw = await req.text();
  const given = req.headers.get("x-razorpay-signature") ?? "";
  const expected = await hmacHex(WEBHOOK_SECRET, raw);
  if (!WEBHOOK_SECRET || !safeEqual(given, expected)) {
    return new Response("Bad signature", { status: 401 });
  }

  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  // Only a captured payment grants time. 'authorized' can still fail later.
  if (event.event !== "payment.captured") {
    return new Response("ignored", { status: 200 });
  }

  const payment = event?.payload?.payment?.entity;
  const userId = payment?.notes?.user_id;
  if (!userId) {
    // Nothing to credit — accept it so Razorpay stops retrying, but say so.
    return new Response("no user_id in payment notes", { status: 200 });
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Extend from whichever is later: today, or the existing expiry. Renewing
  // early must add a year to what's left, not throw the remainder away.
  const { data: existing } = await db
    .from("licences")
    .select("paid_until")
    .eq("user_id", userId)
    .maybeSingle();

  const now = new Date();
  const current = existing?.paid_until ? new Date(existing.paid_until) : now;
  const base = current > now ? current : now;
  const paidUntil = new Date(base);
  paidUntil.setFullYear(paidUntil.getFullYear() + 1);

  const { error } = await db.from("licences").upsert({
    user_id: userId,
    status: "active",
    paid_until: paidUntil.toISOString(),
    last_payment_id: payment.id,
    updated_at: now.toISOString(),
  });

  if (error) return new Response(`db error: ${error.message}`, { status: 500 });
  return new Response(JSON.stringify({ ok: true, paid_until: paidUntil }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
