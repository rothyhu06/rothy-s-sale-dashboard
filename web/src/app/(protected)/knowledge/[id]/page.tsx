import { notFound } from "next/navigation";
import { Badge, Divider, SectionHeader } from "@/components/design-system";
import { getKnowledge } from "@/features/knowledge/queries";

export default async function KnowledgeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let item: Awaited<ReturnType<typeof getKnowledge>>;
  try { item = await getKnowledge(id); } catch { notFound(); }
  return <article className="grid gap-8">
    <SectionHeader level={1} title={item.title} description={item.summary ?? undefined} metadata={`Updated ${new Date(item.updatedAt).toLocaleDateString()}`} action={<span className="flex gap-4"><a className="type-control text-accent" href={`/knowledge/${item.id}/edit`}>Edit Knowledge</a><a className="type-control text-accent" href={`/learning/new?knowledgeId=${item.id}`}>Create Learning</a></span>} />
    <div className="flex flex-wrap gap-2"><Badge tone="accent">{item.status}</Badge><Badge>{item.confidence}</Badge><Badge>{item.knowledgeType}</Badge><Badge>{item.dataLevel}</Badge></div>
    <Divider />
    <section><h2 className="type-heading-2">Knowledge body</h2><p className="type-body-lg max-w-3xl whitespace-pre-line text-ink">{item.contentPlaintext || "No body has been written yet."}</p></section>
    {[['Technical principle',item.technicalPrinciple],['Business value',item.businessValue],['Education scenario',item.educationScenario],['Customer pain point',item.customerPainPoint],['Sales expression',item.salesExpression],['Customer questions',item.customerQuestions],['Competitive note',item.competitiveNote]].filter(([,value]) => value).map(([label,value]) => <section key={label}><h2 className="type-heading-3">{label}</h2><p className="type-body-md whitespace-pre-line text-ink">{value}</p></section>)}
    <Divider />
    <section className="grid gap-3"><h2 className="type-heading-3">Source</h2><p className="type-body-md m-0">{item.sourceType}{item.sourceName ? ` · ${item.sourceName}` : ""}</p>{item.sourceUrl ? <a className="type-control text-accent" href={item.sourceUrl} rel="noreferrer" target="_blank">Open source</a> : null}</section>
    <section className="grid gap-3"><h2 className="type-heading-3">Tags & attachments</h2><div className="flex flex-wrap gap-2">{item.tags.map((tag) => <Badge key={(tag as {id:string}).id}>{(tag as {name:string}).name}</Badge>)}</div>{item.attachments.map((attachment) => <p className="type-body-sm m-0 text-muted" key={(attachment as {id:string}).id}>{(attachment as {original_filename:string}).original_filename}</p>)}</section>
    {item.relations.length ? <section className="grid gap-3"><h2 className="type-heading-3">Related Knowledge</h2>{item.relations.map((relation) => <a className="type-control text-accent" href={`/knowledge/${relation.relatedKnowledgeId}`} key={String(relation.relatedKnowledgeId)}>{(relation.knowledge as {title?:string})?.title ?? "Related Knowledge"}</a>)}</section> : null}
  </article>;
}
