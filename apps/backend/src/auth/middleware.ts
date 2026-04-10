import type { MiddlewareHandler } from "hono";
import { verifyToken, type JwtPayload } from "./jwt";

declare module "hono" {
  interface ContextVariableMap {
    user: JwtPayload;
    requestId: string;
  }
}

export const requireAuth: MiddlewareHandler = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) {
    return c.json({ error: "missing_token" }, 401);
  }
  try {
    const user = await verifyToken(header.slice(7));
    c.set("user", user);
    await next();
  } catch {
    return c.json({ error: "invalid_token" }, 401);
  }
};
