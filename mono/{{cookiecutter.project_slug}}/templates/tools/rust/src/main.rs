//! __NAME__: sample command line tool.
//!
//! ```text
//! __NAME__ greet [NAME] [--shout]
//! __NAME__ version
//! ```

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Print a greeting for NAME
    Greet {
        #[arg(default_value = "world")]
        name: String,
        /// Print the greeting in upper case
        #[arg(long)]
        shout: bool,
    },
    /// Print the version
    Version,
}

fn greeting(name: &str, shout: bool) -> String {
    let message = format!("Hello, {name}!");
    if shout {
        message.to_uppercase()
    } else {
        message
    }
}

fn main() {
    match Cli::parse().command {
        Command::Greet { name, shout } => println!("{}", greeting(&name, shout)),
        Command::Version => println!("{}", env!("CARGO_PKG_VERSION")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greets_by_name() {
        assert_eq!(greeting("nix", false), "Hello, nix!");
    }

    #[test]
    fn shouts() {
        assert_eq!(greeting("nix", true), "HELLO, NIX!");
    }

    #[test]
    fn cli_is_valid() {
        use clap::CommandFactory;
        Cli::command().debug_assert();
    }
}
