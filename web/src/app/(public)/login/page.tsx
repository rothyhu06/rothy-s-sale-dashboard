import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Button } from "@/components/design-system/button";
import { InputField, TextInput } from "@/components/design-system/input";
import { createServerClient } from "@/lib/supabase/server";
import { signIn } from "./actions";
import { LoginFeedback } from "./login-feedback";

export const metadata: Metadata = {
  title: "登录 | CSIG Sales OS",
  robots: { index: false, follow: false },
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  const supabase = await createServerClient();
  const { data } = await supabase.auth.getClaims();

  if (data?.claims) {
    redirect("/");
  }

  const { error } = await searchParams;

  return (
    <main className="relative z-10 flex min-h-screen items-center justify-center px-6 py-12">
      <section className="radius-card w-full max-w-sm border border-border bg-paper p-8 shadow-xl">
        <p className="type-label text-accent">CSIG Sales OS</p>
        <h1 className="type-heading-1 mt-2 text-ink">登录</h1>
        <p className="type-body-md mt-2 text-muted">进入你的私人销售工作台。</p>
        <LoginFeedback error={error} />

        <form action={signIn} className="mt-8 space-y-5">
          <InputField id="email" label="邮箱" required>
            <TextInput name="email" type="email" autoComplete="email" required />
          </InputField>
          <InputField id="password" label="密码" required>
            <TextInput name="password" type="password" autoComplete="current-password" required />
          </InputField>
          <Button type="submit" className="w-full">登录</Button>
        </form>
      </section>
    </main>
  );
}
