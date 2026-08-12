import { Card, Divider, EmptyState, SectionHeader } from "@/components/design-system";
import { getContinueLearning, listLearning } from "@/features/learning/queries";

export default async function LearningPage() {
  const [continuing, learning] = await Promise.all([getContinueLearning(8), listLearning()]);
  return <div className="grid gap-12">
    <SectionHeader level={1} title="Learning Journal" description="Each study, practice, and review remains a real fact in your learning chain." action={<Link className="type-control text-accent" href="/learning/new">New Learning</Link>} />
    <section className="grid gap-6"><SectionHeader title="Continue Learning" description="Return to work that is planned or already in progress." />{continuing.length ? <div className="grid gap-4 sm:grid-cols-2">{continuing.map((item) => <Card href={`/learning/${item.id}`} key={item.id} variant="action"><p className="type-label m-0 text-accent">{item.status}</p><h3 className="type-heading-3 mt-2">{item.title}</h3><p className="type-body-sm mb-0 mt-3 text-muted">{item.objective || item.learningType}</p></Card>)}</div> : <EmptyState title="Nothing waiting for you" description="Create a Learning entry when you are ready to study, practice, or review." action={<Link className="type-control text-accent" href="/learning/new">New Learning</Link>} />}</section>
    <Divider />
    <section className="grid gap-6"><SectionHeader title="Learning history" metadata={`${learning.length} entries`} />{learning.length ? <div className="grid gap-4">{learning.map((item) => <Card href={`/learning/${item.id}`} key={item.id} variant="entity"><div className="flex items-start justify-between gap-4"><div><p className="type-label m-0 text-accent">{item.learningType}</p><h3 className="type-heading-3 mt-2">{item.title}</h3></div><span className="type-metadata text-muted">{item.status}</span></div></Card>)}</div> : null}</section>
  </div>;
}
import Link from "next/link";
