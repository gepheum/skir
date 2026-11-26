# Project examples

Browse these repositories to see how Skir fits into different stacks and workflows. Each example is designed to spotlight a specific integration pattern or capability.

## Language starter projects

Each starter focuses on the same core workflow, implemented in a different language. They all demonstrate how to:

- Set up Skir in a project and run code generation.
- Use generated data classes in application code.
- Start a SkirRPC service on the server side and call it from a client.
- Inspect types at runtime via reflection.
- Optional: write language-specific unit tests.

| Language | Server framework | Notes | Source |
| --- | --- | --- | --- |
| **C++** | cpp-httplib | CMake + GoogleTest integration. | [GitHub](https://github.com/gepheum/skir-cc-example) |
| **C#** | ASP.NET Core | NET 10 project with skir_client NuGet runtime dependency. | [GitHub](https://github.com/gepheum/skir-csharp-example) |
| **Dart** | Shelf | Dart 3 project with pub dependencies. | [GitHub](https://github.com/gepheum/skir-dart-example) |
| **Elixir** | Plug + Bandit | Mix project with Elixir and TypeScript RPC clients. | [GitHub](https://github.com/mishmish-dev/skir-elixir-example) |
| **Gleam** | Wisp | Gleam project with generated Skir types and RPC wiring. | [GitHub](https://github.com/gepheum/skir-gleam-example) |
| **Go** | net/http | Standard library HTTP server, no external framework. | [GitHub](https://github.com/gepheum/skir-go-example) |
| **Java** | Spring Boot | Gradle build and run workflow. | [GitHub](https://github.com/gepheum/skir-java-example) |
| **Kotlin** | Ktor | Gradle Kotlin DSL setup. | [GitHub](https://github.com/gepheum/skir-kotlin-example) |
| **MoonBit** | moonbit/http | MoonBit package workflow with generated Skir RPC endpoints. | [GitHub](https://github.com/gepheum/skir-moonbit-example) |
| **Python** | Flask / FastAPI / Litestar | Multiple server frameworks included. | [GitHub](https://github.com/gepheum/skir-python-example) |
| **Rust** | Axum | Cargo workspace, async Axum server. | [GitHub](https://github.com/gepheum/skir-rust-example) |
| **Scala** | jdk.httpserver | Gradle build with Scala 3. | [GitHub](https://github.com/gepheum/skir-scala-example) |
| **Swift** | Vapor | SwiftPM package with generated sources under Sources/skirout. | [GitHub](https://github.com/gepheum/skir-swift-example) |
| **TypeScript** | Express | Node server + browser client bundle. | [GitHub](https://github.com/gepheum/skir-typescript-example) |
| **Zig** | std.http.Server | Zig build workflow with Skir client dependency in build.zig.zon. | [GitHub](https://github.com/gepheum/skir-zig-example) |

## Projects and demos

Complete applications and specialized projects showing Skir in real usage.

| Project | Type | Backend | Frontend | Source |
| --- | --- | --- | --- | --- |
| **Multilingual Skir example**<br>Minimal web app showing a Python backend and TypeScript frontend exchanging typed RPC messages. | End-to-end app | Python (http.server) | TypeScript (Vite) | [GitHub](https://github.com/gepheum/skir-multilingual-example) |
| **Intergalactic Lost & Found**<br>Full-stack demo with a Kotlin backend and TypeScript frontend that share Skir RPC types end-to-end. | End-to-end app | Kotlin (Ktor) | TypeScript (Vite) | [GitHub](https://github.com/gepheum/skir-lost-and-found-example) |
| **Fantasy Game schema package**<br>Standalone schema repository intended to be imported as a Skir dependency from other projects. | Schema-only project | — | — | [GitHub](https://github.com/gepheum/skir-fantasy-game-example) |
| **RPC Studio demo**<br>TypeScript geometry service that highlights RPC Studio with rich request and response types and interactive exploration. Run with `npx skir-studio-demo`. | Service demo | TypeScript (Express) | RPC Studio | [GitHub](https://github.com/gepheum/skir-studio-demo) |
| **Hello Skir Flutter**<br>Mobile application built with Flutter, communicating with a Bun backend via SkirRPC. | End-to-end mobile app | TypeScript (Bun) | Flutter | [GitHub](https://github.com/gepheum/hello-skir-flutter) |
