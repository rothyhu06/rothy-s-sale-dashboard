import "server-only";

import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

const tagInputSchema = z.object({
  name: z.string().trim().min(1).max(80),
  description: z.string().trim().max(500).nullable().optional(),
  dataLevel: z.enum(["Level1", "Level2", "Level3"]).default("Level2"),
});
const tagRowSchema = z.object({ id: z.uuid(), name: z.string(), normalized_name: z.string(), version: z.coerce.number().int().positive() });
type TagServiceClient = { rpc(name: string, params: Record<string, unknown>): Promise<{ data: unknown; error: unknown }> };
type TagDependencies = { authClient: Parameters<typeof createCommandContext>[2]; serviceClient: TagServiceClient };

function normalizeTagName(name: string) {
  return name.normalize("NFKC").trim().replace(/\s+/g, " ").toLocaleLowerCase("en-US");
}

export function createTagActions(dependencies: TagDependencies) {
  return {
    async createTag(input: z.input<typeof tagInputSchema>, clientRequestId: string) {
      const value = tagInputSchema.parse(input);
      const name = value.name.trim().replace(/\s+/g, " ");
      const context = await createCommandContext("CreateTag", clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("create_tag", {
        p_verified_user_id: context.user.sub,
        p_client_request_id: context.clientRequestId,
        p_name: name,
        p_normalized_name: normalizeTagName(name),
        p_description: value.description ?? null,
        p_data_level: value.dataLevel,
      });
      if (error) throw new Error("Tag could not be created", { cause: error });
      return tagRowSchema.parse(Array.isArray(data) ? data[0] : data);
    },
  };
}

async function defaultActions() {
  return createTagActions({
    authClient: await createServerClient(),
    serviceClient: createServiceRoleClient() as unknown as TagServiceClient,
  });
}

export async function createTag(input: z.input<typeof tagInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createTag(input, clientRequestId);
}
