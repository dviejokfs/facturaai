import { z } from "zod";

const schema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  PUBLIC_URL: z.string().url().default("http://localhost:3000"),

  DATABASE_URL: z.string().url(),

  JWT_SECRET: z.string().min(32),

  GOOGLE_CLIENT_ID: z.string(),
  GOOGLE_CLIENT_SECRET: z.string(),
  GOOGLE_REDIRECT_URI: z.string().url(),
  IOS_REDIRECT_SCHEME: z.string().default("facturaai://auth"),

  ANTHROPIC_API_KEY: z.string(),
  ANTHROPIC_MODEL: z.string().default("claude-sonnet-4-5-20250929"),

  S3_ENDPOINT: z.string().url().optional(),
  S3_REGION: z.string().default("auto"),
  S3_BUCKET: z.string(),
  S3_ACCESS_KEY_ID: z.string().optional(),
  S3_SECRET_ACCESS_KEY: z.string().optional(),
});

// Bun loads .env automatically
export const config = schema.parse(process.env);
export type Config = z.infer<typeof schema>;
