import { google } from "googleapis";
import { clientForUser } from "../auth/google";
import { config } from "../config";
import { sql } from "../db/client";

const TOPIC = `projects/${config.GOOGLE_CLOUD_PROJECT}/topics/gmail-push`;

/**
 * Register Gmail push notifications for a user.
 * Called after OAuth callback and periodically for renewal.
 * Returns the historyId and expiration from Google.
 */
export async function watchGmail(
  userId: string,
  accessToken: string,
  refreshToken: string | null
): Promise<{ historyId: string; expiration: string } | null> {
  if (!config.GOOGLE_CLOUD_PROJECT) {
    console.warn("[gmailWatch] GOOGLE_CLOUD_PROJECT not set, skipping watch");
    return null;
  }

  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  try {
    const res = await gmail.users.watch({
      userId: "me",
      requestBody: {
        topicName: TOPIC,
        labelIds: ["INBOX"],
      },
    });

    const historyId = String(res.data.historyId);
    const expiration = String(res.data.expiration);
    const expiryDate = new Date(Number(expiration));

    await sql`
      UPDATE users
      SET gmail_history_id = ${historyId},
          gmail_watch_expiry = ${expiryDate},
          updated_at = NOW()
      WHERE id = ${userId}
    `;

    console.log(`[gmailWatch] Watching user ${userId}, historyId=${historyId}, expires=${expiryDate.toISOString()}`);
    return { historyId, expiration };
  } catch (err: any) {
    console.error(`[gmailWatch] Failed to watch for user ${userId}:`, err?.message ?? err);
    return null;
  }
}

/**
 * Stop Gmail push notifications for a user.
 * Called on account deletion or Gmail disconnect.
 */
export async function stopWatch(
  userId: string,
  accessToken: string,
  refreshToken: string | null
): Promise<void> {
  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  try {
    await gmail.users.stop({ userId: "me" });
    await sql`
      UPDATE users
      SET gmail_history_id = NULL, gmail_watch_expiry = NULL, updated_at = NOW()
      WHERE id = ${userId}
    `;
    console.log(`[gmailWatch] Stopped watch for user ${userId}`);
  } catch (err: any) {
    console.error(`[gmailWatch] Failed to stop watch for user ${userId}:`, err?.message ?? err);
  }
}

/**
 * Renew watches for all users whose watch is expiring within 24 hours.
 * Should be called via cron/interval every 6 hours.
 */
export async function renewExpiringWatches(): Promise<number> {
  if (!config.GOOGLE_CLOUD_PROJECT) return 0;

  const users = await sql`
    SELECT id, google_access_token, google_refresh_token
    FROM users
    WHERE google_access_token IS NOT NULL
      AND gmail_watch_expiry IS NOT NULL
      AND gmail_watch_expiry < NOW() + INTERVAL '24 hours'
  `;

  let renewed = 0;
  for (const user of users) {
    const result = await watchGmail(user.id, user.google_access_token, user.google_refresh_token);
    if (result) renewed++;
  }

  if (renewed > 0) {
    console.log(`[gmailWatch] Renewed ${renewed}/${users.length} expiring watches`);
  }
  return renewed;
}

/**
 * Set up watches for any Gmail-connected users who don't have an active watch.
 * Called on server startup to ensure coverage after restarts.
 */
export async function ensureAllWatches(): Promise<number> {
  if (!config.GOOGLE_CLOUD_PROJECT) return 0;

  const users = await sql`
    SELECT id, google_access_token, google_refresh_token
    FROM users
    WHERE google_access_token IS NOT NULL
      AND (gmail_watch_expiry IS NULL OR gmail_watch_expiry < NOW())
  `;

  let setup = 0;
  for (const user of users) {
    const result = await watchGmail(user.id, user.google_access_token, user.google_refresh_token);
    if (result) setup++;
  }

  if (setup > 0) {
    console.log(`[gmailWatch] Set up ${setup} watches on startup`);
  }
  return setup;
}
