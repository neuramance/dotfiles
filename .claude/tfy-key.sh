#!/bin/sh
. "$HOME/.zsh_secrets"
printf '%s\n' "${TFY_API_KEY:?is not set in ~/.zsh_secrets}"
