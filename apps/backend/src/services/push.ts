import { sql } from "../db/client";
import { config } from "../config";
import * as jose from "jose";

let cachedToken: { jwt: string; expiresAt: number } | null = null;

function resolveKeyPem(): string {
  const raw = config.APNS_KEY_P8;
  if (!raw) throw new Error("APNS_KEY_P8 is not set");

  // Already PEM-formatted
  if (raw.includes("-----BEGIN PRIVATE KEY-----")) return raw;

  // Base64-encoded PEM (for env vars that can't hold newlines)
  try {
    const decoded = Buffer.from(raw, "base64").toString("utf-8");
    if (decoded.includes("-----BEGIN PRIVATE KEY-----")) return decoded;
  } catch {}

  throw new Error("APNS_KEY_P8 must be a PEM string or base64-encoded PEM");
}

async function getAPNsToken(): Promise<string | null> {
  if (!config.APNS_KEY_P8 || !config.APNS_KEY_ID || !config.APNS_TEAM_ID) {
    return null;
  }

  // Reuse cached token if still valid (APNs tokens are valid for 1 hour)
  if (cachedToken && Date.now() < cachedToken.expiresAt) {
    return cachedToken.jwt;
  }

  const keyPem = resolveKeyPem();
  const privateKey = await jose.importPKCS8(keyPem, "ES256");

  const now = Math.floor(Date.now() / 1000);
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.APNS_KEY_ID })
    .setIssuer(config.APNS_TEAM_ID)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedToken = { jwt, expiresAt: Date.now() + 50 * 60 * 1000 }; // 50 min cache
  return jwt;
}

function apnsHost(): string {
  return config.APNS_ENVIRONMENT === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

export type PushPayload = {
  title: string;
  body: string;
  badge?: number;
  data?: Record<string, string>;
};

/**
 * Send a push notification to a single device token.
 */
async function sendToDevice(token: string, payload: PushPayload): Promise<boolean> {
  const jwt = await getAPNsToken();
  if (!jwt) {
    console.warn("[push] APNs not configured, skipping push");
    return false;
  }

  const apnsPayload = {
    aps: {
      alert: { title: payload.title, body: payload.body },
      badge: payload.badge,
      sound: "default",
    },
    ...payload.data,
  };

  try {
    const resp = await fetch(`${apnsHost()}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": config.APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(apnsPayload),
    });

    if (!resp.ok) {
      const body = await resp.text();
      console.error(`[push] APNs error ${resp.status}: ${body}`);

      // Remove invalid tokens
      if (resp.status === 410 || resp.status === 400) {
        await sql`DELETE FROM device_tokens WHERE token = ${token}`;
      }
      return false;
    }
    return true;
  } catch (err) {
    console.error("[push] Failed to send push:", err);
    return false;
  }
}

/**
 * Send a push notification to all devices for a user.
 */
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<number> {
  const devices = await sql`
    SELECT token FROM device_tokens WHERE user_id = ${userId}
  `;

  let sent = 0;
  for (const device of devices) {
    const ok = await sendToDevice(device.token as string, payload);
    if (ok) sent++;
  }
  return sent;
}
