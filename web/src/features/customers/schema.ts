import { z } from "zod";

export const CustomerRecordStatusSchema = z.enum(["Active", "Dormant", "Archived"]);
export const ExternalReferenceSourceSchema = z.enum(["Manual", "SAP", "Tencent CRM", "Excel Import", "Official Website", "Other"]);
export const CustomerKnowledgeDirectionSchema = z.enum(["Applicable To", "Sourced From"]);
export const CustomerKnowledgeApplicabilitySchema = z.enum(["Unknown", "High", "Medium", "Low", "Not Applicable"]);

export function normalizeCustomerName(value: string) {
  return value.normalize("NFKC").trim().replace(/\s+/gu, " ").toLocaleLowerCase();
}

export const CustomerExternalReferenceInputSchema = z.object({
  sourceSystem: ExternalReferenceSourceSchema,
  externalReference: z.string().trim().min(1).max(300),
}).strict();

export const CustomerKnowledgeLinkInputSchema = z.object({
  knowledgeId: z.uuid(),
  direction: CustomerKnowledgeDirectionSchema,
  applicability: CustomerKnowledgeApplicabilitySchema.nullable().optional(),
  applicabilityReason: z.string().trim().min(1).max(2_000).nullable().optional(),
}).strict().superRefine((value, context) => {
  if (value.direction === "Applicable To" && !value.applicability) {
    context.addIssue({ code: "custom", path: ["applicability"], message: "Applicability is required" });
  }
  if (value.direction === "Sourced From" && value.applicability != null) {
    context.addIssue({ code: "custom", path: ["applicability"], message: "Source links do not carry applicability" });
  }
  if (["Low", "Not Applicable"].includes(value.applicability ?? "") && !value.applicabilityReason) {
    context.addIssue({ code: "custom", path: ["applicabilityReason"], message: "A reason is required" });
  }
});

const optionalText = (max: number) => z.string().trim().min(1).max(max).nullable().optional();
export const CreateCustomerInputSchema = z.object({
  name: z.string().trim().min(1).max(300),
  aliases: z.array(z.string().trim().min(1).max(300)).max(100).default([]),
  customerType: z.string().trim().min(1).max(100),
  educationSegment: optionalText(100),
  region: optionalText(200),
  website: z.url().max(2_000).nullable().optional(),
  background: optionalText(20_000),
  businessContext: optionalText(20_000),
  currentTechnology: optionalText(10_000),
  currentCloudProvider: optionalText(1_000),
  knownNeeds: optionalText(20_000),
  internalAssessment: optionalText(20_000),
  studentCountEstimate: z.number().int().nonnegative().nullable().optional(),
  facultyCountEstimate: z.number().int().nonnegative().nullable().optional(),
  campusCount: z.number().int().nonnegative().nullable().optional(),
  organizationStatsAsOf: z.iso.date().nullable().optional(),
  organizationStatsSource: optionalText(2_000),
  recordStatus: CustomerRecordStatusSchema.default("Active"),
  dataLevel: z.literal("Level3").default("Level3"),
  classificationReason: optionalText(1_000),
  externalReferences: z.array(CustomerExternalReferenceInputSchema).max(100).default([]),
  knowledgeLinks: z.array(CustomerKnowledgeLinkInputSchema).max(100).default([]),
}).strict().superRefine((value, context) => {
  const hasStats = value.studentCountEstimate != null || value.facultyCountEstimate != null || value.campusCount != null;
  if (hasStats && (!value.organizationStatsAsOf || !value.organizationStatsSource)) {
    context.addIssue({ code: "custom", path: ["organizationStatsAsOf"], message: "Factual organization statistics require date and source" });
  }
});

export const CustomerLifecycleProjectionSchema = z.object({
  customerId: z.uuid(),
  lifecycleStage: z.string().nullable(),
  projectionSchemaVersion: z.number().int().positive(),
}).strict();

export type CreateCustomerInput = z.infer<typeof CreateCustomerInputSchema>;
