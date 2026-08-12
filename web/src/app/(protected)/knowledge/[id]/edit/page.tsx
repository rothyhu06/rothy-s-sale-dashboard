import { notFound } from "next/navigation";
import { SectionHeader } from "@/components/design-system";
import { KnowledgeForm } from "@/features/knowledge/components/knowledge-form";
import { getKnowledge, getKnowledgeSupport } from "@/features/knowledge/queries";
import { EntityNotFoundError } from "@/lib/queries/entity-not-found";
export default async function EditKnowledgePage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; let initial: Awaited<ReturnType<typeof getKnowledge>>; try { initial = await getKnowledge(id); } catch (error) { if (error instanceof EntityNotFoundError) notFound(); throw error; } const support = await getKnowledgeSupport(); return <div className="grid gap-8"><SectionHeader level={1} title="Edit Knowledge" description="Update the reusable asset without changing its learning history." /><KnowledgeForm initial={initial} support={support} /></div>; }
