---
name: m4-audit
description: Audit m4, the M4 Max MacBook Pro all work happens on, for CPU, energy, memory, battery, disk, security, and hygiene from measured evidence, explain what Activity Monitor shows, fix verified defects the request authorizes, and report what needs a decision. Use for requests such as "why is Docker using so much energy", "what is eating CPU or memory on my Mac", "is anything draining the battery or taking too much space", or "audit, clean up, or optimize m4".
---

# m4 audit

Produce an evidence-backed account of what on m4 is broken, at risk, or wasteful, starting with what consumes CPU, memory, and energy; fix what the request authorizes; break nothing in use. Every claim cites an observation from this run. Label inferences, absences of evidence, and earlier observations as such.

## Scope and authorization

- A question ("why is…", "is anything…") authorizes inspection and a report. "Fix", "clean up", "address", or "optimize" authorizes the changes the decision table allows. Approval of one change does not extend to another class of change.
- Run on m4 itself. Agents and the user work on it while you audit, so recheck a target immediately before acting on it.
- `w` has no passwordless sudo. Never prompt for a password: when only root can supply the evidence, give the user the exact command to run as `! sudo …` and say what it will show. Unprivileged, `top`, `ps`, `netstat -anv`, and the diagnostic reports cover every process; `lsof` and `ps eww` cover only `w`'s.
- Observe without side effects. Never launch an app or run its internal daemons and helpers (its documented CLI, such as `docker`, is fine), never drive apps through `osascript` (it raises privacy prompts), and never query Docker's engine unless `docker desktop status` says `running`: an engine query can wake the VM that Resource Saver shut down.
- Never print secrets. Process environments hold tokens: read named keys only, never a pattern over a whole environment. Never print the contents of `~/.ssh`, `~/.aws`, `~/.zsh_secrets`, 1Password items, or Docker's proxy settings.

## 1. Collect

- Read `known-state.md` (host facts, baselines, the exposure baseline, accepted decisions) and, when present, `known-state.local.md` (open findings). They change how signals are judged.
- Run `scripts/snapshot.sh`: unprivileged, about 15 seconds, and it changes nothing of `w`'s (`softwareupdate -l` stamps the time of its own check). It samples CPU for 5 seconds before any other probe runs, then takes inventory. Every daemon, disk-scanning, or network call is bounded and prints `snapshot: … timed out after Ns` when the bound fires, because partial data reads as absence. It is the inventory, not the audit: follow each signal it raises with targeted commands until its cause is known.
- A 5-second sample shows what is busy now, not what is busy sometimes. For history use the AVG column, the diagnostic reports, `pmset -g log` for sleep, wake, and assertion history, and a longer sample of the suspects: `top -l 37 -s 5 -stats pid,cpu,mem,command -pid PID` covers the 3 minutes macOS uses for its own CPU limit (keep `command` last: names contain spaces). For a timeline of one process, read the unified log over a short window: `/usr/bin/log show --last 1h --style compact --predicate 'process == "NAME"'`.
- For a question about space, or a disk row over its threshold, attribute it with `du -xh -d 2 -t 1G ~ | sort -hr` (about a minute) and, when the engine runs, `docker system df`.
- Batch independent follow-up commands in parallel. macOS has no `timeout` command: give every command the Bash tool's timeout. In the Bash tool `log` is a zsh builtin and `ls` and `grep` are wrapped, so call `/usr/bin/log`, `/bin/ls`, and `command grep` when output is parsed.

## 2. Judge

A signal is a finding when it crosses these defaults. Explain a signal below them that is still unusual for this host.

| Area | Finding when |
| --- | --- |
| CPU and energy | A process tree at 10% of one core or more, now or on average, that serves nothing in use; anything at a full core or more for 3 minutes that the user did not start; the same process in two or more `cpu usage` or `wakeups` diagnostic reports within 7 days (each states the limit it crossed). On a laptop, CPU spent on nothing is a defect even without pressure: it is battery and heat. |
| Memory | Pressure level above 1, a `JetsamEvent` report for system memory pressure (a kill for a per-process limit is that process's defect), or swap growing during the audit. Used memory, low free memory, and swap in use are not findings: macOS fills memory with cache and compresses before it swaps. |
| Power and battery | Thermal pressure level above 0 or any warning `pmset -g therm` recorded; battery Condition other than Normal or Maximum Capacity below 80%, where AppleCare replaces a battery; more than 0.5% charge lost per hour asleep on battery; display sleep off (`displaysleep=0`) on battery; a sleep assertion held for hours, or by something not doing work the user wants. |
| Disk | The Data volume's APFS container at 80% used, or measured growth reaching 90% within 30 days (compare with the baseline in `known-state.md`); SMART status other than Verified; a write rate far above the baseline, since SSD wear itself is not measurable without `smartmontools`. |
| Services | A KeepAlive LaunchAgent not running; a LaunchAgent whose runs count grows during the audit (a restart loop) or whose nonzero exit recurs; a background item whose program is missing; a crash report recurring for one process; any panic. |
| Exposure | A TCP listener on a non-loopback address, or a UDP socket on a fixed non-loopback port, whose owner differs from the baseline; firewall, SIP, Gatekeeper, or FileVault off; a screen that never locks on its own (display sleep and screen saver both off); sshd accepting passwords while port 22 listens. |
| Updates | A pending update to the installed major macOS version or to Safari, which carry security fixes; automatic security updates off. A new major macOS version is a decision, not a finding. An outdated Homebrew package (`HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --verbose`) is a finding only when its installed version has a vulnerability that applies here. |
| Backups | No Time Machine destination and no other backup of the data recorded in `known-state.md`, or a latest backup older than 7 days. |
| Docker | The engine running with no container in use; a running container nothing uses; a container restarting, unhealthy, or OOM-killed; an image that is not arm64, which runs emulated. |
| Waste | Detached processes, stale worktrees, caches, unused images or volumes: a finding only when they hold CPU or a non-loopback listener, under pressure on their resource, or when they grow without bound. Reclaiming 20 GB from a disk at 35% gains nothing and risks something. |

## 3. Verify before concluding

Try to disprove each candidate finding before reporting or acting on it. When evidence contradicts an earlier claim, including one made earlier in the conversation, correct it explicitly.

- **In use or abandoned.** Every app, agent, and XPC service on macOS is a child of launchd, so a parent of 1 proves nothing. The snapshot marks `[detached]` only `w`'s processes under launchd that are outside app bundles, the OS, and launchd's own jobs. Walk the parent chain with `ps -o ppid=`. Evidence of use: established connections (`lsof -nP -a -p PID -i`, or `netstat -anv -p tcp` for sockets of other users); a live owning session (`ps eww -o command= -p PID | tr ' ' '\n' | grep -E '^(CLAUDE_PID|CLAUDE_CODE_SESSION_ID|TMUX_PANE|HERDR_PANE_ID)='`, then `ps -p` on that `CLAUDE_PID`); recent writes under its working directory (`lsof -a -p PID -d cwd -Fn`). A process that rewrites its title, such as `next-server`, no longer shows its environment: read its parent's.
- **Attributed or blamed.** Load in a system process is usually spent for something else. WindowServer composites every window, so its CPU follows whatever redraws on screen. Spotlight (`mds_stores`, `mdworker_shared`, `corespotlightd`, `spotlightknowledged`) indexes what changes on disk and in apps. `com.apple.Virtualization.VirtualMachine` runs a VM for an app, which `lsof -p PID` names through the disk image it holds. Activity Monitor's Energy Impact is a relative score that also weighs GPU and wakeups; `top`'s POWER column on this Mac only repeats %CPU. Unprivileged, `ioreg -r -c AGXDeviceUserClient -d 1 -w0` gives each GPU client's creator pid and running total `accumulatedGPUTime`, and `nettop -P -L 1 -x` each process's network bytes; sample twice for a rate. Per-process energy and disk I/O need root: ask the user to run `! sudo powermetrics --samplers tasks --show-process-energy --show-process-gpu --show-process-io -i 5000 -n 1`.
- **Docker.** Docker's load appears in three places: `com.docker.backend` (API, networking, file sharing), the VM (`com.docker.virtualization`, and the `com.apple.Virtualization.VirtualMachine` service that Apple's Virtualization framework runs the guest in), and the Docker Desktop UI. Find the container behind VM CPU with `docker stats --no-stream`, where 100% is one of the VM's CPUs. The VM's footprint counts guest page cache and memory the guest has not returned, up to `MemoryMiB`: compare it with the sum in `docker stats` before calling it a leak. While the engine is stopped, `docker ps` answers from the backend's cache without waking the VM, and the backend logs hold the history: in `~/Library/Containers/com.docker.docker/Data/log/host/com.docker.backend.log*`, `idlemetrics` lines give the VM's total compute time against its running time, and `backend.idle` lines show each wake, idle timer, and VM stop. `docker system df` counts every image without a container as reclaimable, including rollback tags and images run on demand.
- **Exposed or filtered.** The application firewall passes every app on its allow-list (`socketfilterfw --listapps`) and, while "allow signed software" is enabled, any signed app; stealth mode only hides closed ports. Treat a non-loopback listener as reachable from the local network unless the firewall blocks its program.
- **Counted or hidden.** AVG divides by wall-clock age, sleep included: scale it by the awake share in the host line, and remember a process that restarts often (Spotlight's) loses its history. `kernel_task` is the kernel itself (I/O, networking, memory management) and appears only in `top`. Activity Monitor's Idle Wake Ups is `top`'s IDLEW, a running total that advances in steps: take a rate over a minute or more, and use the `wakeups` reports for history. `du` cannot read privacy-protected folders (Photos, Safari, Mail, and others under `~/Library`) and prints `Operation not permitted` for them, so sizes under `~/Library` are lower bounds. `launchctl list` shows a negative status for a job killed by a signal, which for Apple's daemons is routine idle exit. A launchd runs count resets when the job is reloaded. Battery telemetry refreshes about once a minute, so one reading of system power is not a measurement of a short burst.
- **Quantified.** State sizes in absolute and percentage terms, CPU as a share of one core, and growth as a rate.

## 4. Decide

| Class | Examples | Action |
| --- | --- | --- |
| Verified, reversible defect in `w`'s files or settings | a LaunchAgent bug in the dotfiles, a background item left by an uninstalled app, a retention gap | Fix when the request authorizes fixes. |
| Interrupts work in progress | killing a process or quitting an app, stopping Docker or a container, changing Docker's CPU or memory limits (restarts its VM), installing updates, restarting | Ask, giving the evidence and the expected disruption. |
| Destroys data | Docker volumes, files that cannot be regenerated, local snapshots | Ask; never act on inference. |
| Security posture or outward-facing | FileVault, the firewall, sharing services, sshd, Tailscale, i9, GitHub, Cloudflare, software another organization requires | Report; act only on an explicit request. |
| Deliberate, or not worth it | listed in `known-state.md`; waste without pressure | Leave it, and say why. |

## 5. Fix

- Reproduce first, with a command whose only effect is to show the defect. The decision table governs reproductions too.
- Fix the cause at the layer that produces it: the agent's definition rather than its log, the setting rather than a one-off kill.
- Use the supported mechanism for that layer. `w`'s LaunchAgents are tracked in the dotfiles: edit the plist, then `launchctl bootout gui/$UID/LABEL` and `launchctl bootstrap gui/$UID PLIST`. Change an app through its own settings or CLI (`docker desktop`); never edit files inside an app bundle or under `/System`, and never edit Docker's `settings-store.json` while Docker runs, because it rewrites the file. A change that needs root or System Settings is the user's to make: give the exact steps.
- Rerun the same reproduction with a check that can fail, and report the counts before and after. Confirm the affected app or service still works.
- Record each lasting change in `known-state.md` with its date, reason, verification, and rollback. Changes to tracked dotfiles follow that repository's conventions.

## 6. Report

Lead with a one-sentence verdict, then:

1. Health: one row per area, with its numbers.
2. Findings, most severe first: claim, evidence, impact.
3. Changes made: what changed, before and after, rollback.
4. Left alone: each item and the evidence for leaving it.
5. Decisions needed: options and their costs.
6. Corrections to earlier claims.

Use absolute paths. Omit a section with nothing in it.

Then update the skill's memory, even when the request was only a question, since it is not part of the system: record each finding awaiting the user in `known-state.local.md`, and each decision that something is deliberate in `known-state.md`, with its date and evidence; delete entries whose subject is gone. The dotfiles repository is public and git ignores `known-state.local.md`: write any open weakness only there.
