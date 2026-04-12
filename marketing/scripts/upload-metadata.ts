#!/usr/bin/env bun
/**
 * App Store Connect Metadata Uploader
 *
 * Updates app metadata from marketing/metadata.json:
 *   - App Info: name, subtitle, privacy URL (per locale)
 *   - App Info: primary/secondary category, content rights
 *   - App Store Version: copyright, release type
 *   - App Store Version localizations: description, keywords, promotional text,
 *     marketing URL, support URL, what's new (per locale)
 *   - App Review info: contact + notes
 *
 * Usage:
 *   bun marketing/scripts/upload-metadata.ts
 *
 * Environment variables same as upload-screenshots.ts.
 *
 * Reference: https://developer.apple.com/documentation/appstoreconnectapi
 */

import jwt from "jsonwebtoken";
import { readFileSync, statSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// ── Config ────────────────────────────────────────────────────────────

const KEY_ID = process.env.ASC_KEY_ID || "P493QCZBH8";
const ISSUER_ID = process.env.ASC_ISSUER_ID || "69a6de82-4145-47e3-e053-5b8c7c11a4d1";
const KEY_PATH = process.env.ASC_KEY_PATH || join(homedir(), ".ssh/AuthKey_P493QCZBH8.p8");
const APP_BUNDLE_ID = process.env.ASC_APP_BUNDLE || "ee.blocklyne.invoscanai";

const METADATA_PATH = join(import.meta.dir, "../metadata.json");
const API_BASE = "https://api.appstoreconnect.apple.com/v1";

// ── JWT ───────────────────────────────────────────────────────────────

function generateToken(): string {
  const privateKey = readFileSync(KEY_PATH, "utf8");
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: ISSUER_ID,
      iat: now,
      exp: now + 15 * 60,
      aud: "appstoreconnect-v1",
    },
    privateKey,
    { algorithm: "ES256", header: { alg: "ES256", kid: KEY_ID, typ: "JWT" } },
  );
}

// ── Client ────────────────────────────────────────────────────────────

class ASCClient {
  token: string;
  constructor() {
    this.token = generateToken();
  }

  async request(method: string, path: string, body?: unknown): Promise<any> {
    const url = path.startsWith("http") ? path : `${API_BASE}${path}`;
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.token}`,
    };
    if (body) headers["Content-Type"] = "application/json";
    const res = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`${method} ${url} → ${res.status}\n${text}`);
    }
    if (res.status === 204) return null;
    const ct = res.headers.get("content-type") || "";
    return ct.includes("json") ? res.json() : null;
  }
}

// ── Strip comment keys (fields starting with "//") ────────────────────

function stripComments<T>(obj: T): T {
  if (!obj || typeof obj !== "object") return obj;
  if (Array.isArray(obj)) return obj.map(stripComments) as any;
  const out: any = {};
  for (const [k, v] of Object.entries(obj)) {
    if (k.startsWith("//")) continue;
    out[k] = stripComments(v);
  }
  return out;
}

// ── Main ──────────────────────────────────────────────────────────────

interface LocaleMetadata {
  name?: string;
  subtitle?: string;
  privacyPolicyUrl?: string;
  privacyChoicesUrl?: string;
  description?: string;
  keywords?: string;
  promotionalText?: string;
  marketingUrl?: string;
  supportUrl?: string;
  whatsNew?: string;
}

interface Metadata {
  app: {
    primaryCategory?: string;
    secondaryCategory?: string;
    contentRightsDeclaration?: string;
  };
  version: {
    copyright?: string;
    releaseType?: string;
  };
  localizations: Record<string, LocaleMetadata>;
  appReviewInfo: {
    contactFirstName?: string;
    contactLastName?: string;
    contactEmail?: string;
    contactPhone?: string;
    demoAccountName?: string;
    demoAccountPassword?: string;
    demoAccountRequired?: boolean;
    notes?: string;
  };
}

async function main() {
  console.log("App Store Connect Metadata Uploader\n");

  if (!statSync(METADATA_PATH, { throwIfNoEntry: false })?.isFile()) {
    console.error(`metadata.json not found at: ${METADATA_PATH}`);
    process.exit(1);
  }

  const raw = JSON.parse(readFileSync(METADATA_PATH, "utf8"));
  const metadata: Metadata = stripComments(raw);

  const client = new ASCClient();

  // ── 1. Find app ─────────────────────────────────────────────────────
  console.log(`Finding app: ${APP_BUNDLE_ID}`);
  const appRes = await client.request("GET", `/apps?filter[bundleId]=${encodeURIComponent(APP_BUNDLE_ID)}&include=appInfos,appStoreVersions&limit=200`);
  if (!appRes.data?.length) throw new Error(`App not found: ${APP_BUNDLE_ID}`);
  const app = appRes.data[0];
  const appId = app.id;
  console.log(`  ✓ ${app.attributes.name} (${appId})\n`);

  // ── 2. Find editable appInfo (app-level metadata) ───────────────────
  console.log("Finding editable app info...");
  const appInfosRes = await client.request(
    "GET",
    `/apps/${appId}/appInfos?limit=10&include=appInfoLocalizations`,
  );
  const editableAppInfo = appInfosRes.data.find((info: any) =>
    ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"].includes(
      info.attributes.state,
    ),
  );
  if (!editableAppInfo) throw new Error("No editable appInfo found");
  console.log(`  ✓ appInfo ${editableAppInfo.id} (${editableAppInfo.attributes.state})\n`);

  // ── 3a. Update appInfo categories ───────────────────────────────────
  console.log("Updating app categories...");
  const appInfoRels: any = {};
  if (metadata.app.primaryCategory) {
    appInfoRels.primaryCategory = {
      data: { type: "appCategories", id: metadata.app.primaryCategory },
    };
  }
  if (metadata.app.secondaryCategory) {
    appInfoRels.secondaryCategory = {
      data: { type: "appCategories", id: metadata.app.secondaryCategory },
    };
  }
  if (Object.keys(appInfoRels).length > 0) {
    await client.request("PATCH", `/appInfos/${editableAppInfo.id}`, {
      data: {
        type: "appInfos",
        id: editableAppInfo.id,
        relationships: appInfoRels,
      },
    });
    console.log(`  ✓ category: ${metadata.app.primaryCategory} / ${metadata.app.secondaryCategory}`);
  }

  // ── 3b. Update content rights on the app resource ───────────────────
  if (metadata.app.contentRightsDeclaration) {
    await client.request("PATCH", `/apps/${appId}`, {
      data: {
        type: "apps",
        id: appId,
        attributes: { contentRightsDeclaration: metadata.app.contentRightsDeclaration },
      },
    });
    console.log(`  ✓ content rights: ${metadata.app.contentRightsDeclaration}`);
  }
  console.log("");

  // ── 4. Upsert appInfo localizations (name, subtitle, privacy URL) ───
  console.log("Updating app info localizations...");
  const appInfoLocsRes = await client.request(
    "GET",
    `/appInfos/${editableAppInfo.id}/appInfoLocalizations?limit=50`,
  );
  const appInfoLocsByLocale = new Map<string, string>(
    appInfoLocsRes.data.map((l: any) => [l.attributes.locale, l.id]),
  );

  for (const [locale, loc] of Object.entries(metadata.localizations)) {
    const attrs: any = {};
    if (loc.name !== undefined) attrs.name = loc.name;
    if (loc.subtitle !== undefined) attrs.subtitle = loc.subtitle;
    if (loc.privacyPolicyUrl !== undefined) attrs.privacyPolicyUrl = loc.privacyPolicyUrl;
    if (loc.privacyChoicesUrl !== undefined) attrs.privacyChoicesUrl = loc.privacyChoicesUrl;

    if (Object.keys(attrs).length === 0) continue;

    const existingId = appInfoLocsByLocale.get(locale);
    if (existingId) {
      await client.request("PATCH", `/appInfoLocalizations/${existingId}`, {
        data: { type: "appInfoLocalizations", id: existingId, attributes: attrs },
      });
      console.log(`  ✓ [${locale}] updated name/subtitle/privacy`);
    } else {
      await client.request("POST", "/appInfoLocalizations", {
        data: {
          type: "appInfoLocalizations",
          attributes: { locale, ...attrs },
          relationships: {
            appInfo: { data: { type: "appInfos", id: editableAppInfo.id } },
          },
        },
      });
      console.log(`  ✓ [${locale}] created name/subtitle/privacy`);
    }
  }

  // ── 5. Find editable AppStoreVersion ────────────────────────────────
  console.log("\nFinding editable app version...");
  const versionRes = await client.request(
    "GET",
    `/apps/${appId}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,INVALID_BINARY,WAITING_FOR_REVIEW&limit=1`,
  );
  if (!versionRes.data?.length) throw new Error("No editable app version found");
  const version = versionRes.data[0];
  console.log(`  ✓ v${version.attributes.versionString} (${version.attributes.appStoreState})\n`);

  // ── 6. Update version-level fields (copyright, releaseType) ─────────
  console.log("Updating version attributes...");
  const versionAttrs: any = {};
  if (metadata.version.copyright) versionAttrs.copyright = metadata.version.copyright;
  if (metadata.version.releaseType) versionAttrs.releaseType = metadata.version.releaseType;
  if (Object.keys(versionAttrs).length > 0) {
    await client.request("PATCH", `/appStoreVersions/${version.id}`, {
      data: { type: "appStoreVersions", id: version.id, attributes: versionAttrs },
    });
    console.log(`  ✓ copyright: ${metadata.version.copyright}`);
    console.log(`  ✓ releaseType: ${metadata.version.releaseType}\n`);
  }

  // ── 7. Upsert version localizations (description, keywords, etc.) ───
  console.log("Updating version localizations...");
  const versionLocsRes = await client.request(
    "GET",
    `/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`,
  );
  const versionLocsByLocale = new Map<string, string>(
    versionLocsRes.data.map((l: any) => [l.attributes.locale, l.id]),
  );

  // "whatsNew" can't be edited on the initial release of an app
  const isFirstRelease = version.attributes.versionString === "1.0";

  for (const [locale, loc] of Object.entries(metadata.localizations)) {
    const attrs: any = {};
    if (loc.description !== undefined) attrs.description = loc.description;
    if (loc.keywords !== undefined) attrs.keywords = loc.keywords;
    if (loc.promotionalText !== undefined) attrs.promotionalText = loc.promotionalText;
    if (loc.marketingUrl !== undefined) attrs.marketingUrl = loc.marketingUrl;
    if (loc.supportUrl !== undefined) attrs.supportUrl = loc.supportUrl;
    if (loc.whatsNew !== undefined && !isFirstRelease) attrs.whatsNew = loc.whatsNew;

    if (Object.keys(attrs).length === 0) continue;

    const existingId = versionLocsByLocale.get(locale);
    if (existingId) {
      await client.request("PATCH", `/appStoreVersionLocalizations/${existingId}`, {
        data: { type: "appStoreVersionLocalizations", id: existingId, attributes: attrs },
      });
      console.log(`  ✓ [${locale}] updated description/keywords/promo`);
    } else {
      await client.request("POST", "/appStoreVersionLocalizations", {
        data: {
          type: "appStoreVersionLocalizations",
          attributes: { locale, ...attrs },
          relationships: {
            appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
          },
        },
      });
      console.log(`  ✓ [${locale}] created description/keywords/promo`);
    }
  }

  if (isFirstRelease) {
    console.log("  ℹ 'whatsNew' skipped (first release — not editable until v1.1+)");
  }

  // ── 8. App Review info (contact + notes) ────────────────────────────
  console.log("\nUpdating App Review info...");
  const reviewInfoRes = await client.request(
    "GET",
    `/appStoreVersions/${version.id}/appStoreReviewDetail`,
  );
  const reviewAttrs = {
    contactFirstName: metadata.appReviewInfo.contactFirstName,
    contactLastName: metadata.appReviewInfo.contactLastName,
    contactEmail: metadata.appReviewInfo.contactEmail,
    contactPhone: metadata.appReviewInfo.contactPhone,
    demoAccountName: metadata.appReviewInfo.demoAccountName || null,
    demoAccountPassword: metadata.appReviewInfo.demoAccountPassword || null,
    demoAccountRequired: metadata.appReviewInfo.demoAccountRequired ?? false,
    notes: metadata.appReviewInfo.notes,
  };
  if (reviewInfoRes?.data?.id) {
    await client.request("PATCH", `/appStoreReviewDetails/${reviewInfoRes.data.id}`, {
      data: {
        type: "appStoreReviewDetails",
        id: reviewInfoRes.data.id,
        attributes: reviewAttrs,
      },
    });
    console.log(`  ✓ updated review contact & notes`);
  } else {
    await client.request("POST", "/appStoreReviewDetails", {
      data: {
        type: "appStoreReviewDetails",
        attributes: reviewAttrs,
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
        },
      },
    });
    console.log(`  ✓ created review contact & notes`);
  }

  console.log("\n✨ Metadata upload complete!");
  console.log(`   App: ${app.attributes.name}`);
  console.log(`   Version: ${version.attributes.versionString}`);
  console.log(`   Locales: ${Object.keys(metadata.localizations).join(", ")}`);
  console.log("\n⚠️  Note: Age rating must still be set manually in App Store Connect —");
  console.log("   the API doesn't support it. Screenshots, pricing, and build selection");
  console.log("   also stay where they are.");
}

main().catch((err) => {
  console.error("\n❌ Error:", err.message);
  process.exit(1);
});
