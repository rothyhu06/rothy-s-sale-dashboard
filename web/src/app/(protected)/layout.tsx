import { requireUser } from "@/lib/auth/require-user";
import { WorkspaceShell } from "@/components/workspace/workspace-shell";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  await requireUser();

  return <WorkspaceShell>{children}</WorkspaceShell>;
}
