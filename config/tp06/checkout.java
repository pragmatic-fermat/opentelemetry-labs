// Service Java minimal, sans dependance : JDK HttpServer + HttpClient.
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class checkout {
    public static void main(String[] args) throws Exception {
        HttpClient client = HttpClient.newHttpClient();
        HttpServer server = HttpServer.create(new InetSocketAddress(8081), 0);
        server.createContext("/order", exchange -> {
            String downstream = "null";
            try {
                HttpRequest req = HttpRequest.newBuilder()
                        .uri(URI.create("http://localhost:8080/stock"))
                        .GET().build();
                downstream = client.send(req, HttpResponse.BodyHandlers.ofString()).body();
            } catch (Exception e) {
                downstream = "{\"error\":\"" + e.getClass().getSimpleName() + "\"}";
            }
            String body = "{\"orders\":\"1 mug\",\"inventory\":" + downstream + "}";
            byte[] out = body.getBytes();
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, out.length);
            exchange.getResponseBody().write(out);
            exchange.close();
        });
        server.start();
        System.out.println("checkout listening on 8081");
    }
}
