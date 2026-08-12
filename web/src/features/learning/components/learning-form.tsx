"use client";

import { useActionState, useState } from "react";
import Link from "next/link";
import { Button, Checkbox, InputField, SelectInput, TextArea, TextInput } from "@/components/design-system";
import { submitLearning, type LearningFormState } from "../page-actions";

type Knowledge = { id: string; title: string };
type SelectedKnowledge = { id: string; masteryBefore: string };
type Support = { tags: { id: string; name: string }[]; attachments: { id: string; original_filename: string; file_category: string }[] };
type LearningSubmitAction = (state: LearningFormState, data: FormData) => Promise<LearningFormState>;

export function LearningForm({ knowledge, support, selectedKnowledgeId, selectedMasteryBefore = "Understand", selectedKnowledge, parent, submitAction = submitLearning }: { knowledge: Knowledge[]; support: Support; selectedKnowledgeId?: string; selectedMasteryBefore?: string; selectedKnowledge?: SelectedKnowledge[]; parent?: { id: string; title: string; tags?: Support["tags"]; attachments?: Support["attachments"] }; submitAction?: LearningSubmitAction }) {
  const [state, action, pending] = useActionState<LearningFormState, FormData>(submitAction, {});
  const [clientRequestId] = useState(() => crypto.randomUUID());
  const review = Boolean(parent);
  const selectedById = new Map((selectedKnowledge ?? []).map((item) => [item.id, item]));
  return (
    <form action={action} className="grid gap-6">
      <input name="clientRequestId" type="hidden" value={clientRequestId} />
      <InputField id="learning-title" label="Title" required><TextInput name="title" required /></InputField>
      <div className="grid gap-5 sm:grid-cols-2">
        <InputField id="learning-type" label="Learning type"><SelectInput defaultValue={review ? "Review" : "Study"} disabled={review} name={review ? undefined : "learningType"}>{["Study", "Practice", "Course", "Product Training", "Case Analysis"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
        <InputField id="learning-status" label="Status"><SelectInput defaultValue="Planned" name="status">{["Planned", "In Progress"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
        <InputField id="learning-started-at" label="Started at"><TextInput name="startedAt" type="datetime-local" /></InputField>
        <InputField id="learning-data-level" label="Data level"><SelectInput defaultValue="Level2" name="dataLevel">{["Level1", "Level2", "Level3"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
      </div>
      <InputField id="learning-objective" label="Objective"><TextArea name="objective" /></InputField>
      {parent ? <p className="type-body-md m-0 text-muted">Review of <a className="text-accent" href={`/learning/${parent.id}`}>{parent.title}</a></p> : null}
      <fieldset className="grid gap-5"><legend className="type-heading-3 mb-3">Linked Knowledge</legend>{knowledge.length ? knowledge.map((item, index) => { const inherited = selectedById.get(item.id); const defaultMastery = inherited?.masteryBefore ?? (item.id === selectedKnowledgeId ? selectedMasteryBefore : "Aware"); return <div className="grid gap-3 sm:grid-cols-2" key={item.id}><Checkbox defaultChecked={!review && item.id === selectedKnowledgeId} label={inherited && review ? `${item.title} · linked to parent (select to inherit)` : item.title} name="knowledgeId" value={item.id} /><InputField id={`learning-mastery-before-${index}`} label={`Mastery before for ${item.title}`}><SelectInput defaultValue={defaultMastery} name={`masteryBefore-${item.id}`}>{["Aware", "Understand", "Explain", "Apply", "Teach"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField></div>; }) : <p className="type-body-sm m-0 text-muted">No Knowledge is available yet.</p>}</fieldset>
      <fieldset className="grid gap-3"><legend className="type-heading-3 mb-3">Tags</legend>{support.tags.length ? support.tags.map((tag) => <Checkbox key={tag.id} label={parent?.tags?.some((item) => item.id === tag.id) ? `${tag.name} · linked to parent (select to inherit)` : tag.name} name="tagIds" value={tag.id} />) : <p className="type-body-sm m-0 text-muted">No tags are available yet.</p>}</fieldset>
      <fieldset className="grid gap-3"><legend className="type-heading-3 mb-3">Attachments</legend>{support.attachments.length ? support.attachments.map((attachment) => <Checkbox key={attachment.id} label={`${attachment.original_filename} · ${attachment.file_category}${parent?.attachments?.some((item) => item.id === attachment.id) ? " · linked to parent (select to inherit)" : ""}`} name="attachmentIds" value={attachment.id} />) : <p className="type-body-sm m-0 text-muted">No verified attachments are available.</p>}</fieldset>
      {state.message ? <p className="type-body-md m-0 text-danger" role="alert">{state.message}</p> : null}
      <div className="flex flex-wrap gap-4"><Button loading={pending} size="large" type="submit">{review ? "Create Review" : "Create Learning"}</Button><Link className="type-control inline-flex min-h-11 items-center text-accent" href="/learning">Cancel</Link></div>
    </form>
  );
}
