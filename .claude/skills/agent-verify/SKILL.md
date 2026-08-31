---
name: agent-verify
description: Provision a repository's self-contained quality gate — scripts/agent-verify, scripts/agent-gate.sh, and .claude/settings.json hooks. Use when asked to add agent-verify, a verify script, or hook-enforced checks to a repo.
---

# Build scripts/agent-verify

This skill provisions a repo-self-contained quality gate that works for every contributor: `scripts/agent-verify` (the checks), `scripts/agent-gate.sh` (hook adapter parsing hook JSON via the repo's own runtime — bun/node/python, never assume jq), and `.claude/settings.json` wiring PostToolUse (Edit|Write, timeout 30) and Stop (timeout 300) to the adapter via `"$CLAUDE_PROJECT_DIR"/scripts/agent-gate.sh`. The user's global ~/.claude/agent-gate.sh defers automatically to any repo that has its own scripts/agent-gate.sh, so there is no double execution. Copy the adapter shape from an existing repo (e.g. unstoppable-math): PostToolUse checks the edited file and exits 2 with an error tail on failure; Stop honors stop_hook_active, allows clean trees, runs the full verify, exits 2 with the tail on failure; unparseable input fails open (exit 0).

## Contract

- Exit 0 = pass, non-zero = fail. Failure output is fed back to the model, so prefer tools that print `file:line: message`.
- `$1` = single file path → fast per-edit check, budget ~1-2s. No argument → full check at turn end, budget under 300s (the Stop hook timeout).
- File types the fast path cannot check: exit 0. A false block is worse than no block.
- Deterministic only: no network, no prompts, no flaky tests. Cheapest checks first, fail fast.

## Procedure

1. Discover what the repo already has: `package.json` scripts, Makefile, justfile, CI workflows, lint/typecheck/test configs. Wrap existing commands; invent nothing. If a `make check` or equivalent exists, the full path is that one command.
2. Fast path: syntax, lint, or typecheck of only the edited file. Full path: lint + typecheck + the fastest deterministic test command. Slow or flaky suites belong in CI, not the gate.
3. Complexity ceilings go in the repo linter config, not the script: cognitive complexity (preferred over cyclomatic), max function length, max file size — each ratcheted just below the current worst offender so the gate blocks regression immediately and can be tightened later. The script merely runs the linter, so agent, humans, and CI share one gate.
4. Write `scripts/agent-verify`: bash, `set -uo pipefail`, `cd "$(git rev-parse --show-toplevel)"`, then the two paths. `chmod +x` it.
5. Test before declaring done: full run exits 0 on the current tree; fast run on a valid file exits 0; fast run on a deliberately broken temp file exits non-zero with actionable stderr; remove the temp file. If the full run fails on pre-existing issues, either fix them or narrow the check — never ship a gate that blocks every turn.
6. Report: checks wrapped, ceilings set and their ratchet values, measured runtimes of both paths.

## Reference shape

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
if (($#)); then
  case $1 in
    *.ts|*.tsx) bun x oxlint "$1" && bun x tsc --noEmit ;;
    *) exit 0 ;;
  esac
  exit $?
fi
bun x oxlint . && bun x tsc --noEmit && bun test
```
