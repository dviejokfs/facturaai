import { Hono } from "hono";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { buildAuthUrl, exchangeCode, fetchUserInfo } from "../auth/google";
import { signToken, verifyToken } from "../auth/jwt";
import { requireAuth } from "../auth/middleware";
import { sql } from "../db/client";
import { config } from "../config";
import { deleteFile } from "../services/storage";
import { sendWelcomeEmail } from "../services/email";
import { watchGmail } from "../services/gmailWatch";

/**
 * Merge anonymous user's expenses into the real user, then delete the anonymous user.
 */
async function mergeAnonymousUser(anonymousToken: string, realUserId: string) {
  try {
    const payload = await verifyToken(anonymousToken);
    if (!payload.anonymous) return;

    const anonymousUserId = payload.sub;
    if (anonymousUserId === realUserId) return;

    // Verify anonymous user exists and pull fields we want to keep
    const [anonUser] = await sql`
      SELECT id, company_name, tax_id, tax_id_type, locale, base_currency
      FROM users WHERE id = ${anonymousUserId} AND is_anonymous = TRUE
    `;
    if (!anonUser) return;

    // Copy onboarding fields the anon user filled in — but don't overwrite
    // values the real user already has (e.g. returning Google user).
    await sql`
      UPDATE users SET
        company_name = COALESCE(company_name, ${anonUser.company_name}),
        tax_id = COALESCE(tax_id, ${anonUser.tax_id}),
        tax_id_type = COALESCE(tax_id_type, ${anonUser.tax_id_type}),
        locale = COALESCE(locale, ${anonUser.locale}),
        base_currency = COALESCE(base_currency, ${anonUser.base_currency}),
        updated_at = NOW()
      WHERE id = ${realUserId}
    `;

    // Move all expenses from anonymous user to real user
    await sql`
      UPDATE expenses SET user_id = ${realUserId}
      WHERE user_id = ${anonymousUserId}
    `;

    // Delete the anonymous user
    await sql`DELETE FROM users WHERE id = ${anonymousUserId}`;

    console.log(`[auth] Merged anonymous user ${anonymousUserId} into ${realUserId}`);
  } catch (err) {
    console.error("[auth] Failed to merge anonymous user:", err);
  }
}

// Cached JWKS for Apple Sign-In token verification
const appleJWKS = createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys"),
);

export const authRoutes = new Hono();

authRoutes.get("/google/start", async (c) => {
  const state = crypto.randomUUID();
  const anonymousToken = c.req.query("anonymous_token");
  // Store anonymous_token alongside state so we can retrieve it in the callback
  await sql`INSERT INTO oauth_states (state, anonymous_token) VALUES (${state}, ${anonymousToken ?? null})`;
  return c.redirect(buildAuthUrl(state));
});

authRoutes.get("/google/callback", async (c) => {
  const code = c.req.query("code");
  const state = c.req.query("state");
  if (!code || !state) return c.text("missing code/state", 400);

  const [stored] =
    await sql`DELETE FROM oauth_states WHERE state = ${state} RETURNING state, anonymous_token`;
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
    RETURNING id, email, (xmax = 0) AS is_new
  `;

  const jwt = await signToken({ sub: user.id, email: user.email });

  // Merge anonymous user data if present
  if (stored.anonymous_token) {
    await mergeAnonymousUser(stored.anonymous_token, user.id);
  }

  // Send welcome email for brand-new users (fire-and-forget)
  if (user.is_new) {
    sendWelcomeEmail(user.email, profile.name ?? null).catch((err) =>
      console.error("Welcome email failed:", err),
    );
  }

  // Start Gmail push notifications (fire-and-forget)
  if (tokens.access_token) {
    watchGmail(user.id, tokens.access_token, tokens.refresh_token ?? null).catch((err) =>
      console.error("[auth] watchGmail failed:", err)
    );
  }

  const redirect = `${config.IOS_REDIRECT_SCHEME}?token=${encodeURIComponent(jwt)}`;
  return c.redirect(redirect);
});

// Sign in with Apple
authRoutes.post("/apple/callback", async (c) => {
  const body = await c.req.json();
  const { identityToken, email, fullName, anonymous_token: anonymousToken } = body;

  if (!identityToken) return c.json({ error: "missing identity token" }, 400);

  // Verify the Apple identity token: signature, issuer, audience, and expiry
  let payload: { sub?: string; email?: string };
  try {
    const { payload: verified } = await jwtVerify(identityToken, appleJWKS, {
      issuer: "https://appleid.apple.com",
      audience: config.APNS_BUNDLE_ID,
    });
    payload = verified as { sub?: string; email?: string };
  } catch (err) {
    const message = err instanceof Error ? err.message : "token verification failed";
    return c.json({ error: `invalid identity token: ${message}` }, 401);
  }

  const appleSub = payload.sub;
  if (!appleSub) return c.json({ error: "no sub in token" }, 400);

  // Apple only sends email on first sign-in; use token email as fallback
  const userEmail = email || payload.email;
  if (!userEmail) return c.json({ error: "no email available" }, 400);

  const displayName = fullName
    ? [fullName.givenName, fullName.familyName].filter(Boolean).join(" ") || null
    : null;

  const [user] = await sql`
    INSERT INTO users (email, name, apple_sub)
    VALUES (${userEmail}, ${displayName}, ${appleSub})
    ON CONFLICT (email) DO UPDATE SET
      name = COALESCE(EXCLUDED.name, users.name),
      apple_sub = EXCLUDED.apple_sub,
      updated_at = NOW()
    RETURNING id, email, (xmax = 0) AS is_new
  `;

  const jwt = await signToken({ sub: user.id, email: user.email });

  // Merge anonymous user data if present
  if (anonymousToken) {
    await mergeAnonymousUser(anonymousToken, user.id);
  }

  // Send welcome email for brand-new users (fire-and-forget)
  if (user.is_new) {
    sendWelcomeEmail(user.email, displayName).catch((err) =>
      console.error("Welcome email failed:", err),
    );
  }

  return c.json({ token: jwt });
});

authRoutes.get("/me", requireAuth, async (c) => {
  const user = c.get("user");
  const [row] = await sql`
    SELECT id, email, name, plan, trial_ends_at,
           locale, base_currency, tax_id, tax_id_type,
           accountant_email, accountant_name, company_name,
           google_sub IS NOT NULL AS gmail_connected,
           google_token_expiry,
           google_refresh_token IS NOT NULL AS google_has_refresh_token,
           GREATEST(0, EXTRACT(EPOCH FROM (trial_ends_at - NOW()))::int / 86400) AS trial_days_left,
           (plan = 'trial' AND trial_ends_at < NOW()) AS trial_expired
    FROM users WHERE id = ${user.sub}
  `;
  // Token was validly signed but the user no longer exists (e.g. DB wipe in
  // dev, or deleted account). Tell the client to sign out so it clears Keychain.
  if (!row) return c.json({ error: "user_not_found" }, 401);
  return c.json(row);
});

authRoutes.patch("/me", requireAuth, async (c) => {
  const user = c.get("user");
  const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;

  const allowed = [
    "locale", "base_currency", "tax_id", "tax_id_type",
    "accountant_email", "accountant_name", "company_name",
  ] as const;

  // Build a single dynamic UPDATE — only set fields the client actually sent.
  const sets: string[] = [];
  const values: unknown[] = [];
  for (const key of allowed) {
    if (key in body) {
      sets.push(`${key} = $${sets.length + 1}`);
      values.push(body[key]);
    }
  }
  if (sets.length === 0) return c.json({ ok: true, updated: 0 });

  // Bun.sql tagged-template doesn't support raw fragments cleanly here, so
  // we use sql.unsafe with bound params.
  await sql.unsafe(
    `UPDATE users SET ${sets.join(", ")}, updated_at = NOW() WHERE id = $${sets.length + 1}`,
    [...values, user.sub],
  );
  return c.json({ ok: true });
});

// ── Account deletion (Apple requirement since June 2022) ─────────────────
authRoutes.delete("/account", requireAuth, async (c) => {
  const user = c.get("user");
  const userId = user.sub;

  // 1. Delete S3 attachments for user's expenses
  const attachments = await sql`
    SELECT attachment_key FROM expenses
    WHERE user_id = ${userId} AND attachment_key IS NOT NULL
  `;
  for (const row of attachments) {
    try {
      await deleteFile(row.attachment_key);
    } catch (err) {
      console.error(`Failed to delete S3 object ${row.attachment_key}:`, err);
    }
  }

  // 2. Delete S3 objects for exports
  const exports = await sql`
    SELECT storage_key FROM exports
    WHERE user_id = ${userId} AND storage_key IS NOT NULL
  `;
  for (const row of exports) {
    try {
      await deleteFile(row.storage_key);
    } catch (err) {
      console.error(`Failed to delete S3 export ${row.storage_key}:`, err);
    }
  }

  // 3. Delete all user data explicitly (CASCADE handles most, but be thorough)
  await sql`DELETE FROM subscription_events WHERE user_id = ${userId}`;
  await sql`DELETE FROM subscriptions WHERE user_id = ${userId}`;
  await sql`DELETE FROM device_tokens WHERE user_id = ${userId}`;
  await sql`DELETE FROM gmail_syncs WHERE user_id = ${userId}`;
  await sql`DELETE FROM export_shares WHERE export_id IN (SELECT id FROM exports WHERE user_id = ${userId})`;
  await sql`DELETE FROM exports WHERE user_id = ${userId}`;
  await sql`DELETE FROM expenses WHERE user_id = ${userId}`;
  await sql`DELETE FROM contacts WHERE user_id = ${userId}`;
  await sql`DELETE FROM companies WHERE user_id = ${userId}`;

  // 4. Finally delete the user row
  await sql`DELETE FROM users WHERE id = ${userId}`;

  return c.json({ ok: true });
});
