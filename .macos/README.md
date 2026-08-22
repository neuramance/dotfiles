# macOS configuration

This file defines the desired state for this Mac and records dated audits. Agents must treat the desired state as authoritative, re-run the read-only audit before relying on observed values, and never record secrets or unique machine identifiers here.

## Desired state

| Area | Configuration |
| --- | --- |
| Security | System Integrity Protection, Gatekeeper, Find My, the application firewall with stealth mode, and automatic security updates enabled. Keep network sharing disabled unless intentionally needed. FileVault intentionally disabled. |
| Backups | Time Machine is optional; having no destination configured is intentional. Third-party backup tools such as restic, Borg, Backblaze, and Arq are intentionally declined, so `~/code` and anything outside iCloud have no recovery path. |
| Updates | Keep automatic updates enabled. Offered updates may be intentionally deferred; treat major macOS upgrades as compatibility-sensitive changes. |
| Performance | Diagnose measured CPU, memory pressure, energy, disk, or network problems; do not apply speculative tweaks. |
| Power | Keep the current display sleep settings. The 80% battery charge limit is intentionally declined. |
| Startup | Keep Rectangle, Notion Calendar, FigmaAgent, and BetterDisplay as login items. Keep Zoom, NordVPN, and `cliproxyapi` background services disabled. |
| Storage | Keep roughly 15–20% free. Remove only known disposable data such as stale build output, simulators, Docker data, and package caches. |
| iCloud | Sync Desktop and Documents only intentionally. Keep source repositories outside iCloud-synced directories. |
| Containers | Use Docker Desktop for the Docker CLI and daemon. Replacing it with OrbStack, Colima, or another runtime is intentionally declined; do not propose the swap again. |
| Development | Use Apple Command Line Tools and Homebrew. Install full Xcode only for Apple-platform work. Prefer one version manager per ecosystem and install tools on demand. |
| Interaction | Fast key repeat with the press-and-hold accent menu disabled, so held keys repeat in Vim and other editors. Smart quotes, smart dashes, and autocorrection off. Dock auto-hidden with no reveal delay. Finder shows the path and status bars and filename extensions, searches the current folder, and saves screenshots to `~/Pictures/Screenshots`. |
| Authentication | Touch ID for `sudo` through `/etc/pam.d/sudo_local`, which survives system updates, with `pam_reattach` listed first so it also works inside tmux. SSH keys stay on disk in `~/.ssh`, unlocked once per login through ssh-agent and the login Keychain; Secure Enclave key stores such as Secretive and the 1Password SSH agent are intentionally declined. |
| Screen lock | Because display sleep is disabled, the display never blanks and the screen never locks itself. Accepted; lock manually with Control+Command+Q. |
| DNS | Plain `1.1.1.1` alongside Tailscale MagicDNS at `100.100.100.100`. Encrypted DNS profiles (DoH or DoT) are intentionally declined, and Tailscale would contend for resolver control regardless. |
| Network filtering | Inbound application firewall with stealth mode only. Outbound filtering such as LuLu or Little Snitch is intentionally declined. |
| Version control | `.gitconfig` is tracked and holds no identity; it includes untracked `~/.gitconfig.local` last so local values win. SSH commit signing is enabled and the key is registered with GitHub only. Identity helpers must write with `git config --file ~/.gitconfig.local`; the global scope resolves to the tracked `.gitconfig` and would publish identity. GitLab is retired; do not propose registering keys there or reinstating `glab`. `core.fsmonitor`, `core.untrackedCache`, and `git maintenance` are declined on measurement, not preference. |
| Spotlight | Keep indexing enabled. Exclude directories only in response to measured `mdworker` churn, never speculatively. |
| Maintenance | Audit top-level Homebrew packages before removal or upgrade. Do not restore old packages and settings indiscriminately on a new Mac. `~/.Brewfile` records the top-level packages for deliberate review and is not applied automatically. |

Never install RAM cleaners or one-click optimizers, delete macOS system components, bulk-apply copied `defaults` commands, or disable System Integrity Protection, Gatekeeper, Spotlight, or security updates for performance.

## Audit: 2026-08-21

| Area | Observed | Action |
| --- | --- | --- |
| macOS | Sequoia 15.7.4; Sequoia 15.7.9, Safari 26.6.1, and Tahoe 26.6.2 are offered but intentionally ignored. Command Line Tools 26.3 is installed and `brew doctor` is clean. | None. |
| Security | FileVault intentionally off. System Integrity Protection, Gatekeeper, Find My, and the application firewall with stealth mode enabled. No network share points configured. | None. |
| Backups | No Time Machine destination configured, intentionally. | None. |
| Updates | Automatic download, macOS installation, configuration-data installation, and critical-update installation enabled. | None. |
| Management | Not enrolled through DEP or MDM. | None. |
| Storage | 699 GiB available on the 926 GiB APFS SSD. | None. |
| Memory | 128 GiB installed; no swap used. | None. |
| Battery | Normal condition, 92% maximum capacity, 266 cycles. No 80% charge limit set. | None. |
| Power | Display sleep disabled on battery and AC power as intended. | None. |
| Uptime | Extension-cleanup restart completed; uptime was 7 minutes at audit. | None. |
| CPU | Post-restart samples were 66–75% idle with no swap while installer, update, and Spotlight services completed transient work. | None. Recheck after post-restart work settles only if usage remains sustained while otherwise idle. |
| Login items | Rectangle, Notion Calendar, FigmaAgent, and BetterDisplay, all approved. | None. |
| Background services | Zoom update agents and daemon, NordVPN helper, and `cliproxyapi` disabled. Google/Chrome updater and Docker service definitions remain. | None. |
| Extensions and sharing | Kerio VPN and Karabiner extensions removed; Tailscale 1.102.3 is the only installed system extension. No network share points configured. The inert 32 KiB Karabiner container is intentionally retained because macOS protects it from deletion without broader Full Disk Access. | None. Do not weaken Full Disk Access solely to remove inert metadata. |
| Homebrew | 147 formulae and 4 casks. `fzf`, `mas`, `fd`, `zoxide`, and `git-delta` added; `~/.Brewfile` now records 37 formulae, 4 casks, 2 taps, and 11 Mac App Store apps. `railway` is outdated and CapCut has an App Store update pending, both intentionally deferred under the Updates policy, which means plain `brew bundle check` fails and `--no-upgrade` is the presence invariant. Nothing pinned, orphaned, or awaiting cleanup. Homebrew's `fd` is shadowed by `~/.kimi-code/bin/fd`, which is prepended to PATH in `.zshrc`; the install exists so `fd` survives removal of that tool. `greptileai/tap` and `supabase/tap` supply their installed CLIs. `brew doctor` is clean. Docker Desktop provides the working Docker CLI. | None. |
| `libtiff` and `webp` | `brew bundle` warns of a circular dependency between them. The cycle is real rather than stale metadata: `libtiff.6.dylib` links `libwebp`, and `cwebp`, `dwebp`, and `img2webp` link `libtiff.6.dylib`, so both keg receipts are accurate. Homebrew reports neither formula outdated, and the currently published bottle embeds the same mutual dependency. A TIFF to WebP to PNG round trip succeeds and all nine dependent formulae resolve every dylib reference. A diagnostic uninstall and reinstall of `webp` reproduced an identical receipt at the same version, and its `installed_on_request` flag was afterwards restored to dependency status so that `~/.Brewfile` continues to record only intent. | None, and do not apply the remedy `brew bundle` prints. Reinstalling restores the same edges, editing the keg receipt would record a dependency that the binaries contradict, and building `webp` from source against the current formula would drop TIFF support from its tools. Revisit only if upstream bumps either formula. |
| Development | Command Line Tools 26.3, Homebrew, Git, Bun, Node, Python, and `uv` installed; Git identity configured; full Xcode absent. | None. Install full Xcode only when required. |
| Finder, Dock, and input | Finder path and status bars, filename extensions, and Dock auto-hide enabled. Screenshots save to `~/Pictures/Screenshots`. Fast key repeat enabled; smart quotes, smart dashes, and spelling autocorrection disabled. Press-and-hold accent menu disabled, Dock reveal delay set to zero with a 0.15 s animation, and Finder search scoped to the current folder. | None. Applications pick up the press-and-hold change on next launch. |
| Authentication | `pam_reattach` installed at `/opt/homebrew/lib/pam/pam_reattach.so`. `/etc/pam.d/sudo_local` not yet created, so `sudo` still requires a typed password. `~/.ssh/config` now ends with a `Host *` block setting `AddKeysToAgent` and `UseKeychain`; `id_ed25519` is passphrase-protected and `id_ed25519_gitlab` is not. | Create `sudo_local` from `sudo_local.template` with `pam_reattach` before `pam_tid`, and run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`. Both need an interactive prompt. |
| Version control | `.gitconfig` tracked with no identity; `~/.gitconfig.local` supplies name, email, credential helper, and `user.signingkey`. `init.defaultBranch=main`, `gpg.format=ssh`, `commit.gpgsign=true`, delta as pager. `~/.ssh/allowed_signers` created for local verification. Signing is not yet exercised because the key is not in the agent, and neither `gh` token carries `admin:ssh_signing_key`. | Load the key into the agent, then register the public key as a signing key with GitHub and GitLab. Note that `git config --global` does not follow includes, so verify with unscoped `git config --get`. |
| Git performance | Largest repository is 4,218 tracked files; 21,628 across all 14 repositories in `~/code`. `git status` completes in 0.01–0.03 s. | None. `core.fsmonitor` and `core.untrackedCache` pay off near 100k files per repository and cost a daemon each; `git maintenance` would add hourly prefetch across 14 repositories. Both declined as speculative. |
| Audit portability | Four audit commands piped to `rg`, which has no binary on this Mac — it existed only as a shell function inside an agent's snapshot environment, so those lines failed in the interactive shell this file prescribes. Rewritten to use base-system `grep`. | None. Prefer base-system tools in this block so the audit runs on a fresh machine. |
| Screen lock | `pmset -g assertions` shows `powerd` holding "Prevent sleep while display is on" continuously, so the display never blanks and no automatic lock occurs. A `caffeinate` assertion and a Handoff assertion were also present. | None, by decision. |
| DNS and filtering | Resolvers are `1.1.1.1` and Tailscale MagicDNS at `100.100.100.100`, unencrypted. No outbound filtering installed. | None, by decision. |
| Spotlight | Indexing enabled on `/` with no exclusions. `mds`, `mds_stores`, and `mdworker` all sampled at 0.0–0.1% CPU while idle, and Spotlight was absent from the top ten CPU consumers. 13 `node_modules` and 3 `target`/`DerivedData`/`.venv` directories within four levels of `~`. | None. No measured churn, so no exclusions. Revisit only if `mdworker` is sustained during builds. |
| Apple Intelligence | Opted in, with `modelcatalogd`, `generativeexperiencesd`, `ModelCatalogAgent`, and `IntelligencePlatformComputeService` resident. All `UAF_FM_*` model asset directories total 0 B, so no weights are downloaded, and none of these processes appeared among the top CPU consumers. | None. The daemons are resident on Sequoia regardless; disabling would reclaim no measured resources. |
| iCloud | Desktop and Documents are synced intentionally. | None. |

## Audit: 2026-08-22

Records only what changed since the previous audit; earlier rows stand as the observation of their date.

| Area | Observed | Action |
| --- | --- | --- |
| Authentication | `/etc/pam.d/sudo_local` created at mode 644 with `pam_reattach` before `pam_tid`. `id_ed25519` is loaded in ssh-agent and persisted to the login Keychain, so it survives reboots. | None. |
| Version control | Commit signing verified end to end and non-interactively: `git log --show-signature` reports a good signature for the registered ED25519 key. The public key is registered on the `neuramance` GitHub account as signing key `m4`, whose token now carries `admin:ssh_signing_key`. | None. `gh ssh-key list` warns that listing authentication keys needs `admin:public_key`; that scope is not required for signing and is intentionally absent. |
| GitLab | Torn down. `meridian-1` was backed up to the private repo `neuramance/meridian` (4 branches plus 4 archival `salvage/*` tags) and repointed at GitHub as its only remote. `meridian-2` through `meridian-4` and `modern_emr` were deleted after verification, reclaiming about 1.8 GiB. `glab` uninstalled, its config and token removed locally, the `id_ed25519_gitlab` keypair deleted, the GitLab `Host` block dropped from `~/.ssh/config`, and four `known_hosts` entries removed. No `gauntlet` or `glab` reference remains in `~/.ssh`, git config, shell config, or `~/.Brewfile`. | The access token was only revoked locally. The instance was confirmed still reachable, so the token stays live until revoked server-side from that GitLab's own token settings; because the credential is no longer on this machine, revoking it needs a browser session there. `modern_emr` was deleted on an explicit decision after its contents were spelled out; it has no other copy. |
| Backup verification | Deletion was gated on proving nothing was lost, not on assuming it. Every ref in the discarded clones, including remote-tracking refs, was checked for reachability from the pushed refs, and every dangling commit was compared by `patch-id` rather than by tree, since a rebased commit has a different tree for the same change. That found one orphaned GitLab branch (`fix/outdated-contract-guard`), one branch absent from `meridian-1` (`feat/holo-trade-buttons`), and four dangling commits whose changes existed nowhere else; all were salvaged and pushed before anything was removed. | None. A plain `git push --all` would have silently dropped six items. |
| Git identity helpers | Removed. `gitpersonal` and `gitgauntlet` in `~/.zsh_aliases.local` both wrote through `git config --global`, which resolves to the tracked `.gitconfig` and would have committed name and email to a public repo. With `gitgauntlet` retired there was one identity left, already persisted in `~/.gitconfig.local`, so the switcher set what was already set and was deleted along with the now-empty `~/.zsh_aliases.local`. The obsolete comment block in the tracked `.zsh_aliases` was dropped; its `[ -f ~/.zsh_aliases.local ] && source` guard remains as the documented escape hatch for machine-specific aliases. | None. Any future identity helper must write with `git config --file ~/.gitconfig.local`; the global scope resolves to the tracked file and would publish identity. |
| Homebrew | 146 formulae and 4 casks after removing `glab`; `~/.Brewfile` records 36 formulae, 4 casks, 2 taps, and 11 Mac App Store apps. `railway` and `awscli` were upgraded with their `aws-c-s3` and `s2n` dependencies, and CapCut was updated to 9.3.0, so nothing is outdated across formulae, casks, or App Store apps and nothing awaits cleanup; 209 MB of superseded kegs and caches were freed. `brew doctor` is clean. | None. With nothing deferred, plain `brew bundle check` passes too, but `--no-upgrade` stays the recorded invariant because the plain form fails again as soon as any update is offered. |

## Read-only audit

Run from an interactive shell. Some commands report that a setting is unavailable or unset when macOS is using its default.

```sh
sw_vers
fdesetup status
spctl --status
csrutil status
defaults read /Library/Preferences/com.apple.FindMyMac FMMEnabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sharing -l
softwareupdate --schedule
softwareupdate -l
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates
defaults read /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall
defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall
tmutil status
tmutil destinationinfo
profiles status -type enrollment
df -h /
memory_pressure
sysctl hw.memsize vm.swapusage
pmset -g custom
system_profiler SPPowerDataType | grep -A12 -E 'Health Information|Charge Information'
osascript -e 'tell application "System Events" to get the name of every login item'
find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons -maxdepth 1 -type f 2>/dev/null | sort
launchctl print-disabled "gui/$(id -u)"
launchctl print-disabled system
systemextensionsctl list
top -l 2 -s 2 -o cpu -stats pid,command,cpu,mem -n 12
xcode-select -p
pkgutil --pkg-info com.apple.pkg.CLTools_Executables
brew --version
brew list --formula | wc -l
brew list --cask | wc -l
brew outdated --formula
brew outdated --cask --greedy
brew list --pinned
brew autoremove --dry-run
brew cleanup --dry-run
brew tap
brew services list
brew doctor
command -v docker
docker --version
defaults read com.apple.finder ShowPathbar
defaults read NSGlobalDomain AppleShowAllExtensions
defaults read com.apple.finder ShowStatusBar
defaults read com.apple.dock autohide
defaults read com.apple.screencapture location
defaults read NSGlobalDomain KeyRepeat
defaults read NSGlobalDomain InitialKeyRepeat
defaults read NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled
defaults read NSGlobalDomain NSAutomaticDashSubstitutionEnabled
defaults read NSGlobalDomain NSAutomaticSpellingCorrectionEnabled
defaults read NSGlobalDomain ApplePressAndHoldEnabled
defaults read com.apple.dock autohide-delay
defaults read com.apple.dock autohide-time-modifier
defaults read com.apple.finder FXDefaultSearchScope
cat /etc/pam.d/sudo_local
ls -l /opt/homebrew/lib/pam/pam_reattach.so
mdutil -s /
ps -Ao pcpu,comm | grep -iE 'mds|mdworker' | sort -rn | head
defaults read com.apple.CloudSubscriptionFeatures.optIn
du -shc /System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_*
brew bundle check --file=~/.Brewfile --no-upgrade
otool -L /opt/homebrew/opt/libtiff/lib/libtiff.6.dylib | grep -i webp
otool -L /opt/homebrew/opt/webp/bin/cwebp | grep -i tiff
git config --get init.defaultBranch
git config --get commit.gpgsign
git config --get gpg.format
git config --get core.pager
git config --global --get include.path
git config --list --show-origin | grep -c gitconfig.local
grep -inE 'user|email|signingkey|credential' ~/.gitconfig
grep -cE 'AddKeysToAgent|UseKeychain' ~/.ssh/config
ssh -G github.com | grep -i addkeystoagent
ssh-add -l
command -v fzf zoxide delta mas fd
mas outdated
```
