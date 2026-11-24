// How to run this example:
// 1) In one terminal: zig build run-start-service
// 2) In another terminal: zig build run-call-service

const std = @import("std");
const skir = @import("skir_client");
const service_mod = @import("skirout/service.zig");
const user_mod = @import("skirout/user.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const client = try skir.ServiceClient.init(allocator, "http://localhost:8787/myapi");
    defer client.deinit();

    std.debug.print("\nAbout to add 2 users: John Doe and Tarzan\n", .{});

    const john: user_mod.User = .{
        .user_id = 42,
        .name = "John Doe",
        .quote = "",
        .pets = &.{},
        .subscription_status = .Free,
        ._unrecognized = null,
    };

    try addUser(client, john, arena.allocator());
    try addUser(client, user_mod.tarzan_const, arena.allocator());

    std.debug.print("Done\n", .{});

    const get_request: service_mod.GetUserRequest = .{
        .user_id = 123,
        ._unrecognized = null,
    };
    const get_result = try client.invokeRemote(
        arena.allocator(),
        service_mod.get_user_method(),
        get_request,
    );

    switch (get_result) {
        .ok => |resp| {
            if (resp.user) |found_user| {
                const as_json = try user_mod.User.serializer().serialize(
                    allocator,
                    found_user,
                    .{ .format = .readableJson },
                );
                defer allocator.free(as_json);
                std.debug.print("Found user: {s}\n", .{as_json});
            } else {
                std.debug.print("User not found\n", .{});
            }
        },
        .err => |rpc_err| {
            std.debug.print(
                "GetUser failed with status {d}: {s}\n",
                .{ rpc_err.status_code, rpc_err.message },
            );
            return error.RemoteInvocationFailed;
        },
    }
}

fn addUser(
    client: *const skir.ServiceClient,
    user: user_mod.User,
    arena_allocator: std.mem.Allocator,
) !void {
    const request: service_mod.AddUserRequest = .{
        .user = user,
        ._unrecognized = null,
    };
    const result = try client.invokeRemote(
        arena_allocator,
        service_mod.add_user_method(),
        request,
    );

    switch (result) {
        .ok => {
            std.debug.print("Added user {s} (id={d})\n", .{ user.name, user.user_id });
        },
        .err => |rpc_err| {
            std.debug.print(
                "AddUser failed with status {d}: {s}\n",
                .{ rpc_err.status_code, rpc_err.message },
            );
            return error.RemoteInvocationFailed;
        },
    }
}
