#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { tmpdir } from "node:os";

let temporaryDirectory;

try {
  if (process.argv.length > 3) throw new Error("Pass at most one directory.");

  const target = resolveTarget(process.argv[2]);
  temporaryDirectory = mkdtempSync(join(tmpdir(), "repo-metrics-"));
  const configPath = join(temporaryDirectory, "repomix.config.json");
  const outputPath = join(temporaryDirectory, "repomix.json");
  writeFileSync(configPath, "{}\n");

  const environment = { ...process.env, CI: "1", NO_COLOR: "1" };
  delete environment.FORCE_COLOR;

  const result = spawnSync(
    "bunx",
    [
      "repomix@1.18.0",
      ".",
      "--config",
      configPath,
      "--style",
      "json",
      "--output",
      outputPath,
      "--token-count-encoding",
      "o200k_base",
    ],
    {
      cwd: target,
      encoding: "utf8",
      env: environment,
      maxBuffer: 10 * 1024 * 1024,
    },
  );

  if (result.error) throw result.error;

  const log = stripTerminalCodes(`${result.stdout}\n${result.stderr}`);
  if (result.status !== 0) throw new Error(lastLine(log) || "Repomix failed.");

  const packed = JSON.parse(readFileSync(outputPath, "utf8"));
  if (
    !packed.files ||
    typeof packed.files !== "object" ||
    Array.isArray(packed.files)
  ) {
    throw new Error("Repomix returned an unexpected JSON format.");
  }

  const totalTokens = summaryNumber(log, /Total Tokens:\s*([\d,]+)\s+tokens/i);
  const cloc = await countLines(temporaryDirectory, packed.files);
  const lines = [
    `- **Packed tokens (o200k_base):** ${formatNumber(totalTokens)}`,
    `- **Code lines:** ${formatNumber(cloc.code)}`,
    `- **Comment lines:** ${formatNumber(cloc.comment)}`,
    `- **Files:** ${formatNumber(cloc.files)} counted / ${formatNumber(Object.keys(packed.files).length)} packed`,
    "",
    ...cloc.languages.flatMap(([language, count]) => [
      `- **${language} code lines:** ${formatNumber(count)} (${percentage(count, cloc.code)}%)`,
      ...(cloc.stylex.has(language)
        ? [
            `  - **StyleX definition lines:** ${formatNumber(cloc.stylex.get(language))} (included in ${language})`,
          ]
        : []),
    ]),
    "",
    "Scope: Repomix-selected files; tokens include JSON packaging. cloc classifies whole files, including data and prose; embedded syntax remains in its host language.",
  ];

  console.log(lines.join("\n"));
} catch (error) {
  console.log(
    `- **Error:** ${oneLine(error instanceof Error ? error.message : error)}`,
  );
  process.exitCode = 1;
} finally {
  if (temporaryDirectory) {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

function resolveTarget(argument) {
  let target = argument ? resolve(argument) : gitRoot();
  if (!target) target = process.cwd();
  if (!existsSync(target) || !statSync(target).isDirectory()) {
    throw new Error(`Directory not found: ${target}`);
  }
  return realpathSync(target);
}

function gitRoot() {
  const result = spawnSync("git", ["rev-parse", "--show-toplevel"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout.trim() : undefined;
}

function stripTerminalCodes(value) {
  return value
    .replace(/\x1B\][^\x07]*(?:\x07|\x1B\\)/g, "")
    .replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/\r/g, "\n");
}

function summaryNumber(log, pattern) {
  const match = log.match(pattern);
  if (!match) throw new Error("Repomix summary is incomplete.");
  return Number(match[1].replaceAll(",", ""));
}

async function countLines(temporaryDirectory, files) {
  const { countStylex } = await import("./stylex.mjs");
  const target = join(temporaryDirectory, "source");
  const snapshot = new Map();
  for (const [file, content] of Object.entries(files)) {
    const path = resolve(target, file);
    if (
      typeof content !== "string" ||
      /[\r\n]/.test(file) ||
      !path.startsWith(target + sep)
    ) {
      throw new Error("Repomix returned an invalid file entry.");
    }
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
    snapshot.set(path, content);
  }
  const config = join(temporaryDirectory, "cloc.config");
  writeFileSync(config, "");
  mkdirSync(target, { recursive: true });
  const result = spawnSync(
    "bunx",
    [
      "--bun",
      "cloc@2.6.0-cloc",
      "--json",
      "--by-file",
      "--skip-uniqueness",
      "--timeout=0",
      `--config=${config}`,
      "--list-file=-",
    ],
    {
      cwd: target,
      encoding: "utf8",
      env: { ...process.env, NO_COLOR: "1" },
      input: [...snapshot.keys()].join("\n"),
      maxBuffer: 10 * 1024 * 1024,
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(lastLine(result.stderr) || "cloc failed.");
  }

  const report = JSON.parse(result.stdout);
  const languages = new Map();
  const stylex = new Map();
  let code = 0;
  let comment = 0;
  let counted = 0;
  for (const [file, counts] of Object.entries(report)) {
    if (file === "header" || file === "SUM") continue;
    if (
      !snapshot.has(file) ||
      typeof counts.language !== "string" ||
      ![counts.code, counts.comment].every(
        (n) => Number.isSafeInteger(n) && n >= 0,
      )
    ) {
      throw new Error("cloc returned an invalid file count.");
    }
    counted++;
    code += counts.code;
    comment += counts.comment;
    languages.set(
      counts.language,
      (languages.get(counts.language) ?? 0) + counts.code,
    );
    const definitions = countStylex(file, snapshot.get(file));
    if (definitions)
      stylex.set(
        counts.language,
        (stylex.get(counts.language) ?? 0) + definitions,
      );
  }
  return {
    code,
    comment,
    files: counted,
    stylex,
    languages: [...languages]
      .filter(([, count]) => count)
      .sort(
        ([nameA, linesA], [nameB, linesB]) =>
          linesB - linesA || nameA.localeCompare(nameB),
      ),
  };
}

function percentage(value, total) {
  return (total ? (value / total) * 100 : 0).toFixed(1);
}

function formatNumber(value) {
  return value.toLocaleString("en-US");
}

function lastLine(value) {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .at(-1);
}

function oneLine(value) {
  return String(value).replace(/\s+/g, " ").trim();
}
