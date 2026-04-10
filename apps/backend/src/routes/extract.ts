import { Hono } from "hono";
import { extractAuto } from "../services/extract";

export const extractRoutes = new Hono();

// ── IP-based rate limiting: 3 requests per IP per hour ──
const RATE_LIMIT_MAX = 3;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const ipHits = new Map<string, number[]>();

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const timestamps = (ipHits.get(ip) ?? []).filter(
    (t) => now - t < RATE_LIMIT_WINDOW_MS,
  );
  if (timestamps.length >= RATE_LIMIT_MAX) {
    ipHits.set(ip, timestamps);
    return true;
  }
  timestamps.push(now);
  ipHits.set(ip, timestamps);
  return false;
}

// Periodically prune stale entries to avoid unbounded memory growth
setInterval(() => {
  const now = Date.now();
  for (const [ip, timestamps] of ipHits) {
    const active = timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
    if (active.length === 0) ipHits.delete(ip);
    else ipHits.set(ip, active);
  }
}, RATE_LIMIT_WINDOW_MS);

// Public endpoint — no auth required.
// Runs AI extraction and returns the result without persisting anything.
extractRoutes.post("/", async (c) => {
  const ip =
    c.req.header("x-forwarded-for")?.split(",")[0]?.trim() ??
    c.req.header("x-real-ip") ??
    "unknown";

  if (isRateLimited(ip)) {
    return c.json(
      { error: "rate_limited", message: "Too many requests. Try again later." },
      429,
    );
  }

  const form = await c.req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return c.json({ error: "file field required" }, 400);
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  const mime = file.type || "application/octet-stream";

  let extracted;
  try {
    extracted = await extractAuto(bytes, mime);
  } catch (err) {
    return c.json({ error: "extraction_failed", details: String(err) }, 422);
  }

  if (!extracted.isValidInvoice) {
    return c.json({ error: "not_an_invoice", message: "The uploaded document does not appear to be an invoice or receipt." }, 422);
  }

  return c.json(extracted);
});
