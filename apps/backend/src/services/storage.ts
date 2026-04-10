import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
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
