import { z } from "zod";
import { ContentBlockDocumentSchema } from "@/lib/content-blocks/schema";

export const KnowledgeTypeSchema = z.enum([
  "Tencent Cloud Product", "AI Technology", "Education Industry", "Sales Method",
  "Solution Reference", "Case Reference", "General",
]);
export const KnowledgeStatusSchema = z.enum(["Draft", "Learning", "Ready", "Archived"]);
export const KnowledgeConfidenceSchema = z.enum(["Official", "Verified", "Observed", "Hypothesis"]);
export const KnowledgeSourceTypeSchema = z.enum([
  "Official Doc", "Training", "Meeting", "Customer", "Book", "Website",
  "Internal Material", "AI Generated", "Personal Note",
]);

const optionalText = z.string().trim().max(20_000).nullable().optional();

export const CreateKnowledgeInputSchema = z.object({
  title: z.string().trim().min(1).max(300),
  knowledgeType: KnowledgeTypeSchema,
  status: KnowledgeStatusSchema,
  confidence: KnowledgeConfidenceSchema,
  sourceType: KnowledgeSourceTypeSchema,
  sourceName: z.string().trim().min(1).max(300).nullable().optional(),
  sourceUrl: z.url().max(2_000).nullable().optional(),
  summary: optionalText,
  technicalPrinciple: optionalText,
  businessValue: optionalText,
  educationScenario: optionalText,
  customerPainPoint: optionalText,
  salesExpression: optionalText,
  customerQuestions: optionalText,
  competitiveNote: optionalText,
  dataLevel: z.enum(["Level1", "Level2", "Level3"]).default("Level1"),
  classificationReason: z.string().trim().max(1_000).nullable().optional(),
  contentBlocks: ContentBlockDocumentSchema,
}).strict();

export type CreateKnowledgeInput = z.infer<typeof CreateKnowledgeInputSchema>;
