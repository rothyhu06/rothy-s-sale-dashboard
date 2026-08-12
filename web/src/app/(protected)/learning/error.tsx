"use client";
import { Button, EmptyState } from "@/components/design-system";
export default function LearningError({ reset }: { reset: () => void }) { return <EmptyState title="Learning could not be loaded" description="Your journal is unchanged. Try loading it again." action={<Button onClick={reset}>Try again</Button>} />; }
