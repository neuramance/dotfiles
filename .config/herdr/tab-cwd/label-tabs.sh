#!/usr/bin/env bash
set -euo pipefail

herdr=(perl -e 'alarm shift; exec @ARGV or die "$ARGV[0]: $!\n"' 2 "$HERDR_BIN_PATH")

"${herdr[@]}" api snapshot |
  jq --raw-output0 '
    .result.snapshot
    | (.panes | INDEX(.pane_id)) as $panes
    | (.tabs | INDEX(.tab_id)) as $tabs
    | .layouts[]
    | ($panes[.focused_pane_id].cwd // empty | split("/") | map(select(. != "")) | last // "/") as $label
    | select($tabs[.tab_id].label != $label)
    | .tab_id, $label
  ' |
  xargs -0 -r -n 2 "${herdr[@]}" tab rename >/dev/null
