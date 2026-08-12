import { beforeEach, describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const survivorId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const duplicateId = "8dfd9adc-4c1d-4bf6-af3b-4b7445b1c019";
const clientRequestId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";

const { createCommandContext } = vi.hoisted(() => ({ createCommandContext: vi.fn() }));
vi.mock("@/lib/commands/command-context", () => ({ createCommandContext }));

import {
  CreateCustomerInputSchema,
  CustomerKnowledgeLinkInputSchema,
  normalizeCustomerName,
} from "@/features/customers/schema";
import { CreateContactInputSchema } from "@/features/contacts/schema";
import { createCustomerActions } from "@/features/customers/actions";
import { createContactActions } from "@/features/contacts/actions";
import { createCustomerQueries } from "@/features/customers/queries";
import { createMergeActions } from "@/features/customers/merge";

function rpcClient(result: unknown) {
  return { rpc: vi.fn().mockResolvedValue({ data: result, error: null }) };
}

describe("Customer and Contact contracts", () => {
  it("normalizes names for advisory duplicate warnings without making names unique", () => {
    expect(normalizeCustomerName("  华南  师范大学（大学城校区） ")).toBe("华南 师范大学(大学城校区)");
    const parsed = CreateCustomerInputSchema.parse({
      name: "华南师范大学",
      customerType: "University",
      studentCountEstimate: 36_000,
      facultyCountEstimate: 2_800,
      campusCount: 3,
      organizationStatsAsOf: "2026-07-01",
      organizationStatsSource: "学校官网 2025 年报",
      externalReferences: [],
      knowledgeLinks: [],
    });
    expect(parsed).not.toHaveProperty("lifecycleStage");
    expect(parsed).not.toHaveProperty("health");
    expect(parsed).not.toHaveProperty("nextAction");
  });

  it("keeps applicability and source direction semantically distinct", () => {
    expect(CustomerKnowledgeLinkInputSchema.safeParse({
      knowledgeId: crypto.randomUUID(), direction: "Applicable To", applicability: "Low",
    }).success).toBe(false);
    expect(CustomerKnowledgeLinkInputSchema.parse({
      knowledgeId: crypto.randomUUID(), direction: "Applicable To", applicability: "Low", applicabilityReason: "仅适用于实验室",
    }).direction).toBe("Applicable To");
    expect(CustomerKnowledgeLinkInputSchema.safeParse({
      knowledgeId: crypto.randomUUID(), direction: "Sourced From", applicability: "High",
    }).success).toBe(false);
  });

  it("separates stable employment position and channel/time preferences from future Opportunity roles", () => {
    const parsed = CreateContactInputSchema.parse({
      customerId: survivorId,
      fullName: "张老师",
      position: "信息化办公室主任",
      preferredChannel: "WeChat",
      preferredContactTime: "Afternoon",
      communicationPreferences: ["WeChat Preferred", "Do Not Call"],
      employmentStatus: "Active",
      relationshipStatus: "Developing",
      organizationInfluence: "High",
      influenceEvidence: "牵头校级云平台评审",
    });
    expect(parsed.position).toBe("信息化办公室主任");
    expect(parsed.preferredChannel).toBe("WeChat");
    expect(parsed.preferredContactTime).toBe("Afternoon");
    expect(parsed).not.toHaveProperty("opportunityRole");
  });

  it("requires a previous Contact for a new employment record and evidence for known influence", () => {
    expect(CreateContactInputSchema.safeParse({
      customerId: survivorId, fullName: "张老师", employmentStatus: "Active",
      relationshipStatus: "Unknown", organizationInfluence: "High",
    }).success).toBe(false);
    expect(CreateContactInputSchema.parse({
      customerId: survivorId, fullName: "张老师", previousContactId: duplicateId,
      employmentStatus: "Active", relationshipStatus: "Unknown",
      organizationInfluence: "High", influenceEvidence: "主持采购评审",
    }).previousContactId).toBe(duplicateId);
  });
});

describe("Customer and Contact service commands", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockResolvedValue({ user: { sub: ownerId }, clientRequestId });
  });

  it("injects the verified owner and delegates normalized names and references to one atomic Customer RPC", async () => {
    const client = rpcClient([{ id: survivorId, name: "华南师范大学", normalized_name: "华南师范大学", version: 1, operation_id: crypto.randomUUID() }]);
    const actions = createCustomerActions({ authClient: {} as never, serviceClient: client as never });
    await actions.createCustomer({
      name: "华南师范大学", customerType: "University",
      externalReferences: [{ sourceSystem: "SAP", externalReference: "EDU-42" }], knowledgeLinks: [],
    }, clientRequestId);
    expect(client.rpc).toHaveBeenCalledWith("create_customer", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_external_references: [{ sourceSystem: "SAP", externalReference: "EDU-42" }],
    }));
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("owner_id");
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("p_normalized_name");
  });

  it("creates Contact through a service-only atomic RPC", async () => {
    const client = rpcClient([{ id: duplicateId, full_name: "张老师", version: 1, operation_id: crypto.randomUUID() }]);
    const actions = createContactActions({ authClient: {} as never, serviceClient: client as never });
    await actions.createContact({
      customerId: survivorId, fullName: "张老师", employmentStatus: "Unknown",
      relationshipStatus: "Unknown", organizationInfluence: "Unknown",
    }, clientRequestId);
    expect(client.rpc).toHaveBeenCalledWith("create_contact", expect.objectContaining({
      p_verified_user_id: ownerId, p_customer_id: survivorId, p_full_name: "张老师",
    }));
  });
});

describe("safe Customer reads and merge protocol", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockResolvedValue({ user: { sub: ownerId }, clientRequestId });
  });

  it("uses normalized-name duplicate lookup as an advisory projection", async () => {
    const client = rpcClient([{ id: survivorId, name: "华南师范大学", normalized_name: "华南师范大学" }]);
    const queries = createCustomerQueries({ client: client as never });
    await expect(queries.findDuplicateWarnings(" 华南师范大学 ")).resolves.toHaveLength(1);
    expect(client.rpc).toHaveBeenCalledWith("find_customer_duplicate_warnings", {
      p_normalized_name: "华南师范大学", p_exclude_customer_id: null,
    });
  });

  it("previews then executes with the opaque token, plan hash, and both versions", async () => {
    const previewClient = rpcClient([{
      preview_id: crypto.randomUUID(), preview_token: "opaque-once-token-value", plan_hash: "a".repeat(64),
      expires_at: new Date(Date.now() + 60_000).toISOString(), entity_type: "Customer",
      survivor_id: survivorId, duplicate_id: duplicateId, survivor_version: 3, duplicate_version: 5,
      plan: { contactCount: 2 },
    }]);
    const actions = createMergeActions({ authClient: {} as never, serviceClient: previewClient as never });
    const preview = await actions.previewMerge({ entityType: "Customer", survivorId, duplicateId });
    await actions.executeMerge({ ...preview, clientRequestId });
    expect(previewClient.rpc).toHaveBeenLastCalledWith("execute_entity_merge", expect.objectContaining({
      p_verified_user_id: ownerId, p_preview_token: "opaque-once-token-value", p_plan_hash: "a".repeat(64),
      p_survivor_version: 3, p_duplicate_version: 5,
    }));
  });
});
