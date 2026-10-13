// __NAME__: command line tool.
//
//	__NAME__ greet [NAME] [--shout]
//	__NAME__ version
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
)

// Set at build time with -ldflags "-X main.version=...".
var version = "dev"

func greeting(name string, shout bool) string {
	message := fmt.Sprintf("Hello, %s!", name)
	if shout {
		return strings.ToUpper(message)
	}
	return message
}

func usage(w io.Writer) {
	fmt.Fprintln(w, "usage: __NAME__ <command> [flags]")
	fmt.Fprintln(w)
	fmt.Fprintln(w, "commands:")
	fmt.Fprintln(w, "  greet [--shout] [NAME]  print a greeting for NAME (default: world)")
	fmt.Fprintln(w, "  version                 print the version")
}

// splitArgs moves flags in front of positional arguments, so flags work in any
// position (`greet nix --shout`); the flag package stops at the first positional.
func splitArgs(args []string) []string {
	var flags, positional []string
	for _, arg := range args {
		if strings.HasPrefix(arg, "-") {
			flags = append(flags, arg)
		} else {
			positional = append(positional, arg)
		}
	}
	return append(flags, positional...)
}

// run executes the command line and returns the exit code.
func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		usage(stderr)
		return 2
	}
	switch args[0] {
	case "greet":
		flags := flag.NewFlagSet("greet", flag.ContinueOnError)
		flags.SetOutput(stderr)
		shout := flags.Bool("shout", false, "print the greeting in upper case")
		if err := flags.Parse(splitArgs(args[1:])); err != nil {
			return 2
		}
		name := "world"
		if flags.NArg() > 0 {
			name = flags.Arg(0)
		}
		fmt.Fprintln(stdout, greeting(name, *shout))
	case "version":
		fmt.Fprintln(stdout, version)
	case "help", "-h", "--help":
		usage(stdout)
	default:
		fmt.Fprintf(stderr, "unknown command %q\n\n", args[0])
		usage(stderr)
		return 2
	}
	return 0
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}
