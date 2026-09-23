#!/bin/sh
exec /usr/bin/security find-generic-password -a "$USER" -s codex-tfy-api-key -w
