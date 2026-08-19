#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const arguments_ = process.argv.slice(2);
const flavorArgument = arguments_.find((argument) => argument.startsWith("--flavor"));
const flavorName = flavorArgument?.includes("=")
  ? flavorArgument.split("=")[1]
  : (arguments_[arguments_.indexOf(flavorArgument) + 1] ?? "oxlint");

const flavors = {
  oxlint: {
    assets: "assets/anti-slop",
    defaultTarget: "tools/oxlint/anti-slop",
    entry: "index.ts",
    linter: "Oxlint",
  },
  eslint: {
    assets: "assets/anti-slop-eslint",
    defaultTarget: "tools/eslint/anti-slop",
    entry: "index.ts",
    linter: "ESLint",
  },
};
const flavor = flavors[flavorName];

if (flavor === undefined) {
  console.error(`Unknown flavor "${flavorName}". Use --flavor oxlint or --flavor eslint.`);
  process.exit(1);
}

const source = resolve(skillRoot, flavor.assets);
const positional = arguments_.filter(
  (argument, index) =>
    !argument.startsWith("--") && arguments_[index - 1] !== "--flavor",
);
const target = resolve(process.cwd(), positional[0] ?? flavor.defaultTarget);
const force = arguments_.includes("--force");

if (existsSync(target) && !force) {
  console.error(`Refusing to overwrite ${target}. Re-run with --force only after reviewing the existing files.`);
  process.exit(1);
}

mkdirSync(dirname(target), { recursive: true });
cpSync(source, target, { recursive: true, force });
console.log(`Copied the anti-slop plugin to ${target}`);
console.log(`Configure ${flavor.linter} with: ${target}/${flavor.entry}`);
