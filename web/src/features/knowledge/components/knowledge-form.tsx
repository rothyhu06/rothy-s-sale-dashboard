"use client";

import { useActionState, useState } from "react";
import { Button, Checkbox, Divider, InputField, SelectInput, TextArea, TextInput } from "@/components/design-system";
import { documentToKnowledgeBody } from "../form-adapter";
import { saveKnowledge, submitKnowledge, type KnowledgeFormState } from "../page-actions";

type Option = { id: string; name?: string; title?: string; original_filename?: string; file_category?: string };
type Initial = Record<string, unknown> & { id?: string; version?: number; tags?: Option[]; attachments?: Option[]; relations?: { relatedKnowledgeId: string }[] };
const groups = {
  knowledgeType: ["Tencent Cloud Product", "AI Technology", "Education Industry", "Sales Method", "Solution Reference", "Case Reference", "General"],
  status: ["Draft", "Learning", "Ready", "Archived"], confidence: ["Official", "Verified", "Observed", "Hypothesis"],
  sourceType: ["Official Doc", "Training", "Meeting", "Customer", "Book", "Website", "Internal Material", "AI Generated", "Personal Note"],
};

export function KnowledgeForm({ initial, support }: { initial?: Initial; support: { tags: Option[]; attachments: Option[]; knowledge: Option[] } }) {
  const edit = Boolean(initial?.id);
  const [state, action, pending] = useActionState<KnowledgeFormState, FormData>(edit ? saveKnowledge : submitKnowledge, {});
  const [clientRequestId] = useState(() => crypto.randomUUID());
  const originalBody = initial?.contentBlocks ? documentToKnowledgeBody(initial.contentBlocks) : "";
  const field = (name: string) => String(initial?.[name] ?? "");
  const selectedTags = new Set((initial?.tags ?? []).map((item) => item.id));
  const selectedAttachments = new Set((initial?.attachments ?? []).map((item) => item.id));
  const selectedRelations = new Set((initial?.relations ?? []).map((item) => item.relatedKnowledgeId));
  const hasStructuredBody = Boolean(initial?.contentBlocks && (initial.contentBlocks as { blocks?: { type?: string }[] }).blocks?.some((block) =>
    !["paragraph", "attachmentReference", "imageReference"].includes(String(block.type))));
  return (
    <form action={action} className="grid gap-8">
      <input name="clientRequestId" type="hidden" value={clientRequestId} />
      {edit ? <><input name="knowledgeId" type="hidden" value={initial?.id} /><input name="version" type="hidden" value={initial?.version} /><input name="originalBody" type="hidden" value={originalBody} /><input name="originalContentBlocks" type="hidden" value={JSON.stringify(initial?.contentBlocks)} /></> : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <InputField id="knowledge-title" label="Title" required><TextInput defaultValue={field("title")} name="title" required /></InputField>
        {Object.entries(groups).map(([name, options]) => <InputField id={`knowledge-${name}`} key={name} label={({ knowledgeType: "Knowledge type", sourceType: "Source type" } as Record<string,string>)[name] ?? name[0].toUpperCase() + name.slice(1)} required><SelectInput defaultValue={field(name) || ({ knowledgeType: "General", status: "Draft", confidence: "Hypothesis", sourceType: "Personal Note" } as Record<string,string>)[name]} name={name}>{options.map((option) => <option key={option}>{option}</option>)}</SelectInput></InputField>)}
        <InputField id="knowledge-source-name" label="Source name"><TextInput defaultValue={field("sourceName")} name="sourceName" /></InputField>
        <InputField id="knowledge-source-url" label="Source URL"><TextInput defaultValue={field("sourceUrl")} name="sourceUrl" type="url" /></InputField>
        <InputField id="knowledge-data-level" label="Data level"><SelectInput defaultValue={field("dataLevel") || "Level1"} name="dataLevel">{["Level1", "Level2", "Level3"].map((option) => <option key={option}>{option}</option>)}</SelectInput></InputField>
      </div>
      <Divider />
      <div className="grid gap-5">
        <InputField id="knowledge-summary" label="Summary"><TextArea defaultValue={field("summary")} name="summary" /></InputField>
        <InputField id="knowledge-body" label="Knowledge body" description="Saved as ContentBlockDocument V1; plaintext is derived by the server."><TextArea defaultValue={originalBody} name="body" /></InputField>
        {edit && hasStructuredBody ? <div className="radius-card border border-border bg-paper p-4"><Checkbox label="将结构化正文转换为纯文本段落" name="confirmStructureConversion" /><p className="type-body-sm mb-0 mt-2 text-muted">仅在修改正文时勾选。转换会将标题、列表、代码与提示框等结构化文本块替换为纯文本段落；已选附件与图片引用块及其说明文字会保留。</p></div> : null}
        {[['technicalPrinciple','Technical principle'],['businessValue','Business value'],['educationScenario','Education scenario'],['customerPainPoint','Customer pain point'],['salesExpression','Sales expression'],['customerQuestions','Customer questions'],['competitiveNote','Competitive note']].map(([name,label]) => <InputField id={`knowledge-${name}`} key={name} label={label}><TextArea defaultValue={field(name)} name={name} /></InputField>)}
      </div>
      <Divider />
      <fieldset className="grid gap-3"><legend className="type-heading-3 mb-3">Tags</legend>{support.tags.length ? support.tags.map((tag) => <Checkbox defaultChecked={selectedTags.has(tag.id)} key={tag.id} label={tag.name ?? "Tag"} name="tagIds" value={tag.id} />) : <p className="type-body-sm m-0 text-muted">No tags are available yet.</p>}</fieldset>
      <fieldset className="grid gap-3"><legend className="type-heading-3 mb-3">Attachments</legend>{support.attachments.length ? support.attachments.map((attachment) => <Checkbox defaultChecked={selectedAttachments.has(attachment.id)} key={attachment.id} label={`${attachment.original_filename} · ${attachment.file_category}`} name="attachmentIds" value={attachment.id} />) : <p className="type-body-sm m-0 text-muted">No verified attachments are available.</p>}</fieldset>
      <fieldset className="grid gap-3"><legend className="type-heading-3 mb-3">Related Knowledge</legend>{support.knowledge.filter((item) => item.id !== initial?.id).map((item) => <Checkbox defaultChecked={selectedRelations.has(item.id)} key={item.id} label={item.title ?? "Knowledge"} name="relatedKnowledgeIds" value={item.id} />)}</fieldset>
      {state.message ? <p className="type-body-md m-0 text-danger" role="alert">{state.message}</p> : null}
      <div className="flex flex-wrap gap-4"><Button loading={pending} size="large" type="submit">{edit ? "Save changes" : "Create Knowledge"}</Button><a className="type-control inline-flex min-h-11 items-center text-accent" href={edit ? `/knowledge/${initial?.id}` : "/knowledge"}>Cancel</a></div>
    </form>
  );
}
