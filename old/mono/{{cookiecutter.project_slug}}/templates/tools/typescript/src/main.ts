#!/usr/bin/env node
// __NAME__: command line tool.
//
//   __NAME__ greet [--shout] [NAME]
//   __NAME__ version
import { readFileSync } from "node:fs";
import { run } from "./cli.js";

// package.json sits next to dist/ in the installed package.
const { version } = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as { version: string };

process.exitCode = run(process.argv.slice(2), version, {
  out: (line) => console.log(line),
  err: (line) => console.error(line),
});
