import { z } from "zod";

const schema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  PUBLIC_URL: z.string().url().default("http://localhost:3000"),

  POSTGRES_URL: z.string().url(),

  JWT_SECRET: z.string().min(32),

  GOOGLE_CLIENT_ID: z.string(),
  GOOGLE_CLIENT_SECRET: z.string(),
  GOOGLE_REDIRECT_URI: z.string().url(),
  IOS_REDIRECT_SCHEME: z.string().default("invoscanai://auth"),

  // AI Gateway (OpenAI-compatible — Temps auto-injects TEMPS_API_TOKEN)
  AI_GATEWAY_URL: z.string().url().default("https://app.temps.kfs.es/api/ai/v1"),
  TEMPS_API_TOKEN: z.string().default(""),
  AI_MODEL: z.string().default("claude-sonnet-4-6"),

  // S3 storage (accepts Temps blob injection: BLOB_ENDPOINT, BLOB_ACCESS_KEY, BLOB_SECRET_KEY)
  S3_ENDPOINT: z.string().url().optional(),
  BLOB_ENDPOINT: z.string().url().optional(),
  S3_REGION: z.string().default("auto"),
  S3_BUCKET: z.string(),
  S3_ACCESS_KEY_ID: z.string().optional(),
  BLOB_ACCESS_KEY: z.string().optional(),
  S3_SECRET_ACCESS_KEY: z.string().optional(),
  BLOB_SECRET_KEY: z.string().optional(),

  // RevenueCat — populated AFTER you sign up and create the InvoScanAI project.
  // Public SDK key is consumed by the iOS app via APIClient.config.
  // Secret API key + webhook secret are server-only.
  REVENUECAT_PUBLIC_SDK_KEY_IOS: z.string().default(""),
  REVENUECAT_SECRET_API_KEY: z.string().default(""),
  REVENUECAT_WEBHOOK_SECRET: z.string().default(""),
  REVENUECAT_PROJECT_ID: z.string().default(""),

  // APNs Push Notifications
  APNS_KEY_ID: z.string().default(""),
  APNS_TEAM_ID: z.string().default(""),
  APNS_BUNDLE_ID: z.string().default("ee.blocklyne.invoscanai"),
  APNS_KEY_P8: z.string().default(""), // .p8 key content (inline, base64, or raw PEM)
  APNS_ENVIRONMENT: z.enum(["development", "production"]).default("development"),

  // Google Cloud Pub/Sub (Gmail push notifications)
  GOOGLE_CLOUD_PROJECT: z.string().default(""),

  // Temps email service
  TEMPS_API_URL: z.string().url().optional(),
  TEMPS_DEPLOYMENT_TOKEN: z.string().default(""),
});

// Bun loads .env automatically
export const config = schema.parse(process.env);
export type Config = z.infer<typeof schema>;
