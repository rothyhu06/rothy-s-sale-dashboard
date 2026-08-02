"use server";

import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth/require-user";
import { createServerClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = formData.get("email");
  const password = formData.get("password");

  if (typeof email !== "string" || typeof password !== "string" || !email || !password) {
    redirect("/login?error=missing_credentials");
  }

  const supabase = await createServerClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    redirect("/login?error=invalid_credentials");
  }

  redirect("/");
}

export async function signOut() {
  const supabase = await createServerClient();
  await requireUser(supabase);
  await supabase.auth.signOut();
  redirect("/login");
}
