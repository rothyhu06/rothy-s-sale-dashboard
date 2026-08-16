"use server";
import { redirect } from "next/navigation";
import { createCustomer } from "./actions";
import { safeActionError } from "@/lib/actions/safe-action-error";
export type CustomerFormState = { message?: string };
const text = (d: FormData, n: string) => String(d.get(n) ?? "").trim();
const nullable = (d: FormData, n: string) => text(d, n) || null;
export async function submitCustomer(_: CustomerFormState, data: FormData): Promise<CustomerFormState> {
  try {
    const result = await createCustomer({ name: text(data,"name"), customerType: text(data,"customerType"), educationSegment: nullable(data,"educationSegment"), region: nullable(data,"region"), website: nullable(data,"website"), background: nullable(data,"background"), businessContext: nullable(data,"businessContext"), currentTechnology: nullable(data,"currentTechnology"), currentCloudProvider: nullable(data,"currentCloudProvider"), knownNeeds: nullable(data,"knownNeeds"), internalAssessment: nullable(data,"internalAssessment"), aliases: [], externalReferences: [], knowledgeLinks: [] }, text(data,"clientRequestId"));
    redirect(`/customers/${result.id}`);
  } catch (error) { if ((error as {digest?:string}).digest?.startsWith("NEXT_REDIRECT")) throw error; return { message: safeActionError(error,{operation:"create-customer",fallback:"客户未能创建，请检查输入后重试。"}) }; }
}
