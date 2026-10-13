import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import { after, before, test } from "node:test";
import { createApp } from "./app.js";

const server = createApp();
let base = "";

before(async () => {
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(() => {
  server.close();
});

test("GET /health", async () => {
  const response = await fetch(`${base}/health`);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "ok");
});

test("GET /hello/{name}", async () => {
  const response = await fetch(`${base}/hello/nix`);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "Hello, nix!");
});

test("unknown route", async () => {
  const response = await fetch(`${base}/nope`);
  assert.equal(response.status, 404);
});
