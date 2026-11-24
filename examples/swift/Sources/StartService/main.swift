// Starts a SkirRPC service on http://localhost:8787/myapi using Vapor.
//
// Run with:
//
//   swift run StartService
//
// Use CallService to send requests to this service.

import Foundation
import MyLib
import SkirClient
import Vapor

// In-memory user store, safe for concurrent access.
actor UserStore {
  private var users: [Int32: Skir.User] = [:]

  func get(_ id: Int32) -> Skir.GetUserResponse {
    Skir.GetUserResponse(
      user: users[id]
    )
  }

  func add(_ user: Skir.User) -> Skir.AddUserResponse {
    users[user.userId] = user
    return Skir.AddUserResponse()
  }
}

@main
struct StartService {
  static func main() async throws {
    let store = UserStore()

    let service = try SkirClient.Service<Void>(methods: [
      .init(Skir.GetUser) { req, _ in
        return await store.get(req.userId)
      },
      .init(Skir.AddUser) { req, _ in
        return await store.add(req.user)
      },
    ])

    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)
    let app = try await Application.make(env)

    app.http.server.configuration.port = 8787

    // Shared handler: delegates to the SkirRPC service dispatcher.
    // GET requests carry the body in the query string (Skir Studio);
    // POST requests carry it in the request body (programmatic clients).
    let handler: @Sendable (Request) async -> Response = { req in
      let body: String
      if req.method == .GET {
        let query = req.url.query ?? ""
        body = query.removingPercentEncoding ?? query
      } else {
        body = req.body.string ?? ""
      }
      let raw = await service.handleRequest(body, meta: ())
      return Response(
        status: HTTPResponseStatus(statusCode: raw.statusCode),
        headers: HTTPHeaders([("Content-Type", raw.contentType)]),
        body: .init(string: raw.data)
      )
    }

    app.get("myapi", use: handler)
    app.post("myapi", use: handler)

    print("Listening on http://localhost:8787/myapi")
    try await app.execute()
    try await app.asyncShutdown()
  }
}
