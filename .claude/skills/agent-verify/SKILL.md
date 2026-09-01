---
name: agent-verify
description: Provision a repository's self-contained quality gate — scripts/agent-verify, scripts/agent-gate.sh, and .claude/settings.json hooks. Use when asked to add agent-verify, a verify script, or hook-enforced checks to a repo.
---

# Build scripts/agent-verify

Provision the gate the way unstoppable-math does it: `scripts/agent-verify` (the checks), `scripts/agent-gate.sh` (hook adapter), and `.claude/settings.json` wiring PostToolUse (matcher `Edit|Write`, timeout 30) and Stop (matcher `""`, timeout 300) to `"$CLAUDE_PROJECT_DIR"/scripts/agent-gate.sh`. The user's global ~/.claude/agent-gate.sh defers to any repo with its own scripts/agent-gate.sh, so there is no double execution.

## Contract

- Exit 0 = pass, non-zero = fail. Failure output feeds back to the model: print `--- <check> failed:` plus the log tail, preferring tools that emit `file:line: message`.
- `$1` = one file → fast per-edit check. No argument → full check at turn end.
- Budgets: fast ≤ 1s, full ≤ 10s wall warm. A check that cannot fit moves to the repo's everything command (`bun run check`, `make check`) or the pre-push hook, never into the gate. 300s is the hook timeout, not the budget.
- File types the fast path cannot check exit 0. A false block is worse than no block.
- Deterministic only: no network, no prompts, no flaky tests.

## Procedure

1. Discover what the repo already has: package.json scripts, Makefile, justfile, CI workflows, lint/typecheck/test configs. Wrap existing commands; invent nothing.
2. Fast path: formatter check + lint of only the edited file, both cached (`prettier --check --cache --no-error-on-unmatched-pattern "$1"`, `eslint --cache --cache-location node_modules/.cache/eslint "$1"`); formatter alone for json/css/md; anything else exits 0. No typecheck on the fast path — it cannot fit the budget.
3. Full path: format, lint, unit tests, and build in parallel via the `run` helper (per-job mktemp log; on failure print the job name and `tail -n 30` of its log), then typecheck serially. Never run two jobs that write the same artifacts concurrently — in Next.js repos typecheck (`next typegen`) and build both write `.next/` and the race makes the gate flaky.
4. Complexity ceilings go in the linter config as a dedicated rules block, never in the script: `complexity` (ESLint core, cyclomatic), `max-depth`, `max-lines`, `max-lines-per-function` (unstoppable-math: 18 / 4 / 500 / 150). Set each global at the current typical code; pin grandfathered offenders with per-file overrides. Pins are a one-way ratchet: never raise a pin, never add a file to the overrides; when a refactor drops a file below its pin, lower or delete the pin in the same change; when no file needs a looser global, tighten the global. The script merely runs the linter, so agent, humans, and CI share one gate.
5. Slow suites (db tests, e2e) go in `.githooks/pre-push` — wired by `git config core.hooksPath .githooks` in the repo's setup script — and in the everything command.
6. Write both scripts from the reference shapes below and `chmod +x` both. The adapter parses hook JSON with the repo's own runtime (bun/node/python — never assume jq) and fails open (exit 0) on unparseable input.
7. Record the contract in the repo's AGENTS.md the way unstoppable-math does: when to run each path, "exit 0 or the task is not done", the ceilings and ratchet rules, and that any edit to the loop requires evidence in the same change — `time scripts/agent-verify` before and after, plus a planted failure proving non-zero exit with a legible tail.
8. Test before declaring done: `time` the full run (exit 0 on the current tree) and the fast run on a valid file; plant a failure in a temp file and prove the fast run exits non-zero with actionable output; remove it. If the full run fails on pre-existing issues, fix them or pin them — never ship a gate that blocks every turn.
9. Report: checks wrapped, ceilings and pins set, measured runtimes of both paths.

## scripts/agent-verify (reference — swap the run lines and typecheck for the repo's own commands)

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
if (($#)); then
  case $1 in
    *.ts | *.tsx | *.js | *.jsx | *.mjs)
      bunx prettier --check --cache --no-error-on-unmatched-pattern "$1" &&
        bunx eslint --cache --cache-location node_modules/.cache/eslint "$1"
      ;;
    *.json | *.css | *.md) bunx prettier --check --cache --no-error-on-unmatched-pattern "$1" ;;
    *) exit 0 ;;
  esac
  exit $?
fi
pids=()
names=()
logs=()
run() {
  local log
  log=$(mktemp)
  logs+=("$log")
  names+=("$1")
  shift
  "$@" >"$log" 2>&1 &
  pids+=($!)
}
run format bunx prettier --check --cache .
run lint bunx eslint --cache --cache-location node_modules/.cache/eslint .
run tests bunx vitest run
run build bun run build
fail=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    fail=1
    printf -- '--- %s failed:\n' "${names[$i]}"
    tail -n 30 "${logs[$i]}"
  fi
done
rm -f "${logs[@]}"
((fail)) && exit 1
out=$(bun run typecheck 2>&1) || {
  printf -- '--- types failed:\n%s\n' "$(printf '%s' "$out" | tail -n 30)"
  exit 1
}
exit 0
```

## scripts/agent-gate.sh (reference — swap `bun -e` for the repo's runtime)

```bash
#!/usr/bin/env bash
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
input=$(cat)
IFS=$'\t' read -r event file active < <(printf '%s' "$input" | bun -e 'const j = JSON.parse(await Bun.stdin.text()); console.log([j.hook_event_name ?? "", j.tool_input?.file_path ?? "", j.stop_hook_active === true ? "1" : "0"].join("\t"))') || exit 0
if [[ $event == PostToolUse ]]; then
  [[ -n $file ]] || exit 0
  out=$("$root/scripts/agent-verify" "$file" 2>&1) && exit 0
  printf '%s\n' "$out" | tail -n 20 >&2
  exit 2
fi
[[ $active == 1 ]] && exit 0
[[ -n $(git -C "$root" status --porcelain) ]] || exit 0
out=$("$root/scripts/agent-verify" 2>&1) && exit 0
printf '%s\n' "$out" | tail -n 30 >&2
exit 2
```
