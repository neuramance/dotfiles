---
name: agent-friendly-web-stack
description: "Strict stack specification for greenfield web applications: TypeScript, React, React Router framework mode, Vite, vanilla CSS, Bun, Active LTS Node.js compatibility, Supabase Cloud with Postgres, Supabase Auth with supabase-js and @supabase/ssr, Row Level Security, Supabase CLI with pgTAP, Zod, bun:test with Testing Library and Happy DOM, Playwright, ESLint with typescript-eslint, and Prettier. Use when creating, scaffolding, bootstrapping, or selecting the stack for a new web application. Do not apply to existing applications unless the user explicitly requests migration to this stack."
---

# Agent-Friendly Web Stack

Use this complete stack for greenfield web applications. Do not replace, omit, or add a competing choice for any layer unless the user explicitly requests it. Preserve an existing application's stack unless the user explicitly requests migration.

## Required stack

- **Language:** TypeScript with strict type checking
- **UI:** React
- **Application framework:** Latest stable React Router in framework mode
- **Build system:** Vite through React Router's supported integration
- **Styling:** Vanilla CSS (plain stylesheets, no utility or CSS-in-JS framework)
- **Package manager:** Bun
- **Primary runtime:** Bun
- **Compatibility runtime:** Current Active LTS Node.js
- **Backend platform:** Supabase Cloud
- **Database:** Supabase Postgres
- **Data access:** `@supabase/supabase-js`
- **Database types:** Supabase CLI-generated TypeScript types
- **Authentication:** Supabase Auth with `@supabase/ssr` cookie sessions
- **Authorization:** PostgreSQL Row Level Security
- **Schema and migrations:** Supabase CLI with version-controlled SQL migrations
- **Runtime validation:** Zod
- **Database tests:** pgTAP through Supabase CLI
- **Unit and component tests:** `bun:test`, Testing Library, and Happy DOM
- **Test fallback:** Vitest only when `bun:test` lacks a required capability
- **Browser tests:** Playwright
- **Linting:** ESLint with typescript-eslint
- **Formatting:** Prettier

Use mutually compatible current supported releases. Preserve explicitly selected majors; do not encode exact versions or implicitly upgrade an existing application.
