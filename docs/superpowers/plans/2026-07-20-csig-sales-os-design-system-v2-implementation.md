# CSIG Sales OS Design System V2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Use `test-driven-development` for every component and `verification-before-completion` before claiming success.

**Goal:** Build the reusable, production-ready Design System foundation for CSIG Sales OS, including Day/Night themes, wallpaper controls, shared responsive primitives, the frozen component library, and an internal visual acceptance page—without implementing Dashboard or business pages.

**Architecture:** Create a standalone Next.js App Router application in `web/`. CSS custom properties are the single source of truth for visual tokens; React components consume semantic classes only. Theme and wallpaper are browser-side services behind small repository interfaces, so a later Supabase-backed implementation can replace persistence without changing components. Tests are split into token/logic tests, component behavior tests, and Playwright visual/accessibility acceptance tests.

**Tech Stack:** Next.js App Router, TypeScript, React, Tailwind CSS, Radix primitives through shadcn CLI where behavior warrants it, Vitest, Testing Library, Playwright, `@axe-core/playwright`, ESLint.

## Global Constraints

- The approved specification at `docs/superpowers/specs/2026-07-20-csig-sales-os-design-system-v2-design.md` is authoritative.
- Do not modify the frozen database model or introduce Supabase tables.
- Do not implement Dashboard, CRM, Knowledge, Account Plan, Report, or AI business flows.
- Do not introduce page-specific colors, spacing, radii, shadows, gradients, or motion values.
- Do not use default shadcn visual styles. Radix/shadcn may supply accessible behavior; CSIG tokens supply all appearance.
- Do not create Metric Card, Glass Card, badge walls, neon effects, glassmorphism, or generic SaaS patterns.
- Every public component must support Day, Night, keyboard navigation, reduced motion, and its documented responsive behavior.
- CSS custom properties in `web/src/app/globals.css` are the visual source of truth. TypeScript exports may describe valid names and variants but must not duplicate raw color values.
- All user-visible component copy in the gallery must use the frozen personal-workspace language system.
- Use `pnpm` consistently and commit `web/pnpm-lock.yaml`.

## Planned File Topology

```text
web/
├── e2e/
│   └── design-system.spec.ts
├── public/
│   └── textures/paper-noise.svg
├── src/
│   ├── app/
│   │   ├── design-system/page.tsx
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   ├── components/
│   │   ├── design-system/
│   │   │   ├── button.tsx
│   │   │   ├── card.tsx
│   │   │   ├── context-panel.tsx
│   │   │   ├── divider.tsx
│   │   │   ├── empty-state.tsx
│   │   │   ├── floating-ai-entry.tsx
│   │   │   ├── index.ts
│   │   │   ├── input.tsx
│   │   │   ├── navigation.tsx
│   │   │   ├── progress.tsx
│   │   │   ├── section-header.tsx
│   │   │   └── timeline.tsx
│   │   ├── gallery/design-system-gallery.tsx
│   │   ├── theme/theme-provider.tsx
│   │   ├── theme/theme-script.tsx
│   │   ├── theme/theme-toggle.tsx
│   │   ├── ui/dialog.tsx
│   │   └── wallpaper/
│   │       ├── wallpaper-layer.tsx
│   │       └── wallpaper-settings.tsx
│   ├── lib/
│   │   ├── cn.ts
│   │   ├── theme/resolve-theme.ts
│   │   └── wallpaper/
│   │       ├── indexed-db-repository.ts
│   │       ├── repository.ts
│   │       └── validation.ts
│   └── tests/
│       ├── components/
│       ├── setup.ts
│       ├── theme/
│       ├── tokens/
│       └── wallpaper/
├── components.json
├── playwright.config.ts
├── vitest.config.ts
└── package.json
```

---

## Task 1: Scaffold the isolated web application and test harness

**Files:**

- Create: `web/` via the official Next.js scaffold
- Modify: `web/package.json`
- Create: `web/vitest.config.ts`
- Create: `web/src/tests/setup.ts`
- Create: `web/playwright.config.ts`
- Modify: `web/tsconfig.json`
- Modify: `web/src/app/page.tsx`

### Steps

- [ ] Verify prerequisites before writing files:

```bash
node --version
pnpm --version
```

Expected: Node.js is `v20.9.0` or newer and `pnpm` exits successfully. Stop and install a supported runtime if not.

- [ ] Scaffold into `web/`, keeping product documents outside the app:

```bash
pnpm create next-app@latest web --ts --tailwind --eslint --app --src-dir --import-alias '@/*' --use-pnpm
```

Choose no optional React Compiler unless the generated stable default enables it. Do not accept a `web/web` nested path.

- [ ] Add the behavior and verification dependencies:

```bash
cd web
pnpm add clsx tailwind-merge
pnpm add -D vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event @vitejs/plugin-react @playwright/test @axe-core/playwright
pnpm exec playwright install chromium
pnpm dlx shadcn@latest init -b radix -d
```

The shadcn initialization establishes the project registry and accessible primitive convention. Its generated theme styles are temporary: Task 2 replaces them with the frozen CSIG semantic tokens before any public component is built.

- [ ] Add scripts to `web/package.json`:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test",
    "verify": "pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e"
  }
}
```

- [ ] Configure Vitest for `jsdom`, React, the `@/*` alias, and `src/tests/setup.ts`. The setup file must import `@testing-library/jest-dom/vitest` and run `cleanup()` after each test.

- [ ] Configure Playwright with `baseURL: http://127.0.0.1:3000`, Chromium desktop by default, and a `webServer` command of `pnpm dev`. Reuse an existing server outside CI.

- [ ] Make `web/src/app/page.tsx` redirect to `/design-system`; the root is only an internal entry until a real Home page is planned.

- [ ] Run the empty harness:

```bash
pnpm lint
pnpm typecheck
pnpm test --passWithNoTests
pnpm build
```

Expected: all commands exit 0, and the build lists `/` as a valid route.

- [ ] Commit:

```bash
git add web
git commit -m "chore: scaffold CSIG Sales OS web foundation"
```

---

## Task 2: Implement token foundations, fonts, reset, and paper surface

**Files:**

- Modify: `web/src/app/globals.css`
- Modify: `web/src/app/layout.tsx`
- Create: `web/public/textures/paper-noise.svg`
- Create: `web/src/tests/tokens/design-tokens.test.ts`
- Create: `web/src/lib/cn.ts`

### Steps

- [ ] Write `design-tokens.test.ts` first. Read `globals.css` as text and assert that both Day and Night scopes define every semantic color token, and that the shared scope defines all spacing, radius, divider, layout, typography, and motion tokens. The required token lists are:

```ts
const colors = [
  "--ds-color-canvas", "--ds-color-paper", "--ds-color-ink", "--ds-color-muted",
  "--ds-color-border", "--ds-color-accent", "--ds-color-success",
  "--ds-color-highlight", "--ds-color-danger",
];
const spaces = Array.from({ length: 10 }, (_, index) => `--space-${index + 1}`);
const radii = ["--radius-none", "--radius-control", "--radius-floating", "--radius-card", "--radius-full"];
const motions = ["--motion-fast", "--motion-base", "--motion-theme", "--motion-reveal", "--motion-distance", "--motion-easing"];
```

Also assert that `box-shadow:` and `backdrop-filter:` do not appear in the global component layer.

- [ ] Run the test and confirm it fails because the tokens do not yet exist:

```bash
pnpm test src/tests/tokens/design-tokens.test.ts
```

Expected: FAIL with missing `--ds-color-canvas` or equivalent token assertion.

- [ ] Implement `globals.css` with these exact semantic values:

```css
:root,
:root[data-theme="day"] {
  --ds-color-canvas: #f7f4ee;
  --ds-color-paper: #fbfaf7;
  --ds-color-ink: #2d2d2d;
  --ds-color-muted: #727272;
  --ds-color-border: #ddd8cf;
  --ds-color-accent: #7b93a7;
  --ds-color-success: #7d9580;
  --ds-color-highlight: #b3945b;
  --ds-color-danger: #a46f68;
}

:root[data-theme="night"] {
  --ds-color-canvas: #1e2230;
  --ds-color-paper: #242938;
  --ds-color-ink: #f1eee8;
  --ds-color-muted: #aeb1bc;
  --ds-color-border: #3a4152;
  --ds-color-accent: #9a92c7;
  --ds-color-success: #819c8a;
  --ds-color-highlight: #d0b16f;
  --ds-color-danger: #c58a82;
}
```

Add the frozen spacing values `4, 8, 12, 16, 24, 32, 48, 64, 80, 120px`; radii `0, 8, 12, 18, 999px`; layout sizes `224, 968, 872, 248px`; typography values; divider width `1px`; and motion values `160, 220, 350, 500ms`, `12px`, and `cubic-bezier(0.22,1,0.36,1)`.

- [ ] Add Tailwind theme aliases that point to CSS variables. Component code must use names such as `bg-canvas`, `bg-paper`, `text-ink`, `text-muted`, and `border-border`; raw palette utilities are forbidden in `src/components`.

```css
@theme inline {
  --color-canvas: var(--ds-color-canvas);
  --color-paper: var(--ds-color-paper);
  --color-ink: var(--ds-color-ink);
  --color-muted: var(--ds-color-muted);
  --color-border: var(--ds-color-border);
  --color-accent: var(--ds-color-accent);
  --color-success: var(--ds-color-success);
  --color-highlight: var(--ds-color-highlight);
  --color-danger: var(--ds-color-danger);
}
```

The `--ds-color-*` variables hold the only raw values; Tailwind's `--color-*` namespace is an alias layer that produces semantic utilities without duplicating hex values.

- [ ] Configure `Source_Serif_4`, `Noto_Serif_SC`, and `Inter` with `next/font/google` in `layout.tsx`. Expose font variables and use system `PingFang SC` before generic sans for Chinese UI fallback.

- [ ] Create a deterministic local `paper-noise.svg` containing a very low-contrast SVG turbulence texture. Apply it as a separate fixed pseudo-layer with opacity `0.02`; it must have `pointer-events: none` and must not alter content opacity.

- [ ] Add global focus-visible, selection, reduced-motion, and body rules. Under `prefers-reduced-motion: reduce`, set transition duration to near-zero and remove transforms, but retain visible focus.

- [ ] Implement `cn(...inputs)` using `clsx` and `tailwind-merge`.

- [ ] Rerun tests and static checks:

```bash
pnpm test src/tests/tokens/design-tokens.test.ts
pnpm lint
pnpm typecheck
```

Expected: all pass.

- [ ] Commit:

```bash
git add web/src/app web/src/lib web/src/tests/tokens web/public/textures
git commit -m "feat: add editorial design tokens and typography"
```

---

## Task 3: Build flash-free Auto/Day/Night theme behavior

**Files:**

- Create: `web/src/lib/theme/resolve-theme.ts`
- Create: `web/src/components/theme/theme-script.tsx`
- Create: `web/src/components/theme/theme-provider.tsx`
- Create: `web/src/components/theme/theme-toggle.tsx`
- Create: `web/src/tests/theme/resolve-theme.test.ts`
- Create: `web/src/tests/theme/theme-provider.test.tsx`
- Modify: `web/src/app/layout.tsx`

### Steps

- [ ] Write resolver tests first for this public contract:

```ts
export type ThemePreference = "auto" | "day" | "night";
export type ResolvedTheme = "day" | "night";
export function resolveTheme(preference: ThemePreference, localHour: number): ResolvedTheme;
export function millisecondsUntilThemeBoundary(now: Date): number;
```

Required cases: Auto at 05:59 → Night, 06:00 → Day, 17:59 → Day, 18:00 → Night; explicit Day/Night ignore the hour; invalid hours throw; the next boundary is always positive and no more than 12 hours away.

- [ ] Run and confirm failure:

```bash
pnpm test src/tests/theme/resolve-theme.test.ts
```

- [ ] Implement the pure resolver and boundary calculation without reading `window` or `Date.now()` internally.

- [ ] Write provider tests before the provider. Required behavior:

  - Missing `localStorage["csig-theme-preference"]` defaults to `auto`.
  - Manual selection writes only `auto`, `day`, or `night`.
  - Provider updates `document.documentElement.dataset.theme`.
  - Auto responds to a fake clock crossing 06:00 or 18:00.
  - A `storage` event from another tab updates the current tab.
  - Toggle buttons expose `aria-pressed` and an accessible group label.

- [ ] Implement `ThemeScript` as a minimal inline pre-hydration script in `<head>`. It must read the preference, derive the local hour, and set `data-theme` before paint. Do not interpolate user-controlled content into the script.

- [ ] Implement `ThemeProvider` with React context exposing:

```ts
type ThemeContextValue = {
  preference: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setPreference: (preference: ThemePreference) => void;
};
```

Use a timeout scheduled to the next 06:00/18:00 boundary only in Auto mode; clear it on unmount or preference change.

- [ ] Implement `ThemeToggle` as a compact three-option control labelled `Theme`, with Auto, Day, and Night. Use text labels, not unexplained sun/moon icons.

- [ ] Mount `ThemeScript` and `ThemeProvider` in `layout.tsx`; add `suppressHydrationWarning` only to `<html>` because the pre-hydration attribute intentionally differs.

- [ ] Verify:

```bash
pnpm test src/tests/theme
pnpm lint
pnpm typecheck
```

Expected: all theme boundary, persistence, and accessibility tests pass.

- [ ] Commit:

```bash
git add web/src/lib/theme web/src/components/theme web/src/tests/theme web/src/app/layout.tsx
git commit -m "feat: add automatic day and night themes"
```

---

## Task 4: Build the wallpaper atmosphere layer and browser persistence

**Files:**

- Create: `web/src/lib/wallpaper/repository.ts`
- Create: `web/src/lib/wallpaper/indexed-db-repository.ts`
- Create: `web/src/lib/wallpaper/validation.ts`
- Create: `web/src/components/wallpaper/wallpaper-layer.tsx`
- Create: `web/src/components/wallpaper/wallpaper-settings.tsx`
- Create: `web/src/tests/wallpaper/validation.test.ts`
- Create: `web/src/tests/wallpaper/wallpaper-settings.test.tsx`
- Modify: `web/src/app/layout.tsx`

### Steps

- [ ] Define the storage boundary before the implementation:

```ts
export type WallpaperSettings = {
  opacity: number;
  blurPx: number;
  brightnessPercent: number;
};

export interface WallpaperRepository {
  getImage(): Promise<Blob | null>;
  setImage(image: Blob): Promise<void>;
  removeImage(): Promise<void>;
  getSettings(theme: "day" | "night"): WallpaperSettings;
  setSettings(theme: "day" | "night", value: WallpaperSettings): void;
}
```

The future Supabase adapter must be able to implement this interface without changing UI component props.

- [ ] Write validation tests first. Accept JPEG, PNG, and WebP up to 8 MiB. Reject all other MIME types, zero-byte files, and larger files with a stable user-facing message. Clamp opacity to `0–0.25`, blur to `0–30`, Day brightness to `0.95–1.10`, and Night brightness to `0.55–0.80`.

- [ ] Run and confirm failure, then implement pure validation and clamping functions:

```bash
pnpm test src/tests/wallpaper/validation.test.ts
```

- [ ] Implement `IndexedDbWallpaperRepository` with one database `csig-sales-os`, object store `preferences`, image key `wallpaper-image`, and per-theme settings keys. IndexedDB stores the Blob; localStorage is not used for image bytes. If IndexedDB is unavailable, return an actionable error while retaining the current wallpaper.

- [ ] Write settings component tests first using an in-memory fake repository. Cover upload, replacement, removal, invalid file preservation, restoring defaults, slider labels/values, and object URL revocation.

- [ ] Implement `WallpaperLayer` as three fixed layers:

  1. Image layer with `background-image`, object-position center, and no pointer events.
  2. Theme overlay using a solid `color.canvas` surface at the frozen Day/Night opacity; do not add decorative gradients.
  3. Content remains in normal app stacking context.

Do not expose Blob URLs outside this component, and revoke every superseded URL.

- [ ] Implement `WallpaperSettings` with visible labels: Upload/Replace, Remove, Visibility, Blur, Brightness, Restore Defaults. Announce success/errors with an `aria-live="polite"` region. Removing the image must immediately return to the theme canvas.

- [ ] Mount `WallpaperLayer` below application content in `layout.tsx`; do not mount the settings UI globally. It will appear in the design-system gallery and later in a real Settings surface.

- [ ] Verify:

```bash
pnpm test src/tests/wallpaper
pnpm lint
pnpm typecheck
```

Expected: tests pass; invalid uploads leave the previous image untouched.

- [ ] Commit:

```bash
git add web/src/lib/wallpaper web/src/components/wallpaper web/src/tests/wallpaper web/src/app/layout.tsx
git commit -m "feat: add restrained wallpaper atmosphere system"
```

---

## Task 5: Implement Button, Input, Divider, and Section Header primitives

**Files:**

- Create: `web/src/components/design-system/button.tsx`
- Create: `web/src/components/design-system/input.tsx`
- Create: `web/src/components/design-system/divider.tsx`
- Create: `web/src/components/design-system/section-header.tsx`
- Create: `web/src/tests/components/button.test.tsx`
- Create: `web/src/tests/components/input.test.tsx`
- Create: `web/src/tests/components/section-header.test.tsx`
- Create: `web/src/tests/components/source-policy.test.ts`

### Steps

- [ ] Write Button tests first for `primary | secondary | text | destructive`, `standard | large`, native button props, forwarded ref, disabled, and loading. Loading must set `aria-busy`, preserve the original accessible name, disable activation, and not change width.

- [ ] Implement Button with a closed variant map. Primary uses Ink fill; Secondary uses Paper and Border; Text has no container; Destructive uses the semantic danger token. Do not accept arbitrary color or radius props.

- [ ] Write Input tests for Text, Search, Textarea, Select, Date, and File wrappers. Labels are mandatory, error text is linked with `aria-describedby`, and error state sets `aria-invalid`.

- [ ] Implement an `InputField` API that composes native controls rather than replacing their behavior:

```ts
type InputFieldProps = {
  id: string;
  label: string;
  description?: string;
  error?: string;
  required?: boolean;
  children: React.ReactElement;
};
```

Export styled `TextInput`, `TextArea`, and `SelectInput` controls. Keep the label visible even when a placeholder exists.

- [ ] Write Divider and Section Header tests. Divider variants are `section | row | vertical | empty`; only `empty` is dashed. Section Header renders serif title, optional description, metadata, and one text action—not a button group.

- [ ] Implement both using semantic elements (`hr`, `header`) and tokens only.

- [ ] Add a source-policy test that scans `src/components/design-system` and fails on raw hex values, `shadow-`, `backdrop-`, or arbitrary Tailwind radii such as `rounded-[`.

- [ ] Verify:

```bash
pnpm test src/tests/components/button.test.tsx src/tests/components/input.test.tsx src/tests/components/section-header.test.tsx
pnpm lint
pnpm typecheck
```

- [ ] Commit:

```bash
git add web/src/components/design-system web/src/tests/components
git commit -m "feat: add core editorial controls"
```

---

## Task 6: Implement Card, Timeline, Progress, and Empty State

**Files:**

- Create: `web/src/components/design-system/card.tsx`
- Create: `web/src/components/design-system/timeline.tsx`
- Create: `web/src/components/design-system/progress.tsx`
- Create: `web/src/components/design-system/empty-state.tsx`
- Create: `web/src/tests/components/card.test.tsx`
- Create: `web/src/tests/components/timeline.test.tsx`
- Create: `web/src/tests/components/progress.test.tsx`
- Create: `web/src/tests/components/empty-state.test.tsx`

### Steps

- [ ] Write Card tests first for the only allowed variants: `action | entity | empty`. Interactive cards must be anchors or buttons, not clickable `div` elements. Static Empty State Card must not receive an interactive role.

- [ ] Implement Card with Paper, 1px Border, 18px radius, 16/24px padding, no shadow, and a 1px hover lift only when interactive. Do not export a generic `variant: string` escape hatch.

- [ ] Write Timeline tests against this model:

```ts
export type TimelineEntry = {
  id: string;
  time: string;
  type: string;
  title: string;
  context?: string;
  href?: string;
};
```

Assert ordered-list semantics, linked source when `href` exists, and no Card classes. At mobile width, CSS may stack time above content without altering DOM order.

- [ ] Implement Timeline as rows separated by inset dividers. Accent applies only to event type. Time and context use Metadata/Muted tokens.

- [ ] Write Progress tests requiring an accessible name, numeric `value` from 0–100, and visible level/status text. Out-of-range values are clamped. Unknown progress uses a text-only status and no looping animation.

- [ ] Implement a 2px linear track using `role="progressbar"`; never add rings, segments, or experience points.

- [ ] Write and implement Empty State with serif title, one explanation, one recommended action, and optional text link. It may use only the dashed Empty divider or the shared Empty Card.

- [ ] Verify:

```bash
pnpm test src/tests/components/card.test.tsx src/tests/components/timeline.test.tsx src/tests/components/progress.test.tsx src/tests/components/empty-state.test.tsx
pnpm lint
pnpm typecheck
```

- [ ] Commit:

```bash
git add web/src/components/design-system web/src/tests/components
git commit -m "feat: add editorial content components"
```

---

## Task 7: Implement responsive studio navigation, context panel, and AI entry

**Files:**

- Create: `web/src/components/design-system/navigation.tsx`
- Create: `web/src/components/design-system/context-panel.tsx`
- Create: `web/src/components/design-system/floating-ai-entry.tsx`
- Create: `web/src/tests/components/navigation.test.tsx`
- Create: `web/src/tests/components/context-panel.test.tsx`
- Create: `web/src/tests/components/floating-ai-entry.test.tsx`

### Steps

- [ ] Write Navigation tests first. Define typed navigation groups and items; render section labels, links, active state via `aria-current="page"`, a 4px accent dot, and profile separated by a Divider. Navigation must not require icons.

- [ ] Implement these responsive modes from one data source:

  - Desktop: 224px left studio index.
  - Tablet: 72px compact trigger rail plus accessible Drawer trigger.
  - Mobile: fixed bottom navigation with a maximum of five primary destinations and a More trigger.

The hidden variants must not remain keyboard-focusable.

- [ ] Write Context Panel tests. It must be a complementary region labelled `Today’s Context`, support Current Customer, Current Opportunity, Current Capability, Editor’s Note, and Suggested Actions, and contain no chat input or conversation log.

- [ ] Implement desktop as a 248px right rail with a vertical divider. Tablet and Mobile expose the same content through a dialog/sheet primitive with focus trapping and Escape-to-close. Add the Radix-backed Dialog through the already initialized shadcn registry:

```bash
pnpm dlx shadcn@latest add dialog
```

Immediately restyle generated code to semantic tokens; do not import default color/radius choices into public components.

- [ ] Write Floating AI Entry tests for accessible label `Ask Your Editor`, click callback, desktop/mobile safe-area positioning, no pulse/red-dot animation, and minimum 44px touch target.

- [ ] Implement it as an action that opens a supplied callback or controlled sheet. Do not implement AI chat, API calls, or Level 3 data access in this task.

- [ ] Verify:

```bash
pnpm test src/tests/components/navigation.test.tsx src/tests/components/context-panel.test.tsx src/tests/components/floating-ai-entry.test.tsx
pnpm lint
pnpm typecheck
```

- [ ] Commit:

```bash
git add web/components.json web/src/components/design-system web/src/tests/components
git commit -m "feat: add responsive studio navigation and context"
```

---

## Task 8: Create the single public barrel and enforce Design System governance

**Files:**

- Create: `web/src/components/design-system/index.ts`
- Create: `web/src/tests/components/public-api.test.ts`
- Modify: `web/eslint.config.mjs`

### Steps

- [ ] Write a public API test first that imports every frozen component from `@/components/design-system`:

```ts
import {
  Button, Card, ContextPanel, Divider, EmptyState, FloatingAiEntry,
  InputField, Navigation, Progress, SectionHeader, TextArea, TextInput,
  Timeline,
} from "@/components/design-system";
```

The test should fail until the barrel exports exactly the supported surface.

- [ ] Export component prop types needed by consumers, while keeping internal styling helpers private.

- [ ] Add lint restrictions for files outside `src/components/design-system`:

  - Page code must not import internal component files; it imports only the barrel.
  - Page and gallery files may not contain raw hex colors.
  - Ban inline `boxShadow`, `backdropFilter`, and arbitrary radius values.

If ESLint cannot express a source-text rule safely, retain it as a Vitest source-policy test rather than adding a fragile custom plugin.

- [ ] Add `data-ds-component` attributes only where useful for acceptance testing; do not use them as styling hooks.

- [ ] Verify:

```bash
pnpm test src/tests/components/public-api.test.ts src/tests/tokens/design-tokens.test.ts
pnpm lint
pnpm typecheck
```

- [ ] Commit:

```bash
git add web/src/components/design-system/index.ts web/src/tests web/eslint.config.mjs
git commit -m "chore: enforce design system governance"
```

---

## Task 9: Build the internal Design System acceptance gallery

**Files:**

- Create: `web/src/components/gallery/design-system-gallery.tsx`
- Create: `web/src/app/design-system/page.tsx`
- Modify: `web/src/app/page.tsx`
- Create: `web/e2e/design-system.spec.ts`

### Steps

- [ ] Write Playwright acceptance tests first. Required scenarios:

  1. `/design-system` loads with heading `CSIG Sales OS — Design System`.
  2. Manual Day and Night selections update `data-theme` and survive reload.
  3. Auto mode resolves correctly under emulated local times where supported; pure resolver tests remain the authoritative boundary test.
  4. Every public component and every documented state appears in the gallery.
  5. Keyboard Tab reaches theme controls, component actions, Context trigger, and AI entry in semantic order.
  6. `@axe-core/playwright` reports no serious or critical accessibility violations.
  7. `prefers-reduced-motion: reduce` results in no transformed reveal state.
  8. Screenshots are captured at 1440×1024, 834×1112, and 390×844 for both themes.
  9. Desktop has three structural columns; Tablet hides the right rail; Mobile uses bottom navigation and keeps the AI entry above it.

- [ ] Run the new suite and confirm it fails because the page does not exist:

```bash
pnpm test:e2e e2e/design-system.spec.ts
```

- [ ] Implement the gallery as a documentation/QA page, not a fake Dashboard. Sections, in this order:

  1. Foundations: palette, typography, spacing, radii, dividers.
  2. Theme and wallpaper controls.
  3. Buttons and form controls in every state.
  4. Action/Entity/Empty cards.
  5. Memory Timeline.
  6. Growth Progress.
  7. Navigation variants.
  8. Today’s Context and Editor’s Note.
  9. Empty, loading, error, disabled, and reduced-motion examples.

Use only the public component barrel. The gallery may display token swatches, but their styles must reference CSS variables rather than duplicate hex values.

- [ ] Use realistic but non-sensitive sample copy, such as:

  - `Prepare discovery questions for the university information center`
  - `Review Tencent Cloud AI Agent notes`
  - `Editor’s Note: strengthen the business-value framing before the next conversation.`

No real customer, contact, meeting, or expense data may appear.

- [ ] Make the root redirect to `/design-system` and add `robots` metadata preventing indexing of this internal route.

- [ ] Run the app and visually inspect all six viewport/theme combinations. Check reading width, separators, wallpaper restraint, text wrapping, fixed controls, and no horizontal scrolling.

- [ ] Run acceptance:

```bash
pnpm test:e2e e2e/design-system.spec.ts
```

Expected: all behavior, responsive, accessibility, and screenshot assertions pass. Store screenshots only as Playwright test output unless the team explicitly chooses to version stable baselines.

- [ ] Commit:

```bash
git add web/src/app web/src/components/gallery web/e2e web/playwright.config.ts
git commit -m "feat: add design system acceptance gallery"
```

---

## Task 10: Final verification, documentation sync, and handoff

**Files:**

- Create: `web/README.md`
- Modify only if implementation discovered a genuine gap: `docs/superpowers/specs/2026-07-20-csig-sales-os-design-system-v2-design.md`
- Modify: `docs/superpowers/plans/2026-07-20-csig-sales-os-design-system-v2-implementation.md` only to record approved deviations

### Steps

- [ ] Write `web/README.md` with:

  - Node and pnpm prerequisites;
  - install, dev, test, build, and full verification commands;
  - token source-of-truth rule;
  - how pages import the public component barrel;
  - Day/Night and wallpaper persistence behavior;
  - how to add a component through the frozen governance process;
  - explicit statement that the gallery contains no production customer data.

- [ ] Search for prohibited implementation patterns:

```bash
rg -n '#[0-9A-Fa-f]{3,8}|shadow-|backdrop-|rounded-\[|animate-(bounce|pulse|spin)' web/src --glob '!**/app/globals.css' --glob '!**/tests/**'
```

Expected: no matches. If a valid exception is unavoidable, document and test the exact reason instead of weakening the search globally.

- [ ] Search for unfinished work:

```bash
rg -n 'TODO|FIXME|coming soon|not implemented' web/src web/README.md
```

Expected: no implementation placeholders.

- [ ] Run the complete verification pipeline from `web/`:

```bash
pnpm verify
```

Expected: ESLint, TypeScript, Vitest, production build, and Playwright all exit 0.

- [ ] Review build output for unexpected routes or server dependencies. The Design System gallery must be able to render without Supabase credentials or AI API keys.

- [ ] Review repository changes:

```bash
git status --short
git diff --check
git log --oneline --max-count=12
```

Expected: only intended `web/` and documentation changes; no `.superpowers/`, screenshots, browser databases, `.env`, or customer data staged.

- [ ] Commit final documentation:

```bash
git add web/README.md docs/superpowers
git commit -m "docs: document design system usage and verification"
```

## Definition of Done

- `web/` starts locally and `/design-system` renders without external services.
- All frozen Day/Night tokens and automatic switching rules work without theme flash.
- Wallpaper upload, replacement, removal, settings, failure preservation, and defaults work locally.
- Every frozen component exists behind one public import surface.
- Desktop 1440×1024, Tablet 834×1112, and Mobile 390×844 behaviors match the approved specification.
- Keyboard, focus, touch-target, reduced-motion, and WCAG automated checks pass.
- No page-specific style invention is required to build the future Home page.
- `pnpm verify` passes from a clean install.
- No database schema, production business page, real customer data, or external AI integration was added.

## Deferred Work (Explicitly Out of Scope)

- Adaptive Sales Command Center and all business pages.
- Supabase Auth, RLS, Storage, database entities, and migrations.
- Cloud synchronization of wallpaper preferences.
- AI chat, AI Context Snapshot, model providers, and Level 3 data processing.
- Product analytics, telemetry, and error-reporting vendors.
- Design variants not present in the frozen V2.0 specification.

## Approved Implementation Deviations

- Fonts use local `@fontsource-variable` packages instead of `next/font/google`. The build environment could not reach Google Fonts, and local packages preserve the specified Source Serif 4, Noto Serif SC, and Inter families while enabling private-network builds.
- Day `color.muted` is `#6B6B6B` rather than `#727272`; automated WCAG testing measured the original combination at 4.38:1. Accent and Danger retain their original non-text colors and add dedicated `accent-ink` and `danger-ink` text tokens.
- Local Playwright verification uses the installed Google Chrome channel because the 171 MiB bundled Chromium download repeatedly timed out. The browser choice does not change the test cases or acceptance thresholds.
