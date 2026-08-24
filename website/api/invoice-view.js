const SUPABASE_URL = 'https://xawpxbhglzhaibmcpwho.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhhd3B4YmhnbHpoYWlibWNwd2hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMTA4MTMsImV4cCI6MjA5MjY4NjgxM30.rin8K6vTWF_L-gCJKw1dyf0Vm2RoDvxcMSKSnClWy9E';

// Transactions are locked to their owner by RLS (auth.uid() = user_id), so an
// anonymous read returns nothing and every shared bill link 404s. This runs
// server-side on Vercel, so the service key can do the one lookup the customer
// asked for. It is read from the environment and never reaches the browser —
// do NOT move this into any client-side file.
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';
// Falls back to anon so a missing env var degrades to today's behaviour
// (a 404) rather than crashing the page.
const READ_KEY = SUPABASE_SERVICE_KEY || SUPABASE_ANON_KEY;

async function supabaseGet(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      'apikey': READ_KEY,
      'Authorization': `Bearer ${READ_KEY}`,
    },
  });
  if (!res.ok) return null;
  return res.json();
}

async function supabasePost(path, body) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) return null;
  return res.json();
}

function fmt(n, sym = '₹') {
  return `${sym}${Number(n).toFixed(2)}`;
}

function escHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderHtml({ tx, settings, shortUid, branch }) {
  const sym = settings.currency_symbol || '₹';
  const storeName = escHtml(settings.store_name || 'BillCat Store');
  const storeAddress = escHtml(settings.store_address || '');
  const storePhone = escHtml(settings.store_phone || '');
  const storeEmail = escHtml(settings.store_email || '');
  const gstin = escHtml(settings.store_gstin || '');
  const upiId = escHtml(settings.store_upi_id || '');
  const taxLabel = escHtml(settings.tax_label || 'Tax');
  const logoUrl = settings.logo_url || '';

  const customerName = escHtml(tx.customer_name || '');
  const customerPhone = escHtml(tx.customer_phone || '');
  const invoiceNo = escHtml(tx.id.replace(/-/g, '').substring(0, 6).toUpperCase());
  const date = new Date(tx.created_at);
  const dateStr = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
  const timeStr = date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });

  const items = Array.isArray(tx.items) ? tx.items : JSON.parse(tx.items || '[]');

  const itemRows = items.map(item => `
    <tr>
      <td>${escHtml(item.productName || item.name || '')}</td>
      <td class="center">${item.quantity}</td>
      <td class="right">${fmt(item.price, sym)}</td>
      <td class="right">${fmt((item.price * item.quantity), sym)}</td>
    </tr>`).join('');

  const discount = Number(tx.discount_amount) || 0;
  const tax = Number(tx.tax_amount) || 0;
  const subtotal = Number(tx.subtotal) || 0;
  const total = Number(tx.total) || 0;

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Invoice #${invoiceNo} — ${storeName}</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',sans-serif;background:#f0f4f8;color:#1a1a2e;min-height:100vh;padding:24px 16px}
.card{background:#fff;max-width:540px;margin:0 auto;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)}
.header{background:#006e25;padding:28px 28px 24px;color:#fff}
.header-top{display:flex;align-items:center;gap:14px;margin-bottom:16px}
.logo-img{width:52px;height:52px;border-radius:10px;object-fit:cover;background:#fff}
.logo-placeholder{width:52px;height:52px;border-radius:10px;background:rgba(255,255,255,.2);display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:800;color:#fff}
.store-name{font-size:20px;font-weight:700;color:#fff}
.store-sub{font-size:12px;color:rgba(255,255,255,.75);margin-top:2px}
.invoice-badge{background:rgba(255,255,255,.18);border-radius:8px;padding:10px 16px;display:flex;justify-content:space-between;align-items:center}
.invoice-label{font-size:11px;font-weight:600;color:rgba(255,255,255,.7);text-transform:uppercase;letter-spacing:.6px}
.invoice-no{font-size:17px;font-weight:700;color:#fff}
.invoice-date{font-size:12px;color:rgba(255,255,255,.8);text-align:right}
.body{padding:24px 28px}
.section-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#8a9bb0;margin-bottom:8px}
.customer-box{background:#f7fafc;border-radius:10px;padding:12px 16px;margin-bottom:20px}
.customer-name{font-size:15px;font-weight:600;color:#1a1a2e}
.customer-phone{font-size:12px;color:#8a9bb0;margin-top:2px}
table{width:100%;border-collapse:collapse;margin-bottom:4px}
thead tr{border-bottom:1px solid #e8edf2}
thead th{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.6px;color:#8a9bb0;padding:6px 4px;text-align:left}
thead th.center{text-align:center}
thead th.right{text-align:right}
tbody tr{border-bottom:1px solid #f0f4f8}
tbody td{font-size:13px;color:#1a1a2e;padding:10px 4px;vertical-align:top}
tbody td.center{text-align:center}
tbody td.right{text-align:right}
.totals{margin-top:12px;border-top:1px solid #e8edf2;padding-top:12px}
.total-row{display:flex;justify-content:space-between;font-size:13px;color:#4a5568;margin-bottom:6px}
.total-row.grand{font-size:16px;font-weight:700;color:#1a1a2e;margin-top:8px;padding-top:8px;border-top:2px solid #e8edf2}
.total-row .label{font-weight:500}
.status-badge{display:inline-block;background:#e6f4ea;color:#006e25;font-size:11px;font-weight:700;padding:4px 10px;border-radius:20px;letter-spacing:.4px;margin-bottom:20px}
.payment-method{font-size:12px;color:#8a9bb0;margin-bottom:20px}
.divider{height:1px;background:#e8edf2;margin:16px 0}
.footer-row{display:flex;justify-content:space-between;font-size:12px;color:#8a9bb0;flex-wrap:wrap;gap:4px}
.footer-info span{display:block;margin-bottom:3px}
.powered{margin-top:20px;text-align:center;font-size:11px;color:#b0bec5}
.powered a{color:#006e25;font-weight:600;text-decoration:none}
@media print{body{background:#fff;padding:0}.card{box-shadow:none;border-radius:0}}
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <div class="header-top">
      ${logoUrl
        ? `<img class="logo-img" src="${escHtml(logoUrl)}" alt="${storeName}">`
        : `<div class="logo-placeholder">${escHtml((settings.store_name || 'B').charAt(0).toUpperCase())}</div>`}
      <div>
        <div class="store-name">${storeName}</div>
        ${storeAddress ? `<div class="store-sub">${storeAddress}</div>` : ''}
      </div>
    </div>
    <div class="invoice-badge">
      <div>
        <div class="invoice-label">Invoice</div>
        <div class="invoice-no">#${invoiceNo}</div>
      </div>
      <div class="invoice-date">
        <div>${dateStr}</div>
        <div>${timeStr}</div>
      </div>
    </div>
  </div>

  <div class="body">
    ${customerName ? `
    <div class="section-label">Bill To</div>
    <div class="customer-box">
      <div class="customer-name">${customerName}</div>
      ${customerPhone ? `<div class="customer-phone">${customerPhone}</div>` : ''}
    </div>` : ''}

    <div class="section-label">Items</div>
    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th class="center">Qty</th>
          <th class="right">Price</th>
          <th class="right">Total</th>
        </tr>
      </thead>
      <tbody>${itemRows}</tbody>
    </table>

    <div class="totals">
      <div class="total-row"><span class="label">Subtotal</span><span>${fmt(subtotal, sym)}</span></div>
      ${discount > 0 ? `<div class="total-row"><span class="label">Discount</span><span>-${fmt(discount, sym)}</span></div>` : ''}
      ${tax > 0 ? `<div class="total-row"><span class="label">${taxLabel}</span><span>${fmt(tax, sym)}</span></div>` : ''}
      <div class="total-row grand"><span class="label">Total</span><span>${fmt(total, sym)}</span></div>
    </div>

    <div class="divider"></div>
    <div class="status-badge">✓ PAID</div>
    <div class="payment-method">Payment via ${escHtml(tx.payment_method || 'Cash')}</div>

    ${(gstin || upiId || storePhone || storeEmail) ? `
    <div class="divider"></div>
    <div class="footer-row">
      <div class="footer-info">
        ${storePhone ? `<span>📞 ${storePhone}</span>` : ''}
        ${storeEmail ? `<span>✉️ ${storeEmail}</span>` : ''}
      </div>
      <div class="footer-info" style="text-align:right">
        ${gstin ? `<span>GSTIN: ${gstin}</span>` : ''}
        ${upiId ? `<span>UPI: ${upiId}</span>` : ''}
      </div>
    </div>` : ''}

    <div class="powered">Powered by <a href="https://billcat.in">BillCat</a></div>
  </div>
</div>
</body>
</html>`;
}

export default async function handler(req, res) {
  const slug = req.query.slug || req.query.uid;
  if (!slug) return res.status(400).send('Missing parameters');
  // This handler now reads with the service key, which bypasses RLS. Pin the
  // slug to the shape BillCat generates (uid + branch + bill, hex-ish) so it
  // can only ever be used to fetch one invoice by its link token.
  if (!/^[a-z0-9]{6,32}$/i.test(slug)) {
    return res.status(404).send(notFoundHtml());
  }

  try {
    // Direct lookup by site_link column — single exact match
    const rows = await supabaseGet(
      `transactions?site_link=eq.${encodeURIComponent(slug.toLowerCase())}&select=*&limit=1`
    );

    const tx = (rows && rows[0]) || null;
    if (!tx) return res.status(404).send(notFoundHtml());

    // Fetch store settings
    const settingsRows = await supabaseGet(
      `user_settings?user_id=eq.${encodeURIComponent(tx.user_id)}&select=*&limit=1`
    );
    const settings = (settingsRows && settingsRows[0]) || {};

    const html = renderHtml({ tx, settings });

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=60');
    res.send(html);
  } catch (e) {
    res.status(500).send(`Error: ${e.message}`);
  }
}

function notFoundHtml() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Invoice Not Found — BillCat</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',sans-serif;background:#f6faff;color:#141d23;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;text-align:center}
.logo{font-size:32px;font-weight:800;color:#006e25;margin-bottom:32px}
h1{font-size:72px;font-weight:800;color:#006e25;line-height:1;margin-bottom:8px}
h2{font-size:20px;font-weight:600;color:#141d23;margin-bottom:12px}
p{font-size:15px;color:#6e7b6b;margin-bottom:32px}
a{background:#006e25;color:#fff;padding:12px 28px;border-radius:8px;font-size:14px;font-weight:700;text-decoration:none}
</style>
</head>
<body>
  <div class="logo">BillCat</div>
  <h1>404</h1>
  <h2>Invoice not found</h2>
  <p>This invoice doesn't exist or hasn't been synced yet.</p>
  <a href="/">Go Home</a>
</body>
</html>`;
}
