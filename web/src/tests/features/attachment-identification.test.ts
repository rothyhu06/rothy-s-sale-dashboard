// @vitest-environment node

import { describe, expect, it } from "vitest";
import { ZipFile } from "yazl";
import { identifyAttachmentFile } from "@/features/attachments/file-identification";

function zip(entries: Array<{ name: string; content: string | Buffer }>) {
  return new Promise<Buffer>((resolve, reject) => {
    const archive = new ZipFile();
    const chunks: Buffer[] = [];
    archive.outputStream.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
    archive.outputStream.on("error", reject);
    archive.outputStream.on("end", () => resolve(Buffer.concat(chunks)));
    for (const entry of entries) archive.addBuffer(Buffer.from(entry.content), entry.name);
    archive.end();
  });
}

describe("server-side attachment identification", () => {
  it("accepts signatures independently of supplied Content-Type", async () => {
    const pdf = Buffer.from("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n");
    await expect(identifyAttachmentFile(pdf, "pdf")).resolves.toMatchObject({ mimeType: "application/pdf", category: "Document" });

    const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlN8AAAAASUVORK5CYII=", "base64");
    await expect(identifyAttachmentFile(png, "png")).resolves.toMatchObject({ mimeType: "image/png", category: "Image" });
  });

  it("rejects spoofed PDF, active text, SVG, and executable bytes", async () => {
    await expect(identifyAttachmentFile(Buffer.from("not really a pdf"), "pdf")).rejects.toThrow("signature");
    await expect(identifyAttachmentFile(Buffer.from("<script>alert(1)</script>"), "txt")).rejects.toThrow(/active content/i);
    await expect(identifyAttachmentFile(Buffer.from("<svg xmlns='http://www.w3.org/2000/svg'/>"), "md")).rejects.toThrow(/active content/i);
    await expect(identifyAttachmentFile(Buffer.from("MZ\u0000\u0000binary"), "txt")).rejects.toThrow();
  });

  it("distinguishes OOXML containers and rejects generic ZIP or macro payloads", async () => {
    const docx = await zip([
      { name: "[Content_Types].xml", content: '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>' },
      { name: "_rels/.rels", content: '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>' },
      { name: "word/document.xml", content: '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body/></w:document>' },
    ]);
    await expect(identifyAttachmentFile(docx, "docx")).resolves.toMatchObject({ extension: "docx" });

    const generic = await zip([{ name: "notes.txt", content: "hello" }]);
    await expect(identifyAttachmentFile(generic, "docx")).rejects.toThrow("OOXML");

    const macro = await zip([
      { name: "[Content_Types].xml", content: '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>' },
      { name: "word/document.xml", content: "<document/>" },
      { name: "word/vbaProject.bin", content: "macro" },
    ]);
    await expect(identifyAttachmentFile(macro, "docx")).rejects.toThrow("macro");
  });
});
