// =============================================================================
// UnrecognizedFields
// =============================================================================

const std = @import("std");

/// Holds raw field data encountered during deserialization that does not
/// correspond to any declared field in the struct.
///
/// Every generated struct has a `_unrecognized: ?UnrecognizedFields(@This()) = null`
/// field. Assign it `null` when constructing a struct — the deserializer fills
/// it in automatically when needed. You never need to read or write this field
/// in normal usage.
pub fn UnrecognizedFields(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Owner = T;

        /// Dense-array trailing values rendered as JSON snippets, used to preserve
        /// unknown slot values across `fromJson(..., keep_unrecognized=true)` ->
        /// `toJson` roundtrips.
        dense_tail_json: ?[]const []const u8 = null,

        /// Count of unknown dense slots encountered beyond recognized fields.
        dense_extra_count: usize = 0,

        /// Raw wire bytes for unknown trailing dense slots encountered when
        /// decoding binary input. Each entry is one encoded value blob.
        dense_tail_wire: ?[]const []const u8 = null,

        /// Returns a deep copy whose buffers are owned by `allocator`.
        pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
            var out: Self = .{
                .dense_extra_count = self.dense_extra_count,
            };

            if (self.dense_tail_json) |tail| {
                var cloned_tail = try allocator.alloc([]const u8, tail.len);
                errdefer allocator.free(cloned_tail);
                var initialized: usize = 0;
                errdefer {
                    for (cloned_tail[0..initialized]) |entry| allocator.free(entry);
                }

                for (tail, 0..) |entry, i| {
                    cloned_tail[i] = try allocator.dupe(u8, entry);
                    initialized += 1;
                }
                out.dense_tail_json = cloned_tail;
            }

            if (self.dense_tail_wire) |tail| {
                var cloned_tail = try allocator.alloc([]const u8, tail.len);
                errdefer allocator.free(cloned_tail);
                var initialized: usize = 0;
                errdefer {
                    for (cloned_tail[0..initialized]) |entry| allocator.free(entry);
                }

                for (tail, 0..) |entry, i| {
                    cloned_tail[i] = try allocator.dupe(u8, entry);
                    initialized += 1;
                }
                out.dense_tail_wire = cloned_tail;
            }

            return out;
        }
    };
}

// =============================================================================
// UnrecognizedVariant
// =============================================================================

/// Holds raw enum payload data encountered during deserialization for an
/// unrecognized enum variant.
pub fn UnrecognizedVariant(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Owner = T;

        /// Unknown enum variant number (kind discriminator).
        number: i32 = 0,

        /// True when captured from binary input; false when captured from JSON.
        from_wire: bool = false,

        /// Unknown wrapper payload rendered as dense JSON text.
        payload_json: ?[]const u8 = null,

        /// Unknown wrapper payload captured as raw wire bytes.
        payload_wire: ?[]const u8 = null,

        /// Returns a deep copy whose buffers are owned by `allocator`.
        pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
            return .{
                .number = self.number,
                .from_wire = self.from_wire,
                .payload_json = if (self.payload_json) |json| try allocator.dupe(u8, json) else null,
                .payload_wire = if (self.payload_wire) |wire| try allocator.dupe(u8, wire) else null,
            };
        }
    };
}

test "UnrecognizedFields.clone deep copies all tails" {
    const alloc = std.testing.allocator;
    const Dummy = struct {};

    const json_tail = try alloc.alloc([]const u8, 2);
    json_tail[0] = try alloc.dupe(u8, "123");
    json_tail[1] = try alloc.dupe(u8, "{\"x\":1}");

    const wire_tail = try alloc.alloc([]const u8, 2);
    wire_tail[0] = try alloc.dupe(u8, &[_]u8{ 0xF3, 0x03, 'a', 'b', 'c' });
    wire_tail[1] = try alloc.dupe(u8, &[_]u8{0x01});

    const original: UnrecognizedFields(Dummy) = .{
        .dense_tail_json = json_tail,
        .dense_extra_count = 2,
        .dense_tail_wire = wire_tail,
    };

    const cloned = try original.clone(alloc);

    defer {
        if (cloned.dense_tail_json) |tail| {
            for (tail) |entry| alloc.free(entry);
            alloc.free(tail);
        }
        if (cloned.dense_tail_wire) |tail| {
            for (tail) |entry| alloc.free(entry);
            alloc.free(tail);
        }
    }

    defer {
        for (json_tail) |entry| alloc.free(entry);
        alloc.free(json_tail);
        for (wire_tail) |entry| alloc.free(entry);
        alloc.free(wire_tail);
    }

    try std.testing.expectEqual(@as(usize, 2), cloned.dense_extra_count);
    try std.testing.expect(cloned.dense_tail_json != null);
    try std.testing.expect(cloned.dense_tail_wire != null);

    const cloned_json_tail = cloned.dense_tail_json.?;
    const cloned_wire_tail = cloned.dense_tail_wire.?;

    try std.testing.expect(cloned_json_tail.ptr != json_tail.ptr);
    try std.testing.expect(cloned_wire_tail.ptr != wire_tail.ptr);

    try std.testing.expectEqualStrings(json_tail[0], cloned_json_tail[0]);
    try std.testing.expectEqualStrings(json_tail[1], cloned_json_tail[1]);
    try std.testing.expectEqualSlices(u8, wire_tail[0], cloned_wire_tail[0]);
    try std.testing.expectEqualSlices(u8, wire_tail[1], cloned_wire_tail[1]);

    try std.testing.expect(cloned_json_tail[0].ptr != json_tail[0].ptr);
    try std.testing.expect(cloned_json_tail[1].ptr != json_tail[1].ptr);
    try std.testing.expect(cloned_wire_tail[0].ptr != wire_tail[0].ptr);
    try std.testing.expect(cloned_wire_tail[1].ptr != wire_tail[1].ptr);
}

test "UnrecognizedVariant.clone deep copies payload buffers" {
    const alloc = std.testing.allocator;
    const Dummy = struct {};

    const original: UnrecognizedVariant(Dummy) = .{
        .number = 42,
        .from_wire = true,
        .payload_json = try alloc.dupe(u8, "[1,2,3]"),
        .payload_wire = try alloc.dupe(u8, &[_]u8{ 0xF8, 0x2A, 0x01 }),
    };

    const cloned = try original.clone(alloc);

    defer {
        if (cloned.payload_json) |json| alloc.free(json);
        if (cloned.payload_wire) |wire| alloc.free(wire);
    }
    defer {
        alloc.free(original.payload_json.?);
        alloc.free(original.payload_wire.?);
    }

    try std.testing.expectEqual(@as(i32, 42), cloned.number);
    try std.testing.expectEqual(true, cloned.from_wire);
    try std.testing.expectEqualStrings(original.payload_json.?, cloned.payload_json.?);
    try std.testing.expectEqualSlices(u8, original.payload_wire.?, cloned.payload_wire.?);
    try std.testing.expect(cloned.payload_json.?.ptr != original.payload_json.?.ptr);
    try std.testing.expect(cloned.payload_wire.?.ptr != original.payload_wire.?.ptr);
}
