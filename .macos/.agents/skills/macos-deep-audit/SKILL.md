---
name: macos-deep-audit
description: Perform a comprehensive, evidence-driven, read-only audit of this Mac against this repository's declared desired state. Use for macOS performance, storage, background software, developer-tooling, reliability, configuration, or overall health audits; do not use for remediation-only requests.
---

# macOS Deep Audit

Determine whether any change would materially improve this Mac without inventing work. A healthy result with no recommended changes is valid.

## Authority and scope

1. Locate the repository root containing `README.md` and `audit.sh`.
2. Read `README.md` completely before interpreting the machine. It defines desired state, intentional exceptions, declined alternatives, and accepted risks.
3. Inspect `audit.sh`, then run it once before expensive diagnostics. A nonzero exit means prescribed coverage was unavailable, not that the Mac is unhealthy.
4. Treat current machine evidence as authoritative for observed state and `README.md` as authoritative for intended state. Report conflicts as drift; never silently choose which side to change.
5. Do not write dated reports or observations into the repository. Respond in the conversation.

Classify policy-related conclusions as one of:

- **MATCHES DESIRED STATE**
- **DESIRED-STATE DRIFT**
- **ACCEPTED RISK**
- **OBSERVED ANOMALY**
- **UNKNOWN / INACCESSIBLE**

Do not recommend an option that `README.md` explicitly declines. If new evidence materially changes the stated tradeoff, identify the evidence and ask whether the desired state should be reconsidered.

## Audit boundary

The audit is diagnostic. Do not remediate, modify repository or system files, change settings, install or update software, clean caches, delete or move data, change permissions, terminate processes, unload services, prune containers, alter snapshots, repair filesystems, reboot, or create persistent jobs.

Use nonprivileged, local, read-only diagnostics by default.

- Do not use `sudo`. If material evidence genuinely requires it, first present the exact command, what it reads, why privilege is required, whether it can persist changes, why the evidence matters, and the lower-privilege alternatives. Wait for approval.
- Do not contact Apple, package registries, vendors, or other network services without explaining the command and side effects and receiving approval.
- Do not start a stopped application, service, container daemon, VM, simulator, database, or indexer to inspect it.
- Do not run CPU, GPU, disk-write, thermal, or network benchmarks during the initial audit.
- Treat sandbox, TCC, SIP, and permission denials as unknown coverage, never as absence.
- Validate uncertain command syntax against the installed macOS tools before relying on it.

Do not read or expose Keychain contents, credentials, passwords, browser history, cookies, private keys, tokens, `.env` files, complete environment dumps, messages, mail, notes, contacts, photos, personal documents, source secrets, or unrelated application databases. Use aggregate sizes and metadata. Redact usernames, hostnames, addresses, tailnet names, serial numbers, UUIDs, fingerprints, and private paths from reported evidence.

## Evidence standard

Prefer, in order:

1. direct measurement from this Mac;
2. corroborating local measurements;
3. locally installed documentation applicable to this release;
4. official Apple or vendor documentation, only when approved network access is necessary.

For every material conclusion distinguish:

- **OBSERVED FACT** — directly measured;
- **SUPPORTED INFERENCE** — strongly implied by multiple facts;
- **HYPOTHESIS** — plausible but unproved;
- **UNKNOWN / NOT MEASURABLE** — unsupported or inaccessible.

Use High, Medium, or Low confidence and Critical, High, Medium, Low, or Negligible impact. Unusual is not equivalent to harmful. Do not invent temperatures, SSD life, recoverable bytes, performance percentages, boot duration, throttling, or battery metrics.

Maintain a compact evidence ledger with the source, observation time, material result, measurement status, confidence, and unresolved question. Preserve failed commands and stderr as coverage evidence without flooding the report with raw output.

## Adaptive workflow

### 1. Desired-state check

Run `./audit.sh`, inspect every section, and compare results with `README.md`. Resolve apparent contradictions with stronger local evidence when possible. Record unavailable checks.

### 2. Lightweight baseline

Before storage scans, establish the supported hardware, architecture, memory, internal storage, APFS capacity, macOS build, kernel, uptime, boot timestamp, shell, battery/power, storage health indicator, security controls, management state, backup configuration, package managers, developer tools, and container platforms.

Do not confuse uptime, boot timestamp, boot duration, login timestamp, and login duration.

### 3. Live performance

Take more than one short sample and record the observation window.

- CPU: total idle/user/system activity and repeated consumers.
- Memory: pressure, used/wired/compressed memory, swap amount and activity, and large consumers.
- I/O: interval disk activity before recursive storage analysis.
- Power: supported thermal-pressure state, assertions, sleep blockers, and active workload on the current power source.

Control observer effects. Terminal rendering can inflate terminal and WindowServer CPU; the audit's own scanning can inflate I/O and indexing.

### 4. Progressive storage analysis

Start with APFS/container and broad allocated usage, then inspect only significant independent categories. Avoid network mounts, external backup destinations, protected personal data, and cloud-placeholder trees.

Account for APFS clones, hard links, sparse files, snapshots, shared Docker layers, package stores, and purgeable-space semantics. Do not equate logical size with recoverable space or sum overlapping paths. Use an authoritative native dry run when one already exists and is read-only; otherwise state that physical recovery is unknown.

Classify material storage as system-required, user data, active application data, active developer data, regeneratable, cache, archival, possibly abandoned, cleanup candidate, user decision, or do not touch.

### 5. Background software and applications

Correlate Background Task Management registrations, LaunchAgents, LaunchDaemons, loaded state, processes, extensions, ownership, parent application presence, and measured CPU/memory impact. Do not label an item unnecessary or orphaned from its name alone. Do not treat framework choice, helper multiplicity, Rosetta, or virtualization as a defect without measured harm.

Inspect installed applications and substantial support directories conservatively. Use bundle identifiers, receipts, signatures, service labels, or vendor ownership to corroborate leftovers. Treat last-used metadata as a weak heuristic.

### 6. Developer environment

Inspect only present ecosystems: Homebrew, language runtimes and version managers, global packages, caches, shell/PATH, Command Line Tools or Xcode artifacts, Git stores, containers, and VMs.

Suppress package-manager auto-update and analytics for the process. Do not run an update, upgrade, cleanup, prune, removal, or ambiguous doctor command. A dry run is evidence only after its local help confirms it is non-mutating.

Measure shell startup only after determining that initialization will not contact services or modify persistent state. Restrict environment inspection to known non-secret variables.

### 7. Targeted health investigation

Go deeper only where earlier evidence supplies a reason. Use bounded, targeted queries for Spotlight, crash/panic metadata, sleep/wake, filesystem/storage errors, update history, network configuration, extensions, and compatibility. Errors in ordinary logs are not findings without recurrence, correlation, or operational impact.

Do not query available software updates, run filesystem verification or repair, rebuild indexes, perform active network tests, or decode sensitive diagnostic contents without separate justification and approval.

### 8. Correlation and stop condition

Investigate shared causes rather than isolated symptoms. Examples:

- Substantial swap requires correlation with uptime, pressure, compression, current consumers, and active swap I/O.
- Low free storage requires independent category accounting, snapshots, and realistic recoverability.
- Startup overhead requires registrations, loaded state, runtime processes, and measured impact.
- High CPU requires repeated samples, workload ownership, I/O, indexing/syncing, and supported thermal state.

Stop drilling into categories that are healthy and low-value. Do not optimize for command count or the number of recommendations.

## macOS interpretation invariants

- Low free RAM is not a problem when pressure and responsiveness are healthy.
- Compression is normal; accumulated swap can reflect earlier workload.
- Cache deletion sacrifices cached work and is not a performance improvement by itself.
- A sparse disk's logical capacity is not consumed physical storage.
- Time Machine local snapshots are system-managed, not automatic cleanup candidates.
- Multiple helpers, Electron, Chromium, Java, Rosetta, VMs, and system extensions require measured impact before criticism.
- Do not disable Spotlight, swap, SIP, Gatekeeper, FileVault, Secure Boot, power management, or useful Apple services for generic optimization.
- Do not recommend RAM cleaners, one-click optimizers, undocumented `defaults` or `sysctl` tuning, generic resets, `trimforce`, or routine repair operations.

## Final report

Lead with the outcome. Include only evidence-supported findings and keep normal results concise.

1. **Executive Summary** — overall health plus applicable performance, memory, storage, background, power, developer, configuration, reliability, and security ratings: Excellent, Good, Fair, Needs Attention, Critical, or Insufficient Evidence.
2. **Desired State** — matches, drift, accepted risks, and unknown coverage. Put drift before generic advice.
3. **Mac Baseline** — concise table of supported hardware, software, storage, power, and security facts.
4. **Findings Ranked by Expected Value** — observed evidence, interpretation, importance, impact, confidence, recommended action, risk, reversibility, expected benefit, conservative storage recovery, and workflow dependencies.
5. **Storage Reclamation** — independent candidates with measured allocation or logical size, conservative physical recovery, regeneratability, safety, and recommendation. Include explicit do-not-touch items.
6. **Background Software** — owner, purpose, registered/loaded/running state, measured impact, parent presence, confidence, and recommendation.
7. **Performance Bottlenecks** — only supported bottlenecks, with the affected dimension. State clearly when none exist.
8. **Configuration Improvements** — current and proposed state, evidence, benefit, downside, risk, and reversal.
9. **Healthy / Normal macOS Behavior** — facts that prevent harmful over-optimization.
10. **Things Not To Do** — tempting but harmful or worthless actions specific to the observed Mac.
11. **Audit Completeness Matrix** — each major area, evidence quality, material finding, and limitation.
12. **Prioritized Action Plan** — high-value/low-risk, optional, workflow-dependent, leave alone, and separately approved diagnostics.

End after the report. State that no remediation was performed and wait for the user to select any action. Before a later approved remediation, show the exact action, scope, benefit, downside, privilege/network/restart/deletion requirements, affected items, conservative storage recovery, rollback, and verification procedure.
