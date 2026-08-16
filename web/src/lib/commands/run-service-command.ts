import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createCommandContext } from "./command-context";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

export async function runServiceCommand(commandType:string,rpc:string,clientRequestId:string,params:Record<string,unknown>,dependencies?:{authClient:Parameters<typeof createCommandContext>[2];serviceClient:Pick<SupabaseClient,"rpc">}){
  const authClient=dependencies?.authClient??await createServerClient();const serviceClient=dependencies?.serviceClient??createServiceRoleClient();
  const context=await createCommandContext(commandType,clientRequestId,authClient);const{data,error}=await serviceClient.rpc(rpc,{p_verified_user_id:context.user.sub,p_client_request_id:context.clientRequestId,...params});
  if(error)throw new Error(`${commandType} could not be completed`,{cause:error});return Array.isArray(data)?data[0]:data;
}
