# CLAUDE.md

Global rules for all projects — only what Claude Code's defaults don't already enforce. Project-specific rules (stack, hosting, services) live in each project's own CLAUDE.md.

## Verification

- A change isn't done until a re-runnable check proves it — a test, script, or command that fails if the behavior breaks. Inspection doesn't count.
- Local verification is the safety net: prefer a hook that runs the test/check suite over CI. No GitHub Actions / GitLab CI / pipelines unless explicitly asked.

## Understand fully, fix the cause

Trace the real flow end to end — every file the change touches — before choosing the smallest diff. A small diff you don't understand is a second bug wearing efficiency as a disguise.

A report names a symptom; the cause is usually upstream. Before editing, find every caller of the function you're about to touch and repair the shared path once — patching only the reported path leaves every sibling caller broken.

## Production essentials — never YAGNI these away

Apply YAGNI inside the system, never at its boundaries. Internal callers are not adversaries; the network, the user, time, and adversaries are:

- Auth and authorization at every trust boundary
- Input validation at the edge where untrusted data enters
- Idempotency keys on state-mutating endpoints — especially anything touching money
- Retries with backoff at external boundaries (network, third-party APIs) — not internal calls
- Rate limiting and abuse protection on public endpoints
- Audit trails for money flows, compliance, anything reconstructed after the fact
- Structured logs and metrics on critical production paths
- Backups, migrations, and rollback paths for stateful systems

A boring, minimal implementation of these beats a clever one that omits them.

## Docs

Beyond the default no-README rule: don't write or propose planning notes, decision records, summaries, or hand-off files either. Code, types, names, and tests are the single source of truth. Exception: a doc gap proven load-bearing — a wrong or missing line that caused real breakage — gets flagged in one sentence; write the fix only if asked.

# Environment

- **Notion:** use the `ntn` CLI (installed globally, already authenticated — verify with `ntn whoami`). `ntn api ls` lists endpoints; search with `ntn api "/v1/search" -d '{"query":"..."}'`; fetch a page as markdown with `ntn api "/v1/pages/{page_id}/markdown"`.
- **Nessie** (personal context library): use the `nessie` CLI (already authenticated — verify with `nessie status`). Start agent sessions with `nessie check-in`; browse with `nessie ls` / `cat` / `head` / `tail`; find content with `nessie search`. Note: `nessie` on PATH is the Nessie.app CLI (`/usr/local/bin/nessie`); the unrelated pynessie data-catalog CLI also exists at `~/.local/bin/nessie` — don't confuse them.
