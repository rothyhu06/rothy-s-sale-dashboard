import { SectionHeader } from "@/components/design-system";
import { KnowledgeForm } from "@/features/knowledge/components/knowledge-form";
import { getKnowledgeSupport } from "@/features/knowledge/queries";
export default async function NewKnowledgePage() { const support = await getKnowledgeSupport(); return <div className="grid gap-8"><SectionHeader level={1} title="New Knowledge" description="Capture the reusable asset, its source, and what it means in practice." /><KnowledgeForm support={support} /></div>; }
