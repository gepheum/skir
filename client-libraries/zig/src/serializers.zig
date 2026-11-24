const std = @import("std");
const base_serializer = @import("serializer.zig");
const type_descriptor = @import("type_descriptor.zig");
const decode_utils = @import("decode_utils.zig");
const Timestamp = @import("timestamp.zig").Timestamp;
const UnrecognizedFields = @import("unrecognized.zig").UnrecognizedFields;
const UnrecognizedVariant = @import("unrecognized.zig").UnrecognizedVariant;

const KeyedArray = @import("keyed_array.zig").KeyedArray;

// =============================================================================
// Shared Core Symbols
// =============================================================================

const SerializeFormat = base_serializer.SerializeFormat;
const Serializer = base_serializer.Serializer;
const _serializerFromAdapter = base_serializer._serializerFromAdapter;
const PrimitiveType = type_descriptor.PrimitiveType;
const ArrayDescriptor = type_descriptor.ArrayDescriptor;
const StructField = type_descriptor.StructField;
const EnumConstantVariant = type_descriptor.EnumConstantVariant;
const EnumWrapperVariant = type_descriptor.EnumWrapperVariant;
const EnumVariant = type_descriptor.EnumVariant;
const StructDescriptor = type_descriptor.StructDescriptor;
const EnumDescriptor = type_descriptor.EnumDescriptor;
const TypeDescriptor = type_descriptor.TypeDescriptor;
const readU8 = decode_utils.readU8;
const readU16Le = decode_utils.readU16Le;
const readU32Le = decode_utils.readU32Le;
const readU64Le = decode_utils.readU64Le;
const decodeNumberBody = decode_utils.decodeNumberBody;
const decodeNumber = decode_utils.decodeNumber;
const encodeUint32 = decode_utils.encodeUint32;
const writeJsonEscapedString = decode_utils.writeJsonEscapedString;

// =============================================================================
// BoolAdapter
// =============================================================================

/// Concrete adapter for `bool` values.
///
/// Dense JSON:    "1" (true) / "0" (false)
/// Readable JSON: "true" / "false"
/// Wire encoding: single byte 0x01 (true) / 0x00 (false)
const BoolAdapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: bool) bool {
        return !input;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: bool) anyerror!bool {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: bool, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        if (eol_indent != null) {
            try out.appendSlice(allocator, if (input) "true" else "false");
        } else {
            try out.append(allocator, if (input) '1' else '0');
        }
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!bool {
        return switch (json) {
            .bool => |b| b,
            .integer => |n| n != 0,
            .float => |f| f != 0.0,
            // Any string other than "0" is truthy; "0" is the only falsy string.
            .string => |s| !std.mem.eql(u8, s, "0"),
            else => false,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: bool, out: *std.ArrayList(u8)) anyerror!void {
        try out.append(allocator, if (input) @as(u8, 1) else @as(u8, 0));
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!bool {
        if (input.len == 0) return error.UnexpectedEndOfInput;
        const b = input.*[0];
        input.* = input.*[1..];
        return b != 0;
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Bool };
        return &static;
    }
};

/// Encodes an `i32` using the skir variable-length wire format.
fn encodeI32(v: i32, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
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

// =============================================================================
// Int32Adapter
// =============================================================================

/// Concrete adapter for `i32` values.
///
/// JSON (both dense and readable): a plain JSON number.
/// Wire encoding: variable-length signed integer.
const Int32Adapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: i32) bool {
        return input == 0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: i32) anyerror!i32 {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: i32, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        var buf: [64]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "{d}", .{input}) catch unreachable;
        try out.appendSlice(allocator, s);
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!i32 {
        return switch (json) {
            .integer => |n| @intCast(n),
            .float => |f| @intFromFloat(f),
            .string => |s| blk: {
                const f = std.fmt.parseFloat(f64, s) catch break :blk 0;
                break :blk @intFromFloat(f);
            },
            else => 0,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: i32, out: *std.ArrayList(u8)) anyerror!void {
        try encodeI32(input, allocator, out);
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!i32 {
        const wire = try readU8(input);
        return switch (wire) {
            240 => @intFromFloat(@round(@as(f32, @bitCast(try readU32Le(input))))),
            241 => @intFromFloat(@round(@as(f64, @bitCast(try readU64Le(input))))),
            else => @truncate(try decodeNumberBody(wire, input)),
        };
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Int32 };
        return &static;
    }
};

// =============================================================================
// Int64Adapter
// =============================================================================

/// Values within `[-MAX_SAFE_INT, MAX_SAFE_INT]` are emitted as JSON numbers;
/// larger values are quoted strings, matching JS `Number.MAX_SAFE_INTEGER`.
const max_safe_int64_json: i64 = 9_007_199_254_740_991;

/// Concrete adapter for `i64` values.
///
/// Dense/readable JSON: number if within JS safe integer range, else quoted string.
/// Wire encoding: variable-length; falls back to i32 encoding if value fits.
const Int64Adapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: i64) bool {
        return input == 0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: i64) anyerror!i64 {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: i64, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        var buf: [64]u8 = undefined;
        if (input >= -max_safe_int64_json and input <= max_safe_int64_json) {
            const s = std.fmt.bufPrint(&buf, "{d}", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        } else {
            const s = std.fmt.bufPrint(&buf, "\"{d}\"", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        }
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!i64 {
        return switch (json) {
            .integer => |n| n,
            .float => |f| @intFromFloat(@round(f)),
            .string => |s| std.fmt.parseInt(i64, s, 10) catch 0,
            else => 0,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: i64, out: *std.ArrayList(u8)) anyerror!void {
        if (input >= std.math.minInt(i32) and input <= std.math.maxInt(i32)) {
            try encodeI32(@intCast(input), allocator, out);
        } else {
            try out.append(allocator, 238);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i64, input)));
        }
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!i64 {
        return decodeNumber(input);
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Int64 };
        return &static;
    }
};

// =============================================================================
// Hash64Adapter
// =============================================================================

const max_safe_hash64_json: u64 = 9_007_199_254_740_991;

/// Concrete adapter for `u64` hash values.
///
/// Dense/readable JSON: number if within JS safe integer range, else quoted string.
/// Wire encoding: variable-length unsigned integer.
const Hash64Adapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: u64) bool {
        return input == 0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: u64) anyerror!u64 {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: u64, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        var buf: [64]u8 = undefined;
        if (input <= max_safe_hash64_json) {
            const s = std.fmt.bufPrint(&buf, "{d}", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        } else {
            const s = std.fmt.bufPrint(&buf, "\"{d}\"", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        }
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!u64 {
        return switch (json) {
            .integer => |n| if (n >= 0) @intCast(n) else 0,
            .float => |f| if (f < 0.0) 0 else @intFromFloat(@round(f)),
            .string => |s| std.fmt.parseInt(u64, s, 10) catch 0,
            else => 0,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: u64, out: *std.ArrayList(u8)) anyerror!void {
        if (input <= 231) {
            try out.append(allocator, @intCast(input));
        } else if (input <= 65535) {
            try out.append(allocator, 232);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u16, @intCast(input))));
        } else if (input <= 4_294_967_295) {
            try out.append(allocator, 233);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, @intCast(input))));
        } else {
            try out.append(allocator, 234);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u64, input)));
        }
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!u64 {
        return @bitCast(try decodeNumber(input));
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Hash64 };
        return &static;
    }
};

// =============================================================================
// TimestampAdapter
// =============================================================================

const min_timestamp_millis: i64 = -8_640_000_000_000_000;
const max_timestamp_millis: i64 = 8_640_000_000_000_000;

/// Converts a unix-millisecond value to an ISO-8601 UTC string with millisecond
/// precision, e.g. `"2009-02-13T23:31:30.000Z"`.
///
/// Uses Howard Hinnant's civil-from-days algorithm.
/// https://howardhinnant.github.io/date_algorithms.html
fn millisToIso8601(ms_raw: i64) [24]u8 {
    const ms = std.math.clamp(ms_raw, min_timestamp_millis, max_timestamp_millis);
    const millis_part: u32 = @intCast(@mod(ms, 1000));
    const secs = @divFloor(ms, 1000);
    const time_of_day: u32 = @intCast(@mod(secs, 86400));
    const h = time_of_day / 3600;
    const mi = (time_of_day % 3600) / 60;
    const s = time_of_day % 60;

    const days = @divFloor(secs, 86400);
    const z = days + 719_468;
    const era = @divFloor(z, 146_097);
    const doe: u32 = @intCast(z - era * 146_097);
    const yoe: u32 = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
    const y_base: i64 = @as(i64, yoe) + era * 400;
    const doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    const mp = (5 * doy + 2) / 153;
    const d = doy - (153 * mp + 2) / 5 + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    const y: i64 = if (m <= 2) y_base + 1 else y_base;

    var buf: [24]u8 = undefined;
    // Year (4 digits, always positive in the supported range)
    const y_u = @as(u32, @intCast(y));
    buf[0] = '0' + @as(u8, @intCast(y_u / 1000));
    buf[1] = '0' + @as(u8, @intCast(y_u / 100 % 10));
    buf[2] = '0' + @as(u8, @intCast(y_u / 10 % 10));
    buf[3] = '0' + @as(u8, @intCast(y_u % 10));
    buf[4] = '-';
    buf[5] = '0' + @as(u8, @intCast(m / 10));
    buf[6] = '0' + @as(u8, @intCast(m % 10));
    buf[7] = '-';
    buf[8] = '0' + @as(u8, @intCast(d / 10));
    buf[9] = '0' + @as(u8, @intCast(d % 10));
    buf[10] = 'T';
    buf[11] = '0' + @as(u8, @intCast(h / 10));
    buf[12] = '0' + @as(u8, @intCast(h % 10));
    buf[13] = ':';
    buf[14] = '0' + @as(u8, @intCast(mi / 10));
    buf[15] = '0' + @as(u8, @intCast(mi % 10));
    buf[16] = ':';
    buf[17] = '0' + @as(u8, @intCast(s / 10));
    buf[18] = '0' + @as(u8, @intCast(s % 10));
    buf[19] = '.';
    buf[20] = '0' + @as(u8, @intCast(millis_part / 100));
    buf[21] = '0' + @as(u8, @intCast(millis_part / 10 % 10));
    buf[22] = '0' + @as(u8, @intCast(millis_part % 10));
    buf[23] = 'Z';
    return buf;
}

/// Concrete adapter for `Timestamp` values (unix milliseconds).
///
/// Dense JSON:    unix millis as a plain JSON number.
/// Readable JSON: `{"unix_millis": N, "formatted": "<ISO-8601>"}`.
/// Wire encoding: millis == 0 → wire 0x00; else wire 0xEF (239) + i64 LE.
const TimestampAdapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: Timestamp) bool {
        return input.unix_millis == 0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: Timestamp) anyerror!Timestamp {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: Timestamp, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        const ms = input.unix_millis;
        if (eol_indent) |eol| {
            // Readable: {"unix_millis": N, "formatted": "ISO8601"}
            var ms_buf: [32]u8 = undefined;
            const ms_str = std.fmt.bufPrint(&ms_buf, "{d}", .{ms}) catch unreachable;
            const iso = millisToIso8601(ms);
            try out.append(allocator, '{');
            try out.appendSlice(allocator, eol);
            try out.appendSlice(allocator, "  ");
            try out.appendSlice(allocator, "\"unix_millis\": ");
            try out.appendSlice(allocator, ms_str);
            try out.append(allocator, ',');
            try out.appendSlice(allocator, eol);
            try out.appendSlice(allocator, "  ");
            try out.appendSlice(allocator, "\"formatted\": \"");
            try out.appendSlice(allocator, &iso);
            try out.append(allocator, '"');
            try out.appendSlice(allocator, eol);
            try out.append(allocator, '}');
        } else {
            var buf: [32]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "{d}", .{ms}) catch unreachable;
            try out.appendSlice(allocator, s);
        }
    }

    pub fn fromJson(self: Self, allocator: std.mem.Allocator, json: std.json.Value, keep_unrecognized: bool) anyerror!Timestamp {
        const ms: i64 = switch (json) {
            .integer => |n| n,
            .float => |f| @intFromFloat(@round(f)),
            .string => |str| blk: {
                const f = std.fmt.parseFloat(f64, str) catch break :blk 0;
                break :blk @intFromFloat(@round(f));
            },
            .object => |obj| blk: {
                if (obj.get("unix_millis")) |field| {
                    const inner = try self.fromJson(allocator, field, keep_unrecognized);
                    return inner;
                }
                break :blk 0;
            },
            else => 0,
        };
        return Timestamp{ .unix_millis = ms };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: Timestamp, out: *std.ArrayList(u8)) anyerror!void {
        const ms = input.unix_millis;
        if (ms == 0) {
            try out.append(allocator, 0);
        } else {
            try out.append(allocator, 239);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i64, ms)));
        }
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!Timestamp {
        const wire = try readU8(input);
        const ms: i64 = switch (wire) {
            240 => @intFromFloat(@round(@as(f32, @bitCast(try readU32Le(input))))),
            241 => @intFromFloat(@round(@as(f64, @bitCast(try readU64Le(input))))),
            else => try decodeNumberBody(wire, input),
        };
        return Timestamp{ .unix_millis = ms };
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Timestamp };
        return &static;
    }
};

// =============================================================================
// Float helpers
// =============================================================================

/// Returns the TypeScript-compatible string for NaN / ±Infinity.
fn floatSpecialString(f: f64) []const u8 {
    if (std.math.isNan(f)) return "NaN";
    if (f > 0) return "Infinity";
    return "-Infinity";
}

// =============================================================================
// Float32Adapter
// =============================================================================

/// Concrete adapter for `f32` values.
///
/// Dense/readable JSON: finite values as shortest round-trip decimal; NaN/±Inf
/// as quoted strings `"NaN"`, `"Infinity"`, `"-Infinity"`.
/// Wire encoding: 0.0 → wire 0; else wire 240 + f32 bits as 4 LE bytes.
const Float32Adapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: f32) bool {
        return input == 0.0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: f32) anyerror!f32 {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: f32, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        if (std.math.isInf(input) or std.math.isNan(input)) {
            try out.append(allocator, '"');
            try out.appendSlice(allocator, floatSpecialString(@floatCast(input)));
            try out.append(allocator, '"');
        } else {
            var buf: [64]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "{}", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        }
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!f32 {
        return switch (json) {
            .float => |f| @floatCast(f),
            .integer => |n| @floatFromInt(n),
            .string => |s| std.fmt.parseFloat(f32, s) catch 0.0,
            else => 0.0,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: f32, out: *std.ArrayList(u8)) anyerror!void {
        if (input == 0.0) {
            try out.append(allocator, 0);
        } else {
            try out.append(allocator, 240);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, @bitCast(input))));
        }
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!f32 {
        const wire = try readU8(input);
        if (wire == 240) {
            return @bitCast(try readU32Le(input));
        } else {
            return @floatFromInt(try decodeNumberBody(wire, input));
        }
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Float32 };
        return &static;
    }
};

// =============================================================================
// Float64Adapter
// =============================================================================

/// Concrete adapter for `f64` values.
///
/// Dense/readable JSON: finite values as shortest round-trip decimal; NaN/±Inf
/// as quoted strings `"NaN"`, `"Infinity"`, `"-Infinity"`.
/// Wire encoding: 0.0 → wire 0; else wire 241 + f64 bits as 8 LE bytes.
const Float64Adapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: f64) bool {
        return input == 0.0;
    }

    pub fn clone(_: Self, _: std.mem.Allocator, input: f64) anyerror!f64 {
        return input;
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: f64, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        if (std.math.isInf(input) or std.math.isNan(input)) {
            try out.append(allocator, '"');
            try out.appendSlice(allocator, floatSpecialString(input));
            try out.append(allocator, '"');
        } else {
            var buf: [64]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "{}", .{input}) catch unreachable;
            try out.appendSlice(allocator, s);
        }
    }

    pub fn fromJson(_: Self, _: std.mem.Allocator, json: std.json.Value, _: bool) anyerror!f64 {
        return switch (json) {
            .float => |f| f,
            .integer => |n| @floatFromInt(n),
            .string => |s| std.fmt.parseFloat(f64, s) catch 0.0,
            else => 0.0,
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: f64, out: *std.ArrayList(u8)) anyerror!void {
        if (input == 0.0) {
            try out.append(allocator, 0);
        } else {
            try out.append(allocator, 241);
            try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u64, @bitCast(input))));
        }
    }

    pub fn decode(_: Self, _: std.mem.Allocator, input: *[]const u8, _: bool) anyerror!f64 {
        const wire = try readU8(input);
        if (wire == 241) {
            return @bitCast(try readU64Le(input));
        } else {
            return @floatFromInt(try decodeNumberBody(wire, input));
        }
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Float64 };
        return &static;
    }
};

// =============================================================================
// StringAdapter
// =============================================================================

/// Concrete adapter for `[]const u8` string values (valid UTF-8).
///
/// Dense/readable JSON: a JSON string literal with escaping (same in both modes).
/// Wire encoding: empty → wire 242; non-empty → wire 243 + encodeUint32(len) + UTF-8 bytes.
const StringAdapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: []const u8) bool {
        return input.len == 0;
    }

    pub fn clone(_: Self, allocator: std.mem.Allocator, input: []const u8) anyerror![]const u8 {
        return allocator.dupe(u8, input);
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: []const u8, _: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        try out.append(allocator, '"');
        var i: usize = 0;
        while (i < input.len) {
            const seq_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                i += 1;
                continue;
            };
            if (i + seq_len > input.len) {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                break;
            }
            _ = std.unicode.utf8Decode(input[i .. i + seq_len]) catch {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                i += 1;
                continue;
            };
            const valid_slice = input[i .. i + seq_len];
            for (valid_slice) |c| {
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
            i += seq_len;
        }
        try out.append(allocator, '"');
    }

    pub fn fromJson(_: Self, allocator: std.mem.Allocator, json: std.json.Value, _: bool) anyerror![]const u8 {
        return switch (json) {
            .string => |s| allocator.dupe(u8, s),
            else => allocator.dupe(u8, &.{}),
        };
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: []const u8, out: *std.ArrayList(u8)) anyerror!void {
        if (input.len == 0) {
            try out.append(allocator, 242);
            return;
        }

        if (std.unicode.utf8ValidateSlice(input)) {
            try out.append(allocator, 243);
            try encodeUint32(@intCast(input.len), allocator, out);
            try out.appendSlice(allocator, input);
            return;
        }

        var i: usize = 0;
        var safe_len: usize = 0;
        while (i < input.len) {
            const seq_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
                safe_len += 3;
                i += 1;
                continue;
            };
            if (i + seq_len > input.len) {
                safe_len += 3;
                break;
            }
            _ = std.unicode.utf8Decode(input[i .. i + seq_len]) catch {
                safe_len += 3;
                i += 1;
                continue;
            };
            safe_len += seq_len;
            i += seq_len;
        }

        try out.append(allocator, 243);
        try encodeUint32(@intCast(safe_len), allocator, out);

        i = 0;
        while (i < input.len) {
            const seq_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                i += 1;
                continue;
            };
            if (i + seq_len > input.len) {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                break;
            }
            _ = std.unicode.utf8Decode(input[i .. i + seq_len]) catch {
                try out.appendSlice(allocator, "\xef\xbf\xbd");
                i += 1;
                continue;
            };
            try out.appendSlice(allocator, input[i .. i + seq_len]);
            i += seq_len;
        }
    }

    pub fn decode(_: Self, allocator: std.mem.Allocator, input: *[]const u8, _: bool) anyerror![]const u8 {
        const wire = try readU8(input);
        if (wire == 0 or wire == 242) {
            return allocator.dupe(u8, &.{});
        }
        const n: usize = @intCast(try decodeNumber(input));
        if (input.len < n) return error.UnexpectedEndOfInput;
        const raw = input.*[0..n];
        input.* = input.*[n..];
        return allocator.dupe(u8, raw);
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .String };
        return &static;
    }
};

// =============================================================================
// Primitive Serializers
// =============================================================================

/// Returns a `Serializer` for `bool` values.
pub fn boolSerializer() Serializer(bool) {
    return _serializerFromAdapter(bool, BoolAdapter);
}

/// Returns a `Serializer` for `i32` values.
pub fn int32Serializer() Serializer(i32) {
    return _serializerFromAdapter(i32, Int32Adapter);
}
/// Returns a `Serializer` for `i64` values.
pub fn int64Serializer() Serializer(i64) {
    return _serializerFromAdapter(i64, Int64Adapter);
}
/// Returns a `Serializer` for `u64` hash values.
pub fn hash64Serializer() Serializer(u64) {
    return _serializerFromAdapter(u64, Hash64Adapter);
}
/// Returns a `Serializer` for `f32` values.
pub fn float32Serializer() Serializer(f32) {
    return _serializerFromAdapter(f32, Float32Adapter);
}
/// Returns a `Serializer` for `f64` values.
pub fn float64Serializer() Serializer(f64) {
    return _serializerFromAdapter(f64, Float64Adapter);
}
/// Returns a `Serializer` for UTF-8 string values (`[]const u8`).
pub fn stringSerializer() Serializer([]const u8) {
    return _serializerFromAdapter([]const u8, StringAdapter);
}
/// Returns a `Serializer` for raw byte blobs (`[]const u8`).
pub fn bytesSerializer() Serializer([]const u8) {
    return _serializerFromAdapter([]const u8, BytesAdapter);
}
/// Returns a `Serializer` for `Timestamp` values.
pub fn timestampSerializer() Serializer(Timestamp) {
    return _serializerFromAdapter(Timestamp, TimestampAdapter);
}

// =============================================================================
// Base64 / hex helpers
// =============================================================================

const base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn encodeBase64(bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const out_len = ((bytes.len + 2) / 3) * 4;
    const out = try allocator.alloc(u8, out_len);
    var i: usize = 0;
    var o: usize = 0;
    while (i < bytes.len) : (i += 3) {
        const b0: u32 = bytes[i];
        const b1: u32 = if (i + 1 < bytes.len) bytes[i + 1] else 0;
        const b2: u32 = if (i + 2 < bytes.len) bytes[i + 2] else 0;
        const triple = (b0 << 16) | (b1 << 8) | b2;
        out[o] = base64_alphabet[(triple >> 18) & 0x3F];
        out[o + 1] = base64_alphabet[(triple >> 12) & 0x3F];
        out[o + 2] = if (i + 1 < bytes.len) base64_alphabet[(triple >> 6) & 0x3F] else '=';
        out[o + 3] = if (i + 2 < bytes.len) base64_alphabet[triple & 0x3F] else '=';
        o += 4;
    }
    return out;
}

fn base64DecodeChar(c: u8) ?u8 {
    return switch (c) {
        'A'...'Z' => c - 'A',
        'a'...'z' => c - 'a' + 26,
        '0'...'9' => c - '0' + 52,
        '+' => 62,
        '/' => 63,
        else => null,
    };
}

fn decodeBase64(s: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Strip trailing '=' padding.
    var end = s.len;
    while (end > 0 and s[end - 1] == '=') end -= 1;
    const trimmed = s[0..end];
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var buf: u32 = 0;
    var bits: u5 = 0;
    for (trimmed) |ch| {
        const v = base64DecodeChar(ch) orelse return error.InvalidBase64;
        buf = (buf << 6) | v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            try out.append(allocator, @intCast((buf >> bits) & 0xFF));
        }
    }
    return out.toOwnedSlice(allocator);
}

fn encodeHex(bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hex_digits = "0123456789abcdef";
    const out = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |b, i| {
        out[i * 2] = hex_digits[b >> 4];
        out[i * 2 + 1] = hex_digits[b & 0xF];
    }
    return out;
}

fn decodeHex(s: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (s.len % 2 != 0) return error.InvalidHex;
    const out = try allocator.alloc(u8, s.len / 2);
    errdefer allocator.free(out);
    for (0..s.len / 2) |i| {
        out[i] = try std.fmt.parseInt(u8, s[i * 2 .. i * 2 + 2], 16);
    }
    return out;
}

// =============================================================================
// BytesAdapter
// =============================================================================

/// Concrete adapter for `[]const u8` byte-array values.
///
/// Dense JSON:    standard base64 with `=` padding.
/// Readable JSON: `"hex:<lowercase-hex>"`.
/// Wire:  empty → 0xF4; non-empty → 0xF5 + encodeUint32(len) + raw bytes.
const BytesAdapter = struct {
    const Self = @This();

    pub fn isDefault(_: Self, input: []const u8) bool {
        return input.len == 0;
    }

    pub fn clone(_: Self, allocator: std.mem.Allocator, input: []const u8) anyerror![]const u8 {
        return allocator.dupe(u8, input);
    }

    pub fn toJson(_: Self, allocator: std.mem.Allocator, input: []const u8, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
        try out.append(allocator, '"');
        if (eol_indent != null) {
            try out.appendSlice(allocator, "hex:");
            const hex = try encodeHex(input, allocator);
            defer allocator.free(hex);
            try out.appendSlice(allocator, hex);
        } else {
            const b64 = try encodeBase64(input, allocator);
            defer allocator.free(b64);
            try out.appendSlice(allocator, b64);
        }
        try out.append(allocator, '"');
    }

    pub fn fromJson(_: Self, allocator: std.mem.Allocator, json: std.json.Value, _: bool) anyerror![]const u8 {
        switch (json) {
            .string => |s| {
                if (std.mem.startsWith(u8, s, "hex:")) {
                    return decodeHex(s[4..], allocator);
                } else {
                    return decodeBase64(s, allocator);
                }
            },
            else => return allocator.dupe(u8, &.{}),
        }
    }

    pub fn encode(_: Self, allocator: std.mem.Allocator, input: []const u8, out: *std.ArrayList(u8)) anyerror!void {
        if (input.len == 0) {
            try out.append(allocator, 244);
        } else {
            try out.append(allocator, 245);
            try encodeUint32(@intCast(input.len), allocator, out);
            try out.appendSlice(allocator, input);
        }
    }

    pub fn decode(_: Self, allocator: std.mem.Allocator, input: *[]const u8, _: bool) anyerror![]const u8 {
        const wire = try readU8(input);
        if (wire == 0 or wire == 244) return allocator.dupe(u8, &.{});
        const n: usize = @intCast(try decodeNumber(input));
        if (input.len < n) return error.UnexpectedEndOfInput;
        const bytes = try allocator.dupe(u8, input.*[0..n]);
        input.* = input.*[n..];
        return bytes;
    }

    pub fn typeDescriptor(_: Self) *const TypeDescriptor {
        const static: TypeDescriptor = .{ .primitive = .Bytes };
        return &static;
    }
};

// =============================================================================
// Composite Serializers
// =============================================================================

/// Returns a serializer for optional values of type `?T`.
///
/// `None` encodes as JSON `null` / wire byte `0xFF`.
/// `Some(v)` delegates to `inner` for both JSON and binary encoding.
pub fn optionalSerializer(comptime inner: anytype) Serializer(?@TypeOf(inner).Value) {
    const T = @TypeOf(inner).Value;
    const ivt = inner._vtable;
    const Adapter = struct {
        pub fn isDefault(_: @This(), value: ?T) bool {
            return value == null;
        }

        pub fn clone(_: @This(), alloc: std.mem.Allocator, value: ?T) anyerror!?T {
            if (value) |v| {
                return try ivt.cloneFn(alloc, v);
            }
            return null;
        }

        pub fn toJson(_: @This(), alloc: std.mem.Allocator, value: ?T, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            if (value) |v| {
                try ivt.toJsonFn(alloc, v, eol, out);
            } else {
                try out.appendSlice(alloc, "null");
            }
        }
        pub fn fromJson(_: @This(), alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror!?T {
            if (json == .null) return null;
            return try ivt.fromJsonFn(alloc, json, keep);
        }
        pub fn encode(_: @This(), alloc: std.mem.Allocator, value: ?T, out: *std.ArrayList(u8)) anyerror!void {
            if (value) |v| {
                try ivt.encodeFn(alloc, v, out);
            } else {
                try out.append(alloc, 255);
            }
        }
        pub fn decode(_: @This(), alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror!?T {
            if (input.*.len > 0 and input.*[0] == 255) {
                input.* = input.*[1..];
                return null;
            }
            return try ivt.decodeFn(alloc, input, keep);
        }
        pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
            const S = struct {
                var desc: TypeDescriptor = undefined;
                fn initOnce() void {
                    desc = .{ .optional = ivt.typeDescriptorFn() };
                }
                var once = std.once(initOnce);
            };
            S.once.call();
            return &S.desc;
        }
    };

    return _serializerFromAdapter(?T, Adapter);
}

/// Returns a serializer for `Recursive(T)` values.
///
/// Use this for self-referential types (e.g. a tree node that contains child
/// nodes of the same type). `Recursive(T)` heap-allocates non-default values
/// to break the layout cycle.
pub fn recursiveSerializer(comptime T: type, comptime inner: Serializer(T)) Serializer(@import("recursive.zig").Recursive(T)) {
    const Recursive = @import("recursive.zig").Recursive(T);
    const ivt = inner._vtable;
    const Adapter = struct {
        pub fn isDefault(_: @This(), value: Recursive) bool {
            return switch (value) {
                .default_value => true,
                .value => |p| ivt.isDefaultFn(p.*),
            };
        }

        pub fn clone(_: @This(), alloc: std.mem.Allocator, value: Recursive) anyerror!Recursive {
            return switch (value) {
                .default_value => .default_value,
                .value => |p| blk: {
                    const v = try ivt.cloneFn(alloc, p.*);
                    const copy = try alloc.create(T);
                    copy.* = v;
                    break :blk .{ .value = copy };
                },
            };
        }

        pub fn toJson(_: @This(), alloc: std.mem.Allocator, value: Recursive, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            switch (value) {
                .default_value => try ivt.toJsonFn(alloc, T.default, eol, out),
                .value => |p| try ivt.toJsonFn(alloc, p.*, eol, out),
            }
        }

        pub fn fromJson(_: @This(), alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror!Recursive {
            const v = try ivt.fromJsonFn(alloc, json, keep);
            if (ivt.isDefaultFn(v)) return .default_value;
            const p = try alloc.create(T);
            p.* = v;
            return .{ .value = p };
        }

        pub fn encode(_: @This(), alloc: std.mem.Allocator, value: Recursive, out: *std.ArrayList(u8)) anyerror!void {
            switch (value) {
                .default_value => try ivt.encodeFn(alloc, T.default, out),
                .value => |p| try ivt.encodeFn(alloc, p.*, out),
            }
        }

        pub fn decode(_: @This(), alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror!Recursive {
            const v = try ivt.decodeFn(alloc, input, keep);
            if (ivt.isDefaultFn(v)) return .default_value;
            const p = try alloc.create(T);
            p.* = v;
            return .{ .value = p };
        }

        pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
            return ivt.typeDescriptorFn();
        }
    };

    return _serializerFromAdapter(Recursive, Adapter);
}

/// Returns a serializer for `*const T` pointer values.
///
/// Serialization delegates entirely to `inner`; the pointer is transparent on
/// the wire. Deserialization allocates a new `T` from the request allocator.
pub fn pointerSerializer(comptime T: type, comptime inner: Serializer(T)) Serializer(*const T) {
    const ivt = inner._vtable;
    const Adapter = struct {
        pub fn isDefault(_: @This(), value: *const T) bool {
            return ivt.isDefaultFn(value.*);
        }

        pub fn clone(_: @This(), alloc: std.mem.Allocator, value: *const T) anyerror!*const T {
            const v = try ivt.cloneFn(alloc, value.*);
            const p = try alloc.create(T);
            p.* = v;
            return p;
        }

        pub fn toJson(_: @This(), alloc: std.mem.Allocator, value: *const T, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            try ivt.toJsonFn(alloc, value.*, eol, out);
        }

        pub fn fromJson(_: @This(), alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror!*const T {
            const v = try ivt.fromJsonFn(alloc, json, keep);
            const p = try alloc.create(T);
            p.* = v;
            return p;
        }

        pub fn encode(_: @This(), alloc: std.mem.Allocator, value: *const T, out: *std.ArrayList(u8)) anyerror!void {
            try ivt.encodeFn(alloc, value.*, out);
        }

        pub fn decode(_: @This(), alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror!*const T {
            const v = try ivt.decodeFn(alloc, input, keep);
            const p = try alloc.create(T);
            p.* = v;
            return p;
        }

        pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
            return ivt.typeDescriptorFn();
        }
    };

    return _serializerFromAdapter(*const T, Adapter);
}

/// Returns a serializer for slice values of type `[]const T`.
///
/// Dense JSON:    `[v1,v2,...]`
/// Readable JSON: `[\n  v1,\n  v2\n]`
/// Wire:  0 items → 0xF6; 1–3 items → 0xF7–0xF9 (no length);
///        4+ items → 0xFA + encodeUint32(count).
pub fn arraySerializer(comptime inner: anytype) Serializer([]const @TypeOf(inner).Value) {
    const T = @TypeOf(inner).Value;
    const ivt = inner._vtable;
    const Adapter = struct {
        pub fn isDefault(_: @This(), value: []const T) bool {
            return value.len == 0;
        }

        pub fn clone(_: @This(), alloc: std.mem.Allocator, value: []const T) anyerror![]const T {
            const items = try alloc.alloc(T, value.len);
            errdefer alloc.free(items);
            for (value, 0..) |item, i| {
                items[i] = try ivt.cloneFn(alloc, item);
            }
            return items;
        }

        pub fn toJson(_: @This(), alloc: std.mem.Allocator, value: []const T, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            try out.append(alloc, '[');
            if (eol) |eol_str| {
                // Readable: each item on its own line, indented 2 more spaces than the parent.
                var child_buf: [256]u8 = undefined;
                const child_len = @min(eol_str.len + 2, child_buf.len);
                @memcpy(child_buf[0..eol_str.len], eol_str);
                child_buf[eol_str.len] = ' ';
                if (eol_str.len + 1 < child_buf.len) child_buf[eol_str.len + 1] = ' ';
                const child_eol: []const u8 = child_buf[0..child_len];
                for (value, 0..) |item, i| {
                    try out.appendSlice(alloc, child_eol);
                    try ivt.toJsonFn(alloc, item, child_eol, out);
                    if (i + 1 < value.len) try out.append(alloc, ',');
                }
                if (value.len > 0) try out.appendSlice(alloc, eol_str);
            } else {
                for (value, 0..) |item, i| {
                    if (i > 0) try out.append(alloc, ',');
                    try ivt.toJsonFn(alloc, item, null, out);
                }
            }
            try out.append(alloc, ']');
        }
        pub fn fromJson(_: @This(), alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror![]const T {
            const arr = switch (json) {
                .array => |a| a.items,
                else => return alloc.dupe(T, &.{}),
            };
            const items = try alloc.alloc(T, arr.len);
            errdefer alloc.free(items);
            for (arr, 0..) |v, i| {
                items[i] = try ivt.fromJsonFn(alloc, v, keep);
            }
            return items;
        }
        pub fn encode(_: @This(), alloc: std.mem.Allocator, value: []const T, out: *std.ArrayList(u8)) anyerror!void {
            const n = value.len;
            if (n <= 3) {
                try out.append(alloc, @intCast(246 + n));
            } else {
                try out.append(alloc, 250);
                try encodeUint32(@intCast(n), alloc, out);
            }
            for (value) |item| try ivt.encodeFn(alloc, item, out);
        }
        pub fn decode(_: @This(), alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror![]const T {
            const wire = try readU8(input);
            if (wire == 0 or wire == 246) return alloc.dupe(T, &.{});
            const n: usize = if (wire == 250)
                @intCast(try decodeNumber(input))
            else
                @intCast(wire - 246);
            const items = try alloc.alloc(T, n);
            errdefer alloc.free(items);
            for (0..n) |i| items[i] = try ivt.decodeFn(alloc, input, keep);
            return items;
        }
        pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
            const S = struct {
                var desc: TypeDescriptor = undefined;
                fn initOnce() void {
                    desc = .{ .array = .{ .item_type = ivt.typeDescriptorFn(), .key_extractor = "" } };
                }
                var once = std.once(initOnce);
            };
            S.once.call();
            return &S.desc;
        }
    };

    return _serializerFromAdapter([]const T, Adapter);
}

/// Returns a serializer for keyed arrays (`KeyedArray(Spec)`).
///
/// Serialization matches `arraySerializer(inner)`, while preserving
/// keyed lookup behavior on the deserialized container.
pub fn keyedArraySerializer(comptime Spec: type, comptime inner: Serializer(Spec.Value)) Serializer(KeyedArray(Spec)) {
    const Value = Spec.Value;
    const KArr = KeyedArray(Spec);
    const ivt = inner._vtable;
    const Adapter = struct {
        pub fn isDefault(_: @This(), value: KArr) bool {
            return value.values.len == 0;
        }

        pub fn clone(_: @This(), alloc: std.mem.Allocator, value: KArr) anyerror!KArr {
            const items = try alloc.alloc(Value, value.values.len);
            errdefer alloc.free(items);
            for (value.values, 0..) |item, i| {
                items[i] = try ivt.cloneFn(alloc, item);
            }
            return KArr.init(alloc, items);
        }

        pub fn toJson(_: @This(), alloc: std.mem.Allocator, value: KArr, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            try out.append(alloc, '[');
            if (eol) |eol_str| {
                // Readable: each item on its own line, indented 2 more spaces than the parent.
                var child_buf: [256]u8 = undefined;
                const child_len = @min(eol_str.len + 2, child_buf.len);
                @memcpy(child_buf[0..eol_str.len], eol_str);
                child_buf[eol_str.len] = ' ';
                if (eol_str.len + 1 < child_buf.len) child_buf[eol_str.len + 1] = ' ';
                const child_eol: []const u8 = child_buf[0..child_len];
                for (value.values, 0..) |item, i| {
                    try out.appendSlice(alloc, child_eol);
                    try ivt.toJsonFn(alloc, item, child_eol, out);
                    if (i + 1 < value.values.len) try out.append(alloc, ',');
                }
                if (value.values.len > 0) try out.appendSlice(alloc, eol_str);
            } else {
                for (value.values, 0..) |item, i| {
                    if (i > 0) try out.append(alloc, ',');
                    try ivt.toJsonFn(alloc, item, null, out);
                }
            }
            try out.append(alloc, ']');
        }

        pub fn fromJson(_: @This(), alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror!KArr {
            const arr = switch (json) {
                .array => |a| a.items,
                else => return KArr.init(alloc, try alloc.dupe(Value, &.{})),
            };
            const items = try alloc.alloc(Value, arr.len);
            errdefer alloc.free(items);
            for (arr, 0..) |v, i| {
                items[i] = try ivt.fromJsonFn(alloc, v, keep);
            }
            return KArr.init(alloc, items);
        }

        pub fn encode(_: @This(), alloc: std.mem.Allocator, value: KArr, out: *std.ArrayList(u8)) anyerror!void {
            const n = value.values.len;
            if (n <= 3) {
                try out.append(alloc, @intCast(246 + n));
            } else {
                try out.append(alloc, 250);
                try encodeUint32(@intCast(n), alloc, out);
            }
            for (value.values) |item| try ivt.encodeFn(alloc, item, out);
        }

        pub fn decode(_: @This(), alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror!KArr {
            const wire = try readU8(input);
            if (wire == 0 or wire == 246) return KArr.init(alloc, try alloc.dupe(Value, &.{}));
            const n: usize = if (wire == 250)
                @intCast(try decodeNumber(input))
            else
                @intCast(wire - 246);
            const items = try alloc.alloc(Value, n);
            errdefer alloc.free(items);
            for (0..n) |i| items[i] = try ivt.decodeFn(alloc, input, keep);
            return KArr.init(alloc, items);
        }

        pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
            const key_extractor_name = Spec.key_extractor;
            const S = struct {
                var desc: TypeDescriptor = undefined;
                fn initOnce() void {
                    desc = .{ .array = .{ .item_type = ivt.typeDescriptorFn(), .key_extractor = key_extractor_name } };
                }
                var once = std.once(initOnce);
            };
            S.once.call();
            return &S.desc;
        }
    };

    return _serializerFromAdapter(KArr, Adapter);
}

// Duplicated Method/TypeDescriptor symbols are intentionally sourced from
// serializer.zig via aliases at the top of this file.

// =============================================================================
// Tests — boolSerializer
// =============================================================================

test "boolSerializer: serialize dense true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const out = try s.serialize(alloc, true, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("1", out);
}

test "boolSerializer: serialize dense false" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const out = try s.serialize(alloc, false, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("0", out);
}

test "boolSerializer: serialize readable true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const out = try s.serialize(alloc, true, .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("true", out);
}

test "boolSerializer: serialize readable false" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const out = try s.serialize(alloc, false, .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("false", out);
}

test "boolSerializer: deserialize bool literal true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(try s.deserialize(alloc, "true", .{}));
    try std.testing.expect(!try s.deserialize(alloc, "false", .{}));
}

test "boolSerializer: deserialize number 1 and 0" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(try s.deserialize(alloc, "1", .{}));
    try std.testing.expect(!try s.deserialize(alloc, "0", .{}));
}

test "encode lossy utf8" {
    const alloc = std.testing.allocator;
    const adapter = StringAdapter{};

    // Encode empty string
    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();

    try adapter.encode(alloc, "", &out);
    try std.testing.expectEqualSlices(u8, &.{242}, out.items);

    // Encode valid UTF-8
    out.clearRetainingCapacity();
    try adapter.encode(alloc, "hello", &out);
    // wire 243, length 5, then 'h', 'e', 'l', 'l', 'o'
    try std.testing.expectEqualSlices(u8, &.{ 243, 5, 'h', 'e', 'l', 'l', 'o' }, out.items);

    // Encode invalid UTF-8
    out.clearRetainingCapacity();
    // \xFF is invalid
    try adapter.encode(alloc, "\xff", &out);
    // \xef\xbf\xbd (3 bytes) length 3
    try std.testing.expectEqualSlices(u8, &.{ 243, 3, 0xef, 0xbf, 0xbd }, out.items);

    // Encode mixed valid and invalid UTF-8
    out.clearRetainingCapacity();
    // "a" + \xFF + "b" -> "a" + \xef\xbf\xbd + "b"
    try adapter.encode(alloc, "a\xffb", &out);
    // The length will be 1 + 3 + 1 = 5
    try std.testing.expectEqualSlices(u8, &.{ 243, 5, 'a', 0xef, 0xbf, 0xbd, 'b' }, out.items);
}

test "toJson lossy utf8" {
    const alloc = std.testing.allocator;
    const adapter = StringAdapter{};

    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();

    // Valid UTF-8 string with escape
    try adapter.toJson(alloc, "hello \"world\"", null, &out);
    try std.testing.expectEqualStrings("\"hello \\\"world\\\"\"", out.items);

    // Invalid UTF-8 string
    out.clearRetainingCapacity();
    try adapter.toJson(alloc, "a\xffb", null, &out);
    try std.testing.expectEqualStrings("\"a\xef\xbf\xbdb\"", out.items);

    // Invalid UTF-8 with chars that need escaping
    out.clearRetainingCapacity();
    try adapter.toJson(alloc, "a\xff\nb", null, &out);
    try std.testing.expectEqualStrings("\"a\xef\xbf\xbd\\nb\"", out.items);
}

test "boolSerializer: deserialize nonzero number is true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(try s.deserialize(alloc, "42", .{}));
}

test "boolSerializer: deserialize float zero is false" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(!try s.deserialize(alloc, "0.0", .{}));
}

test "boolSerializer: deserialize string zero is false" {
    // The string "0" is the only falsy string value.
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(!try s.deserialize(alloc, "\"0\"", .{}));
}

test "boolSerializer: deserialize string nonzero is true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(try s.deserialize(alloc, "\"1\"", .{}));
    try std.testing.expect(try s.deserialize(alloc, "\"true\"", .{}));
}

test "boolSerializer: deserialize null is false" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    try std.testing.expect(!try s.deserialize(alloc, "null", .{}));
}

test "boolSerializer: binary round-trip true" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const bytes = try s.serialize(alloc, true, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expect(try s.deserialize(alloc, bytes, .{}));
}

test "boolSerializer: binary round-trip false" {
    const alloc = std.testing.allocator;
    const s = boolSerializer();
    const bytes = try s.serialize(alloc, false, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expect(!try s.deserialize(alloc, bytes, .{}));
}

test "boolSerializer: binary encoding true is skir then 0x01" {
    const alloc = std.testing.allocator;
    const bytes = try boolSerializer().serialize(alloc, true, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\x01", bytes);
}

test "boolSerializer: binary encoding false is skir then 0x00" {
    const alloc = std.testing.allocator;
    const bytes = try boolSerializer().serialize(alloc, false, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\x00", bytes);
}

test "boolSerializer: typeDescriptor is primitive bool" {
    const td = boolSerializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Bool, td.primitive);
}

// =============================================================================
// Tests — int32Serializer
// =============================================================================

test "int32Serializer: serialize zero" {
    const alloc = std.testing.allocator;
    const out = try int32Serializer().serialize(alloc, 0, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("0", out);
}

test "int32Serializer: serialize positive" {
    const alloc = std.testing.allocator;
    const out = try int32Serializer().serialize(alloc, 42, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("42", out);
}

test "int32Serializer: serialize negative" {
    const alloc = std.testing.allocator;
    const out = try int32Serializer().serialize(alloc, -1, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("-1", out);
}

test "int32Serializer: serialize same in readable mode" {
    const alloc = std.testing.allocator;
    const dense = try int32Serializer().serialize(alloc, 12345, .{});
    defer alloc.free(dense);
    const readable = try int32Serializer().serialize(alloc, 12345, .{ .format = .readableJson });
    defer alloc.free(readable);
    try std.testing.expectEqualStrings(dense, readable);
}

test "int32Serializer: deserialize integer" {
    const alloc = std.testing.allocator;
    const s = int32Serializer();
    try std.testing.expectEqual(@as(i32, 42), try s.deserialize(alloc, "42", .{}));
    try std.testing.expectEqual(@as(i32, -1), try s.deserialize(alloc, "-1", .{}));
    try std.testing.expectEqual(@as(i32, 0), try s.deserialize(alloc, "0", .{}));
}

test "int32Serializer: deserialize float truncates" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(i32, 3), try int32Serializer().deserialize(alloc, "3.9", .{}));
    try std.testing.expectEqual(@as(i32, -1), try int32Serializer().deserialize(alloc, "-1.5", .{}));
}

test "int32Serializer: deserialize string" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(i32, 7), try int32Serializer().deserialize(alloc, "\"7\"", .{}));
}

test "int32Serializer: deserialize unparseable string is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(i32, 0), try int32Serializer().deserialize(alloc, "\"abc\"", .{}));
}

test "int32Serializer: deserialize null is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(i32, 0), try int32Serializer().deserialize(alloc, "null", .{}));
}

test "int32Serializer: binary small positive is single byte" {
    const alloc = std.testing.allocator;
    const s = int32Serializer();
    const b0 = try s.serialize(alloc, 0, .{ .format = .binary });
    defer alloc.free(b0);
    try std.testing.expectEqualSlices(u8, "skir\x00", b0);
    const b1 = try s.serialize(alloc, 1, .{ .format = .binary });
    defer alloc.free(b1);
    try std.testing.expectEqualSlices(u8, "skir\x01", b1);
    const b231 = try s.serialize(alloc, 231, .{ .format = .binary });
    defer alloc.free(b231);
    try std.testing.expectEqualSlices(u8, "skir\xe7", b231);
}

test "int32Serializer: binary u16 range" {
    // 232..=65535 → wire 232 + u16 LE
    const alloc = std.testing.allocator;
    const bytes = try int32Serializer().serialize(alloc, 1000, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 232, 232, 3 }, bytes[4..]); // 1000 = 0x03E8 LE
}

test "int32Serializer: binary u32 range" {
    // >= 65536 → wire 233 + u32 LE
    const alloc = std.testing.allocator;
    const bytes = try int32Serializer().serialize(alloc, 65536, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 233, 0, 0, 1, 0 }, bytes[4..]);
}

test "int32Serializer: binary small negative" {
    // -256..=-1 → wire 235 + u8(v+256)
    const alloc = std.testing.allocator;
    const bytes = try int32Serializer().serialize(alloc, -1, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 235, 255 }, bytes[4..]);
}

test "int32Serializer: binary medium negative" {
    // -65536..=-257 → wire 236 + u16 LE
    const alloc = std.testing.allocator;
    const bytes = try int32Serializer().serialize(alloc, -300, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 236, 212, 254 }, bytes[4..]); // -300+65536=65236=0xFED4 LE
}

test "int32Serializer: binary large negative" {
    // < -65536 → wire 237 + i32 LE
    const alloc = std.testing.allocator;
    const bytes = try int32Serializer().serialize(alloc, -100_000, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 237, 96, 121, 254, 255 }, bytes[4..]);
}

test "int32Serializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = int32Serializer();
    for ([_]i32{ 0, 1, 42, 231, 232, 300, 65535, 65536, std.math.maxInt(i32), -1, -255, -256, -65536, std.math.minInt(i32) }) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const decoded = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, decoded);
    }
}

test "int32Serializer: typeDescriptor is primitive int32" {
    const td = int32Serializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Int32, td.primitive);
}

// =============================================================================
// Tests — int64Serializer
// =============================================================================

test "int64Serializer: serialize safe integer range" {
    const alloc = std.testing.allocator;
    const s = int64Serializer();
    const b0 = try s.serialize(alloc, 0, .{});
    defer alloc.free(b0);
    try std.testing.expectEqualStrings("0", b0);
    const bmax = try s.serialize(alloc, 9_007_199_254_740_991, .{});
    defer alloc.free(bmax);
    try std.testing.expectEqualStrings("9007199254740991", bmax);
    const bmin = try s.serialize(alloc, -9_007_199_254_740_991, .{});
    defer alloc.free(bmin);
    try std.testing.expectEqualStrings("-9007199254740991", bmin);
}

test "int64Serializer: serialize large value is quoted" {
    const alloc = std.testing.allocator;
    const s = int64Serializer();
    const b = try s.serialize(alloc, 9_007_199_254_740_992, .{});
    defer alloc.free(b);
    try std.testing.expectEqualStrings("\"9007199254740992\"", b);
    const bmax = try s.serialize(alloc, std.math.maxInt(i64), .{});
    defer alloc.free(bmax);
    try std.testing.expectEqualStrings("\"9223372036854775807\"", bmax);
}

test "int64Serializer: deserialize integer" {
    const alloc = std.testing.allocator;
    const s = int64Serializer();
    try std.testing.expectEqual(@as(i64, 42), try s.deserialize(alloc, "42", .{}));
    try std.testing.expectEqual(@as(i64, -1), try s.deserialize(alloc, "-1", .{}));
}

test "int64Serializer: deserialize quoted large" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(
        @as(i64, 9_007_199_254_740_992),
        try int64Serializer().deserialize(alloc, "\"9007199254740992\"", .{}),
    );
}

test "int64Serializer: deserialize null is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 0), try int64Serializer().deserialize(alloc, "null", .{}));
}

test "int64Serializer: binary fits i32 reuses i32 encoding" {
    const alloc = std.testing.allocator;
    const b0 = try int64Serializer().serialize(alloc, 0, .{ .format = .binary });
    defer alloc.free(b0);
    try std.testing.expectEqualSlices(u8, "skir\x00", b0);
    const b42 = try int64Serializer().serialize(alloc, 42, .{ .format = .binary });
    defer alloc.free(b42);
    try std.testing.expectEqualSlices(u8, "skir\x2a", b42);
}

test "int64Serializer: binary wire 238 for large values" {
    const alloc = std.testing.allocator;
    const v: i64 = @as(i64, std.math.maxInt(i32)) + 1;
    const bytes = try int64Serializer().serialize(alloc, v, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqual(@as(u8, 238), bytes[4]);
    try std.testing.expectEqualSlices(u8, &std.mem.toBytes(std.mem.nativeToLittle(i64, v)), bytes[5..]);
}

test "int64Serializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = int64Serializer();
    for ([_]i64{ 0, 1, 231, 232, 65536, std.math.maxInt(i32), @as(i64, std.math.maxInt(i32)) + 1, std.math.maxInt(i64), -1, std.math.minInt(i32), std.math.minInt(i64) }) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const decoded = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, decoded);
    }
}

test "int64Serializer: typeDescriptor is primitive int64" {
    const td = int64Serializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Int64, td.primitive);
}

// =============================================================================
// Tests — hash64Serializer
// =============================================================================

test "hash64Serializer: serialize safe integer range" {
    const alloc = std.testing.allocator;
    const s = hash64Serializer();
    const b0 = try s.serialize(alloc, 0, .{});
    defer alloc.free(b0);
    try std.testing.expectEqualStrings("0", b0);
    const bmax = try s.serialize(alloc, 9_007_199_254_740_991, .{});
    defer alloc.free(bmax);
    try std.testing.expectEqualStrings("9007199254740991", bmax);
}

test "hash64Serializer: serialize large value is quoted" {
    const alloc = std.testing.allocator;
    const s = hash64Serializer();
    const b = try s.serialize(alloc, 9_007_199_254_740_992, .{});
    defer alloc.free(b);
    try std.testing.expectEqualStrings("\"9007199254740992\"", b);
    const bmax = try s.serialize(alloc, std.math.maxInt(u64), .{});
    defer alloc.free(bmax);
    try std.testing.expectEqualStrings("\"18446744073709551615\"", bmax);
}

test "hash64Serializer: deserialize integer" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(u64, 42), try hash64Serializer().deserialize(alloc, "42", .{}));
}

test "hash64Serializer: deserialize negative number is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(u64, 0), try hash64Serializer().deserialize(alloc, "-1.0", .{}));
}

test "hash64Serializer: deserialize quoted large" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(
        @as(u64, 9_007_199_254_740_992),
        try hash64Serializer().deserialize(alloc, "\"9007199254740992\"", .{}),
    );
}

test "hash64Serializer: deserialize null is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(u64, 0), try hash64Serializer().deserialize(alloc, "null", .{}));
}

test "hash64Serializer: binary single byte range" {
    const alloc = std.testing.allocator;
    const s = hash64Serializer();
    const b0 = try s.serialize(alloc, 0, .{ .format = .binary });
    defer alloc.free(b0);
    try std.testing.expectEqualSlices(u8, "skir\x00", b0);
    const b231 = try s.serialize(alloc, 231, .{ .format = .binary });
    defer alloc.free(b231);
    try std.testing.expectEqualSlices(u8, "skir\xe7", b231);
}

test "hash64Serializer: binary u16 range" {
    // 232..=65535 → wire 232 + u16 LE
    const alloc = std.testing.allocator;
    const bytes = try hash64Serializer().serialize(alloc, 1000, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 232, 232, 3 }, bytes[4..]);
}

test "hash64Serializer: binary u32 range" {
    // 65536..=4294967295 → wire 233 + u32 LE
    const alloc = std.testing.allocator;
    const bytes = try hash64Serializer().serialize(alloc, 65536, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 233, 0, 0, 1, 0 }, bytes[4..]);
}

test "hash64Serializer: binary u64 range" {
    // >= 2^32 → wire 234 + u64 LE
    const alloc = std.testing.allocator;
    const v: u64 = 4_294_967_296;
    const bytes = try hash64Serializer().serialize(alloc, v, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqual(@as(u8, 234), bytes[4]);
    try std.testing.expectEqualSlices(u8, &std.mem.toBytes(std.mem.nativeToLittle(u64, v)), bytes[5..]);
}

test "hash64Serializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = hash64Serializer();
    for ([_]u64{ 0, 1, 231, 232, 65535, 65536, 4_294_967_295, 4_294_967_296, std.math.maxInt(u64) }) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const decoded = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, decoded);
    }
}

test "hash64Serializer: typeDescriptor is primitive hash64" {
    const td = hash64Serializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Hash64, td.primitive);
}

// =============================================================================
// Tests — millisToIso8601
// =============================================================================

test "millisToIso8601: epoch" {
    try std.testing.expectEqualStrings("1970-01-01T00:00:00.000Z", &millisToIso8601(0));
}

test "millisToIso8601: known date" {
    try std.testing.expectEqualStrings("2009-02-13T23:31:30.000Z", &millisToIso8601(1_234_567_890_000));
}

test "millisToIso8601: milliseconds" {
    try std.testing.expectEqualStrings("2009-02-13T23:31:30.123Z", &millisToIso8601(1_234_567_890_123));
}

test "millisToIso8601: negative millis" {
    try std.testing.expectEqualStrings("1969-12-31T23:59:59.000Z", &millisToIso8601(-1000));
}

// =============================================================================
// Tests — timestampSerializer
// =============================================================================

test "timestampSerializer: serialize dense epoch" {
    const alloc = std.testing.allocator;
    const out = try timestampSerializer().serialize(alloc, Timestamp.epoch, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("0", out);
}

test "timestampSerializer: serialize dense nonzero" {
    const alloc = std.testing.allocator;
    const ts = Timestamp{ .unix_millis = 1_234_567_890_000 };
    const out = try timestampSerializer().serialize(alloc, ts, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("1234567890000", out);
}

test "timestampSerializer: serialize readable" {
    const alloc = std.testing.allocator;
    const ts = Timestamp{ .unix_millis = 1_234_567_890_000 };
    const out = try timestampSerializer().serialize(alloc, ts, .{ .format = .readableJson });
    defer alloc.free(out);
    const expected = "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30.000Z\"\n}";
    try std.testing.expectEqualStrings(expected, out);
}

test "timestampSerializer: deserialize number" {
    const alloc = std.testing.allocator;
    const ts = try timestampSerializer().deserialize(alloc, "1234567890000", .{});
    try std.testing.expectEqual(@as(i64, 1_234_567_890_000), ts.unix_millis);
}

test "timestampSerializer: deserialize string" {
    const alloc = std.testing.allocator;
    const ts = try timestampSerializer().deserialize(alloc, "\"1234567890000\"", .{});
    try std.testing.expectEqual(@as(i64, 1_234_567_890_000), ts.unix_millis);
}

test "timestampSerializer: deserialize readable object" {
    const alloc = std.testing.allocator;
    const json = "{\"unix_millis\": 1234567890000, \"formatted\": \"2009-02-13T23:31:30.000Z\"}";
    const ts = try timestampSerializer().deserialize(alloc, json, .{});
    try std.testing.expectEqual(@as(i64, 1_234_567_890_000), ts.unix_millis);
}

test "timestampSerializer: deserialize null is epoch" {
    const alloc = std.testing.allocator;
    const ts = try timestampSerializer().deserialize(alloc, "null", .{});
    try std.testing.expectEqual(@as(i64, 0), ts.unix_millis);
}

test "timestampSerializer: binary epoch is single byte zero" {
    const alloc = std.testing.allocator;
    const bytes = try timestampSerializer().serialize(alloc, Timestamp.epoch, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\x00", bytes);
}

test "timestampSerializer: binary nonzero is wire 239 + i64 LE" {
    const alloc = std.testing.allocator;
    const ts = Timestamp{ .unix_millis = 1_234_567_890_000 };
    const bytes = try timestampSerializer().serialize(alloc, ts, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqual(@as(u8, 239), bytes[4]);
    try std.testing.expectEqualSlices(u8, &std.mem.toBytes(std.mem.nativeToLittle(i64, 1_234_567_890_000)), bytes[5..]);
}

test "timestampSerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = timestampSerializer();
    for ([_]i64{ 0, 1, 1_234_567_890_000, -1000 }) |ms| {
        const ts = Timestamp{ .unix_millis = ms };
        const bytes = try s.serialize(alloc, ts, .{ .format = .binary });
        defer alloc.free(bytes);
        const decoded = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(ms, decoded.unix_millis);
    }
}

test "timestampSerializer: typeDescriptor is primitive timestamp" {
    const td = timestampSerializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Timestamp, td.primitive);
}

// =============================================================================
// Tests — optionalSerializer
// =============================================================================

test "optionalSerializer: serialize dense none is null" {
    const alloc = std.testing.allocator;
    const out = try optionalSerializer(int32Serializer()).serialize(alloc, null, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("null", out);
}

test "optionalSerializer: serialize dense some delegates" {
    const alloc = std.testing.allocator;
    const out = try optionalSerializer(int32Serializer()).serialize(alloc, @as(?i32, 42), .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("42", out);
}

test "optionalSerializer: serialize readable none is null" {
    const alloc = std.testing.allocator;
    const out = try optionalSerializer(int32Serializer()).serialize(alloc, null, .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("null", out);
}

test "optionalSerializer: serialize readable some delegates" {
    const alloc = std.testing.allocator;
    const out = try optionalSerializer(int32Serializer()).serialize(alloc, @as(?i32, 42), .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("42", out);
}

test "optionalSerializer: deserialize null is none" {
    const alloc = std.testing.allocator;
    const v = try optionalSerializer(int32Serializer()).deserialize(alloc, "null", .{});
    try std.testing.expectEqual(@as(?i32, null), v);
}

test "optionalSerializer: deserialize value is some" {
    const alloc = std.testing.allocator;
    const v = try optionalSerializer(int32Serializer()).deserialize(alloc, "7", .{});
    try std.testing.expectEqual(@as(?i32, 7), v);
}

test "optionalSerializer: binary none is wire 255" {
    const alloc = std.testing.allocator;
    const bytes = try optionalSerializer(int32Serializer()).serialize(alloc, null, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xff", bytes);
}

test "optionalSerializer: binary some delegates" {
    const alloc = std.testing.allocator;
    const bytes = try optionalSerializer(int32Serializer()).serialize(alloc, @as(?i32, 5), .{ .format = .binary });
    defer alloc.free(bytes);
    // Some(5): int32 encodes 5 as a single wire byte 5.
    try std.testing.expectEqualSlices(u8, "skir\x05", bytes);
}

test "optionalSerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = optionalSerializer(int32Serializer());
    for ([_]?i32{ null, 0, 42, -1 }) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, got);
    }
}

test "optionalSerializer: typeDescriptor is optional of int32" {
    const td = optionalSerializer(int32Serializer()).typeDescriptor();
    try std.testing.expect(td == .optional);
    try std.testing.expectEqual(PrimitiveType.Int32, td.optional.primitive);
}

// =============================================================================
// Tests — arraySerializer
// =============================================================================

test "arraySerializer: serialize dense empty" {
    const alloc = std.testing.allocator;
    const out = try arraySerializer(int32Serializer()).serialize(alloc, &.{}, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("[]", out);
}

test "arraySerializer: serialize dense nonempty" {
    const alloc = std.testing.allocator;
    const items = [_]i32{ 1, 2, 3 };
    const out = try arraySerializer(int32Serializer()).serialize(alloc, &items, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("[1,2,3]", out);
}

test "arraySerializer: serialize readable empty" {
    const alloc = std.testing.allocator;
    const out = try arraySerializer(int32Serializer()).serialize(alloc, &.{}, .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("[]", out);
}

test "arraySerializer: serialize readable nonempty" {
    const alloc = std.testing.allocator;
    const items = [_]i32{ 1, 2 };
    const out = try arraySerializer(int32Serializer()).serialize(alloc, &items, .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("[\n  1,\n  2\n]", out);
}

test "arraySerializer: deserialize array" {
    const alloc = std.testing.allocator;
    const result = try arraySerializer(int32Serializer()).deserialize(alloc, "[10,20,30]", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(i32, &.{ 10, 20, 30 }, result);
}

test "arraySerializer: deserialize null is empty" {
    const alloc = std.testing.allocator;
    const result = try arraySerializer(int32Serializer()).deserialize(alloc, "null", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(i32, &.{}, result);
}

test "arraySerializer: binary empty is wire 246" {
    const alloc = std.testing.allocator;
    const bytes = try arraySerializer(int32Serializer()).serialize(alloc, &.{}, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xf6", bytes);
}

test "arraySerializer: binary nonempty wire byte" {
    const alloc = std.testing.allocator;
    const items = [_]i32{ 1, 2, 3 };
    const bytes = try arraySerializer(int32Serializer()).serialize(alloc, &items, .{ .format = .binary });
    defer alloc.free(bytes);
    // 3 items → wire 249 (246 + 3), then each int32 as single byte
    try std.testing.expectEqualSlices(u8, "skir\xf9\x01\x02\x03", bytes);
}

test "arraySerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = arraySerializer(int32Serializer());
    const cases = [_][]const i32{ &.{}, &.{0}, &.{ 1, 2, 3 }, &.{ -1, 0, 1 } };
    for (cases) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        defer alloc.free(got);
        try std.testing.expectEqualSlices(i32, v, got);
    }
}

test "arraySerializer: typeDescriptor is array of int32" {
    const td = arraySerializer(int32Serializer()).typeDescriptor();
    try std.testing.expect(td == .array);
    try std.testing.expectEqual(PrimitiveType.Int32, td.array.item_type.primitive);
}

// =============================================================================
// Tests — keyedArraySerializer
// =============================================================================

const TestIntKeyedSpec = struct {
    pub const Value = i32;
    pub const Key = i32;

    pub fn getGet(v: i32) i32 {
        return v;
    }

    pub const default_value: i32 = -1;

    pub const key_extractor: []const u8 = "self";
};

test "keyedArraySerializer: serialize dense nonempty" {
    const alloc = std.testing.allocator;
    var values = [_]i32{ 1, 2, 3 };
    const keyed = KeyedArray(TestIntKeyedSpec).init(alloc, values[0..]);
    const out = try keyedArraySerializer(TestIntKeyedSpec, int32Serializer()).serialize(alloc, keyed, .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("[1,2,3]", out);
}

test "keyedArraySerializer: deserialize and findByKey" {
    const alloc = std.testing.allocator;
    var keyed = try keyedArraySerializer(TestIntKeyedSpec, int32Serializer()).deserialize(alloc, "[10,20,30]", .{});
    defer keyed.deinit();
    defer alloc.free(keyed.values);

    try std.testing.expectEqualSlices(i32, &.{ 10, 20, 30 }, keyed.values);

    const found = (try keyed.findByKey(20)).?;
    try std.testing.expectEqual(@as(i32, 20), found.*);

    const missing = try keyed.findByKeyOrDefault(999);
    try std.testing.expectEqual(@as(i32, -1), missing.*);
}

test "keyedArraySerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = keyedArraySerializer(TestIntKeyedSpec, int32Serializer());

    var source_items = [_]i32{ -1, 0, 1, 2 };
    const source = KeyedArray(TestIntKeyedSpec).init(alloc, source_items[0..]);

    const bytes = try s.serialize(alloc, source, .{ .format = .binary });
    defer alloc.free(bytes);

    var decoded = try s.deserialize(alloc, bytes, .{});
    defer decoded.deinit();
    defer alloc.free(decoded.values);

    try std.testing.expectEqualSlices(i32, source.values, decoded.values);
}

test "keyedArraySerializer: typeDescriptor includes key extractor" {
    const td = keyedArraySerializer(TestIntKeyedSpec, int32Serializer()).typeDescriptor();
    try std.testing.expect(td == .array);
    try std.testing.expectEqual(PrimitiveType.Int32, td.array.item_type.primitive);
    try std.testing.expectEqualStrings("self", td.array.key_extractor);
}

// =============================================================================
// Tests — bytesSerializer
// =============================================================================

test "bytesSerializer: serialize dense base64" {
    const alloc = std.testing.allocator;
    const out = try bytesSerializer().serialize(alloc, "hello", .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("\"aGVsbG8=\"", out);
}

test "bytesSerializer: serialize readable hex" {
    const alloc = std.testing.allocator;
    const out = try bytesSerializer().serialize(alloc, "hello", .{ .format = .readableJson });
    defer alloc.free(out);
    try std.testing.expectEqualStrings("\"hex:68656c6c6f\"", out);
}

test "bytesSerializer: serialize dense empty" {
    const alloc = std.testing.allocator;
    const out = try bytesSerializer().serialize(alloc, "", .{});
    defer alloc.free(out);
    try std.testing.expectEqualStrings("\"\"", out);
}

test "bytesSerializer: deserialize base64" {
    const alloc = std.testing.allocator;
    const result = try bytesSerializer().deserialize(alloc, "\"aGVsbG8=\"", .{});
    defer alloc.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "bytesSerializer: deserialize hex" {
    const alloc = std.testing.allocator;
    const result = try bytesSerializer().deserialize(alloc, "\"hex:68656c6c6f\"", .{});
    defer alloc.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "bytesSerializer: deserialize number is empty" {
    const alloc = std.testing.allocator;
    const result = try bytesSerializer().deserialize(alloc, "0", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(u8, &.{}, result);
}

test "bytesSerializer: deserialize null is empty" {
    const alloc = std.testing.allocator;
    const result = try bytesSerializer().deserialize(alloc, "null", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(u8, &.{}, result);
}

test "bytesSerializer: binary empty is wire 244" {
    const alloc = std.testing.allocator;
    const bytes = try bytesSerializer().serialize(alloc, "", .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xf4", bytes);
}

test "bytesSerializer: binary nonempty" {
    const alloc = std.testing.allocator;
    const bytes = try bytesSerializer().serialize(alloc, &.{ 1, 2, 3 }, .{ .format = .binary });
    defer alloc.free(bytes);
    // wire 245 + length 3 (single byte) + raw bytes
    try std.testing.expectEqualSlices(u8, "skir\xf5\x03\x01\x02\x03", bytes);
}

test "bytesSerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = bytesSerializer();
    const cases = [_][]const u8{ &.{}, &.{0}, "hello", &([_]u8{0xFF} ** 300) };
    for (cases) |data| {
        const bytes = try s.serialize(alloc, data, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        defer alloc.free(got);
        try std.testing.expectEqualSlices(u8, data, got);
    }
}

test "bytesSerializer: typeDescriptor is primitive bytes" {
    const td = bytesSerializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Bytes, td.primitive);
}

// =============================================================================
// float32Serializer tests
// =============================================================================

test "float32Serializer: serialize zero" {
    const alloc = std.testing.allocator;
    const s = try float32Serializer().serialize(alloc, 0.0, .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("0", s);
}

test "float32Serializer: serialize finite" {
    const alloc = std.testing.allocator;
    const s = try float32Serializer().serialize(alloc, 1.5, .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("1.5", s);
}

test "float32Serializer: serialize NaN" {
    const alloc = std.testing.allocator;
    const s = try float32Serializer().serialize(alloc, std.math.nan(f32), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"NaN\"", s);
}

test "float32Serializer: serialize Infinity" {
    const alloc = std.testing.allocator;
    const s = try float32Serializer().serialize(alloc, std.math.inf(f32), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"Infinity\"", s);
}

test "float32Serializer: serialize -Infinity" {
    const alloc = std.testing.allocator;
    const s = try float32Serializer().serialize(alloc, -std.math.inf(f32), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"-Infinity\"", s);
}

test "float32Serializer: deserialize number" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(f32, 1.5), try float32Serializer().deserialize(alloc, "1.5", .{}));
}

test "float32Serializer: deserialize string NaN" {
    const alloc = std.testing.allocator;
    const v = try float32Serializer().deserialize(alloc, "\"NaN\"", .{});
    try std.testing.expect(std.math.isNan(v));
}

test "float32Serializer: deserialize string Infinity" {
    const alloc = std.testing.allocator;
    const v = try float32Serializer().deserialize(alloc, "\"Infinity\"", .{});
    try std.testing.expectEqual(std.math.inf(f32), v);
}

test "float32Serializer: deserialize null is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(f32, 0.0), try float32Serializer().deserialize(alloc, "null", .{}));
}

test "float32Serializer: binary zero is wire 0" {
    const alloc = std.testing.allocator;
    const bytes = try float32Serializer().serialize(alloc, 0.0, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\x00", bytes);
}

test "float32Serializer: binary nonzero is wire 240 + LE bits" {
    const alloc = std.testing.allocator;
    const bytes = try float32Serializer().serialize(alloc, 1.5, .{ .format = .binary });
    defer alloc.free(bytes);
    // 1.5f32 bits = 0x3FC00000, little-endian = 00 00 c0 3f
    try std.testing.expectEqualSlices(u8, "skir\xf0\x00\x00\xc0\x3f", bytes);
}

test "float32Serializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = float32Serializer();
    const cases = [_]f32{ 0.0, 1.0, -1.0, 1.5, 3.14, std.math.inf(f32), -std.math.inf(f32) };
    for (cases) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, got);
    }
}

test "float32Serializer: typeDescriptor is primitive float32" {
    const td = float32Serializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Float32, td.primitive);
}

// =============================================================================
// float64Serializer tests
// =============================================================================

test "float64Serializer: serialize zero" {
    const alloc = std.testing.allocator;
    const s = try float64Serializer().serialize(alloc, 0.0, .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("0", s);
}

test "float64Serializer: serialize finite" {
    const alloc = std.testing.allocator;
    const s = try float64Serializer().serialize(alloc, 1.5, .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("1.5", s);
}

test "float64Serializer: serialize NaN" {
    const alloc = std.testing.allocator;
    const s = try float64Serializer().serialize(alloc, std.math.nan(f64), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"NaN\"", s);
}

test "float64Serializer: serialize Infinity" {
    const alloc = std.testing.allocator;
    const s = try float64Serializer().serialize(alloc, std.math.inf(f64), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"Infinity\"", s);
}

test "float64Serializer: serialize -Infinity" {
    const alloc = std.testing.allocator;
    const s = try float64Serializer().serialize(alloc, -std.math.inf(f64), .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"-Infinity\"", s);
}

test "float64Serializer: deserialize number" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(f64, 1.5), try float64Serializer().deserialize(alloc, "1.5", .{}));
}

test "float64Serializer: deserialize string NaN" {
    const alloc = std.testing.allocator;
    const v = try float64Serializer().deserialize(alloc, "\"NaN\"", .{});
    try std.testing.expect(std.math.isNan(v));
}

test "float64Serializer: deserialize string Infinity" {
    const alloc = std.testing.allocator;
    const v = try float64Serializer().deserialize(alloc, "\"Infinity\"", .{});
    try std.testing.expectEqual(std.math.inf(f64), v);
}

test "float64Serializer: deserialize null is zero" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(@as(f64, 0.0), try float64Serializer().deserialize(alloc, "null", .{}));
}

test "float64Serializer: binary zero is wire 0" {
    const alloc = std.testing.allocator;
    const bytes = try float64Serializer().serialize(alloc, 0.0, .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\x00", bytes);
}

test "float64Serializer: binary nonzero is wire 241 + LE bits" {
    const alloc = std.testing.allocator;
    const bytes = try float64Serializer().serialize(alloc, 1.5, .{ .format = .binary });
    defer alloc.free(bytes);
    // 1.5f64 bits = 0x3FF8000000000000, little-endian = 00 00 00 00 00 00 f8 3f
    try std.testing.expectEqualSlices(u8, "skir\xf1\x00\x00\x00\x00\x00\x00\xf8\x3f", bytes);
}

test "float64Serializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = float64Serializer();
    const cases = [_]f64{ 0.0, 1.0, -1.0, 1.5, 3.14, std.math.inf(f64), -std.math.inf(f64) };
    for (cases) |v| {
        const bytes = try s.serialize(alloc, v, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        try std.testing.expectEqual(v, got);
    }
}

test "float64Serializer: typeDescriptor is primitive float64" {
    const td = float64Serializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.Float64, td.primitive);
}

// =============================================================================
// stringSerializer tests
// =============================================================================

test "stringSerializer: serialize plain string" {
    const alloc = std.testing.allocator;
    const s = try stringSerializer().serialize(alloc, "hello", .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"hello\"", s);
}

test "stringSerializer: serialize empty" {
    const alloc = std.testing.allocator;
    const s = try stringSerializer().serialize(alloc, "", .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"\"", s);
}

test "stringSerializer: serialize readable is same as dense" {
    const alloc = std.testing.allocator;
    const dense = try stringSerializer().serialize(alloc, "hello", .{ .format = .denseJson });
    defer alloc.free(dense);
    const readable = try stringSerializer().serialize(alloc, "hello", .{ .format = .readableJson });
    defer alloc.free(readable);
    try std.testing.expectEqualStrings(dense, readable);
}

test "stringSerializer: serialize escapes quote and backslash" {
    const alloc = std.testing.allocator;
    const s = try stringSerializer().serialize(alloc, "say \"hi\" \\n", .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"say \\\"hi\\\" \\\\n\"", s);
}

test "stringSerializer: serialize escapes control characters" {
    const alloc = std.testing.allocator;
    const s = try stringSerializer().serialize(alloc, "\x00\n\r\t\x08\x0C\x1B", .{});
    defer alloc.free(s);
    try std.testing.expectEqualStrings("\"\\u0000\\n\\r\\t\\b\\f\\u001b\"", s);
}

test "stringSerializer: deserialize string" {
    const alloc = std.testing.allocator;
    const result = try stringSerializer().deserialize(alloc, "\"hello\"", .{});
    defer alloc.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "stringSerializer: deserialize number is empty" {
    const alloc = std.testing.allocator;
    const result = try stringSerializer().deserialize(alloc, "42", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(u8, &.{}, result);
}

test "stringSerializer: deserialize null is empty" {
    const alloc = std.testing.allocator;
    const result = try stringSerializer().deserialize(alloc, "null", .{});
    defer alloc.free(result);
    try std.testing.expectEqualSlices(u8, &.{}, result);
}

test "stringSerializer: binary empty is wire 242" {
    const alloc = std.testing.allocator;
    const bytes = try stringSerializer().serialize(alloc, "", .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xf2", bytes);
}

test "stringSerializer: binary nonempty is wire 243 + length + utf8" {
    const alloc = std.testing.allocator;
    const bytes = try stringSerializer().serialize(alloc, "hello", .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xf3\x05hello", bytes);
}

test "stringSerializer: binary round-trip" {
    const alloc = std.testing.allocator;
    const s = stringSerializer();
    const cases = [_][]const u8{ "", "hello", "Unicode: \xe2\x9c\x93", "a" ** 300 };
    for (cases) |str| {
        const bytes = try s.serialize(alloc, str, .{ .format = .binary });
        defer alloc.free(bytes);
        const got = try s.deserialize(alloc, bytes, .{});
        defer alloc.free(got);
        try std.testing.expectEqualStrings(str, got);
    }
}

test "stringSerializer: decode invalid utf8 replaced with U+FFFD" {
    const alloc = std.testing.allocator;
    // Manually craft a binary payload with invalid UTF-8 byte 0xFF
    const payload = "skir\xf3\x01\xff";
    const result = try stringSerializer().deserialize(alloc, payload, .{});
    defer alloc.free(result);
    // 0xFF is not valid UTF-8; should be replaced with U+FFFD = EF BF BD
    try std.testing.expectEqualSlices(u8, "\xef\xbf\xbd", result);
}

test "stringSerializer: binary encode invalid utf8 bytes replaced with U+FFFD" {
    const alloc = std.testing.allocator;
    const bytes = try stringSerializer().serialize(alloc, "\xffz", .{ .format = .binary });
    defer alloc.free(bytes);
    try std.testing.expectEqualSlices(u8, "skir\xf3\x04\xef\xbf\xbdz", bytes);
}

test "stringSerializer: json encode invalid utf8 bytes replaced with U+FFFD" {
    const alloc = std.testing.allocator;
    const json = try stringSerializer().serialize(alloc, "\xffz", .{ .format = .denseJson });
    defer alloc.free(json);
    try std.testing.expectEqualSlices(u8, "\"\xef\xbf\xbdz\"", json);
}

test "stringSerializer: typeDescriptor is primitive string" {
    const td = stringSerializer().typeDescriptor();
    try std.testing.expect(td == .primitive);
    try std.testing.expectEqual(PrimitiveType.String, td.primitive);
}
