import { Hono } from "hono";
import { logger } from "hono/logger";
import { cors } from "hono/cors";
import { config } from "./config";
import { sql } from "./db/client";
import { runMigrations } from "./db/migrate";
import { requireAuth } from "./auth/middleware";
import { authRoutes } from "./routes/auth";
import { expenseRoutes } from "./routes/expenses";
import { uploadRoutes } from "./routes/upload";
import { gmailRoutes } from "./routes/gmail";
import { exportRoutes, shareDownloadRoute } from "./routes/export";
import { revenuecatRoutes } from "./routes/revenuecat";
import { extractRoutes } from "./routes/extract";
import { companyRoutes } from "./routes/companies";
import { contactRoutes } from "./routes/contacts";
import { deviceRoutes } from "./routes/devices";
import { gmailWebhookRoutes } from "./routes/gmailWebhook";
import { ensureAllWatches, renewExpiringWatches } from "./services/gmailWatch";
import { ensureBucket } from "./services/storage";

// Run migrations before starting the server
await runMigrations();

// Ensure S3 bucket exists (creates it on Temps blob / MinIO if missing)
await ensureBucket();

const app = new Hono();

// Request ID middleware — adds X-Request-Id header for tracing
app.use("*", async (c, next) => {
  const requestId = c.req.header("x-request-id") ?? crypto.randomUUID();
  c.set("requestId", requestId);
  c.header("X-Request-Id", requestId);
  await next();
});

app.use("*", logger((msg, ...rest) => {
  console.log(JSON.stringify({ ts: new Date().toISOString(), msg: msg.trim(), ...rest }));
}));
app.use("*", cors({
  origin: config.NODE_ENV === "production"
    ? [config.PUBLIC_URL]
    : ["http://localhost:3000", "http://localhost:3005"],
  allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
}));

app.get("/", (c) => c.json({ name: "invoscanai", version: "1.0.0", status: "ok" }));
app.get("/health", (c) => c.json({ ok: true }));

// Public auth routes
app.route("/auth", authRoutes);

// Public webhooks (auth via shared secret in the route handler itself)
app.route("/webhooks/revenuecat", revenuecatRoutes);
app.route("/webhooks/gmail", gmailWebhookRoutes);

// Public share download (no auth)
app.route("/e", shareDownloadRoute);

// Public extract (no auth — for first-use onboarding)
app.route("/api/extract", extractRoutes);

// Protected API
const api = new Hono();
api.use("*", requireAuth);
api.route("/expenses", expenseRoutes);
api.route("/expenses/upload", uploadRoutes);
api.route("/gmail", gmailRoutes);
api.route("/export", exportRoutes);
api.route("/companies", companyRoutes);
api.route("/contacts", contactRoutes);
api.route("/devices", deviceRoutes);
api.get("/me", async (c) => {
  const user = c.get("user");
  return c.json(user);
});

// GDPR full data export
api.get("/account/export", async (c) => {
  const user = c.get("user") as { sub: string };
  const userId = user.sub;

  const [profile] = await sql`
    SELECT id, email, name, plan, trial_ends_at, locale, base_currency,
           tax_id, tax_id_type, accountant_email, accountant_name,
           company_name, created_at, updated_at
    FROM users WHERE id = ${userId}
  `;

  const expenses = await sql`
    SELECT id, vendor, vendor_tax_id, client, client_tax_id, cif, date,
           invoice_number, subtotal, iva_rate, iva_amount, irpf_rate,
           irpf_amount, total, currency, category, status, confidence,
           source, notes, created_at
    FROM expenses WHERE user_id = ${userId}
    ORDER BY date DESC
  `;

  const contacts = await sql`
    SELECT id, name, tax_id, email, phone, address, notes, created_at
    FROM contacts WHERE user_id = ${userId}
    ORDER BY name
  `;

  const companies = await sql`
    SELECT id, name, tax_id, tax_id_type, address, is_default, created_at
    FROM companies WHERE user_id = ${userId}
    ORDER BY name
  `;

  const subscriptions = await sql`
    SELECT id, entitlement, product_id, period_type, status, store,
           purchased_at, expires_at, created_at
    FROM subscriptions WHERE user_id = ${userId}
    ORDER BY created_at DESC
  `;

  const gmailSyncs = await sql`
    SELECT id, status, messages_processed, invoices_found, total_messages,
           error, last_sync_at, created_at
    FROM gmail_syncs WHERE user_id = ${userId}
    ORDER BY created_at DESC
  `;

  const exportData = {
    exportedAt: new Date().toISOString(),
    profile,
    expenses,
    contacts,
    companies,
    subscriptions,
    gmailSyncs,
  };

  return c.json(exportData);
});

app.route("/api", api);

app.onError((err, c) => {
  const requestId = c.get("requestId") ?? "unknown";
  console.error(JSON.stringify({
    ts: new Date().toISOString(),
    level: "error",
    requestId,
    method: c.req.method,
    path: c.req.path,
    error: err.message,
    stack: config.NODE_ENV !== "production" ? err.stack : undefined,
  }));
  return c.json({
    error: "internal_error",
    message: config.NODE_ENV === "production"
      ? "An unexpected error occurred"
      : err.message,
    requestId,
  }, 500);
});

// Graceful shutdown
const shutdown = async () => {
  console.log("[server] Shutting down gracefully...");
  clearInterval(watchRenewalInterval);
  await sql.close();
  process.exit(0);
};
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

// Gmail Pub/Sub: ensure watches on startup + renew every 6 hours
ensureAllWatches().catch((err) => console.error("[startup] ensureAllWatches failed:", err));
const watchRenewalInterval = setInterval(() => {
  renewExpiringWatches().catch((err) => console.error("[cron] renewExpiringWatches failed:", err));
}, 6 * 60 * 60 * 1000); // every 6 hours

console.log(`InvoScanAI backend listening on :${config.PORT}`);
export default {
  port: config.PORT,
  fetch: app.fetch,
};
