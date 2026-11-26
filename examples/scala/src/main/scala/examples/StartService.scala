package examples

import build.skir.service.Service
import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlinx.coroutines.BuildersKt
import kotlinx.coroutines.future.FutureKt
import skirout.service.AddUser
import skirout.service.AddUserRequest
import skirout.service.AddUserResponse
import skirout.service.GetUser
import skirout.service.GetUserRequest
import skirout.service.GetUserResponse
import skirout.user.User
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Optional
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Starts a Skir service on http://localhost:8787/myapi
 *
 * Run with: ./gradlew run -PmainClass=examples.StartService
 *
 * Use 'CallService.scala' to call this service from another process.
 */
object StartService:
  /**
   * Custom data class containing relevant information extracted from the HTTP
   * request headers.
   */
  case class RequestMetadata(isAdmin: Boolean = false)

  object RequestMetadata:
    def fromExchange(exchange: HttpExchange): RequestMetadata =
      RequestMetadata()

  /** Implementation of the service methods. */
  class ServiceImpl:
    private val idToUser = new ConcurrentHashMap[Int, User]()

    // Sync
    def getUser(
      request: GetUserRequest,
      metadata: RequestMetadata,
    ): GetUserResponse =
      val userId = request.userId
      val user = idToUser.get(userId)
      GetUserResponse.partial(user = Optional.ofNullable(user))

    // Async
    def addUser(
      request: AddUserRequest,
      metadata: RequestMetadata,
      continuation: Continuation[? >: AddUserResponse],
    ): AnyRef =
      val user = request.user
      if user.userId == 0 then
        throw new IllegalArgumentException("invalid user id")

      val future = new CompletableFuture[AddUserResponse]()
      CompletableFuture
        .delayedExecutor(1, TimeUnit.MILLISECONDS)
        .execute(() => {
          println(s"Adding user: $user")
          idToUser.put(user.userId, user)
          future.complete(AddUserResponse.default)
        })

      FutureKt.await(future, continuation)

  def main(args: Array[String]): Unit =
    val serviceImpl = new ServiceImpl()

    val skirService = new Service.Builder[RequestMetadata]()
      .addMethod(
        AddUser,
        (req, meta, continuation) => serviceImpl.addUser(req, meta, continuation),
      )
      .addMethod(
        GetUser,
        (req, meta, _) => serviceImpl.getUser(req, meta),
      )
      .build()

    val server = HttpServer.create(new InetSocketAddress(8787), 0)
    server.setExecutor(Executors.newCachedThreadPool())

    server.createContext(
      "/",
      exchange => {
        val responseBytes = "Hello, World!".getBytes(StandardCharsets.UTF_8)
        exchange.sendResponseHeaders(200, responseBytes.length.toLong)
        val os = exchange.getResponseBody
        try os.write(responseBytes)
        finally os.close()
      },
    )

    server.createContext(
      "/myapi",
      exchange => {
        val requestBody =
          if exchange.getRequestMethod.equalsIgnoreCase("POST") then
            val is = exchange.getRequestBody
            try new String(is.readAllBytes(), StandardCharsets.UTF_8)
            finally is.close()
          else
            val query = exchange.getRequestURI.getRawQuery
            if query != null then URLDecoder.decode(query, StandardCharsets.UTF_8)
            else ""

        val metadata = RequestMetadata.fromExchange(exchange)

        val rawResponse = BuildersKt.runBlocking[Service.RawResponse](
          EmptyCoroutineContext.INSTANCE,
          (_, continuation) =>
            skirService.handleRequest(requestBody, metadata, continuation),
        )

        val responseBytes = rawResponse.data().getBytes(StandardCharsets.UTF_8)
        exchange.getResponseHeaders.set("Content-Type", rawResponse.contentType())
        exchange.sendResponseHeaders(
          rawResponse.statusCode(),
          responseBytes.length.toLong,
        )
        val os = exchange.getResponseBody
        try os.write(responseBytes)
        finally os.close()
      },
    )

    println("Serving at http://localhost:8787")
    println("API endpoint: http://localhost:8787/myapi")
    println("Press Ctrl+C to stop the server")
    server.start()
