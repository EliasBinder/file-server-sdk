import { XMLParser } from "fast-xml-parser";
import { s3Client } from "./utils/s3";
import type { TOperation } from "./utils/task-extractor";
import { PDFArray, PDFDict, PDFDocument, PDFName, PDFStream } from "pdf-lib";

const parser = new XMLParser();

export const extractPdfMetadata = async (operation: TOperation) => {
  const inputFile = operation.inputFile;
  const outputFile = operation.outputFile;

  // Validate input
  if (!inputFile) throw new Error("No input file provided");

  if (!outputFile) throw new Error("No output path provided");

  // Check if output file already exists in S3
  if (await s3Client.file(outputFile).exists()) {
    throw new Error(`Output file already exists in S3: ${outputFile}`);
  }

  if (!(await s3Client.file(inputFile).exists())) {
    throw new Error(`Input file not found in S3: ${inputFile}`);
  }

  // Download file from S3 and return as ArrayBuffer
  const s3file = s3Client.file(inputFile);
  const fileBuffer = await s3file.arrayBuffer();

  // Extract attachments using pdf-lib
  const attachments = await extractAttachments(fileBuffer);

  if (attachments.length === 0) {
    if (operation.onMissingOrInvalidMetadata === "fail")
      throw new Error("No attachments found in PDF");
    else return;
  }

  // Convert metadata from xml to JSON
  if (attachments.length !== 2) {
    if (operation.onMissingOrInvalidMetadata === "fail")
      throw new Error(
        `Expected exactly 2 attachments (xml and p7s) in PDF, but found ${attachments.length} attachments`,
      );
    else return;
  }

  const xmlAttachment = attachments.find((att) => att.name.endsWith(".xml"));
  const p7sAttachment = attachments.find((att) => att.name.endsWith(".p7s"));

  if (!xmlAttachment) {
    throw new Error("No XML attachment found in PDF");
  }

  if (!p7sAttachment) {
    throw new Error("No P7S attachment found in PDF");
  }

  // Validate the p7s signature against the XML metadata for mathematical correctness
  // TODO: Implement signature verification using node-forge or a similar library

  // Trust check p7s signature against known trusted certificates (e.g., from a specific certificate authority or a list of trusted public keys)
  // TODO: Implement trust check using node-forge or a similar library

  // Convert the XML metadata to JSON
  const jsonMetadata = parser.parse(xmlAttachment.data.toString());

  // Save the Json metadata to S3
  await s3Client.write(outputFile, Buffer.from(JSON.stringify(jsonMetadata)));
};

const extractAttachments = async (pdfBuffer: ArrayBuffer) => {
  const pdfDoc = await PDFDocument.load(pdfBuffer);
  const catalog = pdfDoc.catalog;

  // Navigate: Root -> Names -> EmbeddedFiles -> Names -> [name, filespec, ...]
  const namesDict = catalog.lookupMaybe(PDFName.of("Names"), PDFDict);
  if (!namesDict) return [];

  const efDict = namesDict.lookupMaybe(PDFName.of("EmbeddedFiles"), PDFDict);
  if (!efDict) return [];

  const efNames = efDict.lookupMaybe(PDFName.of("Names"), PDFArray);
  if (!efNames) return [];

  const results = [];

  // Array is pairs: [nameString, fileSpecDict, nameString, fileSpecDict, ...]
  for (let i = 0; i < efNames.size(); i += 2) {
    const nameObj = efNames.lookup(i);
    const name =
      nameObj instanceof PDFName ? nameObj.asString() : String(nameObj);
    const fileSpec = efNames.lookup(i + 1, PDFDict);
    const ef = fileSpec.lookupMaybe(PDFName.of("EF"), PDFDict);
    const fileStream = ef?.lookupMaybe(PDFName.of("F"), PDFStream);

    if (fileStream) {
      results.push({
        name,
        data: Buffer.from(fileStream.getContents()),
      });
    }
  }

  return results;
};
