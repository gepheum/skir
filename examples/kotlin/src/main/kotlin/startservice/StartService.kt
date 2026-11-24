/**
 * Starts a Skir service on http://localhost:8787/myapi
 *
 * Run with: ./gradlew run -PmainClass=examples.startservice.StartServiceKt
 *
 * Use 'CallService.kt' to call this service from another process.
 */

package examples.startservice

import build.skir.service.Service
import io.ktor.http.Headers
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.request.queryString
import io.ktor.server.request.receiveText
import io.ktor.server.response.header
import io.ktor.server.response.respondBytes
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import kotlinx.coroutines.delay
import skirout.service.AddUser
import skirout.service.AddUserRequest
import skirout.service.AddUserResponse
import skirout.service.GetUser
import skirout.service.GetUserRequest
import skirout.service.GetUserResponse
import skirout.user.User
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

/**
 * Custom data class containing relevant information extracted from the HTTP
 * request headers.
 */
data class RequestMetadata(
    val isAdmin: Boolean,
    // Add fields here.
) {
    companion object {
        fun fromHeaders(headers: Headers): RequestMetadata {
            return RequestMetadata(false)
        }
    }
}

/** Implementation of the service methods. */
class ServiceImpl {
    private val idToUser = mutableMapOf<Int, User>()

    fun getUser(request: GetUserRequest): GetUserResponse {
        val userId = request.userId
        val user = idToUser[userId]
        return GetUserResponse.partial(user = user)
    }

    suspend fun addUser(
        request: AddUserRequest,
        metadata: RequestMetadata,
    ): AddUserResponse {
        delay(1L)
        val user = request.user
        if (user.userId == 0) {
            throw IllegalArgumentException("invalid user id")
        }
        println("Adding user: $user")
        idToUser[user.userId] = user

        return AddUserResponse.partial()
    }
}

fun main() {
    val serviceImpl = ServiceImpl()

    // Build the Skir service with custom metadata
    val skirService =
        Service.Builder<RequestMetadata>()
            .addMethod(AddUser) { req, meta -> serviceImpl.addUser(req, meta) }
            .addMethod(GetUser) { req, _ -> serviceImpl.getUser(req) }
            .build()

    println("Serving at http://localhost:8787")
    println("API endpoint: http://localhost:8787/myapi")
    println("Press Ctrl+C to stop the server")

    embeddedServer(Netty, port = 8787) {
        routing {
            get("/") {
                call.respondText("Hello, World!")
            }

            // Shared logic for /myapi
            val apiHandler: suspend (io.ktor.server.application.ApplicationCall) -> Unit =
                { call ->
                    // -----------------------------------------------------------------------------
                    // Install the Skir service on the Ktor server.

                    val requestBody =
                        if (call.request.local.method == HttpMethod.Post) {
                            call.receiveText()
                        } else {
                            // For GET requests, use the query string
                            val query = call.request.queryString()
                            URLDecoder.decode(query, StandardCharsets.UTF_8)
                        }

                    // Handle the request
                    val rawResponse =
                        skirService.handleRequest(
                            requestBody,
                            RequestMetadata.fromHeaders(call.request.headers),
                        )

                    call.response.header("Content-Type", rawResponse.contentType)
                    call.respondBytes(
                        bytes = rawResponse.data.toByteArray(StandardCharsets.UTF_8),
                        status = HttpStatusCode.fromValue(rawResponse.statusCode),
                    )
                    // -----------------------------------------------------------------------------
                }

            post("/myapi") { apiHandler(call) }
            get("/myapi") { apiHandler(call) }
        }
    }.start(wait = true)
}
