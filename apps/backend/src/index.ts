import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { config } from "./config";
import { requireAuth } from "./auth/middleware";
import { authRoutes } from "./routes/auth";
import { expenseRoutes } from "./routes/expenses";
import { uploadRoutes } from "./routes/upload";
import { gmailRoutes } from "./routes/gmail";
import { exportRoutes } from "./routes/export";

const app = new Hono();

app.use("*", logger());
app.use("*", cors({ origin: "*" }));

app.get("/", (c) => c.json({ name: "facturaai", version: "1.0.0", status: "ok" }));
app.get("/health", (c) => c.json({ ok: true }));

// Public auth routes
app.route("/auth", authRoutes);

// Protected API
const api = new Hono();
api.use("*", requireAuth);
api.route("/expenses", expenseRoutes);
api.route("/expenses/upload", uploadRoutes);
api.route("/gmail", gmailRoutes);
api.route("/export", exportRoutes);
api.get("/me", async (c) => {
  const user = c.get("user");
  return c.json(user);
});
app.route("/api", api);

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: "internal_error", message: err.message }, 500);
});

console.log(`FacturaAI backend listening on :${config.PORT}`);
export default {
  port: config.PORT,
  fetch: app.fetch,
};
