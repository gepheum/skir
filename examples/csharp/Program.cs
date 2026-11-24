// Entry point — run with no arguments for Snippets, or specify a command:
//
//   dotnet run                  # code snippets (default)
//   dotnet run -- start-service # starts the RPC service
//   dotnet run -- call-service  # calls the running service

switch (args.FirstOrDefault())
{
    case "start-service":
        await StartService.RunAsync(args[1..]);
        break;
    case "call-service":
        await CallService.RunAsync();
        break;
    default:
        Snippets.Run();
        break;
}
