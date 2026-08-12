import { notFound } from "next/navigation";
import { Badge, Divider, Progress, SectionHeader } from "@/components/design-system";
import { CompleteLearningForm } from "@/features/learning/components/complete-learning-form";
import { getLearning } from "@/features/learning/queries";
const masteryValue: Record<string, number> = { Aware: 20, Understand: 40, Explain: 60, Apply: 80, Teach: 100 };

export default async function LearningDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params; let item: Awaited<ReturnType<typeof getLearning>>;
  try { item = await getLearning(id); } catch { notFound(); }
  return <article className="grid gap-8">
    <SectionHeader level={1} title={item.title} description={item.objective ?? undefined} metadata={item.status} action={item.status === "Completed" ? <a className="type-control text-accent" href={`/learning/${item.id}/review`}>Create Review</a> : undefined} />
    <div className="flex flex-wrap gap-2"><Badge tone={item.status === "Completed" ? "success" : "accent"}>{item.status}</Badge><Badge>{item.learningType}</Badge>{item.learningOutcome ? <Badge tone="success">{item.learningOutcome}</Badge> : null}</div>
    {item.knowledgeLinks.length ? <section className="grid gap-5"><h2 className="type-heading-3">Linked Knowledge</h2>{item.knowledgeLinks.map((link) => <div className="grid gap-3" key={String(link.knowledgeId)}><a className="type-control text-accent" href={`/knowledge/${link.knowledgeId}`}>{(link.knowledge as {title?:string})?.title ?? "Knowledge"}</a><Progress label="Mastery" level={`${link.masteryBefore} → ${link.masteryAfter}`} value={masteryValue[String(link.masteryAfter)]} /></div>)}</section> : null}
    {item.parent ? <p className="type-body-md m-0 text-muted">Review of <a className="text-accent" href={`/learning/${(item.parent as {id:string}).id}`}>{(item.parent as {title:string}).title}</a></p> : null}
    {item.children.length ? <section className="grid gap-3"><h2 className="type-heading-3">Review chain</h2>{item.children.map((child) => <a className="type-control text-accent" href={`/learning/${(child as {id:string}).id}`} key={(child as {id:string}).id}>{(child as {title:string}).title}</a>)}</section> : null}
    {item.practiceResult ? <section><h2 className="type-heading-3">Practice result</h2><p className="type-body-lg whitespace-pre-line">{item.practiceResult}</p></section> : null}
    {item.takeaway ? <section><h2 className="type-heading-3">Takeaway</h2><p className="type-body-lg whitespace-pre-line">{item.takeaway}</p></section> : null}
    {item.status !== "Completed" && item.status !== "Cancelled" ? <><Divider /><section className="grid gap-5"><SectionHeader title="Complete this Learning" description="Record the outcome and advance mastery only when the work is complete." /><CompleteLearningForm learningId={item.id} knowledgeLinks={item.knowledgeLinks.map((link) => ({ knowledgeId: String(link.knowledgeId), title: (link.knowledge as {title?:string})?.title ?? "Knowledge", masteryBefore: String(link.masteryBefore), masteryAfter: String(link.masteryAfter) }))} version={item.version} /></section></> : null}
  </article>;
}
