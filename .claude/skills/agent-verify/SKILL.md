---
name: agent-verify
description: Build or improve repository verification loops with enforced complexity ceilings, fast actionable checks, and Codex CLI or Claude Code hooks. Use when asked to install agent-verify, wire automatic checks, or strengthen an agent verification workflow; use existing commands directly for routine testing.
---

# Agent verification

Build one repository-owned gate that enforces correctness checks and complexity limits, shared by manual commands, agent hooks, and Git hooks. Correctness outranks architecture, architecture outranks code size, and measured speed comes last. Repository setup includes establishing missing quality controls; installing the skill itself does not install repository hooks.

## Inspect before changing

- Read the repository instructions, package scripts, linter configuration, gate implementation, test selection, lock, and Git hooks. Trace edits through focused checks, turn-end checks, and pre-push checks. Check the agent version and relevant project and user hook settings.
- Run the existing gate before changing it. Identify uncovered source files, missing quality controls, pre-existing failures, and measured bottlenecks. Report the chosen commands, ceilings, counting options, rationale, and integration before editing; proceed within the requested scope without introducing an approval step.
- Separate observed results, assumptions, and recommendations. Verify consequential claims against resolved configuration, executed commands, and primary documentation for the installed versions. Seek evidence that could disprove the working explanation and revise it when contradicted. A green exit alone does not establish coverage or hook activation.
- Target the requested host; otherwise use the host running the task. Add support for both hosts only when requested. Preserve unrelated settings, notifications, and hooks.
- Reuse a working gate such as `bun run gate`; do not create a second `scripts/agent-verify` just to match this skill's name. Extend existing tooling for missing controls. If no gate exists, add one repository command and the adapter needed to translate lifecycle events into it.
- Use the repository's runtime and dependencies; do not require personal scripts or assume jq, Bash, Vitest, or a framework. Before adding a concept, dependency, or coordination mechanism, identify the simpler alternative and the current requirement it cannot satisfy. Prefer the design with the least total implementation and maintenance burden.

## No tautological tests

- Derive expectations from requirements, contracts, or independently verified examples. Reject self-comparisons, expected results copied from actual results, production logic duplicated as the sole oracle, and assertions that only confirm test setup or mock return values.
- Exercise the real behavior under test and assert observable outputs, state changes, errors, or required interactions. Mocks, shared fixtures, property tests, and snapshots are valid when they independently constrain that behavior. Do not mock away the behavior being verified or blindly approve snapshots.
- Enforce mechanically detectable tautologies as errors in the existing focused and full lint commands, covering actual test files. Prefer maintained framework-aware rules. Assertion-presence and validity rules do not establish this coverage; ESLint's `no-self-compare` does not inspect `expect(value).toEqual(value)`. For a demonstrated gap, use one narrow local rule if the linter supports it, reusing its parser and scope APIs. Recognize actual assertion APIs, import aliases, and variable bindings; reject direct cases such as `expect(true).toBe(true)` and `expect(value).toEqual(value)`. Identical calls or property reads alone do not prove equal values. Report unsupported cases instead of building a general analyzer.
- Verify assertion rules with rejecting fixtures and representative valid tests, including independent expectations, legitimate mocks, and repeated calls. Exercise the actual focused and full commands; confirm the rule and location reach the caller. Measure added latency with representative inputs under the feedback targets below before adopting new tooling. Keep these checks in the existing lint invocation; do not add a separate scanner, hook, typechecking pass, or model call.
- Before completion, review every added or changed test and identify a concrete behavioral defect it would catch. For regression tests, demonstrate failure on the original defect and success after the fix. If fault detection is unclear, introduce a relevant fault in an isolated copy and confirm failure for the intended behavioral reason; rerun against correct code afterward. Syntax, import, and setup failures do not establish defect detection. Report unavailable evidence as unverified.
- Reuse that regression or fault check as evidence; do not add mutation testing to every edit by default. Add mutation tooling only for a concrete remaining verification gap with measured cost appropriate to the feedback budget. Scope it to affected behavior, including code affected by test-only changes, and preserve existing required suites and execution points. A surviving mutation may be behaviorally equivalent, and good existing tests can hide a useless new test; do not impose a universal 100% mutation target.
- Rewrite or remove tautological tests while preserving required coverage; unresolved tautologies leave the task incomplete. Lint, coverage, and mutation scores do not replace semantic review. Do not add tests that merely match source text or instruction wording to certify compliance.

## Calibrate and enforce complexity limits

Use these starting recommendations for JavaScript and TypeScript repositories without established limits. They are policy defaults, not proven optima or limits of AI capability. Preserve existing ceilings and rule options; assess any proposed tightening before adoption. Enforce adopted limits as linter errors for maintained source, including tests and verification code. Store global values in one dedicated linter rules block; scripts invoke the linter rather than duplicate its policy.

| Constraint | ESLint rule | Starting maximum |
| --- | --- | --- |
| Cyclomatic complexity per function | `complexity` | 10 |
| Nested control-flow depth | `max-depth` | 3 |
| Lines per file | `max-lines` | 500 |
| Lines per function | `max-lines-per-function` | 100 |

- Before adopting new limits or tightening existing ones, assess representative implementation, UI components where present, tests, and verification code against expected changes. Evaluate correctness, cohesion, ownership, dependencies, and locality. Initial choices need a concrete rationale; do not select limits merely to fit current violations. Where representative code is unavailable, use the starting recommendations and report calibration as unverified.
- Make counting semantics explicit. For new ESLint rules, use classic cyclomatic complexity, count formatted physical lines including blank and comment lines, and include IIFEs in function length. Verify resolved options against documentation for the installed version: optional chaining and defaults can contribute to complexity, JSX contributes to length, and control-flow depth does not measure JSX nesting.
- AI authorship and larger context windows do not establish better thresholds. File length alone does not measure the context needed for a change. Claim improvements only with comparable representative changes: correctness and regressions first, then dependencies and coordination, agent time, and token use. Measure runtime performance separately.
- For other languages, use maintained language-native tooling for the same constraints. Prefer existing tools; add a dependency only for a concrete enforcement gap, through the repository's package manager and lockfile. Verify metric semantics before comparing limits. Report unsupported constraints as incomplete coverage rather than silently omitting them or substituting a different metric.
- For Rust, reuse the validated setup in `~/code/rust-template` (configuration, `scripts/agent-verify`, `scripts/verify-push`, and the `scripts/test-agent-verify` self-test). It maps nesting to clippy `excessive_nesting` at 5 (ESLint depth 3 inside methods, depth 4 in free functions), function length to `too_many_lines` at 100 (non-blank, non-comment body lines, so looser than physical lines), file length to the gate's 500-physical-line check, and boolean mode parameters to `fn_params_excessive_bools` with `max-fn-params-bools = 0`. Classic cyclomatic complexity has no maintained Rust equivalent; report it as a gap, because clippy's `cognitive_complexity` measures something else and is easy to game. The gate passes lint levels to clippy on the command line from the protected `.lints-baseline`, so manifest edits cannot weaken them, denies warnings with `CARGO_BUILD_WARNINGS=deny`, and rejects suppression attributes (also written as raw identifiers), `cfg_attr`, `cfg_select!`, `cfg`s that mention clippy or `debug_assertions`, build-script `rustc-cfg`, `include!`, `#[path]` and local macros with a whitespace-insensitive scan, and runs cargo with `--locked --offline` so a network fault cannot stall a hook. Avoid `forbid` and `--force-warn` for clippy lints: `forbid` breaks code generated by serde, thiserror, clap and tokio macros, `--force-warn` overrides the allowances `#[tokio::main]` emits, and group-level `forbid` does not stop `#[expect]`. Permission deny rules do not bind subprocess writes; Claude Code's sandbox enforces them at the OS level, but it is opt-in because it blocks signed commits on this machine.
- Make the same rules run in focused lint and the full gate. Check actual file coverage and rule resolution; a configured rule that ignores the repository's source does not count. Preserve legitimate generated-code and dependency exclusions; never expand ignores to hide maintained code, tests, or adapters.
- Apply a one-way ratchet: never raise an established ceiling, disable a rule, reduce severity, add suppressions or per-file overrides, or weaken hook wiring to obtain green. Calibration does not reopen established limits. Do not loosen counting options or coverage to reduce reported violations. Preserve existing stricter per-file rules. Lower or remove existing looser overrides when their code meets a tighter limit; never add or increase one. Tighten globals only for a justified stricter repository target that the full tree meets; a small current maximum alone is not justification. Keep ceiling values solely in linter configuration.
- If the adopted limits reveal violations, fix them through small behavior-preserving refactors within scope. If completing the baseline requires substantial unrelated refactoring, report the exact failures and necessary scope; leave the setup explicitly incomplete. Never choose a looser baseline, pin offenders, or declare success over a red gate.
- Extract only along a real seam: a cohesive component, state transition, domain operation, or external boundary. Account for dependencies and coordination removed and interfaces introduced; a lower metric alone does not justify a split. Prefer guard clauses and linear flow over nesting. Use closed state representations for mutually exclusive states and validate untrusted input at boundaries. Keep cohesive behavior together; avoid boolean mode parameters, shallow wrappers, and helpers used only to evade a metric.
- Reuse existing code and framework paths. Add an abstraction only for three real divergent uses or a required external boundary. Write no new comments or docstrings except required machine directives and mandated licenses. Preserve unrelated existing comments. Numeric limits support review; they do not prove correctness or good architecture.
- A failing check is not evidence that the check is defective. Correct a check only with independent evidence of its intended behavior; prove it accepts a compliant case and rejects a relevant violation, then rerun affected gates. Never bypass hooks or weaken a valid check.

## Build the feedback loop

Keep the gate directly runnable outside the agent: selected paths request focused checks; no paths request the full turn-end gate, unless an existing command interface already provides these operations. Exit 0 only when every selected required check passes; failures, missing tools, and timeouts exit nonzero.

| Execution point | Required behavior |
| --- | --- |
| After an edit | Formatter check and lint, including complexity and assertion rules, on supported changed files. Reuse sound affected-test selection when available. Fall back to a broader check when dependency impact cannot be determined safely. |
| Before task completion | All applicable formatting, lint, typechecking, unit tests, and production build checks. Reuse equivalent existing coverage; add missing checks appropriate to the repository without manufacturing a build or typecheck for a stack that has neither. |
| Before push | Full gate plus existing slower integration, database, and browser suites required for release. For a new loop, expose these through the repository's everything command and local pre-push hook; preserve existing hooks and required execution points. |

- Make failures actionable: print the check name, command, exit status or timeout, and bounded diagnostics with `file:line` and violated rule when available. Preserve enough of the error to identify its cause and retain the complete failure log locally without secrets. Keep successful output concise and separate concurrent logs so messages remain attributable.
- Preserve all existing required checks, test locks, and hooks. Do not move an existing required check to a later execution point to meet a speed target. Do not call partial verification the full gate. If a required service or input is unavailable, report that check as unverified and the required gate as incomplete.
- For new Git hook wiring, inspect `core.hooksPath` and existing hooks. Compose with the existing setup; do not replace unrelated hooks. Verify executability and reproducible setup. Re-running installation must preserve unrelated settings and produce no duplicate hooks or verification runs. Do not add CI or edit instruction documents unless explicitly requested.

## Shorten feedback without weakening it

- Use the focused command after edits and the required turn-end command at Stop. Batch paths from one operation into one invocation when supported. Avoid repeating typechecking already fully covered by the build; verify that equivalence before removing a command.
- Treat one second for focused checks and ten seconds for a warm turn-end run as targets, never reasons to omit required checks. Measure before and after with equivalent inputs, cache state, and load. Use repeated representative runs and report variability before claiming improvement; distinguish cold and warm results.
- Reuse dependency-correct caches. File-only ESLint caches do not establish correctness for type-aware rules affected by imported files; keep an uncached type-aware check where required.
- Parallelize only independent checks. Preserve database serialization and avoid concurrent writers to generated files, build output, or caches, including across overlapping hook invocations. Set a total gate deadline below the host timeout, leaving time for diagnostics and cleanup; cancel and reap descendants on interruption or timeout.
- Keep verification deterministic: no automatic source fixes, prompts, or dependency downloads. Expected build artifacts, generated types, caches, and isolated test data are allowed; do not rewrite maintained source or leave unexpected tracked changes. Use installed tools and keep new focused and turn-end checks offline. Preserve existing environment-dependent suites and their required services at their established execution points; do not remove coverage to make a gate offline.
- Keep the execution path simple. Add caching, persistent state, workers, or custom scheduling only for a measured bottleneck that simpler existing tooling cannot solve correctly. Once final checks pass, repeat them only when subsequent changes invalidate their results or unresolved concerns justify it.

## Hook adapter contract

Read one JSON object from stdin and validate the event fields before use. Resolve relative paths from the event's `cwd`, and the repository from the edited file's directory for edit events (a session can edit files in another repository) or from `cwd` otherwise. Pass paths as argument values, protecting option-like filenames with absolute paths or `--`; never interpolate them into shell commands. Never execute `tool_input.command`; for Codex patches it is data.

| Event | Input | Action |
| --- | --- | --- |
| Codex `PostToolUse` for `apply_patch` | `tool_input.command` contains the patch; a single patch can affect multiple files | Select existing added/updated files and rename destinations, then run focused verification. Account for deletions in the turn-end gate. |
| Claude Code `PostToolUse` for `Edit` or `Write` | `tool_input.file_path` | Run focused verification on the edited file. |
| Either host's `Stop` | `stop_hook_active` and `cwd` | Run the chosen turn-end gate, including after edits made through shell or other tools. |

Validate selected paths against the repository boundary, including symlink resolution. If a patch cannot be mapped reliably, run the broader check and report the fallback. Unsupported file types may skip focused verification only when explicitly outside its scope and covered by the turn-end contract; never label an unrecognized edit verified.

A clean Git status alone is not proof of verification: an agent may have committed its edits. Start with an unconditional Stop check rather than adding persistent state or skipping clean trees.

- Pass: exit 0 with empty stdout. Keep check logs out of protocol stdout.
- Failed check, invalid relevant payload, or failed startup: send the command or event, failure reason, and bounded diagnostics to stderr; exit 2 so the agent receives feedback.
- Stop re-entry: when `stop_hook_active` is true, recheck. If still red, end automatic retries with exit 0 and a JSON object containing `continue: false`, `stopReason`, and `systemMessage` that clearly report verification failed and the task remains incomplete. Never silently accept the failure or loop indefinitely.
- Use synchronous hooks for blocking checks, with a timeout above measured runtime. Label skips explicitly. A hook cannot undo an edit, and hooks are not a complete security or correctness boundary.

## Codex CLI integration

Consult the installed CLI version and the current [OpenAI hook documentation](https://learn.chatgpt.com/docs/hooks) before wiring hooks. Project hooks live in `.codex/hooks.json` or inline `[hooks]` in `.codex/config.toml`. Prefer the representation already present; otherwise use `hooks.json`. Matching hooks from multiple sources all run, so inspect user and project hooks to prevent duplicate verification.

For a Bun repository using `scripts/agent-gate.ts`, merge these entries into the existing configuration after implementing the adapter. Adapt the runtime and path to the repository. Root resolution keeps the command working when Codex starts in a subdirectory; do not assume `CLAUDE_PROJECT_DIR` exists in Codex.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "^apply_patch$",
        "hooks": [
          {
            "type": "command",
            "command": "root=$(git rev-parse --show-toplevel) || exit 2; exec bun \"$root/scripts/agent-gate.ts\"",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "root=$(git rev-parse --show-toplevel) || exit 2; exec bun \"$root/scripts/agent-gate.ts\"",
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

The matcher observes native patches, not every possible file mutation. Stop covers shell edits; add other PostToolUse matchers only for observed tool paths that need focused feedback. Codex also accepts `Edit` and `Write` as aliases for `apply_patch`, but still sends a patch payload, not Claude's `file_path`.

Codex requires project trust and review of new or changed hook definitions through `/hooks`. Finish the implementation and validation before handing off that review. Do not write trusted hashes or bypass hook trust. Distinguish configured, discovered, trusted, and executed hooks in the final report.

## Claude Code integration

Merge project hooks into `.claude/settings.json`. Use `PostToolUse` with matcher `Edit|Write` and a Stop hook, both calling the repository adapter. Claude provides `CLAUDE_PROJECT_DIR` for locating it. Preserve existing permission settings and unrelated hooks.

Inspect any global adapter before adding project hooks. In this user's setup, `~/.claude/agent-gate.sh` currently skips repositories with an executable `scripts/agent-gate.sh` that the repository's `.claude/settings.json` references; a differently named adapter, or an unreferenced one, does not trigger that skip. Verify delegation rather than assuming identical commands are deduplicated. Do not alter global hooks without authorization. Confirm host-specific behavior against [Claude Code's hook documentation](https://code.claude.com/docs/en/hooks).

## Verify and deliver

- Use isolated fixtures to prove each complexity and size limit accepts a compliant case at its boundary and rejects one over it. Exercise actual focused and full commands on source, tests, and gate code; assert the violated rule and location reach the caller. Verify stricter rules and actual coverage. For dependency-sensitive caches or affected-test selection, change an imported dependency and confirm stale results cannot hide a violation.
- Exercise the requested host's edit events, paths with spaces or option-like names, repository-boundary violations, malformed input, failed startup, shell edits followed by Stop, and a committed clean tree. For Codex, include multi-file patches, renames, deletions, and broader-check fallback. Assert selected commands and diagnostic causes. Repeat setup to verify hook composition and idempotency.
- Prove a failed Stop continues the agent and repeated failure ends with a visible incomplete result. Check interruption cleanup and that verification does not recursively invoke itself.
- For a new loop, measure constituent checks before wiring them. Plant a failure and prove it propagates through the gate, adapter, and configured hook; restore the fixture and run final required checks. Preserve these cases as small re-runnable checks using existing test tooling. Test observable behavior, not implementation details or instruction wording.
- Report concisely: commands and execution points, ceilings and counting options, calibration evidence and limits, coverage gaps, timings, failures, skips, and hook activation evidence. Separate observations from unresolved assumptions. Required red or unrun checks leave the task incomplete; label unexercised lifecycle behavior unverified. Adapter tests do not prove hook activation, and green checks do not prove universal correctness or optimality.
- For installation of the skill itself into Codex, validate `SKILL.md` and confirm it appears enabled in Codex's `/skills` or `skills/list` from the target directory. Codex supports symlinked folders under `~/.agents/skills`; preserve one source when sharing with Claude. Restart the CLI if its picker is stale. See [OpenAI's skill discovery documentation](https://learn.chatgpt.com/docs/build-skills#where-to-save-skills).
