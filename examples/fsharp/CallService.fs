// Sends RPCs to a SkirRPC service.
//
// Run with:
//   dotnet run -- call-service
//
// Make sure the service is already running first:
//   dotnet run -- start-service

module CallService

open System.Collections.Generic
open System.Threading.Tasks
open SkirClient
open Skirout_Service
open Skirout_User

let runAsync () : Task =
    task {
        use client = new ServiceClient("http://localhost:8787/myapi")

        printfn "\nAbout to add 2 users: John Doe and Tarzan"

        let! _ =
            client.InvokeRemote(
                Methods.AddUser,
                AddUserRequest.Create(
                    user =
                        User.Create(
                            userId = 42,
                            name = "John Doe",
                            quote = "Coffee is just a socially acceptable form of rage.",
                            subscriptionStatus = SubscriptionStatus.Free
                        )
                )
            )

        // Extra HTTP headers can be passed to InvokeRemote.
        let! _ =
            client.InvokeRemote(
                Methods.AddUser,
                AddUserRequest.Create(user = Consts.Tarzan),
                extraHeaders = [ KeyValuePair("X-Foo", "hi") ]
            )

        printfn "Done"

        // Retrieve one of the users we just added.
        let! response =
            client.InvokeRemote(
                Methods.GetUser,
                GetUserRequest.Create(userId = Consts.Tarzan.UserId)
            )

        match response.User with
        | Some user ->
            printfn "Found user: %s" (User.Serializer.ToJson(user, readable = true))
        | None ->
            printfn "User not found"
    }
