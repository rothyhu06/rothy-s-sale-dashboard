import { Button } from "@/components/design-system/button";
import { signOut } from "@/app/(public)/login/actions";

export default function Home() {
  return (
    <main className="relative z-10 flex min-h-screen items-center justify-center px-6 py-12">
      <section className="radius-card w-full max-w-2xl border border-border bg-paper p-8 shadow-xl">
        <p className="type-label text-accent">私人工作台</p>
        <h1 className="type-heading-1 mt-2 text-ink">CSIG Sales OS</h1>
        <p className="type-body-md mt-3 text-muted">安全会话已建立，业务工作流将在后续切片中接入。</p>
        <form action={signOut} className="mt-8">
          <Button type="submit" variant="secondary">退出登录</Button>
        </form>
      </section>
    </main>
  );
}
