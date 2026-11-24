// Sends RPCs to the SkirRPC service. See StartService for how to start it.
//
// Run with:
//
//   swift run CallService
//
// Make sure the service is running first (using StartService or StartService).

import Foundation
import MyLib
import SkirClient

@main
struct CallService {
  static func main() async throws {
    let client = try SkirClient.ServiceClient(serviceUrl: "http://localhost:8787/myapi")

    // Add two users. The server assigns the userId, so we leave it at 0.
    let usersToAdd: [Skir.User] = [
      Skir.User.partial(
        userId: 42,
        name: "John Doe",
        quote: "Coffee is just a socially acceptable form of rage.",
        subscriptionStatus: .free
      ),
      Skir.tarzan,
    ]

    for user in usersToAdd {
      _ = try await client.invokeRemote(
        Skir.AddUser,
        request: Skir.AddUserRequest.partial(user: user)
      )
      print("Added user \"\(user.name)\"")
    }

    let resp = try await client.invokeRemote(
      Skir.GetUser,
      request: Skir.GetUserRequest.partial(userId: Skir.tarzan.userId)
    )

    if let user = resp.user {
      print("Got user: \(Skir.User.serializer.toJson(user, readable: true))")
    } else {
      print("User not found")
    }
  }
}
