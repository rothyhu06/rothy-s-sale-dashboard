import { SectionHeader } from "@/components/design-system";
import { LearningForm } from "@/features/learning/components/learning-form";
import { listKnowledge } from "@/features/knowledge/queries";
export default async function NewLearningPage({ searchParams }: { searchParams: Promise<{ knowledgeId?: string; parentId?: string }> }) { const options = await searchParams; const knowledge = await listKnowledge(); return <div className="grid gap-8"><SectionHeader level={1} title="New Learning" description="Record the real activity and the mastery level you are beginning from." /><LearningForm knowledge={knowledge} selectedKnowledgeId={options.knowledgeId} /></div>; }
