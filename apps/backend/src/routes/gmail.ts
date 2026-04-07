import { Hono } from "hono";
import { sql } from "../db/client";
import { runGmailSync } from "../workers/gmailSync";

export const gmailRoutes = new Hono();

gmailRoutes.post("/sync", async (c) => {
  const user = c.get("user");

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
