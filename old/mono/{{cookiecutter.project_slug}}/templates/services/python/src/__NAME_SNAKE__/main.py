"""Entry point: serves the app on 0.0.0.0:$PORT (default 8080).

uvicorn handles SIGTERM (what `docker stop` sends) with a graceful shutdown.
"""

import os

import uvicorn

from __NAME_SNAKE__.app import app


def main() -> None:
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))


if __name__ == "__main__":
    main()
