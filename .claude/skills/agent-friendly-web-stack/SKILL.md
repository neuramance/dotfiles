---
name: agent-friendly-web-stack
description: "Select the core stack for greenfield authenticated relational web applications, including SaaS apps, internal tools, and CRUD products. Preserve existing stacks unless migration is explicitly requested."
---

# Agent-Friendly Web Stack

Use this stack for new browser-based, authenticated relational applications built around conventional request-response interactions. Choose a suitable stack for other workloads. Preserve an existing application's stack unless the user explicitly requests migration.

| Concern | Choice |
| --- | --- |
| Language | TypeScript |
| Application framework and UI | Next.js App Router with React |
| Application bundler | Turbopack |
| Styling | StyleX |
| Package manager and task runner | Bun |
| Application runtime | Node.js Active LTS |
| Backend platform | Supabase Cloud |
| Database | Supabase Postgres |
| Authentication | Supabase Auth with `@supabase/ssr` |
| Data access | `@supabase/supabase-js` |
| Database authorization | PostgreSQL grants and Row Level Security |
| Migrations and database types | Supabase CLI, SQL migrations, and generated TypeScript types |
| Runtime validation | Zod |
| Unit and component testing | Vitest and Testing Library |
| Database testing | pgTAP through Supabase CLI |
| Browser and end-to-end testing | Playwright |
| Linting | ESLint |
| Formatting | Prettier |

Use these defaults unless a concrete requirement or the user calls for another choice. Select mutually compatible supported releases, including the React version supported by Next.js. Leave implementation and workflow decisions to the task and repository.
