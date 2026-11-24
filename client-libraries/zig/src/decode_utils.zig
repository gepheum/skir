const std = @import("std");

pub fn readU8(input: *[]const u8) error{UnexpectedEndOfInput}!u8 {
    if (input.*.len == 0) return error.UnexpectedEndOfInput;
    const b = input.*[0];
    input.* = input.*[1..];
    return b;
}

pub fn readU16Le(input: *[]const u8) error{UnexpectedEndOfInput}!u16 {
    if (input.*.len < 2) return error.UnexpectedEndOfInput;
    const v = std.mem.readInt(u16, input.*[0..2], .little);
    input.* = input.*[2..];
    return v;
}

pub fn readU32Le(input: *[]const u8) error{UnexpectedEndOfInput}!u32 {
    if (input.*.len < 4) return error.UnexpectedEndOfInput;
    const v = std.mem.readInt(u32, input.*[0..4], .little);
    input.* = input.*[4..];
    return v;
}

pub fn readU64Le(input: *[]const u8) error{UnexpectedEndOfInput}!u64 {
    if (input.*.len < 8) return error.UnexpectedEndOfInput;
    const v = std.mem.readInt(u64, input.*[0..8], .little);
    input.* = input.*[8..];
    return v;
}

pub fn decodeNumberBody(wire: u8, input: *[]const u8) error{UnexpectedEndOfInput}!i64 {
    return switch (wire) {
        0...231 => @as(i64, wire),
        232 => @as(i64, try readU16Le(input)),
        233 => @as(i64, try readU32Le(input)),
        234 => @as(i64, @bitCast(try readU64Le(input))),
        235 => @as(i64, try readU8(input)) - 256,
        236 => @as(i64, try readU16Le(input)) - 65536,
        237 => @as(i64, @as(i32, @bitCast(try readU32Le(input)))),
        238, 239 => @as(i64, @bitCast(try readU64Le(input))),
        else => 0,
    };
}

pub fn decodeNumber(input: *[]const u8) error{UnexpectedEndOfInput}!i64 {
    const wire = try readU8(input);
    return decodeNumberBody(wire, input);
}

/// Encodes an `i32` using the skir variable-length wire format.
pub fn encodeI32(v: i32, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
    if (v >= std.math.minInt(i32) and v <= -65537) {
        try out.append(allocator, 237);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, v)));
    } else if (v >= -65536 and v <= -257) {
        try out.append(allocator, 236);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, @intCast(v + 65536))));
    } else if (v >= -256 and v <= -1) {
        try out.append(allocator, 235);
        try out.append(allocator, @as(u8, @intCast(v + 256)));
    } else if (v >= 0 and v <= 231) {
        try out.append(allocator, @intCast(v));
    } else if (v >= 232 and v <= 65535) {
        try out.append(allocator, 232);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, @intCast(v))));
    } else {
        try out.append(allocator, 233);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, @bitCast(v))));
    }
}

/// Encodes a non-negative integer as a variable-length unsigned value used for
/// array lengths and string/bytes sizes.
///
///  0..=231   → single byte equal to the value
///  232..=65535 → wire 232 + u16 LE
///  else      → wire 233 + u32 LE
pub fn encodeUint32(n: u32, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
    if (n <= 231) {
        try out.append(allocator, @intCast(n));
    } else if (n <= 65535) {
        try out.append(allocator, 232);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, @intCast(n))));
    } else {
        try out.append(allocator, 233);
        try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, n)));
    }
}

pub fn skipValue(input: *[]const u8) anyerror!void {
    const wire = try readU8(input);
    switch (wire) {
        0...231 => {},
        235 => {
            if (input.*.len < 1) return error.UnexpectedEndOfInput;
            input.* = input.*[1..];
        },
        232, 236 => {
            if (input.*.len < 2) return error.UnexpectedEndOfInput;
            input.* = input.*[2..];
        },
        233, 237, 240 => {
            if (input.*.len < 4) return error.UnexpectedEndOfInput;
            input.* = input.*[4..];
        },
        234, 238, 239, 241 => {
            if (input.*.len < 8) return error.UnexpectedEndOfInput;
            input.* = input.*[8..];
        },
        242, 244, 246, 255 => {},
        243, 245 => {
            const n: usize = @intCast(try decodeNumber(input));
            if (input.*.len < n) return error.UnexpectedEndOfInput;
            input.* = input.*[n..];
        },
        247...249 => {
            const n = @as(usize, wire) - 246;
            for (0..n) |_| try skipValue(input);
        },
        250 => {
            const n: usize = @intCast(try decodeNumber(input));
            for (0..n) |_| try skipValue(input);
        },
        251...254 => try skipValue(input),
    }
}

pub fn writeJsonEscapedString(input: []const u8, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
    try out.append(allocator, '"');
    for (input) |c| {
        switch (c) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            '\x08' => try out.appendSlice(allocator, "\\b"),
            '\x0C' => try out.appendSlice(allocator, "\\f"),
            0x00...0x07, 0x0B, 0x0E...0x1F, 0x7F => {
                var buf: [6]u8 = undefined;
                const written = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch unreachable;
                try out.appendSlice(allocator, written);
            },
            else => try out.append(allocator, c),
        }
    }
    try out.append(allocator, '"');
}
