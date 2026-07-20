import Link from "next/link";
import { Divider } from "./divider";

export type NavigationItem = { label: string; href: string; active?: boolean };
export type NavigationGroup = { label: string; items: NavigationItem[] };
export type NavigationProfile = { name: string; detail: string };

export function Navigation({ groups, profile }: { groups: NavigationGroup[]; profile: NavigationProfile }) {
  const links = groups.flatMap((group) => group.items);
  return (
    <>
      <nav aria-label="Studio index" className="fixed inset-y-0 left-0 z-20 hidden w-[72px] flex-col border-r border-border bg-canvas px-4 py-8 md:flex lg:w-[var(--layout-nav)] lg:px-6">
        <Link className="mb-12 block" href="/">
          <span className="type-label block text-muted">CSIG</span>
          <span className="type-heading-3 hidden lg:block">Sales OS</span>
        </Link>
        <div className="flex-1 space-y-8">
          {groups.map((group) => (
            <section key={group.label}>
              <h2 className="type-label mb-3 hidden text-muted lg:block">{group.label}</h2>
              <ul className="m-0 list-none space-y-1 p-0">
                {group.items.map((item) => (
                  <li key={item.href}>
                    <Link aria-current={item.active ? "page" : undefined} className="type-body-sm group flex min-h-11 items-center gap-3 text-muted hover:text-ink aria-[current=page]:text-ink" href={item.href}>
                      <span aria-hidden className="h-1 w-1 shrink-0 rounded-full bg-transparent group-aria-[current=page]:bg-accent" />
                      <span className="hidden lg:inline">{item.label}</span>
                      <span className="sr-only lg:hidden">{item.label}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
        <Divider className="mb-5" />
        <div className="hidden lg:block">
          <p className="type-body-sm m-0 text-ink">{profile.name}</p>
          <p className="type-metadata m-0 text-muted">{profile.detail}</p>
        </div>
      </nav>
      <nav aria-label="Mobile navigation" className="fixed inset-x-0 bottom-0 z-30 flex min-h-16 items-center justify-around border-t border-border bg-paper px-2 md:hidden">
        {links.slice(0, 5).map((item) => <Link aria-current={item.active ? "page" : undefined} className="type-metadata min-h-11 px-2 py-3 text-muted aria-[current=page]:text-ink" href={item.href} key={item.href}>{item.label}</Link>)}
      </nav>
    </>
  );
}
