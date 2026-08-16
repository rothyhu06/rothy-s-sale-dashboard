"use client";
import Link from "next/link";
import { useActionState, useState } from "react";
import { Button, InputField, SelectInput, TextArea, TextInput } from "@/components/design-system";
import { submitCustomer, type CustomerFormState } from "../page-actions";
export function CustomerForm() {
  const [state, action, pending] = useActionState<CustomerFormState,FormData>(submitCustomer,{});
  const [requestId] = useState(()=>crypto.randomUUID());
  return <form action={action} className="grid gap-6"><input name="clientRequestId" type="hidden" value={requestId}/><div className="grid gap-5 sm:grid-cols-2">
    <InputField id="customer-name" label="Institution name" required><TextInput name="name" required/></InputField>
    <InputField id="customer-type" label="Customer type" required><SelectInput name="customerType"><option>University</option><option>K12 School</option><option>Vocational Education</option><option>Training Institution</option><option>Online Education</option><option>Other</option></SelectInput></InputField>
    <InputField id="customer-segment" label="Education segment"><TextInput name="educationSegment"/></InputField><InputField id="customer-region" label="Region"><TextInput name="region"/></InputField><InputField id="customer-website" label="Website"><TextInput name="website" type="url"/></InputField><InputField id="customer-cloud" label="Current cloud provider"><TextInput name="currentCloudProvider"/></InputField>
  </div>{[["background","Background"],["businessContext","Business context"],["currentTechnology","Current technology"],["knownNeeds","Known needs"],["internalAssessment","Internal assessment"]].map(([name,label])=><InputField id={`customer-${name}`} key={name} label={label}><TextArea name={name}/></InputField>)}
  {state.message?<p role="alert" className="type-body-sm text-danger">{state.message}</p>:null}<div className="flex gap-4"><Button loading={pending} size="large" type="submit">Create Customer</Button><Link className="type-control inline-flex min-h-11 items-center text-accent" href="/customers">Cancel</Link></div></form>;
}
