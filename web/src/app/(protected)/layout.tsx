import { requireUser } from "@/lib/auth/require-user";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  await requireUser();

  return children;
}
