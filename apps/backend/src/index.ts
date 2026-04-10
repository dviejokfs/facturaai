import { Hono } from "hono";
import { logger } from "hono/logger";
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

// Run migrations before starting the server
await runMigrations();

const app = new Hono();

app.use("*", logger());

app.get("/", (c) => c.json({ name: "invoscanai", version: "1.0.0", status: "ok" }));
app.get("/health", (c) => c.json({ ok: true }));

// Public auth routes
app.route("/auth", authRoutes);

// Public webhooks (auth via shared secret in the route handler itself)
app.route("/webhooks/revenuecat", revenuecatRoutes);

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
  console.error(err);
  const message =
    config.NODE_ENV === "production"
      ? "An unexpected error occurred"
      : err.message;
  return c.json({ error: "internal_error", message }, 500);
});

console.log(`InvoScanAI backend listening on :${config.PORT}`);
export default {
  port: config.PORT,
  fetch: app.fetch,
};
