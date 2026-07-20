# CSIG Sales OS

> A quiet, editorial personal workspace for the journey from intern to Solution Sales professional and education industry expert.

## Online Experience

### [Open CSIG Sales OS →](https://rothy-s-sale-dashboard.vercel.app/design-system)

The current release is the **Design System V2.0 interactive gallery**. It demonstrates the shared visual foundation for every future page, including:

- Day, Night, and automatic time-based themes
- User wallpaper controls with opacity, blur, and brightness settings
- Editorial navigation, cards, timeline, progress, forms, empty states, and contextual panels
- Responsive desktop, tablet, and mobile layouts
- Reduced-motion and accessibility behavior

> All content in the gallery is fictional sample data. It contains no real customer, contact, meeting, opportunity, expense, or other sensitive business information.

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

Open `http://localhost:3000/design-system`.

## Quality Checks

```bash
cd web
pnpm verify
```

The verification flow covers linting, TypeScript, component tests, production build, responsive behavior, accessibility, theme persistence, and reduced motion.
