import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createHash, randomUUID } from "node:crypto";
import { requireLocalSupabaseUrl } from "./support/local-supabase";
import { ensureDeterministicLocalUser } from "./support/local-test-user";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function settledAxe(page: import("@playwright/test").Page) {
  await page.waitForTimeout(400);
  return new AxeBuilder({ page }).analyze();
}

test.describe("Knowledge and Learning journal", () => {
  test.describe.configure({ mode: "serial" });

  const email = "knowledge-learning-e2e@example.test";
  const password = "Knowledge-learning-e2e-only!";
  const suffix = "task3";
  let attachmentId = "";
  const attachmentName = "task3-learning-guide.pdf";
  const relatedTitle = `AI security prerequisite ${suffix}`;
  const structuredTitle = `Structured Knowledge ${suffix}`;
  const knowledgeTitle = `Tencent Cloud AI foundations ${suffix}`;
  const revisedTitle = `${knowledgeTitle} field guide`;
  const learningTitle = `Apply ${knowledgeTitle}`;
  const reviewTitle = `Review ${knowledgeTitle}`;

  test.beforeAll(async () => {
    const localUrl = requireLocalSupabaseUrl(supabaseUrl);
    expect(supabaseAnonKey, "Export the local NEXT_PUBLIC_SUPABASE_ANON_KEY").toBeTruthy();
    expect(serviceRoleKey, "Export the local SUPABASE_SERVICE_ROLE_KEY").toBeTruthy();

    const admin = createClient(localUrl.href, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const user = await ensureDeterministicLocalUser(admin.auth.admin, email, password);
    const userClient = createClient(localUrl.href, supabaseAnonKey!, { auth: { autoRefreshToken: false, persistSession: false } });
    expect((await userClient.auth.signInWithPassword({ email, password })).error).toBeNull();
    const tag = await admin.rpc("create_tag", {
      p_verified_user_id: user.id,
      p_client_request_id: randomUUID(),
      p_name: `Tencent AI ${suffix}`,
      p_normalized_name: `tencent ai ${suffix}`,
      p_description: "Knowledge and Learning E2E tag",
      p_data_level: "Level2",
    });
    expect(tag.error).toBeNull();
    const pdf = Buffer.from("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n");
    const prepareReceipt = await admin.rpc("claim_saga_command_receipt", {
      p_verified_user_id: user.id, p_command_type: "PrepareAttachmentUpload", p_client_request_id: randomUUID(),
    });
    expect(prepareReceipt.error).toBeNull();
    const prepared = await admin.rpc("prepare_attachment_upload", {
      p_verified_user_id: user.id,
      p_receipt_id: prepareReceipt.data[0].id,
      p_operation_id: prepareReceipt.data[0].operation_id,
      p_original_filename: attachmentName,
      p_safe_filename: attachmentName,
      p_mime_type: "application/pdf",
      p_file_extension: "pdf",
      p_size_bytes: pdf.byteLength,
      p_file_category: "Document",
      p_data_level: "Level2",
      p_classification_reason: "Local Knowledge Learning E2E fixture",
    });
    expect(prepared.error).toBeNull();
    attachmentId = prepared.data[0].id;
    const objectPath = prepared.data[0].object_path;
    expect((await admin.rpc("authorize_attachment_upload_credential", {
      p_verified_user_id: user.id,
      p_operation_id: prepareReceipt.data[0].operation_id,
      p_attachment_id: attachmentId,
      p_object_path: objectPath,
      p_expires_at: new Date(Date.now() + 60 * 60 * 1_000).toISOString(),
    })).error).toBeNull();
    const signed = await admin.storage.from("business-attachments").createSignedUploadUrl(objectPath, { upsert: false });
    expect(signed.error).toBeNull();
    expect((await userClient.storage.from("business-attachments").uploadToSignedUrl(
      objectPath, signed.data!.token,
      new Blob([pdf.buffer.slice(pdf.byteOffset, pdf.byteOffset + pdf.byteLength) as ArrayBuffer], { type: "application/pdf" }),
      { contentType: "application/pdf" },
    )).error).toBeNull();
    const finalizeReceipt = await admin.rpc("claim_saga_command_receipt", {
      p_verified_user_id: user.id, p_command_type: "FinalizeAttachmentUpload", p_client_request_id: randomUUID(),
    });
    const finalized = await admin.rpc("finalize_attachment_upload", {
      p_verified_user_id: user.id,
      p_receipt_id: finalizeReceipt.data[0].id,
      p_operation_id: finalizeReceipt.data[0].operation_id,
      p_attachment_id: attachmentId,
      p_size_bytes: pdf.byteLength,
      p_mime_type: "application/pdf",
      p_checksum_sha256: createHash("sha256").update(pdf).digest("hex"),
    });
    expect(finalized.error).toBeNull();
    expect(finalized.data[0].storage_status).toBe("Available");
    const structured = await admin.rpc("create_knowledge", {
      p_verified_user_id: user.id, p_client_request_id: randomUUID(), p_title: structuredTitle,
      p_knowledge_type: "General", p_status: "Draft", p_confidence: "Verified", p_source_type: "Personal Note",
      p_source_name: null, p_source_url: null, p_summary: "Structured edit fixture", p_technical_principle: null,
      p_business_value: null, p_education_scenario: null, p_customer_pain_point: null, p_sales_expression: null,
      p_customer_questions: null, p_competitive_note: null,
      p_content_blocks: { schemaVersion: 1, blocks: [
        { id: "heading-stable", type: "heading", level: 2, text: "Structured heading" },
        { id: "attachment-stable", type: "attachmentReference", attachmentId, caption: "Exact attachment caption" },
      ] },
      p_data_level: "Level2", p_classification_reason: "Local E2E fixture",
      p_attachment_ids: [attachmentId], p_tag_ids: [], p_relations: [],
    });
    expect(structured.error).toBeNull();
  });

  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/login");
    await page.getByLabel("邮箱").fill(email);
    await page.getByLabel("密码").fill(password);
    await page.getByRole("button", { name: "登录" }).click();
    await expect(page).toHaveURL(/\/$/);
  });

  test("creates, edits, searches, learns, completes, and reviews a Knowledge note", async ({ page }) => {
    await page.goto("/knowledge");
    await expect(page.getByRole("heading", { name: "Knowledge Library", exact: true })).toBeVisible();
    expect((await settledAxe(page)).violations).toEqual([]);
    await page.getByRole("link", { name: structuredTitle }).click();
    await page.getByRole("link", { name: "Edit Knowledge" }).click();
    await page.getByLabel("Knowledge body").fill("Converted body after explicit confirmation.");
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByText(/结构化正文已更改；请确认转换/)).toBeVisible();
    await page.getByLabel("Knowledge body").fill("Converted body after explicit confirmation.");
    await page.getByRole("checkbox", { name: "将结构化正文转换为纯文本段落" }).check();
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByText("Converted body after explicit confirmation.")).toBeVisible();
    await expect(page.getByText(attachmentName)).toBeVisible();
    await page.goto("/knowledge");
    await page.getByRole("link", { name: "New Knowledge" }).first().click();

    await page.getByLabel("Title").fill(relatedTitle);
    await page.getByLabel("Status").selectOption("Ready");
    await page.getByLabel("Knowledge body").fill("Secure deployment is a prerequisite.");
    await page.getByRole("button", { name: "Create Knowledge" }).click();
    await expect(page.getByRole("heading", { name: relatedTitle })).toBeVisible();
    await page.goto("/knowledge/new");

    await page.getByLabel("Title").fill(knowledgeTitle);
    await page.getByLabel("Knowledge type").selectOption("AI Technology");
    await page.getByLabel("Status").selectOption("Learning");
    await page.getByLabel("Confidence").selectOption("Verified");
    await page.getByLabel("Source type").selectOption("Official Doc");
    await page.getByLabel("Source name").fill("Tencent Cloud documentation");
    await page.getByLabel("Source URL").fill("https://cloud.tencent.com/document/product/1772");
    await page.getByLabel("Summary").fill("A reusable account of Tencent Cloud AI capabilities.");
    await page.getByLabel("Knowledge body").fill("Model services, secure deployment, and an education scenario.");
    await page.getByRole("checkbox", { name: new RegExp(`Tencent AI ${suffix}`) }).check();
    await page.getByRole("checkbox", { name: new RegExp(attachmentName) }).check();
    await page.getByRole("checkbox", { name: relatedTitle }).check();
    await page.getByRole("button", { name: "Create Knowledge" }).click();

    await expect(page).toHaveURL(/\/knowledge\/[0-9a-f-]+$/);
    await expect(page.getByRole("heading", { name: knowledgeTitle })).toBeVisible();
    expect((await settledAxe(page)).violations).toEqual([]);
    await expect(page.getByText("Model services, secure deployment, and an education scenario.")).toBeVisible();
    await expect(page.getByText(`Tencent AI ${suffix}`)).toBeVisible();
    await expect(page.getByText(attachmentName)).toBeVisible();
    await expect(page.getByRole("link", { name: relatedTitle })).toBeVisible();

    await page.getByRole("link", { name: "Edit Knowledge" }).click();
    await page.getByLabel("Title").fill(revisedTitle);
    await page.getByLabel("Business value").fill("Helps schools evaluate secure AI adoption.");
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByRole("heading", { name: revisedTitle })).toBeVisible();
    await expect(page.getByText("Helps schools evaluate secure AI adoption.")).toBeVisible();

    await page.getByRole("link", { name: "Create Learning" }).click();
    await page.getByLabel("Title").fill(learningTitle);
    await page.getByLabel("Learning type").selectOption("Study");
    await page.getByLabel("Status").selectOption("In Progress");
    await page.getByLabel("Objective").fill("Explain the capability in a customer conversation.");
    await page.getByLabel(`Mastery before for ${revisedTitle}`).selectOption("Understand");
    await page.getByRole("checkbox", { name: relatedTitle }).check();
    await page.getByLabel(`Mastery before for ${relatedTitle}`).selectOption("Aware");
    await page.getByRole("checkbox", { name: new RegExp(`Tencent AI ${suffix}`) }).check();
    await page.getByRole("checkbox", { name: new RegExp(attachmentName) }).check();
    await page.getByRole("button", { name: "Create Learning" }).click();

    await expect(page).toHaveURL(/\/learning\/[0-9a-f-]+$/);
    await expect(page.getByRole("heading", { name: learningTitle })).toBeVisible();
    await expect(page.getByText(`Tencent AI ${suffix}`)).toBeVisible();
    await expect(page.getByText(attachmentName)).toBeVisible();
    await page.getByLabel("Learning outcome").selectOption("Applied");
    await page.getByLabel(`Mastery after for ${revisedTitle}`).selectOption("Apply");
    await page.getByLabel(`Mastery after for ${relatedTitle}`).selectOption("Explain");
    await page.getByLabel("Practice result").fill("Used the explanation in a school AI workshop.");
    await page.getByRole("button", { name: "Complete Learning" }).click();

    await expect(page.getByText("Applied", { exact: true })).toBeVisible();
    await expect(page.getByText(/Understand → Level 4 of 5 · Apply/)).toBeVisible();
    await expect(page.getByText(/Aware → Level 3 of 5 · Explain/)).toBeVisible();
    await expect(page.getByRole("progressbar")).toHaveCount(0);
    await page.getByRole("link", { name: "Create Review" }).click();
    await page.getByLabel("Title").fill(reviewTitle);
    await page.getByLabel("Objective").fill("Retain the customer-ready explanation.");
    await page.getByRole("checkbox", { name: new RegExp(`${revisedTitle}.*linked to parent`) }).check();
    await page.getByRole("checkbox", { name: new RegExp(`${relatedTitle}.*linked to parent`) }).check();
    await page.getByRole("checkbox", { name: new RegExp(`Tencent AI ${suffix}.*linked to parent`) }).check();
    await page.getByRole("checkbox", { name: new RegExp(`${attachmentName}.*linked to parent`) }).check();
    await page.getByRole("button", { name: "Create Review" }).click();

    await expect(page.getByRole("heading", { name: reviewTitle })).toBeVisible();
    await expect(page.getByText("Review of")).toBeVisible();
    await expect(page.getByRole("link", { name: learningTitle })).toBeVisible();
    await expect(page.getByRole("link", { name: revisedTitle })).toBeVisible();
    await expect(page.getByRole("link", { name: relatedTitle })).toBeVisible();
    await expect(page.getByText(`Tencent AI ${suffix}`)).toBeVisible();
    await expect(page.getByText(attachmentName)).toBeVisible();

    await page.goto("/knowledge");
    await page.getByLabel("Search Knowledge").fill(suffix);
    await page.getByRole("button", { name: "Search" }).click();
    await expect(page.getByRole("link", { name: new RegExp(revisedTitle) })).toBeVisible();
    await page.getByLabel("Status filter").selectOption("Ready");
    await expect(page.getByRole("link", { name: relatedTitle })).toBeVisible();
    await expect(page.getByRole("link", { name: new RegExp(revisedTitle) })).toHaveCount(0);
    await page.getByLabel("Status filter").selectOption("All");

    const accessibility = await settledAxe(page);
    expect(accessibility.violations).toEqual([]);
  });

  test("keeps Continue Learning usable on mobile and by keyboard", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/learning");
    await expect(page.getByRole("heading", { name: "Learning Journal" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Continue Learning" })).toBeVisible();
    await expect(page.getByRole("link", { name: reviewTitle }).first()).toBeVisible();

    await page.keyboard.press("Tab");
    await expect(page.locator(":focus-visible")).toBeVisible();
    await expect(page.locator("main")).toHaveCSS("padding-left", "20px");
    await page.screenshot({ path: `test-results/knowledge-learning-mobile-${suffix}.png`, fullPage: true });

    const accessibility = await settledAxe(page);
    expect(accessibility.violations).toEqual([]);
  });

  for (const viewport of [
    { name: "tablet", width: 834, height: 1112, expectedLeft: "72px" },
    { name: "desktop", width: 1440, height: 1000, expectedLeft: "224px" },
  ]) {
    test(`keeps the editorial shell responsive on ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto("/knowledge");
      await expect(page.getByRole("heading", { level: 1, name: "Knowledge Library" })).toBeVisible();
      await expect(page.getByRole("navigation", { name: "Studio index" })).toBeVisible();
      await expect(page.locator("main")).toHaveCSS("margin-left", viewport.expectedLeft);
      await page.screenshot({ path: `test-results/knowledge-learning-${viewport.name}-${suffix}.png`, fullPage: true });
    });
  }
});
