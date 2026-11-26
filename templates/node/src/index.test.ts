import { expect, test } from "vitest";
import { greeting } from "./index.ts";

test("greeting", () => {
  expect(greeting()).toBe("Hello World!");
});
