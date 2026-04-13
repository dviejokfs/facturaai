import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  HeadBucketCommand,
  CreateBucketCommand,
} from "@aws-sdk/client-s3";
import { config } from "../config";

const endpoint = config.S3_ENDPOINT ?? config.BLOB_ENDPOINT;
const accessKey = config.S3_ACCESS_KEY_ID ?? config.BLOB_ACCESS_KEY;
const secretKey = config.S3_SECRET_ACCESS_KEY ?? config.BLOB_SECRET_KEY;

const s3 = new S3Client({
  region: config.S3_REGION,
  endpoint,
  credentials:
    accessKey && secretKey
      ? { accessKeyId: accessKey, secretAccessKey: secretKey }
      : undefined,
  forcePathStyle: !!endpoint,
});

/**
 * Ensures the configured bucket exists. Safe to call at startup — creates it
 * lazily if missing (common on fresh Temps/MinIO blob services). Logs and
 * swallows errors so a misconfigured S3 doesn't crash the API.
 */
export async function ensureBucket(): Promise<void> {
  try {
    await s3.send(new HeadBucketCommand({ Bucket: config.S3_BUCKET }));
    console.log(`[storage] bucket ready: ${config.S3_BUCKET}`);
  } catch (err: any) {
    const code = err?.$metadata?.httpStatusCode;
    if (code === 404 || err?.name === "NotFound" || err?.Code === "NoSuchBucket") {
      try {
        await s3.send(new CreateBucketCommand({ Bucket: config.S3_BUCKET }));
        console.log(`[storage] created bucket: ${config.S3_BUCKET}`);
      } catch (createErr) {
        console.warn(`[storage] failed to create bucket ${config.S3_BUCKET}:`, createErr);
      }
    } else {
      console.warn(`[storage] bucket check failed (continuing):`, err);
    }
  }
}

export async function uploadFile(
  key: string,
  body: Buffer | Uint8Array,
  contentType: string
): Promise<string> {
  await s3.send(
    new PutObjectCommand({
      Bucket: config.S3_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
    })
  );
  return key;
}

export async function downloadFile(key: string): Promise<Buffer> {
  const res = await s3.send(
    new GetObjectCommand({ Bucket: config.S3_BUCKET, Key: key })
  );
  const bytes = await res.Body!.transformToByteArray();
  return Buffer.from(bytes);
}

export async function deleteFile(key: string): Promise<void> {
  await s3.send(
    new DeleteObjectCommand({ Bucket: config.S3_BUCKET, Key: key })
  );
}

export function keyForUpload(userId: string, filename: string): string {
  const ts = Date.now();
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `users/${userId}/${ts}-${safe}`;
}
