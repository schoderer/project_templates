import assert from "node:assert/strict";
import { test } from "node:test";
import { run } from "./cli.js";

function cli(...args: string[]): { code: number; out: string[] } {
  const out: string[] = [];
  const code = run(args, "1.2.3", {
    out: (line) => out.push(line),
    err: () => {},
  });
  return { code, out };
}

test("greet defaults to world", () => {
  assert.deepEqual(cli("greet"), { code: 0, out: ["Hello, world!"] });
});

test("greet --shout", () => {
  assert.deepEqual(cli("greet", "--shout", "nix"), {
    code: 0,
    out: ["HELLO, NIX!"],
  });
});

test("version", () => {
  assert.deepEqual(cli("version"), { code: 0, out: ["1.2.3"] });
});

test("unknown command fails", () => {
  assert.equal(cli("nope").code, 2);
});
