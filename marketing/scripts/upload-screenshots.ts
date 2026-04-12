#!/usr/bin/env bun
/**
 * App Store Connect Screenshot Uploader
 *
 * Uploads framed screenshots to App Store Connect for the InvoScanAI app.
 *
 * Usage:
 *   bun marketing/scripts/upload-screenshots.ts
 *
 * Environment variables (or edit constants below):
 *   ASC_KEY_ID       — App Store Connect API Key ID (e.g., P493QCZBH8)
 *   ASC_ISSUER_ID    — App Store Connect Issuer ID (UUID)
 *   ASC_KEY_PATH     — Path to the .p8 private key file
 *   ASC_APP_BUNDLE   — App bundle ID (default: ee.blocklyne.invoscanai)
 *
 * Reference:
 *   https://developer.apple.com/documentation/appstoreconnectapi
 */

import jwt from "jsonwebtoken";
import { readFileSync, readdirSync, statSync } from "fs";
import { createHash } from "crypto";
import { join, basename } from "path";
import { homedir } from "os";

// ── Config ────────────────────────────────────────────────────────────

const KEY_ID = process.env.ASC_KEY_ID || "P493QCZBH8";
const ISSUER_ID = process.env.ASC_ISSUER_ID || "69a6de82-4145-47e3-e053-5b8c7c11a4d1";
const KEY_PATH = process.env.ASC_KEY_PATH || join(homedir(), ".ssh/AuthKey_P493QCZBH8.p8");
const APP_BUNDLE_ID = process.env.ASC_APP_BUNDLE || "ee.blocklyne.invoscanai";

const FRAMED_DIR = join(import.meta.dir, "../screenshots/framed");
const API_BASE = "https://api.appstoreconnect.apple.com/v1";

// Map raw device-dir names to App Store Connect display type and locale mapping
interface DeviceMap {
  displayType: string; // ASC screenshotDisplayType enum
  matches: (dir: string) => boolean;
}

const DEVICE_MAPS: DeviceMap[] = [
  {
    // iPhone 6.7" / 6.9" display type (iPhone 17 Pro Max screenshots are 1320x2868)
    displayType: "APP_IPHONE_67",
    matches: (dir) => dir.includes("Pro_Max"),
  },
  {
    // iPhone 6.1" / 6.3" display type (iPhone 17 Pro screenshots are 1206x2622)
    displayType: "APP_IPHONE_61",
    matches: (dir) => dir.includes("iPhone") && !dir.includes("Pro_Max"),
  },
  {
    // iPad Pro 13" — ASC uses the 12.9" 3rd gen display type
    displayType: "APP_IPAD_PRO_3GEN_129",
    matches: (dir) => dir.includes("iPad"),
  },
];

// Map directory locale to ASC locale string
const LOCALE_MAP: Record<string, string> = {
  en: "en-US",
  es: "es-ES",
};

// ── JWT Auth ──────────────────────────────────────────────────────────

function generateToken(): string {
  const privateKey = readFileSync(KEY_PATH, "utf8");
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: ISSUER_ID,
      iat: now,
      exp: now + 15 * 60, // 15 min max per Apple docs
      aud: "appstoreconnect-v1",
    },
    privateKey,
    {
      algorithm: "ES256",
      header: { alg: "ES256", kid: KEY_ID, typ: "JWT" },
    },
  );
}

// ── API Client ────────────────────────────────────────────────────────

class ASCClient {
  token: string;

  constructor() {
    this.token = generateToken();
  }

  async request(method: string, path: string, body?: unknown, extraHeaders: Record<string, string> = {}): Promise<any> {
    const url = path.startsWith("http") ? path : `${API_BASE}${path}`;
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.token}`,
      ...extraHeaders,
    };
    if (body && !(body instanceof Uint8Array) && !(body instanceof ArrayBuffer)) {
      headers["Content-Type"] = "application/json";
    }
    const res = await fetch(url, {
      method,
      headers,
      body:
        body instanceof Uint8Array || body instanceof ArrayBuffer
          ? (body as BodyInit)
          : body
            ? JSON.stringify(body)
            : undefined,
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`${method} ${url} → ${res.status}: ${text}`);
    }
    if (res.status === 204) return null;
    const contentType = res.headers.get("content-type") || "";
    if (contentType.includes("application/json")) return res.json();
    return null;
  }

  async findApp(bundleId: string): Promise<{ id: string; name: string }> {
    const res = await this.request("GET", `/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
    if (!res.data || res.data.length === 0) {
      throw new Error(`No app found with bundle ID: ${bundleId}`);
    }
    const app = res.data[0];
    return { id: app.id, name: app.attributes.name };
  }

  async findEditableVersion(appId: string): Promise<{ id: string; version: string; state: string }> {
    // Look for a version in an editable state (PREPARE_FOR_SUBMISSION, etc.)
    const res = await this.request(
      "GET",
      `/apps/${appId}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,INVALID_BINARY,WAITING_FOR_REVIEW&limit=1`,
    );
    if (!res.data || res.data.length === 0) {
      throw new Error(
        "No editable app version found. Create a new version in App Store Connect first.",
      );
    }
    const v = res.data[0];
    return { id: v.id, version: v.attributes.versionString, state: v.attributes.appStoreState };
  }

  async getLocalizations(versionId: string): Promise<Array<{ id: string; locale: string }>> {
    const res = await this.request("GET", `/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=50`);
    return res.data.map((d: any) => ({ id: d.id, locale: d.attributes.locale }));
  }

  async createLocalization(versionId: string, locale: string): Promise<string> {
    const res = await this.request("POST", "/appStoreVersionLocalizations", {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: { locale },
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: versionId } },
        },
      },
    });
    return res.data.id;
  }

  async getOrCreateScreenshotSet(localizationId: string, displayType: string): Promise<string> {
    const res = await this.request(
      "GET",
      `/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`,
    );
    const existing = res.data.find((d: any) => d.attributes.screenshotDisplayType === displayType);
    if (existing) return existing.id;

    const created = await this.request("POST", "/appScreenshotSets", {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: displayType },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: localizationId },
          },
        },
      },
    });
    return created.data.id;
  }

  async deleteExistingScreenshots(screenshotSetId: string): Promise<void> {
    const res = await this.request(
      "GET",
      `/appScreenshotSets/${screenshotSetId}/appScreenshots?limit=50`,
    );
    for (const s of res.data || []) {
      await this.request("DELETE", `/appScreenshots/${s.id}`);
    }
  }

  async uploadScreenshot(
    screenshotSetId: string,
    fileName: string,
    bytes: Buffer,
  ): Promise<void> {
    // Step 1: Reserve
    const reserve = await this.request("POST", "/appScreenshots", {
      data: {
        type: "appScreenshots",
        attributes: {
          fileName,
          fileSize: bytes.length,
        },
        relationships: {
          appScreenshotSet: { data: { type: "appScreenshotSets", id: screenshotSetId } },
        },
      },
    });

    const screenshotId = reserve.data.id;
    const uploadOps: Array<{
      method: string;
      url: string;
      length: number;
      offset: number;
      requestHeaders: Array<{ name: string; value: string }>;
    }> = reserve.data.attributes.uploadOperations;

    // Step 2: Upload chunks
    for (const op of uploadOps) {
      const chunk = new Uint8Array(bytes.buffer, bytes.byteOffset + op.offset, op.length);
      const headers: Record<string, string> = {};
      for (const h of op.requestHeaders) {
        headers[h.name] = h.value;
      }
      const res = await fetch(op.url, { method: op.method, headers, body: chunk });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`Chunk upload failed: ${res.status} ${text}`);
      }
    }

    // Step 3: Commit with MD5
    const md5 = createHash("md5").update(bytes).digest("hex");
    await this.request("PATCH", `/appScreenshots/${screenshotId}`, {
      data: {
        type: "appScreenshots",
        id: screenshotId,
        attributes: {
          uploaded: true,
          sourceFileChecksum: md5,
        },
      },
    });
  }
}

// ── Main ──────────────────────────────────────────────────────────────

async function main() {
  console.log("App Store Connect Screenshot Uploader\n");

  if (!statSync(FRAMED_DIR, { throwIfNoEntry: false })?.isDirectory()) {
    console.error(`Framed screenshots not found at: ${FRAMED_DIR}`);
    console.error("Run 'bun marketing/scripts/frame-screenshots.ts' first.");
    process.exit(1);
  }

  if (!statSync(KEY_PATH, { throwIfNoEntry: false })?.isFile()) {
    console.error(`API key not found at: ${KEY_PATH}`);
    process.exit(1);
  }

  const client = new ASCClient();

  console.log(`Finding app with bundle ID: ${APP_BUNDLE_ID}`);
  const app = await client.findApp(APP_BUNDLE_ID);
  console.log(`  ✓ ${app.name} (${app.id})\n`);

  console.log("Finding editable app version...");
  const version = await client.findEditableVersion(app.id);
  console.log(`  ✓ v${version.version} (${version.state})\n`);

  console.log("Loading localizations...");
  const existingLocs = await client.getLocalizations(version.id);
  const locsById = new Map(existingLocs.map((l) => [l.locale, l.id]));
  console.log(`  ✓ ${existingLocs.length} localizations: ${existingLocs.map((l) => l.locale).join(", ")}\n`);

  // Iterate device dirs
  const deviceDirs = readdirSync(FRAMED_DIR).filter((d) => statSync(join(FRAMED_DIR, d)).isDirectory());

  let totalUploaded = 0;

  for (const deviceDir of deviceDirs) {
    const deviceMap = DEVICE_MAPS.find((m) => m.matches(deviceDir));
    if (!deviceMap) {
      console.log(`⏭ Skipping ${deviceDir} — no display type mapping`);
      continue;
    }

    const langDirs = readdirSync(join(FRAMED_DIR, deviceDir)).filter((d) =>
      statSync(join(FRAMED_DIR, deviceDir, d)).isDirectory(),
    );

    for (const lang of langDirs) {
      const locale = LOCALE_MAP[lang];
      if (!locale) {
        console.log(`⏭ Skipping lang ${lang} — no locale mapping`);
        continue;
      }

      // Ensure localization exists
      let localizationId = locsById.get(locale);
      if (!localizationId) {
        console.log(`  Creating localization: ${locale}`);
        localizationId = await client.createLocalization(version.id, locale);
        locsById.set(locale, localizationId);
      }

      console.log(`\n▶ ${deviceMap.displayType} / ${locale}`);

      // Get or create screenshot set, then clear existing screenshots
      const setId = await client.getOrCreateScreenshotSet(localizationId, deviceMap.displayType);
      await client.deleteExistingScreenshots(setId);

      // Upload each screenshot in filename order
      const inputDir = join(FRAMED_DIR, deviceDir, lang);
      const files = readdirSync(inputDir)
        .filter((f) => f.endsWith(".png"))
        .sort();

      for (const file of files) {
        const path = join(inputDir, file);
        const bytes = readFileSync(path);
        await client.uploadScreenshot(setId, file, bytes);
        console.log(`  ✓ ${file} (${(bytes.length / 1024).toFixed(0)} KB)`);
        totalUploaded++;
      }
    }
  }

  console.log(`\n✨ Done! Uploaded ${totalUploaded} screenshots to App Store Connect.`);
  console.log(`   App: ${app.name}  |  Version: ${version.version}`);
}

main().catch((err) => {
  console.error("\n❌ Error:", err.message);
  process.exit(1);
});
