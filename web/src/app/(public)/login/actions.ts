"use server";

import { redirect } from "next/navigation";
import { signInWithAudit, signOutWithAudit } from "@/lib/auth/session-audit";
import { createServerClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = formData.get("email");
  const password = formData.get("password");

  if (typeof email !== "string" || typeof password !== "string" || !email || !password) {
    redirect("/login?error=missing_credentials");
  }

  const supabase = await createServerClient();
  const result = await signInWithAudit(
    { email, password },
    { auth: supabase.auth },
  );

  if (!result.ok) {
    redirect("/login?error=invalid_credentials");
  }

  redirect("/");
}

export async function signOut() {
  const supabase = await createServerClient();
  await signOutWithAudit({ auth: supabase.auth });
  redirect("/login");
}
