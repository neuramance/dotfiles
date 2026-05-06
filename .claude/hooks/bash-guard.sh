#!/usr/bin/env bash
# PreToolUse hook for the Bash tool.
# Blocks four classes of dangerous commands:
#   1. Supply-chain "curl ... | sh" patterns (and equivalents).
#   2. Secret-path exfiltration via read/copy commands.
#   3. Writes (redirect, cp/mv/tee) to tamper-sensitive paths.
#   4. rm/mv targeting / or top-level home directories.
# Exit 0 = allow. Exit 2 = deny (stderr is shown to the model).

set -u

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[[ "$tool" != "Bash" ]] && exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Heredoc bodies are usually data (commit messages, file contents,
# templates) being passed as a string to commands like git commit, cat,
# tee. Strip them before scanning so messages and templates that mention
# credential filenames or attack-pattern text don't false-positive.
# Tradeoff: this misses the exotic `bash <<EOF ... EOF` form where the
# heredoc IS code; that form is rarely used by humans or by Claude, and
# any attacker motivated enough to wrap an attack in a heredoc could just
# encode it ten other ways.
cmd_stripped=$(printf '%s' "$cmd" | perl -0777 -e '
  my $c = do { local $/; <STDIN> };
  $c =~ s/<<-?\s*(["\x27]?)(\w+)\1.*?\n\2\s*(\n|$)/<<HEREDOC_STRIPPED\n/gs;
  print $c;
' 2>/dev/null)
[[ -z "$cmd_stripped" ]] && cmd_stripped="$cmd"

block() {
  printf 'Blocked by bash-guard: %s\n' "$1" >&2
  printf '%s\n' "$2" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Class 1: supply-chain pipe-to-shell
# ---------------------------------------------------------------------------

# 1a. curl/wget piped directly into a shell interpreter.
if printf '%s' "$cmd_stripped" | grep -qE '(^|[^A-Za-z0-9_/])(curl|wget)([^|]|\|\|)*\|[[:space:]]*(sudo[[:space:]]+(-[A-Za-z]+[[:space:]]+)*)?(sh|bash|zsh|fish|ksh|dash|csh|tcsh|ash)([[:space:]]|$|;|&|\|)'; then
  block "curl/wget output piped into a shell interpreter (supply-chain risk)" \
        "Mitigation: download to a file (curl -fsSL URL -o script.sh), inspect, then run explicitly."
fi

# 1b. Process substitution feeding curl/wget output to a shell.
if printf '%s' "$cmd_stripped" | grep -qE '(^|[^A-Za-z0-9_/])(sh|bash|zsh|fish|ksh|dash|csh|tcsh|ash)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*<\([[:space:]]*(curl|wget)'; then
  block "shell reading curl/wget output via process substitution" \
        "Mitigation: download to a file, inspect, then run."
fi

# 1c. eval / shell -c with command substitution from curl/wget.
if printf '%s' "$cmd_stripped" | grep -qE '(^|[^A-Za-z0-9_/])(eval|(sh|bash|zsh|fish|ksh|dash)[[:space:]]+-c)[[:space:]]+["'\''[:space:]]*\$\([[:space:]]*(curl|wget)'; then
  block "command substitution of curl/wget output passed to eval or shell -c" \
        "Mitigation: download to a file, inspect, then run."
fi

# 1d. curl/wget piped into a non-shell interpreter (python, ruby, node, perl, php).
if printf '%s' "$cmd_stripped" | grep -qE '(^|[^A-Za-z0-9_/])(curl|wget)([^|]|\|\|)*\|[[:space:]]*(python3?|ruby|node|perl|php)([[:space:]]|$|;|&|\|)'; then
  block "curl/wget output piped into an interpreter (supply-chain risk)" \
        "Mitigation: download to a file, inspect, then run."
fi

# ---------------------------------------------------------------------------
# Class 2: secret-path exfiltration
# ---------------------------------------------------------------------------
# Strategy: block when the command contains BOTH (a) a sensitive path AND
# (b) a command that surfaces file bytes into agent-visible output (cat, grep,
# tar, cp, rsync, scp, base64, etc.). Plain `ssh -i ~/.ssh/id_rsa ...` and
# `git ...` are intentionally allowed because they use the key without
# exposing its bytes.

# (a) Sensitive paths. Matches tilde, $HOME, and absolute /Users/<u>/ forms.
HOME_PFX='(~|\$HOME|/Users/[^/[:space:]"]+)'
SECRETS_RE="${HOME_PFX}/\\.ssh(/|[[:space:]\"']|$)"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.aws(/|[[:space:]\"']|$)"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.gnupg(/|[[:space:]\"']|$)"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.kube(/|[[:space:]\"']|$)"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.(netrc|npmrc|pypirc)([[:space:]\"']|$)"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.docker/config\\.json"
SECRETS_RE="${SECRETS_RE}|${HOME_PFX}/\\.config/gh/hosts\\.yml"
# Dotfiles by name appearing as path components or bare filenames
SECRETS_RE="${SECRETS_RE}|(^|[/[:space:]\"'])\\.env(\\.[A-Za-z0-9_.-]+)?([[:space:]\"';|&]|$)"
SECRETS_RE="${SECRETS_RE}|(^|[/[:space:]\"'])\\.envrc([[:space:]\"';|&]|$)"
SECRETS_RE="${SECRETS_RE}|(^|[/[:space:]\"'])id_(rsa|ed25519|ecdsa|dsa)([[:space:]\"';|&.]|$)"
SECRETS_RE="${SECRETS_RE}|(^|[/[:space:]\"'])credentials\\.json"
SECRETS_RE="${SECRETS_RE}|(^|[/[:space:]\"'])service-account[A-Za-z0-9_.-]*\\.json"
# File extensions that almost always indicate keys/certs.
SECRETS_RE="${SECRETS_RE}|\\.(pem|key|p12|pfx|jks|keystore)([[:space:]\"';|&]|$)"

# (b) Commands that read/copy file bytes into agent-visible output.
READ_CMD_RE='(^|[;&|`(]|[[:space:]])(cat|bat|nl|tac|head|tail|less|more|view|vi|vim|nano|emacs|grep|egrep|fgrep|rg|ag|ack|awk|gawk|mawk|sed|xxd|base64|openssl|od|hexdump|strings|file|stat|cp|rsync|scp|tar|zip|gzip|bzip2|xz|7z|dd|ln|install|read)([[:space:]]|$)'

# Bare input redirection from a sensitive path: `... < ~/.aws/credentials`
REDIR_RE='<[[:space:]]*'"${HOME_PFX}/\\.(ssh|aws|gnupg|kube|netrc|npmrc|pypirc)"

if printf '%s' "$cmd_stripped" | grep -qE "$REDIR_RE"; then
  block "input redirection from a sensitive credential path" \
        "Refusing to read SSH keys, cloud creds, dotfile tokens, etc."
fi

if printf '%s' "$cmd_stripped" | grep -qE "$READ_CMD_RE"; then
  if printf '%s' "$cmd_stripped" | grep -qE "$SECRETS_RE"; then
    block "command appears to read or copy a sensitive credential path" \
          "Refusing to surface SSH keys, cloud creds, .env files, .pem/.key, etc. into agent output."
  fi
fi

# ---------------------------------------------------------------------------
# Class 3: writes / tampering of sensitive paths
# ---------------------------------------------------------------------------
# Tool-level Edit/Write denies don't catch shell-out writes (cp, tee, > redir).
# Block when a tamper-sensitive target is the destination of any write.

TAMPER_RE="${HOME_PFX}/\\.ssh(/|[[:space:]\"']|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.aws(/|[[:space:]\"']|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.gnupg(/|[[:space:]\"']|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.kube/config([[:space:]\"';|&]|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.(zshrc|zshenv|zprofile|zlogin|bashrc|bash_profile|profile|tmux\\.conf|gitconfig)([[:space:]\"';|&]|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.config/git/config([[:space:]\"';|&]|$)"
TAMPER_RE="${TAMPER_RE}|${HOME_PFX}/\\.config/fish/config\\.fish"

# Output redirect (> or >>) into a tamper path.
if printf '%s' "$cmd_stripped" | grep -qE '>>?[[:space:]]*('"$TAMPER_RE"')'; then
  block "output redirected into a tamper-sensitive path" \
        "Refusing to overwrite shell init files, SSH/AWS/kube creds, or git config."
fi

# Write tools (cp, mv, tee, install, dd, rsync, scp) targeting a tamper path.
WRITE_CMD_RE='(^|[;&|`(]|[[:space:]])(cp|mv|tee|install|dd|rsync|scp|ln)([[:space:]]|$)'
if printf '%s' "$cmd_stripped" | grep -qE "$WRITE_CMD_RE"; then
  if printf '%s' "$cmd_stripped" | grep -qE "$TAMPER_RE"; then
    block "command writes/copies into a tamper-sensitive path" \
          "Refusing to modify shell init files, SSH/AWS/kube creds, or git config via shell."
  fi
fi

# ---------------------------------------------------------------------------
# Class 4: rm/mv of catastrophic paths
# ---------------------------------------------------------------------------
# Replaces the bypassable `Bash(rm -rf *)` deny with a real check that
# inspects the actual targets. Allows deep paths like `rm -rf node_modules`
# or `rm -rf ~/.cache/foo/bar` while blocking targets that wipe a user's
# entire workspace or system.

# Top-level home directories that should never be the target of rm/mv.
HOME_TOP='(Documents|Desktop|Downloads|Movies|Music|Pictures|Public|Library|Applications|Projects|projects|Code|code|work|src|repos|github|\.claude|\.config|\.ssh|\.aws|\.gnupg|\.kube|\.docker|\.cache|\.local)'

TOK_START='(^|[[:space:]"'\''=`(])'
TOK_END='([[:space:]"'\''$;|&)`]|$)'

DANGER_RE="${TOK_START}/${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}~/?${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}\\\$HOME/?${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}~/?\\*${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}\\\$HOME/?\\*${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}~/${HOME_TOP}/?${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}\\\$HOME/${HOME_TOP}/?${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}/Users/[^/[:space:]\"']+/?${TOK_END}"
DANGER_RE="${DANGER_RE}|${TOK_START}/Users/[^/[:space:]\"']+/${HOME_TOP}/?${TOK_END}"

RM_MV_RE='(^|[;&|`(]|[[:space:]])(rm|mv)([[:space:]]|$)'

if printf '%s' "$cmd_stripped" | grep -qE "$RM_MV_RE"; then
  if printf '%s' "$cmd_stripped" | grep -qE "$DANGER_RE"; then
    block "rm/mv targets a system or top-level home directory" \
          "Refusing to delete or move /, \$HOME, or top-level home dirs (Documents, Library, .ssh, .config, .claude, etc.). Deeper targets like ~/.cache/foo are allowed."
  fi
fi

exit 0
