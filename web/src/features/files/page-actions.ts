"use server";
import { redirect } from "next/navigation";
import { createTag } from "@/features/tags/actions";
import { createAttachmentDownloadUrl, finalizeUpload, prepareUpload } from "@/features/attachments/actions";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { safeActionError } from "@/lib/actions/safe-action-error";
export type State={message?:string};const t=(d:FormData,n:string)=>String(d.get(n)??"").trim();
export async function submitTag(_:State,d:FormData):Promise<State>{try{await createTag({name:t(d,"name"),description:t(d,"description")||null,dataLevel:t(d,"dataLevel")as"Level2"},t(d,"clientRequestId"));redirect("/files")}catch(e){if((e as{digest?:string}).digest?.startsWith("NEXT_REDIRECT"))throw e;return{message:safeActionError(e,{operation:"create-tag",fallback:"标签未能创建。"})}}}
export async function submitAttachment(_:State,d:FormData):Promise<State>{try{const file=d.get("file");if(!(file instanceof File)||file.size===0)return{message:"请选择文件。"};const prepared=await prepareUpload({originalFilename:file.name,mimeType:file.type,sizeBytes:file.size,dataLevel:t(d,"dataLevel")as"Level2",classificationReason:t(d,"classificationReason")||null},t(d,"clientRequestId"));const upload=await createServiceRoleClient().storage.from("business-attachments").uploadToSignedUrl(prepared.objectPath,prepared.uploadToken,file,{contentType:file.type});if(upload.error)throw upload.error;await finalizeUpload({attachmentId:prepared.attachmentId},crypto.randomUUID());redirect("/files")}catch(e){if((e as{digest?:string}).digest?.startsWith("NEXT_REDIRECT"))throw e;return{message:safeActionError(e,{operation:"upload-attachment",fallback:"文件未能安全上传。"})}}}
export async function downloadAttachment(d:FormData){const url=await createAttachmentDownloadUrl({attachmentId:t(d,"attachmentId"),expiresIn:60});redirect(url)}
