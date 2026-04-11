#!/usr/bin/env bun
/**
 * App Store Screenshot Framer
 *
 * Takes raw simulator screenshots and produces framed versions with:
 *   - Gradient background (brand colors)
 *   - Bold headline text above the screenshot
 *   - Rounded screenshot with subtle shadow
 *
 * Usage:
 *   bun marketing/scripts/frame-screenshots.ts
 *
 * Input:  marketing/screenshots/raw/{device}/{lang}/{screen}.png
 * Output: marketing/screenshots/framed/{device}/{lang}/{screen}.png
 */

import { chromium } from "playwright";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync } from "fs";
import { join, basename } from "path";

const ROOT = join(import.meta.dir, "..");
const RAW_DIR = join(ROOT, "screenshots/raw");
const OUT_DIR = join(ROOT, "screenshots/framed");

// ── Headlines per screenshot per language ─────────────────────────────

const headlines: Record<string, Record<string, string>> = {
  "01_Dashboard": {
    en: "Your invoices.\nAt a glance.",
    es: "Tus facturas.\nDe un vistazo.",
  },
  "02_Dashboard_Charts": {
    en: "Spending insights.\nAutomatically.",
    es: "Análisis de gastos.\nAutomático.",
  },
  "03_Invoices": {
    en: "Every invoice.\nOrganized.",
    es: "Cada factura.\nOrganizada.",
  },
  "04_Export": {
    en: "One ZIP your\naccountant loves.",
    es: "Un ZIP que tu\ngestor agradece.",
  },
  "05_Settings": {
    en: "Gmail sync.\nConnected.",
    es: "Sincronización Gmail.\nConectada.",
  },
};

// ── App Store required sizes ──────────────────────────────────────────

interface DeviceSpec {
  width: number;
  height: number;
  screenshotScale: number; // how much to scale the screenshot relative to frame width
  cornerRadius: number;
  fontSize: number;
}

// Map device directory name patterns to output specs
function getDeviceSpec(deviceDir: string): DeviceSpec {
  if (deviceDir.includes("Pro_Max")) {
    // 6.9" — App Store: 1320 × 2868
    return { width: 1320, height: 2868, screenshotScale: 0.82, cornerRadius: 40, fontSize: 72 };
  }
  if (deviceDir.includes("iPhone")) {
    // 6.3" — App Store: 1206 × 2622
    return { width: 1206, height: 2622, screenshotScale: 0.82, cornerRadius: 36, fontSize: 66 };
  }
  // iPad 13" — App Store: 2064 × 2752
  return { width: 2064, height: 2752, screenshotScale: 0.75, cornerRadius: 24, fontSize: 80 };
}

// ── HTML Template ─────────────────────────────────────────────────────

function buildHTML(
  spec: DeviceSpec,
  headline: string,
  screenshotBase64: string,
): string {
  const headlineHTML = headline.replace(/\n/g, "<br>");

  return `<!DOCTYPE html>
<html>
<head>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    width: ${spec.width}px;
    height: ${spec.height}px;
    overflow: hidden;
    font-family: -apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif;
    background: linear-gradient(165deg, #312e81 0%, #6d28d9 40%, #7c3aed 60%, #8b5cf6 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .headline {
    color: #ffffff;
    font-size: ${spec.fontSize}px;
    font-weight: 700;
    text-align: center;
    line-height: 1.2;
    padding-top: ${Math.round(spec.height * 0.06)}px;
    padding-bottom: ${Math.round(spec.height * 0.03)}px;
    letter-spacing: -0.5px;
    text-shadow: 0 2px 20px rgba(0,0,0,0.15);
  }

  .screenshot-container {
    flex: 1;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    overflow: hidden;
  }

  .screenshot {
    width: ${Math.round(spec.width * spec.screenshotScale)}px;
    border-radius: ${spec.cornerRadius}px;
    box-shadow:
      0 20px 60px rgba(0,0,0,0.3),
      0 8px 20px rgba(0,0,0,0.2);
  }
</style>
</head>
<body>
  <div class="headline">${headlineHTML}</div>
  <div class="screenshot-container">
    <img class="screenshot" src="data:image/png;base64,${screenshotBase64}" />
  </div>
</body>
</html>`;
}

// ── Main ──────────────────────────────────────────────────────────────

async function main() {
  if (!existsSync(RAW_DIR)) {
    console.error("No raw screenshots found. Run capture-screenshots.sh first.");
    process.exit(1);
  }

  const browser = await chromium.launch();
  let count = 0;

  // Iterate device dirs
  const deviceDirs = readdirSync(RAW_DIR).filter((d) =>
    statSync(join(RAW_DIR, d)).isDirectory()
  );

  for (const deviceDir of deviceDirs) {
    const spec = getDeviceSpec(deviceDir);
    const langDirs = readdirSync(join(RAW_DIR, deviceDir)).filter((d) =>
      statSync(join(RAW_DIR, deviceDir, d)).isDirectory()
    );

    for (const lang of langDirs) {
      const inputDir = join(RAW_DIR, deviceDir, lang);
      const outputDir = join(OUT_DIR, deviceDir, lang);
      mkdirSync(outputDir, { recursive: true });

      const screenshots = readdirSync(inputDir).filter((f) =>
        f.endsWith(".png")
      );

      for (const file of screenshots) {
        const screenName = basename(file, ".png");
        const headlineMap = headlines[screenName];
        if (!headlineMap) {
          console.log(`  ⏭ ${screenName} — no headline configured, skipping`);
          continue;
        }

        const headline = headlineMap[lang] || headlineMap["en"];
        const inputPath = join(inputDir, file);
        const outputPath = join(outputDir, file);

        const imgBase64 = readFileSync(inputPath).toString("base64");
        const html = buildHTML(spec, headline, imgBase64);
        const page = await browser.newPage({
          viewport: { width: spec.width, height: spec.height },
          deviceScaleFactor: 1,
        });
        await page.setContent(html, { waitUntil: "load" });
        // Small delay for image rendering
        await page.waitForTimeout(500);
        await page.screenshot({ path: outputPath, type: "png" });
        await page.close();

        count++;
        console.log(`  ✓ ${deviceDir}/${lang}/${screenName}`);
      }
    }
  }

  await browser.close();
  console.log(`\nDone! ${count} framed screenshots in: ${OUT_DIR}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
