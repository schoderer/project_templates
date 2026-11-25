"""__NAME__: HTTP service."""

from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("__NAME__")
except PackageNotFoundError:  # running from a source checkout without installing
    __version__ = "0.0.0+dev"
