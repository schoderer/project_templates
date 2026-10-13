from click.testing import CliRunner

from __NAME_SNAKE__.cli import main


def test_greet_defaults_to_world() -> None:
    result = CliRunner().invoke(main, ["greet"])
    assert result.exit_code == 0
    assert result.output == "Hello, world!\n"


def test_greet_shout() -> None:
    result = CliRunner().invoke(main, ["greet", "nix", "--shout"])
    assert result.exit_code == 0
    assert result.output == "HELLO, NIX!\n"
