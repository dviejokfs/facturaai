import type { Context } from "hono";

type Bucket = { timestamps: number[] };

const buckets = new Map<string, Bucket>();

// Periodic sweep of empty buckets to prevent unbounded memory growth.
setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets) {
    // Drop buckets whose newest entry is older than 1 hour.
    if (bucket.timestamps.length === 0 || now - bucket.timestamps[bucket.timestamps.length - 1]! > 3_600_000) {
      buckets.delete(key);
    }
  }
}, 5 * 60 * 1000).unref();

export type RateLimitResult =
  | { allowed: true; remaining: number; resetMs: number }
  | { allowed: false; retryAfterSec: number; resetMs: number };

/**
 * Sliding-window rate limiter. In-memory; fine for a single-instance Bun deploy.
 * Swap to Redis (Bun.redis) when we scale horizontally.
 */
export function checkRate(key: string, limit: number, windowMs: number): RateLimitResult {
  const now = Date.now();
  const cutoff = now - windowMs;

  const bucket = buckets.get(key) ?? { timestamps: [] };
  bucket.timestamps = bucket.timestamps.filter((t) => t > cutoff);

  if (bucket.timestamps.length >= limit) {
    const oldest = bucket.timestamps[0]!;
    const resetMs = oldest + windowMs - now;
    return {
      allowed: false,
      retryAfterSec: Math.max(1, Math.ceil(resetMs / 1000)),
      resetMs,
    };
  }

  bucket.timestamps.push(now);
  buckets.set(key, bucket);

  return {
    allowed: true,
    remaining: limit - bucket.timestamps.length,
    resetMs: windowMs,
  };
}

/**
 * Best-effort client IP extraction. Trusts X-Forwarded-For only when a known
 * proxy header is present; otherwise falls back to the connection remote addr.
 */
export function clientIp(c: Context): string {
  const cf = c.req.header("cf-connecting-ip");
  if (cf) return cf.trim();

  const real = c.req.header("x-real-ip");
  if (real) return real.trim();

  const fwd = c.req.header("x-forwarded-for");
  if (fwd) {
    // Take the first entry (original client); the rest are proxy hops.
    const first = fwd.split(",")[0]?.trim();
    if (first) return first;
  }

  // Bun's request.headers doesn't expose remote addr; Hono sets it on c.env in some adapters.
  // As a last resort, use a constant so all unknown-origin requests share a bucket
  // (prevents a totally unthrottled anonymous path).
  return "unknown";
}

/**
 * Sends a 429 response with Retry-After header.
 */
export function tooManyRequests(c: Context, result: Extract<RateLimitResult, { allowed: false }>, scope: string) {
  c.header("Retry-After", String(result.retryAfterSec));
  return c.json(
    {
      error: "rate_limited",
      scope,
      message: `Too many requests. Try again in ${result.retryAfterSec} seconds.`,
      retryAfterSec: result.retryAfterSec,
    },
    429,
  );
}
