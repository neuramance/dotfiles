# i9 known state

Facts and decisions that change how audit signals are judged. Date each decision and open finding, give its reason and rollback, and delete an entry once its subject is gone.

## Host

- The primary link is Wi-Fi `wlo1`. `enp3s0` is a direct Ethernet link (10.42.0.2/24, `/etc/netplan/70-direct-link.yaml`), usually without carrier. networkd's `off` state means administratively down or being deleted; a Wi-Fi drop is `no-carrier` or `dormant`.
- `/etc/netplan/60-wifi.yaml` and its `.backup-*` copy hold the Wi-Fi password.
- `/tmp` is tmpfs, so its files use RAM, up to half of it. `systemd-tmpfiles-clean` deletes entries older than 10 days and a reboot empties it. Agent scratch directories accumulate there.
- `w` owns the machine. `heila` is a separate user with a loop-mounted home at `/home/heila`, their own herdr server and agents, and podman containers. `mathblox` is the service user for `/srv/mathblox`. Processes listed under `usbmux` belong to the Supabase containers, whose UID matches that host user.
- Podman's `conmon` logs container stderr at error priority, so ordinary container stderr appears as journal errors under the container's name. `catatonit -P` is podman's rootless pause process, one per user who has run podman.
- NVMe `unsafe_shutdowns` was 39 on 2026-10-07.

## Exposure baseline

- ufw denies incoming by default. Its rules, identical for IPv4 and IPv6 except the 10.42.0.0/24 rule: allow anything on `tailscale0`, allow 22/tcp and 2222/tcp on `tailscale0`, allow 22/tcp from 10.42.0.0/24, deny 5678/udp on `wlo1`.
- Docker publishes Supabase on `0.0.0.0:54321-54324`, which bypasses ufw. The `DOCKER-USER` chains from `/etc/ufw/after.rules` and `/etc/ufw/after6.rules` drop forwarded traffic to Docker networks unless it comes from `tailscale0` or a Docker bridge: two DROP rules per address family. Without them, every published port is reachable from the Wi-Fi network.
- sshd is socket-activated on 22 and 2222, with password and keyboard-interactive authentication and root login off. Tailscale SSH is on (`RunSSH`).
- Expected non-loopback listeners: ports 22 and 2222 (systemd socket activation for sshd), docker-proxy on 54321-54324, tailscaled on 41641/udp and its tailnet addresses, cloudflared's outbound QUIC sockets, and the DHCP client on `wlo1`.
- caddy serves 127.0.0.1:80 behind the cloudflared tunnel; cloudflared's metrics are on 127.0.0.1:20241.

## Expected processes and services

- The Mac's `i9-tunnel` LaunchAgent forwards ports 3000-3099 and 54321-54324 to i9's 127.0.0.1 over `ssh i9`, so a `tailscaled` or `sshd` client on those ports is the Mac using that server.
- Agent sessions run in herdr panes, and each Claude Code or Codex session runs its own language servers, 0.1-1.4 GiB each. `herdr server`, `claude daemon run`, `claude bg-pty-host`, and `codex app-server` run detached by design.
- Dev servers started by agent sessions outlive them: `bun run dev` in an umath checkout runs `scripts/serve-cc.ts`, and `next dev` runs in `website`. Judge each by the evidence rules, never by detachment alone.
- Every umath checkout (`umath_1` to `umath_4`) sets Supabase `project_id = "umath"`, so they share one stack (`supabase_*_umath`) and its volumes. Docker also runs `umath-browser` (Playwright run-server on the host network, 127.0.0.1:39093) and `mathblox-welcome` (127.0.0.1:8080).
- `webapps-backup.timer` backs the web apps up daily with restic into `/var/backups/webapps` (keeping 7 daily, 4 weekly, and 6 monthly snapshots) and pings healthchecks. `webapps-health.timer` checks them every 2 minutes. The user timer `neuramance-deploy.timer` deploys every minute and is tracked in the dotfiles.
- `reboot-check.timer` runs `/usr/local/sbin/reboot-check` hourly and pings healthchecks with its output; a run fails while `/run/reboot-required` exists or `nvidia-smi -L` lists no GPU. Ubuntu's kernel hooks write that flag, naming `linux-image-<version>` and `linux-base`, whenever a package for an installed kernel changes, including a packaging-only `linux-modules-nvidia` rebuild for the running kernel (2026-10-08). NVIDIA is the only separately packaged module loaded. A flag naming only `linux-image-$(uname -r)` and `linux-base` is stale when `NEEDRESTART-KSTA` is 1 and `/sys/module/nvidia/srcversion` equals `modinfo -F srcversion nvidia`; clear it with `sudo rm /run/reboot-required /run/reboot-required.pkgs && sudo systemctl start reboot-check.service`. The check honours every flag entry on purpose, because a real NVIDIA driver update (595.58 to 595.71 on 2026-05-20) writes the same flag.

## Accepted decisions

- 2026-10-07: chrony's networkd-dispatcher `off.d` hook is diverted to `/usr/lib/networkd-dispatcher/off.d-chrony-onoffline.disabled`. On this host it fired only when Docker deleted an interface, where it does nothing, and each such event logged a `networkctl` error and a dispatcher `Failed to get interface` error. The routable hook remains. Verified: three Docker network create-and-remove cycles logged 12 `networkctl` errors before and 0 after, and the next 25 interface events logged no `Failed to get interface` line (210 earlier that boot). Still expected, and unaffected by the divert: `WARNING:Unknown index N seen, reloading interface list` for each new Docker interface, and an occasional `ERROR:Unknown interface index N seen even after reload` (at info priority) when an interface disappears before the dispatcher reloads, an upstream race. Undo: `sudo dpkg-divert --local --rename --remove /usr/lib/networkd-dispatcher/off.d/chrony-onoffline`.

## Open findings

- 2026-10-07: `apt-daily` and `apt-daily-upgrade` wait the full 30 seconds for network-online and log an error on every run, because `systemd-networkd-wait-online` waits for `enp3s0`, which has no carrier. The generated `/run/systemd/network/10-netplan-enp3s0.network` has no `RequiredForOnline=no`, although `/etc/netplan/00-installer-config.yaml` sets `optional: true` for the same interface. Changing netplan needs the user's approval.
