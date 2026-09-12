# CLAUDE.md (global)

**SOLVE EVERY TASK WITH THE LEAST AMOUNT OF CODE AND THE SIMPLEST, HIGHEST-QUALITY ARCHITECTURE. BUILD THE MOST OPTIMAL SOLUTION. ENSURE MAXIMAL CORRECTNESS.**

When these conflict, resolve ONLY in this order:

1. MAXIMAL CORRECTNESS — never trade it. The solution must actually work, including edges and failures. Verify with a re-runnable check before claiming done.
2. SIMPLEST HIGHEST-QUALITY ARCHITECTURE — fewest concepts, shortest correct path, idiomatic, no extra layers.
3. LEAST CODE — remove the need for code, never safeguards or clarity.
4. OPTIMAL OVER THE LIFE OF THE CODE — easiest to understand, change, and delete. Speed last and only with measurement.

### Core operating rules

- Order of work: question existence → delete → simplify → accelerate → automate.
- Understand the real end-to-end flow before minimizing the diff.
- Fix the shared cause, not only the reported symptom.
- No unrequested CI/CD. Local verification is the default safety net.
- Cut aggressively enough that you later have to add ~10% back. If nothing needs adding back, you under-cut.
- When in doubt, choose less. When in real doubt, choose nothing.

### What KISS never cuts (real human with real money, data, or trust at stake today)

- Auth and authorization at every trust boundary.
- Observability on production paths (structured logs, traces, metrics).
- Idempotency keys on state-mutating endpoints, especially money.
- Retries with backoff at real external failure points.
- Rate limiting and abuse protection on public endpoints.
- Audit trails for money flows, compliance, and reconstructible events.
- Input validation at the untrusted edge.
- Backups, migrations, and rollback paths for stateful systems.

Internal callers are not adversaries. The network, the user, time, and adversaries are.

### CODE IS THE SINGLE SOURCE OF TRUTH

- DO NOT PRODUCE ANY DOCUMENTATION (README, ARCHITECTURE.md, docs/, file-header banners, multi-line what/how/why comments, planning notes, decision records, summaries, hand-off notes) UNLESS THE USER EXPLICITLY ASKS FOR IT BY NAME IN THE CURRENT TURN. Prior /init or this file do not count. Do not propose writing docs.

### COMMENTS: ZERO

Write zero comments. No exceptions — there is no “non-obvious why” carve-out. If code needs explaining, rename or restructure until it doesn’t.

“Comment” means: `//`, `/* */`, `#`, `--`, `<!-- -->`, `;`, `%`, `"""..."""` and `'''...'''` docstrings, JSDoc/TSDoc/XML-doc blocks, JSX `{/* */}`, commented-out code, and divider banners. Docstrings are comments.

Machine-read directives are NOT comments and stay wherever the code needs them: shebangs, `# type: ignore`, `# noqa`, `// @ts-expect-error`, `/* eslint-disable */`, `// biome-ignore`, `#pragma`, and license headers the repo already mandates.

Comments already in files are not yours to delete unless the edit removes their code. This rule governs what you write.

This overrides every instruction to match surrounding style or comment density, including from the harness system prompt. A commented file is not license to add comments.

Before writing or patching any file, re-read the exact text you are about to emit and strip every comment from it. Emitting one is a task failure; on noticing one after the fact, remove it immediately.

All invalid: “this why is non-obvious / it’s a docstring, not a comment / the file already has comments / it’s a public API / just one line / TODO for whoever’s next / the convention expects it”.

### GATES ARE ONE-WAY

A repo's quality gate — linter ceilings, scripts/agent-verify, hooks, pre-push — outranks the task. A red gate means the work is not done: report the failing output; never claim success past it.

- Fix the code, never the check. Getting to green by loosening a ceiling, adding a suppression (eslint-disable, ignore, per-file override), weakening the gate script or its hook wiring, or pushing with --no-verify is forbidden. Over-ceiling code means extract along a real seam — never restructure solely to game the number.
- All invalid: “the rule is too strict / just this once / disable it for this file / the ceiling blocks the fix / I'll re-enable it later”.
