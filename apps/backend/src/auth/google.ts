import { google } from "googleapis";
import { config } from "../config";
import { sql } from "../db/client";

export const GMAIL_SCOPES = [
  "openid",
  "email",
  "profile",
  "https://www.googleapis.com/auth/gmail.readonly",
];

export function createOAuthClient() {
  return new google.auth.OAuth2(
    config.GOOGLE_CLIENT_ID,
    config.GOOGLE_CLIENT_SECRET,
    config.GOOGLE_REDIRECT_URI
  );
}

export function buildAuthUrl(state: string): string {
  const client = createOAuthClient();
  return client.generateAuthUrl({
    access_type: "offline",
    prompt: "consent", // force refresh_token issuance
    scope: GMAIL_SCOPES,
    state,
    include_granted_scopes: true,
  });
}

export async function exchangeCode(code: string) {
  const client = createOAuthClient();
  const { tokens } = await client.getToken(code);
  return tokens;
}

export async function fetchUserInfo(accessToken: string) {
  const client = createOAuthClient();
  client.setCredentials({ access_token: accessToken });
  const oauth2 = google.oauth2({ version: "v2", auth: client });
  const { data } = await oauth2.userinfo.get();
  return data; // { id, email, name, ... }
}

export function clientForUser(accessToken: string, refreshToken?: string | null, userId?: string) {
  const client = createOAuthClient();
  client.setCredentials({
    access_token: accessToken,
    refresh_token: refreshToken ?? undefined,
  });
  // When the SDK auto-refreshes the access token, persist the new token + expiry
  if (userId) {
    client.on("tokens", (tokens) => {
      const expiry = tokens.expiry_date ? new Date(tokens.expiry_date) : null;
      sql`
        UPDATE users
        SET google_access_token = ${tokens.access_token ?? accessToken},
            google_token_expiry = ${expiry},
            updated_at = NOW()
        WHERE id = ${userId}
      `.catch((err: unknown) => console.error("Failed to persist refreshed token:", err));
    });
  }
  return client;
}
