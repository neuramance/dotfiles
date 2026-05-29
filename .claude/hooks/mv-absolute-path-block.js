#!/usr/bin/env node
'use strict';

// mv-absolute-path-block.js — PreToolUse hook (matcher: Bash, if: Bash(mv *))
// Blocks `mv` commands where any argument is an absolute path rooted outside
// the project directory. Directs the user to check the project root.

const path = require('path');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => { raw += d; });
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(raw); } catch { process.exit(0); }
  if (data.tool_name !== 'Bash') process.exit(0);

  const fullCmd = String(data.tool_input?.command ?? '').trim();
  if (!fullCmd) process.exit(0);

  const cwd = process.cwd();
  const cwdWithSep = cwd + path.sep;

  // Split on command separators and inspect each segment independently.
  const segments = fullCmd.split(/;|&&|\|\|/).map(s => s.trim()).filter(Boolean);

  for (const segment of segments) {
    const tokens = segment.split(/\s+/);
    const mvIdx = tokens.findIndex(t => t === 'mv');
    if (mvIdx === -1) continue;

    // Arguments after 'mv', skipping flags (-n, -f, -v, etc.)
    const args = tokens.slice(mvIdx + 1).filter(t => !t.startsWith('-'));

    const offendingArg = args.find(arg => {
      return arg.startsWith('/') && arg !== cwd && !arg.startsWith(cwdWithSep)
    });

    if (offendingArg) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason:
            'Please check that you are in the project root directory and then use a relative path instead.',
        },
      }));
      process.exit(0);
    }
  }

  process.exit(0);
});
