#!/usr/bin/env node
// __NAME__: HTTP service.
//
// Routes:
//   GET /health       -> ok
//   GET /hello/{name} -> Hello, {name}!
//
// Listens on 0.0.0.0:$PORT (default 8080) and shuts down gracefully on
// SIGINT/SIGTERM (what `docker stop` sends).
import { createApp } from "./app.js";

const port = Number(process.env.PORT ?? 8080);
const server = createApp();

server.listen(port, "0.0.0.0", () => {
  console.log(`listening on 0.0.0.0:${port}`);
});

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
    server.closeIdleConnections();
  });
}
