---
description: Deep correctness audit of work in scope — either a proposed change about to be written (audit before writing) or recently written changes (audit and fix).
---

Think hard. The bar for this audit is extreme certainty — not "looks correct," not "probably fine," but verified. Correctness, diligence, and comprehensiveness are non-negotiable here. Every change must be proven, not assumed. Do not make mistakes. If you make one, catch it and correct it before moving on.

Stop and shift into a slower, more deliberate mode. The work you are about to
review is foundational. Errors here compound — they become assumptions that
later code builds on, tests validate against, and users depend on. The cost of
a mistake caught now is near zero; the cost of one caught later is orders of
magnitude higher.

## Mindset

You are not skimming for obvious bugs. You are a careful, skeptical auditor
who assumes every line might be wrong until proven otherwise. For each change,
ask: *Is this actually correct, or does it just look correct?*

Common failure modes to guard against:
- **Plausible but wrong** — code that reads naturally but has a subtle logic
  error (off-by-one, wrong variable, inverted condition, missing edge case)
- **Inconsistent with context** — code that is correct in isolation but
  contradicts conventions, types, or invariants established elsewhere in the
  codebase
- **Incomplete** — a change that handles the happy path but silently breaks
  under null, empty, concurrent, or boundary conditions
- **Copy-paste drift** — duplicated patterns where one instance was updated
  but another was not
- **Wrong abstraction level** — solving the right problem at the wrong layer,
  or coupling things that should be independent

## Step 1 — Define the audit scope

There are two modes. Determine which applies before doing anything else.

### Prospective — work proposed but not yet written
If the conversation contains a change you planned but have not yet written to
disk (a diff you sketched, an edit you described in prose, a patch you were
about to apply, a response you were about to give that contains code or
config), audit the proposal **before writing it**. The cost of catching an
error here is lower than catching it after the edit lands.

In this mode the unit under audit is the proposal itself. "Fix it" in Step 5
means revising the proposal, not editing files. The final report ends with
either a green light to apply, or a revised proposal — never a silent edit.

### Retrospective — work already written
If there is no pending proposal, audit recent on-disk work. Run in parallel:

```bash
git diff HEAD~1...HEAD          # Last commit diff
git diff --cached               # Staged changes
git diff                        # Unstaged changes
git log --oneline -5            # Recent commits for context
git diff HEAD~1...HEAD --name-only
git diff --name-only
git diff --cached --name-only
```

Review uncommitted changes if the tree is dirty, otherwise the most recent
commit(s) from this session. Use judgment — the goal is to audit what was
just produced, not the entire history.

### Both, or neither
If a proposal **and** uncommitted changes both exist, audit both and keep the
boundary explicit in the report. If the tree is clean and no proposal is in
flight, say so and stop — there is nothing to audit.

### Default when ambiguous
If the user invokes /correct immediately after you described a plan but
before you wrote it, default to **prospective**. That is almost always the
intent — they want to verify the plan, not re-audit unrelated history.

## Step 2 — Read every changed file in full

For each changed file, read the **entire file**, not just the diff hunks. You
need full context to verify:
- The change is consistent with the rest of the file
- Imports, type signatures, and dependencies are correct
- No existing code was broken by the change
- The file still makes sense as a coherent whole

In prospective mode: read the **current** version of every file the proposal
would touch, plus closely related files, so the proposal can be evaluated
against real context rather than imagined context.

## Step 3 — Verify correctness, line by line

For every change, work through these checks deliberately. Do not skip any.

### Logic
- Trace the control flow. Does every branch do what it should?
- Check boundary conditions: null, empty, zero, negative, maximum values.
- Verify loop bounds and termination conditions.
- Check arithmetic: operator precedence, integer overflow, floating-point
  precision, off-by-one errors.
- For conditionals: are the conditions correct? Are they inverted? Is the
  else branch right?

### Types and signatures
- Do all function signatures match their call sites?
- Are return types correct for every code path (including early returns and
  error paths)?
- Are nullable types handled — not just annotated, but actually checked before
  use?
- Do generic types, array shapes, and collection types match what is actually
  stored and retrieved?

### Names and references
- Does every variable reference the right thing? Watch for similarly-named
  variables (`$user` vs `$users`, `$id` vs `$patientId`, `result` vs
  `results`).
- Are string literals correct — no typos in keys, column names, route paths,
  event names, or config keys?
- Do enum values, constants, and magic strings match their usage sites?

### State and side effects
- Are mutations happening to the right object? (Mutating a copy instead of the
  original is a classic bug.)
- Is ordering correct — are operations sequenced in the right order?
- Are resources properly acquired and released (connections, locks, file
  handles)?
- For async or concurrent code: are there race conditions, missing awaits, or
  shared state issues?

### Integration
- Does this change work with the code that calls it and the code it calls?
- Are database queries correct — right table, right columns, right joins,
  right WHERE clause?
- Do API contracts (request/response shapes, HTTP methods, status codes) match
  both sides?
- Are configuration values, environment variables, and feature flags referenced
  correctly?

### Edge cases
- What happens with empty input? Null input? Extremely large input?
- What happens if an external service is down or returns an error?
- What happens on the first run? The last iteration? When there are zero items?
- What happens if this code runs twice (idempotency)?

## Step 4 — Cross-reference with existing code

For each changed file, search the codebase for related code that might be
affected:

- If you changed a function signature, find all callers.
- If you changed a data structure, find all consumers.
- If you changed a pattern (naming, convention, approach), check if parallel
  instances need the same update.
- If you changed configuration or constants, find everything that reads them.

Use grep, find, and file reads to verify. Do not assume — prove that nothing
is broken.

## Step 5 — Fix every issue found

In prospective mode, "fix" means revising the proposal — do not write files.
In retrospective mode, edit the code.

For each issue identified in Steps 3-4:

1. **Describe the issue clearly** — what is wrong, why it is wrong, and what
   the correct behavior should be.
2. **Fix it** — edit the code (retrospective) or revise the proposal
   (prospective). Do not leave TODOs or "fix later" notes.
3. **Verify the fix** — re-read the surrounding code to confirm the fix is
   correct and does not introduce a new issue.
4. **Check for the same bug elsewhere** — if this was a pattern error, search
   for other instances.

If applicable, run available verification tools:
- Type checkers / static analysis (phpstan, mypy, tsc, etc.)
- Linters (phpcs, eslint, etc.)
- Tests (if a relevant test suite exists and can run quickly)

Do not skip verification because it is slow. Correctness is more important
than speed.

## Step 6 — Second pass

After fixing all issues, do one final read-through of every file you touched
(including files modified by your fixes). This pass catches:
- Issues introduced by your own fixes
- Things you missed on the first pass now that you understand the code better
- Inconsistencies between files (e.g., you fixed a type in file A but not in
  file B which uses the same type)

## Step 7 — Report

State clearly:
- How many files were reviewed
- What issues were found and fixed (if any)
- What verification was performed
- Your confidence level that the changes are correct

If you found zero issues, say so — but only after genuinely completing every
step above. A clean audit is a valid outcome, but a rushed "looks good" is not.

For prospective audits, conclude with one of:
- **Proceed as proposed** — the proposal is correct and ready to apply
- **Proceed with the following revisions** — apply this revised version
- **Do not proceed** — the proposal is wrong; here is why and what to do instead
