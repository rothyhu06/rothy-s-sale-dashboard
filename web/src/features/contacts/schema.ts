import { z } from "zod";

export const PreferredContactTimeSchema = z.enum(["No Preference", "Morning", "Afternoon", "Evening"]);
export const CommunicationPreferenceSchema = z.enum(["Email First", "WeChat Preferred", "Do Not Call"]);
export const EmploymentStatusSchema = z.enum(["Active", "Left", "Unknown"]);
export const RelationshipStatusSchema = z.enum(["Unknown", "New", "Developing", "Trusted", "Dormant"]);
export const OrganizationInfluenceSchema = z.enum(["Unknown", "Low", "Medium", "High"]);
const optionalText = (max: number) => z.string().trim().min(1).max(max).nullable().optional();

export const CreateContactInputSchema = z.object({
  customerId: z.uuid(),
  fullName: z.string().trim().min(1).max(300),
  preferredName: optionalText(300),
  department: optionalText(300),
  position: optionalText(300),
  email: z.email().max(320).nullable().optional(),
  mobile: optionalText(100),
  wechat: optionalText(300),
  preferredChannel: optionalText(80),
  preferredContactTime: PreferredContactTimeSchema.default("No Preference"),
  communicationPreferences: z.array(CommunicationPreferenceSchema).max(3).default([]),
  employmentStatus: EmploymentStatusSchema.default("Unknown"),
  relationshipStatus: RelationshipStatusSchema.default("Unknown"),
  organizationInfluence: OrganizationInfluenceSchema.default("Unknown"),
  influenceEvidence: optionalText(2_000),
  previousContactId: z.uuid().nullable().optional(),
  dataLevel: z.literal("Level3").default("Level3"),
  classificationReason: optionalText(1_000),
}).strict().superRefine((value, context) => {
  if (value.organizationInfluence !== "Unknown" && !value.influenceEvidence) {
    context.addIssue({ code: "custom", path: ["influenceEvidence"], message: "Known influence requires evidence" });
  }
});

export type CreateContactInput = z.infer<typeof CreateContactInputSchema>;
