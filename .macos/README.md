# macOS configuration

This file defines the desired state for this Mac. `./audit.sh` observes the current state read-only and exits nonzero only when a prescribed check could not run, because a silently skipped check reads exactly like a passing one. Agents must treat the desired state as authoritative and re-run the audit before relying on observed values.

Dated observations are not kept here; `git log -p` is the audit trail.

This repository is public. Never record secrets, private hostnames, addresses, tailnet names, or other unique machine identifiers in it. Before committing, run `git diff --cached | grep -inE 'sk-|glpat|gho_|\.ts\.net|[0-9]{1,3}(\.[0-9]{1,3}){3}'` and confirm every hit is an intended public value such as `1.1.1.1`.

## Desired state

| Area | Configuration |
| --- | --- |
| Security | System Integrity Protection, Gatekeeper, Find My, the application firewall with stealth mode, and automatic security updates enabled. Keep network sharing disabled unless intentionally needed. FileVault intentionally disabled. The inert Karabiner container is retained because macOS protects it from deletion without broader Full Disk Access; never weaken Full Disk Access to remove inert metadata. |
| Backups | Time Machine is optional; having no destination configured is intentional. Third-party backup tools such as restic, Borg, Backblaze, and Arq are intentionally declined, so `~/code` and anything outside iCloud have no recovery path. Before discarding any clone, prove nothing is lost rather than assuming it: check every ref, remote-tracking refs included, for reachability from the pushed refs, and compare dangling commits by `patch-id` rather than by tree, since a rebased commit has a different tree for the same change. A plain `git push --all` drops such work silently. |
| Updates | Keep automatic updates enabled. Offered updates may be intentionally deferred; treat major macOS upgrades as compatibility-sensitive changes. |
| Performance | Diagnose measured CPU, memory pressure, energy, disk, or network problems; do not apply speculative tweaks. |
| Power | Keep the current display sleep settings. The 80% battery charge limit is intentionally declined. |
| Startup | Keep Rectangle, Notion Calendar, FigmaAgent, and BetterDisplay as login items. Keep Zoom and NordVPN background services disabled. |
| Storage | Keep roughly 15–20% free. Remove only known disposable data such as stale build output, simulators, Docker data, and package caches. |
| iCloud | Sync Desktop and Documents only intentionally. Keep source repositories outside iCloud-synced directories. |
| Containers | Use Docker Desktop for the Docker CLI and daemon. Replacing it with OrbStack, Colima, or another runtime is intentionally declined; do not propose the swap again. |
| Development | Use Apple Command Line Tools and Homebrew. Install full Xcode only for Apple-platform work. Prefer one version manager per ecosystem and install tools on demand. The AI coding CLIs opencode, kimi-code, grok, the Antigravity CLI shim, `cliproxyapi`, and `ollama` were removed as unused surface and should not return without a named need. |
| Interaction | Fast key repeat with the press-and-hold accent menu disabled, so held keys repeat in Vim and other editors. Smart quotes, smart dashes, and autocorrection off. Dock auto-hidden with no reveal delay. Finder shows the path and status bars and filename extensions, searches the current folder, and saves screenshots to `~/Pictures/Screenshots`. |
| Authentication | Touch ID for `sudo` through `/etc/pam.d/sudo_local`, which survives system updates, with `pam_reattach` listed first so it also works inside tmux. SSH keys stay on disk in `~/.ssh`, unlocked once per login through ssh-agent and the login Keychain; Secure Enclave key stores such as Secretive and the 1Password SSH agent are intentionally declined. |
| Screen lock | Because display sleep is disabled, the display never blanks and the screen never locks itself. Accepted; lock manually with Control+Command+Q. |
| DNS | Cloudflare `1.1.1.1` and `1.0.0.1` set explicitly on every internet-bearing network service, so resolvers never depend on what DHCP hands out, alongside Tailscale MagicDNS at `100.100.100.100` scoped to the tailnet. Encrypted DNS profiles (DoH or DoT) are intentionally declined, and Tailscale would contend for resolver control regardless. |
| Network filtering | Inbound application firewall with stealth mode only. Outbound filtering such as LuLu or Little Snitch is intentionally declined. |
| Version control | `.gitconfig` is tracked and holds no identity; it includes untracked `~/.gitconfig.local` last so local values win. That split buys portability to other machines, not privacy: name and email are already public in this repository's history and in the SSH key comment. Identity helpers must still write with `git config --file ~/.gitconfig.local`, because the global scope resolves to the tracked file. SSH commit signing is enabled and the key is registered with GitHub only. GitLab is retired and fully removed; do not propose reinstating it. `core.fsmonitor`, `core.untrackedCache`, and `git maintenance` are declined on measurement, not preference. |
| Spotlight | Keep indexing enabled. Exclude directories only in response to measured `mdworker` churn, never speculatively. |
| Maintenance | Audit top-level packages before removal or upgrade. Do not restore old packages and settings indiscriminately on a new Mac. `~/.Brewfile` records Homebrew formulae, casks, taps, and Mac App Store apps alongside npm, cargo, and uv globals for deliberate review, and is not applied automatically. `brew bundle check --file=~/.Brewfile --no-upgrade` is the presence invariant, because the plain form fails as soon as any update is offered. The `libtiff` and `webp` circular dependency that `brew bundle` warns about is real rather than stale metadata and both keg receipts are accurate: do not apply the remedy it prints, do not edit the receipts, and revisit only if upstream bumps either formula. |

Never install RAM cleaners or one-click optimizers, delete macOS system components, bulk-apply copied `defaults` commands, or disable System Integrity Protection, Gatekeeper, Spotlight, or security updates for performance.
