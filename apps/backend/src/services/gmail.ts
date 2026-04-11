import { google, type gmail_v1 } from "googleapis";
import { clientForUser } from "../auth/google";

// Base query: emails with PDF attachments that look like invoices
const INVOICE_QUERY_BASE = [
  "has:attachment",
  "filename:pdf",
  "(subject:(factura OR invoice OR receipt OR recibo) OR from:(billing OR invoice OR facturacion OR no-reply@stripe.com OR aws-receipts))",
].join(" ");

/**
 * Exponential backoff helper for Google API 429 errors.
 * Retries up to `maxRetries` times with delays starting at 1s, doubling up to 32s.
 */
async function withBackoff<T>(fn: () => Promise<T>, maxRetries = 5): Promise<T> {
  let delay = 1000; // start at 1s
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      const status = err?.code ?? err?.response?.status ?? err?.status;
      if (status === 429 && attempt < maxRetries) {
        console.warn(`[gmail] 429 rate limit, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((r) => setTimeout(r, delay));
        delay = Math.min(delay * 2, 32000);
      } else {
        throw err;
      }
    }
  }
}

export type GmailMessageRef = {
  messageId: string;
};

export type GmailAttachment = {
  messageId: string;
  filename: string;
  mimeType: string;
  data: Buffer;
};

/**
 * Phase 1: Paginate through ALL matching messages in Gmail.
 * Returns every message ID that matches the invoice query.
 * If `afterDate` is provided, appends `after:YYYY/MM/DD` to limit results.
 */
export async function listInvoiceMessageIds(
  accessToken: string,
  refreshToken: string | null,
  userId?: string,
  afterDate?: Date | null
): Promise<GmailMessageRef[]> {
  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  let query = INVOICE_QUERY_BASE;
  if (afterDate) {
    const y = afterDate.getFullYear();
    const m = String(afterDate.getMonth() + 1).padStart(2, "0");
    const d = String(afterDate.getDate()).padStart(2, "0");
    query += ` after:${y}/${m}/${d}`;
  }

  const all: GmailMessageRef[] = [];
  let pageToken: string | undefined;

  do {
    const list = await withBackoff(() =>
      gmail.users.messages.list({
        userId: "me",
        q: query,
        maxResults: 100, // max allowed per page
        pageToken,
      })
    );

    const messages = list.data.messages ?? [];
    for (const m of messages) {
      if (m.id) all.push({ messageId: m.id });
    }

    pageToken = list.data.nextPageToken ?? undefined;
  } while (pageToken);

  return all;
}

/**
 * Phase 2: Download and extract attachments from a single message.
 */
export async function getMessageAttachments(
  accessToken: string,
  refreshToken: string | null,
  messageId: string,
  userId?: string
): Promise<GmailAttachment[]> {
  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  const msg = await withBackoff(() =>
    gmail.users.messages.get({
      userId: "me",
      id: messageId,
      format: "full",
    })
  );

  const parts = flattenParts(msg.data.payload);
  const out: GmailAttachment[] = [];

  for (const p of parts) {
    const filename = p.filename;
    const attId = p.body?.attachmentId;
    if (!filename || !attId) continue;
    if (!isInvoiceFile(filename, p.mimeType ?? "")) continue;

    const att = await withBackoff(() =>
      gmail.users.messages.attachments.get({
        userId: "me",
        messageId,
        id: attId,
      })
    );
    const dataB64 = att.data.data ?? "";
    const buf = Buffer.from(dataB64, "base64url");
    out.push({
      messageId,
      filename,
      mimeType: p.mimeType ?? "application/octet-stream",
      data: buf,
    });
  }

  return out;
}

function flattenParts(payload?: gmail_v1.Schema$MessagePart | null): gmail_v1.Schema$MessagePart[] {
  if (!payload) return [];
  const out: gmail_v1.Schema$MessagePart[] = [payload];
  for (const p of payload.parts ?? []) out.push(...flattenParts(p));
  return out;
}

function isInvoiceFile(filename: string, mimeType: string): boolean {
  const lower = filename.toLowerCase();
  if (lower.endsWith(".pdf")) return true;
  if (mimeType === "application/pdf") return true;
  if (/invoice|factura|receipt|recibo/i.test(lower)) return true;
  return false;
}

/**
 * Incremental sync using history.list().
 * Given a startHistoryId, returns only NEW message IDs that arrived since then
 * and match our invoice criteria (have PDF attachments).
 * Returns { messageIds, latestHistoryId }.
 */
export async function listNewMessagesSinceHistory(
  accessToken: string,
  refreshToken: string | null,
  userId: string,
  startHistoryId: string
): Promise<{ messageIds: string[]; latestHistoryId: string | null }> {
  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  const messageIds = new Set<string>();
  let pageToken: string | undefined;
  let latestHistoryId: string | null = null;

  do {
    const res = await withBackoff(() =>
      gmail.users.history.list({
        userId: "me",
        startHistoryId,
        historyTypes: ["messageAdded"],
        pageToken,
      })
    );

    latestHistoryId = res.data.historyId ?? latestHistoryId;

    for (const h of res.data.history ?? []) {
      for (const added of h.messagesAdded ?? []) {
        if (added.message?.id) {
          messageIds.add(added.message.id);
        }
      }
    }

    pageToken = res.data.nextPageToken ?? undefined;
  } while (pageToken);

  return { messageIds: Array.from(messageIds), latestHistoryId };
}

/**
 * Check if a single message has invoice-like PDF attachments.
 * Lightweight check — only fetches metadata, not attachment data.
 */
export async function messageHasInvoiceAttachments(
  accessToken: string,
  refreshToken: string | null,
  messageId: string,
  userId?: string
): Promise<boolean> {
  const auth = clientForUser(accessToken, refreshToken, userId);
  const gmail = google.gmail({ version: "v1", auth });

  const msg = await withBackoff(() =>
    gmail.users.messages.get({
      userId: "me",
      id: messageId,
      format: "metadata",
      metadataHeaders: ["Subject"],
    })
  );

  const parts = flattenParts(msg.data.payload);
  return parts.some((p) => p.filename && isInvoiceFile(p.filename, p.mimeType ?? ""));
}
