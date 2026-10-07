---
name: i9-audit
description: Audit the i9 server's health, capacity, security, and hygiene from measured evidence, fix verified defects the request authorizes, and report what needs a decision. Use for requests such as "how is the server doing", "is anything taking too much space or resources", or "audit, clean up, or optimize i9".
---

# i9 audit

Produce an evidence-backed account of what on i9 is broken, at risk, or wasteful; fix what the request authorizes; break nothing in use. Every claim cites an observation from this run. Label inferences, absences of evidence, and earlier observations as such.

## Scope and authorization

- A question ("how is…", "is anything…") authorizes inspection and a report. "Fix", "clean up", "address", or "optimize" authorizes the changes the decision table allows. Approval of one change does not extend to another class of change.
- Run on i9. From another host, run the same commands through `ssh i9`.
- i9 is shared: act only on `w`'s processes, files, and the system configuration; report what belongs to other users. Other sessions change the machine while you work, so recheck a target immediately before acting on it.
- Never print secrets. Read single keys (`sudo netplan get ethernets.enp3s0`) rather than whole files from `/etc/netplan`, `/etc/cloudflared`, restic configuration, or environment files, and never print their values.

## 1. Collect

- Read `known-state.md`: host facts, the exposure baseline, accepted decisions, and open findings. They change how signals are judged.
- Run `scripts/snapshot.sh`: read-only, about 10 seconds, every daemon or filesystem call bounded by `timeout -v`, which prints a line when it fires. It needs passwordless `sudo -n` and stops without it, because partial data reads as absence. It is the inventory, not the audit: follow each signal it raises with targeted commands until its cause is known.
- For history behind a current reading, such as a past load spike, read `sar` (sysstat samples every 10 minutes): `sar -q`, `sar -r`, `sar -d`.
- Batch independent follow-up commands in parallel. Give every command a timeout.

## 2. Judge

A signal is a finding when it crosses these defaults. Explain a signal below them that is still unusual for this host.

| Area | Finding when |
| --- | --- |
| Pressure | PSI `some avg60` above 10% for memory or io, `some avg300` above 25% for cpu, or any `full avg60` above 1%. Load average and `ps %cpu` (a lifetime average) are not pressure. |
| Memory | Available below 15% of total. `/tmp` is RAM: project its growth over its 10-day retention. Swap in use is not a finding; memory pressure is. |
| Disk | Space or inodes at 80% on any real filesystem, or a measured growth rate reaching 90% within 30 days. NVMe `critical_warning` not 0, `media_errors` above 0, `available_spare` at or below its threshold, `percentage_used` at 80%, or `unsafe_shutdowns` above its recorded baseline. |
| Services | A failed unit, nonzero `NRestarts`, a timer's service whose last `Result` is not `success` or that is stuck `activating`, an expected timer with no next run, or a container unhealthy, restarting, restarted, or OOM-killed. |
| Logs | Any recurring source in the journal summary, at any priority: a real fault, or noise that hides real faults; both are defects. Any kernel fault signature. A previous boot that did not end with `Journal stopped`, which means a crash or power loss. |
| Exposure | A listener, ufw rule, or `DOCKER-USER` DROP count that differs from the baseline, or ufw inactive. |
| Updates | Pending security updates, a required reboot, `NEEDRESTART-KSTA` 2 or 3 (a newer kernel is installed), or services under `NEEDRESTART-SVC`. |
| Waste | Detached processes, unused images or volumes, stale worktrees, caches: a finding only under pressure on that resource or when it grows without bound. Reclaiming 3 GB from a disk at 4% gains nothing and risks something. |

## 3. Verify before concluding

Try to disprove each candidate finding before reporting or acting on it. When evidence contradicts an earlier claim, including one made earlier in the conversation, correct it explicitly.

- **In use or abandoned.** Detached (reparented to init) means the launcher exited, not that the process is unused; a missing tty means nothing, because agent shells have none. Walk the parent chain with `ps -o ppid=` up to PID 1, not `pstree | head`. Evidence of use: established connections in the listener table, refreshed with `sudo ss -tniO state established '( sport = :PORT )'` and read through `lastsnd`/`lastrcv`; a live owning session (`CLAUDE_CODE_SESSION_ID` and `HERDR_PANE_ID` in `/proc/PID/environ`, compared with live sessions); recent writes under its working directory. Zero connections does not prove disuse: tailnet clients reach Docker-published ports through NAT, which host sockets never show. A docker scope in `/proc/PID/cgroup` means the process belongs to a container.
- **Reclaimable or needed.** `docker system df` counts every image without a container as reclaimable, including rollback tags and images run on demand (`supabase test db` runs `pg_prove`). `supabase stop` keeps the project's volumes on purpose. A re-pullable image is safer to remove than any volume.
- **Exposed or filtered.** Published Docker ports bypass ufw's INPUT chain; `DOCKER-USER` decides who reaches them. `tailscale serve status` does not show Tailscale SSH port forwards.
- **Counted or hidden.** Use `journalctl -q`, or `-- No entries --` counts as a line. Services that log to stderr land at info priority even when the line says `ERROR`, so `-p err` alone misses them. Without `sudo`, `ss -p` hides other users' socket owners. `sudo sshd -G` prints sshd's effective configuration; `sshd -T` fails while socket activation leaves `/run/sshd` absent.
- **Quantified.** State sizes in absolute and percentage terms, and growth as a rate.

## 4. Decide

| Class | Examples | Action |
| --- | --- | --- |
| Verified, reversible defect in `w`'s files or the system configuration | false error noise from a package hook, a misconfigured unit or timer, a retention gap | Fix when the request authorizes fixes. |
| Interrupts work in progress | killing a process, restarting docker, tailscaled, sshd, caddy, cloudflared, or networking; rebooting; upgrading packages | Ask, giving the evidence and the expected disruption. |
| Destroys data | volumes, databases, backups, files that cannot be regenerated | Ask; never act on inference. |
| Another user's, or outward-facing | another user's processes or files, `/srv/mathblox`, DNS, Cloudflare, GitHub | Report; act only on an explicit request. |
| Deliberate, or not worth it | listed in `known-state.md`; waste without pressure | Leave it, and say why. |

i9 is remote and its only uplink is Wi-Fi. Treat every netplan, networkd, ufw, or Tailscale change as interrupting work. When one is approved, run `sudo netplan try` in the background, confirm connectivity, then accept with `sudo pkill -USR1 -f '^/usr/bin/python3 /usr/sbin/netplan try'` (anchored, so it cannot match the `sudo pkill` itself); any other ending, including its timeout, reverts the change.

## 5. Fix

- Reproduce first, with a command whose only effect is to show the defect: run the failing check itself, or trigger the event and count journal lines after a cursor (`journalctl -n 0 --show-cursor`, then `--after-cursor`). The decision table governs reproductions too: never start a unit such as `apt-daily-upgrade` to watch it fail.
- Fix the cause at the layer that produces it: the retention policy rather than a one-off deletion, the hook rather than the log.
- Use the upgrade-safe mechanism for that layer. Find a file's package with `dpkg -S`. Override a package file with `dpkg-divert --local --rename` to a path its consumer does not scan; never edit or delete it. Change units through `systemctl edit` drop-ins and daemons through their own files under `/etc`. After touching a package's files, `dpkg --verify <package>` must stay clean.
- Rerun the same reproduction with a check that can fail, and report the counts before and after: a filter that matches nothing, such as `-p err` on a service that logs at info, proves nothing. Confirm the affected service still works.
- Record each lasting system change in `known-state.md` with its date, reason, verification, and rollback command: nothing else tracks `/etc` on i9. Record a decision that something is deliberate, or a finding awaiting the user, the same way, and delete entries whose subject is gone. Changes to tracked dotfiles follow that repository's conventions.

## 6. Report

Lead with a one-sentence verdict, then:

1. Health: one row per area, with its numbers.
2. Findings, most severe first: claim, evidence, impact.
3. Changes made: what changed, before and after, rollback.
4. Left alone: each item and the evidence for leaving it.
5. Decisions needed: options and their costs.
6. Corrections to earlier claims.

Use absolute paths. Omit a section with nothing in it.
