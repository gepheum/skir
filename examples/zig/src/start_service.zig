// How to run this example:
// 1) In one terminal: zig build run-start-service
// 2) In another terminal: zig build run-call-service

const std = @import("std");
const httpz = @import("httpz");
const skir = @import("skir_client");
const service_mod = @import("skirout/service.zig");
const user_mod = @import("skirout/user.zig");

const StoredUser = struct {
    arena: std.heap.ArenaAllocator,
    user: user_mod.User,
};

const UserStore = struct {
    mutex: std.Thread.Mutex = .{},
    backing_allocator: std.mem.Allocator,
    map: std.AutoHashMap(i32, StoredUser),

    fn init(allocator: std.mem.Allocator) UserStore {
        return .{
            .backing_allocator = allocator,
            .map = std.AutoHashMap(i32, StoredUser).init(allocator),
        };
    }

    fn deinit(self: *UserStore) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.arena.deinit();
        }
        self.map.deinit();
    }
};

// Method impls match the signature expected by Service(*UserStore).addMethod:
//   fn(std.mem.Allocator, Request, *UserStore) MethodResult(Response)

fn getUser(
    allocator: std.mem.Allocator,
    request: service_mod.GetUserRequest,
    store: *UserStore,
) skir.MethodResult(service_mod.GetUserResponse) {
    _ = allocator;
    store.mutex.lock();
    defer store.mutex.unlock();
    const maybe_stored = store.map.getPtr(request.user_id);
    return .{ .ok = .{ .user = if (maybe_stored) |s| s.user else null } };
}

fn addUser(
    allocator: std.mem.Allocator,
    request: service_mod.AddUserRequest,
    store: *UserStore,
) skir.MethodResult(service_mod.AddUserResponse) {
    _ = allocator;

    if (request.user.user_id == 0) {
        return .{ .service_error = .{
            .status_code = ._400_BadRequest,
            .message = "invalid user id",
        } };
    }

    // Clone into a fresh arena before taking the lock.
    var arena = std.heap.ArenaAllocator.init(store.backing_allocator);
    const user = request.user.clone(arena.allocator()) catch {
        arena.deinit();
        return .{ .unknown_error = "failed to clone user" };
    };

    store.mutex.lock();
    const old = store.map.fetchPut(user.user_id, .{ .arena = arena, .user = user }) catch {
        store.mutex.unlock();
        arena.deinit();
        return .{ .unknown_error = "failed to insert user" };
    };
    store.mutex.unlock();

    // Free the displaced entry's arena outside the lock.
    if (old) |entry| entry.value.arena.deinit();

    std.debug.print("Added user {s} (id={d})\n", .{ user.name, user.user_id });

    return .{ .ok = service_mod.AddUserResponse.default };
}

const App = struct {
    service: *const skir.Service(*UserStore),
    user_store: *UserStore,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var user_store = UserStore.init(allocator);
    defer user_store.deinit();

    var service = try skir.Service(*UserStore).init(allocator);
    defer service.deinit();

    _ = try service.addMethod(service_mod.get_user_method(), getUser);
    _ = try service.addMethod(service_mod.add_user_method(), addUser);

    var app = App{
        .service = &service,
        .user_store = &user_store,
    };

    var server = try httpz.Server(*App).init(allocator, .{
        .address = .all(8787),
        .request = .{ .max_body_size = 1024 * 1024 },
    }, &app);
    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/", index, .{});
    router.all("/myapi", myApi, .{});

    std.debug.print("Listening on http://localhost:8787/myapi\n", .{});
    try server.listen();
}

fn index(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.body = "Hello, World!";
}

fn myApi(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const body_for_service = switch (req.method) {
        .GET => try skir.getPercentDecodedQueryFromUrl(req.arena, req.url.raw),
        .POST => req.body() orelse "",
        else => {
            res.status = 405;
            res.body = "method not allowed";
            return;
        },
    };

    const raw_response = try app.service.handleRequest(req.arena, body_for_service, app.user_store);
    res.status = raw_response.status_code;
    res.header("content-type", raw_response.content_type);
    res.body = raw_response.data;
}
