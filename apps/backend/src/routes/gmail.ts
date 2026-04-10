import { Hono } from "hono";
import { sql } from "../db/client";
import { runGmailSync } from "../workers/gmailSync";
import { checkProAccess } from "../services/entitlements";

export const gmailRoutes = new Hono();

/** Recover syncs stuck in running/queued for >30 minutes. */
async function recoverStaleSyncs(userId: string): Promise<void> {
  await sql`
    UPDATE gmail_syncs
    SET status = 'failed', error = 'Sync timed out', updated_at = NOW()
    WHERE user_id = ${userId}
      AND status IN ('running', 'queued')
      AND updated_at < NOW() - INTERVAL '30 minutes'
  `;
}

gmailRoutes.post("/sync", async (c) => {
  const user = c.get("user");

  // Gmail sync requires Pro
  const access = await checkProAccess(user.sub);
  if (!access.allowed) {
    return c.json(
      { error: access.error, message: access.message, upgrade: access.upgrade },
      access.status as 403,
    );
  }

  // Recover any stale syncs before starting a new one
  await recoverStaleSyncs(user.sub);

  // Prevent duplicate: if there's already an active sync, return it
  const [existing] = await sql`
    SELECT id, status, messages_processed, invoices_found, total_messages, error,
           last_sync_at, created_at, updated_at
    FROM gmail_syncs
    WHERE user_id = ${user.sub} AND status IN ('queued', 'running')
    ORDER BY created_at DESC LIMIT 1
  `;
  if (existing) return c.json(existing, 202);

  const [sync] = await sql`
    INSERT INTO gmail_syncs (user_id, status) VALUES (${user.sub}, 'queued')
    RETURNING id, status
  `;

  // Fire-and-forget background job
  runGmailSync(user.sub, sync.id).catch((err) => {
    console.error("gmail sync failed:", err);
  });

  return c.json(sync, 202);
});

gmailRoutes.get("/sync/:id", async (c) => {
  const user = c.get("user");
  const id = c.req.param("id");

  // /sync/active — returns most recent active or last completed sync
  if (id === "active") {
    await recoverStaleSyncs(user.sub);

    const [active] = await sql`
      SELECT * FROM gmail_syncs
      WHERE user_id = ${user.sub} AND status IN ('queued', 'running')
      ORDER BY created_at DESC LIMIT 1
    `;
    if (active) return c.json(active);

    const [latest] = await sql`
      SELECT * FROM gmail_syncs
      WHERE user_id = ${user.sub}
      ORDER BY created_at DESC LIMIT 1
    `;
    return c.json(latest ?? null);
  }

  const [row] = await sql`
    SELECT * FROM gmail_syncs WHERE id = ${id} AND user_id = ${user.sub}
  `;
  if (!row) return c.json({ error: "not_found" }, 404);
  return c.json(row);
});

gmailRoutes.get("/sync", async (c) => {
  const user = c.get("user");
  const rows = await sql`
    SELECT * FROM gmail_syncs WHERE user_id = ${user.sub}
    ORDER BY created_at DESC LIMIT 10
  `;
  return c.json(rows);
});
