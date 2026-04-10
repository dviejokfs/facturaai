import Anthropic from "@anthropic-ai/sdk";
import pdfParse from "pdf-parse";
import { config } from "../config";

const client = new Anthropic({ apiKey: config.ANTHROPIC_API_KEY });

export type ExtractedExpense = {
  vendor: string;
  vendorTaxId: string | null;
  client: string | null;
  clientTaxId: string | null;
  cif: string | null;
  date: string; // YYYY-MM-DD
  invoiceNumber: string | null;
  subtotal: number;
  ivaRate: number;
  ivaAmount: number;
  irpfRate: number;
  irpfAmount: number;
  total: number;
  currency: string;
  category:
    | "software"
    | "suministros"
    | "materialOficina"
    | "serviciosProfesionales"
    | "formacion"
    | "vehiculo"
    | "representacion"
    | "hosting"
    | "telefonia"
    | "otros";
  confidence: number; // 0..1
  isValidInvoice: boolean;
  isExpense: boolean; // true if expense, false if income
};

const SYSTEM_PROMPT = `You are an expert accountant extracting structured data from business invoices and receipts worldwide.

You will receive either the text of a PDF invoice or an image of a receipt. Extract the fields exactly as they appear on the document. Never invent data.

Rules:
- "vendor" is the company or person ISSUING the invoice (the seller/provider).
- "vendorTaxId" is the vendor's tax identification number (NIF, CIF, VAT number, EIN, GSTIN, etc.).
- "client" is the company or person RECEIVING the invoice (the buyer/customer). May also be labeled "bill to", "customer", "client", etc.
- "clientTaxId" is the client's tax identification number.
- "cif" is DEPRECATED — copy vendorTaxId here for backwards compatibility.
- All amounts MUST be in the original invoice currency. NEVER convert.
- "currency" MUST be a valid ISO-4217 three-letter code (EUR, USD, GBP, JPY, MXN, BRL, CAD, AUD, CHF, SEK, etc.).
- If you cannot determine the currency with high confidence, set isValidInvoice to false.
- "ivaRate" / "ivaAmount" represent the document's tax (VAT, IVA, GST, sales tax, TVA, etc.) — use 0 if no tax line.
- "irpfRate" / "irpfAmount" represent withholding (Spain IRPF, US 1099 backup withholding, etc.) — use 0 if none.
- Verify that subtotal + tax - withholding ≈ total (tolerance 0.02).
- "category" must be one of: software, suministros, materialOficina, serviciosProfesionales, formacion, vehiculo, representacion, hosting, telefonia, otros.
  - hosting: AWS, Google Cloud, Azure, OVH, Hetzner, DigitalOcean
  - software: SaaS subscriptions (Figma, Notion, Slack, Adobe, GitHub, Stripe fees)
  - telefonia: Vodafone, Movistar, Orange, Masmovil, internet providers
  - vehiculo: fuel, parking, tolls, car rental
  - representacion: business meals, client entertainment
  - serviciosProfesionales: lawyers, accountants, consultants, freelancers
  - formacion: courses, books, conferences
  - materialOficina: office supplies, equipment, furniture
  - suministros: electricity, water, gas (home office)
  - otros: anything else
- "confidence" is your overall confidence (0.0 to 1.0).
- "isValidInvoice": false if this is NOT an invoice/receipt (e.g., marketing email, bank statement, shipping notification).
- "isExpense": determines if this is an expense or income for the user. If the user's company name is provided and the vendor name matches or closely matches the user's company, this is INCOME (the user issued the invoice) so set isExpense to false. If the vendor is a different company, this is an EXPENSE (the user received the invoice) so set isExpense to true. If no user company name is provided, default to true (expense).
- Return null for fields you cannot find with reasonable confidence. Never guess invoice numbers or CIFs.

Return ONLY a valid JSON object matching the schema. No markdown, no explanation.`;

const JSON_SCHEMA_HINT = `{
  "vendor": "string (the seller/provider)",
  "vendorTaxId": "string or null (vendor's tax ID: NIF, CIF, VAT, EIN, etc.)",
  "client": "string or null (the buyer/customer)",
  "clientTaxId": "string or null (client's tax ID)",
  "cif": "string or null (same as vendorTaxId, for backwards compat)",
  "date": "YYYY-MM-DD",
  "invoiceNumber": "string or null",
  "subtotal": number,
  "ivaRate": number,
  "ivaAmount": number,
  "irpfRate": number,
  "irpfAmount": number,
  "total": number,
  "currency": "ISO-4217 code (EUR, USD, GBP, ...)",
  "category": "one of the allowed categories",
  "confidence": 0.0-1.0,
  "isValidInvoice": boolean,
  "isExpense": boolean
}`;

function parseJsonResponse(text: string): ExtractedExpense {
  // Strip markdown fences if present
  const cleaned = text.replace(/^```json\s*/i, "").replace(/```\s*$/, "").trim();
  const jsonStart = cleaned.indexOf("{");
  const jsonEnd = cleaned.lastIndexOf("}");
  if (jsonStart === -1 || jsonEnd === -1) {
    throw new Error("No JSON found in Claude response");
  }
  return JSON.parse(cleaned.slice(jsonStart, jsonEnd + 1));
}

function companyContext(companyName?: string | null): string {
  if (!companyName) return "";
  return `\n\nThe user's company name is: "${companyName}". Use this to determine the "isExpense" field — if the vendor matches this company, it's income (isExpense=false), otherwise it's an expense (isExpense=true).`;
}

export async function extractFromPdfText(pdfBuffer: Buffer, companyName?: string | null): Promise<ExtractedExpense> {
  const parsed = await pdfParse(pdfBuffer);
  const text = parsed.text.slice(0, 8000); // bound for safety

  const response = await client.messages.create({
    model: config.ANTHROPIC_MODEL,
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: `Extract the invoice data. Return JSON matching this schema:\n${JSON_SCHEMA_HINT}${companyContext(companyName)}\n\n---\n\nInvoice text:\n\n${text}`,
      },
    ],
  });

  const block = response.content[0];
  if (block.type !== "text") throw new Error("Unexpected response block type");
  return parseJsonResponse(block.text);
}

export async function extractFromImage(
  imageBuffer: Buffer,
  mediaType: "image/png" | "image/jpeg" | "image/webp",
  companyName?: string | null
): Promise<ExtractedExpense> {
  const base64 = imageBuffer.toString("base64");

  const response = await client.messages.create({
    model: config.ANTHROPIC_MODEL,
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: base64 },
          },
          {
            type: "text",
            text: `Extract the receipt data from this image. Return JSON matching this schema:\n${JSON_SCHEMA_HINT}${companyContext(companyName)}`,
          },
        ],
      },
    ],
  });

  const block = response.content[0];
  if (block.type !== "text") throw new Error("Unexpected response block type");
  return parseJsonResponse(block.text);
}

export async function extractAuto(
  buffer: Buffer,
  mimeType: string,
  companyName?: string | null
): Promise<ExtractedExpense> {
  if (mimeType === "application/pdf") {
    try {
      return await extractFromPdfText(buffer, companyName);
    } catch (err) {
      console.warn("PDF text extraction failed, falling back to vision:", err);
      // TODO: render first page to PNG and call extractFromImage
      throw err;
    }
  }
  if (mimeType.startsWith("image/")) {
    const mt = mimeType as "image/png" | "image/jpeg" | "image/webp";
    return extractFromImage(buffer, mt, companyName);
  }
  throw new Error(`Unsupported mime type: ${mimeType}`);
}
