---
name: ntn
description: "Operate the ntn Notion CLI to read, create, edit, and trash Notion pages, query data sources, upload files, and call the public Notion API. Use when the task mentions Notion, ntn, Notion pages, databases, or data sources."
---

# ntn

Binary: `ntn`. Run `ntn --version` first; written against 0.21.6.
Source of truth: `ntn <cmd> --help`; help embeds worked examples. No schema command.
API long tail: `ntn api ls` lists endpoints, `ntn api <path> --spec` prints a reduced OpenAPI fragment, `--docs` the full endpoint docs. Read those instead of guessing request shapes.

## Contract
- Auth precheck: `ntn whoami` exits 0 when authenticated. Never run `ntn login`; hand auth to the user.
- Non-interactive sessions do not hang (probed): missing confirmation or content refuses with a named error and hint; $EDITOR opens only in an interactive TTY.
- `pages create` and `pages edit` read Markdown from `--content` or stdin; a stray stdin redirect becomes page content, so pass `--content` or an explicit file.
- `ntn api` infers the HTTP method: GET by default, POST once `--data` or inline body fields are given, `-X` always wins (help-derived; probed that empty stdin stays GET).
- Output may mirror to both streams (probed: `whoami` writes identical bytes to stdout and stderr); errors print `error: ...` plus a recovery hint on stderr. Read stdout; prefer `--json`; `--plain` gives headerless TSV.
- The token lives in the keychain or `NOTION_API_TOKEN`; never place it on argv, never print it.

## Effects
| command | effects | confirm |
|---|---|---|
| ntn whoami / doctor | read_only | no |
| ntn pages get | read_only | no |
| ntn datasources query / resolve | read_only | no |
| ntn files list / get | read_only | no |
| ntn api GET endpoints, ls, --spec, --docs | read_only | no |
| ntn pages create / edit, files create | non_idempotent | explicit user request |
| ntn api with --data, inline body, or -X | per endpoint method | explicit user request |
| ntn pages trash | non_idempotent | --yes |
| ntn logout / update | state_changing | explicit user request |

## Grammar (common path)
ntn whoami [--json|--plain]
ntn pages get <page-id> [--json]
ntn pages create --parent data-source:<id> --content '# Title' [--json]
ntn pages create --parent page:<id> < page.md
ntn pages edit <page-id> --content '# Updated body'
ntn pages trash <page-id> --yes
ntn datasources resolve <database-id> [--json]
ntn datasources query <data-source-id> [--limit N] [--start-cursor <cursor>] [--filter '<json>'] [-s '<prop> [asc|desc]'] [--json]
ntn api <path> [INPUT...] [-d <json|@path|@->] [-X <METHOD>]

Parent targets: `page:<id>`, `database:<id>`, `data-source:<id>`. `query` takes a data-source ID, never a database ID; resolve first (probed hint).

## Exit
0 ok
1 confirmation refused in a non-interactive session: add `--yes` only for a user-authorized mutation
2 usage error: reread `ntn <cmd> --help`, never retry the same argv
5 runtime error (unknown or unshared ID, missing content): follow the stderr hint, add `-v` for source chains

## Don't
- Don't run `ntn auth token`; it prints the live credential
- Don't run bare `ntn pages create` or `ntn pages edit`; pass `--content` or pipe stdin
- Don't pass `--allow-deleting-content` to `pages edit` without explicit user authorization to delete child pages or databases
- Don't trash pages without `--yes` and user authorization
- Don't guess API request bodies; read `ntn api <path> --spec` first
- Don't run `ntn update`, `ntn login`, or `ntn logout` unless the user asks
