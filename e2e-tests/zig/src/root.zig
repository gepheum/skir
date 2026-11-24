// Root module for the e2e test build. Imports generated skirout files to
// verify that the generated code compiles successfully.
const std = @import("std");
const structs = @import("skirout/structs.zig");

pub const skirout_constants = @import("skirout/constants.zig");
pub const skirout_enums = @import("skirout/enums.zig");
pub const skirout_full_name = @import("skirout/full_name.zig");
pub const skirout_methods = @import("skirout/methods.zig");
pub const skirout_ownership = @import("skirout/ownership.zig");
pub const skirout_quest_collection = @import("skirout/quest_collection.zig");
pub const skirout_reflection = @import("skirout/reflection.zig");
pub const skirout_schema_change = @import("skirout/schema_change.zig");
pub const skirout_service_user = @import("skirout/service_user.zig");
pub const skirout_service = @import("skirout/service.zig");
pub const skirout_shapes = @import("skirout/shapes.zig");
pub const skirout_structs = @import("skirout/structs.zig");
pub const skirout_user = @import("skirout/user.zig");
pub const skirout_vehicles_car = @import("skirout/vehicles/car.zig");
pub const skirout_external_fantasy_game =
    @import("skirout/external/gepheum/skir_fantasy_game_example/fantasy_game.zig");
pub const skirout_external_fantasy_game_items_loot =
    @import("skirout/external/gepheum/skir_fantasy_game_example/items/loot.zig");
pub const skirout_external_goldens =
    @import("skirout/external/gepheum/skir_golden_tests/goldens.zig");
pub const skir_client = @import("skir_client");

test "structs keyed array findByKeyOrDefault" {
    var keyed = structs.Items.default.array_with_bool_key;
    const value = try keyed.findByKeyOrDefault(true);
    try std.testing.expect(!value.bool);
}

test "structs simple value construction" {
    const point = structs.Point{
        .x = 12,
        .y = 34,
    };
    try std.testing.expectEqual(@as(i32, 12), point.x);
    try std.testing.expectEqual(@as(i32, 34), point.y);
}

test "structs nested value construction" {
    const triangle = structs.Triangle{
        .color = structs.Color{ .r = 1, .g = 2, .b = 3 },
        .points = &.{
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 0 },
            .{ .x = 0, .y = 1 },
        },
    };
    try std.testing.expectEqual(@as(i32, 2), triangle.color.g);
    try std.testing.expectEqual(@as(usize, 3), triangle.points.len);
}

test "structs serialize to readable json" {
    const point = structs.Point{ .x = 7, .y = 9 };
    const json = try structs.Point.serializer().serialize(
        std.testing.allocator,
        point,
        .{ .format = .readableJson },
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"x\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"y\"") != null);
}

test "enums obtain variant and kind" {
    const weekday: skirout_enums.Weekday = .Sunday;
    try std.testing.expect(weekday.kind() == .Sunday);
}

test "generated types support clone" {
    const point = structs.Point{ .x = 12, .y = 34 };
    const cloned_point = try point.clone(std.testing.allocator);
    try std.testing.expectEqual(@as(i32, 12), cloned_point.x);
    try std.testing.expectEqual(@as(i32, 34), cloned_point.y);

    const weekday: skirout_enums.Weekday = .Sunday;
    const cloned_weekday = try weekday.clone(std.testing.allocator);
    try std.testing.expect(cloned_weekday.kind() == .Sunday);
}

test "constants access values" {
    try std.testing.expectEqual(@as(i64, 9223372036854775807), skirout_constants.large_int64_const);
    try std.testing.expectEqual(@as(i64, 1703984028000), skirout_constants.one_timestamp_const.unix_millis);
    try std.testing.expectEqualStrings("\"Foo\"", skirout_constants.one_single_quoted_string_const);
    try std.testing.expectEqual(@as(i32, 255), skirout_constants.one_triangle_const.color.r);
    try std.testing.expectEqual(@as(usize, 3), skirout_constants.one_triangle_const.corners.len);

    const one_json = skirout_constants.one_constant_const();
    _ = one_json;
}

test "methods access values" {
    const procedure = skirout_methods.my_procedure_method();
    try std.testing.expectEqualStrings("MyProcedure", procedure.name);
    try std.testing.expectEqual(@as(i64, 674706602), procedure.number);

    const explicit = skirout_methods.with_explicit_number_method();
    try std.testing.expectEqualStrings("WithExplicitNumber", explicit.name);
    try std.testing.expectEqual(@as(i64, 3), explicit.number);

    const true_method = skirout_methods.true_method();
    try std.testing.expectEqualStrings("True", true_method.name);
    try std.testing.expectEqual(@as(i64, 78901), true_method.number);
}
