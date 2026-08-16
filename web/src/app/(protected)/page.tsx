/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import { Badge, Card, ContextPanel, Divider, EmptyState, SectionHeader, Timeline } from "@/components/design-system";
import { signOut } from "@/app/(public)/login/actions";
import { Button } from "@/components/design-system/button";
import { getDashboard } from "@/features/dashboard/query";
import { getTimeline } from "@/features/timeline/query";

export default async function Home() {
  const [dash, timeline] = await Promise.all([getDashboard(), getTimeline(6)]);
  const focus = [
    ...dash.tasks.map((item: any) => ({ type: "Next Action", title: item.title, detail: item.due_at ? `Due ${new Date(item.due_at).toLocaleString()}` : "Schedule it", href: `/tasks/${item.id}` })),
    ...dash.opportunities.slice(0, Math.max(0, 4 - dash.tasks.length)).map((item: any) => ({ type: "Opportunity", title: item.name, detail: "Review the next stage", href: `/opportunities/${item.id}` })),
  ].slice(0, 4);
  return <div className="grid gap-10 xl:grid-cols-[minmax(0,1fr)_280px]">
    <div className="grid gap-10">
      <header className="flex items-start justify-between gap-6"><div><p className="type-label text-accent">Adaptive Sales Command Center</p><h1 className="type-heading-1 mt-3">Good {new Date().getHours() < 12 ? "morning" : "evening"}, Yuxing</h1><p className="type-body-md mt-3 text-muted">Build knowledge. Understand customers. Create value.</p></div><form action={signOut}><Button type="submit" variant="secondary">退出登录</Button></form></header>
      <Card variant="entity"><p className="type-label text-accent">Daily Brief · Rule based</p><p className="type-heading-3 mt-3">{focus[0] ? `Start with “${focus[0].title}”. Move one real commitment forward before opening new work.` : "Your workspace is clear. Capture one Learning or Customer Interaction today."}</p></Card>
      <section className="grid gap-5"><SectionHeader title="Today Focus" description="The few actions that deserve attention now." action={<Link className="text-accent" href="/tasks/new">Quick capture</Link>} />
        {focus.length ? <div className="grid gap-4 sm:grid-cols-2">{focus.map((item: any) => <Card href={item.href} key={`${item.type}:${item.title}`} variant="action"><Badge tone="accent">{item.type}</Badge><h3 className="type-heading-3 mt-4">{item.title}</h3><p className="type-body-sm text-muted">{item.detail}</p></Card>)}</div> : <EmptyState action={<Link className="text-accent" href="/learning/new">Start Learning</Link>} title="A quiet day" description="Choose one capability to improve." />}
      </section>
      <Divider />
      <section><SectionHeader title="Memory Timeline" description="A growing archive of work and learning." action={<Link className="text-accent" href="/timeline">View all</Link>} /><Timeline entries={timeline.map((item) => ({ ...item, time: new Date(item.time).toLocaleString() }))} /></section>
      <section><SectionHeader title="Weekly Reflection" description="Lightweight growth feedback—not a BI dashboard." /><div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {[ ["Interactions", dash.interactions.length], ["Insights", dash.insights.length], ["Active Tasks", dash.tasks.length], ["Learning", dash.learning.length] ].map(([label, value]) => <Card key={label} variant="entity"><p className="type-label text-muted">{label}</p><p className="type-heading-2">{value}</p></Card>)}
      </div></section>
    </div>
    <aside className="hidden xl:block"><div className="sticky top-12"><ContextPanel capability={dash.learning[0]?.title ?? "Customer Discovery"} editorNote="The system prioritizes action from real Tasks and sales facts." opportunity={dash.opportunities[0]?.name} actions={["Finish one commitment", "Capture the result as an Interaction", "Turn validated learning into an Insight"]} /></div></aside>
  </div>;
}
