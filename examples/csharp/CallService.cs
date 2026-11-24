// Sends RPCs to a SkirRPC service.
//
// Run with:
//   dotnet run -- call-service
//
// Make sure the service is already running first:
//   dotnet run -- start-service

using SkirClient;
using Skirout_Service;
using Skirout_User;

static class CallService
{
    public static async Task RunAsync()
    {
        using var client = new ServiceClient("http://localhost:8787/myapi");

        Console.WriteLine("\nAbout to add 2 users: John Doe and Tarzan");

        await client.InvokeRemote(Methods.AddUser, new AddUserRequest
        {
            User = new User
            {
                UserId = 42,
                Name = "John Doe",
                Quote = "Coffee is just a socially acceptable form of rage.",
                Pets = [],
                SubscriptionStatus = SubscriptionStatus.Free,
            },
        });

        // Extra HTTP headers can be passed to InvokeRemote.
        await client.InvokeRemote(
            Methods.AddUser,
            new AddUserRequest { User = Consts.Tarzan },
            extraHeaders: [new("X-Foo", "hi")]);

        Console.WriteLine("Done");

        // Retrieve one of the users we just added.
        var response = await client.InvokeRemote(
            Methods.GetUser,
            new GetUserRequest { UserId = Consts.Tarzan.UserId });

        if (response.User is User user)
            Console.WriteLine(
                $"Found user: {User.Serializer.ToJson(user, readable: true)}");
        else
            Console.WriteLine("User not found");
    }
}
