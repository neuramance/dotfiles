#!/usr/bin/env bash
# PreToolUse hook for the Bash tool.
# Blocks two classes of dangerous commands:
#   1. Supply-chain "curl ... | sh" patterns (and equivalents).
#   2. Secret-path exfiltration via read/copy commands.
# Exit 0 = allow. Exit 2 = deny (stderr is shown to the model).

set -u

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[[ "$tool" != "Bash" ]] && exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

block() {
  printf 'Blocked by bash-guard: %s\n' "$1" >&2
  printf '%s\n' "$2" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Class 1: supply-chain pipe-to-shell
# ---------------------------------------------------------------------------

# 1a. curl/wget piped directly into a shell interpreter.
if printf '%s' "$cmd" | grep -qE '(^|[^A-Za-z0-9_/])(curl|wget)([^|]|\|\|)*\|[[:space:]]*(sudo[[:space:]]+(-[A-Za-z]+[[:space:]]+)*)?(sh|bash|zsh|fish|ksh|dash|csh|tcsh|ash)([[:space:]]|$|;|&|\|)'; then
  block "curl/wget output piped into a shell interpreter (supply-chain risk)" \
        "Mitigation: download to a file (curl -fsSL URL -o script.sh), inspect, then run explicitly."
fi

# 1b. Process substitution feeding curl/wget output to a shell.
if printf '%s' "$cmd" | grep -qE '(^|[^A-Za-z0-9_/])(sh|bash|zsh|fish|ksh|dash|csh|tcsh|ash)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*<\([[:space:]]*(curl|wget)'; then
  block "shell reading curl/wget output via process substitution" \
        "Mitigation: download to a file, inspect, then run."
fi

# 1c. eval / shell -c with command substitution from curl/wget.
if printf '%s' "$cmd" | grep -qE '(^|[^A-Za-z0-9_/])(eval|(sh|bash|zsh|fish|ksh|dash)[[:space:]]+-c)[[:space:]]+["'\''[:space:]]*\$\([[:space:]]*(curl|wget)'; then
  block "command substitution of curl/wget output passed to eval or shell -c" \
        "Mitigation: download to a file, inspect, then run."
fi

# 1d. curl/wget piped into a non-shell interpreter (python, ruby, node, perl, php).
if printf '%s' "$cmd" | grep -qE '(^|[^A-Za-z0-9_/])(curl|wget)([^|]|\|\|)*\|[[:space:]]*(python3?|ruby|node|perl|php)([[:space:]]|$|;|&|\|)'; then
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

if printf '%s' "$cmd" | grep -qE "$REDIR_RE"; then
  block "input redirection from a sensitive credential path" \
        "Refusing to read SSH keys, cloud creds, dotfile tokens, etc."
fi

if printf '%s' "$cmd" | grep -qE "$READ_CMD_RE"; then
  if printf '%s' "$cmd" | grep -qE "$SECRETS_RE"; then
    block "command appears to read or copy a sensitive credential path" \
          "Refusing to surface SSH keys, cloud creds, .env files, .pem/.key, etc. into agent output."
  fi
fi

exit 0
