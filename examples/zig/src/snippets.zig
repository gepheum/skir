// Code snippets showing how to use Zig-generated data types.
//
// Run with: zig build run

const std = @import("std");
const skir = @import("skir_client");
const user_mod = @import("skirout/user.zig");
const service_mod = @import("skirout/service.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // =========================================================================
    // STRUCT TYPES
    // =========================================================================

    // Skir generates a plain Zig struct for each struct in the .skir schema.
    const john: user_mod.User = .{
        .user_id = 42,
        .name = "John Doe",
        .quote = "Coffee is just a socially acceptable form of rage.",
        .pets = &.{.{
            .name = "Dumbo",
            .height_in_meters = 1.0,
            .picture = "🐘",
            ._unrecognized = null,
        }},
        .subscription_status = .Free,
        ._unrecognized = null, // Present in every struct; always set to null
    };

    std.debug.print("{s}\n", .{john.name});
    // John Doe

    // To create a value with only some fields set, start from the default
    // and override what you need. All other fields keep their default values.
    var jane = user_mod.User.default;
    jane.name = "Jane";
    jane.quote = "I came, I saw, I deleted the cache.";
    std.debug.print("{s}\n", .{jane.name});
    // Jane
    std.debug.print("{d}\n", .{jane.user_id});
    // 0

    // For a shallow copy, use a plain assignment.
    var evil_jane = jane;
    evil_jane.name = "Evil Jane";

    // For a deep copy, use clone().
    var evil_john = try john.clone(arena_allocator);
    evil_john.name = "Evil John";
    evil_john.quote = "I solemnly swear I am up to no good.";

    std.debug.print("{s}\n", .{evil_john.name});
    // Evil John
    std.debug.print("{d}\n", .{evil_john.user_id});
    // 42

    // =========================================================================
    // ENUM TYPES
    // =========================================================================

    const trial_payload: user_mod.SubscriptionStatus.Trial_ = .{
        .start_time = .{ .unix_millis = 1_744_974_198_000 },
        ._unrecognized = null,
    };

    const some_statuses = [_]user_mod.SubscriptionStatus{
        user_mod.SubscriptionStatus.unknown,
        .Free,
        .Premium,
        .{ .Trial = &trial_payload },
    };
    _ = some_statuses;

    // =========================================================================
    // ENUM MATCHING
    // =========================================================================

    std.debug.print("{s}\n", .{subscriptionInfoText(john.subscription_status)});
    // Free user
    std.debug.print("{s}\n", .{subscriptionInfoText(user_mod.SubscriptionStatus.unknown)});
    // Unknown subscription status
    std.debug.print("{s}\n", .{subscriptionInfoText(.{ .Trial = &trial_payload })});
    // On trial since (some timestamp)

    // =========================================================================
    // SERIALIZATION
    // =========================================================================

    const user_serializer = user_mod.User.serializer();

    const john_dense_json = try user_serializer.serialize(
        arena_allocator,
        john,
        .{ .format = .denseJson },
    );
    std.debug.print("{s}\n", .{john_dense_json});
    // [42,"John Doe","Coffee is just a socially acceptable form of rage.",[["Dumbo",1,"🐘"]],1]

    const john_readable_json = try user_serializer.serialize(
        arena_allocator,
        john,
        .{ .format = .readableJson },
    );
    std.debug.print("{s}\n", .{john_readable_json});
    // {
    //   "user_id": 42,
    //   "name": "John Doe",
    //   ...
    // }

    const john_binary = try user_serializer.serialize(
        arena_allocator,
        john,
        .{ .format = .binary },
    );

    // deserialize() auto-detects the format (dense JSON, readable JSON, or
    // binary) from the input bytes — the same call works for all three.
    // Pass an arena allocator; everything allocated through it is freed at
    // once by calling arena.deinit().

    // Deserialize from dense JSON.
    const from_dense = try user_serializer.deserialize(
        arena_allocator,
        john_dense_json,
        .{},
    );
    std.debug.print("{s}\n", .{from_dense.name});
    // John Doe

    // Deserialize from readable JSON — same call, different bytes.
    const from_readable = try user_serializer.deserialize(
        arena_allocator,
        john_readable_json,
        .{},
    );
    std.debug.print("{s}\n", .{from_readable.name});
    // John Doe

    // Deserialize from binary — same call again.
    const from_binary = try user_serializer.deserialize(
        arena_allocator,
        john_binary,
        .{},
    );
    std.debug.print("{s}\n", .{from_binary.name});
    // John Doe

    // =========================================================================
    // PRIMITIVE SERIALIZERS
    // =========================================================================

    _ = try skir.boolSerializer().serialize(
        arena_allocator,
        true,
        .{ .format = .denseJson },
    );
    _ = try skir.int32Serializer().serialize(
        arena_allocator,
        @as(i32, 3),
        .{ .format = .denseJson },
    );
    _ = try skir.int64Serializer().serialize(
        arena_allocator,
        @as(i64, 9_223_372_036_854_775_807),
        .{ .format = .denseJson },
    );
    _ = try skir.hash64Serializer().serialize(
        arena_allocator,
        @as(u64, 18_446_744_073_709_551_615),
        .{ .format = .denseJson },
    );
    _ = try skir.timestampSerializer().serialize(
        arena_allocator,
        skir.Timestamp{ .unix_millis = 1_743_682_787_000 },
        .{ .format = .denseJson },
    );
    _ = try skir.float32Serializer().serialize(
        arena_allocator,
        @as(f32, 3.14),
        .{ .format = .denseJson },
    );
    _ = try skir.float64Serializer().serialize(
        arena_allocator,
        @as(f64, 3.14),
        .{ .format = .denseJson },
    );
    _ = try skir.stringSerializer().serialize(
        arena_allocator,
        "Foo",
        .{ .format = .denseJson },
    );
    _ = try skir.bytesSerializer().serialize(
        arena_allocator,
        @as([]const u8, &.{ 1, 2, 3 }),
        .{ .format = .denseJson },
    );

    // =========================================================================
    // COMPOSITE SERIALIZERS
    // =========================================================================

    const opt_string_ser = skir.optionalSerializer(skir.stringSerializer());
    _ = try opt_string_ser.serialize(
        arena_allocator,
        @as(?[]const u8, null),
        .{ .format = .denseJson },
    );

    const bool_array_ser = skir.arraySerializer(skir.boolSerializer());
    _ = try bool_array_ser.serialize(
        arena_allocator,
        @as([]const bool, &.{ true, false }),
        .{ .format = .denseJson },
    );

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    const tarzan = user_mod.tarzan_const;
    std.debug.print("{s}\n", .{tarzan.name});
    // Tarzan

    const tarzan_json = try user_serializer.serialize(
        arena_allocator,
        tarzan,
        .{ .format = .readableJson },
    );
    std.debug.print("{s}\n", .{tarzan_json});
    // {
    //   "user_id": 123,
    //   "name": "Tarzan",
    //   ...
    // }

    // =========================================================================
    // KEYED ARRAYS
    // =========================================================================

    var users = [_]user_mod.User{ john, jane, evil_john, tarzan };
    var registry = user_mod.UserRegistry{
        .users = skir.KeyedArray(user_mod.User.By_UserId).init(
            arena_allocator,
            users[0..],
        ),
        ._unrecognized = null,
    };

    const found = try registry.users.findByKey(42);
    if (found) |u| {
        std.debug.print("{s}\n", .{u.name});
        // Evil John (last duplicate wins)
    }

    const not_found = try registry.users.findByKey(43);
    std.debug.print("{}\n", .{not_found == null});
    // true

    const found_or_default = try registry.users.findByKeyOrDefault(999);
    std.debug.print("{d}\n", .{found_or_default.pets.len});
    // 0

    // =========================================================================
    // REFLECTION
    // =========================================================================

    const type_descriptor = user_serializer.typeDescriptor();
    switch (type_descriptor) {
        .struct_record => |sd| {
            std.debug.print("{s} has {d} fields\n", .{ sd.name, sd.fields.len });
            // User has 5 fields
            if (sd.fieldByName("name")) |f| {
                std.debug.print("field 'name' number={d}\n", .{f.number});
                // field 'name' number=1
            }
        },
        else => {},
    }

    const enum_type_descriptor =
        user_mod.SubscriptionStatus.serializer().typeDescriptor();
    switch (enum_type_descriptor) {
        .enum_record => |ed| {
            std.debug.print("{s} has {d} variants\n", .{ ed.name, ed.variants.len });
            // SubscriptionStatus has 3 variants
            if (ed.variantByName("trial")) |variant| {
                std.debug.print("variant trial number={d}\n", .{variant.number()});
                // variant trial number=2
            }
        },
        else => {},
    }
}

fn subscriptionInfoText(status: user_mod.SubscriptionStatus) []const u8 {
    return switch (status) {
        .Unknown => "Unknown subscription status",
        .Free => "Free user",
        .Trial => |trial| blk: {
            _ = trial;
            break :blk "On trial since (some timestamp)";
        },
        .Premium => "Premium user",
    };
}
