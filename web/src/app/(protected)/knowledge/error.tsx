"use client";
import { Button, EmptyState } from "@/components/design-system";
export default function KnowledgeError({ reset }: { reset: () => void }) { return <EmptyState title="Knowledge could not be loaded" description="Your library is unchanged. Try loading it again." action={<Button onClick={reset}>Try again</Button>} />; }
