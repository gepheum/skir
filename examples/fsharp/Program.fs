// Entry point — run with no arguments for Snippets, or specify a command:
//
//   dotnet run                  # code snippets (default)
//   dotnet run -- start-service # starts the RPC service
//   dotnet run -- call-service  # calls the running service

[<EntryPoint>]
let main args =
    match args |> Array.tryHead with
    | Some "start-service" ->
        (StartService.runAsync args.[1..]).GetAwaiter().GetResult()
    | Some "call-service" ->
        (CallService.runAsync ()).GetAwaiter().GetResult()
    | _ ->
        Snippets.run ()
    0
