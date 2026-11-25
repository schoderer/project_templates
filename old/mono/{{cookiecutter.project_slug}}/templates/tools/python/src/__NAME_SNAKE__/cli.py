"""Command line interface of __NAME__."""

import click

from __NAME_SNAKE__ import __version__


@click.group()
def main() -> None:
    """__NAME__: sample monorepo tool."""


@main.command()
@click.argument("name", default="world")
@click.option("--shout", is_flag=True, help="Print the greeting in upper case.")
def greet(name: str, shout: bool) -> None:
    """Print a greeting for NAME."""
    message = f"Hello, {name}!"
    click.echo(message.upper() if shout else message)


@main.command()
def version() -> None:
    """Print the version."""
    click.echo(__version__)
