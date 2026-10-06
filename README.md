# dotfiles

Personal dotfiles for macOS and Debian/Ubuntu. The repository lives directly in the home directory and uses a deny-by-default `.gitignore`, so only explicitly managed files are public.

## Install

Back up any conflicting dotfiles first, then initialize the home directory as the worktree:

```sh
cd ~
git init
git remote add origin https://github.com/neuramance/dotfiles.git
git fetch origin
git checkout -B main origin/main
```

Bootstrap the platform-specific command-line dependencies:

On macOS:

```sh
bash ~/.config/scripts/mac-setup.sh
```

On Debian/Ubuntu:

```sh
bash ~/.config/scripts/apt-setup.sh
```

Open a new shell or run `source ~/.zshrc`. The equivalent aliases are `macsetup` and `aptsetup`.

The macOS script installs Homebrew when needed, then `jq`, Node.js, the 1Password CLI, and the `fast-cli` npm package. The apt script installs the shell, editor, terminal, PostgreSQL client, compiler, and download utilities used by these dotfiles, including `eza` and `gh` from their upstream apt repositories. These scripts install managed dependencies, not a complete workstation image.

On macOS, restore the untracked files from 1Password with [`local-state`](#local-state):

1. Install the 1Password app, sign in with the personal account, and turn on Settings → Developer → Integrate with 1Password CLI.
2. Open a new terminal window, so the Homebrew tools from `mac-setup.sh` are on `PATH`, and run the first command below, replacing `m4` with the host whose backup to restore.
3. Open another terminal window to load the restored shell files, and run the second command, entering the passphrase from the 1Password item `SSH key passphrase (id_ed25519)` once so the macOS keychain remembers it. From then on `.zprofile` loads the key into ssh-agent at login, so Git can sign commits after a restart.

On i9, restore its untracked files from the Mac with the command under [`local-state`](#local-state), then link its mise config as described under [Local-only state](#local-only-state).

```sh
local-state restore m4
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

## Managed configuration

| Area | Files |
| --- | --- |
| Shell | `.zshrc`, `.zprofile`, `.zshenv`, `.zsh_aliases`, `.hushlogin` — prompt, environment, tool paths, login behavior, and common shell, Git, package-manager, development, and tmux shortcuts. |
| Terminal and editors | `.tmux.conf`, `.vimrc`, `.psqlrc`, `.config/rustfmt.toml` — tmux navigation and display, Vim defaults, PostgreSQL client behavior, and Rust formatting. |
| Toolchain | `.config/mise/config.<host>.toml` — each machine's global mise tools and settings: i9 pins Bun, Node, the Supabase CLI and pyright; m4 takes Node from Homebrew. |
| Git | `.gitconfig` — default branch and SSH commit signing. Identity, credential helper, and signing key live in untracked `~/.gitconfig.local`, which the tracked file includes last so local values win. Required on any new machine, like `.zsh_secrets`. |
| System display | `.config/fastfetch/` and `.config/herdr/config.toml` — Fastfetch theme, host-specific logos, resource helpers, and Herdr theme/key bindings. |
| AI agents | `.codex/` and `.claude/` — global Codex and Claude Code instructions, settings, notifications, status line, plugin configuration, and reusable skills. |
| macOS | Moved to [macstate](https://github.com/neuramance/macstate) — declared system state with a read-only audit and an idempotent apply, no longer tracked in this repository. |
| Homebrew | `.Brewfile` — snapshot of top-level formulae, casks, taps, Mac App Store apps, and global npm, cargo, and uv tools. A record for deliberate review, not an automatic restore. Refresh with `brew bundle dump --file=~/.Brewfile --force --no-vscode`; verify with `brew bundle check --file=~/.Brewfile --no-upgrade`. Dropping `--no-upgrade` also reports available updates, so it fails whenever any package or App Store app has one pending. |
| Bootstrap | `.config/scripts/apt-setup.sh` and `.config/scripts/mac-setup.sh` — idempotent platform package setup. |
| Repository tooling | `repomix.config.json` and `.repomixignore` — bounded Repomix export configuration. |

## `wifi-speed`

`~/.local/bin/wifi-speed` measures a macOS Wi-Fi connection against Apple `networkquality`, Cloudflare, and Netflix Open Connect, then appends JSONL results to the untracked `~/.local/share/wifi-speed/log.jsonl`.

```sh
wifi-speed             # one run
wifi-speed -n 3        # median of three runs
wifi-speed --show      # last ten logged results
```

Run `wifi-speed --help` for all options.

## `open-remote`

`~/.local/bin/open-remote` makes Cmd-click work on server paths printed in an SSH session, such as files Claude Code writes on a remote host. It copies the file over SSH into `~/Library/Caches/open-remote/<host>/` and opens the copy with its default app. Each click copies the file again, and edits to the copy stay on the Mac.

Connect it in iTerm2 under Settings → Profiles → Advanced → Smart Selection → Edit. Add a rule with precision **Very High** and this regular expression:

```text
(?<![A-Za-z0-9._~+@%/-])/(?:root|home|srv)/[A-Za-z0-9._~+@%,=/-]*[A-Za-z0-9_~+@%=/-](?::[0-9]+){0,2}
```

Under Edit Actions, add **Run Command…** with this parameter, replacing `w@i9` with the server:

```sh
"$HOME/.local/bin/open-remote" w@i9 '\0'
```

The rule matches only `/root`, `/home`, and `/srv` paths, which macOS does not use, so Cmd-click on local paths keeps its normal behavior. The server must accept your SSH key without a prompt. Failures appear as a macOS notification and in iTerm2's Script Console (Scripts → Manage → Console).

## `local-state`

`~/.local/bin/local-state` keeps the untracked files a new machine needs in 1Password, so this repository plus 1Password restores the whole setup. It stores `~/.ssh` (configuration and keys, without the agent sockets in `~/.ssh/agent`), `~/.aws/config`, `~/.aws/credentials`, `~/.gitconfig.local`, `~/.zsh_aliases.local`, and `~/.zsh_secrets`, whichever exist, as one tar archive in a Document item named `local-state-<host>`, where `<host>` is the Mac's local hostname (`scutil --get LocalHostName`), in the personal 1Password account (`my.1password.com`), never a company account. `local-state backup i9` stores the same files from i9's home directory, read over SSH, as `local-state-i9`.

```sh
local-state backup          # also runs daily on its own
local-state restore m4      # on a new machine, from host m4's backup
local-state backup i9       # i9's files over SSH, also daily
```

To restore a new i9, run this on the Mac; `-k` keeps any file already on i9:

```sh
op document get local-state-i9 --account my.1password.com | ssh i9 'tar -C ~ -xvkf -'
```

Backup stores the contents of symlinked files, and replaces the item's archive only after every file was read; it stops if more than one item has that name. It uploads only when the archive differs from the last upload from this Mac, whose hash it keeps in `~/.local/state/local-state/`, and it refuses to drop a file the stored backup has: restore the file, or delete the item in 1Password to start a new backup. Each `op` call is stopped after 120 seconds, Touch ID prompt included. Restore refuses to replace anything already at a restored path, symlinks included, except a real directory, and names each one; move them aside and run it again. The passphrase of `~/.ssh/id_ed25519` is not in the archive; it is the separate 1Password item `SSH key passphrase (id_ed25519)`.

`~/Library/LaunchAgents/io.github.neuramance.local-state.plist` runs `local-state backup` and then `local-state backup i9` daily at 13:00, or at the next wake if the Mac was asleep. It asks for Touch ID only when something changed, logs to `~/Library/Logs/local-state.log`, and shows a notification when either fails. macOS loads it at login; `launchctl bootout gui/$(id -u)/io.github.neuramance.local-state` stops it.

It needs the 1Password app, installed by hand and signed in to the personal account with Settings → Developer → Integrate with 1Password CLI turned on, plus the 1Password CLI and `jq`, which `mac-setup.sh` installs.

## `i9-tunnel`

`~/Library/LaunchAgents/io.github.neuramance.i9-tunnel.plist` keeps one SSH tunnel to `i9` open, so a dev server on i9 opens in the Mac's browser at the same `http://localhost:<port>`, hot reload included. It forwards ports 3000–3099 and the local Supabase ports 54321–54324, connects through the `Host i9` entry and `known_hosts` that [`local-state`](#local-state) restores, and writes its latest attempt to `~/Library/Logs/i9-tunnel.log`. macOS loads it at login and restarts it within 10 seconds whenever it exits. A port another Mac process already holds is skipped, so stop the tunnel with `launchctl bootout gui/$(id -u)/io.github.neuramance.i9-tunnel` before running a local Supabase on the same ports.

It needs Tailscale on both machines, with Tailscale SSH enabled on i9 (`sudo tailscale set --ssh`). After replacing i9, run `ssh-keygen -R i9` and `ssh i9` once on the Mac to trust its new host key; the tunnel reconnects on its own.

## `agent-sounds`

Claude Code and Codex run `~/.claude/play-notification.sh` when a turn ends (Purr) and when they need input (Funk). On the Mac it plays the sound with `afplay`. On i9 it sends the sound's name to `127.0.0.1:47123`, which a reverse SSH tunnel carries to the Mac, and the Mac plays it; when the Mac does not answer `ok` within a second, it rings the terminal bell instead, which iTerm2 plays.

`~/Library/LaunchAgents/io.github.neuramance.agent-sounds.plist` listens on the Mac's `127.0.0.1:47123`, plays `Purr` or `Funk` from `/System/Library/Sounds` and ignores anything else; launchd starts it only when a sound arrives. `~/Library/LaunchAgents/io.github.neuramance.agent-sounds-tunnel.plist` keeps the reverse tunnel from i9's `127.0.0.1:47123` to it open through the same `Host i9` entry as [`i9-tunnel`](#i9-tunnel), and writes its latest attempt to `~/Library/Logs/agent-sounds-tunnel.log`. It runs apart from `i9-tunnel` because it exits whenever i9 still holds the port for a dropped connection, and retries every 10 seconds until it gets it. macOS loads both at login; `launchctl bootout gui/$(id -u)/io.github.neuramance.agent-sounds-tunnel` stops the tunnel.

On the Mac, `printf 'Purr\n' | nc -w 1 127.0.0.1 47123` plays Purr and prints `ok`; on i9, `echo '{"hook_event_name":"Stop"}' | ~/.claude/play-notification.sh` plays it through the tunnel. A new sound must be named in both `play-notification.sh` and the listener's `case`.

## Local-only state

This is a public repository. Secrets, identities, SSH configuration, histories, caches, logs, and application runtime state remain untracked; [`local-state`](#local-state) backs up the files a new machine needs. Before committing, run `git diff --cached | grep -inE 'sk-|glpat|gho_|\.ts\.net|[0-9]{1,3}(\.[0-9]{1,3}){3}'` and confirm every hit is an intended public value such as `1.1.1.1`. Put shell secrets in `~/.zsh_secrets`, local aliases in `~/.zsh_aliases.local`, and Git identity, credential helper, and signing key in `~/.gitconfig.local`. The first two are sourced automatically when present; the third is pulled in by the tracked `.gitconfig`, which also points `gpg.ssh.allowedSignersFile` at the untracked `~/.ssh/allowed_signers`; commits sign without that file, but verifying them needs it. Fastfetch reads `~/.config/fastfetch/logo.png`, an untracked per-host symlink: link it to the tracked logo for the machine with `ln -sf logo.m4.png ~/.config/fastfetch/logo.png`. mise reads `~/.config/mise/config.toml`, also an untracked per-host symlink: link it with `ln -sf config.m4.toml ~/.config/mise/config.toml` (`config.i9.toml` on i9), then run `mise install`.
