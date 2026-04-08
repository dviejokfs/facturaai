// Cloudflare R2 (S3-compatible) storage
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

let _client: S3Client | null = null;

function client(): S3Client {
  if (_client) return _client;
  const accountId = process.env.R2_ACCOUNT_ID;
  if (!accountId) throw new Error('R2_ACCOUNT_ID missing');
  _client = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: process.env.R2_ACCESS_KEY_ID!,
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
    },
  });
  return _client;
}

export async function upload(opts: {
  key: string;
  filePath: string;
  contentType?: string;
}): Promise<string> {
  const bucket = process.env.R2_BUCKET;
  if (!bucket) throw new Error('R2_BUCKET missing');
  const body = await Bun.file(opts.filePath).arrayBuffer();
  await client().send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: opts.key,
      Body: new Uint8Array(body),
      ContentType: opts.contentType ?? 'application/octet-stream',
    }),
  );
  return opts.key;
}

export async function signedUrl(key: string, expiresInSec = 7 * 24 * 3600): Promise<string> {
  const bucket = process.env.R2_BUCKET!;
  return getSignedUrl(client(), new GetObjectCommand({ Bucket: bucket, Key: key }), {
    expiresIn: expiresInSec,
  });
}
