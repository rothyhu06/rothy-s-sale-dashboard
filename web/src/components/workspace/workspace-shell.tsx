"use client";

import { Navigation } from "@/components/design-system";
import { usePathname } from "next/navigation";

export function WorkspaceShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <>
      <Navigation
        groups={[
          { label: "Workspace", items: [{label:"Today",href:"/",active:pathname==="/"},{label:"Customers",href:"/customers",active:pathname.startsWith("/customers")},{label:"Contacts",href:"/contacts",active:pathname.startsWith("/contacts")},{label:"Opportunities",href:"/opportunities",active:pathname.startsWith("/opportunities")},{label:"Interactions",href:"/interactions",active:pathname.startsWith("/interactions")},{label:"Tasks",href:"/tasks",active:pathname.startsWith("/tasks")}] },
          { label: "Knowledge", items: [{ label: "Knowledge Hub", href: "/knowledge", active: pathname.startsWith("/knowledge") }, { label: "Learning", href: "/learning", active: pathname.startsWith("/learning") },{label:"Insights",href:"/insights",active:pathname.startsWith("/insights")}] },
          { label: "Review", items: [{label:"Reports",href:"/reports",active:pathname.startsWith("/reports")},{label:"Timeline",href:"/timeline",active:pathname.startsWith("/timeline")},{label:"Search",href:"/search",active:pathname.startsWith("/search")},{label:"Files & Tags",href:"/files",active:pathname.startsWith("/files")}] },
        ]}
        profile={{ name: "Private workspace", detail: "Your learning journal" }}
      />
      <main className="relative z-10 min-h-screen px-5 pb-24 pt-8 md:ml-[72px] md:px-8 md:pb-16 md:pt-12 lg:ml-[var(--layout-nav)] lg:px-12">
        <div className="mx-auto w-full max-w-[var(--layout-reading)]">{children}</div>
      </main>
    </>
  );
}
