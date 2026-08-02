"use client";

import { useState } from "react";
import {
  Badge,
  Button,
  Card,
  Checkbox,
  CommandDialog,
  ContextPanel,
  Divider,
  EmptyState,
  FloatingAiEntry,
  InputField,
  Navigation,
  Progress,
  SectionHeader,
  SelectInput,
  Skeleton,
  TextArea,
  TextInput,
  Timeline,
} from "@/components/design-system";
import { ThemeToggle } from "@/components/theme/theme-toggle";
import { WallpaperSettingsPanel } from "@/components/wallpaper/wallpaper-settings";

const navigation = [
  { label: "Workspace", items: [{ label: "Home", href: "#top", active: true }, { label: "Components", href: "#controls" }] },
  { label: "Knowledge", items: [{ label: "Foundations", href: "#foundations" }, { label: "Timeline", href: "#timeline" }] },
  { label: "Growth", items: [{ label: "Progress", href: "#progress" }, { label: "Reflection", href: "#empty" }] },
];

const colors = ["canvas", "paper", "ink", "muted", "border", "accent", "success", "highlight", "danger"];

export function DesignSystemGallery() {
  const [editorOpen, setEditorOpen] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);
  const [query, setQuery] = useState("");
  return (
    <div id="top">
      <Navigation groups={navigation} profile={{ name: "Yuxing", detail: "Personal workspace" }} />
      <main className="min-h-screen px-5 pb-28 pt-12 md:ml-[72px] md:px-10 lg:ml-[var(--layout-nav)] lg:px-12 xl:mr-[var(--layout-context)]">
        <div className="mx-auto max-w-[var(--layout-reading)]">
          <header className="mb-[var(--space-9)] border-b border-border pb-[var(--space-8)]">
            <div className="mb-4 flex flex-wrap items-center gap-3"><p className="type-label m-0 text-accent">Foundations · V2.0</p><Badge>Demo / Sample Data</Badge></div>
            <h1 className="type-display-xl">CSIG Sales OS — Design System</h1>
            <p className="type-body-lg mt-5 max-w-2xl text-muted">A quiet editorial foundation for a private Solution Sales workspace. Typography, action and reflection lead; interface decoration recedes.</p>
            <div className="mt-8"><ThemeToggle /></div>
          </header>

          <GallerySection id="foundations" title="Foundations" description="One semantic language across Day, Night and every future page.">
            <div className="grid grid-cols-3 gap-4 max-sm:grid-cols-2">
              {colors.map((color) => (
                <div className="border-b border-border pb-3" key={color}>
                  <div className="mb-3 h-14 border border-border" style={{ backgroundColor: `var(--ds-color-${color})` }} />
                  <span className="type-metadata text-muted">{color}</span>
                </div>
              ))}
            </div>
            <div className="mt-12 space-y-5 border-t border-border pt-8">
              <p className="type-display-xl">Display XL — private strategy notebook</p>
              <p className="type-heading-1">Heading 1 — customer understanding</p>
              <p className="type-heading-2">Heading 2 — thoughtful structure</p>
              <p className="type-body-lg max-w-2xl text-muted">Body Large carries reflective writing at a calm reading rhythm. It remains generous on mobile rather than collapsing into metadata.</p>
              <p className="type-label text-accent">Small uppercase label</p>
            </div>
          </GallerySection>

          <GallerySection id="cross-cutting-controls" title="Cross-cutting Controls" description="Shared selection, state, search and loading patterns for every business workflow.">
            <div className="grid grid-cols-2 gap-8 max-sm:grid-cols-1">
              <div className="space-y-5">
                <Checkbox description="A calm native control with visible focus and a full text label." label="Include archived sample entries" />
                <div className="flex flex-wrap gap-3"><Badge>Draft</Badge><Badge tone="accent">Verified</Badge><Badge tone="success">Available</Badge><Badge tone="danger">Needs review</Badge></div>
                <Button onClick={() => setCommandOpen(true)} variant="secondary">Open command dialog</Button>
              </div>
              <div aria-label="Sample loading structure" className="space-y-4" role="status">
                <Skeleton className="w-1/3" /><Skeleton /><Skeleton className="w-5/6" />
              </div>
            </div>
          </GallerySection>

          <GallerySection id="wallpaper" title="Atmosphere" description="Wallpaper remains an emotional layer, never business information.">
            <WallpaperSettingsPanel />
          </GallerySection>

          <GallerySection id="controls" title="Controls" description="Clear states, visible labels and one primary action per region.">
            <div className="flex flex-wrap items-center gap-3">
              <Button>Save note</Button><Button variant="secondary">Review</Button><Button variant="text">Open library</Button><Button variant="destructive">Remove</Button><Button loading>Saving</Button>
            </div>
            <div className="mt-10 grid grid-cols-2 gap-6 max-sm:grid-cols-1">
              <InputField description="Use a concise working title." id="gallery-title" label="Title"><TextInput placeholder="Customer discovery framework" /></InputField>
              <InputField id="gallery-stage" label="Sales stage"><SelectInput defaultValue="discovery"><option value="discovery">Discovery</option><option value="poc">POC</option></SelectInput></InputField>
              <div className="col-span-2 max-sm:col-span-1"><InputField id="gallery-note" label="Reflection"><TextArea placeholder="What changed in your understanding?" /></InputField></div>
            </div>
          </GallerySection>

          <GallerySection id="cards" title="Cards" description="Reserved for objects and actions that deserve opening or completing.">
            <div className="grid grid-cols-2 gap-5 max-sm:grid-cols-1">
              <Card onClick={() => undefined} variant="action"><p className="type-label m-0 text-accent">Customer</p><h3 className="type-heading-3 mt-3">Prepare university discovery questions</h3><p className="type-body-sm mb-0 mt-3 text-muted">Next: clarify the current teaching workflow before discussing products.</p></Card>
              <Card href="#timeline" variant="entity"><p className="type-label m-0 text-muted">Knowledge</p><h3 className="type-heading-3 mt-3">Tencent Cloud AI Agent notes</h3><p className="type-body-sm mb-0 mt-3 text-muted">A reusable knowledge entry for future customer conversations.</p></Card>
            </div>
          </GallerySection>

          <GallerySection id="timeline" title="Memory Timeline" description="A personal sales growth archive, composed from facts rather than a new activity entity.">
            <Timeline entries={[
              { id: "1", time: "09:00", type: "Learning", title: "Tencent Cloud AI Agent knowledge" },
              { id: "2", time: "11:00", type: "Interaction", title: "University information center discussion", context: "Identified teaching-content governance as the first discovery thread." },
              { id: "3", time: "16:00", type: "Feedback", title: "Improve business value expression" },
              { id: "4", time: "18:00", type: "Insight", title: "Created a customer discovery method" },
            ]} />
          </GallerySection>

          <GallerySection id="progress" title="Growth Progress" description="Capability feedback without game mechanics or experience points.">
            <div className="grid gap-6">
              <Progress label="Cloud Knowledge" level="Foundation · 64%" value={64} />
              <Progress label="AI Solution" level="Developing · 48%" value={48} />
              <Progress label="Customer Discovery" level="Practising · 36%" value={36} />
              <Progress label="Account Management" level="Not assessed" />
            </div>
          </GallerySection>

          <GallerySection id="empty" title="Empty States" description="Zero data is an invitation to begin, not an error.">
            <EmptyState action={<Button>Write the first note</Button>} description="Capture one useful discovery today. Your personal knowledge library will grow from real work." link={<Button variant="text">Learn how entries connect</Button>} title="A quiet library, for now" />
          </GallerySection>
        </div>
      </main>

      <aside className="fixed inset-y-0 right-0 hidden w-[var(--layout-context)] border-l border-border bg-canvas px-6 py-10 xl:block">
        <ContextPanel actions={["Review discovery questions", "Refine the value statement"]} capability="Customer Discovery" customer="Harbor University" editorNote="Strengthen the business-value framing before the next conversation." opportunity="AI Teaching Assistant" />
      </aside>

      {editorOpen ? (
        <div aria-label="Your Editor" className="fixed bottom-24 right-6 z-40 w-[min(380px,calc(100vw-3rem))]" role="dialog">
          <Card variant="empty"><SectionHeader action={<button className="type-control text-accent" onClick={() => setEditorOpen(false)} type="button">Close</button>} description="AI integrations remain outside this Design System foundation." title="Your Editor" /><p className="type-body-md mb-0 mt-6 text-muted">This surface verifies the quiet entry pattern without sending any data to an external model.</p></Card>
        </div>
      ) : <FloatingAiEntry onOpen={() => setEditorOpen(true)} />}
      <CommandDialog description="Search uses fictional entries on this public gallery." onOpenChange={setCommandOpen} onQueryChange={setQuery} open={commandOpen} query={query} title="Search sample workspace">
        <button aria-selected="false" className="type-body-md min-h-11 w-full border-b border-border px-3 text-left text-ink hover:text-accent" role="option" type="button">AI teaching assistant · Sample Knowledge</button>
      </CommandDialog>
    </div>
  );
}

function GallerySection({ children, description, id, title }: { children: React.ReactNode; description: string; id: string; title: string }) {
  return (
    <section className="mb-[var(--space-9)] scroll-mt-8" id={id}>
      <Divider className="mb-8" />
      <SectionHeader description={description} title={title} />
      <div className="mt-10">{children}</div>
    </section>
  );
}
