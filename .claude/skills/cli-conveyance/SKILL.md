---
name: cli-conveyance
description: "Build the interface conveyance for a CLI tool so coding agents invoke it correctly: a compact tool skill, a machine-readable schema when you own the tool, and live-binary introspection otherwise. Use when asked to document a CLI for agents, make a CLI agent-friendly, write a skill for a command-line tool, or add a schema or manifest command. Do not use for MCP server development or human-facing documentation."
disable-model-invocation: true
---

# CLI Conveyance

Optimize the product of three factors: minimum tokens in always-loaded context, maximum probability that the next invocation is correct, and zero hangs or double-applied mutations. Completeness is not the objective; complete references are how man pages fail. Every claim in a conveyance either derives from the installed binary or gets deleted.

## Decision table

| Situation | Build |
|---|---|
| Tool already in model priors (`git status`, `rg`, `tar`) | Nothing except project-specific deviations |
| Third-party CLI, small | One skill: live `--help` procedure, 3–6 examples, danger flags |
| Third-party CLI, huge (`git`, `kubectl`, `aws`) | Skill plus per-subcommand reference files, snippets only |
| CLI you own | Change the product first, then a thin skill over the machine contract |
| No local argv program exists (authenticated SaaS, DB session, long-lived resource) | MCP server |

## The four contracts

Every conveyance covers these four; the execution contract prevents the worst failures (hangs, double-applied mutations, argv retry loops), so never ship without it.

1. Execution contract: non-interactive behavior, TTY rules, exit-code meaning with retry-safety and side effects, confirmation flags.
2. Invocation grammar: subcommands, typed flags, defaults, mutual exclusivity, requiredness.
3. Output contract: stdout carries data, stderr carries diagnostics, JSON when available.
4. Worked examples: 3–6 real invocations of the common path. Examples condition models more strongly than option catalogs; treat this as a strong heuristic and keep the full grammar demand-loaded.

## Procedure: third-party CLI

The source of truth is the installed binary, never a vendored man page or web docs.

1. `command -v tool`, then `tool --version`; record the version in the skill.
2. Read `tool --help`, then `tool <cmd> --help` for each subcommand the skill covers. Read to extract; do not paste.
3. Identify mutation commands and their guards (`--yes`, `--force`, `--dry-run`) from help, then probe the execution contract; never assert it from help text, which describes the interactive path agents do not run. Probe read-only paths, eliciting errors with obviously invalid IDs and `</dev/null`. Probe a guarded mutation only when the invocation cannot succeed — obviously invalid target ID, `</dev/null`, no content or confirmation supplied — to capture its refusal and exit code; never run one that could succeed. Compare stdout and stderr on one successful command; streams may mirror. Every prompt, editor, hang, stream, and exit-code claim comes from a probe or carries a help-derived label.
4. Identify commands that print credentials; forbid them in the skill.
5. Write the skill from the template below, at or under 80 lines. The skill teaches the discovery procedure; it does not replicate the reference.
6. For huge tools, add `references/<subcommand>.md` one level deep, loaded only on demand. Extract man-page sections with targeted snippets, never whole pages: `man bash` measures ~73k tokens; a targeted snippet measures 1.6–2.9k.
7. Verify before shipping: the frontmatter parses, the file is at or under 80 lines, and every execution-contract line is probe-backed or labeled help-derived.

## Procedure: CLI you own

Documentation cannot fix a human-only binary. Change the product first, per clispec.dev and cli-agent-spec.github.io:

1. Add `tool schema` (or `tool manifest --output json`) emitting the full command tree: args, types, defaults, exclusivity, effects, error kinds. Generate it from the parser (walk clap's command tree or use clap_describe; Cobra's command tree; Click or Typer introspection). Never hand-write it; hand-written schemas drift.
2. The schema command must succeed with no auth, no config file, no network.
3. Add `--output json` to data commands.
4. Never require a TTY; refuse with a named error instead of prompting or hanging.
5. Guard mutations with `--yes` and offer `--dry-run`.
6. Declare exit codes with retryable and side-effect meaning per code.
7. Point `--help` at `schema`.

The skill then reduces to a thin procedure: run `tool schema`, obey the effects declarations.

## Packaging

| Agent | Global | Per project |
|---|---|---|
| Claude Code | `~/.claude/skills/<tool>/SKILL.md` | `.claude/skills/<tool>/SKILL.md` |
| Codex | `~/.codex/skills/<tool>/SKILL.md` | `AGENTS.md` pointer to the skill file |

Always-on files (`CLAUDE.md`, `AGENTS.md`) carry at most a pointer and invariants, under 5 lines, zero flag tables:

```md
## CLI: foo
Use the foo skill. Do not guess flags.
Discover: `foo schema` if present, else `foo <cmd> --help`.
Prefer `--output json`. Pass secrets via stdin or env, never argv.
```

Reference files sit beside the skill in `references/`, one level deep, demand-loaded.

## Skill template

```md
---
name: foo-cli
description: "Operate the foo CLI for env, deploy, and log tasks. Use when the task mentions foo, fooctl, deployments, or preview environments."
---

# foo

Binary: `foo`. Run `foo --version` first; written against <probed version>.
Source of truth: `foo schema` if it exits 0, else `foo <cmd> --help`.

## Contract
- Non-interactive. If a command would prompt, abort; add `--yes` only for user-authorized mutations.
- stdout is data, stderr is diagnostics. Prefer `--output json`.
- Run `--dry-run` before any destructive command that supports it.

## Effects
| command | effects | confirm |
|---|---|---|
| foo env list | read_only | no |
| foo env set | idempotent | no |
| foo deploy | non_idempotent | --yes |
| foo env delete | non_idempotent | --yes |

## Grammar (common path)
foo env list [--output json]
foo env set <KEY> <VALUE>
foo deploy <service> [--env NAME] [--yes]
foo logs <service> [--since 1h] [--output json]

## Exit
0 ok
2 usage error: reread help for that subcommand, never retry the same argv
4 conflict: inspect state before retrying
10 confirmation required: missing --yes

## Don't
- Don't load references/ unless the grammar above is missing a flag
- Don't run deploy or delete without `--yes` and user authorization
- Don't trust man pages over this binary's `--help`
```

Adapt the effects and exit tables to what the tool declares or what probing showed; delete any row you cannot verify.

## MCP boundary

A CLI is already a tool-calling interface: argv in, exit code plus stdout and stderr out. Wrap a capability in MCP only when no local argv program can exist: authenticated SaaS, a live DB session, a long-lived stateful resource. State the costs precisely: MCP tool schemas enter every request; prompt caching cuts the repeated token cost roughly 10× but the context-window occupancy remains. Measured overheads reach 17× (search API) and 35× (Intune) on stateless single-call tasks, while some multi-turn workflows measure near parity. Decide by capability, not token dogma, and never use MCP to re-describe a binary already on PATH.

## Format

YAML or tight Markdown for model-facing text; JSON from `schema` for validators and tooling. Per clispec.dev: "Markdown and YAML use significantly fewer tokens for LLM consumption."

## Anti-patterns

- A full man page anywhere in loaded context
- MCP wrappers around local binaries
- Flag tables or encyclopedic references in `CLAUDE.md` or `AGENTS.md`
- Hand-written schemas that drift from the parser
- Reference trees more than one level deep
- Secrets on argv
- Retrying an unchanged argv after a usage error
