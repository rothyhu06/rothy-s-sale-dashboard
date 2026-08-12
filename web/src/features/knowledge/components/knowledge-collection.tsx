"use client";

import { useActionState, useMemo, useState } from "react";
import { Button, Card, EmptyState, InputField, SelectInput, TextInput } from "@/components/design-system";
import { searchKnowledgeAction, type KnowledgeSearchState } from "../search-action";

type Knowledge = { id: string; title: string; knowledgeType: string; status: string; confidence: string; summary: string | null; contentPlaintext: string; updatedAt: string };

export function KnowledgeCollection({ knowledge }: { knowledge: Knowledge[] }) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("All");
  const [searchState, searchAction, searching] = useActionState<KnowledgeSearchState, FormData>(searchKnowledgeAction, {});
  const filtered = useMemo(() => knowledge.filter((item) => {
    const haystack = `${item.title} ${item.summary ?? ""} ${item.contentPlaintext}`.normalize("NFKC").toLocaleLowerCase();
    return (status === "All" || item.status === status) && haystack.includes(search.normalize("NFKC").trim().toLocaleLowerCase());
  }), [knowledge, search, status]);

  return (
    <div className="grid gap-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <form action={searchAction} className="grid gap-3"><InputField id="knowledge-search" label="Search Knowledge"><TextInput name="query" type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></InputField><Button loading={searching} type="submit" variant="secondary">Search</Button></form>
        <InputField id="knowledge-status-filter" label="Status filter">
          <SelectInput value={status} onChange={(event) => setStatus(event.target.value)}>
            {['All', 'Draft', 'Learning', 'Ready', 'Archived'].map((value) => <option key={value}>{value}</option>)}
          </SelectInput>
        </InputField>
      </div>
      {searchState.message ? <p className="type-body-md m-0 text-danger" role="alert">{searchState.message}</p> : null}
      {searchState.results?.length ? <section className="grid gap-3"><h2 className="type-heading-3">Search results</h2>{searchState.results.map((result) => <a className="type-control text-accent" href={result.route} key={result.knowledgeId}>{result.title}</a>)}</section> : null}
      {filtered.length ? <div className="grid gap-4 sm:grid-cols-2">{filtered.map((item) => (
        <Card href={`/knowledge/${item.id}`} key={item.id} variant="entity">
          <p className="type-label m-0 text-accent">{item.knowledgeType}</p>
          <h2 className="type-heading-3 mt-2">{item.title}</h2>
          <p className="type-body-sm mb-0 mt-3 text-muted">{item.summary || item.contentPlaintext || "Open this note to continue shaping it."}</p>
          <p className="type-metadata mb-0 mt-4 text-muted">{item.status} · {item.confidence}</p>
        </Card>
      ))}</div> : <EmptyState title="No Knowledge matches these filters." description="Clear or adjust the filters to return to your library." action={<button className="type-control text-accent" onClick={() => { setSearch(""); setStatus("All"); }} type="button">Clear filters</button>} />}
    </div>
  );
}
