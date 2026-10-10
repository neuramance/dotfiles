#!/usr/bin/env bash
set -uo pipefail
hook=${1:-$HOME/.claude/agent-gate.sh}
work=$(mktemp -d "${TMPDIR:-/tmp}/agent-gate-test.XXXXXX") || exit 2
work=$(cd "$work" && pwd -P) || exit 2
trap 'chmod -R u+rwx "$work" 2>/dev/null; rm -rf "$work"' EXIT
export TMPDIR=$work/tmp
mkdir -p "$TMPDIR" || exit 2
repo=$work/repo
runs=$work/runs
: >"$runs"
: >"$work/arguments"
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
printf '%s\n' "\$@" >"$work/arguments"
[ -f "$work/red" ] && exit 1
if [ -f "$work/slow" ]; then sleep 300 & echo \$! >"$work/sleep-pid"; wait; fi
[ -f "$work/create-during-run" ] && printf 'transient\n' >"$repo/appeared.txt"
if [ -f "$work/pycache-during-run" ]; then
  mkdir -p "$repo/.pytest_cache" "$repo/pkg/__pycache__" && printf x >>"$repo/.pytest_cache/v" && printf x >>"$repo/pkg/__pycache__/m.pyc"
fi
if [ -f "$work/cache-during-run" ]; then
  for cache in .cache .tmp .vite .vitest-cache; do
    mkdir -p "$repo/node_modules/\$cache" && printf x >>"$repo/node_modules/\$cache/entry"
  done
fi
if [ -f "$work/next-during-run" ]; then
  mkdir -p "$repo/.next/types" && printf x >>"$repo/.next/types/routes.ts"
fi
[ -f "$work/unverified" ] && echo '   not verified · notes.md: no focused check covers this file'
exit 0
EOF
chmod +x "$repo/scripts/agent-verify"
printf '.next/\nvendor/\nnode_modules/\ntarget/\n' >"$repo/.gitignore"
printf '{}\n' >"$repo/package.json"
printf 'one\n' >"$repo/tracked.txt"
printf 'module.exports = 1\n' >"$repo/node_modules/pkg/index.js"
commit() { git -C "$repo" -c user.name=agent-gate-test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm "$1"; }
git -C "$repo" add -A && commit initial || exit 2
failed=0
hook_event=Stop
stop_active=false
hook_path=$hook
session_id=
turn_id=
event_cwd=
unset event_file
stderr_pattern=
expect() {
  local name=$1 runs_expected=$2 status_expected=$3 pattern=${4:-} before output status ran payload
  before=$(wc -c <"$runs")
  payload=${event_payload-$(printf '{"hook_event_name":"%s","cwd":"%s","session_id":"%s","turn_id":"%s","stop_hook_active":%s,"tool_input":{"file_path":"%s"}}' \
    "$hook_event" "${event_cwd:-$repo}" "$session_id" "$turn_id" "$stop_active" "${event_file-$repo/tracked.txt}")}
  output=$(printf '%s' "$payload" |
    perl -e 'alarm 60; exec @ARGV' "$hook_path" 2>"$work/stderr")
  status=$?
  output+=$(<"$work/stderr")
  ran=$(($(wc -c <"$runs") - before))
  if [[ $ran == "$runs_expected" && $status == "$status_expected" && $output == *"$pattern"* && $(<"$work/stderr") == *"$stderr_pattern"* ]]; then
    echo "ok - $name"
  else
    echo "not ok - $name: expected runs=$runs_expected status=$status_expected output~'$pattern'; got runs=$ran status=$status output: $output"
    failed=1
  fi
}
stderr_pattern='agent-gate: invalid hook payload:'
for event_payload in '' '{' '[]' 'null' 'true' '1' '"Stop"' '{}'
do
  expect "invalid JSON payload is rejected: ${event_payload:-empty stdin}" 0 2
done
for event_payload in \
  "{\"hook_event_name\":\"Unknown\",\"cwd\":\"$repo\"}" \
  '{"hook_event_name":null}' \
  '{"hook_event_name":1}' \
  '{"hook_event_name":"Stop"}{"hook_event_name":"Stop"}'
do
  expect "invalid hook event is rejected: $event_payload" 0 2
done
for value in null false 1 '[]' '{}' '""'; do
  event_payload="{\"hook_event_name\":\"PostToolUse\",\"tool_input\":{\"file_path\":$value}}"
  expect "invalid file_path is rejected: $value" 0 2
done
for cwd in '' ',"cwd":"relative"' ',"cwd":null' ',"cwd":5'; do
  event_payload="{\"hook_event_name\":\"PostToolUse\",\"tool_input\":{\"file_path\":\"tracked.txt\"}$cwd}"
  expect "relative edit without absolute cwd is rejected: ${cwd:-absent cwd}" 0 2
done
unset event_payload
stderr_pattern=
hook_event=PostToolUse
event_file=tracked.txt
expect 'relative edit resolves against event cwd outside the process cwd' 1 0
if [[ $(<"$work/arguments") == "$repo/tracked.txt" ]]; then
  echo 'ok - relative edit passes the absolute file to the gate'
else
  echo "not ok - relative edit passes the absolute file to the gate: $(<"$work/arguments")"
  failed=1
fi
event_file=$repo/tracked.txt
touch "$work/unverified"
expect 'an edit the repository could not verify is reported to Claude' 1 0 '"additionalContext": "   not verified · notes.md: no focused check covers this file"'
codex_output=$(printf '{"hook_event_name":"PostToolUse","cwd":"%s","turn_id":"codex-turn","tool_input":{"file_path":"%s"}}' "$repo" "$repo/tracked.txt" | "$hook_path" 2>&1)
if [[ -z $codex_output ]]; then
  echo 'ok - a Codex edit the repository could not verify gets no Claude hook output'
else
  echo "not ok - a Codex edit the repository could not verify gets no Claude hook output: $codex_output"
  failed=1
fi
rm -f "$work/unverified"
verified_output=$(printf '{"hook_event_name":"PostToolUse","cwd":"%s","tool_input":{"file_path":"%s"}}' "$repo" "$repo/tracked.txt" | "$hook_path" 2>&1)
if [[ -z $verified_output ]]; then
  echo 'ok - a verified edit prints nothing'
else
  echo "not ok - a verified edit prints nothing: $verified_output"
  failed=1
fi
printf 'option-like\n' >"$repo/-z.ts"
event_file=-z.ts
expect 'option-like relative edit is verified from event cwd' 1 0
if [[ $(<"$work/arguments") == "$repo/-z.ts" && ! -s $work/stderr ]]; then
  echo 'ok - option-like edit passes an absolute argument without utility errors'
else
  echo "not ok - option-like edit passes an absolute argument without utility errors: $(<"$work/arguments") $(<"$work/stderr")"
  failed=1
fi
rm "$repo/-z.ts"
unset event_file
hook_event=Stop
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
mkdir -p "$repo/vendor/types" && printf 'stale\n' >"$repo/vendor/types/routes.ts"
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
ln -s "$work/missing" "$repo/vendor/broken-link"
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
git -C "$repo" -c user.name=agent-gate-test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m detached
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
touch "$work/cache-during-run"
printf 'cached\n' >"$repo/tracked.txt"
expect 'gate that writes only its tool caches runs' 1 0
expect 'state verified while the gate wrote only tool caches is skipped' 0 0 'skipped'
rm "$work/cache-during-run"
touch "$work/next-during-run"
printf 'next build\n' >"$repo/tracked.txt"
expect 'gate that creates Next build output runs' 1 0
expect 'second Stop skips after the gate created Next build output' 0 0 'skipped'
printf 'next source edit\n' >"$repo/tracked.txt"
expect 'tracked edit reruns a gate that rewrites Next build output' 1 0
expect 'Stop skips again after Next build output was rewritten' 0 0 'skipped'
rm "$work/next-during-run"
printf '[project]\nname = "x"\n' >"$repo/pyproject.toml"
expect 'python project runs the gate' 1 0
touch "$work/pycache-during-run"
printf 'python\n' >"$repo/tracked.txt"
expect 'gate that creates python caches runs' 1 0
expect 'caches first seen in the last run make the next stop run once more' 1 0
expect 'state verified while the gate rewrote only python caches is skipped' 0 0 'skipped'
rm "$work/pycache-during-run"
mkdir -p "$repo/.venv/lib/site-packages" && printf 'import os\n' >"$repo/.venv/lib/site-packages/extra.pth"
expect 'new .pth file in .venv runs the gate' 1 0
expect 'unchanged .venv is skipped again' 0 0 'skipped'
printf 'import sys\n' >"$repo/.venv/lib/site-packages/extra.pth"
expect 'rewritten .pth file in .venv runs the gate' 1 0
git -C "$repo" config agent-gate.stopDeadline 2
expect 'gate within its deadline passes' 1 0
touch "$work/slow"
printf 'five\n' >"$repo/tracked.txt"
expect 'gate past its deadline blocks the stop' 1 2 'FAIL [deadline]'
if kill -0 "$(cat "$work/sleep-pid")" 2>/dev/null; then
  echo "not ok - deadline leaves no process of the gate behind"
  kill "$(cat "$work/sleep-pid")"
  failed=1
else
  echo "ok - deadline leaves no process of the gate behind"
fi
stop_active=true
expect 'gate past its deadline on the retry ends the turn' 1 0 'still fails after a retry'
stop_active=false
kill "$(cat "$work/sleep-pid")" 2>/dev/null
rm "$work/slow"
pyrepo=$work/pyrepo
mkdir -p "$pyrepo/scripts" "$pyrepo/.venv/bin"
git -C "$pyrepo" init -q -b main
printf '#!/bin/sh\nexit 0\n' >"$pyrepo/scripts/agent-verify" && chmod +x "$pyrepo/scripts/agent-verify"
printf 'line-length = 88\n' >"$pyrepo/ruff.toml"
if real_ruff=$(command -v ruff); then
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$real_ruff" >"$pyrepo/.venv/bin/ruff" && chmod +x "$pyrepo/.venv/bin/ruff"
  printf 'import sys\nimport os\nx=[os.sep,sys.argv]\n' >"$pyrepo/mod.py"
  status=$(printf '{"hook_event_name":"PostToolUse","cwd":"%s","tool_input":{"file_path":"%s"}}' "$pyrepo" "$pyrepo/mod.py" |
    perl -e 'alarm 60; exec @ARGV' "$hook_path" >/dev/null 2>&1; echo $?)
  if [[ $status == 0 && $(<"$pyrepo/mod.py") == $'import os\nimport sys\n\nx = [os.sep, sys.argv]' ]]; then
    echo "ok - python edit is import-sorted and formatted before the gate"
  else
    echo "not ok - python edit is import-sorted and formatted before the gate: status=$status: $(<"$pyrepo/mod.py")"
    failed=1
  fi
else
  echo "ok - python formatting case skipped: ruff is not installed"
fi
git -C "$repo" config agent-gate.skipUnchanged false
git -C "$repo" config agent-gate.stopDeadline 280
unset event_file
mkdir "$work/nonrepo"
for name in B C D slow-one slow-two; do
  directory=$work/$name
  mkdir -p "$directory/scripts"
  git -C "$directory" init -q -b main
  printf 'one\n' >"$directory/tracked.txt"
  cat >"$directory/scripts/agent-verify" <<EOF
#!/bin/sh
printf x >>"$runs"
printf '%s\n' '$name' >>"$work/order"
if [ -f "$work/$name-slow" ]; then sleep 300 & echo \$! >"$work/$name-pid"; wait; fi
if [ -f "$work/$name-orphan" ]; then sleep 3 & echo \$! >"$work/$name-pid"; exit 0; fi
if [ -f "$work/$name-late" ]; then echo "$name passed and printed enough to move its offset"; (sleep 1; echo "LATE-FROM-$name") & exit 0; fi
[ ! -f "$work/$name-delay" ] || sleep 2
if [ -f "$work/$name-detached" ]; then perl -MPOSIX -e 'fork and exit; POSIX::setsid(); sleep 5' & exit 0; fi
[ ! -f "$work/$name-silent" ] || exit 1
if [ -f "$work/$name-whitespace" ]; then printf ' \t\n\n'; exit 1; fi
if [ -f "$work/$name-red" ]; then printf '%s\n' '$name failed'; exit 1; fi
exit 0
EOF
  chmod +x "$directory/scripts/agent-verify"
  git -C "$directory" add -A
  git -C "$directory" -c user.name=agent-gate-test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm initial
done
session_id=session_B
event_file=$work/B/tracked.txt
hook_event=PostToolUse
expect 'editing another repository records its session' 1 0
expect 'repeated edits in another repository still run focused checks' 1 0
hook_event=Stop
event_cwd=$work/nonrepo
expect 'Stop outside git gates the edited repository once' 1 0
session_id=different_session
expect 'a different session does not gate another sessions edits' 0 0
session_id=session_B
event_cwd=$repo
touch "$work/B-red"
stderr_pattern="agent-gate: $work/B"
expect 'Stop gates cwd and a failing edited repository' 2 2 'B failed'
stderr_pattern=
stop_active=true
expect 'a retry reports the failing edited repository' 2 0 "still fails after a retry; the task is incomplete\nagent-gate: $work/B"
stop_active=false
session_id=failed_edit
hook_event=PostToolUse
expect 'a failing focused check still records its repository' 1 2 'B failed'
hook_event=Stop
event_cwd=$work/nonrepo
expect 'Stop gates a repository recorded before focused failure' 1 2 'B failed'
rm "$work/B-red"
session_id=../escape
hook_event=PostToolUse
expect 'an invalid session id still runs its focused check' 1 0
if [[ -e $TMPDIR/escape || -e $TMPDIR/agent-gate/escape ]]; then
  echo 'not ok - invalid session id creates no record'
  failed=1
else
  echo 'ok - invalid session id creates no record'
fi
hook_event=Stop
expect 'an invalid session id provides no recorded roots' 0 0
for name in C D; do
  printf '#!/bin/sh\nexit 0\n' >"$work/$name/scripts/agent-gate.sh"
  chmod +x "$work/$name/scripts/agent-gate.sh"
done
mkdir "$work/C/.claude" "$work/D/.codex"
printf '{"command":"scripts/agent-gate.sh"}\n' >"$work/C/.claude/settings.json"
printf '{"command":"scripts/agent-gate.sh"}\n' >"$work/D/.codex/hooks.json"
session_id=delegation
event_cwd=$work/nonrepo
event_file=$work/C/tracked.txt
hook_event=PostToolUse
export CLAUDE_PROJECT_DIR=$work/C
expect 'Claude delegates an edit only when its adapter was loaded' 0 0
export CLAUDE_PROJECT_DIR=$work/nonrepo
expect 'Claude gates an edit whose adapter was not loaded' 1 0
hook_event=Stop
expect 'Claude gates a recorded repository whose adapter was not loaded' 1 0
export CLAUDE_PROJECT_DIR=$work/C
expect 'Claude delegates a recorded repository whose adapter was loaded' 0 0
session_id=
turn_id=codex_turn
event_cwd=$work/C
expect 'Codex ignores Claude adapter settings and inherited launch directory' 1 0
event_cwd=$work/D
expect 'Codex delegates to its loaded repository adapter' 0 0
event_cwd=$work/nonrepo
event_file=$work/D/tracked.txt
hook_event=PostToolUse
expect 'Codex gates edits outside its loaded repository' 1 0
turn_id=
hook_event=Stop
event_cwd=$work/B
touch "$work/B-silent"
stderr_pattern="agent-gate: $work/B"
expect 'silent failure has nonempty stderr diagnostics' 1 2 'exited non-zero without output'
stderr_pattern=
rm "$work/B-silent"
touch "$work/B-whitespace"
expect 'whitespace-only failure has useful diagnostics' 1 2 'exited non-zero without output'
rm "$work/B-whitespace"
touch "$work/B-orphan"
started=$SECONDS
expect 'a gate may finish before its background child' 1 0
if (( SECONDS - started < 3 )) && kill -0 "$(<"$work/B-pid")" 2>/dev/null; then
  echo 'ok - a background child neither delays the gate nor is killed by it'
else
  echo 'not ok - a background child neither delays the gate nor is killed by it'
  failed=1
fi
kill "$(<"$work/B-pid")" 2>/dev/null
rm "$work/B-orphan"
touch "$work/B-detached"
started=$SECONDS
expect 'a gate may leave a detached child holding its output' 1 0
if (( SECONDS - started < 4 )); then
  echo 'ok - a detached child does not delay the gate'
else
  echo 'not ok - a detached child does not delay the gate'
  failed=1
fi
rm "$work/B-detached"
session_id=session_B
expect 'cwd and recorded repository are deduplicated' 1 0
hook_event=PostToolUse
event_file=
cp "$TMPDIR/agent-gate/session_B" "$work/record-before"
event_payload=$(jq -n --arg cwd "$event_cwd" --arg session "$session_id" '{hook_event_name: "PostToolUse", cwd: $cwd, session_id: $session, tool_input: {command: "apply_patch data"}}')
expect 'other hosts without a file path do not verify' 0 0
unset event_payload
if cmp -s "$TMPDIR/agent-gate/session_B" "$work/record-before"; then
  echo 'ok - other hosts without a file path do not record'
else
  echo 'not ok - other hosts without a file path do not record'
  failed=1
fi
session_id=ordered
event_cwd=$work/nonrepo
export CLAUDE_PROJECT_DIR=$work/nonrepo
for name in C B C; do
  event_file=$work/$name/tracked.txt
  expect "record $name in first-seen order" 1 0
done
hook_event=Stop
: >"$work/order"
expect 'recorded repositories run once each' 2 0
if [[ $(<"$work/order") == $'C\nB' ]]; then
  echo 'ok - recorded repositories run in first-seen order'
else
  echo "not ok - recorded repositories run in first-seen order: $(<"$work/order")"
  failed=1
fi
for name in B C; do git -C "$work/$name" config agent-gate.skipUnchanged true; done
expect 'each recorded repository establishes its own green fingerprint' 2 0
stderr_pattern=
expect 'unchanged recorded repositories share one skip message' 0 0 "agent-gate: $work/C\nagent-gate: $work/B"
touch "$work/B-red" "$work/C-red"
for name in B C; do git -C "$work/$name" config agent-gate.skipUnchanged false; done
stderr_pattern="agent-gate: $work/C"$'\nC failed\n'"agent-gate: full log: $work/C/.git/agent-gate-failure.log"$'\n'"agent-gate: $work/B"$'\nB failed'
expect 'all failing repositories have separate headers and diagnostics' 2 2 'B failed'
stderr_pattern=
rm "$work/B-red" "$work/C-red"
mkdir -p "$TMPDIR/agent-gate"
printf '%s\n' "$work/missing" "$work/nonrepo" >>"$TMPDIR/agent-gate/$session_id"
expect 'missing and ungated recorded directories are ignored' 2 0
hook_event=PostToolUse
session_id=budget
for name in slow-one slow-two; do
  event_file=$work/$name/tracked.txt
  expect "record $name before its slow gate" 1 0
  git -C "$work/$name" config agent-gate.stopDeadline 5
  touch "$work/$name-slow"
done
hook_event=Stop
event_cwd=$repo
git -C "$repo" config agent-gate.stopDeadline 3
started=$SECONDS
stderr_pattern="FAIL [deadline] agent-gate: no time left to verify $work/slow-two"
expect 'Stop shares its deadline across repositories' 2 2 'FAIL [deadline]'
stderr_pattern=
if (( SECONDS - started < 8 )); then
  echo 'ok - shared Stop budget finishes in under eight seconds'
else
  echo 'not ok - shared Stop budget finishes in under eight seconds'
  failed=1
fi
if [[ -f $work/slow-one-pid ]] && ! kill -0 "$(<"$work/slow-one-pid")" 2>/dev/null; then
  echo 'ok - the timed-out gate leaves no process behind'
else
  echo 'not ok - the timed-out gate leaves no process behind'
  failed=1
fi
if [[ ! -e $work/slow-two-pid ]]; then
  echo 'ok - a repository reached with no time left is not started'
else
  echo 'not ok - a repository reached with no time left is not started'
  failed=1
fi
git -C "$work/slow-one" config agent-gate.stopDeadline 1
session_id=own_deadline
printf '%s\n' "$work/slow-one" >"$TMPDIR/agent-gate/$session_id"
event_cwd=$work/nonrepo
expect 'a recorded repository keeps its own deadline' 1 2 'within 1 s'
mkdir -p "$work/plain/scripts"
printf '#!/bin/sh\nprintf x >>"%s"\n' "$runs" >"$work/plain/scripts/agent-verify"
chmod +x "$work/plain/scripts/agent-verify"
session_id=plain
printf '%s\n' "$work/plain" >"$TMPDIR/agent-gate/$session_id"
expect 'a recorded directory that is not a repository toplevel is not run' 0 0
spaced="$work/my repo"
mkdir -p "$spaced/scripts"
git -C "$spaced" init -q -b main
cp "$work/plain/scripts/agent-verify" "$spaced/scripts/agent-verify"
session_id=
event_cwd=$spaced
expect 'a repository path with a space passes its green gate' 1 0
hook_event=PostToolUse
event_cwd=$work/nonrepo
event_file=$work/B/tracked.txt
session_id=unreadable
expect 'an edit records its repository for the unreadable case' 1 0
chmod 000 "$TMPDIR/agent-gate/$session_id"
hook_event=Stop
expect 'an unreadable record fails loudly' 0 2 'cannot read'
chmod 600 "$TMPDIR/agent-gate/$session_id"
hook_event=PostToolUse
session_id=blocked
mkdir "$work/blocked" && : >"$work/blocked/agent-gate"
export TMPDIR=$work/blocked
expect 'a record that cannot be written fails loudly' 0 2 'cannot record'
mkdir "$work/linked-state" "$work/real-state" && ln -s "$work/real-state" "$work/linked-state/agent-gate"
export TMPDIR=$work/linked-state
expect 'a symlinked record directory is refused' 0 2 'cannot record'
export TMPDIR=$work/tmp
git -C "$work/B" worktree add -q --detach "$work/B-tree"
session_id=worktree
event_file=$work/B-tree/tracked.txt
expect 'an edit in a linked worktree runs its focused check' 1 0
if [[ ! -e $TMPDIR/agent-gate/$session_id ]]; then
  echo 'ok - a linked worktree is not recorded'
else
  echo 'not ok - a linked worktree is not recorded'
  failed=1
fi
unset CLAUDE_PROJECT_DIR
session_id=
event_cwd=$work/C
event_file=$work/C/tracked.txt
expect 'without CLAUDE_PROJECT_DIR Claude delegates by the event cwd' 0 0
event_cwd=$work/nonrepo
expect 'without CLAUDE_PROJECT_DIR Claude gates a repository outside the event cwd' 1 0
newline_repo=$work/new$'\n'line
mkdir -p "$newline_repo/scripts"
git -C "$newline_repo" init -q -b main
cp "$work/plain/scripts/agent-verify" "$newline_repo/scripts/agent-verify"
status=$(jq -n --arg cwd "$newline_repo" '{hook_event_name: "Stop", cwd: $cwd}' |
  perl -e 'alarm 60; exec @ARGV' "$hook_path" 2>"$work/stderr" >/dev/null; echo $?)
if [[ $status == 2 && $(<"$work/stderr") == *'contains a newline'* ]]; then
  echo 'ok - a cwd repository path with a newline fails loudly'
else
  echo "not ok - a cwd repository path with a newline fails loudly: status=$status $(<"$work/stderr")"
  failed=1
fi
status=$(jq -n --arg file "$newline_repo/tracked" '{hook_event_name: "PostToolUse", session_id: "newline", tool_input: {file_path: $file}}' |
  perl -e 'alarm 60; exec @ARGV' "$hook_path" 2>"$work/stderr" >/dev/null; echo $?)
if [[ $status == 2 && $(<"$work/stderr") == *'cannot record'* ]]; then
  echo 'ok - a repository path with a newline is not recorded'
else
  echo "not ok - a repository path with a newline is not recorded: status=$status $(<"$work/stderr")"
  failed=1
fi
export CLAUDE_PROJECT_DIR=$work/nonrepo
hook_event=Stop
session_id=unreadable
chmod 000 "$TMPDIR/agent-gate/$session_id"
stop_active=true
expect 'an unreadable record on the retry ends the turn' 0 0 'cannot read'
stop_active=false
chmod 600 "$TMPDIR/agent-gate/$session_id"
mkdir "$work/readonly" && chmod 500 "$work/readonly"
export TMPDIR=$work/readonly
session_id=
stop_active=true
expect 'an unwritable TMPDIR does not block a Stop with nothing to gate' 0 0
stop_active=false
hook_event=PostToolUse
event_file=$work/nonrepo/file.txt
expect 'an unwritable TMPDIR does not block an edit outside any repository' 0 0
export TMPDIR=$work/tmp
session_id=late
for name in C B; do
  event_file=$work/$name/tracked.txt
  expect "record $name for the late output case" 1 0
done
touch "$work/C-late" "$work/B-delay" "$work/B-red"
hook_event=Stop
expect 'a failing repository after one with a late child still fails' 2 2 'B failed'
if [[ $(<"$work/stderr") != *LATE-FROM-C* ]]; then
  echo 'ok - output from an earlier repository never lands in a later repository diagnostics'
else
  echo "not ok - output from an earlier repository never lands in a later repository diagnostics: $(<"$work/stderr")"
  failed=1
fi
rm "$work/C-late" "$work/B-delay" "$work/B-red"
rm -f "$work/B-pid"
touch "$work/B-slow"
jq -n --arg file "$work/B/tracked.txt" '{hook_event_name: "PostToolUse", tool_input: {file_path: $file}}' >"$work/event.json"
perl -e 'setpgrp; exec @ARGV' "$hook_path" <"$work/event.json" >/dev/null 2>&1 &
hook_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s $work/B-pid ]] && break; sleep 0.5; done
kill -TERM -"$hook_pid" 2>/dev/null
wait "$hook_pid" 2>/dev/null
sleep 1
if [[ -s $work/B-pid ]] && ! kill -0 "$(<"$work/B-pid")" 2>/dev/null; then
  echo 'ok - killing the hook also stops its gate'
else
  echo 'not ok - killing the hook also stops its gate'
  [[ -s $work/B-pid ]] && kill "$(<"$work/B-pid")" 2>/dev/null
  failed=1
fi
rm "$work/B-slow"
mkdir -p "$work/E/scripts" "$work/slowbin"
git -C "$work/E" init -q -b main
: >"$work/E/rustfmt.toml"
printf 'fn main() {}\n' >"$work/E/x.rs"
printf '#!/bin/sh\nexec sleep 300\n' >"$work/E/scripts/agent-verify"
printf '#!/bin/sh\nexec sleep 60\n' >"$work/slowbin/rustfmt"
chmod +x "$work/E/scripts/agent-verify" "$work/slowbin/rustfmt"
saved_path=$PATH
export PATH=$work/slowbin:$PATH
started=$SECONDS
status=$(jq -n --arg file "$work/E/x.rs" '{hook_event_name: "PostToolUse", tool_input: {file_path: $file}}' |
  perl -e 'alarm 60; exec @ARGV' "$hook_path" 2>"$work/stderr" >/dev/null; echo $?)
elapsed=$((SECONDS - started))
export PATH=$saved_path
if [[ $status == 2 && $elapsed -lt 30 && $(<"$work/stderr") == *'did not finish within'* ]]; then
  echo 'ok - a slow formatter and a hung focused check still finish inside the 30 s hook timeout'
else
  echo "not ok - a slow formatter and a hung focused check still finish inside the 30 s hook timeout: status=$status elapsed=$elapsed $(<"$work/stderr")"
  failed=1
fi
logrepo=$work/logrepo
mkdir -p "$logrepo/scripts"
git -C "$logrepo" init -q -b main
for ((i = 1; i <= 150; i++)); do printf 'diagnostic %03d\n' "$i"; done >"$work/complete-output"
cat >"$logrepo/scripts/agent-verify" <<EOF
#!/bin/sh
printf x >>"$runs"
cat "$work/complete-output"
[ ! -f "$work/log-slow" ] || exec sleep 300
exit 1
EOF
chmod +x "$logrepo/scripts/agent-verify"
session_id=
event_cwd=$logrepo
event_file=$logrepo/file.txt
full_log=$logrepo/.git/agent-gate-failure.log
printf 'do not overwrite\n' >"$work/protected"
ln -s "$work/protected" "$full_log"
for hook_event in PostToolUse Stop; do
  expect "$hook_event failure reports its full log" 1 2 "agent-gate: full log: $full_log"
  if [[ -f $full_log && ! -L $full_log ]] && cmp -s "$work/complete-output" "$full_log" &&
    [[ $(stat -c %a "$full_log" 2>/dev/null || stat -f %Lp "$full_log") == 600 && $(<"$work/protected") == 'do not overwrite' &&
       $(tail -n 1 "$work/stderr") == "agent-gate: full log: $full_log" && $(wc -l <"$work/stderr") -le 103 ]]; then
    echo "ok - $hook_event preserves complete private output without following symlinks"
  else
    echo "not ok - $hook_event preserves complete private output without following symlinks"
    failed=1
  fi
  printf 'replacement\n' >>"$work/complete-output"
done
touch "$work/log-slow"
git -C "$logrepo" config agent-gate.stopDeadline 1
expect 'deadline failure reports its full log' 1 2 "agent-gate: full log: $full_log"
if [[ -f $full_log && $(<"$full_log") == *replacement* && $(<"$full_log") == *'FAIL [deadline]'* &&
      $(tail -n 1 "$work/stderr") == "agent-gate: full log: $full_log" ]]; then
  echo 'ok - deadline log retains gate output and the timeout diagnostic'
else
  echo 'not ok - deadline log retains gate output and the timeout diagnostic'
  failed=1
fi
rm "$work/log-slow" "$full_log"
printf '#!/bin/sh\nprintf x >>"%s"\nexit 0\n' "$runs" >"$logrepo/scripts/agent-verify"
for hook_event in PostToolUse Stop; do
  expect "$hook_event successful gate runs without creating a failure log" 1 0
  if [[ ! -e $full_log ]]; then
    echo "ok - $hook_event success leaves no new failure log"
  else
    echo "not ok - $hook_event success leaves no new failure log"
    failed=1
  fi
done
if [[ -z $(find "$TMPDIR" -maxdepth 1 -name 'agent-gate.*' -print) ]]; then
  echo 'ok - temporary output logs are removed after failures and successes'
else
  echo 'not ok - temporary output logs are removed after failures and successes'
  failed=1
fi
signalrepo=$work/signals
mkdir -p "$signalrepo/scripts"
git -C "$signalrepo" init -q -b main
cat >"$signalrepo/scripts/agent-verify" <<'EOF'
#!/usr/bin/env perl
use strict;
use warnings;
my $child = fork // die $!;
if ($child == 0) {
  setpgrp;
  $SIG{$_} = sub {
    open my $exit, ">", "child-exited" or die $!;
    print {$exit} "exited\n";
    close $exit;
    exit 0;
  } for qw(TERM INT HUP);
  open my $pid, ">", "child-pid" or die $!;
  print {$pid} "$$\n";
  close $pid;
  sleep 60 while 1;
}
$SIG{TERM} = sub {
  sleep 3 if -e "delayed";
  kill "TERM", -$child;
  waitpid $child, 0;
  sleep 60 if -e "stubborn";
  open my $exit, ">", "supervisor-exited" or die $!;
  print {$exit} "cleaned\n";
  close $exit;
  exit 0;
};
open my $pid, ">", "supervisor-pid" or die $!;
print {$pid} "$$\n";
close $pid;
sleep 60 while 1;
EOF
chmod +x "$signalrepo/scripts/agent-verify"
jq -n --arg file "$signalrepo/file.txt" '{hook_event_name: "PostToolUse", tool_input: {file_path: $file}}' >"$work/signal-event.json"
for signal_case in TERM:pid INT:pid HUP:pid TERM:group INT:group HUP:group delayed:pid delayed:group; do
  signal=${signal_case%:*}
  target=${signal_case#*:}
  rm -f "$signalrepo/child-pid" "$signalrepo/supervisor-pid" "$signalrepo/child-exited" "$signalrepo/supervisor-exited" "$signalrepo/delayed"
  [[ $signal != delayed ]] || { touch "$signalrepo/delayed"; signal=TERM; }
  perl -e 'setpgrp; $SIG{INT} = "DEFAULT"; alarm 45; exec @ARGV' "$hook_path" <"$work/signal-event.json" >"$work/signal-stdout" 2>"$work/signal-stderr" &
  hook_pid=$!
  for ((i = 0; i < 100; i++)); do
    [[ -s $signalrepo/child-pid && -s $signalrepo/supervisor-pid ]] && break
    sleep 0.05
  done
  target_pid=$hook_pid
  [[ $target != group ]] || target_pid=-$hook_pid
  kill -"$signal" -- "$target_pid" 2>/dev/null
  wait "$hook_pid" 2>/dev/null
  status=$?
  status_expected=143
  [[ $signal != INT ]] || status_expected=130
  for ((i = 0; i < 40; i++)); do
    [[ -s $signalrepo/child-exited && -s $signalrepo/supervisor-exited ]] &&
      ! kill -0 "$(<"$signalrepo/child-pid")" 2>/dev/null &&
      ! kill -0 "$(<"$signalrepo/supervisor-pid")" 2>/dev/null && break
    sleep 0.05
  done
  if [[ $status == "$status_expected" && -s $signalrepo/child-exited && -s $signalrepo/supervisor-exited ]] &&
    ! kill -0 "$(<"$signalrepo/child-pid")" 2>/dev/null && ! kill -0 "$(<"$signalrepo/supervisor-pid")" 2>/dev/null &&
    ! kill -0 -- "-$hook_pid" 2>/dev/null; then
    echo "ok - interruption $signal_case reaps the gate and its detached child with status $status_expected"
  else
    echo "not ok - interruption $signal_case reaps the gate and its detached child with status $status_expected: got status=$status child-exited=$([[ -s $signalrepo/child-exited ]] && echo yes || echo no) supervisor-exited=$([[ -s $signalrepo/supervisor-exited ]] && echo yes || echo no)"
    failed=1
  fi
  [[ ! -s $signalrepo/supervisor-pid ]] || kill -TERM -- "-$(<"$signalrepo/supervisor-pid")" 2>/dev/null
  [[ ! -s $signalrepo/child-pid ]] || kill -TERM -- "-$(<"$signalrepo/child-pid")" 2>/dev/null
  kill -TERM -- "-$hook_pid" 2>/dev/null
  for ((i = 0; i < 80; i++)); do
    [[ -s $signalrepo/child-pid && -s $signalrepo/supervisor-pid ]] &&
      ! kill -0 "$(<"$signalrepo/child-pid")" 2>/dev/null &&
      ! kill -0 "$(<"$signalrepo/supervisor-pid")" 2>/dev/null && break
    sleep 0.05
  done
done
touch "$signalrepo/delayed"
git -C "$signalrepo" config agent-gate.stopDeadline 1
rm -f "$signalrepo/child-exited" "$signalrepo/supervisor-exited"
status=$(jq -n --arg cwd "$signalrepo" '{hook_event_name: "Stop", cwd: $cwd}' |
  perl -e 'alarm 30; exec @ARGV' "$hook_path" >"$work/signal-stdout" 2>"$work/signal-stderr"; echo $?)
if [[ $status == 2 && -s $signalrepo/child-exited && -s $signalrepo/supervisor-exited ]] &&
  ! kill -0 "$(<"$signalrepo/child-pid")" 2>/dev/null && ! kill -0 "$(<"$signalrepo/supervisor-pid")" 2>/dev/null; then
  echo 'ok - deadline allows three-second supervisor cleanup of its detached child'
else
  echo "not ok - deadline allows three-second supervisor cleanup of its detached child: status=$status child-exited=$([[ -s $signalrepo/child-exited ]] && echo yes || echo no) supervisor-exited=$([[ -s $signalrepo/supervisor-exited ]] && echo yes || echo no)"
  failed=1
fi
kill -TERM -- "-$(<"$signalrepo/child-pid")" 2>/dev/null
rm -f "$signalrepo/delayed" "$signalrepo/child-exited" "$signalrepo/supervisor-exited"
touch "$signalrepo/stubborn"
started=$SECONDS
status=$(jq -n --arg cwd "$signalrepo" '{hook_event_name: "Stop", cwd: $cwd}' |
  perl -e 'alarm 30; exec @ARGV' "$hook_path" >"$work/signal-stdout" 2>"$work/signal-stderr"; echo $?)
elapsed=$((SECONDS - started))
if [[ $status == 2 && -s $signalrepo/child-exited && ! -e $signalrepo/supervisor-exited && $elapsed -ge 9 && $elapsed -lt 13 ]] &&
  ! kill -0 "$(<"$signalrepo/child-pid")" 2>/dev/null && ! kill -0 "$(<"$signalrepo/supervisor-pid")" 2>/dev/null; then
  echo 'ok - deadline kills and reaps a stubborn supervisor after eight seconds of grace'
else
  echo "not ok - deadline kills and reaps a stubborn supervisor after eight seconds of grace: status=$status elapsed=$elapsed"
  failed=1
fi
if [[ -z $(find "$TMPDIR" -maxdepth 1 -name 'agent-gate.*' -print) ]]; then
  echo 'ok - interrupted runs remove their temporary logs'
else
  echo 'not ok - interrupted runs remove their temporary logs'
  failed=1
fi
exit "$failed"
