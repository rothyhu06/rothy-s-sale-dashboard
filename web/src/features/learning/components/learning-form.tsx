"use client";

import { useActionState, useState } from "react";
import Link from "next/link";
import { Button, InputField, SelectInput, TextArea, TextInput } from "@/components/design-system";
import { submitLearning, type LearningFormState } from "../page-actions";

type Knowledge = { id: string; title: string };
type SelectedKnowledge = { id: string; masteryBefore: string };

export function LearningForm({ knowledge, selectedKnowledgeId, selectedMasteryBefore = "Understand", selectedKnowledge, parent }: { knowledge: Knowledge[]; selectedKnowledgeId?: string; selectedMasteryBefore?: string; selectedKnowledge?: SelectedKnowledge[]; parent?: { id: string; title: string } }) {
  const [state, action, pending] = useActionState<LearningFormState, FormData>(submitLearning, {});
  const [clientRequestId] = useState(() => crypto.randomUUID());
  const review = Boolean(parent);
  return (
    <form action={action} className="grid gap-6">
      <input name="clientRequestId" type="hidden" value={clientRequestId} />
      {parent ? <input name="parentLearningId" type="hidden" value={parent.id} /> : null}
      <InputField id="learning-title" label="Title" required><TextInput name="title" required /></InputField>
      <div className="grid gap-5 sm:grid-cols-2">
        <InputField id="learning-type" label="Learning type"><SelectInput defaultValue={review ? "Review" : "Study"} disabled={review} name={review ? undefined : "learningType"}>{["Study", "Practice", "Course", "Product Training", "Case Analysis"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
        {review ? <input name="learningType" type="hidden" value="Review" /> : null}
        <InputField id="learning-status" label="Status"><SelectInput defaultValue="Planned" name="status">{["Planned", "In Progress"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
        <InputField id="learning-started-at" label="Started at"><TextInput name="startedAt" type="datetime-local" /></InputField>
        <InputField id="learning-data-level" label="Data level"><SelectInput defaultValue="Level2" name="dataLevel">{["Level1", "Level2", "Level3"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
      </div>
      <InputField id="learning-objective" label="Objective"><TextArea name="objective" /></InputField>
      {parent ? <p className="type-body-md m-0 text-muted">Review of <a className="text-accent" href={`/learning/${parent.id}`}>{parent.title}</a></p> : null}
      {selectedKnowledge?.length ? <fieldset className="grid gap-5"><legend className="type-heading-3 mb-3">Linked Knowledge</legend>{selectedKnowledge.map((selected, index) => <div className="grid gap-5 sm:grid-cols-2" key={selected.id}><input name="knowledgeId" type="hidden" value={selected.id} /><p className="type-body-md m-0">{knowledge.find((item) => item.id === selected.id)?.title}</p><InputField id={`learning-mastery-before-${index}`} label={`Mastery before for ${knowledge.find((item) => item.id === selected.id)?.title}`}><SelectInput defaultValue={selected.masteryBefore} name="masteryBefore">{["Aware", "Understand", "Explain", "Apply", "Teach"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField></div>)}</fieldset> : <div className="grid gap-5 sm:grid-cols-2">
        <InputField id="learning-knowledge" label="Linked Knowledge"><SelectInput defaultValue={selectedKnowledgeId ?? ""} name="knowledgeId"><option value="">No linked Knowledge</option>{knowledge.map((item) => <option key={item.id} value={item.id}>{item.title}</option>)}</SelectInput></InputField>
        <InputField id="learning-mastery-before" label={selectedKnowledgeId ? `Mastery before for ${knowledge.find((item) => item.id === selectedKnowledgeId)?.title}` : "Mastery before"}><SelectInput defaultValue={selectedMasteryBefore} name="masteryBefore">{["Aware", "Understand", "Explain", "Apply", "Teach"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
      </div>}
      {state.message ? <p className="type-body-md m-0 text-danger" role="alert">{state.message}</p> : null}
      <div className="flex flex-wrap gap-4"><Button loading={pending} size="large" type="submit">{review ? "Create Review" : "Create Learning"}</Button><Link className="type-control inline-flex min-h-11 items-center text-accent" href="/learning">Cancel</Link></div>
    </form>
  );
}
