package build.skir.service

import build.skir.JsonFlavor
import build.skir.UnrecognizedValuesPolicy
import build.skir.internal.JsonObjectBuilder
import build.skir.internal.expectDepthWithinLimit
import build.skir.internal.formatReadableJson
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.URI

/**
 * Implementation of a SkirRPC service.
 *
 * @param RequestMeta A custom type containing the information you wish to pass
 *     from the HTTP request (typically headers) to your service methods.
 */
class Service<in RequestMeta> private constructor(private val impl: Impl<RequestMeta>) {
    /**
     * Parses the content of a user request and invokes the appropriate method.
     *
     * If the request is a GET request, pass in the decoded query string as the
     * request's body. The query string is the part of the URL after '?'.
     */
    suspend fun handleRequest(
        requestBody: String,
        requestMeta: RequestMeta,
    ): RawResponse {
        return impl.handleRequest(requestBody, requestMeta)
    }

    /** Raw response returned by the server. */
    data class RawResponse(
        @get:JvmName("data")
        val data: String,
        @get:JvmName("statusCode")
        val statusCode: Int,
        @get:JvmName("contentType")
        val contentType: String,
    ) {
        companion object {
            internal fun okJson(data: String) = RawResponse(data, 200, "application/json")

            internal fun okHtml(data: String) = RawResponse(data, 200, "text/html; charset=utf-8")

            internal fun badRequest(data: String) = RawResponse(data, 400, "text/plain; charset=utf-8")

            internal fun serverError(
                data: String,
                statusCode: Int = 500,
            ) = RawResponse(data, statusCode, "text/plain; charset=utf-8")
        }
    }

    private data class ServiceOptions<in RequestMeta>(
        val keepUnrecognizedValues: Boolean = false,
        val maxNestingDepth: Int,
        val canSendUnknownErrorMessage: (MethodErrorInfo<RequestMeta, *>) -> Boolean,
        val errorLogger: (MethodErrorInfo<RequestMeta, *>) -> Unit,
        val studioAppJsUrl: String,
    )

    private data class MethodImpl<Request, Response, in RequestMeta>(
        val method: Method<Request, Response>,
        val impl: suspend (req: Request, requestMeta: RequestMeta) -> Response,
    )

    /**
     * Builder for creating [Service] instances.
     *
     * @param RequestMeta A custom type containing the information you wish to
     *     pass from the HTTP request (typically headers) to your service methods.
     */
    class Builder<RequestMeta> {
        private val methodImpls: MutableMap<Long, MethodImpl<*, *, RequestMeta>> = mutableMapOf()
        private var keepUnrecognizedValues = false
        private var maxNestingDepth = -1
        private var canSendUnknownErrorMessage: (MethodErrorInfo<RequestMeta, *>) -> Boolean = { false }
        private var errorLogger: (MethodErrorInfo<RequestMeta, *>) -> Unit = { errorContext ->
            System.err.println("Error in method ${errorContext.method.name}: ${errorContext.error}")
        }
        private var studioAppJsUrl = "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js"

        /**
         * Registers the implementation of a method.
         *
         * @return `this` builder
         */
        fun <Request, Response> addMethod(
            method: Method<Request, Response>,
            impl: suspend (req: Request, requestMeta: RequestMeta) -> Response,
        ): Builder<RequestMeta> {
            val number = method.number
            if (methodImpls.containsKey(number)) {
                throw IllegalArgumentException("Method with the same number already registered ($number)")
            }
            methodImpls[number] = MethodImpl(method, impl)
            return this
        }

        /**
         * Whether to keep unrecognized values when deserializing requests.
         *
         * Only enable this for data from trusted sources. Malicious actors could
         * inject fields with IDs not yet defined in your schema. If you preserve
         * this data and later define those IDs in a future schema version, the
         * injected data could be deserialized as valid fields, leading to security
         * vulnerabilities or data corruption.
         *
         * @return `this` builder
         */
        fun setKeepUnrecognizedValues(keepUnrecognizedValues: Boolean): Builder<RequestMeta> {
            this.keepUnrecognizedValues = keepUnrecognizedValues
            return this
        }

        /**
         * Limits request nesting depth.
         * Zero and negative values disable the check (default).
         *
         * @return `this` builder
         */
        fun setMaxNestingDepth(maxNestingDepth: Int): Builder<RequestMeta> {
            this.maxNestingDepth = maxNestingDepth
            return this
        }

        /**
         * Determines whether the message of an unknown error (i.e. not a
         * [ServiceException]) can be sent to the client in the response body.
         * Can help with debugging.
         *
         * By default, unknown errors are masked and the client receives a generic
         * 'server error' message with status 500. This is to prevent leaking
         * sensitive information to the client.
         *
         * You can enable this if your server is internal or if you are sure that
         * your error messages are safe to expose.
         *
         * @return `this` builder
         */
        fun setCanSendUnknownErrorMessage(canSendUnknownErrorMessage: Boolean): Builder<RequestMeta> {
            return setCanSendUnknownErrorMessage({ canSendUnknownErrorMessage })
        }

        /**
         * A predicate which determines whether the message of an unknown error (i.e.
         * not a [ServiceException]) can be sent to the client in the response body.
         * Can help with debugging.
         *
         * By default, unknown errors are masked and the client receives a generic
         * 'server error' message with status 500. This is to prevent leaking
         * sensitive information to the client.
         *
         * You can enable this if your server is internal or if you are sure that
         * your error messages are safe to expose. By passing a predicate instead of
         * true or false, you can control on a per-error basis whether to expose the
         * error message; for example, you can send error messages only if the user
         * is an admin.
         *
         * @return `this` builder
         */
        fun setCanSendUnknownErrorMessage(
            canSendUnknownErrorMessage: (MethodErrorInfo<RequestMeta, *>) -> Boolean,
        ): Builder<RequestMeta> {
            this.canSendUnknownErrorMessage = canSendUnknownErrorMessage
            return this
        }

        /**
         * Callback invoked whenever an error is thrown during method execution.
         *
         * Use this to log errors for monitoring, debugging, or alerting purposes.
         *
         * Defaults to a function which prints the method name and error message to
         * stderr.
         *
         * @return `this` builder
         */
        fun setErrorLogger(errorLogger: (MethodErrorInfo<RequestMeta, *>) -> Unit): Builder<RequestMeta> {
            this.errorLogger = errorLogger
            return this
        }

        /**
         * URL to the JavaScript file for the Skir Studio app.
         *
         * Skir Studio is a web interface for exploring and testing your Skir
         * service. It is served when the service receives a request at
         * '${serviceUrl}?studio'.
         *
         * @return `this` builder
         */
        fun setStudioAppJsUrl(studioAppJsUrl: String): Builder<RequestMeta> {
            this.studioAppJsUrl = URI(studioAppJsUrl).toString()
            return this
        }

        /** Builds the [Service] instance. */
        fun build() =
            Service<RequestMeta>(
                Impl(
                    methodImpls.toMap(),
                    ServiceOptions(
                        keepUnrecognizedValues,
                        maxNestingDepth,
                        canSendUnknownErrorMessage,
                        errorLogger,
                        studioAppJsUrl,
                    ),
                ),
            )
    }

    private class Impl<in RequestMeta>(
        val methodImpls: Map<Long, MethodImpl<*, *, RequestMeta>>,
        val options: ServiceOptions<RequestMeta>,
    ) {
        private fun getMethodNumberByName(methodName: String): Long? {
            val nameMatches = methodImpls.values.filter { it.method.name == methodName }
            return when {
                nameMatches.isEmpty() -> null
                nameMatches.size > 1 -> null
                else -> nameMatches[0].method.number
            }
        }

        suspend fun handleRequest(
            requestBody: String,
            requestMeta: RequestMeta,
        ): RawResponse {
            if (requestBody == "list") {
                val methodsData =
                    JsonArray(
                        methodImpls.values.map { methodImpl ->
                            JsonObjectBuilder()
                                .put("method", JsonPrimitive(methodImpl.method.name))
                                .put("number", JsonPrimitive(methodImpl.method.number))
                                .put("request", methodImpl.method.requestSerializer.typeDescriptor.asJson())
                                .put("response", methodImpl.method.responseSerializer.typeDescriptor.asJson())
                                .putUnlessEmpty("doc", JsonPrimitive(methodImpl.method.doc))
                                .build()
                        },
                    )
                val json = JsonObject(mapOf("methods" to methodsData))
                val jsonCode =
                    formatReadableJson(json)
                return RawResponse.okJson(jsonCode)
            } else if (requestBody.isEmpty() || requestBody == "studio") {
                return RawResponse.okHtml(getStudioHtml(options.studioAppJsUrl))
            }

            // Method invocation
            val methodName: String
            val methodNumber: Long
            val format: String
            val requestDataJson: JsonElement?
            val requestDataCode: String?

            val firstChar = requestBody[0]
            if (firstChar.isWhitespace() || firstChar == '{') {
                // A JSON object
                if (options.maxNestingDepth > 0) {
                    try {
                        val envelopeMaxNestingDepth =
                            if (options.maxNestingDepth == Int.MAX_VALUE) {
                                Int.MAX_VALUE
                            } else {
                                options.maxNestingDepth + 1
                            }
                        expectDepthWithinLimit(requestBody, envelopeMaxNestingDepth)
                    } catch (e: Exception) {
                        return RawResponse.badRequest(
                            "bad request: maximum nesting depth ${options.maxNestingDepth} reached",
                        )
                    }
                }
                val reqBodyJson: JsonObject =
                    try {
                        kotlinx.serialization.json.Json.parseToJsonElement(requestBody) as? JsonObject
                            ?: return RawResponse.badRequest(
                                "bad request: expected JSON object",
                            )
                    } catch (e: Exception) {
                        return RawResponse.badRequest("bad request: invalid JSON")
                    }

                val methodField =
                    reqBodyJson["method"]
                        ?: return RawResponse.badRequest(
                            "bad request: missing 'method' field in JSON",
                        )

                when (methodField) {
                    is JsonPrimitive -> {
                        if (methodField.isString) {
                            methodName = methodField.content
                            // Try to get the method number by name
                            val foundNumber = getMethodNumberByName(methodName)
                            if (foundNumber == null) {
                                val nameMatches = methodImpls.values.filter { it.method.name == methodName }
                                return if (nameMatches.isEmpty()) {
                                    RawResponse.badRequest(
                                        "bad request: method not found: $methodName",
                                    )
                                } else {
                                    RawResponse.badRequest(
                                        "bad request: method name '$methodName' is ambiguous; " +
                                            "use method number instead",
                                    )
                                }
                            }
                            methodNumber = foundNumber
                        } else {
                            methodName = "?"
                            methodNumber = methodField.content.toLongOrNull()
                                ?: return RawResponse.badRequest(
                                    "bad request: 'method' field must be a string or an integer",
                                )
                        }
                    }
                    else -> {
                        return RawResponse.badRequest(
                            "bad request: 'method' field must be a string or an integer",
                        )
                    }
                }

                format = "readable"

                val requestField =
                    reqBodyJson["request"]
                        ?: return RawResponse.badRequest(
                            "bad request: missing 'request' field in JSON",
                        )

                requestDataJson = requestField
                requestDataCode = null
            } else {
                // A colon-separated string
                val regex = Regex("^([^:]*):([^:]*):([^:]*):(\\S[\\s\\S]*)$")
                val matchResult =
                    regex.find(requestBody)
                        ?: return RawResponse.badRequest(
                            "bad request: invalid request format",
                        )

                val (methodNamePart, methodNumberStr, formatPart, requestDataPart) = matchResult.destructured

                methodName = methodNamePart
                format = formatPart
                requestDataJson = null
                requestDataCode = requestDataPart

                if (methodNumberStr.isNotEmpty()) {
                    val methodNumberRegex = Regex("-?[0-9]+")
                    if (!methodNumberRegex.matches(methodNumberStr)) {
                        return RawResponse.badRequest(
                            "bad request: can't parse method number",
                        )
                    }
                    methodNumber = methodNumberStr.toLong()
                } else {
                    // Try to get the method number by name
                    val foundNumber = getMethodNumberByName(methodName)
                    if (foundNumber == null) {
                        val nameMatches = methodImpls.values.filter { it.method.name == methodName }
                        return if (nameMatches.isEmpty()) {
                            RawResponse.badRequest(
                                "bad request: method not found: $methodName",
                            )
                        } else {
                            RawResponse.badRequest(
                                "bad request: method name '$methodName' is ambiguous; use method number instead",
                            )
                        }
                    }
                    methodNumber = foundNumber
                }
            }

            val methodImpl =
                methodImpls[methodNumber]
                    ?: return RawResponse.badRequest(
                        "bad request: method not found: $methodName; number: $methodNumber",
                    )

            val unrecognizedValues =
                if (options.keepUnrecognizedValues) {
                    UnrecognizedValuesPolicy.KEEP
                } else {
                    UnrecognizedValuesPolicy.DROP
                }

            val req: Any? =
                try {
                    if (requestDataCode != null) {
                        methodImpl.method.requestSerializer.fromJsonCode(
                            requestDataCode,
                            unrecognizedValues,
                            if (options.maxNestingDepth > 0) options.maxNestingDepth else -1,
                        )
                    } else {
                        methodImpl.method.requestSerializer.fromJson(requestDataJson!!, unrecognizedValues)
                    }
                } catch (e: Exception) {
                    return RawResponse.badRequest(
                        "bad request: can't parse JSON: ${e.message}",
                    )
                }

            val res: Any =
                @Suppress("UNCHECKED_CAST")
                try {
                    (methodImpl.impl as suspend (Any?, RequestMeta) -> Any)(req, requestMeta)
                } catch (e: Throwable) {
                    val errorContext =
                        MethodErrorInfo(
                            error = e,
                            method = methodImpl.method as Method<Any?, *>,
                            request = req,
                            requestMeta = requestMeta,
                        )
                    options.errorLogger(errorContext)
                    return if (e is ServiceException) {
                        e.toRawResponse()
                    } else {
                        val message =
                            if (options.canSendUnknownErrorMessage(errorContext)) {
                                "server error: ${e.message}"
                            } else {
                                "server error"
                            }
                        RawResponse.serverError(message)
                    }
                }

            val resJson: String =
                try {
                    val jsonFlavor = if (format == "readable") JsonFlavor.READABLE else JsonFlavor.DENSE
                    @Suppress("UNCHECKED_CAST")
                    (methodImpl.method as Method<Any?, Any?>).responseSerializer.toJsonCode(res, jsonFlavor)
                } catch (e: Exception) {
                    return RawResponse.serverError(
                        "server error: can't serialize response to JSON: ${e.message}",
                    )
                }

            return RawResponse.okJson(resJson)
        }
    }

    companion object {
        private fun getStudioHtml(studioAppJsUrl: String): String {
            // Copied from
            //   https://github.com/gepheum/skir-studio/blob/main/index.jsdeliver.html
            // No escaping needed because 'studioAppJsUrl' is validated as a URI
            return """<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src="$studioAppJsUrl"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
"""
        }
    }
}
