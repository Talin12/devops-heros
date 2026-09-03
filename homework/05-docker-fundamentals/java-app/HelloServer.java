import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class HelloServer {
    public static void main(String[] args) throws Exception {
        int port = 8080;
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);

        server.createContext("/", exchange -> {
            String html = "<!doctype html>"
                    + "<html><head><title>Java Hello World</title></head>"
                    + "<body style=\"font-family:sans-serif;text-align:center;padding-top:80px\">"
                    + "<h1>Hello World from Java </h1>"
                    + "<p>Served from inside a Docker container</p>"
                    + "<p>Talin Daga | 24BCS10321</p>"
                    + "</body></html>";
            byte[] body = html.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });

        server.setExecutor(null);
        System.out.println("Java app listening on port " + port);
        server.start();
    }
}
