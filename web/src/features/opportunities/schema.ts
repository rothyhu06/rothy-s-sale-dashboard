import { z } from "zod";

export const OpportunityStageSchema = z.enum([
  "Lead",
  "Discovery",
  "Needs Confirmed",
  "Solution Design",
  "POC",
  "Commercial Negotiation",
  "Closed Won",
  "Closed Lost",
]);
export const OpportunityTypeSchema = z.enum(["New Business", "Expansion", "Renewal"]);
export const OpportunitySourceTypeSchema = z.enum([
  "Inbound", "Outbound", "Partner", "Existing Customer", "Marketing", "Referral", "Event", "Internal", "Other",
]);
export const OpportunityChangedSourceSchema = z.enum(["Manual", "Workflow", "Import", "Migration"]);
export const OpportunityOutcomeTypeSchema = z.enum(["Won", "Lost"]);
export const OpportunitySupportLevelSchema = z.enum(["Unknown", "Opposed", "Neutral", "Supportive", "Champion"]);

const iso4217 = new Set([
  "AED", "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD", "HUF", "IDR", "ILS", "INR",
  "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "PLN", "RUB", "SAR", "SEK", "SGD", "THB", "TRY", "TWD",
  "USD", "VND", "ZAR",
]);
export const CurrencySchema = z.string().length(3).refine((value) => iso4217.has(value), "Use an ISO 4217 currency code");
const optionalText = (max: number) => z.string().trim().min(1).max(max).nullable().optional();

export const OpportunityContactRoleInputSchema = z.object({
  contactId: z.uuid(), role: z.string().trim().min(1).max(100),
  supportLevel: OpportunitySupportLevelSchema.default("Unknown"), notes: optionalText(2_000),
}).strict();

export const CreateOpportunityInputSchema = z.object({
  customerId: z.uuid(), parentOpportunityId: z.uuid().nullable().optional(),
  name: z.string().trim().min(1).max(300), opportunityType: OpportunityTypeSchema,
  sourceType: OpportunitySourceTypeSchema.nullable().optional(), sourceContactId: z.uuid().nullable().optional(),
  scenario: optionalText(20_000), customerNeed: optionalText(20_000), desiredOutcome: optionalText(20_000),
  solutionDirection: optionalText(20_000), constraints: optionalText(20_000),
  estimatedAmount: z.number().nonnegative().nullable().optional(), currency: CurrencySchema.nullable().optional(),
  amountBasis: optionalText(2_000), amountAsOf: z.iso.date().nullable().optional(),
  expectedDecisionDate: z.iso.date().nullable().optional(),
  contactRoles: z.array(OpportunityContactRoleInputSchema).max(100).default([]),
}).strict().superRefine((value, context) => {
  if ((value.estimatedAmount == null) !== (value.currency == null)) {
    context.addIssue({ code: "custom", path: ["currency"], message: "Amount and currency must be provided together" });
  }
  if (value.estimatedAmount != null && (!value.amountBasis || !value.amountAsOf)) {
    context.addIssue({ code: "custom", path: ["amountBasis"], message: "Estimated amount requires basis and as-of date" });
  }
  if (value.opportunityType === "Renewal" && !value.parentOpportunityId) {
    context.addIssue({ code: "custom", path: ["parentOpportunityId"], message: "Renewal requires a parent opportunity" });
  }
  if (value.opportunityType !== "Renewal" && value.parentOpportunityId) {
    context.addIssue({ code: "custom", path: ["parentOpportunityId"], message: "Only Renewal may have a parent opportunity" });
  }
});

export const TransitionOpportunityInputSchema = z.object({
  opportunityId: z.uuid(), expectedVersion: z.number().int().positive(), expectedCurrentStageHistoryId: z.uuid(),
  toStage: OpportunityStageSchema.exclude(["Closed Won", "Closed Lost"]),
  changedSource: OpportunityChangedSourceSchema.default("Manual"), reason: optionalText(10_000),
}).strict();

export const OpportunityOutcomeInputSchema = z.object({
  opportunityId: z.uuid(), expectedVersion: z.number().int().positive(), expectedCurrentStageHistoryId: z.uuid(),
  outcomeType: OpportunityOutcomeTypeSchema, finalAmount: z.number().nonnegative(), currency: CurrencySchema,
  decisionDate: z.iso.date(), reason: z.string().trim().min(1).max(10_000), competitor: optionalText(1_000),
  decisionFactors: z.array(z.string().trim().min(1).max(2_000)).max(100).default([]),
  customerValue: optionalText(20_000), lessons: optionalText(20_000), reviewCompletedAt: z.iso.datetime().nullable().optional(),
}).strict();

export const ReopenOpportunityInputSchema = z.object({
  opportunityId: z.uuid(), expectedVersion: z.number().int().positive(), expectedCurrentStageHistoryId: z.uuid(),
  toStage: OpportunityStageSchema.exclude(["Closed Won", "Closed Lost"]),
  changedSource: OpportunityChangedSourceSchema.default("Manual"), reason: z.string().trim().min(1).max(10_000),
}).strict();

export type OpportunityStage = z.infer<typeof OpportunityStageSchema>;
