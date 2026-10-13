// HTTP routes of __NAME__.
import { createServer, type Server } from "node:http";

export function createApp(): Server {
  return createServer((req, res) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const hello = url.pathname.match(/^\/hello\/([^/]+)$/);

    if (req.method === "GET" && url.pathname === "/health") {
      res.writeHead(200, { "content-type": "text/plain" }).end("ok");
    } else if (req.method === "GET" && hello) {
      const name = decodeURIComponent(hello[1]);
      res
        .writeHead(200, { "content-type": "text/plain" })
        .end(`Hello, ${name}!`);
    } else {
      res.writeHead(404, { "content-type": "text/plain" }).end("not found");
    }
  });
}
