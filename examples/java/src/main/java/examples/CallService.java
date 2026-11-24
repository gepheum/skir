package examples;

import build.skir.service.ServiceClient;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import skirout.service.AddUserRequest;
import skirout.service.GetUserRequest;
import skirout.service.GetUserResponse;
import skirout.service.Methods;
import skirout.user.Constants;
import skirout.user.SubscriptionStatus;
import skirout.user.User;

/**
 * Sends RPCs to a Skir service. See StartService.java for how to start one.
 *
 * <p>Run with: ./gradlew run -PmainClass=examples.CallService
 *
 * <p>Make sure the service is running first (using StartService).
 */
public class CallService {
  public static void main(String[] args) throws Exception {
    final ServiceClient serviceClient = new ServiceClient("http://localhost:8787/myapi");

    System.out.println();
    System.out.println("About to add 2 users: John Doe and Tarzan");

    // Add John Doe
    serviceClient.invokeRemoteBlocking(
        Methods.ADD_USER,
        AddUserRequest.builder()
            .setUser(
                User.builder()
                    .setName("John Doe")
                    .setPets(List.of())
                    .setQuote("")
                    .setSubscriptionStatus(SubscriptionStatus.UNKNOWN)
                    .setUserId(42)
                    .build())
            .build(),
        Map.of(),
        Duration.ofSeconds(30));

    // Add Tarzan with custom headers
    final Map<String, List<String>> customHeaders = new HashMap<>();
    customHeaders.put("X-Foo", List.of("hi"));
    serviceClient.invokeRemoteBlocking(
        Methods.ADD_USER,
        AddUserRequest.builder().setUser(Constants.TARZAN).build(),
        customHeaders,
        Duration.ofSeconds(30));

    System.out.println("Done");

    // Get user by ID
    final GetUserResponse foundUserResponse =
        serviceClient.invokeRemoteBlocking(
            Methods.GET_USER,
            GetUserRequest.builder().setUserId(123).build(),
            Map.of(),
            Duration.ofSeconds(30));

    System.out.println("Found user: " + foundUserResponse.user());
  }
}
