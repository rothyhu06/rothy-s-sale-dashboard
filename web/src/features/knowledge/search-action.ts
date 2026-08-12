"use server";

import { searchKnowledge } from "./queries";
import { safeActionError } from "@/lib/actions/safe-action-error";

export type KnowledgeSearchState = { results?: Awaited<ReturnType<typeof searchKnowledge>>; message?: string };

export async function searchKnowledgeAction(_state: KnowledgeSearchState, data: FormData): Promise<KnowledgeSearchState> {
  const query = String(data.get("query") ?? "").trim();
  if (!query) return { results: [] };
  try {
    return { results: await searchKnowledge(query, 50) };
  } catch (error) {
    return { message: safeActionError(error, { operation: "search-knowledge", fallback: "知识搜索未能完成，请稍后重试。" }) };
  }
}
