package examples

import build.skir.service.ServiceClient
import skirout.service.AddUser
import skirout.service.AddUserRequest
import skirout.service.GetUser
import skirout.service.GetUserRequest
import skirout.user.SubscriptionStatus
import skirout.user.TARZAN
import skirout.user.User
import java.time.Duration
import java.util.List
import java.util.Map

/**
 * Sends RPCs to a Skir service. See StartService.scala for how to start one.
 *
 * Run with: ./gradlew run -PmainClass=examples.CallService
 *
 * Make sure the service is running first (using StartService).
 */
object CallService:
  def main(args: Array[String]): Unit =
    val serviceClient = new ServiceClient(
      "http://localhost:8787/myapi",
      Map.of("Content-Type", List.of("text/plain; charset=utf-8")),
    )

    println()
    println("About to add 2 users: John Doe and Tarzan")

    // Add John Doe
    serviceClient.invokeRemoteBlocking(
      AddUser,
      AddUserRequest(
        user = User(
          userId = 42,
          name = "John Doe",
          quote = "",
          pets = List.of(),
          subscriptionStatus = SubscriptionStatus.UNKNOWN,
        ),
      ),
    )

    // Add Tarzan with custom headers
    val customHeaders = Map.of(
      "Content-Type",
      List.of("text/plain; charset=utf-8"),
      "X-Foo",
      List.of("hi"),
    )
    serviceClient.invokeRemoteBlocking(
      AddUser,
      AddUserRequest(user = TARZAN),
      customHeaders,
      Duration.ofSeconds(30),
    )

    println("Done")

    // Get user by ID
    val foundUserResponse = serviceClient.invokeRemoteBlocking(
      GetUser,
      GetUserRequest(userId = 123),
    )

    println(s"Found user: ${foundUserResponse.user}")
