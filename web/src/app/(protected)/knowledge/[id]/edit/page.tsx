import { notFound } from "next/navigation";
import { SectionHeader } from "@/components/design-system";
import { KnowledgeForm } from "@/features/knowledge/components/knowledge-form";
import { getKnowledge, getKnowledgeSupport } from "@/features/knowledge/queries";
export default async function EditKnowledgePage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; const [initial,support] = await Promise.all([getKnowledge(id).catch(() => null),getKnowledgeSupport()]); if (!initial) notFound(); return <div className="grid gap-8"><SectionHeader level={1} title="Edit Knowledge" description="Update the reusable asset without changing its learning history." /><KnowledgeForm initial={initial} support={support} /></div>; }
