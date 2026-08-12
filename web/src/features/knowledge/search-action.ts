"use server";

import { searchKnowledge } from "./queries";

export type KnowledgeSearchState = { results?: Awaited<ReturnType<typeof searchKnowledge>>; message?: string };

export async function searchKnowledgeAction(_state: KnowledgeSearchState, data: FormData): Promise<KnowledgeSearchState> {
  const query = String(data.get("query") ?? "").trim();
  if (!query) return { results: [] };
  try {
    return { results: await searchKnowledge(query, 50) };
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Knowledge search could not be completed" };
  }
}
