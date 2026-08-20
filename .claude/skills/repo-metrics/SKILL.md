---
name: repo-metrics
description: Report a repository's Repomix token count and cloc language breakdown when explicitly invoked.
---

# Repo Metrics

Run `node <this skill directory>/scripts/repo-metrics.mjs`, passing the user's directory as its sole argument when provided. With no directory argument, the script analyzes the current Git repository or current directory.

Return the script's stdout exactly, without an introduction, explanation, code fence, or conclusion. If it exits nonzero, return its single error line exactly.
