import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db/client";

export const deviceRoutes = new Hono();

const RegisterSchema = z.object({
  token: z.string().min(1),
  platform: z.enum(["ios", "android"]).default("ios"),
});

deviceRoutes.post("/", async (c) => {
  const user = c.get("user");
  const body = RegisterSchema.parse(await c.req.json());

  await sql`
    INSERT INTO device_tokens (user_id, token, platform)
    VALUES (${user.sub}, ${body.token}, ${body.platform})
    ON CONFLICT (user_id, token) DO NOTHING
  `;

  return c.json({ ok: true });
});

deviceRoutes.delete("/", async (c) => {
  const user = c.get("user");
  const { token } = await c.req.json();
  if (token) {
    await sql`DELETE FROM device_tokens WHERE user_id = ${user.sub} AND token = ${token}`;
  }
  return c.json({ ok: true });
});
