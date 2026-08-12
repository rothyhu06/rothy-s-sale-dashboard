import { notFound } from "next/navigation";
import { SectionHeader } from "@/components/design-system";
import { LearningForm } from "@/features/learning/components/learning-form";
import { listKnowledge } from "@/features/knowledge/queries";
import { getLearning } from "@/features/learning/queries";
export default async function ReviewLearningPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; const [parent,knowledge] = await Promise.all([getLearning(id).catch(() => null),listKnowledge()]); if (!parent) notFound(); return <div className="grid gap-8"><SectionHeader level={1} title="Create Review" description="Create a new child fact; the original Learning remains unchanged." /><LearningForm knowledge={knowledge} parent={{ id: parent.id, title: parent.title }} selectedKnowledge={parent.knowledgeLinks.map((link) => ({ id: String(link.knowledgeId), masteryBefore: String(link.masteryAfter) }))} /></div>; }
