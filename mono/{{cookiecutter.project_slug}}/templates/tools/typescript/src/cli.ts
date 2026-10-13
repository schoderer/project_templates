// Command line interface of __NAME__.
import { parseArgs } from "node:util";

const USAGE = `usage: __NAME__ <command> [options]

commands:
  greet [--shout] [NAME]  print a greeting for NAME (default: world)
  version                 print the version`;

export function greeting(name: string, shout: boolean): string {
  const message = `Hello, ${name}!`;
  return shout ? message.toUpperCase() : message;
}

export interface Io {
  out: (line: string) => void;
  err: (line: string) => void;
}

/** Runs the command line and returns the exit code. */
export function run(args: string[], version: string, io: Io): number {
  const [command, ...rest] = args;
  switch (command) {
    case "greet": {
      const { values, positionals } = parseArgs({
        args: rest,
        options: { shout: { type: "boolean", default: false } },
        allowPositionals: true,
      });
      io.out(greeting(positionals[0] ?? "world", values.shout));
      return 0;
    }
    case "version":
      io.out(version);
      return 0;
    case "help":
    case "-h":
    case "--help":
      io.out(USAGE);
      return 0;
    default:
      io.err(command ? `unknown command "${command}"\n\n${USAGE}` : USAGE);
      return 2;
  }
}
