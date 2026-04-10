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

// ─── Plan-aware helpers ────────────────────────────────────────────────────

type UserPlanRow = { plan: string; trial_ends_at: Date | string };

const planCache = new Map<string, { row: UserPlanRow; fetchedAt: number }>();

export async function getUserPlan(userId: string): Promise<UserPlanRow> {
  const now = Date.now();
  const hit = planCache.get(userId);
  if (hit && now - hit.fetchedAt < TTL_MS) return hit.row;

  const [row] = (await sql`
    SELECT plan, trial_ends_at FROM users WHERE id = ${userId}
  `) as UserPlanRow[];

  const result: UserPlanRow = row ?? { plan: "free", trial_ends_at: new Date(0) };
  planCache.set(userId, { row: result, fetchedAt: now });
  return result;
}

export function invalidatePlanCache(userId: string) {
  planCache.delete(userId);
}

/**
 * Returns true if the user's trial has expired (plan = 'trial' and trial_ends_at < now).
 */
export function isTrialExpired(plan: UserPlanRow): boolean {
  if (plan.plan !== "trial") return false;
  const expiresAt = typeof plan.trial_ends_at === "string"
    ? new Date(plan.trial_ends_at)
    : plan.trial_ends_at;
  return expiresAt < new Date();
}

/**
 * Checks whether the user has an active paid plan (via subscription or non-expired trial
 * that grants the entitlement). Combines both the subscriptions table and users table.
 *
 * Returns { allowed: true } or { allowed: false, error, message, upgrade, status? }.
 */
export async function checkProAccess(userId: string): Promise<
  | { allowed: true }
  | { allowed: false; error: string; message: string; upgrade: boolean; status?: number }
> {
  // First check subscription entitlements (RevenueCat-backed)
  if (await hasEntitlement(userId, "pro")) {
    return { allowed: true };
  }

  // No subscription — check user plan/trial
  const plan = await getUserPlan(userId);

  if (isTrialExpired(plan)) {
    return {
      allowed: false,
      error: "trial_expired",
      message: "Your trial has expired. Upgrade to Pro to continue using this feature.",
      upgrade: true,
      status: 403,
    };
  }

  // Active trial with no subscription — they still don't have "pro" entitlement
  // Only subscriptions grant pro access, trials are limited like free
  return {
    allowed: false,
    error: "pro_required",
    message: "This feature requires a Pro subscription.",
    upgrade: true,
    status: 403,
  };
}

/**
 * Checks the free-tier scan limit (5/month). Users with "pro" or "business" bypass.
 * Returns { allowed: true } or an error payload.
 */
export async function checkScanLimit(userId: string): Promise<
  | { allowed: true }
  | { allowed: false; error: string; message: string; upgrade: boolean; status: number }
> {
  // Pro/business users bypass limits
  if (await hasEntitlement(userId, "pro")) {
    return { allowed: true };
  }

  const plan = await getUserPlan(userId);
  const trialExpired = isTrialExpired(plan);

  const [countRow] = (await sql`
    SELECT count(*)::int AS cnt FROM expenses
    WHERE user_id = ${userId}
      AND created_at >= date_trunc('month', NOW())
  `) as Array<{ cnt: number }>;

  const count = countRow?.cnt ?? 0;

  if (count >= 5) {
    return {
      allowed: false,
      error: trialExpired ? "trial_expired" : "limit_reached",
      message: trialExpired
        ? "Your trial has expired. Upgrade to Pro for unlimited scans."
        : "Free plan limited to 5 scans per month. Upgrade to Pro for unlimited scans.",
      upgrade: true,
      status: 403,
    };
  }

  return { allowed: true };
}
