import { TempsClient } from "@temps-sdk/node-sdk";

const temps = new TempsClient({
  baseUrl: process.env.TEMPS_API_URL!,
  apiKey: process.env.TEMPS_DEPLOYMENT_TOKEN!,
});

const FROM_ADDRESS = "noreply@kfsoft.tech";
const FROM_NAME = "InvoScanAI";

/** Send a welcome email after first sign-up. */
export async function sendWelcomeEmail(to: string, name: string | null) {
  const displayName = name || "there";
  await temps.email.send({
    body: {
      from: FROM_ADDRESS,
      from_name: FROM_NAME,
      to: [to],
      subject: "¡Bienvenido a InvoScanAI!",
      html: welcomeHtml(displayName),
      text: welcomeText(displayName),
      tags: ["welcome"],
    },
  });
}

/** Send an export share link to the accountant. */
export async function sendExportEmail(opts: {
  to: string;
  accountantName: string | null;
  senderName: string | null;
  companyName: string | null;
  quarter: string;
  shareUrl: string;
  expiresAt: string;
}) {
  const recipient = opts.accountantName || opts.to;
  const sender = opts.companyName || opts.senderName || "Un cliente";
  const expiryDate = new Date(opts.expiresAt).toLocaleDateString("es-ES", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  await temps.email.send({
    body: {
      from: FROM_ADDRESS,
      from_name: FROM_NAME,
      to: [opts.to],
      subject: `Exportación de facturas ${opts.quarter} — ${sender}`,
      html: exportHtml(recipient, sender, opts.quarter, opts.shareUrl, expiryDate),
      text: exportText(recipient, sender, opts.quarter, opts.shareUrl, expiryDate),
      tags: ["export-share"],
    },
  });
}

// ── HTML templates ─────────────────────────────────────────────────────────

function welcomeHtml(name: string): string {
  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#f5f5f5">
  <div style="max-width:560px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.06)">
    <div style="background:linear-gradient(135deg,#6366f1,#a855f7);padding:32px;text-align:center">
      <h1 style="color:#fff;margin:0;font-size:24px">¡Bienvenido a InvoScanAI!</h1>
    </div>
    <div style="padding:32px">
      <p style="font-size:16px;color:#333">Hola ${name},</p>
      <p style="font-size:15px;color:#555;line-height:1.6">
        Tu cuenta está lista. Con InvoScanAI puedes escanear facturas con IA,
        clasificarlas automáticamente y exportarlas para tu gestor.
      </p>
      <p style="font-size:15px;color:#555;line-height:1.6"><strong>Primeros pasos:</strong></p>
      <ol style="font-size:15px;color:#555;line-height:1.8">
        <li>Escanea tu primera factura con la cámara</li>
        <li>Revisa los datos extraídos por la IA</li>
        <li>Exporta tu trimestre en CSV, XLSX o ZIP</li>
      </ol>
      <p style="font-size:15px;color:#555;line-height:1.6">
        Tu plan incluye <strong>5 escaneos gratis al mes</strong>. Si necesitas más,
        puedes pasar a Pro desde la app.
      </p>
      <p style="font-size:13px;color:#999;margin-top:32px">
        — El equipo de InvoScanAI<br>
        <a href="mailto:info@kungfusoftware.es" style="color:#6366f1">info@kungfusoftware.es</a>
      </p>
    </div>
  </div>
</body>
</html>`;
}

function welcomeText(name: string): string {
  return `¡Bienvenido a InvoScanAI!

Hola ${name},

Tu cuenta está lista. Con InvoScanAI puedes escanear facturas con IA, clasificarlas automáticamente y exportarlas para tu gestor.

Primeros pasos:
1. Escanea tu primera factura con la cámara
2. Revisa los datos extraídos por la IA
3. Exporta tu trimestre en CSV, XLSX o ZIP

Tu plan incluye 5 escaneos gratis al mes. Si necesitas más, puedes pasar a Pro desde la app.

— El equipo de InvoScanAI
info@kungfusoftware.es`;
}

function exportHtml(
  recipient: string,
  sender: string,
  quarter: string,
  url: string,
  expiryDate: string,
): string {
  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#f5f5f5">
  <div style="max-width:560px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.06)">
    <div style="background:linear-gradient(135deg,#6366f1,#a855f7);padding:32px;text-align:center">
      <h1 style="color:#fff;margin:0;font-size:22px">Exportación de facturas</h1>
    </div>
    <div style="padding:32px">
      <p style="font-size:16px;color:#333">Hola ${recipient},</p>
      <p style="font-size:15px;color:#555;line-height:1.6">
        <strong>${sender}</strong> ha compartido contigo la exportación de facturas
        del <strong>${quarter}</strong>.
      </p>
      <p style="font-size:15px;color:#555;line-height:1.6">
        El archivo ZIP incluye:
      </p>
      <ul style="font-size:15px;color:#555;line-height:1.8">
        <li>CSV localizado y universal (EN)</li>
        <li>Excel con desglose por divisa</li>
        <li>Facturas originales (PDF/imágenes)</li>
      </ul>
      <div style="text-align:center;margin:28px 0">
        <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#6366f1,#a855f7);color:#fff;text-decoration:none;padding:14px 32px;border-radius:8px;font-size:16px;font-weight:600">
          Descargar exportación
        </a>
      </div>
      <p style="font-size:13px;color:#999;text-align:center">
        Este enlace caduca el ${expiryDate}.
      </p>
      <p style="font-size:13px;color:#999;margin-top:32px">
        Enviado a través de <a href="https://invoscanai.com" style="color:#6366f1">InvoScanAI</a>
      </p>
    </div>
  </div>
</body>
</html>`;
}

function exportText(
  recipient: string,
  sender: string,
  quarter: string,
  url: string,
  expiryDate: string,
): string {
  return `Hola ${recipient},

${sender} ha compartido contigo la exportación de facturas del ${quarter}.

El archivo ZIP incluye:
- CSV localizado y universal (EN)
- Excel con desglose por divisa
- Facturas originales (PDF/imágenes)

Descargar: ${url}

Este enlace caduca el ${expiryDate}.

Enviado a través de InvoScanAI — https://invoscanai.com`;
}
