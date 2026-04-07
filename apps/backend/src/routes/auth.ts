import { Hono } from "hono";
import { buildAuthUrl, exchangeCode, fetchUserInfo } from "../auth/google";
import { signToken } from "../auth/jwt";
import { sql } from "../db/client";
import { config } from "../config";

export const authRoutes = new Hono();

authRoutes.get("/google/start", async (c) => {
  const state = crypto.randomUUID();
  await sql`INSERT INTO oauth_states (state) VALUES (${state})`;
  return c.redirect(buildAuthUrl(state));
});

authRoutes.get("/google/callback", async (c) => {
  const code = c.req.query("code");
  const state = c.req.query("state");
  if (!code || !state) return c.text("missing code/state", 400);

  const [stored] =
    await sql`DELETE FROM oauth_states WHERE state = ${state} RETURNING state`;
  if (!stored) return c.text("invalid state", 400);

  const tokens = await exchangeCode(code);
  if (!tokens.access_token) return c.text("no access token", 400);

  const profile = await fetchUserInfo(tokens.access_token);
  if (!profile.email) return c.text("no email from google", 400);

  const expiry = tokens.expiry_date ? new Date(tokens.expiry_date) : null;

  const [user] = await sql`
    INSERT INTO users (email, name, google_sub, google_access_token, google_refresh_token, google_token_expiry)
    VALUES (${profile.email}, ${profile.name ?? null}, ${profile.id ?? null},
            ${tokens.access_token}, ${tokens.refresh_token ?? null}, ${expiry})
    ON CONFLICT (email) DO UPDATE SET
      name = EXCLUDED.name,
      google_sub = EXCLUDED.google_sub,
      google_access_token = EXCLUDED.google_access_token,
      google_refresh_token = COALESCE(EXCLUDED.google_refresh_token, users.google_refresh_token),
      google_token_expiry = EXCLUDED.google_token_expiry,
      updated_at = NOW()
    RETURNING id, email
  `;

  const jwt = await signToken({ sub: user.id, email: user.email });

  const redirect = `${config.IOS_REDIRECT_SCHEME}?token=${encodeURIComponent(jwt)}`;
  return c.redirect(redirect);
});

authRoutes.get("/me", async (c) => {
  // simple helper: requires auth middleware upstream
  const user = c.get("user");
  if (!user) return c.json({ error: "unauthenticated" }, 401);
  const [row] = await sql`
    SELECT id, email, name, plan, trial_ends_at,
           GREATEST(0, EXTRACT(EPOCH FROM (trial_ends_at - NOW()))::int / 86400) AS trial_days_left,
           (plan = 'trial' AND trial_ends_at < NOW()) AS trial_expired
    FROM users WHERE id = ${user.sub}
  `;
  return c.json(row ?? null);
});
