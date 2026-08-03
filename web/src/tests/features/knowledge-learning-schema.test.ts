import { describe, expect, it } from "vitest";
import {
  CreateKnowledgeInputSchema,
  KnowledgeConfidenceSchema,
  KnowledgeSourceTypeSchema,
  KnowledgeStatusSchema,
  KnowledgeTypeSchema,
} from "@/features/knowledge/schema";
import {
  CreateLearningInputSchema,
  LearningOutcomeSchema,
  LearningStatusSchema,
  LearningTypeSchema,
  MasterySchema,
} from "@/features/learning/schema";

describe("Knowledge and Learning schema contracts", () => {
  it("freezes the Knowledge lifecycle, confidence, source, and type vocabularies", () => {
    expect(KnowledgeTypeSchema.options).toEqual([
      "Tencent Cloud Product", "AI Technology", "Education Industry", "Sales Method",
      "Solution Reference", "Case Reference", "General",
    ]);
    expect(KnowledgeStatusSchema.options).toEqual(["Draft", "Learning", "Ready", "Archived"]);
    expect(KnowledgeConfidenceSchema.options).toEqual(["Official", "Verified", "Observed", "Hypothesis"]);
    expect(KnowledgeSourceTypeSchema.options).toEqual([
      "Official Doc", "Training", "Meeting", "Customer", "Book", "Website",
      "Internal Material", "AI Generated", "Personal Note",
    ]);
  });

  it("accepts only the shared ContentBlockDocument V1 envelope and never browser-owned plaintext", () => {
    const input = CreateKnowledgeInputSchema.parse({
      title: "腾讯云 AI 助教",
      knowledgeType: "Tencent Cloud Product",
      status: "Draft",
      confidence: "Official",
      sourceType: "Official Doc",
      contentBlocks: { schemaVersion: 1, blocks: [{ id: "p1", type: "paragraph", text: "可复用知识" }] },
    });
    expect(input.contentBlocks.blocks).toHaveLength(1);
    expect(() => CreateKnowledgeInputSchema.parse({ ...input, contentPlaintext: "forged" })).toThrow();
  });

  it("freezes the Learning chain, outcome, and mastery vocabularies", () => {
    expect(LearningTypeSchema.options).toEqual(["Study", "Review", "Practice", "Course", "Product Training", "Case Analysis"]);
    expect(LearningStatusSchema.options).toEqual(["Planned", "In Progress", "Completed", "Cancelled"]);
    expect(LearningOutcomeSchema.options).toEqual(["Passed", "Needs Practice", "Blocked", "Applied", "Shared"]);
    expect(MasterySchema.options).toEqual(["Aware", "Understand", "Explain", "Apply", "Teach"]);
    expect(CreateLearningInputSchema.parse({
      title: "复习产品定位", learningType: "Review", status: "Completed", learningOutcome: "Applied",
    }).parentLearningId).toBeUndefined();
  });
});
