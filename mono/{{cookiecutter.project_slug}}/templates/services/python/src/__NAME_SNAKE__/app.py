"""HTTP routes of __NAME__."""

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

from __NAME_SNAKE__ import __version__

app = FastAPI(title="__NAME__", version=__version__)


@app.get("/health", response_class=PlainTextResponse)
def health() -> str:
    return "ok"


@app.get("/hello/{name}", response_class=PlainTextResponse)
def hello(name: str) -> str:
    return f"Hello, {name}!"
