import { execFileSync } from "node:child_process";
import { requireLocalSupabaseUrl } from "./support/local-supabase";

export default function resetLocalE2eDatabase() {
  requireLocalSupabaseUrl(process.env.NEXT_PUBLIC_SUPABASE_URL);
  execFileSync("pnpm", ["db:reset"], { cwd: process.cwd(), stdio: "pipe" });
}
