package examples;

import build.skir.service.Service;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import kotlin.coroutines.Continuation;
import kotlin.coroutines.EmptyCoroutineContext;
import kotlinx.coroutines.CoroutineScopeKt;
import kotlinx.coroutines.CoroutineStart;
import kotlinx.coroutines.Dispatchers;
import kotlinx.coroutines.future.FutureKt;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import skirout.service.AddUserRequest;
import skirout.service.AddUserResponse;
import skirout.service.GetUserRequest;
import skirout.service.GetUserResponse;
import skirout.service.Methods;
import skirout.user.User;

/**
 * Starts a Skir service on http://localhost:8787/myapi
 *
 * <p>Run with: ./gradlew bootRun -PmainClass=examples.StartService
 *
 * <p>Use 'CallService.java' to call this service from another process.
 */
@SpringBootApplication
public class StartService {
  /** Custom data class containing relevant information extracted from the HTTP request headers. */
  public static class RequestMetadata {
    // Add fields here.

    RequestMetadata() {}

    static RequestMetadata fromRequest(HttpServletRequest request) {
      return new RequestMetadata();
    }
  }

  /** Implementation of the service methods. */
  public static class ServiceImpl {
    private final Map<Integer, User> idToUser = new ConcurrentHashMap<>();

    // Sync
    public GetUserResponse getUser(GetUserRequest request, RequestMetadata metadata) {
      final int userId = request.userId();
      final User user = idToUser.get(userId);
      return GetUserResponse.partialBuilder().setUser(Optional.ofNullable(user)).build();
    }

    // Async
    public Object addUser(
        AddUserRequest request,
        RequestMetadata metadata,
        Continuation<? super AddUserResponse> continuation) {
      final User user = request.user();
      if (user.userId() == 0) {
        throw new IllegalArgumentException("invalid user id");
      }

      CompletableFuture<AddUserResponse> future = new CompletableFuture<>();
      CompletableFuture.delayedExecutor(1, TimeUnit.MILLISECONDS)
          .execute(
              () -> {
                System.out.println("Adding user: " + user);
                idToUser.put(user.userId(), user);
                future.complete(AddUserResponse.DEFAULT);
              });

      return FutureKt.await(future, continuation);
    }
  }

  @Bean
  public Service<RequestMetadata> skirService() {
    final ServiceImpl serviceImpl = new ServiceImpl();
    return new Service.Builder<RequestMetadata>()
        .addMethod(
            Methods.ADD_USER,
            (req, meta, continuation) -> serviceImpl.addUser(req, meta, continuation))
        .addMethod(Methods.GET_USER, (req, meta, continuation) -> serviceImpl.getUser(req, meta))
        .build();
  }

  @RestController
  public static class ApiController {
    private final Service<RequestMetadata> skirService;

    public ApiController(Service<RequestMetadata> skirService) {
      this.skirService = skirService;
    }

    @GetMapping("/")
    public String root() {
      return "Hello, World!";
    }

    @PostMapping("/myapi")
    public CompletableFuture<ResponseEntity<byte[]>> handlePost(
        HttpServletRequest request, @RequestBody byte[] body) throws IOException {
      String requestBody = new String(body, StandardCharsets.UTF_8);
      return handleRequest(request, requestBody);
    }

    @GetMapping("/myapi")
    public CompletableFuture<ResponseEntity<byte[]>> handleGet(HttpServletRequest request)
        throws IOException {
      String query = request.getQueryString();
      String requestBody = query != null ? URLDecoder.decode(query, StandardCharsets.UTF_8) : "";
      return handleRequest(request, requestBody);
    }

    private CompletableFuture<ResponseEntity<byte[]>> handleRequest(
        HttpServletRequest request, String requestBody) {
      // Simplified metadata extraction
      RequestMetadata metadata = RequestMetadata.fromRequest(request);

      // Handle the request asynchronously
      CompletableFuture<Service.RawResponse> asyncResponse =
          FutureKt.future(
              CoroutineScopeKt.CoroutineScope(Dispatchers.getDefault()),
              EmptyCoroutineContext.INSTANCE,
              CoroutineStart.DEFAULT,
              (scope, continuation) ->
                  skirService.handleRequest(requestBody, metadata, continuation));

      return asyncResponse.thenApply(
          (Service.RawResponse rawResponse) ->
              ResponseEntity.status(rawResponse.statusCode())
                  .header("Content-Type", rawResponse.contentType())
                  .body(rawResponse.data().getBytes(StandardCharsets.UTF_8)));
    }
  }

  public static void main(String[] args) {
    SpringApplication.run(StartService.class, args);
  }
}
