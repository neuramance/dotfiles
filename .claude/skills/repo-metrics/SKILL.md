---
name: repo-metrics
description: Report a repository's packed token count, cloc language breakdown, and embedded StyleX definition lines when explicitly invoked.
---

# Repo Metrics

Run `bun install --cwd <this skill directory> --frozen-lockfile`, then `node <this skill directory>/scripts/repo-metrics.mjs`, passing the user's directory as the script's sole argument when provided. With no directory argument, the script analyzes the current Git repository or current directory.

Return the script's stdout exactly, without an introduction, explanation, code fence, or conclusion. If it exits nonzero, return its single error line exactly.
