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

The macOS script installs Homebrew when needed, then `jq`, Node.js, and the `fast-cli` npm package. The apt script installs the shell, editor, terminal, PostgreSQL client, compiler, and download utilities used by these dotfiles, including `eza` from its upstream apt repository. These scripts install managed dependencies, not a complete workstation image.

## Managed configuration

| Area | Files |
| --- | --- |
| Shell | `.zshrc`, `.zprofile`, `.zshenv`, `.zsh_aliases`, `.hushlogin` — prompt, environment, tool paths, login behavior, and common shell, Git, package-manager, development, and tmux shortcuts. |
| Terminal and editors | `.tmux.conf`, `.vimrc`, `.psqlrc`, `.config/rustfmt.toml` — tmux navigation and display, Vim defaults, PostgreSQL client behavior, and Rust formatting. |
| Git | `.gitconfig` — default branch and SSH commit signing. Identity, credential helper, and signing key live in untracked `~/.gitconfig.local`, which the tracked file includes last so local values win. Required on any new machine, like `.zsh_secrets`. |
| System display | `.config/fastfetch/` and `.config/herdr/config.toml` — Fastfetch theme, host-specific logos, resource helpers, and Herdr theme/key bindings. |
| AI agents | `.codex/` and `.claude/` — global Codex and Claude Code instructions, settings, notifications, status line, plugin configuration, and reusable skills. |
| macOS | [`.macos/README.md`](.macos/README.md), [`.macos/audit.sh`](.macos/audit.sh), `.macos/.agents/skills/macos-deep-audit/` — documented desired state and decisions, a read-only audit that observes the machine against them, and the deep-audit skill that interprets the two; nothing here applies settings. |
| Homebrew | `.Brewfile` — snapshot of top-level formulae, casks, taps, and Mac App Store apps. A record for deliberate review, not an automatic restore. Refresh with `brew bundle dump --file=~/.Brewfile --force --formula --cask --tap --mas --no-vscode`; verify with `brew bundle check --file=~/.Brewfile --no-upgrade`. Dropping `--no-upgrade` also reports available updates, so it fails whenever any package or App Store app has one pending. |
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

## Local-only state

This is a public repository. Secrets, identities, SSH configuration, histories, caches, logs, and application runtime state remain untracked. Put shell secrets in `~/.zsh_secrets`, local aliases in `~/.zsh_aliases.local`, and Git identity, credential helper, and signing key in `~/.gitconfig.local`. The first two are sourced automatically when present; the third is pulled in by the tracked `.gitconfig`, which also points `gpg.ssh.allowedSignersFile` at the untracked `~/.ssh/allowed_signers`; commits sign without that file, but verifying them needs it. Fastfetch reads `~/.config/fastfetch/logo.png`, an untracked per-host symlink: link it to the tracked logo for the machine with `ln -sf logo.m4.png ~/.config/fastfetch/logo.png`.
