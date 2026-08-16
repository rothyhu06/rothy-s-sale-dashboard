# CSIG Sales OS

Private, single-user Solution Sales workspace for learning, customer management, opportunity execution, interactions, tasks, insight formation and daily reflection.

**Online experience:** [https://rothy-s-sale-dashboard.vercel.app](https://rothy-s-sale-dashboard.vercel.app)

**Public sample-only Design System:** [https://rothy-s-sale-dashboard.vercel.app/design-system](https://rothy-s-sale-dashboard.vercel.app/design-system)

## Requirements

- Node.js 20.9 or newer
- pnpm 11 or compatible
- Google Chrome for the local Playwright configuration

The font files are installed as local npm packages. Production builds do not contact Google Fonts, which keeps the application suitable for private networks and future Tencent Cloud or internal deployment.

## Commands

```bash
pnpm install
pnpm dev
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm test:e2e
pnpm verify
```

Open `http://localhost:3000`. Business routes require the single Supabase account. `/design-system` remains public and uses fictional sample data only.

## Implemented MVP

- Adaptive Sales Command Center
- Global Search and unified Memory Timeline
- Knowledge Hub and Learning chain
- Customer, Contact and Opportunity Pipeline
- Interaction facts and Task commitments
- Evidence-linked Insights
- Daily Report and derived Weekly Review
- Private Attachment upload/download and reusable Tags
- Supabase SSR Auth, forced RLS, owner-aware foreign keys, AuditLog, idempotent commands, optimistic concurrency and soft delete

Operations: [runbook](docs/operations/runbook.md) · [security checklist](docs/operations/security-checklist.md)

## Source of Truth

- Product specification: `../docs/superpowers/specs/2026-07-20-csig-sales-os-design-system-v2-design.md`
- Visual tokens: `src/app/globals.css`
- Public component API: `src/components/design-system/index.ts`
- Visual and responsive acceptance: `e2e/design-system.spec.ts`

Pages must import components from the public barrel only:

```tsx
import { Button, Card, SectionHeader, Timeline } from "@/components/design-system";
```

Pages must not import internal component files, duplicate raw colors, create new radii, add shadows or glass effects, or introduce page-specific motion.

## Theme Behavior

- `Auto` is the default preference.
- Day runs from 06:00 through 17:59 in the user’s local time.
- Night runs from 18:00 through 05:59.
- Manual Day or Night preference persists in localStorage.
- A pre-hydration script applies the resolved theme before paint.
- Theme changes preserve layout and respect Reduced Motion.

## Wallpaper Behavior

- JPEG, PNG, and WebP are accepted up to 8 MiB.
- Image bytes are stored in IndexedDB; settings are stored locally per theme.
- Invalid uploads preserve the current image.
- The image is isolated behind a theme overlay and never becomes business information.
- `WallpaperRepository` is the persistence boundary. A future Supabase Storage adapter can replace the browser repository without changing the UI.

## Component Governance

The frozen public surface includes Button, Card, Divider, Section Header, Input, Timeline, Progress, Empty State, Navigation, Today’s Context, and Floating AI Entry.

Before adding a component:

1. Demonstrate that the existing public components cannot express the real business need.
2. Define responsibility, usage boundary, all states, responsiveness, and accessibility.
3. Add a failing behavior test.
4. Implement with semantic tokens only.
5. Add the component to the internal gallery and public barrel.
6. Run `pnpm verify`.

The gallery uses fictional organizations and non-sensitive sample content. Never place real customer, contact, meeting, opportunity, expense, or Level 3 information in examples or tests.
