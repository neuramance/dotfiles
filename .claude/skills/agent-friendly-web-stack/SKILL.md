---
name: agent-friendly-web-stack
description: "Select the core stack for greenfield authenticated relational web applications, including SaaS apps, internal tools, and CRUD products. Use when starting a new web app or choosing its stack. Preserve existing stacks unless migration is explicitly requested."
---

# Agent-Friendly Web Stack

Use this stack for new browser-based, authenticated relational applications built around conventional request-response interactions. Choose a suitable stack for other workloads. Preserve an existing application's stack unless the user explicitly requests migration.

| Concern | Choice |
| --- | --- |
| Language | TypeScript |
| Application framework and UI | Next.js App Router with React |
| Application bundler | Turbopack |
| Styling | StyleX |
| UI components | Base UI |
| Package manager and task runner | Bun |
| Application runtime | Latest Node.js LTS |
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
| Linting | Oxlint |
| Formatting | Oxfmt |

Use these defaults unless a concrete requirement or the user calls for another choice. Select the newest releases that work together, including the React version Next.js supports, and confirm each combination with lint, type checking, tests, and a build. Scaffold with `--no-tailwind` and replace the generated CSS Modules with StyleX. Follow the StyleX Next.js guide, which works with Turbopack, but drop its `require()` calls, which fail Oxlint's `no-require-imports`: write the Babel alias as `` `${__dirname}/*` `` and give the PostCSS plugin only `useCSSLayers: true`, since it reuses the project Babel config and finds source files itself. Style Base UI parts by spreading `stylex.props`, and target their state attributes with keys such as `':is([data-checked])'`. Convert create-next-app's ESLint config to Oxlint with `@oxlint/migrate`, set the `correctness` category to `error`, enable `options.typeAware` with `oxlint-tsgolint`, then remove ESLint; without Next.js's rules, Oxlint enables no React, Next.js, or accessibility rules. Load `@stylexjs/eslint-plugin` through Oxlint's `jsPlugins` and enable each of its rules as an error except the stylistic `sort-keys` and `no-lookahead-selectors`, which bans the `stylex.when` selectors that need `:has()`, now supported by every major browser. StyleX throws at runtime unless compiled, so in Vitest pass the Babel config's `plugins` to `@rolldown/plugin-babel` in `vitest.config.mjs`; a `.mts` config fails type checking on the imported plugin tuples. A build that emits no StyleX CSS still passes, so assert a computed StyleX style with Playwright. Run package scripts with `bun run`, because `bun test` starts Bun's test runner instead of Vitest. Enable Row Level Security on every table the Supabase Data API exposes, grant each role only the privileges it needs, prove allowed and denied access with pgTAP, and run `supabase db advisors --fail-on warn`, since without the flag it exits 0 even on errors. Verify identity on the server with `supabase.auth.getClaims()`. Leave other implementation and workflow decisions to the task and repository.
