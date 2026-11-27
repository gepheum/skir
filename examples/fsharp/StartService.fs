// Starts a SkirRPC service on http://localhost:8787/myapi
//
// Run with:
//   dotnet run -- start-service
//
// Use CallService to send requests to this service.

module StartService

open System
open System.Collections.Concurrent
open System.IO
open System.Text
open System.Threading.Tasks
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Http
open SkirClient
open Skirout_Service
open Skirout_User

let runAsync (args: string[]) : Task =
    task {
        // In-memory user store — keyed by UserId.
        let idToUser = ConcurrentDictionary<int, User>()

        // Build the Skir service by registering each generated method.
        let service =
            Service<obj>.Builder()
                .AddMethod(
                    Methods.GetUser,
                    fun req _ ->
                        let mutable user = User.Default
                        let found =
                            if idToUser.TryGetValue(req.UserId, &user) then
                                Some user
                            else
                                None
                        Task.FromResult(GetUserResponse.Create(user = found))
                )
                .AddMethod(
                    Methods.AddUser,
                    fun req _ ->
                        if req.User.UserId = 0 then
                            raise (ServiceError(HttpErrorCode._400_BadRequest, "user_id must be non-zero"))
                        printfn "Adding user: %s" req.User.Name
                        idToUser.[req.User.UserId] <- req.User
                        Task.FromResult(AddUserResponse.Default)
                )
                .Build()

        let builder = WebApplication.CreateBuilder(args)
        let app = builder.Build()

        app.MapGet("/", Func<string>(fun () -> "Hello, World!")) |> ignore

        // GET /myapi — request payload arrives as a URL-encoded query string.
        app.MapGet(
            "/myapi",
            Func<HttpContext, Task<IResult>>(fun ctx ->
                task {
                    let raw =
                        if ctx.Request.QueryString.HasValue then
                            ctx.Request.QueryString.Value.Substring(1)
                        else
                            ""
                    let decoded =
                        try
                            Uri.UnescapeDataString(raw)
                        with _ ->
                            raw
                    let! resp = service.HandleRequest(decoded, null)
                    return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, Nullable(int resp.StatusCode))
                })
        )
        |> ignore

        // POST /myapi — request payload arrives in the request body.
        app.MapPost(
            "/myapi",
            Func<HttpContext, Task<IResult>>(fun ctx ->
                task {
                    use reader =
                        new StreamReader(ctx.Request.Body, Encoding.UTF8, detectEncodingFromByteOrderMarks = false)
                    let! body = reader.ReadToEndAsync()
                    let! resp = service.HandleRequest(body, null)
                    return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, Nullable(int resp.StatusCode))
                })
        )
        |> ignore

        printfn "Listening on http://localhost:8787/myapi"
        do! app.RunAsync("http://localhost:8787")
    }
