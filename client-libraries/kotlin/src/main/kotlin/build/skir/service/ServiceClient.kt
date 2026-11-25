package build.skir.service

import build.skir.UnrecognizedValuesPolicy
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

/** Sends RPCs to a SkirRPC service. */
class ServiceClient
    @JvmOverloads
    constructor(
        serviceUrl: String,
        private val defaultRequestHeaders: Map<String, List<String>> = emptyMap(),
        private val httpClient: HttpClient = HttpClient.newBuilder().build(),
    ) {
        private val serviceUri = URI(serviceUrl)

        init {
            if (serviceUri.query != null) {
                throw IllegalArgumentException("Service URL must not contain a query string")
            }
        }

        /** Invokes the given method on the remote server through an RPC. */
        @JvmOverloads
        suspend fun <Request, Response> invokeRemote(
            method: Method<Request, Response>,
            request: Request,
            requestHeaders: Map<String, List<String>> = defaultRequestHeaders,
            timeout: Duration = MAX_DURATION,
        ): Response =
            withContext(Dispatchers.IO) {
                val requestJson = method.requestSerializer.toJsonCode(request)
                val requestBody = listOf(method.name, method.number.toString(), "", requestJson).joinToString(":")

                val httpRequestBuilder = HttpRequest.newBuilder()

                // Add headers from metadata
                for ((name, values) in requestHeaders) {
                    for (value in values) {
                        httpRequestBuilder.header(name, value)
                    }
                }

                // Set timeout if provided
                if (timeout != MAX_DURATION) {
                    httpRequestBuilder.timeout(timeout)
                }

                httpRequestBuilder
                    .uri(serviceUri)
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))

                val httpRequest = httpRequestBuilder.build()
                val httpResponse = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString())

                if (httpResponse.statusCode() in 200..299) {
                    val jsonCode = httpResponse.body()
                    method.responseSerializer.fromJsonCode(jsonCode, UnrecognizedValuesPolicy.KEEP)
                } else {
                    var message = ""
                    val contentType = httpResponse.headers().firstValue("content-type").orElse("")
                    if (contentType.contains("text/plain", ignoreCase = true)) {
                        message = ": ${httpResponse.body()}"
                    }
                    throw IOException("HTTP status ${httpResponse.statusCode()}$message")
                }
            }

        /**
         * Invokes the given method on the remote server through an RPC.
         * This is a blocking version suitable for calling from Java.
         */
        @JvmOverloads
        fun <Request, Response> invokeRemoteBlocking(
            method: Method<Request, Response>,
            request: Request,
            requestHeaders: Map<String, List<String>> = defaultRequestHeaders,
            timeout: Duration = MAX_DURATION,
        ): Response =
            runBlocking {
                invokeRemote(method, request, requestHeaders, timeout)
            }

        companion object {
            private val MAX_DURATION = Duration.ofNanos(Long.MAX_VALUE)
        }
    }
