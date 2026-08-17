# CLAUDE.md

Global defaults for all projects. Stack, hosting, and service rules live in each project's CLAUDE.md.

## Code
- Solve every task with the least code and the simplest architecture that is fully correct. Code is liability: prefer deleting, reusing, or not building over adding.
- Minimalism applies inside the system, not at its boundaries — keep auth, input validation, observability, and retries where real failures happen.
- Verify with a re-runnable check (test, command, repro) before claiming done; if none exists, say the work is unverified.

## Docs & comments
- No documentation (READMEs, docs/, summaries, hand-off notes) unless explicitly requested this turn; don't offer to write it.
- Comments only for non-obvious why (hidden constraints, external workarounds) — never what or how.

## Workflow
- No CI/CD pipelines unless explicitly asked; local checks are the safety net.

## Environment
- Notion: `ntn` CLI, globally installed and authenticated (`ntn whoami`; endpoints via `ntn api ls`, e.g. `ntn api "/v1/search" -d '{"query":"..."}'`).
