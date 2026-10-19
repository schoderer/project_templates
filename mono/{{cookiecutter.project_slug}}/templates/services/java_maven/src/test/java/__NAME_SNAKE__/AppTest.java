package __NAME_SNAKE__;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

class AppTest {
  private static HttpServer server;
  private static final HttpClient CLIENT = HttpClient.newHttpClient();

  @BeforeAll
  static void startServer() throws Exception {
    server = App.start(new InetSocketAddress("127.0.0.1", 0));
  }

  @AfterAll
  static void stopServer() {
    server.stop(0);
  }

  private static HttpResponse<String> get(String path) throws Exception {
    URI uri = URI.create("http://127.0.0.1:" + server.getAddress().getPort() + path);
    return CLIENT.send(HttpRequest.newBuilder(uri).build(), HttpResponse.BodyHandlers.ofString());
  }

  @Test
  void health() throws Exception {
    HttpResponse<String> response = get("/health");
    assertEquals(200, response.statusCode());
    assertEquals("ok", response.body());
  }

  @Test
  void hello() throws Exception {
    HttpResponse<String> response = get("/hello/nix");
    assertEquals(200, response.statusCode());
    assertEquals("Hello, nix!", response.body());
  }

  @Test
  void unknownRoute() throws Exception {
    assertEquals(404, get("/nope").statusCode());
  }
}
