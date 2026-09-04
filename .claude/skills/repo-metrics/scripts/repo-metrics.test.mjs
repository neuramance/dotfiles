import assert from "node:assert/strict";
import { test } from "node:test";
import { execFileSync, spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { countStylex } from "./stylex.mjs";

for (const extension of [
  "ts",
  "tsx",
  "mts",
  "cts",
  "js",
  "jsx",
  "mjs",
  "cjs",
]) {
  test(`counts all StyleX definition APIs in ${extension}`, () => {
    const source = [
      "import * as sx from '@stylexjs/stylex'",
      "const styles = sx.create({",
      "  box: {",
      "    color: 'red',",
      "  },",
      "})",
      "const vars = sx.defineVars({ color: 'red' })",
      "const constants = sx.defineConsts({ query: '@media (width > 1px)' })",
      "const animation = sx.keyframes({ to: { opacity: 1 } })",
      "const theme = sx.createTheme(vars, { color: 'blue' })",
      "sx.props(styles.box)",
    ].join("\n");
    assert.equal(countStylex(`fixture.${extension}`, source), 9);
  });
}

test("recognizes named, default, and namespace aliases without counting shadowed names", () => {
  const source = [
    "import sx, { create as make, keyframes as frames } from '@stylexjs/stylex'",
    "sx.create({ box: { color: 'red' } })",
    "make({ box: { color: 'blue' } })",
    "frames({ to: { opacity: 1 } })",
    "function unrelated(sx, make, frames) {",
    "  sx.create({ box: {} })",
    "  make({ box: {} })",
    "  frames({ to: {} })",
    "}",
  ].join("\n");
  assert.equal(countStylex("fixture.tsx", source), 3);
});

test("recognizes CommonJS bindings and static bracket access", () => {
  const source = [
    "const sx = require('@stylexjs/stylex')",
    "const { create: make, keyframes } = require('@stylexjs/stylex')",
    "sx['create']({ box: { color: 'red' } })",
    "make({ box: { color: 'blue' } })",
    "keyframes({ to: { opacity: 1 } })",
  ].join("\n");
  assert.equal(countStylex("fixture.cjs", source), 3);
  assert.equal(
    countStylex("fixture.cjs", `function require() {}\n${source}`),
    0,
  );
});

test("does not identify lookalikes, type-only imports, or props as definitions", () => {
  const source = [
    "import type { create } from '@stylexjs/stylex'",
    "import { type keyframes, props } from '@stylexjs/stylex'",
    "import * as stylex from 'another-package'",
    "const text = 'stylex.create({ box: {} })'",
    "stylex.create({ box: {} })",
    "create({ box: {} })",
    "keyframes({ to: {} })",
    "props({})",
  ].join("\n");
  assert.equal(countStylex("fixture.ts", source), 0);
});

test("counts syntax lines once, excluding blanks and comments while retaining literal contents", () => {
  const source = [
    "import * as sx from '@stylexjs/stylex'",
    "const styles = sx.create({",
    "  // a comment",
    "",
    "  box: {",
    "    /** a comment */",
    "    color: 'red', // an inline comment",
    "    content: `first",
    "// literal text",
    "last`,",
    "  },",
    "})",
    "sx.create({ box: { animationName: sx.keyframes({ to: {} }) } }); sx.defineVars({ color: 'red' })",
  ].join("\r\n");
  assert.equal(countStylex("fixture.tsx", source), 9);
});

test("does not fabricate a count from malformed StyleX source", () => {
  assert.throws(
    () =>
      countStylex(
        "broken.ts",
        "import * as sx from '@stylexjs/stylex'; sx.create({",
      ),
    /Cannot measure StyleX/,
  );
});

function run(directory, ...args) {
  return spawnSync(
    process.execPath,
    [join(import.meta.dirname, "repo-metrics.mjs"), ...args],
    {
      cwd: directory,
      encoding: "utf8",
      timeout: 60_000,
    },
  );
}

function metric(output, name) {
  const line = output.split("\n").find((line) => line.includes(`**${name}:**`));
  assert.ok(line, output);
  return Number(
    line
      .split("**")
      .at(-1)
      .match(/[\d,]+/)[0]
      .replaceAll(",", ""),
  );
}

test("the CLI counts duplicate files, identifies StyleX as a subset, and respects exclusions", () => {
  const directory = mkdtempSync(join(tmpdir(), "repo metrics "));
  try {
    const source =
      "import * as sx from '@stylexjs/stylex'\nconst styles = sx.create({ box: { color: 'red' } })\nconst element = <div {...sx.props(styles.box)} />\n";
    writeFileSync(join(directory, "one.tsx"), source);
    writeFileSync(join(directory, "two.tsx"), source);
    writeFileSync(join(directory, "other.js"), "const value = 1\n");
    writeFileSync(join(directory, "notes.md"), "plain prose\n");
    writeFileSync(join(directory, "unknown.xyz"), "unclassified content\n");
    writeFileSync(join(directory, ".gitignore"), "ignored.ts\n");
    writeFileSync(join(directory, "ignored.ts"), "const ignored = 1\n");
    const before = readdirSync(directory);
    const result = run(directory, directory);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(metric(result.stdout, "Code lines"), 8);
    assert.equal(metric(result.stdout, "TypeScript code lines"), 6);
    assert.equal(metric(result.stdout, "StyleX definition lines"), 2);
    assert.equal(metric(result.stdout, "Files"), 4);
    assert.ok(metric(result.stdout, "Packed tokens (o200k_base)") > 0);
    const totals = [
      ...result.stdout.matchAll(/^- \*\*.+ code lines:\*\* ([\d,]+)/gm),
    ].map((match) => Number(match[1].replaceAll(",", "")));
    assert.equal(
      totals.reduce((sum, count) => sum + count, 0),
      8,
    );
    assert.deepEqual(readdirSync(directory), before);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("line counts use the packed contents even if source files change after packing", () => {
  const directory = mkdtempSync(join(tmpdir(), "repo-metrics-snapshot-"));
  try {
    const bin = join(directory, "bin");
    mkdirSync(bin);
    const bunx = execFileSync("which", ["bunx"], { encoding: "utf8" }).trim();
    const wrapper = [
      "#!/usr/bin/env node",
      "const { writeFileSync } = require('node:fs')",
      "const { spawnSync } = require('node:child_process')",
      "const args = process.argv.slice(2)",
      "if (args[0] === 'repomix@1.18.0') {",
      "  writeFileSync(args[args.indexOf('--output') + 1], JSON.stringify({files: {'source.ts': 'const original = 1\\n'}}))",
      "  writeFileSync('source.ts', 'const changed = 1\\n'.repeat(10))",
      "  console.log('Total Tokens: 100 tokens')",
      "} else {",
      `  process.exit(spawnSync(${JSON.stringify(bunx)}, args, {stdio: 'inherit'}).status)`,
      "}",
    ].join("\n");
    writeFileSync(join(bin, "bunx"), wrapper, { mode: 0o755 });
    const result = spawnSync(
      process.execPath,
      [join(import.meta.dirname, "repo-metrics.mjs"), directory],
      {
        cwd: directory,
        env: { ...process.env, PATH: bin + ":" + process.env.PATH },
        encoding: "utf8",
        timeout: 60_000,
      },
    );
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(metric(result.stdout, "Code lines"), 1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

for (const files of [{}, { "unknown.xyz": "unclassified content\n" }]) {
  test(`the CLI reports zero code for ${Object.keys(files).length} unclassified files`, () => {
    const directory = mkdtempSync(join(tmpdir(), "repo-metrics-empty-"));
    try {
      for (const [file, content] of Object.entries(files))
        writeFileSync(join(directory, file), content);
      const result = run(directory, directory);
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.equal(metric(result.stdout, "Code lines"), 0);
      assert.equal(metric(result.stdout, "Files"), 0);
      assert.ok(metric(result.stdout, "Packed tokens (o200k_base)") > 0);
      assert.ok(!result.stdout.includes("NaN"));
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
}

test("the CLI returns one error line and a failure status for invalid input", () => {
  const directory = mkdtempSync(join(tmpdir(), "repo-metrics-error-"));
  try {
    for (const args of [[join(directory, "missing")], [directory, directory]]) {
      const result = run(directory, ...args);
      assert.equal(result.status, 1);
      assert.equal(result.stdout.trim().split("\n").length, 1);
      assert.ok(result.stdout.startsWith("- **Error:** "));
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
