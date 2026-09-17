---
name: git-sync
description: Pull remote changes, sync Git and GitHub state, and fix verified repository integration problems. Use for requests such as "pull all remote changes" or "sync this repo and get everything correct." Scope optimization to synchronization and repository health; ordinary feature work and general refactoring are separate tasks.
---

# Git Sync

Bring the requested checkout up to date, preserve existing work, and verify its resulting Git and GitHub state. Use Git and the authenticated `gh` CLI; an available GitHub connector can supply missing read access. No plugin is required.

## Scope and authorization

Default to the current repository and branch. "All remote changes" means fetch every configured remote and integrate the current branch's intended upstream; it does not mean merge every remote branch, switch to the default branch, or update every worktree. Expand only when the user's request names a wider scope.

A pull/sync request authorizes safe local integration, necessary conflict resolution, and focused fixes for demonstrated integration or verification failures. Preserve prior authorization. Pushes, GitHub PR creation or merging, remote branch deletion, CI reruns, deployments, and settings changes need authorization from the actual request or conversation; this skill supplies none. Do not turn "optimal" into unrelated refactoring, dependency upgrades, cleanup, or new CI/documentation.

## Establish the starting state

- Read applicable `AGENTS.md`, shared-worktree rules, and verification instructions. Inspect repository scripts and hooks before running commands that can trigger them.
- Identify the repository root, current branch or detached HEAD, starting commit, upstream, remotes and fetch refspecs, worktrees, staged/unstaged/untracked work, and any merge, rebase, cherry-pick, or other operation in progress. Keep remote credentials out of output.
- Use `git status --short --branch`, `git worktree list --porcelain`, and branch/upstream inspection. Record enough baseline state to verify preservation; do not dump private file contents.
- Do not take over another session's operation, remove lock files, or mutate another worktree's checkout. Recheck HEAD and local changes immediately before integration; concurrent movement invalidates earlier decisions.

## Fetch and choose the integration target

Fetch explicitly before integrating so configured `pull.rebase` or autostash cannot silently choose the workflow. For ordinary remote-tracking refspecs, use `git fetch --prune --no-prune-tags <remote>` for each configured remote, checking each result. Inspect unusual refspecs and pruning settings first: pruning can delete local tags when tags are explicitly mapped. Do not prune tags or local branches, or update other worktrees' branch refs through mirror/custom mappings; use safe explicit remote-tracking destinations when needed. Honor deliberate remote exclusions and report them.

Use the configured upstream unless the user specified a different target. If it is absent or gone, inspect branch configuration and the remote default branch. Infer a target only when the requested branch and remote mapping establish it unambiguously. Detached HEAD, competing remotes, deleted upstreams, or an unexpectedly rewritten upstream require resolving the actual intent before moving the checkout. Do not silently replace the upstream with `origin/main`.

A failed fetch is not proof of freshness. Continue independent inspection and successful remotes, but do not integrate stale refs from a failed remote or report a complete sync. Diagnose authentication/network errors without changing credentials or remotes speculatively.

Resolve the target to a commit and inspect `git rev-list --left-right --count HEAD...<target>`; the counts are local-only, then upstream-only. If shallow history prevents proving ancestry, deepen the relevant history before classifying divergence; never bypass unrelated-history checks. Inspect the incoming changes before integration, including changed instructions, dependency locks, submodules, and verification scripts.

| Local-only | Upstream-only | Action |
| --- | --- | --- |
| 0 | 0 | Already aligned; verify health without manufacturing changes. |
| 0 | Positive | Fast-forward using `git -c merge.autostash=false merge --ff-only <target>`. |
| Positive | 0 | Preserve local commits; report that the branch is ahead. Do not reset or push merely to make counts zero. |
| Positive | Positive | Inspect both histories and the repository's integration policy before reconciling. |

For divergence, honor an established merge/rebase/fast-forward-only policy. Otherwise prefer a history-preserving merge for ordinary shared history. Rebase only when policy or the user calls for it and the affected commits are confirmed unpublished; never rewrite published history automatically. Inspect force-updates before merging so removed upstream commits are not accidentally resurrected. Resolve only conflicts whose intended behavior is supported by code, tests, and requirements; ask a concise question when a material choice remains. Never choose ours/theirs wholesale to make conflicts disappear. Local merge commits required by the chosen integration are distinct from unrelated or WIP commits.

## Preserve work while integrating

A dirty tree is not automatically a blocker: a fast-forward can preserve non-overlapping edits. Verify paths and staging before and after, disable autostash, and let Git refuse overwrites. Do not force past a refusal. Avoid history-changing integration with unfinished edits in the same tree.

When edits overlap or another session owns the checkout, use an isolated temporary worktree for investigation, conflict preparation, or verification where useful. That work does not mean the original checkout is synchronized. Do not automatically stash, commit, clean, reset, restore, delete branches, or discard files to obtain a clean status. Retain existing stashes and unrelated staged changes. If completing integration depends on ownership or an unresolved content decision, finish independent checks and state precisely what input is needed.

Hydrate pinned dependencies, LFS objects, or submodules only when the incoming change and repository workflow require it. Preserve dirty submodules; do not advance submodules with `--remote`. Use the existing package manager and lockfile. Never run shared-database migrations or resets as routine sync verification.

## Check GitHub and repository health

- Resolve the GitHub host and owner/repository from the relevant remote, including fork/base relationships. Use explicit repository/host targeting for `gh`; do not assume the current directory's default points at the PR base.
- Inspect the current branch's PR when one exists and relevant CI for the synchronized branch. Read base/head branches, head commit, mergeability, required checks, and review status as needed. Unrelated open PRs are not automatic integration candidates.
- Match check results to the relevant commit or PR test-merge commit. Distinguish failures, cancellations, pending, skipped, stale, and unavailable results. No checks or unavailable protection data mean unknown, not green. Local success does not clear a failed or cancelled GitHub check.
- Run the repository's prescribed routine sync/fast checks and behavior-focused checks warranted by incoming changes or repairs. Inspect the entire integrated range and final diff, not just the last commit. Follow the repository's local-versus-CI split; do not recreate its full release pipeline on every sync. Reuse verified results only when their commit, working-tree content, and relevant environment still match.
- Fix demonstrated failures within the requested scope and rerun affected checks. Distinguish existing defects, integration regressions, missing prerequisites, and external outages. Never weaken a gate, bypass hooks, or change CI/settings to manufacture success. Escalate an unrelated defect that would expand the task substantially.

Before an authorized push or PR merge, inspect current protection/rulesets and required checks, verify the exact outgoing commits and destination, and honor hooks. Fetch again if concurrent remote movement is plausible; use a normal explicit push and reconcile any rejection. Never force-push as part of this workflow. Prepare and verify the local result before asking for any missing publication authorization; do not ask again for authorization already given.

## Verify and report the final state

Recheck branch, HEAD, upstream relationship, dirty/staged/untracked state, and unfinished operations. Confirm pre-existing work survived and account for any temporary worktree or recovery state created. A verification run in another tree does not establish the state of the user's checkout.

Report concisely: what was fetched and integrated, the resulting branch/commit and ahead/behind counts, relevant fixes, checks actually run with results and limits, preserved local work, and any GitHub or authorization blocker. Distinguish "up to date with the fetched upstream" from "verified healthy." Do not call a red or unverified gate complete, claim everything is optimal, or repeat passed checks without a new reason.
