import { Divider, EmptyState, SectionHeader } from "@/components/design-system";
import { KnowledgeCollection } from "@/features/knowledge/components/knowledge-collection";
import { listKnowledge } from "@/features/knowledge/queries";

export default async function KnowledgePage() {
  const knowledge = await listKnowledge();
  return <div className="grid gap-8">
    <SectionHeader level={1} title="Knowledge Library" description="Reusable notes that turn learning into customer-ready capability." action={<Link className="type-control text-accent" href="/knowledge/new">New Knowledge</Link>} />
    <Divider />
    {knowledge.length ? <KnowledgeCollection knowledge={knowledge} /> : <EmptyState title="Begin your Knowledge Library" description="Capture one durable idea, source, or customer-ready explanation." action={<Link className="type-control text-accent" href="/knowledge/new">New Knowledge</Link>} />}
  </div>;
}
import Link from "next/link";
