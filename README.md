# CSIG Sales OS

> A quiet, editorial personal workspace for the journey from intern to Solution Sales professional and education industry expert.

## Online Experience

### [Open CSIG Sales OS →](https://rothy-s-sale-dashboard.vercel.app)

[Public Design System sample gallery →](https://rothy-s-sale-dashboard.vercel.app/design-system)

The current release is a private single-user MVP. It includes:

- Adaptive Sales Command Center, Global Search and Memory Timeline
- Knowledge Hub, Learning chain and evidence-linked Insights
- Customer, Contact, Opportunity, Interaction and Task workflows
- Daily Report, Weekly Review, private Attachments and Tags
- Supabase SSR Auth, forced RLS, owner isolation, AuditLog and idempotent commands
- Day/Night themes, responsive layouts and the shared Design System V2.0

> `/design-system` is public and contains fictional sample data only. Every business route requires the pre-created private account.

## Product Direction

CSIG Sales OS is a personal Education Solution Sales operating system rather than a traditional CRM dashboard. Its long-term scope combines:

- Sales Knowledge Hub
- Lightweight CRM and opportunity management
- Account planning and discovery workflows
- AI Sales Assistant with data-level security controls
- Learning, feedback, insight, and reporting loops

## Repository Structure

- `web/` — Next.js application and reusable component library
- `docs/superpowers/specs/` — approved product and design specifications
- `docs/superpowers/plans/` — implementation plans

## Local Development

```bash
cd web
pnpm install
pnpm dev
```

Open `http://localhost:3000`. Configure the Supabase variables from `web/.env.example` first.

## Quality Checks

```bash
cd web
pnpm verify
```

The verification flow covers linting, TypeScript, component tests, production build, responsive behavior, accessibility, theme persistence, and reduced motion.
