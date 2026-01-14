# Skir services

Skir provides a transport-agnostic RPC (Remote Procedure Call) framework that lets you define API methods in your schema and implement them in your preferred programming language.

Unlike many RPC frameworks that couple your code to a specific transport protocol or server implementation, Skir services are designed to be embedded within your existing application stack. See the following examples:
*   **Java**: [Spring Boot](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/StartService.java)
*   **Kotlin**: [Ktor](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/startservice/StartService.kt)
*   **Dart**: [Shelf](https://github.com/gepheum/skir-dart-example/blob/main/lib/all_strings_to_upper_case.dart)
*   **Python**: [FastAPI](https://github.com/gepheum/skir-python-example/blob/main/start_service_fastapi.py), [Flask](https://github.com/gepheum/skir-python-example/blob/main/start_service_flask.py), or [Starlite](https://github.com/gepheum/skir-python-example/blob/main/start_service_starlite.py)
*   **TypeScript**: [Express](https://github.com/gepheum/skir-typescript-example/blob/main/src/server.ts)
*   **C++**: [httplib](https://github.com/gepheum/skir-cc-example/blob/main/service_start.cc)

Features like authentification, request logging or rate limiting are handled by the underlying framework.

### Why use Skir services?

The primary advantage of using Skir services is **end-to-end type safety**.

In a traditional REST API, the contract between client and server is often implicit: *Send a JSON object with fields `x` and `y` to `/api/foo`, and receive a JSON object with field `z`.* This contract is fragile; if the server code changes the expected keys but the client isn't updated, the API breaks at runtime.

Skir enforces this contract at compile time. By defining your methods in a `.skir` schema, both your server implementation and your client calls are generated from the same source of truth. You cannot call a method that doesn't exist, pass the wrong arguments, or mishandle the response type without the compiler alerting you immediately.

> [!NOTE]
> Skir solves the same problem as [**tRPC**](https://trpc.io/), but it is **language-agnostic**. While tRPC is excellent for full-stack TypeScript applications, Skir brings that same level of developer experience and safety to polyglot environments (e.g., a TypeScript frontend talking to a Kotlin or Python backend).

### Use cases

Skir services are versatile and can be used in two main contexts:
1.  **Microservices**: Similar to **gRPC**, Skir allows efficiently typed communication between backend services.
2.  **Browser-to-Backend**: Skir works seamlessly over standard HTTP/JSON, making it perfect for connecting a web frontend (React, Vue, etc.) to your backend.

## Defining methods

In Skir, a service is simply a collection of methods. You define methods in your `.skir` files using the `method` keyword.

```d
// Defines a method named 'GetUser' which takes a GetUserRequest and returns a GetUserResponse
method GetUser(GetUserRequest): GetUserResponse = 12345;
```

A method definition specifies the **request** type, the **response** type, and a stable numeric identifier.

> [!NOTE]
> Methods are defined globally in your schema. Skir does not group methods into "Service" blocks in the `.skir` file. You decide how to group and implement methods in your application code.

## Implementing a service

> *The examples below use Python, but the concepts apply identically to all supported languages.*

Skir provides a `Service` class in its runtime library for each supported language. This class acts as a central dispatcher that handles deserialization, routing, and serialization.

To create a service, you instantiate the `Service` class and register your method implementations.

### 1. The `RequestMeta` concept

Skir services are generic over a `RequestMeta` type. This is a type you define to hold context information extracted from the HTTP request, such as authentication tokens, user sessions, or client IP addresses. This metadata is passed to your method implementations along with the request body.

```python
from dataclasses import dataclass
import skir

@dataclass
class RequestMeta:
    auth_token: str
    client_ip: str


# Create an async service typed with our metadata class
service = skir.ServiceAsync[RequestMeta]()
```

### 2. Registering methods

You link the abstract method definitions generated from your schema to your actual code logic.

```python
from skirout.user import GetUser, GetUserRequest, GetUserResponse

async def get_user(req: GetUserRequest, meta: RequestMeta) -> GetUserResponse:
    # We have type-safe access to both the request fields and our metadata
    print(f"Request from IP: {meta.client_ip}")
    return GetUserResponse(user=await db.get_user(req.user_id))

# Typing error if the signature of get_user does not match GetUser.
service.add_method(GetUser, get_user)
```

## Running the service

Skir does not start its own HTTP server. Instead, it provides a `handle_request` method that you call from your existing web server's request handler.

This `handle_request` method takes:
1.  The raw request body (as a string).
2.  Your constructed `RequestMeta` object.

It returns a generated response containing the status code, content type, and body data, which you seamlessly write back to your HTTP client.

Since Skir manages the request body parsing and routing internally, you typically only need **one HTTP endpoint** (e.g., `/api`) to serve your entire API.

```python
# FastAPI example
from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI()


@app.api_route("/myapi", methods=["GET", "POST"])
async def myapi(request: Request):
    # 1. Read body
    if request.method == "POST":
        req_body = (await request.body()).decode("utf-8")
    else:
        req_body = urllib.parse.unquote(
            request.url.query.encode("utf-8").decode("utf-8")
        )

    # 2. Build metadata from framework-specific request object
    req_meta = extract_meta_from_request(request)

    # 3. Delegate to Skir
    raw_response = await skir_service.handle_request(req_body, req_headers)

    # 4. Map back to framework response
    return Response(
        content=raw_response.data,
        status_code=raw_response.status_code,
        media_type=raw_response.content_type,
    )


def extract_meta_from_request(request: Request) -> RequestMeta:
    ...
```

## Calling a service

### Using Skir Clients

Skir generates a type-safe `ServiceClient` class that abstracts away the network layer. This ensures that your client code is always in sync with your API definition.

```python
from skir import ServiceClient
import aiohttp

# 1. Initialize the client with your service URL
client = ServiceClient("http://localhost:8000/api")

async def main():
    async with aiohttp.ClientSession() as session:
         # 2. Call methods directly using the generated definitions
        response = await client.invoke_remote_async(
            session,
            GetUser,
            GetUserRequest(user_id="u_123"),
            headers={"Authorization": "Bearer token"}
        )
        
        # 'response' is fully typed as 'GetUserResponse'
        print(response.user.name)
```

See examples for:
*   **Java**: [CallService.java](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/CallService.java)
*   **Kotlin**: [CallService.kt](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/callservice/CallService.kt)
*   **Dart**: [call_service.dart](https://github.com/gepheum/skir-dart-example/blob/main/bin/call_service.dart)
*   **Python**: [call_service.py](https://github.com/gepheum/skir-python-example/blob/main/call_service.py)
*   **TypeScript**: [client.ts](https://github.com/gepheum/skir-typescript-example/blob/main/src/client.ts)
*   **C++**: [service_client.cc](https://github.com/gepheum/skir-cc-example/blob/main/service_client.cc)

### Using cURL

You can also invoke Skir methods using any HTTP client by sending a POST request with a JSON body. The body must follow a specific structure identifying the method and its arguments.

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"method": "GetUser", "request": {"user_id": "u_123"}}' \
  http://localhost:8787/api
```

## Skir Studio

Every Skir service comes with a built-in interactive documentation and testing tool called **Skir Studio**.

To access it, simply visit your API endpoint in a browser with the `?studio` query parameter (e.g., `http://localhost:8000/api?studio`). Skir serves a lightweight HTML page that inspects your service, lists all available methods, and provides auto-generated forms to send test requests and view responses.

> [!TIP]
> If you are familiar with **Swagger UI** (common in the FastAPI ecosystem), Skir Studio fills the same role. It provides a dedicated, auto-generated web interface to explore your API schema and execute requests interactively.
