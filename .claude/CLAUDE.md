# CLAUDE.md (global)

**SOLVE EVERY TASK WITH THE LEAST AMOUNT OF CODE AND THE SIMPLEST, HIGHEST-QUALITY ARCHITECTURE. BUILD THE MOST OPTIMAL SOLUTION. ENSURE MAXIMAL CORRECTNESS.**

This mandate is binding for every change of every size. No exemptions for urgency, prototypes, or temporary code.

When the four conflict, resolve ONLY in this order:

1. MAXIMAL CORRECTNESS — never trade it. The solution must actually work, including edges and failures. Verify with a re-runnable check before claiming done.
2. SIMPLEST HIGHEST-QUALITY ARCHITECTURE — fewest concepts, shortest correct path, idiomatic, no extra layers.
3. LEAST CODE — remove the need for code, never safeguards or clarity.
4. OPTIMAL OVER THE LIFE OF THE CODE — easiest to understand, change, and delete. Speed last and only with measurement.

### Enforcement (all four must pass or the change is incomplete)

- VERIFIED CORRECT by a re-runnable check. If none is possible, mark the work unverified. Claiming otherwise is the gravest violation.
- No simpler design survives scrutiny. Name the simpler design you rejected and the concrete requirement it fails. If you cannot name it, build the simpler one.
- The diff is irreducible. Delete every line whose removal leaves behavior intact.
- The change is understandable on first read without narration, changeable without fear, deletable without regret.

### Decision gate (answer all four before any new concept, layer, parameter, dependency, helper, or abstraction may exist)

1. Who is the specific human and what is their concrete problem TODAY? “The spec / team / best practice / we might need it” do not count.
2. Is there a third real, divergent caller? Two is coincidence. Inline until three. (True external boundaries are exempt.)
3. Would the standard library, the framework’s intended path, or existing code already do it?
4. Is this reversible cheaply, or am I buying flexibility I may never need?

Fail any → choose the simpler default (usually non-existence).

### Core operating rules

- DEFAULT STATE IS NON-EXISTENCE. Every concept must justify existing against the alternative of not existing.
- CODE IS LIABILITY. Maximize behavior per line. Minimize lines.
- EVERY LINE MUST BE LOAD-BEARING. If removing it leaves behavior intact, it is decoration.
- YAGNI with a name attached. No named human → cut it.
- Rule of Three: inline until three real divergent uses.
- Order of work: question existence → delete → simplify → accelerate → automate.
- Understand the real end-to-end flow before minimizing the diff.
- Fix the shared cause, not only the reported symptom.
- No unrequested CI/CD. Local verification is the default safety net.
- Reversibility before flexibility.
- Minimum viable surface area for every public contract.
- Boring substrate everywhere; leading-edge only where differentiation lives.
- Make it work, then right, then fast (measured).
- Cut aggressively enough that you later have to add ~10% back. If nothing needs adding back, you under-cut.
- Violating the letter is usually violating the spirit. Do not invent special cases.

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

### Red-flag rationalizations → required action

- “We might need this later / just in case / more flexible / cleaner / the proper way / what if we swap implementations / only a few extra lines / we’ll clean it up later / let me add a config option / handle this defensive case / extract this helper / this is elegant / same pattern as before / I’ll generalize while I’m here / let me speed this up or automate this / spec / team / best practice says so”
  → STOP. Hardcode the actual case or delete. Promote only on a real second or third need. Inline until three. Validate only at edges. Do less now.

When in doubt, choose less. When in real doubt, choose nothing.

### CODE IS THE SINGLE SOURCE OF TRUTH

- DO NOT PRODUCE ANY DOCUMENTATION (README, ARCHITECTURE.md, docs/, file-header banners, multi-line what/how/why comments, planning notes, decision records, summaries, hand-off notes) UNLESS THE USER EXPLICITLY ASKS FOR IT BY NAME IN THE CURRENT TURN. Prior /init or this file do not count. Do not propose writing docs.

### Environment

Notion: use the global `ntn` CLI (already authenticated). Verify with `ntn whoami`.

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
