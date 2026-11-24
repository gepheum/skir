// Starts a SkirRPC service on http://localhost:8787/myapi
//
// Run with:
//   dotnet run -- start-service
//
// Use CallService to send requests to this service.

using System.Collections.Concurrent;
using System.Text;
using SkirClient;
using Skirout_Service;
using Skirout_User;

static class StartService
{
    public static async Task RunAsync(string[] args)
    {
        // In-memory user store — keyed by UserId.
        var idToUser = new ConcurrentDictionary<int, User>();

        // Build the Skir service by registering each generated method.
        var service = Service<object?>.Builder()
            .AddMethod(Methods.GetUser, (req, _) =>
            {
                idToUser.TryGetValue(req.UserId, out var user);
                return Task.FromResult(new GetUserResponse { User = user });
            })
            .AddMethod(Methods.AddUser, (req, _) =>
            {
                if (req.User.UserId == 0)
                    throw new ServiceError(
                        HttpErrorCode._400_BadRequest, "user_id must be non-zero");

                Console.WriteLine($"Adding user: {req.User.Name}");
                idToUser[req.User.UserId] = req.User;
                return Task.FromResult(AddUserResponse.Default);
            })
            .Build();

        // Wire the service to ASP.NET Core minimal API endpoints.
        var builder = WebApplication.CreateBuilder(args);
        var app = builder.Build();

        app.MapGet("/", () => "Hello, World!");

        // GET /myapi — request payload arrives as a URL-encoded query string.
        app.MapGet("/myapi", async (HttpContext ctx) =>
        {
            string raw = ctx.Request.QueryString.HasValue
                ? ctx.Request.QueryString.Value![1..]
                : string.Empty;
            string decoded;
            try { decoded = Uri.UnescapeDataString(raw); }
            catch { decoded = raw; }

            RawResponse resp = await service.HandleRequest(decoded, null);
            return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, resp.StatusCode);
        });

        // POST /myapi — request payload arrives in the request body.
        app.MapPost("/myapi", async (HttpContext ctx) =>
        {
            using var reader = new StreamReader(
                ctx.Request.Body, Encoding.UTF8, detectEncodingFromByteOrderMarks: false);
            string body = await reader.ReadToEndAsync();

            RawResponse resp = await service.HandleRequest(body, null);
            return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, resp.StatusCode);
        });

        Console.WriteLine("Listening on http://localhost:8787/myapi");
        await app.RunAsync("http://localhost:8787");
    }
}
