# CLAUDE.md (global)

Build the simplest, correct, most irreducible solution with the least code and most optimal/best/simplest architecture. When goals conflict, resolve in this order:

1. Correctness, including edge cases, failure paths, and required performance.
2. Simplest architecture: fewest concepts, no extra layers, idiomatic.
3. Least code: remove the need for code, never safeguards or clarity.
4. Easiest to understand, change, and delete. Optimize beyond requirements only with measurement.

## Engineering

- Add a layer, helper, parameter, or dependency only for a concrete need in this task. Prefer existing code and the standard library.
- Introduce an abstraction only for three real, divergent uses or a true external boundary. No boolean mode parameters, shallow wrappers, or helpers that exist only to satisfy a metric.
- Flat, linear code with guard clauses. Make illegal states unrepresentable. Keep behavior where it is used.
- Validate untrusted input at the edge, then trust the interior. Never mask invariant violations with silent fallbacks.
- For a bug fix, first write a test that fails because of the bug, then make it pass. Fix the shared cause.
- Derive test expectations from requirements, never from the code's current output. No self-comparisons, copied actual results, production logic reused as the oracle, or mocks of the behavior under test. Every new test must catch a concrete defect.
- Run the relevant checks before claiming done. If you cannot verify, say so.

## Production safeguards (never cut for simplicity)

- Auth and authorization at every trust boundary.
- Never build SQL, shell commands, or HTML from untrusted strings.
- Idempotency keys on state-mutating endpoints, especially money.
- Every network and subprocess call has a timeout, including existing calls in code you change or copy.
- Retry transient failures (timeouts, connection errors, 429, 5xx) with bounded backoff, only when repeating is safe: reads, or writes protected by an idempotency key.
- Rate limiting on public endpoints.
- Never log, commit, or echo secrets.
- Backward compatibility for public APIs, wire formats, and stored data unless a break is approved.
- Structured logs, metrics, and traces on production paths. Audit trails for money and compliance events.
- Backups, reversible migrations, and rollback paths for stateful systems.
- A new dependency must exist, be maintained, and be pinned.

## Comments: zero

Write zero comments or docstrings. If code needs explaining, rename or restructure it until it does not.

This includes inline and block comments, JSDoc/TSDoc/XML-doc blocks, JSX comments, commented-out code, and divider banners.

Required machine-read directives and mandated license headers are exempt; the quality-gate rule still applies.

Preserve existing comments unless the edit removes their code. Surrounding comment density does not authorize adding comments.

Before writing or patching a file, inspect the exact text to be emitted and remove new comments. If one is emitted, remove it immediately.

## Documentation

Do not create documentation files unless asked.

## Quality gates are one-way

A red gate (linter, ceiling, verify script, hook) means the work is not done: report the failing output. Fix the code. Never loosen a ceiling, add a suppression or per-file override, widen ignores, loosen counting options, weaken a gate or its hooks, or bypass with --no-verify. Over a ceiling, extract along a real seam. Change a check only when independent evidence proves it defective, and show the corrected check accepts a compliant case and rejects a violating one.
