import { google, type gmail_v1 } from "googleapis";
import { clientForUser } from "../auth/google";

// Query: unread or read, from last N days, with PDF attachments, likely invoices
const INVOICE_QUERY = [
  "has:attachment",
  "filename:pdf",
  "(subject:(factura OR invoice OR receipt OR recibo) OR from:(billing OR invoice OR facturacion OR no-reply@stripe.com OR aws-receipts))",
  "newer_than:90d",
].join(" ");

export type GmailAttachment = {
  messageId: string;
  filename: string;
  mimeType: string;
  data: Buffer;
};

export async function listInvoiceAttachments(
  accessToken: string,
  refreshToken: string | null,
  maxMessages = 50
): Promise<GmailAttachment[]> {
  const auth = clientForUser(accessToken, refreshToken);
  const gmail = google.gmail({ version: "v1", auth });

  const list = await gmail.users.messages.list({
    userId: "me",
    q: INVOICE_QUERY,
    maxResults: maxMessages,
  });

  const out: GmailAttachment[] = [];
  const messages = list.data.messages ?? [];

  for (const m of messages) {
    if (!m.id) continue;
    const msg = await gmail.users.messages.get({
      userId: "me",
      id: m.id,
      format: "full",
    });
    const parts = flattenParts(msg.data.payload);
    for (const p of parts) {
      const filename = p.filename;
      const attId = p.body?.attachmentId;
      if (!filename || !attId) continue;
      if (!isInvoiceFile(filename, p.mimeType ?? "")) continue;

      const att = await gmail.users.messages.attachments.get({
        userId: "me",
        messageId: m.id,
        id: attId,
      });
      const dataB64 = att.data.data ?? "";
      const buf = Buffer.from(dataB64, "base64url");
      out.push({
        messageId: m.id,
        filename,
        mimeType: p.mimeType ?? "application/octet-stream",
        data: buf,
      });
    }
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
