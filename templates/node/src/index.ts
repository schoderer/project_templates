#!/usr/bin/env node

export function greeting(): string {
  return "Hello World!";
}

if (import.meta.main) {
  console.log(greeting());
}
