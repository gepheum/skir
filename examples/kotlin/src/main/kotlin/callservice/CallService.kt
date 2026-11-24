package examples.callservice

import build.skir.service.ServiceClient
import kotlinx.coroutines.runBlocking
import skirout.service.AddUser
import skirout.service.AddUserRequest
import skirout.service.GetUser
import skirout.service.GetUserRequest
import skirout.user.SubscriptionStatus
import skirout.user.TARZAN
import skirout.user.User
import java.time.Duration

/**
 * Sends RPCs to a Skir service. See StartService.kt for how to start one.
 *
 * Run with: ./gradlew run -PmainClass=examples.callservice.CallServiceKt
 *
 * Make sure the service is running first (using StartService).
 */
fun main() =
    runBlocking {
        val serviceClient = ServiceClient("http://localhost:8787/myapi")

        println()
        println("About to add 2 users: John Doe and Tarzan")

        // Add John Doe
        serviceClient.invokeRemote(
            AddUser,
            AddUserRequest(
                user =
                    User(
                        userId = 42,
                        name = "John Doe",
                        quote = "",
                        pets = emptyList(),
                        subscriptionStatus = SubscriptionStatus.UNKNOWN,
                    ),
            ),
            emptyMap(),
            Duration.ofSeconds(30),
        )

        // Add Tarzan with custom headers
        val customHeaders = mapOf("X-Foo" to listOf("hi"))
        serviceClient.invokeRemote(
            AddUser,
            AddUserRequest(user = TARZAN),
            customHeaders,
            Duration.ofSeconds(30),
        )

        println("Done")

        // Get user by ID
        val foundUserResponse =
            serviceClient.invokeRemote(
                GetUser,
                GetUserRequest(userId = 123),
                emptyMap(),
                Duration.ofSeconds(30),
            )

        println("Found user: ${foundUserResponse.user}")
    }
