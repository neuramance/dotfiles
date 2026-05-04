#!/usr/bin/env python3
"""
worktree_guard.py — PreToolUse hook for Edit / Write / NotebookEdit.

PURPOSE
    When a Claude Code session is running inside a git worktree (i.e. its cwd
    contains `.claude/worktrees/`), every file edit must land inside that
    worktree. This hook exists because Claude has, in the past, taken absolute
    paths from tool results or subagent reports that pointed at the main
    checkout and written to them directly — silently leaving the worktree
    empty and polluting main. A worktree is supposed to isolate work; writing
    outside it defeats the whole point.

BEHAVIOR
    Reads the PreToolUse JSON payload on stdin, extracts `tool_input.file_path`,
    and:

    - exits 0 (allow) when the session is NOT inside a worktree
    - exits 0 when the tool call has no file_path
    - exits 0 when file_path resolves inside the current worktree
    - exits 0 when file_path is in one of the allowlisted harness paths:
          ~/.claude/           — plans, memory, skills, settings, hooks
          /tmp/, /private/tmp/ — scratch files
          /var/folders/        — macOS tempfile module default
    - exits 2 (block) with an explanatory stderr message otherwise.
      Exit code 2 is a hard block: it runs BEFORE permission rules are
      evaluated, so it cannot be bypassed by allow rules nor by
      --dangerously-skip-permissions.

CONFIG
    Wired up in ~/.claude/settings.json under hooks.PreToolUse with matcher
    `Edit|Write|NotebookEdit`. To disable temporarily, comment the hook out
    via the /hooks menu or remove the entry from settings.json.

INPUT
    The harness pipes this JSON on stdin:
        { "tool_name": "Edit", "tool_input": { "file_path": "...", ... }, ... }

EXIT CODES
    0 — allow the tool call
    2 — block the tool call (stderr message is shown to Claude for retry)

CHANGELOG
    2026-04-08  Initial version. Added after the Linear theme refactor, during
                which edits meant for a worktree accidentally landed on main.
"""

from __future__ import annotations

import json
import os
import sys


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        # Malformed payload shouldn't block tool use — fail open.
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""

    cwd = os.getcwd()
    if ".claude/worktrees/" not in cwd or not file_path:
        return 0

    abs_path = os.path.abspath(file_path)
    home = os.path.expanduser("~")
    allowed_prefixes = (
        cwd + os.sep,
        home + "/.claude/",
        "/tmp/",
        "/private/tmp/",
        "/var/folders/",
    )
    if abs_path == cwd or abs_path.startswith(allowed_prefixes):
        return 0

    sys.stderr.write(
        f"blocked: {abs_path} is outside worktree {cwd}. "
        f"You are inside a git worktree — edits must stay under the worktree "
        f"root (or ~/.claude/, /tmp, /var/folders). "
        f"Retranslate the path and retry.\n"
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
