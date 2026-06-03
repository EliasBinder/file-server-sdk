import { S3Client } from "bun";

export let s3Client: S3Client;

export const setupS3Client = () => {
  if (
    !process.env.S3_ACCESS_KEY_ID ||
    !process.env.S3_SECRET_ACCESS_KEY ||
    !process.env.S3_ENDPOINT
  ) {
    throw new Error(
      "S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, and S3_ENDPOINT environment variables must be set",
    );
  }

  s3Client = new S3Client({
    accessKeyId: process.env.S3_ACCESS_KEY_ID!,
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY!,
    endpoint: process.env.S3_ENDPOINT!,
  });
};
