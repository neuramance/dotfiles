# m4 known state

Facts and decisions that earlier audits recorded, which change how audit signals are judged. An entry can be stale, wrong, or incomplete, and the machine changes between runs: confirm each one against this run's evidence before relying on it, and correct it when the evidence disagrees. Date each decision and open finding, give its reason and rollback, and delete an entry once its subject is gone.

## Host

- m4 is a MacBook Pro (Mac16,5): Apple M4 Max with 12 performance and 4 efficiency cores, 128 GiB of memory, a 1 TB SSD (APPLE SSD AP1024Z, a 994.7 GB APFS container), and a 140 W adapter. It ran macOS 26.6.2 (25G83) on 2026-10-07.
- `w` is the only user and has no passwordless sudo. macOS has no `timeout`; the snapshot bounds calls with `/usr/bin/perl`. `smartmontools` is not installed.
- `SFA-*.json` diagnostic reports (`bug_type 226`) are periodic keychain-sync analytics, written several times a week, not faults.
- `top`'s POWER column equals its %CPU column here. Battery telemetry (`ioreg -rw0 -c AppleSmartBattery`, `SystemLoad` in milliwatts) refreshes about once a minute.
- Baselines on 2026-10-07, 45 days after boot and awake 54% of that time: 318 GB written to the internal disk per day; Data volume 308 GiB used, container 637 GB free of 995 GB; 1.8 GB of 3 GB swap used at pressure level 1; battery at 314 cycles, Maximum Capacity 92%, Condition Normal; 4% charge lost over 12.8 h from sleep to wake on battery (0.31% per hour); 7-12 W system power with the display on and no heavy job.

## Exposure baseline

- The application firewall is on with stealth mode, and it automatically allows built-in and downloaded signed software; its allow-list includes Homebrew's `node@24`, Chrome, and zoom.us. A non-loopback listener from a signed program is therefore reachable from the local network. SIP and Gatekeeper are on.
- Expected non-loopback listeners: launchd on 22 for sshd (Remote Login), ControlCenter (AirPlay Receiver) on 5000 and 7000, rapportd (Continuity) and Tailscale (`io.tailscale.ipn`) on ephemeral TCP ports, Tailscale on 41641/udp, netbiosd on 137-138/udp, mDNSResponder and Chrome on 5353/udp, and sharingd, syslogd, and replicatord on ephemeral UDP ports.
- Expected loopback listeners: `ssh` from the `i9-tunnel` LaunchAgent on 3000-3099 and 54321-54324, forwarding to i9's loopback; launchd on 127.0.0.1:47123 for the `agent-sounds` socket, which `agent-sounds-tunnel` forwards from i9; figma_agent on 44950 and 44960; Notion and Tailscale on ephemeral ports.

## Expected processes and services

- Agent sessions run in herdr panes and iTerm2 tabs. `herdr server`, `codex app-server daemon`, `op daemon` (1Password CLI), and `keyboxd` (GnuPG) run detached by design.
- Each working Claude Code session renews a `caffeinate -i -t 300` child, and Codex sets `prevent_idle_sleep = true`, so their idle-sleep assertions are expected while agents work.
- Dev servers started by agent sessions (`bun run dev`, which runs `next-server`) outlive the session and listen on all interfaces. Judge each by the evidence rules, never by detachment alone. On ports 3000-3099 the `i9-tunnel` holds 127.0.0.1 and ::1, so `localhost` reaches i9, and a local server there is reachable only from other hosts.
- Docker Desktop 4.71.0 keeps `com.docker.backend` and its UI running. Its Linux VM uses Apple's Virtualization framework with 16 CPUs, `MemoryMiB` 16384, and Rosetta for amd64 images; its log (`com.docker.virtualization.log` under `~/Library/Containers/com.docker.docker/Data/log/host`) records VM starts from 2026-04-27 to 2026-10-06. Resource Saver stops the VM after 5 minutes idle, and `docker desktop status` then reports `stopped`. Its `idlemetrics` log line recorded 174 h 39 m of VM compute over 654 h 10 m of running time at its 2026-10-06 stop, about 27% of one core while running. `Docker.raw` is sparse: 24 GiB allocated of 926 GiB.
- LaunchAgents tracked in the dotfiles and described in `~/README.md`: `i9-tunnel` and `agent-sounds-tunnel` (KeepAlive `ssh`, which exits 255 when the network drops; their logs in `~/Library/Logs` hold only the latest attempt). `agent-sounds-tunnel` also exits whenever i9 still holds 127.0.0.1:47123 for a dropped connection and retries every 10 seconds, so its runs count grows by design. `agent-sounds` is socket-activated in inetd style, so launchd's runs count stays 0 and its state `not running` is normal. `local-state` runs daily at 13:00 and backs up `~/.ssh`, AWS configuration, and shell secrets of m4 and i9 to 1Password; it is not a backup of files.
- Google's updater LaunchAgent runs on an interval, so its runs count grows by design.

## Accepted decisions

None yet.

## Open findings

Kept in `known-state.local.md`, which git ignores because this repository is public.
