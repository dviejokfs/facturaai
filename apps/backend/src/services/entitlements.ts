import { sql } from "../db/client";

/**
 * Entitlement = a feature flag granted by an active subscription.
 * Backed by the `subscriptions` table, which is kept in sync by the
 * RevenueCat webhook handler at routes/revenuecat.ts.
 *
 * The iOS app is the source of truth for UI gating (via the RevenueCat SDK),
 * but the server enforces gates for anything that could be tampered with
 * client-side (e.g. invoice count limits, recurring invoice generation).
 */

export type EntitlementId = "pro" | "business";

type CachedEntitlement = {
  active: Set<EntitlementId>;
  fetchedAt: number;
};

const TTL_MS = 60_000; // 60 seconds — short enough to feel real-time, long enough to cut DB load
const cache = new Map<string, CachedEntitlement>();

export async function getActiveEntitlements(userId: string): Promise<Set<EntitlementId>> {
  const now = Date.now();
  const hit = cache.get(userId);
  if (hit && now - hit.fetchedAt < TTL_MS) {
    return hit.active;
  }

  const rows = (await sql`
    SELECT entitlement, status, expires_at
    FROM subscriptions
    WHERE user_id = ${userId}
      AND status IN ('active', 'in_grace')
      AND (expires_at IS NULL OR expires_at > NOW())
  `) as Array<{ entitlement: string; status: string; expires_at: Date | null }>;

  const active = new Set<EntitlementId>();
  for (const r of rows) {
    if (r.entitlement === "pro" || r.entitlement === "business") {
      active.add(r.entitlement);
    }
  }
  // Business implies Pro.
  if (active.has("business")) active.add("pro");

  cache.set(userId, { active, fetchedAt: now });
  return active;
}

export function invalidateEntitlements(userId: string) {
  cache.delete(userId);
}

export async function hasEntitlement(userId: string, entitlement: EntitlementId): Promise<boolean> {
  const active = await getActiveEntitlements(userId);
  return active.has(entitlement);
}

/**
 * Convenience for routes: throw a 402 Payment Required if the user lacks the entitlement.
 * Caller is responsible for catching and translating to a Hono response.
 */
export class EntitlementRequiredError extends Error {
  constructor(public entitlement: EntitlementId) {
    super(`entitlement_required:${entitlement}`);
  }
}

export async function requireEntitlement(userId: string, entitlement: EntitlementId): Promise<void> {
  if (!(await hasEntitlement(userId, entitlement))) {
    throw new EntitlementRequiredError(entitlement);
  }
}
