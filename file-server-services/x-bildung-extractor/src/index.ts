import { extractPdfMetadata } from "./extract-pdf-metadata";
import { connectMQ, reportErrorToMQ } from "./utils/mq";
import { setupS3Client } from "./utils/s3";
import {
  extractTask,
  publishTaskCompletion,
  type TRequest,
} from "./utils/task-extractor";

// Handler for incoming RabbitMQ messages
const onMessage = async (payload: TRequest) => {
  const [task, context] = extractTask(payload);
  try {
    await extractPdfMetadata(task);
    publishTaskCompletion(payload);
  } catch (error) {
    reportErrorToMQ(
      error instanceof Error ? error : new Error(String(error)),
      context,
    );
  }
};

// Setup S3 client
setupS3Client();

// Connect to RabbitMQ broker and listen for messages on the "pdf_merger" queue
const QUEUE = "pdf_metadata_extractor";
await connectMQ(QUEUE, onMessage);
