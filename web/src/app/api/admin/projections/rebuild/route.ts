import { NextResponse } from "next/server";
import { createCommandContext } from "@/lib/commands/command-context";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
export async function POST(request:Request){try{const auth=await createServerClient();const requestId=request.headers.get("idempotency-key")??crypto.randomUUID();const context=await createCommandContext("RebuildSearchDocuments",requestId,auth);const{data,error}=await createServiceRoleClient().rpc("rebuild_search_documents",{p_verified_user_id:context.user.sub,p_client_request_id:context.clientRequestId,p_projection_schema_version:1});if(error)throw error;return NextResponse.json(Array.isArray(data)?data[0]:data)}catch{return NextResponse.json({error:"Projection rebuild could not be completed"},{status:401})}}
