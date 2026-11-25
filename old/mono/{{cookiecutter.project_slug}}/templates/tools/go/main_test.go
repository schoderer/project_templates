package main

import (
	"bytes"
	"testing"
)

func runCLI(t *testing.T, args ...string) (int, string) {
	t.Helper()
	var stdout, stderr bytes.Buffer
	code := run(args, &stdout, &stderr)
	return code, stdout.String()
}

func TestGreetDefault(t *testing.T) {
	if code, out := runCLI(t, "greet"); code != 0 || out != "Hello, world!\n" {
		t.Fatalf("got %d %q", code, out)
	}
}

func TestGreetShout(t *testing.T) {
	if code, out := runCLI(t, "greet", "--shout", "nix"); code != 0 || out != "HELLO, NIX!\n" {
		t.Fatalf("got %d %q", code, out)
	}
}

func TestGreetFlagAfterName(t *testing.T) {
	if code, out := runCLI(t, "greet", "nix", "--shout"); code != 0 || out != "HELLO, NIX!\n" {
		t.Fatalf("got %d %q", code, out)
	}
}

func TestUnknownCommand(t *testing.T) {
	if code, _ := runCLI(t, "nope"); code != 2 {
		t.Fatalf("got exit code %d", code)
	}
}
