#!/usr/bin/env bash
set -euo pipefail

herdr=(perl -e 'alarm shift; exec @ARGV or die "$ARGV[0]: $!\n"' 2 "$HERDR_BIN_PATH")

"${herdr[@]}" api snapshot |
  jq --raw-output0 '
    .result.snapshot
    | (.panes | INDEX(.pane_id)) as $panes
    | (.layouts | INDEX(.tab_id)) as $layouts
    | foreach .tabs[] as $tab ({}; .[$tab.workspace_id] += 1; [$tab, .[$tab.workspace_id]])
    | . as [$tab, $position]
    | ($panes[$layouts[$tab.tab_id].focused_pane_id].cwd // empty | split("/") | map(select(. != "")) | last // "/") as $directory
    | "\($position) \($directory)"
    | select(. != $tab.label)
    | $tab.tab_id, .
  ' |
  xargs -0 -r -n 2 "${herdr[@]}" tab rename >/dev/null
