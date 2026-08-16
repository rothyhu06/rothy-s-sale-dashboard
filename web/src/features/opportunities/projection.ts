import { z } from "zod";
import { OpportunityStageSchema } from "./schema";

const inputSchema = z.object({
  opportunityId: z.uuid(), currentStage: OpportunityStageSchema, stageEnteredAt: z.iso.datetime(),
  lastProgressAt: z.iso.datetime(), nextTaskDueAt: z.iso.datetime().nullable(),
  activeOutcome: z.object({ outcomeType: z.enum(["Won", "Lost"]), reviewCompletedAt: z.iso.datetime().nullable() }).nullable(),
  asOf: z.iso.datetime(), stalledAfterDays: z.number().int().positive(),
});
export function deriveOpportunityProjection(input: z.input<typeof inputSchema>) {
  const v = inputSchema.parse(input);
  const daysInStage = Math.max(0, Math.floor((Date.parse(v.asOf) - Date.parse(v.stageEnteredAt)) / 86_400_000));
  const isClosed = v.currentStage === "Closed Won" || v.currentStage === "Closed Lost";
  return {
    opportunityId: v.opportunityId, currentStage: v.currentStage, stageEnteredAt: v.stageEnteredAt, daysInStage,
    isClosed, isStalled: !isClosed && Date.parse(v.asOf) - Date.parse(v.lastProgressAt) >= v.stalledAfterDays * 86_400_000,
    lastProgressAt: v.lastProgressAt, nextTaskDueAt: v.nextTaskDueAt, forecastCategory: null,
    outcomeReviewMissing: isClosed && v.activeOutcome != null && v.activeOutcome.reviewCompletedAt == null,
    projectionSchemaVersion: 1,
  };
}
