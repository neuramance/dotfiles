#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
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
  if (!packed.files || Array.isArray(packed.files)) {
    throw new Error("Repomix returned an unexpected JSON format.");
  }

  const totalTokens = summaryNumber(log, /Total Tokens:\s*([\d,]+)\s+tokens/i);
  const cloc = countLines(target, Object.keys(packed.files));
  const lines = [
    `- **Total tokens:** ${formatNumber(totalTokens)}`,
    `- **Code lines:** ${formatNumber(cloc.code)}`,
    `- **Comment lines:** ${formatNumber(cloc.comment)}`,
    ...(cloc.languages.length ? ["", "\u200b", ""] : []),
    ...cloc.languages.map(
      ([language, count]) =>
        `- **${language} code lines:** ${formatNumber(count)} (${percentage(count, cloc.code)}%)`,
    ),
  ];

  console.log(lines.join("\n"));
} catch (error) {
  console.log(`- **Error:** ${oneLine(error instanceof Error ? error.message : error)}`);
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

function countLines(target, files) {
  if (!files.length) return { code: 0, comment: 0, languages: [] };
  if (files.some((file) => /[\r\n]/.test(file))) {
    throw new Error("Cannot count a filename containing a line break.");
  }

  const result = spawnSync(
    "bunx",
    ["--bun", "cloc@2.6.0-cloc", "--json", "--list-file=-"],
    {
      cwd: target,
      encoding: "utf8",
      env: { ...process.env, NO_COLOR: "1" },
      input: files.join("\n"),
      maxBuffer: 10 * 1024 * 1024,
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(lastLine(result.stderr) || "cloc failed.");
  }

  const report = JSON.parse(result.stdout);
  if (!report.SUM) throw new Error("cloc returned an incomplete report.");
  const languages = Object.entries(report)
    .filter(([name, counts]) => name !== "header" && name !== "SUM" && counts.code)
    .map(([name, counts]) => [name, counts.code])
    .sort(
      ([nameA, linesA], [nameB, linesB]) =>
        linesB - linesA || nameA.localeCompare(nameB),
    );
  return {
    code: report.SUM.code,
    comment: report.SUM.comment,
    languages,
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
