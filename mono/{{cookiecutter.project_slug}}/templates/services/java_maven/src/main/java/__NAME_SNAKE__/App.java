package __NAME_SNAKE__;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.logging.Logger;

/**
 * __NAME__: HTTP service (JDK built-in {@code com.sun.net.httpserver}).
 *
 * <p>Routes:
 *
 * <pre>
 * GET /health       -> ok
 * GET /hello/{name} -> Hello, {name}!
 * </pre>
 *
 * <p>Listens on 0.0.0.0:$PORT (default 8080) and shuts down gracefully on SIGINT/SIGTERM (what
 * {@code docker stop} sends).
 */
public final class App {
  private static final Logger LOG = Logger.getLogger(App.class.getName());

  private App() {}

  /** Starts the server on {@code address}; port 0 picks a free port (used by the tests). */
  static HttpServer start(InetSocketAddress address) throws IOException {
    HttpServer server = HttpServer.create(address, 0);
    server.createContext("/", App::handle);
    server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
    server.start();
    return server;
  }

  private static void handle(HttpExchange exchange) throws IOException {
    try (exchange) {
      String path = exchange.getRequestURI().getPath();
      if (!exchange.getRequestMethod().equals("GET")) {
        respond(exchange, 405, "method not allowed");
      } else if (path.equals("/health")) {
        respond(exchange, 200, "ok");
      } else if (path.startsWith("/hello/") && path.length() > "/hello/".length()) {
        respond(exchange, 200, "Hello, " + path.substring("/hello/".length()) + "!");
      } else {
        respond(exchange, 404, "not found");
      }
    }
  }

  private static void respond(HttpExchange exchange, int status, String body) throws IOException {
    byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
    exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
    exchange.sendResponseHeaders(status, bytes.length);
    try (OutputStream out = exchange.getResponseBody()) {
      out.write(bytes);
    }
  }

  public static void main(String[] args) throws IOException {
    int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
    HttpServer server = start(new InetSocketAddress("0.0.0.0", port));
    LOG.info("listening on " + server.getAddress());

    // The JVM runs shutdown hooks on SIGINT/SIGTERM: let in-flight requests finish (up to 10s).
    Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(10)));
  }
}
