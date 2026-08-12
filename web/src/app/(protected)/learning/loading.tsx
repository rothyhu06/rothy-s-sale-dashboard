import { Skeleton } from "@/components/design-system";
export default function LearningLoading() { return <div aria-label="Loading Learning" className="grid gap-8" role="status"><Skeleton className="h-10 w-2/3" /><div className="grid gap-4 sm:grid-cols-2"><Skeleton className="h-48" /><Skeleton className="h-48" /></div></div>; }
