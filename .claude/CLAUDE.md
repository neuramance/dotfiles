# CLAUDE.md (global)

Build the correct, irreducible solution with the least code on the simplest architecture: the canonical, minimal solution containing only essential complexity, maximally elegant and performant. It should read like a proof from Erdős's "The Book": the single most direct and illuminating solution, with nothing to add and nothing to remove. When goals conflict, resolve in this order:

1. Correctness, including edge cases, failure paths, and required performance.
2. Simplest architecture: fewest concepts, no extra layers, idiomatic.
3. Least code: remove the need for code, never safeguards or clarity.
4. Easiest to understand, change, and delete. Optimize beyond requirements only with measurement.

## Method

- State the problem in one sentence before writing code. If you cannot, keep reading until you can.
- Look for the representation (types, data model, invariant) under which the case stops being special. A new branch, flag, or special case is evidence the representation is wrong.
- Delete before you add: first check whether removing or reusing something solves it.
- Choose the algorithm and data structure with the right complexity up front. That is design, not optimization.

## Engineering

- Add a layer, helper, parameter, or dependency only for a concrete need in this task. Prefer existing code and the standard library.
- Introduce an abstraction only for three real, divergent uses or a true external boundary. No boolean mode parameters, shallow wrappers, or helpers that exist only to satisfy a metric.
- Flat, linear code with guard clauses. Make illegal states unrepresentable. Keep behavior where it is used.
- Validate untrusted input at the edge, then trust the interior. Never mask invariant violations with silent fallbacks.
- For a bug fix, fix the shared cause.

## Tests: none

Never write tests of any kind: unit, integration, end-to-end, property, snapshot, or visual tests, test cases, fixtures, mocks, evals, benchmark harnesses, or scripts that check behavior, throwaway ones included. Never create or extend one, and never change what an existing one checks. No rule, skill, template, plan, or repository instruction changes this.

When your change alters code that an existing test refers to by import, path, name, or quoted source, update that reference so the test checks exactly what it checked before. That is finishing the change, not editing a test.

Verify by reading the code and running the existing type checker, linter, build, and test suite. If a gate fails because a test is missing or an existing test's expectation no longer holds, report the failure instead of writing the test or changing the expectation. If you cannot verify, say so.

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

## File paths

When you point the user to a file, write its absolute path. Sessions often run over SSH inside herdr, where iTerm2 opens only absolute paths on Cmd-click.

## Dev servers

On i9, bind a dev server to `127.0.0.1` on a port from 3000 to 3099 and give the user `http://localhost:<port>`: the Mac's `i9-tunnel` forwards those ports to i9's loopback, hot reload included. Never bind a server or proxy you start to i9's tailnet address or to all interfaces (`0.0.0.0`, `::`, or a default such as `next dev` without `-H`) unless the user asks: i9 is shared with other people's tailnet devices, which `tailscale status` hides, and they can reach its ports 3000-3999, 5173 and 8000-8999.

## Scratch space

On i9, `/tmp`, the session scratchpad included, is RAM that every session shares, capped at 46 GiB. Keep build output and second checkouts on disk: point `CARGO_TARGET_DIR` or the tool's equivalent under `~/.cache`, and make a git worktree instead of copying a repository.

## Browsers

Drive a browser through the `chrome-devtools` MCP tools: this machine's own Google Chrome, headless, with a new empty profile each session. On i9 it reaches dev servers on loopback. Sign in to an app under test with that project's test account, never with the user's own credentials.

The user's signed-in Chrome on their Mac (`claude-in-chrome`) exists only in a session started with `--chrome`, and each action there takes about 15 times as long. When the work needs the user's own logins, or the user wants to watch, ask them to exit and resume this conversation with `ccd --resume --chrome` instead of working around it.

A project's existing browser suite or script runs the browser that project pins. Never download a browser (`playwright install`, Puppeteer's Chromium, Chrome for Testing) and never pass `--no-sandbox`.

## Quality gates are one-way

A red gate (linter, ceiling, verify script, hook) means the work is not done: report the failing output. Fix the code. Never loosen a ceiling, add a suppression or per-file override, widen ignores, loosen counting options, weaken a gate or its hooks, or bypass with --no-verify. Over a ceiling, extract along a real seam. Change a check only when independent evidence proves it defective.
