"use client";

import { useActionState, useState } from "react";
import { Button, InputField, SelectInput, TextArea, TextInput } from "@/components/design-system";
import { finishLearning, type LearningFormState } from "../page-actions";

export function CompleteLearningForm({ learningId, version, knowledgeLinks }: { learningId: string; version: number; knowledgeLinks: { knowledgeId: string; title: string; masteryBefore: string; masteryAfter: string }[] }) {
  const [state, action, pending] = useActionState<LearningFormState, FormData>(finishLearning, {});
  const [clientRequestId] = useState(() => crypto.randomUUID());
  return <form action={action} className="grid gap-5">
    <input name="clientRequestId" type="hidden" value={clientRequestId} /><input name="learningId" type="hidden" value={learningId} /><input name="version" type="hidden" value={version} />
    <div className="grid gap-5 sm:grid-cols-2">
      <InputField id="learning-outcome" label="Learning outcome"><SelectInput defaultValue="Applied" name="learningOutcome">{["Passed", "Needs Practice", "Blocked", "Applied", "Shared"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField>
      <InputField id="learning-duration" label="Duration minutes"><TextInput min="0" name="durationMinutes" type="number" /></InputField>
    </div>
    {knowledgeLinks.map((link, index) => <div className="grid gap-3" key={link.knowledgeId}><input name="knowledgeId" type="hidden" value={link.knowledgeId} /><InputField id={`learning-mastery-after-${index}`} label={knowledgeLinks.length === 1 ? "Mastery after" : `Mastery after for ${link.title}`}><SelectInput defaultValue={link.masteryAfter} name="masteryAfter">{["Aware", "Understand", "Explain", "Apply", "Teach"].map((value) => <option key={value}>{value}</option>)}</SelectInput></InputField></div>)}
    <InputField id="learning-takeaway" label="Takeaway"><TextArea name="takeaway" /></InputField>
    <InputField id="learning-practice-result" label="Practice result"><TextArea name="practiceResult" /></InputField>
    {state.message ? <p className="type-body-md m-0 text-danger" role="alert">{state.message}</p> : null}
    <Button loading={pending} type="submit">Complete Learning</Button>
  </form>;
}
