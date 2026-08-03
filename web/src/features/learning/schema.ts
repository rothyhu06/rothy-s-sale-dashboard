import { z } from "zod";

export const LearningTypeSchema = z.enum(["Study", "Review", "Practice", "Course", "Product Training", "Case Analysis"]);
export const LearningStatusSchema = z.enum(["Planned", "In Progress", "Completed", "Cancelled"]);
export const LearningOutcomeSchema = z.enum(["Passed", "Needs Practice", "Blocked", "Applied", "Shared"]);
export const MasterySchema = z.enum(["Aware", "Understand", "Explain", "Apply", "Teach"]);

export const CreateLearningInputSchema = z.object({
  title: z.string().trim().min(1).max(300),
  learningType: LearningTypeSchema,
  status: LearningStatusSchema,
  objective: z.string().trim().max(10_000).nullable().optional(),
  startedAt: z.iso.datetime({ offset: true }).nullable().optional(),
  completedAt: z.iso.datetime({ offset: true }).nullable().optional(),
  durationMinutes: z.number().int().min(0).max(1_440).nullable().optional(),
  takeaway: z.string().trim().max(20_000).nullable().optional(),
  practiceResult: z.string().trim().max(20_000).nullable().optional(),
  learningOutcome: LearningOutcomeSchema.nullable().optional(),
  parentLearningId: z.uuid().nullable().optional(),
  dataLevel: z.enum(["Level1", "Level2", "Level3"]).default("Level2"),
  classificationReason: z.string().trim().max(1_000).nullable().optional(),
}).strict();

export type CreateLearningInput = z.infer<typeof CreateLearningInputSchema>;
