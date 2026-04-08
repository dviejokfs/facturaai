import { Hono } from "hono";
import { sql } from "../db/client";
import { config } from "../config";
import { invalidateEntitlements, type EntitlementId } from "../services/entitlements";

/**
 * RevenueCat webhook receiver.
 *
 * Setup: in the RevenueCat dashboard → Project Settings → Integrations → Webhooks,
 * point at https://<your-host>/webhooks/revenuecat and set the Authorization header
 * to "Bearer <REVENUECAT_WEBHOOK_SECRET>". Also enable "Send Sandbox events" if you
 * want trial flows from TestFlight to land here.
 *
 * RevenueCat webhooks: https://www.revenuecat.com/docs/integrations/webhooks
 */

export const revenuecatRoutes = new Hono();

// RevenueCat event types we care about. Anything else is logged but ignored.
const RELEVANT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "CANCELLATION",
  "UNCANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIBER_ALIAS",
  "SUBSCRIPTION_PAUSED",
  "TRANSFER",
  "TEMPORARY_ENTITLEMENT_GRANT",
  "TEST",
]);

type RCEvent = {
  api_version: string;
  event: {
    id: string;
    type: string;
    event_timestamp_ms: number;
    app_user_id: string;
    original_app_user_id?: string;
    aliases?: string[];
    product_id?: string;
    period_type?: string;
    purchased_at_ms?: number;
    expiration_at_ms?: number | null;
    environment?: "SANDBOX" | "PRODUCTION";
    entitlement_ids?: string[] | null;
    entitlement_id?: string | null;
    store?: string;
    cancel_reason?: string;
    new_product_id?: string;
    transferred_from?: string[];
    transferred_to?: string[];
  };
};

revenuecatRoutes.post("/", async (c) => {
  // Auth: RevenueCat signs the webhook by sending whatever Authorization header you
  // configure in the dashboard. We expect "Bearer <secret>".
  const auth = c.req.header("authorization") ?? "";
  const expected = `Bearer ${config.REVENUECAT_WEBHOOK_SECRET}`;
  if (!config.REVENUECAT_WEBHOOK_SECRET || auth !== expected) {
    return c.json({ error: "unauthorized" }, 401);
  }

  let body: RCEvent;
  try {
    body = (await c.req.json()) as RCEvent;
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }

  const ev = body?.event;
  if (!ev?.id || !ev?.type || !ev?.app_user_id) {
    return c.json({ error: "bad_event" }, 400);
  }

  // Idempotency — if we've already processed this event id, ack and skip.
  const dup = (await sql`
    SELECT id FROM subscription_events WHERE event_id = ${ev.id} LIMIT 1
  `) as Array<{ id: string }>;
  if (dup.length > 0) {
    return c.json({ ok: true, deduped: true });
  }

  // Resolve our internal user. RevenueCat's app_user_id should be set by the iOS
  // client to our DB user UUID at sign-in time (see iOS RevenueCatService).
  // Fall back to email matching if someone is on an anonymous RC id.
  const internalUserId = await resolveUserId(ev.app_user_id, ev.aliases ?? []);

  // Audit log — store every event regardless of whether we act on it.
  await sql`
    INSERT INTO subscription_events
      (event_id, user_id, revenuecat_app_user_id, event_type, environment, payload)
    VALUES
      (${ev.id}, ${internalUserId}, ${ev.app_user_id}, ${ev.type},
       ${ev.environment ?? "PRODUCTION"}, ${JSON.stringify(body)}::jsonb)
  `;

  if (!RELEVANT_EVENTS.has(ev.type)) {
    console.log(`[revenuecat] ignored event type=${ev.type} id=${ev.id}`);
    return c.json({ ok: true, ignored: true });
  }

  if (!internalUserId) {
    console.warn(`[revenuecat] event for unknown user app_user_id=${ev.app_user_id} type=${ev.type}`);
    // Still 200 — we don't want RC to keep retrying for users we can't resolve.
    return c.json({ ok: true, unknown_user: true });
  }

  await applyEvent(internalUserId, ev);
  invalidateEntitlements(internalUserId);

  return c.json({ ok: true });
});

async function resolveUserId(appUserId: string, aliases: string[]): Promise<string | null> {
  // Our convention: RC app_user_id IS our user uuid. Try direct match first.
  const candidates = [appUserId, ...aliases].filter(Boolean);
  for (const c of candidates) {
    if (isUuid(c)) {
      const rows = (await sql`SELECT id FROM users WHERE id = ${c} LIMIT 1`) as Array<{ id: string }>;
      if (rows.length > 0) return rows[0].id;
    }
  }
  return null;
}

function isUuid(s: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
}

async function applyEvent(userId: string, ev: RCEvent["event"]): Promise<void> {
  const entitlementIds = (ev.entitlement_ids ?? (ev.entitlement_id ? [ev.entitlement_id] : [])) as string[];

  // Map RC event types to our subscription status.
  const status = statusFromEventType(ev.type);

  // EXPIRATION / CANCELLATION events with no entitlement_ids: down all entitlements for this user.
  if ((ev.type === "EXPIRATION" || ev.type === "CANCELLATION") && entitlementIds.length === 0) {
    await sql`
      UPDATE subscriptions
      SET status = ${status},
          auto_renew = ${ev.type !== "EXPIRATION"},
          last_event_at = NOW(),
          updated_at = NOW()
      WHERE user_id = ${userId}
    `;
    return;
  }

  for (const entRaw of entitlementIds) {
    if (entRaw !== "pro" && entRaw !== "business") continue;
    const entitlement = entRaw as EntitlementId;

    const productId = ev.product_id ?? ev.new_product_id ?? "unknown";
    const periodType = ev.period_type ?? null;
    const store = ev.store ?? "app_store";
    const purchasedAt = ev.purchased_at_ms ? new Date(ev.purchased_at_ms) : null;
    const expiresAt = ev.expiration_at_ms ? new Date(ev.expiration_at_ms) : null;
    const env = ev.environment ?? "PRODUCTION";
    const autoRenew = !["CANCELLATION", "EXPIRATION"].includes(ev.type);

    await sql`
      INSERT INTO subscriptions
        (user_id, revenuecat_app_user_id, entitlement, product_id, period_type,
         status, store, purchased_at, expires_at, auto_renew, environment, last_event_at)
      VALUES
        (${userId}, ${ev.app_user_id}, ${entitlement}, ${productId}, ${periodType},
         ${status}, ${store}, ${purchasedAt}, ${expiresAt}, ${autoRenew}, ${env}, NOW())
      ON CONFLICT (revenuecat_app_user_id, entitlement) DO UPDATE
      SET product_id     = EXCLUDED.product_id,
          period_type    = EXCLUDED.period_type,
          status         = EXCLUDED.status,
          store          = EXCLUDED.store,
          purchased_at   = COALESCE(EXCLUDED.purchased_at, subscriptions.purchased_at),
          expires_at     = EXCLUDED.expires_at,
          auto_renew     = EXCLUDED.auto_renew,
          environment    = EXCLUDED.environment,
          last_event_at  = NOW(),
          updated_at     = NOW()
    `;
  }

  // Mirror plan onto users.plan for legacy code paths (auth/me, paywall gate).
  await syncUserPlan(userId);
}

function statusFromEventType(type: string): string {
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
    case "TEMPORARY_ENTITLEMENT_GRANT":
    case "TRANSFER":
      return "active";
    case "BILLING_ISSUE":
      return "in_grace";
    case "CANCELLATION":
      return "cancelled";
    case "EXPIRATION":
      return "expired";
    case "SUBSCRIPTION_PAUSED":
      return "paused";
    default:
      return "active";
  }
}

async function syncUserPlan(userId: string): Promise<void> {
  const rows = (await sql`
    SELECT entitlement
    FROM subscriptions
    WHERE user_id = ${userId}
      AND status IN ('active', 'in_grace')
      AND (expires_at IS NULL OR expires_at > NOW())
  `) as Array<{ entitlement: string }>;

  let plan = "trial";
  if (rows.some((r) => r.entitlement === "business")) plan = "business";
  else if (rows.some((r) => r.entitlement === "pro")) plan = "pro";
  else plan = "expired"; // had a sub at some point but nothing active right now

  // Don't downgrade users who are still inside their free trial window.
  await sql`
    UPDATE users
    SET plan = CASE
                 WHEN ${plan} = 'expired' AND trial_ends_at > NOW() THEN 'trial'
                 ELSE ${plan}
               END,
        updated_at = NOW()
    WHERE id = ${userId}
  `;
}
