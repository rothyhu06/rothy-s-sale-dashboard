import { notFound } from "next/navigation";
import { SectionHeader } from "@/components/design-system";
import { LearningForm } from "@/features/learning/components/learning-form";
import { listKnowledge } from "@/features/knowledge/queries";
import { getLearning } from "@/features/learning/queries";
import { getLearningSupport } from "@/features/learning/queries";
import { submitReviewLearning } from "@/features/learning/page-actions";
import { EntityNotFoundError } from "@/lib/queries/entity-not-found";
export default async function ReviewLearningPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; let parent: Awaited<ReturnType<typeof getLearning>>; try { parent = await getLearning(id); } catch (error) { if (error instanceof EntityNotFoundError) notFound(); throw error; } if (parent.status !== "Completed") notFound(); const [knowledge,support] = await Promise.all([listKnowledge(),getLearningSupport()]); const action = submitReviewLearning.bind(null, parent.id); return <div className="grid gap-8"><SectionHeader level={1} title="Create Review" description="Create a new child fact; the original Learning remains unchanged. Parent links are inherited only when you select them below." /><LearningForm knowledge={knowledge} support={support} submitAction={action} parent={{ id: parent.id, title: parent.title, tags: parent.tags as never, attachments: parent.attachments as never }} selectedKnowledge={parent.knowledgeLinks.map((link) => ({ id: String(link.knowledgeId), masteryBefore: String(link.masteryAfter) }))} /></div>; }
