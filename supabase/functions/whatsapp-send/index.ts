// BillCat → WhatsApp e-bill relay.
//
// Shops never hold WhatsApp credentials. A token shipped inside the desktop
// binary can be pulled out of it and used to send from BillCat's number, so the
// token lives here as a secret and the app only ever asks this function to send
// one specific, pre-approved template. Same rule as razorpay-webhook: the
// client is never trusted with anything that costs money.
//
// Deploy WITH jwt verification (no --no-verify-jwt) so only a signed-in shop
// can reach it:
//   supabase functions deploy whatsapp-send
// and set the secrets:
//   supabase secrets set WA_PHONE_NUMBER_ID=... WA_ACCESS_TOKEN=... SERVICE_ROLE_KEY=...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WA_PHONE_NUMBER_ID = Deno.env.get("WA_PHONE_NUMBER_ID") ?? "";
const WA_ACCESS_TOKEN = Deno.env.get("WA_ACCESS_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const GRAPH = "https://graph.facebook.com/v19.0";

/// The template approved on BillCat's WhatsApp Business Account. Only this one
/// is ever sent — the app cannot ask for arbitrary message content.
const TEMPLATE_NAME = "invoice_receipts";
const TEMPLATE_LANGUAGE = "en";

/// Bills one shop may send per day. A runaway loop or an abusive shop would
/// otherwise bill BillCat for every message and drag the number's quality
/// rating down for everyone sharing it.
const DAILY_CAP = Number(Deno.env.get("WA_DAILY_CAP") ?? "100");

/// Largest PDF accepted, before base64. Meta's own document ceiling is 100 MB,
/// but a receipt is tens of KB — anything large is a bug or an attack.
const MAX_PDF_BYTES = 2 * 1024 * 1024;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// Meta rejects template parameters that are empty or carry newlines, tabs or
/// runs of 4+ spaces (error 132018), so every value is flattened first.
function param(value: unknown, fallback: string): string {
  const cleaned = String(value ?? "").replace(/\s+/g, " ").trim();
  return cleaned.length === 0 ? fallback : cleaned;
}

/// Digits only, no leading zero. A bare 10-digit number has no country code, so
/// the shop's configured dial code is prepended rather than guessed.
function normalizePhone(raw: string, dialCode: string): string {
  let p = String(raw ?? "").replace(/\D/g, "");
  if (p.startsWith("0")) p = p.replace(/^0+/, "");
  if (p.length === 10) p = `${String(dialCode ?? "91").replace(/\D/g, "")}${p}`;
  return p;
}

/// Pulls the human-readable reason out of a Graph API error body, so a failure
/// tells the shopkeeper what to fix instead of just "send failed".
function describe(status: number, body: string): string {
  try {
    const err = JSON.parse(body)?.error;
    if (err) {
      const code = err.code ?? status;
      const detail = err.error_data?.details;
      return detail ? `[${code}] ${detail}` : `[${code}] ${err.message ?? ""}`;
    }
  } catch { /* fall through to the raw body */ }
  return `HTTP ${status}: ${body.slice(0, 200)}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { ok: false, error: "Method not allowed" });

  // Read the whole body BEFORE any check that can return early. The desktop
  // app uploads the bill (~450 KB) over HTTP/1.1; answering before the body is
  // consumed leaves the upload hanging, and the app only ever sees
  // "Connection reset" instead of the real error below.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { ok: false, error: "Bad request body" });
  }

  if (!WA_PHONE_NUMBER_ID || !WA_ACCESS_TOKEN) {
    console.error("whatsapp-send: WA_PHONE_NUMBER_ID / WA_ACCESS_TOKEN secret missing");
    return json(500, { ok: false, error: "WhatsApp relay is not configured" });
  }

  // Identify the shop. Deployed with jwt verification, Supabase has already
  // rejected a forged token; this resolves it to a user id for the daily cap.
  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!jwt) return json(401, { ok: false, error: "Not signed in" });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  const userId = userData?.user?.id;
  if (userErr || !userId) {
    console.error(
      `whatsapp-send: getUser failed — ${userErr?.name ?? ""} ${userErr?.status ?? ""} ${userErr?.message ?? "no user id"}` +
        ` (SUPABASE_URL set: ${!!SUPABASE_URL}, SERVICE_ROLE_KEY set: ${!!SERVICE_ROLE_KEY})`,
    );
    return json(401, { ok: false, error: "Not signed in" });
  }

  const phone = normalizePhone(String(body.toPhone ?? ""), String(body.dialCode ?? "91"));
  if (phone.length < 10) return json(400, { ok: false, error: "Invalid phone number" });

  const pdfBase64 = String(body.pdfBase64 ?? "");
  if (!pdfBase64) return json(400, { ok: false, error: "Missing bill PDF" });

  let pdf: Uint8Array;
  try {
    pdf = Uint8Array.from(atob(pdfBase64), (c) => c.charCodeAt(0));
  } catch {
    return json(400, { ok: false, error: "Bill PDF is not valid base64" });
  }
  if (pdf.byteLength === 0 || pdf.byteLength > MAX_PDF_BYTES) {
    return json(400, { ok: false, error: "Bill PDF is empty or too large" });
  }

  const invoiceNo = param(body.invoiceNo, "-");
  const docType = param(body.docType, "Invoice");

  // Daily cap. The log table is optional: without it the relay still sends, so
  // deploying the function never depends on a migration having been run.
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countErr } = await admin
    .from("whatsapp_send_log")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("sent_at", since);
  if (!countErr && (count ?? 0) >= DAILY_CAP) {
    return json(429, {
      ok: false,
      error: `Daily WhatsApp limit reached (${DAILY_CAP} bills). Try again tomorrow.`,
    });
  }

  // 1. Upload the PDF as a WhatsApp media object.
  const form = new FormData();
  form.append("messaging_product", "whatsapp");
  form.append("type", "application/pdf");
  form.append(
    "file",
    new Blob([pdf], { type: "application/pdf" }),
    `${docType}-${invoiceNo}.pdf`,
  );

  const upload = await fetch(`${GRAPH}/${WA_PHONE_NUMBER_ID}/media`, {
    method: "POST",
    headers: { Authorization: `Bearer ${WA_ACCESS_TOKEN}` },
    body: form,
  });
  const uploadBody = await upload.text();
  if (!upload.ok) {
    return json(502, { ok: false, error: `PDF upload — ${describe(upload.status, uploadBody)}` });
  }
  const mediaId = JSON.parse(uploadBody)?.id;
  if (!mediaId) return json(502, { ok: false, error: "PDF upload — no media id returned" });

  // 2. Send the approved template. The PDF is the header; the six body values
  // follow {{1}}..{{6}} in the approved text exactly.
  const send = await fetch(`${GRAPH}/${WA_PHONE_NUMBER_ID}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${WA_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: phone,
      type: "template",
      template: {
        name: TEMPLATE_NAME,
        language: { code: TEMPLATE_LANGUAGE },
        components: [
          {
            type: "header",
            parameters: [
              {
                type: "document",
                document: { id: mediaId, filename: `${docType}-${invoiceNo}.pdf` },
              },
            ],
          },
          {
            type: "body",
            parameters: [
              { type: "text", text: param(body.customerName, "Valued Customer") },
              { type: "text", text: param(body.storeName, "BillCat") },
              { type: "text", text: docType },
              { type: "text", text: invoiceNo },
              { type: "text", text: param(body.amount, "-") },
              { type: "text", text: param(body.date, "-") },
            ],
          },
        ],
      },
    }),
  });
  const sendBody = await send.text();
  if (!send.ok) return json(502, { ok: false, error: describe(send.status, sendBody) });

  // Record the send for the cap. A failure here must not fail a bill that has
  // already gone out, so the error is swallowed deliberately.
  await admin.from("whatsapp_send_log").insert({ user_id: userId }).then(
    () => {},
    () => {},
  );

  return json(200, { ok: true });
});
