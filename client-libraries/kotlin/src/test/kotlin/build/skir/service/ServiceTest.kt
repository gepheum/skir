package build.skir.service

import build.skir.Serializers
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Test

class ServiceTest {
    data class Meta(val user: String)

    private val echoMethod =
        Method(
            name = "echo",
            number = 1,
            requestSerializer = Serializers.string,
            responseSerializer = Serializers.string,
            doc = "Echoes the input",
        )

    private val reverseMethod =
        Method(
            name = "reverse",
            number = 2,
            requestSerializer = Serializers.string,
            responseSerializer = Serializers.string,
            doc = "Reverses the input",
        )

    private val errorMethod =
        Method(
            name = "error",
            number = 3,
            requestSerializer = Serializers.string,
            responseSerializer = Serializers.string,
            doc = "Throws an error",
        )

    private val service =
        Service
            .Builder<Meta>()
            .addMethod(echoMethod) { req, meta ->
                // Basic implementation using meta
                "${meta.user}: $req"
            }
            .addMethod(reverseMethod) { req, _ ->
                req.reversed()
            }
            .addMethod(errorMethod) { req, _ ->
                if (req == "bad") {
                    throw ServiceException(HttpErrorCode.BAD_REQUEST, "Custom bad request")
                } else {
                    throw RuntimeException("Unexpected error")
                }
            }
            .build()

    private val defaultMeta = Meta("Alice")

    @Test
    fun `max depth limits both request formats and accounts for the envelope`() =
        runBlocking {
            val serializer = Serializers.list(Serializers.list(Serializers.int32))
            val method = Method("nested", 4, serializer, serializer, "")
            for (maxNestingDepth in listOf(-1, 0, 1, 2, Int.MAX_VALUE)) {
                var calls = 0
                val limitedService =
                    Service.Builder<Meta>()
                        .setMaxNestingDepth(maxNestingDepth)
                        .addMethod(method) { req, _ ->
                            calls++
                            req
                        }
                        .build()
                for (body in listOf("{\"method\":\"nested\",\"request\":[[42]]}", "nested::dense:[[42]]")) {
                    val response = limitedService.handleRequest(body, defaultMeta)
                    assertThat(response.statusCode).isEqualTo(if (maxNestingDepth == 1) 400 else 200)
                    if (maxNestingDepth != 1) {
                        assertThat(serializer.fromJsonCode(response.data)).isEqualTo(listOf(listOf(42)))
                    }
                }
                assertThat(calls).isEqualTo(if (maxNestingDepth == 1) 0 else 2)
            }
        }

    @Test
    fun `max depth checks the entire JSON envelope before decoding the request`() =
        runBlocking {
            var calls = 0
            val limitedService =
                Service.Builder<Meta>()
                    .setMaxNestingDepth(1)
                    .addMethod(echoMethod) { req, _ ->
                        calls++
                        req
                    }
                    .build()
            val accepted =
                limitedService.handleRequest(
                    "{\"method\":\"echo\",\"request\":\"hello\",\"extra\":[0]}",
                    defaultMeta,
                )
            assertThat(accepted.statusCode).isEqualTo(200)
            val rejected =
                limitedService.handleRequest(
                    "{\"method\":\"echo\",\"request\":\"hello\",\"extra\":[[0]]}",
                    defaultMeta,
                )
            assertThat(rejected.statusCode).isEqualTo(400)
            assertThat(rejected.data).contains("maximum nesting depth 1 reached")
            assertThat(calls).isEqualTo(1)
        }

    @Test
    fun `test handleRequest - list methods`() =
        runBlocking {
            val response = service.handleRequest("list", defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            assertThat(response.contentType).isEqualTo("application/json")

            val json = Json.parseToJsonElement(response.data).jsonObject
            val methods = json["methods"]!!.jsonArray

            assertThat(methods).hasSize(3)

            val method1 = methods[0].jsonObject
            assertThat(method1["method"]!!.jsonPrimitive.content).isEqualTo("echo")
            assertThat(method1["number"]!!.jsonPrimitive.content).isEqualTo("1")
            assertThat(method1["doc"]!!.jsonPrimitive.content).isEqualTo("Echoes the input")

            val method2 = methods[1].jsonObject
            assertThat(method2["method"]!!.jsonPrimitive.content).isEqualTo("reverse")
            assertThat(method2["number"]!!.jsonPrimitive.content).isEqualTo("2")
        }

    @Test
    fun `test handleRequest - studio`() =
        runBlocking {
            val response = service.handleRequest("studio", defaultMeta)
            assertThat(response.statusCode).isEqualTo(200)
            assertThat(response.contentType).isEqualTo("text/html; charset=utf-8")
            assertThat(response.data).contains("<!DOCTYPE html>")
            assertThat(response.data).contains("skir-studio-app")
        }

    @Test
    fun `test invoke method by name - json`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": "echo",
                    "request": "hello"
                }
                """.trimIndent()

            val response = service.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            val responseData = Json.parseToJsonElement(response.data).jsonPrimitive.content
            assertThat(responseData).isEqualTo("Alice: hello")
        }

    @Test
    fun `test invoke method by number - json`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": 2,
                    "request": "hello"
                }
                """.trimIndent()

            val response = service.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            val responseData = Json.parseToJsonElement(response.data).jsonPrimitive.content
            assertThat(responseData).isEqualTo("olleh")
        }

    @Test
    fun `test invoke method by number string - json`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": "2",
                    "request": "hello"
                }
                """.trimIndent()

            val response = service.handleRequest(requestBody, defaultMeta)

            // Should find by name first ("2"), fail, then NOT try number unless it's an int?
            // Let's check logic. Service.kt:
            // if (methodField.isString) -> methodName = content. getMethodNumberByName.
            // If not found, it errors. It does NOT try to parse string as number if lookup by name fails.
            // BUT wait, looking at Service.kt:
            //   if (methodField.isString) {
            //      methodName = methodField.content
            //      val foundNumber = getMethodNumberByName(methodName)
            //      ...
            // So sending "2" as string means looking for method named "2". We don't have one.
            // It should match logic in Service.kt.

            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("method not found: 2")
        }

    @Test
    fun `test invoke method - colon separated format`() =
        runBlocking {
            val requestBody = "echo::readable:\"world\""

            val response = service.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            val responseData = Json.parseToJsonElement(response.data).jsonPrimitive.content
            assertThat(responseData).isEqualTo("Alice: world")
        }

    @Test
    fun `test invoke method - colon separated format with number`() =
        runBlocking {
            // regex: ^([^:]*):([^:]*):([^:]*):(\S[\s\S]*)$
            // name:number:format:data

            val requestBody = ":2:readable:\"world\""

            val response = service.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            val responseData = Json.parseToJsonElement(response.data).jsonPrimitive.content
            assertThat(responseData).isEqualTo("dlrow")
        }

    @Test
    fun `test method not found`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": "unknown",
                    "request": "foo"
                }
                """.trimIndent()

            val response = service.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("method not found")
        }

    @Test
    fun `test service exception`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": "error",
                    "request": "bad"
                }
                """.trimIndent()

            val response = service.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("Custom bad request")
        }

    @Test
    fun `test internal server error - masked`() =
        runBlocking {
            val requestBody =
                """
                {
                    "method": "error",
                    "request": "crash"
                }
                """.trimIndent()

            // Default behavior masks error
            val response = service.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(500)
            assertThat(response.data).isEqualTo("server error")
        }

    @Test
    fun `test internal server error - unmasked`() =
        runBlocking {
            val unsafeService =
                Service.Builder<Meta>()
                    .addMethod(errorMethod) { _, _ -> throw RuntimeException("Secret info") }
                    .setCanSendUnknownErrorMessage(true)
                    .build()

            val requestBody =
                """
                {
                    "method": "error",
                    "request": "whatever"
                }
                """.trimIndent()

            val response = unsafeService.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(500)
            assertThat(response.data).contains("Secret info")
        }

    @Test
    fun `test error logger`() =
        runBlocking {
            var capturedError: Throwable? = null
            var capturedMeta: Meta? = null

            val loggingService =
                Service.Builder<Meta>()
                    .addMethod(errorMethod) { _, _ -> throw RuntimeException("Log me") }
                    .setErrorLogger { context ->
                        capturedError = context.error
                        capturedMeta = context.requestMeta
                    }
                    .build()

            val requestBody =
                """
                {
                    "method": "error",
                    "request": "test"
                }
                """.trimIndent()

            loggingService.handleRequest(requestBody, Meta("Bob"))

            assertThat(capturedError).hasMessageThat().isEqualTo("Log me")
            assertThat(capturedMeta).isEqualTo(Meta("Bob"))
        }

    @Test
    fun `test ambiguous method name`() =
        runBlocking {
            // Create service with duplicate names (via logic - normally builder prevents same number,
            // but let's define two methods with same NAME but different NUMBERS)

            val m1 = Method("dup", 10, Serializers.string, Serializers.string, "")
            val m2 = Method("dup", 11, Serializers.string, Serializers.string, "")

            val ambiguousService =
                Service.Builder<Meta>()
                    .addMethod(m1) { _, _ -> "" }
                    .addMethod(m2) { _, _ -> "" }
                    .build()

            val requestBody =
                """
                {
                    "method": "dup",
                    "request": "test"
                }
                """.trimIndent()

            val response = ambiguousService.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("ambiguous")
        }

    @Test
    fun `test ambiguous method name resolution by number`() =
        runBlocking {
            val m1 = Method("dup", 10, Serializers.string, Serializers.string, "")
            val m2 = Method("dup", 11, Serializers.string, Serializers.string, "")

            val ambiguousService =
                Service.Builder<Meta>()
                    .addMethod(m1) { _, _ -> "one" }
                    .addMethod(m2) { _, _ -> "two" }
                    .build()

            val requestBody =
                """
                {
                    "method": 11,
                    "request": "test"
                }
                """.trimIndent()

            val response = ambiguousService.handleRequest(requestBody, defaultMeta)

            assertThat(response.statusCode).isEqualTo(200)
            val data = Json.parseToJsonElement(response.data).jsonPrimitive.content
            assertThat(data).isEqualTo("two")
        }

    @Test
    fun `test colon string format with invalid format`() =
        runBlocking {
            val requestBody = "not:valid"
            val response = service.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("invalid request format")
        }

    @Test
    fun `test invalid json`() =
        runBlocking {
            val requestBody = "{ invalid json }"
            val response = service.handleRequest(requestBody, defaultMeta)
            assertThat(response.statusCode).isEqualTo(400)
            assertThat(response.data).contains("invalid JSON")
        }
}
