import { SectionHeader } from "@/components/design-system";
import { LearningForm } from "@/features/learning/components/learning-form";
import { listKnowledge } from "@/features/knowledge/queries";
import { getLearningSupport } from "@/features/learning/queries";
export default async function NewLearningPage({ searchParams }: { searchParams: Promise<{ knowledgeId?: string }> }) { const options = await searchParams; const [knowledge,support] = await Promise.all([listKnowledge(),getLearningSupport()]); return <div className="grid gap-8"><SectionHeader level={1} title="New Learning" description="Record the real activity and the mastery level you are beginning from." /><LearningForm knowledge={knowledge} support={support} selectedKnowledgeId={options.knowledgeId} /></div>; }
