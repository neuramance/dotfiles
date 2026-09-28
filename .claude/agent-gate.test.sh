#!/usr/bin/env bash
set -uo pipefail
hook=${1:-$HOME/.claude/agent-gate.sh}
work=$(mktemp -d "${TMPDIR:-/tmp}/agent-gate-test.XXXXXX") || exit 2
trap 'chmod -R u+rwx "$work" 2>/dev/null; rm -rf "$work"' EXIT
repo=$work/repo
runs=$work/runs
: >"$runs"
mkdir -p "$repo/scripts" "$repo/node_modules/pkg" "$work/bin" || exit 2
printf 'v1\n' >"$work/node-version"
printf '2026-01-01\n' >"$work/today"
printf '#!/bin/sh\ncat "%s"\n' "$work/node-version" >"$work/bin/node"
printf '#!/bin/sh\necho 1.0.0\n' >"$work/bin/bun"
printf '#!/bin/sh\ncat "%s"\n' "$work/today" >"$work/bin/date"
printf '#!/bin/sh\necho one\n' >"$work/bin/helper-tool"
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"
git -C "$repo" init -q -b main || exit 2
cat >"$repo/scripts/agent-verify" <<EOF
#!/bin/sh
printf x >>"$runs"
[ -f "$work/red" ] && exit 1
[ -f "$work/create-during-run" ] && printf 'transient\n' >"$repo/appeared.txt"
exit 0
EOF
chmod +x "$repo/scripts/agent-verify"
printf '.next/\nvendor/\nnode_modules/\ntarget/\n' >"$repo/.gitignore"
printf '{}\n' >"$repo/package.json"
printf 'one\n' >"$repo/tracked.txt"
printf 'module.exports = 1\n' >"$repo/node_modules/pkg/index.js"
commit() { git -C "$repo" -c user.name=agent-gate-test -c user.email=test@example.invalid commit -qm "$1"; }
git -C "$repo" add -A && commit initial || exit 2
failed=0
hook_event=Stop
stop_active=false
hook_path=$hook
expect() {
  local name=$1 runs_expected=$2 status_expected=$3 pattern=${4:-} before output status ran
  before=$(wc -c <"$runs")
  output=$(printf '{"hook_event_name":"%s","cwd":"%s","stop_hook_active":%s,"tool_input":{"file_path":"%s"}}' \
    "$hook_event" "$repo" "$stop_active" "$repo/tracked.txt" | perl -e 'alarm 60; exec @ARGV' "$hook_path" 2>&1)
  status=$?
  ran=$(($(wc -c <"$runs") - before))
  if [[ $ran == "$runs_expected" && $status == "$status_expected" && $output == *"$pattern"* ]]; then
    echo "ok - $name"
  else
    echo "not ok - $name: expected runs=$runs_expected status=$status_expected output~'$pattern'; got runs=$ran status=$status output: $output"
    failed=1
  fi
}
expect 'without opt-in the first Stop runs the gate' 1 0
expect 'without opt-in an unchanged Stop still runs the gate' 1 0
git -C "$repo" config agent-gate.skipUnchanged true
expect 'first opted-in Stop runs the gate' 1 0
expect 'unchanged checkout skips the gate and says so' 0 0 'skipped'
export COLUMNS=7 LINES=3 CLAUDE_EFFORT=high CLAUDE_CODE_SESSION_ID=other CLAUDE_PID=1 TRACEPARENT=00-x TRACESTATE=x
expect 'per-spawn Claude variables still skip' 0 0 'skipped'
unset COLUMNS LINES CLAUDE_EFFORT CLAUDE_CODE_SESSION_ID CLAUDE_PID TRACEPARENT TRACESTATE
printf 'two\n' >"$repo/tracked.txt"
expect 'edited tracked file runs the gate' 1 0
cp -p "$repo/tracked.txt" "$work/reference"
printf 'tw2\n' >"$repo/tracked.txt"
touch -r "$work/reference" "$repo/tracked.txt"
expect 'same-size edit with restored mtime runs the gate' 1 0
printf 'new\n' >"$repo/untracked.txt"
expect 'new untracked file runs the gate' 1 0
rm "$repo/untracked.txt"
expect 'deleted file runs the gate' 1 0
mkdir "$repo/empty"
expect 'new empty directory runs the gate' 1 0
rmdir "$repo/empty"
expect 'removed empty directory runs the gate' 1 0
mkdir -p "$repo/.next/types" && printf 'stale\n' >"$repo/.next/types/routes.ts"
expect 'ignored file the gate can read runs the gate' 1 0
mkdir -p "$repo/vendor/nested" && git -C "$repo/vendor/nested" init -q && printf 'a\n' >"$repo/vendor/nested/file.ts"
expect 'new nested repository runs the gate' 1 0
printf 'b\n' >"$repo/vendor/nested/file.ts"
expect 'edit inside a nested repository runs the gate' 1 0
printf 'module.exports = 2\n' >"$repo/node_modules/pkg/index.js"
expect 'dependency change runs the gate' 1 0
mkdir -p "$repo/node_modules/.cache/tool" && printf 'cache\n' >"$repo/node_modules/.cache/tool/entry"
expect 'gate cache writes alone still skip' 0 0 'skipped'
mkdir -p "$repo/target" && printf 'source\n' >"$repo/target/input.txt"
expect 'target directory outside a Cargo repository runs the gate' 1 0
printf 'changed\n' >"$repo/target/input.txt"
expect 'edit inside target outside a Cargo repository runs the gate' 1 0
printf 'outside\n' >"$work/outside.txt"
ln -s "$work/outside.txt" "$repo/linked.txt"
expect 'new symlink runs the gate' 1 0
printf 'changed outside\n' >"$work/outside.txt"
expect 'changed symlink target outside the checkout runs the gate' 1 0
mkdir "$work/outside-dir" && printf 'ok\n' >"$work/outside-dir/flag"
ln -s "$work/outside-dir" "$repo/linked-dir"
expect 'new symlinked directory runs the gate' 1 0
printf 'broken\n' >"$work/outside-dir/flag"
expect 'edit behind a symlinked directory outside the checkout runs the gate' 1 0
ln -s "$work/missing" "$repo/.next/broken-link"
expect 'new broken symlink in an ignored directory runs the gate' 1 0
printf 'staged\n' >"$repo/staged.txt"
expect 'new file before staging runs the gate' 1 0
git -C "$repo" add staged.txt
expect 'index-only change runs the gate' 1 0
printf 'worktree\n' >"$repo/staged.txt"
expect 'edit after staging runs the gate' 1 0
restaged=$(printf 'restaged\n' | git -C "$repo" hash-object -w --stdin)
git -C "$repo" update-index --cacheinfo "100644,$restaged,staged.txt"
expect 'restaged blob with an unchanged status runs the gate' 1 0
commit staged
expect 'commit runs the gate' 1 0
git -C "$repo" branch other
expect 'new branch runs the gate' 1 0
git -C "$repo" switch -q other
expect 'switching to a branch at the same commit runs the gate' 1 0
git -C "$repo" switch -q --detach
expect 'detaching HEAD runs the gate' 1 0
git -C "$repo" -c user.name=agent-gate-test -c user.email=test@example.invalid commit -q --allow-empty -m detached
expect 'detached commit runs the gate' 1 0
git -C "$repo" switch -q main
expect 'returning to main runs the gate' 1 0
git -C "$repo" update-ref refs/remotes/origin/main HEAD
expect 'moved ref runs the gate' 1 0
printf 'excludable\n' >"$repo/excludable.txt"
expect 'new file before an exclude rule runs the gate' 1 0
printf 'excludable.txt\n' >>"$repo/.git/info/exclude"
expect 'exclude rule change runs the gate' 1 0
git -C "$repo" config core.hooksPath hooks
expect 'git config change runs the gate' 1 0
printf 'v2\n' >"$work/node-version"
expect 'toolchain version change runs the gate' 1 0
printf '#!/bin/sh\necho two\n' >"$work/bin/helper-tool"
expect 'replaced tool on PATH runs the gate' 1 0
printf '2026-01-02\n' >"$work/today"
expect 'new UTC day runs the gate' 1 0
export AGENT_GATE_TEST_VARIABLE=1
expect 'environment change runs the gate' 1 0
unset AGENT_GATE_TEST_VARIABLE
expect 'environment restored runs the gate' 1 0
cp "$hook" "$work/hook-copy.sh" && printf ':\n' >>"$work/hook-copy.sh" && chmod +x "$work/hook-copy.sh"
hook_path=$work/hook-copy.sh
expect 'changed hook runs the gate' 1 0
hook_path=$hook
expect 'original hook runs the gate again' 1 0
hook_event=PostToolUse
expect 'focused edit check is never skipped' 1 0
hook_event=Stop
mkdir "$repo/locked" && chmod 000 "$repo/locked"
expect 'unreadable directory runs the gate' 1 0
expect 'unreadable directory never skips' 1 0
chmod 755 "$repo/locked" && rmdir "$repo/locked"
expect 'checkout restored to its last green state skips' 0 0 'skipped'
printf 'three\n' >"$repo/tracked.txt"
touch "$work/red"
expect 'red gate blocks the stop' 1 2
stop_active=true
expect 'red state is rechecked, not skipped' 1 0 'still fails after a retry'
stop_active=false
rm "$work/red"
expect 'fixed gate runs and passes' 1 0
expect 'fixed state is then skipped' 0 0 'skipped'
touch "$work/create-during-run"
printf 'four\n' >"$repo/tracked.txt"
expect 'gate passes while a file appears under it' 1 0
rm "$work/create-during-run" "$repo/appeared.txt"
expect 'start state of a run that saw a transient file is not trusted' 1 0
expect 'state verified without concurrent change is skipped' 0 0 'skipped'
exit "$failed"
