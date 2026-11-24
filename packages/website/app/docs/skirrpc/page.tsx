import { HoverVideo } from '@/components/hover-video'
import { NextPageLink } from '@/components/next-page-link'
import { CodeBlock, Note, Prose } from '@/components/prose'

export const metadata = {
  title: 'Typesafe APIs with SkirRPC - Skir Documentation',
  description: 'Build typesafe APIs with SkirRPC services.',
}

export default function RpcPage() {
  return (
    <Prose>
      <h1>Typesafe APIs with SkirRPC</h1>
      <p>
        A <strong>SkirRPC service</strong> is a typesafe HTTP API: a server and a client communicate
        using shared Skir data types. Your schema defines each method’s signature (request type and
        response type), and both the server code and the client code refer to those same
        schema-defined signatures—so you get a compile-time guarantee that both sides agree on the
        contract.
      </p>
      <p>
        SkirRPC services work equally well for communication between microservices, or between a
        frontend (browser/mobile app) and a backend. The protocol is lightweight and easy to
        integrate: you can attach a SkirRPC service handler to almost any HTTP server framework.
      </p>

      <h2>Core concepts</h2>
      <p>
        Building a SkirRPC service involves three main steps: defining the API schema, implementing
        the server logic, and calling the service.
      </p>

      <h3>API definition</h3>
      <p>
        Everything starts in your <code>.skir</code> schema. You define methods using the{' '}
        <code>method</code> keyword.
      </p>
      <CodeBlock language="skir">{`// calculator.skir

method Square(float32): float32 = 1001;
method SquareRoot(float32): float32 = 1002;`}</CodeBlock>
      <p>
        A method definition specifies the request type (input), the response type (output), and a
        stable numeric identifier.
      </p>
      <p>
        Methods are defined globally in your schema. Skir does not group methods into{' '}
        <em>service</em> blocks in the <code>.skir</code> file like Protocol Buffer does. You decide
        how to group and implement methods in your application code.
      </p>

      <h3>Implement the service</h3>
      <p>
        The Skir runtime library provides a <code>Service</code> class that handles all the heavy
        lifting: deserializing requests, routing to your code, serializing responses.
      </p>
      <Note type="info">
        <p>
          The examples below use Python, but the concepts apply identically to all supported
          languages.
        </p>
      </Note>

      <h4>Registering methods</h4>
      <p>
        You simply link the abstract method definitions from your schema to your Python functions
        (method implementations) using <code>add_method</code>.
      </p>
      <CodeBlock language="python">{`from skirout.calc import Square, SquareRoot
import math

async def square_impl(val: float, meta: RequestMeta) -> float:
    return val * val

async def sqrt_impl(val: float, meta: RequestMeta) -> float:
    if val < 0:
        raise ValueError("Cannot calculate square root of negative number")
    return math.sqrt(val)

service = skir.ServiceAsync[RequestMeta]
service.add_method(Square, square_impl)
service.add_method(SquareRoot, sqrt_impl)`}</CodeBlock>

      <h4>Request context</h4>
      <p>
        <code>RequestMeta</code> is a custom type you define to pass context (like auth tokens or
        user IDs) from the HTTP layer into your method logic. This context object is passed to every
        method implementation.
      </p>
      <p>
        If you do not need to extract any context from the request, you can simply define an empty
        class.
      </p>
      <CodeBlock language="python">{`from dataclasses import dataclass
import skir

@dataclass
class RequestMeta:
    auth_token: str
    client_ip: str


# Create an async service typed with our metadata class
service = skir.ServiceAsync[RequestMeta]`}</CodeBlock>

      <h3>Running the service</h3>
      <p>
        Skir does not start its own HTTP server. Instead, it provides a <code>handle_request</code>{' '}
        method that you call from your existing framework's request handler (FastAPI, Flask,
        Express, etc.).
      </p>
      <p>
        This allows you to leverage your framework's existing middleware for logging, auth, and rate
        limiting.
      </p>
      <CodeBlock language="python" filename="FastAPI example">{`from fastapi import FastAPI, Request
from fastapi.responses import Response
from .my_skir_service import service, RequestMeta

app = FastAPI()


# Mount the SkirRPC service into this FastAPI app
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
    raw_response = await service.handle_request(req_body, req_meta)

    # 4. Map back to framework response
    return Response(
        content=raw_response.data,
        status_code=raw_response.status_code,
        media_type=raw_response.content_type,
    )


def extract_meta_from_request(request: Request) -> RequestMeta:
    ...`}</CodeBlock>

      <h3>Call the service</h3>
      <p>Here is how you call a SkirRPC service directly from your application code.</p>
      <p>
        The Skir runtime library provides a <code>ServiceClient</code> class. You point it at your
        server URL, and use it to invoke your generated API methods.
      </p>
      <CodeBlock language="python">{`from skir import ServiceClient
import aiohttp
from skirout.calc import Square

# Initialize the client with your service URL
client = ServiceClient("http://localhost:8000/api")

async def main():
    async with aiohttp.ClientSession() as session:
        # Call methods directly using the generated definitions
        response = await client.invoke_remote_async(
            session,
            Square,
            5.0,
            headers={"Authorization": "Bearer token"}
        )

        print(response) # 25.0`}</CodeBlock>

      <h2>Code examples</h2>
      <div className="my-6 w-full overflow-y-auto">
        <table className="w-full border-collapse border border-border text-sm">
          <thead>
            <tr className="bg-secondary/50">
              <th className="border-b border-border p-4 text-left font-medium">Language</th>
              <th className="border-b border-border p-4 text-left font-medium">Server side</th>
              <th className="border-b border-border p-4 text-left font-medium">Client side</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">TypeScript</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-typescript-example/blob/main/src/server.ts"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Express
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-typescript-example/blob/main/src/client.ts"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Python</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-python-example/blob/main/start_service_flask.py"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Flask
                </a>
                ,{' '}
                <a
                  href="https://github.com/gepheum/skir-python-example/blob/main/start_service_fastapi.py"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  FastAPI
                </a>
                ,{' '}
                <a
                  href="https://github.com/gepheum/skir-python-example/blob/main/start_service_starlite.py"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Litestar
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-python-example/blob/main/call_service.py"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">C++</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-cc-example/blob/main/service_start.cc"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  cpp-httplib
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-cc-example/blob/main/service_client.cc"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Java</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/StartService.java"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Spring Boot
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/CallService.java"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">C#</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-csharp-example/blob/main/StartService.cs"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  ASP.NET Core
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-csharp-example/blob/main/CallService.cs"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Kotlin</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/startservice/StartService.kt"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Ktor
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/callservice/CallService.kt"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">MoonBit</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-moonbit-example/blob/main/src/start_service.mbt"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  moonbit/http
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-moonbit-example/blob/main/src/call_service.mbt"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Dart</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-dart-example/blob/main/bin/start_service.dart"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Shelf
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-dart-example/blob/main/bin/call_service.dart"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Go</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-go-example/blob/main/cmd/start-service/main.go"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  net/http
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-go-example/blob/main/cmd/call-service/main.go"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Zig</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-zig-example/blob/main/src/start_service.zig"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  std.http.Server
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-zig-example/blob/main/src/call_service.zig"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Swift</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-swift-example/blob/main/Sources/StartService/main.swift"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Vapor
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-swift-example/blob/main/Sources/CallService/main.swift"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Rust</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-rust-example/blob/main/src/bin/start_service.rs"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Axum
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-rust-example/blob/main/src/bin/call_service.rs"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Gleam</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-gleam-example/blob/main/src/start_service.gleam"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Wisp
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/gepheum/skir-gleam-example/blob/main/src/call_service.gleam"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
            <tr className="transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Elixir</td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/lib/skir_example/router.ex"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Plug + Bandit
                </a>
              </td>
              <td className="p-4 text-muted-foreground">
                <a
                  href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/scripts/call_service.exs"
                  target="_blank"
                  rel="noreferrer"
                  className="underline hover:text-foreground"
                >
                  Client
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2>Why use SkirRPC services?</h2>
      <p>
        In a traditional REST API, the contract between client and server is implicit and fragile.
        If the server changes an endpoint but the client isn't updated, things break at runtime.
      </p>
      <p>
        Skir enforces this contract at compile time. Both your server implementation and your client
        calls are generated from the same source of truth. You cannot call a method that doesn't
        exist or pass wrong arguments without the compiler alerting you.
      </p>

      <h3>Versus traditional REST APIs</h3>
      <div className="my-6 w-full overflow-y-auto">
        <table className="w-full border-collapse border border-border text-sm">
          <thead>
            <tr className="bg-secondary/50">
              <th className="border-b border-border p-4 text-left font-medium">Feature</th>
              <th className="border-b border-border p-4 text-left font-medium">
                Traditional API (REST)
              </th>
              <th className="border-b border-border p-4 text-left font-medium">
                SkirRPC service (RPC)
              </th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Endpoint</td>
              <td className="p-4 text-muted-foreground">
                Resource-based (e.g. <code>/users/123</code>)
              </td>
              <td className="p-4 text-muted-foreground">
                Single URL (e.g. <code>/api</code>)
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Operations</td>
              <td className="p-4 text-muted-foreground">
                Endpoint + HTTP verb (e.g. <code>GET /users/123</code>)
              </td>
              <td className="p-4 text-muted-foreground">
                Methods defined in the <code>.skir</code> file (e.g. <code>GetUser</code>)
              </td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Input</td>
              <td className="p-4 text-muted-foreground">Path params, query params, JSON body</td>
              <td className="p-4 text-muted-foreground">Strongly-typed request</td>
            </tr>
            <tr className="border-b border-border transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Output</td>
              <td className="p-4 text-muted-foreground">JSON with implicit structure</td>
              <td className="p-4 text-muted-foreground">Strongly-typed response</td>
            </tr>
            <tr className="transition-colors hover:bg-muted/50">
              <td className="p-4 font-medium">Client</td>
              <td className="p-4 text-muted-foreground">Manual fetch/axios calls</td>
              <td className="p-4 text-muted-foreground">
                Typesafe, handles serialization and transport
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <Note type="info">
        <p>
          Skir solves the same problem as{' '}
          <a href="https://trpc.io" target="_blank" rel="noreferrer" className="hover:underline">
            <strong>tRPC</strong>
          </a>
          , but it is <strong>language-agnostic</strong>. While tRPC is excellent for full-stack
          TypeScript applications, Skir brings that same level of developer experience and safety to
          polyglot environments (e.g., a TypeScript frontend talking to a Kotlin or Python backend).
        </p>
      </Note>

      <h2>Tooling</h2>

      <h3>RPC Studio</h3>
      <p>
        Every SkirRPC service comes with a built-in interactive documentation and testing tool
        called RPC Studio.
      </p>
      <p>
        To access it, simply visit your API endpoint in a browser with the <code>?studio</code>{' '}
        query parameter (e.g., <code>http://localhost:8000/api?studio</code>). Skir serves a
        lightweight HTML page that inspects your service, lists all available methods, and allows
        you to quickly send requests and view responses.
      </p>
      <div className="not-prose pt-[2px] max-w-full mx-auto mb-8">
        <HoverVideo src="/rpc-studio.mp4" />
      </div>
      <p>You can try out a demo:</p>
      <CodeBlock language="bash">{`npx skir-studio-demo`}</CodeBlock>
      <Note type="tip">
        <p>
          If you are familiar with <strong>Swagger UI</strong> (common in the FastAPI ecosystem),
          RPC Studio fills the same role. It provides a dedicated, auto-generated web interface to
          explore your API schema and execute requests interactively.
        </p>
      </Note>
      <p>
        RPC Studio also lets you download a lightweight instruction file that you can pass to an AI
        agent. It teaches the agent how to call your API, what each method does, and the
        input/output schema for each method.
      </p>
      <div className="not-prose max-w-full mx-auto mb-8 rounded-lg overflow-hidden border border-border">
        <img
          src="/studio-llms.png"
          alt="RPC Studio agent-ready instruction file"
          className="w-full h-auto"
        />
      </div>

      <h3>Sending requests with cURL</h3>
      <p>
        Since Skir runs over standard HTTP, you can also inspect or call it manually. Requests are
        just POSTs with a JSON body specifying the method name and arguments.
      </p>
      <CodeBlock language="bash">{`curl -X POST \\
  -H "Content-Type: application/json" \\
  -d '{"method": "Square", "request": 5.0}' \\
  http://localhost:8000/api`}</CodeBlock>

      <NextPageLink title="GitHub imports" href="/docs/github-imports" />
    </Prose>
  )
}
