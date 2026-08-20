---
name: agent-friendly-web-stack
description: "Build or select a strict, agent-optimized stack for greenfield authenticated relational web products: TypeScript, Next.js App Router, Bun, Node.js, and Supabase, with explicit boundaries and deterministic local verification. Use for new SaaS apps, internal tools, and CRUD-heavy request-response products. Do not apply to existing apps, static sites, mobile, ML/data, streaming-first, embedded, or backend-specialized systems unless the user explicitly requests this stack or a migration."
---

# Agent-Friendly Web Stack

Optimize for the speed of verified, user-relevant progress: minimize the time from the smallest meaningful change to trustworthy, actionable evidence, subject to reliability, security, and data-integrity constraints. Treat code output, iteration count, test runtime, deployment frequency, and any other single metric as proxies, never objectives. Reduce feedback latency only after preserving signal quality and required coverage.

Build with one conventional path per concern and explicit system boundaries. Do not replace, omit, or add a competing choice for any layer unless the user explicitly requests it. Preserve an existing application's stack unless the user explicitly requests migration.

Apply this stack only when the product is greenfield, browser-delivered, relational, authenticated, and dominated by conventional request-response interactions. If any condition fails, preserve the existing stack or choose a workload-specific stack instead. Do not present this stack as universally optimal; its advantage is one constrained, executable path for this workload.

## Required stack

- **Language:** TypeScript with strict type checking and Next.js route-aware types
- **UI:** The React release supported by Next.js, with Server Components by default and Client Components only at interactive or browser-only boundaries
- **Application framework:** A current supported Next.js release selected at scaffold time and then held fixed in the lockfile, in App Router mode; do not add the Pages Router or a custom server
- **Build system:** Next.js's supported Turbopack defaults; do not add Vite as the application bundler, switch to Webpack, or customize the bundler without a demonstrated blocker
- **Styling:** Vanilla CSS; use CSS Modules for route and component styles and `app/globals.css` only for tokens, reset, and base rules; do not add utility CSS, CSS-in-JS, or a preprocessor
- **Package manager and task runner:** Bun for dependency installation, the lockfile, and invoking package scripts; application and test code must not depend on Bun runtime APIs
- **Application runtime:** Current Active LTS Node.js as the compatibility baseline for Next.js, tests, and production; use the Node server for production smoke tests and do not use Edge Runtime APIs without an explicit requirement and compatibility proof
- **Backend platform:** Supabase Cloud
- **Database:** Supabase Postgres
- **Data access:** `@supabase/supabase-js` in server-only data modules; do not add an ORM
- **Database types:** Supabase CLI-generated TypeScript types
- **Authentication:** Supabase Auth with `@supabase/ssr` cookie sessions and the current Next.js `proxy.ts` refresh pattern
- **Authorization:** Verified identity at each server entry point plus PostgreSQL Row Level Security at the data boundary
- **Schema and migrations:** Supabase CLI with version-controlled SQL migrations
- **Runtime validation:** Zod at every untrusted boundary
- **Database tests:** pgTAP through Supabase CLI
- **Unit and component tests:** Vitest, Testing Library, and jsdom
- **Server-rendered and browser tests:** Playwright, including async Server Components, Server Actions, navigation, streaming, and critical user journeys
- **Linting:** ESLint CLI with the current `eslint-config-next` Core Web Vitals and TypeScript rules
- **Formatting:** Prettier

Select mutually compatible supported releases when scaffolding and let Next.js select its compatible React versions. Make dependency or framework upgrades separate changes; consult the installed Next.js documentation under `node_modules/next/dist/docs/` or matching official migration guidance, then run the full completion gate. Never upgrade during unrelated work or mix patterns from different release eras. Do not hardcode package versions in this skill.

## Next.js architecture

- Start from a customized `create-next-app` App Router scaffold with TypeScript, ESLint, Turbopack, the `@/*` alias, no Tailwind, no `src/` indirection, and React Compiler disabled until a measured need justifies it. Do not generate agent documentation unless the user asks.
- Organize `app/` by route or feature. Colocate route-specific components, actions, schemas, styles, and tests; move code to shared directories only for a real third use or a system boundary. Use route groups only when they change layout or route organization materially.
- Keep pages and layouts as Server Components. Add `'use client'` only to the smallest leaf that needs state, effects, event handlers, browser APIs, or context; never pass secrets or unfiltered database records across that boundary.
- Read data directly in Server Components through a small `server-only` data-access boundary that performs authorization and returns minimal safe objects. Do not call the application's own Route Handlers from Server Components.
- Use thin Server Actions for UI mutations: validate input, re-verify authentication and resource authorization, call server-only domain/data code, then revalidate or redirect. Treat every Server Action as a directly reachable public POST endpoint.
- Use Route Handlers only for genuine HTTP boundaries such as webhooks, callbacks, public APIs, file responses, and non-UI clients. Authenticate, authorize, validate, rate-limit, and make state-changing handlers idempotent as their boundary requires.
- Use URL state for shareable state, Server Component data for server state, and local Client Component state for interaction. Do not add a client data-fetching, form, routing, or global-state library without a concrete unmet requirement.
- Use `loading.tsx` or `<Suspense>` for meaningful streaming boundaries, `error.tsx` for recoverable segment failures, and `not-found.tsx` for absent resources. Prefer Next.js Link, Image, Font, Metadata, and navigation APIs over replacements.
- Enable typed routes. Generate route types before standalone type checking and never edit or commit `.next/` output or `next-env.d.ts`.
- Keep the Node.js runtime by default and deploy to a platform that supports the Next.js features in use. Do not use static export for this authenticated server-backed stack; leave the hosting provider unselected until a concrete requirement chooses it.
- Prefer platform APIs, Next.js, Supabase, and existing code over new dependencies. Do not add repository, controller, adapter, or service layers beyond the server-only data and external boundaries that enforce correctness.

## Caching and data freshness

- Keep Cache Components disabled until a concrete shared caching or prerendering need justifies its added model.
- Make caching an explicit, reviewed decision. Fetch authenticated and request-specific data at request time by default; cache only data intentionally safe to share across users.
- Never put authorization-sensitive data or a response carrying `Set-Cookie` in a shared cache. Add private caching only for a measured need with tested identity keys, lifetime, and invalidation.
- Define a cache key, lifetime, ownership scope, and invalidation event before using `use cache`, cache tags, or revalidation APIs. Revalidate affected data after successful mutations; do not clear broader caches than necessary.
- Prefer uncached correctness over speculative caching. Add caching only after measuring a real latency or load constraint, and verify both freshness and tenant isolation.

## Data and security boundaries

- Validate environment variables once with Zod and fail with a clear error. Prefix only deliberately public values with `NEXT_PUBLIC_`; keep service-role and other privileged keys in `server-only` modules. Declare safe local defaults in an example environment file without secrets.
- Validate route parameters, search parameters, form data, cookies, Server Action arguments, Route Handler bodies, webhooks, and external responses before use. Derive TypeScript types from Zod schemas rather than restating them.
- Centralize Supabase browser, server, and Proxy clients. Use the server client by default and create a browser client only for a concrete browser-side or Realtime need.
- Refresh Supabase cookies in `proxy.ts`, but never treat Proxy, a layout, hidden UI, or a page redirect as authorization. Verify identity with the current trusted Supabase verification method near each data access; never authorize from the unverified user object returned by `getSession()`.
- Make every schema change in a forward migration. Do not make dashboard-only schema changes. Regenerate and commit database types after each migration; never hand-edit generated types.
- Enable RLS before exposing a table. Give every operation an explicit least-privilege policy and test allowed and denied cases with pgTAP.
- Put atomic multi-row mutations and transaction-dependent invariants in version-controlled PostgreSQL functions called through Supabase RPC; test their success, rollback, and authorization behavior with pgTAP. Never emulate a transaction with sequential client calls.
- Use user-scoped Supabase clients by default. Keep the service-role key server-only and use it only for an operation that intentionally bypasses RLS, with application authorization and audit coverage.
- Return only minimal safe data to Client Components and external responses. Add idempotency, rate limits, audit records, bounded retries, and structured logs where the actual boundary requires them; do not add speculative infrastructure.
- Before production, use platform-native structured logs, metrics, and traces on production paths, verify configured backups with an authorized non-production restore, and verify migration rollback or forward-fix procedures. Add an observability dependency only when the selected deployment's native facilities cannot meet a concrete requirement.

## Reproducible repository contract

- Treat `package.json` scripts, types, migrations, configuration, and tests as executable documentation. Do not scaffold a README, architecture document, CI pipeline, `AGENTS.md`, `CLAUDE.md`, or duplicate prose unless the user asks.
- Commit `bun.lock`, SQL migrations, generated database types, and lint, format, and test configuration. Declare the Bun release in `packageManager` and the supported Node.js major in `engines`; ignore `.next/`, test artifacts, local Supabase state, and secrets.
- Install the Supabase CLI and every build, lint, format, and test tool as a project development dependency. Do not rely on unrecorded global packages.
- Expose canonical scripts named `setup`, `dev`, `build`, `start`, `typecheck`, `lint`, `format`, `format:check`, `test`, `test:db`, `test:e2e`, `db:start`, `db:reset`, `db:types`, and `check`. Implement `typecheck` as `next typegen` followed by `tsc --noEmit`, `lint` with ESLint CLI, and `test` with non-watch `vitest run`.
- Make `setup` idempotently install Playwright's required browser and prepare the local Supabase database. Make verification scripts noninteractive, return reliable exit codes and concise failures, and accept path or name filters where supported.
- Make `check` the single non-source-mutating completion gate. Run formatting verification, linting, route-aware type checking, unit/component tests, database tests, a production build and Node LTS server smoke check, and Playwright tests in fastest-failure order.
- Make a fresh clone require only the declared Bun and Node versions plus Docker, followed by `bun install --frozen-lockfile` and `bun run setup`. Make tests provision or clearly fail on missing local dependencies instead of relying on hidden machine state.
- If an agent-instruction file exists or the user requests one, keep it short and reference the canonical scripts instead of duplicating their behavior.

## Feedback-loop contract

- Work in the smallest self-contained vertical slice with one falsifiable outcome while keeping the application runnable and the change easy to revert.
- Before editing, identify the intended behavior or invariant, the boundary at risk, and the fastest check capable of disproving correctness. For a reproducible bug, capture a failing regression test before fixing it.
- Use nested loops: targeted type, lint, and unit checks in seconds; affected component, database, integration, and build checks in minutes; `bun run check` at completion; and release telemetry and user outcomes after deployment.
- Run the narrowest sufficient check after each meaningful slice. Run the full gate at completion and earlier when a change crosses multiple layers. Stop on failure, fix the cause, and rerun the failing check before widening the loop.
- Trust feedback only when it is relevant, deterministic, and actionable. Treat a flaky check as broken, an escaped defect as missing coverage, and a passing suite as evidence for modeled behavior rather than proof of absolute correctness.
- Reduce latency by deleting redundant checks, proving behavior at the lowest sufficient layer, filtering affected tests, caching unchanged work, and parallelizing independent checks. Never remove required coverage or boundary verification to make a metric faster.
- Keep the full local gate within ten minutes when practical. Treat a slower gate as a signal to measure stage duration and fix the largest avoidable wait, not as permission to weaken verification.
- Measure feedback-loop health only when it guides a decision: stage latency, flake rate, change-to-accepted time, escaped defects, and recovery time. Optimize the system constraint, not the easiest local metric.
- When selecting or changing a framework, runtime, package manager, data layer, or test tool, compare the current path with at most one credible alternative on representative work. Measure first-pass gate success, accepted-change time, correction loops, human review effort, escaped defects, gate latency, and cost. Change the stack only for a concrete unmet requirement or a material measured improvement; never optimize token use, generated lines, or benchmark scores alone.
- Close outer loops at real boundaries with migration checks, safe rollout and rollback, structured telemetry, SLOs, and direct user evidence when the product risk requires them.

## Test contract

- Test observable behavior at the lowest layer that proves it. Add a regression test for every bug fix.
- Test pure domain logic and synchronous Server or Client Components with Vitest. Test UI through Testing Library user interactions. Test database constraints and RLS with pgTAP.
- Test async Server Components, Server Actions, Route Handlers, streaming, navigation, hydration, and critical cross-layer journeys with Playwright rather than simulating unsupported framework behavior in jsdom.
- Keep tests deterministic and independent. Control time, randomness, network responses, and database state at their boundaries; never depend on test order or shared production data.
- Prefer real internal modules and a local Supabase instance. Mock only external systems or behavior that cannot run locally.
- Query components by accessible role, label, and visible text. Avoid implementation-detail assertions and broad snapshots.

## Completion gate

Before claiming completion:

1. Confirm the requested behavior and boundaries are covered by tests.
2. Regenerate route and database types affected by schema, route, or configuration changes.
3. Run `bun run check` successfully from the final state.
4. Run every release-boundary check required and authorized by the task.
5. Review the final diff for secrets, client-boundary leaks, unsafe caching, unrelated changes, duplicated facts, dead code, and dependencies that no longer justify their cost.
6. Report the exact verification evidence, remaining risks, and any check that could not run.

Describe the result as verified by the named evidence, never as absolutely correct. If a required check cannot run, mark the work unverified rather than complete.
