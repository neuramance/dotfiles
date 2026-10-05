#!/bin/sh
if [ -x /usr/bin/security ]; then
  exec /usr/bin/security find-generic-password -a "$USER" -s codex-tfy-api-key -w
fi
. "$HOME/.zsh_secrets"
printf '%s\n' "${TFY_API_KEY:?is not set in ~/.zsh_secrets}"
