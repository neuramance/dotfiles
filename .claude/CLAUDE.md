# CLAUDE.md

Global guidance for Claude Code (claude.ai/code), inherited by every project. Project-specific rules — stack, hosting, services — live in each project's own CLAUDE.md.

**Scope:** these rules govern **code**. For prose, docs, specs, and other non-code artifacts, apply the same _spirit_ — minimal, every part load-bearing, nothing decorative, clear over clever — in that medium, not the literal code rules (the gate, least-lines, no-comments, line-level irreducibility).

# The mandate

> **SOLVE EVERY TASK WITH THE LEAST AMOUNT OF CODE AND THE SIMPLEST, HIGHEST-QUALITY ARCHITECTURE. BUILD THE MOST OPTIMAL SOLUTION. ENSURE MAXIMAL CORRECTNESS.**

This is the bar every change is held to — binding, not aspirational. It governs every change of every size: features, fixes, tests, scripts, one-liners. No exemption for urgency, prototypes, or "temporary" code, and no rationalization in "Red-flag thoughts" overrides it. If another rule in this file ever seems to conflict, the mandate wins. The four are one standard, not four wishes — and when they pull against each other, resolve them in this exact order:

1. **Maximal correctness is the constraint, never the trade.** The solution must actually do what it should — including the edges, failures, and boundaries named in "What KISS does not cut." Fewer lines never justify a wrong result; a smaller wrong answer is still wrong. Verify it — with a check you can re-run, not by inspection — before you claim it.
2. **Simplest, highest-quality architecture is the method.** The fewest concepts and the shortest path from input to outcome that _stays_ correct. Quality is fitness, not elaborateness: the right boundaries, honest names, and idiomatic use of the platform — never extra layers, patterns, or polish added in its name. Simplicity is what makes correctness checkable on first read — that is why it ranks above raw brevity.
3. **Least code follows from the first two, never the reverse.** You reach it by removing the _need_ for code, not by removing safeguards or compressing behavior into cleverness. Density that hides what the code does is the opposite of this mandate.
4. **Most optimal means optimal over the whole life of the code** — easiest to understand, change, and delete — not fastest to type, not cleverest, not micro-optimized. Speed comes last, and only with measurement.

## Enforcement

No change is complete until its final state passes all four checks — one per mandate clause, same order. A failed check blocks delivery: fix it and re-run; never present, commit, or claim completion first, and never ship a known violation behind a "clean up later" note.

1. **Verified correct.** A re-runnable check — test, command, reproduction — has passed against the final state. If no such check is possible, say so and mark the work unverified; claiming this bar was met when it wasn't is the gravest violation of this file.
2. **No simpler design survives scrutiny.** Name the simpler design you rejected and the concrete requirement it fails. If you cannot name that requirement, the simpler design is the solution — build it instead.
3. **The diff is irreducible.** Re-read the final diff line by line and delete every line whose removal leaves behavior intact. Whatever remains is load-bearing by construction.
4. **Optimal over the code's life.** The change is understandable on first read without your narration, changeable without fear, deletable without regret. If following the diff requires the explanation around it, simplify until it doesn't.

Everything below is _how_ to meet this bar, and the enforcement above is how you prove you met it. KISS is how you reach the least code and the simplest architecture; "What KISS does not cut" is how you hold maximal correctness while doing it. Read the rest of this file as the operational detail of the one sentence above.

# Keep It Simple (KISS)

**Default state is non-existence.** Every concept, layer, parameter, dependency, line — every _thing_ — must justify _existing_ against the alternative of not existing. The cheapest, fastest, most reliable system is the one that doesn't exist; the next-best is the one with the fewest things in it.

**Code is liability, not asset.** Lines get read, modified, debugged, secured, ported, and eventually deleted — forever. Value comes from _behavior_, not from code. Maximize behavior per line; minimize lines. Users pay you for behavior; you pay for code.

**Every line must be load-bearing.** Existence is the first gate; form is the second. Once a thing must exist, write it so removing any line breaks the behavior — the irreducible form. If removing a line leaves the behavior intact, the line was decoration. This applies at every scale: a guard, a test, a function, a module. The idea has a natural size; the code expressing it should be no larger.

This goes beyond the default "don't add features beyond what the task requires." It applies at the moments the default doesn't reach: choosing tools, picking abstractions, deciding when to extract, and when to delete.

## The gate

Before letting any new concept exist — a layer, parameter, dependency, config option, helper, interface, abstraction — answer all four:

1. **Who is the human asking, and what is their concrete problem _today_?** "The spec," "the team," "best practice," "we might need it" do not count. Name the person.
2. **Is there a third real, divergent caller?** Two cases is a coincidence. Inline until three. _Bends for:_ a true external boundary (HTTP, plugin, public API, persistence schema) — the boundary itself is the abstraction.
3. **Would the standard library, the framework's intended path, or something already in this codebase do?** The cheapest line is the one you didn't write.
4. **Is this reversible cheaply, or am I buying flexibility now to avoid a cost I may never pay?** Prefer reversibility over flexibility.

If you can't pass all four, choose the simpler default.

## What "simple" means

Not "easy" and not "short." Few concepts; one unit, one concern (Hickey's "simple," not "easy"); the shortest reasonable path from input to outcome; what a competent reader would expect in this codebase's idiom; easy to delete, replace, or change.

## Core principles

- **YAGNI, with a name attached.** Every requirement needs a human whose concrete problem it solves. No name → cut it. Smart-sounding requirements are routinely wrong by a wide margin.
- **Rule of Three.** Don't extract until three real, divergent uses. Three lines inline beats a premature helper.
- **Order: question → delete → simplify → accelerate → automate.** Challenge whether the work should exist. Then delete what survives. Then simplify. Then tighten the loop. _Last,_ automate. Optimizing or automating something that should be deleted is the most expensive form of waste in software.
- **Understand before you minimize.** The least-code rule shortens the solution, never the reading. Trace the real flow end to end — every file the change touches — before you choose the smallest diff. A small diff you don't understand is not economy; it's a second bug wearing efficiency as a disguise.
- **Fix the cause, not the symptom.** A report names a symptom; the cause is usually upstream. Before editing, find every caller of the function you're about to touch and repair the shared function once — one guard where all callers route through is a smaller _and_ more correct diff than one guard per caller, and patching only the path the report named leaves every sibling caller broken.
- **No CI/CD by default.** Local verification — a hook running the test/check suite — is the safety net. Don't add GitLab CI / GitHub Actions / pipelines unless explicitly asked; an unrequested one is bloat that fails noisily on infra it doesn't have.
- **Reversibility before flexibility.** A reversible decision needs no flexibility built in. Flexibility is complexity you pay for now to avoid a cost you may never incur.
- **Minimum viable surface area.** Public functions, exports, flags, env vars are contracts you'll have to keep. Expose the smallest set real callers need.
- **Boring substrate, leading edge surface.** Novelty is a tax paid every day. Pay it where product capability genuinely demands it — the latest model, a new technique, a cutting-edge library at the value-creating surface. Use boring, well-worn tools everywhere else: databases, deploys, frameworks, package managers, auth, queues. The bet is leading edge _where the differentiation lives_, conservative everywhere it doesn't.
- **Make it work, then right, then fast.** In that order. Optimization without measurement is fiction.
- **Cut aggressively enough that you have to add ~10% back later.** If nothing ever needs adding back, you under-cut.
- **Violating the letter is usually violating the spirit.** Don't talk yourself into a special case.

## What KISS does not cut

KISS targets _internal_ complexity — speculative flexibility, premature abstraction, layers that don't pay rent. It does **not** mean cutting production essentials at system boundaries. These have a real human with a real problem _today_ (the user whose money, data, or trust is at stake) and pass the gate cleanly. Don't apply YAGNI to the system's contract with the outside world.

- **Auth and authorization** at every trust boundary.
- **Observability on production paths.** Structured logs, traces, metrics on critical flows. You can't fix what you can't see, and a system you can't see is not production-grade.
- **Idempotency keys** on state-mutating endpoints — especially anything touching money.
- **Retries with backoff** at external boundaries where real failures happen (network, third-party APIs, payment processors). _Not_ internal calls that can't fail.
- **Rate limiting and abuse protection** on public endpoints.
- **Audit trails** for money flows, compliance, and anything you'd be asked to reconstruct after the fact.
- **Input validation** at the edge where untrusted data enters.
- **Backups, migrations, and rollback paths** for stateful systems. The day you need them, "we'll add it later" is too late.

Rule of thumb: apply YAGNI _inside_ the system, not at the boundaries. Internal callers are not adversaries; the network, the user, time, and adversaries are. A boring, minimal implementation of the essentials beats a clever one that omits them. "Production grade" means these are _present and working_, not that they are elaborate.

## Red-flag thoughts

When any of these surfaces, you are rationalizing. Stop and choose the simpler default.

Each entry: **the rationalizing thought** → _what it really means_ → **default action**.

- **"We might need this later."** → No evidence we will. → **Add it the day a real need appears.**
- **"This is more flexible."** → Knobs nobody is turning. → **Hardcode the actual case.**
- **"This is cleaner."** → More layers. → **Inline.**
- **"This is the proper way."** → I learned a pattern and want to use it. → **Use the pattern when the problem demands it, not when the pattern wants a host.**
- **"What if we want to swap implementations?"** → Speculative interface. → **Concrete first. Extract on a real second implementation.**
- **"Just in case."** → No real case. → **Don't write it.**
- **"It's only a few extra lines."** → Each line is read many times more than written. → **Cut them.**
- **"We'll clean it up later."** → We won't. → **Do less now.**
- **"Let me add a config option."** → One caller wanted it once. → **Hardcode. Promote on a second caller with a different value.**
- **"Let me handle this just in case."** → Defensive code for an impossible state. → **Trust internal code. Validate at edges.**
- **"Let me extract this helper."** → Two similar lines. → **Inline until three.**
- **"This is elegant."** → Clever. → **Choose obvious over clever.**
- **"Same pattern as before."** → Shapes match; meaning may not. → **Compare meanings, not shapes, before unifying.**
- **"I'll generalize while I'm in here."** → Scope creep dressed as efficiency. → **Make the change you came to make.**
- **"Let me speed this up / automate this."** → May be optimizing what should be deleted. → **Try to remove the underlying work first.**
- **"Spec / team / best practice says so."** → Citing an authority instead of a person. → **Find the human whose problem this solves, or treat as a guess and cut.**

**When in doubt, choose less. When in real doubt, choose nothing** — and promote a thing into existence only when it proves it must exist _today_. Your goal is the design a competent reader can fully understand on first read, change without fear, and delete without regret.

## CODE IS THE SINGLE SOURCE OF TRUTH

Every fact about the system lives in code: types, names, structure, tests, and (rarely) load-bearing comments where the _why_ is non-obvious. Prose documentation is, by default, **absent**. DOCUMENTATION IS A LIABILITY. The code is how the system ACTUALLY works and what the system ACTUALLY does in reality.

1. **DO NOT PRODUCE DOCUMENTATION UNLESS THE USER EXPLICITLY ASKS FOR IT IN THE CURRENT TURN**, naming docs or a doc file. Prior `/init`, this CLAUDE.md, or inferred intent do not count. "Documentation" includes READMEs, ARCHITECTURE.md, anything under `docs/`, file-header banners, multi-line "what/how/why" comment blocks, planning notes, decision records, summaries, hand-off notes.
2. **Comments: NONE.** Justified only for non-obvious _why_ — hidden constraints, subtle invariants, workarounds for specific external bugs. Never narrate _what_, never reference task/PR/caller.
3. **Don't propose writing docs.** No "want me to update the README?" suggestions. No `/init`-style auto-doc skills against this repo.

# Environment

- **Notion:** use the `ntn` CLI (installed globally, already authenticated — verify with `ntn whoami`). `ntn api ls` lists endpoints; search with `ntn api "/v1/search" -d '{"query":"..."}'`; fetch a page as markdown with `ntn api "/v1/pages/{page_id}/markdown"`.
