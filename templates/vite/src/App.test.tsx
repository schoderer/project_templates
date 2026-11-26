import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test } from "vitest";
import App from "./App.tsx";

test("counter increments", () => {
  render(<App />);
  const button = screen.getByRole("button");
  expect(button.textContent).toBe("count is 0");
  fireEvent.click(button);
  expect(button.textContent).toBe("count is 1");
});
