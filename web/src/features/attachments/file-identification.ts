import { fileTypeFromBuffer } from "file-type";
import yauzl, { type Entry } from "yauzl";

const MAX_ZIP_ENTRIES = 2_000;
const MAX_ZIP_ENTRY_BYTES = 100 * 1024 * 1024;
const MAX_ZIP_TOTAL_BYTES = 200 * 1024 * 1024;
const MAX_COMPRESSION_RATIO = 100;

type IdentifiedFile = { extension: string; mimeType: string; category: "Document" | "Image" | "Text" | "Data" };

function zipEntries(buffer: Buffer) {
  return new Promise<Entry[]>((resolve, reject) => {
    yauzl.fromBuffer(buffer, { lazyEntries: true, validateEntrySizes: true }, (openError, archive) => {
      if (openError || !archive) return reject(new Error("Malformed OOXML container", { cause: openError }));
      const entries: Entry[] = [];
      let total = 0;
      const fail = (message: string) => {
        archive.close();
        reject(new Error(message));
      };
      archive.on("error", (error) => reject(new Error("Malformed OOXML container", { cause: error })));
      archive.on("entry", (entry) => {
        const name = entry.fileName.replaceAll("\\", "/");
        if (name.startsWith("/") || name.split("/").includes("..")) return fail("Unsafe OOXML path");
        if (entries.length >= MAX_ZIP_ENTRIES) return fail("OOXML entry limit exceeded");
        if (entry.uncompressedSize > MAX_ZIP_ENTRY_BYTES) return fail("OOXML entry size limit exceeded");
        total += entry.uncompressedSize;
        if (total > MAX_ZIP_TOTAL_BYTES) return fail("OOXML total size limit exceeded");
        if (entry.uncompressedSize > 0 && (entry.compressedSize === 0 || entry.uncompressedSize / entry.compressedSize > MAX_COMPRESSION_RATIO)) {
          return fail("OOXML compression ratio limit exceeded");
        }
        entries.push(entry);
        archive.readEntry();
      });
      archive.on("end", () => resolve(entries));
      archive.readEntry();
    });
  });
}

async function identifyOoxml(buffer: Buffer, expectedExtension: string): Promise<IdentifiedFile> {
  const entries = await zipEntries(buffer);
  const names = entries.map((entry) => entry.fileName.replaceAll("\\", "/").toLowerCase());
  if (!names.includes("[content_types].xml")) throw new Error("Generic ZIP is not an OOXML document");
  if (names.some((name) => name.endsWith("vbaproject.bin") || name.includes("/macros/") || name.endsWith(".xlam"))) {
    throw new Error("OOXML macro payloads are not allowed");
  }
  const hasRoot = expectedExtension === "docx"
    ? names.some((name) => name.startsWith("word/"))
    : expectedExtension === "xlsx"
      ? names.some((name) => name.startsWith("xl/"))
      : names.some((name) => name.startsWith("ppt/"));
  if (!hasRoot) throw new Error(`OOXML container does not match .${expectedExtension}`);

  const raw = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength) as ArrayBuffer;
  const detected = await fileTypeFromBuffer(raw);
  if (detected?.ext !== expectedExtension) throw new Error(`OOXML package does not validate as .${expectedExtension}`);

  const mimeType = expectedExtension === "docx"
    ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    : expectedExtension === "xlsx"
      ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      : "application/vnd.openxmlformats-officedocument.presentationml.presentation";
  return { extension: expectedExtension, mimeType, category: "Document" };
}

function identifyText(buffer: Buffer, extension: "txt" | "md" | "csv"): IdentifiedFile {
  const detected = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
  if (/\0|[\u0001-\u0008\u000B\u000C\u000E-\u001F]/u.test(detected)) throw new Error("Binary content is not allowed as text");
  if (/<\s*(?:script|svg|html|iframe|object|embed)\b|javascript\s*:|<!doctype\s+html/iu.test(detected)) {
    throw new Error("Active content is not allowed in text attachments");
  }
  return {
    extension,
    mimeType: extension === "md" ? "text/markdown" : extension === "csv" ? "text/csv" : "text/plain",
    category: extension === "csv" ? "Data" : "Text",
  };
}

export async function identifyAttachmentFile(buffer: Buffer, expectedExtension: string): Promise<IdentifiedFile> {
  const extension = expectedExtension.toLowerCase();
  if (["txt", "md", "csv"].includes(extension)) return identifyText(buffer, extension as "txt" | "md" | "csv");
  if (["docx", "xlsx", "pptx"].includes(extension)) return identifyOoxml(buffer, extension);

  const bytes = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength) as ArrayBuffer;
  const detected = await fileTypeFromBuffer(bytes);
  const accepted = {
    pdf: { mimeType: "application/pdf", category: "Document" },
    png: { mimeType: "image/png", category: "Image" },
    jpg: { mimeType: "image/jpeg", category: "Image" },
    jpeg: { mimeType: "image/jpeg", category: "Image" },
    webp: { mimeType: "image/webp", category: "Image" },
  } as const;
  if (!(extension in accepted) || !detected) throw new Error("File signature is not allowed");
  const policy = accepted[extension as keyof typeof accepted];
  const detectedExtension = detected.ext === "jpg" && extension === "jpeg" ? "jpeg" : detected.ext;
  if (detectedExtension !== extension || detected.mime !== policy.mimeType) throw new Error("File signature does not match its extension");
  return { extension, ...policy };
}
