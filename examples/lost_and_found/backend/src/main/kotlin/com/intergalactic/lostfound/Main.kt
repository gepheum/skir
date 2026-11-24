package com.intergalactic.lostfound

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

fun main() {
    val service = LostAndFoundService().createService()

    embeddedServer(Netty, port = 8080) {
        install(CORS) {
            allowMethod(HttpMethod.Options)
            allowMethod(HttpMethod.Get)
            allowMethod(HttpMethod.Post)
            allowHeader(HttpHeaders.ContentType)
            anyHost() // For development only
        }

        routing {
            // Main API endpoint for Skir RPC calls
            route("/api") {
                get {
                    val query = call.request.queryString()
                    val requestBody = URLDecoder.decode(query, StandardCharsets.UTF_8)
                    val meta = RequestMetadata.empty()
                    val response = service.handleRequest(requestBody, meta)

                    call.response.header("Content-Type", response.contentType)
                    call.respondBytes(
                        bytes = response.data.toByteArray(StandardCharsets.UTF_8),
                        status = HttpStatusCode.fromValue(response.statusCode),
                    )
                }

                post {
                    val body = call.receiveText()
                    val meta = RequestMetadata.empty()
                    val response = service.handleRequest(body, meta)

                    call.response.header("Content-Type", response.contentType)
                    call.respondBytes(
                        bytes = response.data.toByteArray(StandardCharsets.UTF_8),
                        status = HttpStatusCode.fromValue(response.statusCode),
                    )
                }
            }

            // Health check endpoint
            get("/health") {
                call.respondText("OK", contentType = ContentType.Text.Plain)
            }
        }

        println("🚀 Intergalactic Lost & Found server running on http://localhost:8080")
        println("📡 API endpoint: http://localhost:8080/api")
        println("🔍 Skir Studio: http://localhost:8080/api?studio")
    }.start(wait = true)
}
