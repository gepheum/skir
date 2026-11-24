const std = @import("std");
const skir_client = @import("skir_client");
const goldens = @import("skirout/external/gepheum/skir_golden_tests/goldens.zig");

fn containsBytes(candidates: []const []const u8, actual: []const u8) bool {
    for (candidates) |candidate| {
        if (std.mem.eql(u8, candidate, actual)) return true;
    }
    return false;
}

fn containsString(candidates: []const []const u8, actual: []const u8) bool {
    for (candidates) |candidate| {
        if (std.mem.eql(u8, candidate, actual)) return true;
    }
    return false;
}

fn evaluateBytes(expr: *const goldens.BytesExpression, allocator: std.mem.Allocator) ![]const u8 {
    return switch (expr.*) {
        .Literal => |bytes| bytes,
        .ToBytes => |tv| {
            const evaluated = try evaluateTypedValue(tv, allocator);
            return typedValueToBytes(&evaluated, allocator);
        },
        .Unknown => error.UnknownBytesExpression,
    };
}

fn evaluateString(expr: *const goldens.StringExpression, allocator: std.mem.Allocator) ![]const u8 {
    return switch (expr.*) {
        .Literal => |s| s,
        .ToDenseJson => |tv| {
            const evaluated = try evaluateTypedValue(tv, allocator);
            return typedValueToDenseJson(&evaluated, allocator);
        },
        .ToReadableJson => |tv| {
            const evaluated = try evaluateTypedValue(tv, allocator);
            return typedValueToReadableJson(&evaluated, allocator);
        },
        .Unknown => error.UnknownStringExpression,
    };
}

fn evaluateTypedValue(tv: *const goldens.TypedValue, allocator: std.mem.Allocator) anyerror!goldens.TypedValue {
    return switch (tv.*) {
        .Bool,
        .Int32,
        .Int64,
        .Hash64,
        .Float32,
        .Float64,
        .Timestamp,
        .String,
        .Bytes,
        .BoolOptional,
        .Ints,
        .Point,
        .Color,
        .MyEnum,
        .EnumA,
        .EnumB,
        .KeyedArrays,
        .RecStruct,
        .RecEnum,
        => tv.*,

        .RoundTripDenseJson => |inner| {
            const evaluated = try evaluateTypedValue(inner, allocator);
            const dense_json = try typedValueToDenseJson(&evaluated, allocator);
            return typedValueFromJson(&evaluated, allocator, dense_json, false);
        },
        .RoundTripReadableJson => |inner| {
            const evaluated = try evaluateTypedValue(inner, allocator);
            const readable_json = try typedValueToReadableJson(&evaluated, allocator);
            return typedValueFromJson(&evaluated, allocator, readable_json, false);
        },
        .RoundTripBytes => |inner| {
            const evaluated = try evaluateTypedValue(inner, allocator);
            const bytes = try typedValueToBytes(&evaluated, allocator);
            return typedValueFromBytes(&evaluated, allocator, bytes, false);
        },

        .PointFromJsonKeepUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = true });
            return .{ .Point = value };
        },
        .PointFromJsonDropUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = false });
            return .{ .Point = value };
        },
        .PointFromBytesKeepUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = true });
            return .{ .Point = value };
        },
        .PointFromBytesDropUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
            return .{ .Point = value };
        },

        .ColorFromJsonKeepUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = true });
            return .{ .Color = value };
        },
        .ColorFromJsonDropUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = false });
            return .{ .Color = value };
        },
        .ColorFromBytesKeepUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = true });
            return .{ .Color = value };
        },
        .ColorFromBytesDropUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
            return .{ .Color = value };
        },

        .MyEnumFromJsonKeepUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = true });
            return .{ .MyEnum = value };
        },
        .MyEnumFromJsonDropUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = false });
            return .{ .MyEnum = value };
        },
        .MyEnumFromBytesKeepUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = true });
            return .{ .MyEnum = value };
        },
        .MyEnumFromBytesDropUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
            return .{ .MyEnum = value };
        },

        .EnumAFromJsonKeepUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = true });
            return .{ .EnumA = value };
        },
        .EnumAFromJsonDropUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = false });
            return .{ .EnumA = value };
        },
        .EnumAFromBytesKeepUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = true });
            return .{ .EnumA = value };
        },
        .EnumAFromBytesDropUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
            return .{ .EnumA = value };
        },

        .EnumBFromJsonKeepUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = true });
            return .{ .EnumB = value };
        },
        .EnumBFromJsonDropUnrecognized => |expr| {
            const json = try evaluateString(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = false });
            return .{ .EnumB = value };
        },
        .EnumBFromBytesKeepUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = true });
            return .{ .EnumB = value };
        },
        .EnumBFromBytesDropUnrecognized => |expr| {
            const bytes = try evaluateBytes(expr, allocator);
            const value = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
            return .{ .EnumB = value };
        },

        .Unknown => error.UnknownTypedValue,
    };
}

fn typedValueToDenseJson(tv: *const goldens.TypedValue, allocator: std.mem.Allocator) ![]const u8 {
    return switch (tv.*) {
        .Bool => |v| try skir_client.boolSerializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Int32 => |v| try skir_client.int32Serializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Int64 => |v| try skir_client.int64Serializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Hash64 => |v| try skir_client.hash64Serializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Float32 => |v| try skir_client.float32Serializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Float64 => |v| try skir_client.float64Serializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Timestamp => |v| try skir_client.timestampSerializer().serialize(allocator, v, .{ .format = .denseJson }),
        .String => |v| try skir_client.stringSerializer().serialize(allocator, v, .{ .format = .denseJson }),
        .Bytes => |v| try skir_client.bytesSerializer().serialize(allocator, v, .{ .format = .denseJson }),
        .BoolOptional => |v| try skir_client.optionalSerializer(skir_client.boolSerializer()).serialize(allocator, v, .{ .format = .denseJson }),
        .Ints => |v| try skir_client.arraySerializer(skir_client.int32Serializer()).serialize(allocator, v, .{ .format = .denseJson }),
        .Point => |v| try goldens.Point.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .Color => |v| try goldens.Color.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .MyEnum => |v| try goldens.MyEnum.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .EnumA => |v| try goldens.EnumA.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .EnumB => |v| try goldens.EnumB.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .KeyedArrays => |v| try goldens.KeyedArrays.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .RecStruct => |v| try goldens.RecStruct.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        .RecEnum => |v| try goldens.RecEnum.serializer().serialize(allocator, v.*, .{ .format = .denseJson }),
        else => error.UnsupportedTypedValueVariant,
    };
}

fn typedValueToReadableJson(tv: *const goldens.TypedValue, allocator: std.mem.Allocator) ![]const u8 {
    return switch (tv.*) {
        .Bool => |v| try skir_client.boolSerializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Int32 => |v| try skir_client.int32Serializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Int64 => |v| try skir_client.int64Serializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Hash64 => |v| try skir_client.hash64Serializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Float32 => |v| try skir_client.float32Serializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Float64 => |v| try skir_client.float64Serializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Timestamp => |v| try skir_client.timestampSerializer().serialize(allocator, v, .{ .format = .readableJson }),
        .String => |v| try skir_client.stringSerializer().serialize(allocator, v, .{ .format = .readableJson }),
        .Bytes => |v| try skir_client.bytesSerializer().serialize(allocator, v, .{ .format = .readableJson }),
        .BoolOptional => |v| try skir_client.optionalSerializer(skir_client.boolSerializer()).serialize(allocator, v, .{ .format = .readableJson }),
        .Ints => |v| try skir_client.arraySerializer(skir_client.int32Serializer()).serialize(allocator, v, .{ .format = .readableJson }),
        .Point => |v| try goldens.Point.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .Color => |v| try goldens.Color.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .MyEnum => |v| try goldens.MyEnum.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .EnumA => |v| try goldens.EnumA.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .EnumB => |v| try goldens.EnumB.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .KeyedArrays => |v| try goldens.KeyedArrays.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .RecStruct => |v| try goldens.RecStruct.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        .RecEnum => |v| try goldens.RecEnum.serializer().serialize(allocator, v.*, .{ .format = .readableJson }),
        else => error.UnsupportedTypedValueVariant,
    };
}

fn typedValueToBytes(tv: *const goldens.TypedValue, allocator: std.mem.Allocator) ![]const u8 {
    return switch (tv.*) {
        .Bool => |v| try skir_client.boolSerializer().serialize(allocator, v, .{ .format = .binary }),
        .Int32 => |v| try skir_client.int32Serializer().serialize(allocator, v, .{ .format = .binary }),
        .Int64 => |v| try skir_client.int64Serializer().serialize(allocator, v, .{ .format = .binary }),
        .Hash64 => |v| try skir_client.hash64Serializer().serialize(allocator, v, .{ .format = .binary }),
        .Float32 => |v| try skir_client.float32Serializer().serialize(allocator, v, .{ .format = .binary }),
        .Float64 => |v| try skir_client.float64Serializer().serialize(allocator, v, .{ .format = .binary }),
        .Timestamp => |v| try skir_client.timestampSerializer().serialize(allocator, v, .{ .format = .binary }),
        .String => |v| try skir_client.stringSerializer().serialize(allocator, v, .{ .format = .binary }),
        .Bytes => |v| try skir_client.bytesSerializer().serialize(allocator, v, .{ .format = .binary }),
        .BoolOptional => |v| try skir_client.optionalSerializer(skir_client.boolSerializer()).serialize(allocator, v, .{ .format = .binary }),
        .Ints => |v| try skir_client.arraySerializer(skir_client.int32Serializer()).serialize(allocator, v, .{ .format = .binary }),
        .Point => |v| try goldens.Point.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .Color => |v| try goldens.Color.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .MyEnum => |v| try goldens.MyEnum.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .EnumA => |v| try goldens.EnumA.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .EnumB => |v| try goldens.EnumB.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .KeyedArrays => |v| try goldens.KeyedArrays.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .RecStruct => |v| try goldens.RecStruct.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        .RecEnum => |v| try goldens.RecEnum.serializer().serialize(allocator, v.*, .{ .format = .binary }),
        else => error.UnsupportedTypedValueVariant,
    };
}

fn typedValueFromJson(
    tv: *const goldens.TypedValue,
    allocator: std.mem.Allocator,
    json: []const u8,
    keep_unrecognized: bool,
) !goldens.TypedValue {
    return switch (tv.*) {
        .Bool => .{ .Bool = try skir_client.boolSerializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Int32 => .{ .Int32 = try skir_client.int32Serializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Int64 => .{ .Int64 = try skir_client.int64Serializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Hash64 => .{ .Hash64 = try skir_client.hash64Serializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Float32 => .{ .Float32 = try skir_client.float32Serializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Float64 => .{ .Float64 = try skir_client.float64Serializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Timestamp => .{ .Timestamp = try skir_client.timestampSerializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .String => .{ .String = try skir_client.stringSerializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Bytes => .{ .Bytes = try skir_client.bytesSerializer().deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .BoolOptional => .{ .BoolOptional = try skir_client.optionalSerializer(skir_client.boolSerializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Ints => .{ .Ints = try skir_client.arraySerializer(skir_client.int32Serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Point => .{ .Point = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Color => .{ .Color = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .MyEnum => .{ .MyEnum = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .EnumA => .{ .EnumA = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .EnumB => .{ .EnumB = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .KeyedArrays => .{ .KeyedArrays = try skir_client.pointerSerializer(goldens.KeyedArrays, goldens.KeyedArrays.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .RecStruct => .{ .RecStruct = try skir_client.pointerSerializer(goldens.RecStruct, goldens.RecStruct.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .RecEnum => .{ .RecEnum = try skir_client.pointerSerializer(goldens.RecEnum, goldens.RecEnum.serializer()).deserialize(allocator, json, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        else => error.UnsupportedTypedValueVariant,
    };
}

fn typedValueFromBytes(
    tv: *const goldens.TypedValue,
    allocator: std.mem.Allocator,
    bytes: []const u8,
    keep_unrecognized: bool,
) !goldens.TypedValue {
    return switch (tv.*) {
        .Bool => .{ .Bool = try skir_client.boolSerializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Int32 => .{ .Int32 = try skir_client.int32Serializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Int64 => .{ .Int64 = try skir_client.int64Serializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Hash64 => .{ .Hash64 = try skir_client.hash64Serializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Float32 => .{ .Float32 = try skir_client.float32Serializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Float64 => .{ .Float64 = try skir_client.float64Serializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Timestamp => .{ .Timestamp = try skir_client.timestampSerializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .String => .{ .String = try skir_client.stringSerializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Bytes => .{ .Bytes = try skir_client.bytesSerializer().deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .BoolOptional => .{ .BoolOptional = try skir_client.optionalSerializer(skir_client.boolSerializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Ints => .{ .Ints = try skir_client.arraySerializer(skir_client.int32Serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Point => .{ .Point = try skir_client.pointerSerializer(goldens.Point, goldens.Point.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .Color => .{ .Color = try skir_client.pointerSerializer(goldens.Color, goldens.Color.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .MyEnum => .{ .MyEnum = try skir_client.pointerSerializer(goldens.MyEnum, goldens.MyEnum.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .EnumA => .{ .EnumA = try skir_client.pointerSerializer(goldens.EnumA, goldens.EnumA.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .EnumB => .{ .EnumB = try skir_client.pointerSerializer(goldens.EnumB, goldens.EnumB.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .KeyedArrays => .{ .KeyedArrays = try skir_client.pointerSerializer(goldens.KeyedArrays, goldens.KeyedArrays.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .RecStruct => .{ .RecStruct = try skir_client.pointerSerializer(goldens.RecStruct, goldens.RecStruct.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        .RecEnum => .{ .RecEnum = try skir_client.pointerSerializer(goldens.RecEnum, goldens.RecEnum.serializer()).deserialize(allocator, bytes, .{ .keepUnrecognizedValues = keep_unrecognized }) },
        else => error.UnsupportedTypedValueVariant,
    };
}

fn verifyBytesEqual(a: *const goldens.Assertion.BytesEqual_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateBytes(&a.actual, allocator);
    const expected = try evaluateBytes(&a.expected, allocator);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn verifyBytesIn(a: *const goldens.Assertion.BytesIn_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateBytes(&a.actual, allocator);
    try std.testing.expect(containsBytes(a.expected, actual));
}

fn verifyStringEqual(a: *const goldens.Assertion.StringEqual_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateString(&a.actual, allocator);
    const expected = try evaluateString(&a.expected, allocator);
    try std.testing.expectEqualStrings(expected, actual);
}

fn verifyStringIn(a: *const goldens.Assertion.StringIn_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateString(&a.actual, allocator);
    try std.testing.expect(containsString(a.expected, actual));
}

fn verifyEnumAFromJsonIsConstant(a: *const goldens.Assertion.EnumAFromJsonIsConstant_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateString(&a.actual, allocator);
    const value = try goldens.EnumA.serializer().deserialize(allocator, actual, .{ .keepUnrecognizedValues = a.keep_unrecognized });
    try std.testing.expect(value == .A);
}

fn verifyEnumAFromBytesIsConstant(a: *const goldens.Assertion.EnumAFromBytesIsConstant_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateBytes(&a.actual, allocator);
    const value = try goldens.EnumA.serializer().deserialize(allocator, actual, .{ .keepUnrecognizedValues = a.keep_unrecognized });
    try std.testing.expect(value == .A);
}

fn verifyEnumBFromJsonIsWrapperB(a: *const goldens.Assertion.EnumBFromJsonIsWrapperB_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateString(&a.actual, allocator);
    const value = try goldens.EnumB.serializer().deserialize(allocator, actual, .{ .keepUnrecognizedValues = a.keep_unrecognized });
    switch (value) {
        .B => |payload| try std.testing.expectEqualStrings(a.expected, payload),
        else => return error.TestUnexpectedResult,
    }
}

fn verifyEnumBFromBytesIsWrapperB(a: *const goldens.Assertion.EnumBFromBytesIsWrapperB_, allocator: std.mem.Allocator) !void {
    const actual = try evaluateBytes(&a.actual, allocator);
    const value = try goldens.EnumB.serializer().deserialize(allocator, actual, .{ .keepUnrecognizedValues = a.keep_unrecognized });
    switch (value) {
        .B => |payload| try std.testing.expectEqualStrings(a.expected, payload),
        else => return error.TestUnexpectedResult,
    }
}

fn verifyReserializeLargeString(input: *const goldens.Assertion.ReserializeLargeString_, allocator: std.mem.Allocator) !void {
    const n: usize = @intCast(input.num_chars);
    const s = try allocator.alloc(u8, n);
    @memset(s, 'a');

    const ser = skir_client.stringSerializer();

    const dense_json = try ser.serialize(allocator, s, .{ .format = .denseJson });
    const dense_round_trip = try ser.deserialize(allocator, dense_json, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqualStrings(s, dense_round_trip);

    const readable_json = try ser.serialize(allocator, s, .{ .format = .readableJson });
    const readable_round_trip = try ser.deserialize(allocator, readable_json, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqualStrings(s, readable_round_trip);

    const bytes = try ser.serialize(allocator, s, .{ .format = .binary });
    try std.testing.expect(std.mem.startsWith(u8, bytes, input.expected_byte_prefix));
    const binary_round_trip = try ser.deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqualStrings(s, binary_round_trip);
}

fn verifyReserializeLargeArray(input: *const goldens.Assertion.ReserializeLargeArray_, allocator: std.mem.Allocator) !void {
    const n: usize = @intCast(input.num_items);
    const values = try allocator.alloc(i32, n);
    for (values) |*v| v.* = 1;

    const ser = skir_client.arraySerializer(skir_client.int32Serializer());

    const dense_json = try ser.serialize(allocator, values, .{ .format = .denseJson });
    const dense_round_trip = try ser.deserialize(allocator, dense_json, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqual(n, dense_round_trip.len);
    for (dense_round_trip) |v| try std.testing.expectEqual(@as(i32, 1), v);

    const readable_json = try ser.serialize(allocator, values, .{ .format = .readableJson });
    const readable_round_trip = try ser.deserialize(allocator, readable_json, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqual(n, readable_round_trip.len);
    for (readable_round_trip) |v| try std.testing.expectEqual(@as(i32, 1), v);

    const bytes = try ser.serialize(allocator, values, .{ .format = .binary });
    try std.testing.expect(std.mem.startsWith(u8, bytes, input.expected_byte_prefix));
    const binary_round_trip = try ser.deserialize(allocator, bytes, .{ .keepUnrecognizedValues = false });
    try std.testing.expectEqual(n, binary_round_trip.len);
    for (binary_round_trip) |v| try std.testing.expectEqual(@as(i32, 1), v);
}

fn verifyReserializeValue(input: *const goldens.Assertion.ReserializeValue_, allocator: std.mem.Allocator) !void {
    const round_trip_dense = goldens.TypedValue{ .RoundTripDenseJson = &input.value };
    const round_trip_readable = goldens.TypedValue{ .RoundTripReadableJson = &input.value };
    const round_trip_bytes = goldens.TypedValue{ .RoundTripBytes = &input.value };
    const all_values = [_]goldens.TypedValue{
        input.value,
        round_trip_dense,
        round_trip_readable,
        round_trip_bytes,
    };

    for (all_values) |tv| {
        const evaluated = try evaluateTypedValue(&tv, allocator);
        const actual_bytes = try typedValueToBytes(&evaluated, allocator);
        try std.testing.expect(containsBytes(input.expected_bytes, actual_bytes));

        const dense_json = try typedValueToDenseJson(&evaluated, allocator);
        try std.testing.expect(containsString(input.expected_dense_json, dense_json));

        const readable_json = try typedValueToReadableJson(&evaluated, allocator);
        try std.testing.expect(containsString(input.expected_readable_json, readable_json));
    }

    for (input.expected_bytes) |expected_bytes| {
        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "skir");
        try buf.append(allocator, 248);
        try buf.appendSlice(allocator, expected_bytes[4..]);
        try buf.append(allocator, 1);

        const point = try goldens.Point.serializer().deserialize(allocator, buf.items, .{ .keepUnrecognizedValues = false });
        try std.testing.expectEqual(@as(i32, 1), point.x);
    }

    const canonical = try evaluateTypedValue(&input.value, allocator);

    for (input.alternative_jsons) |alt_json_expr| {
        const alt_json = try evaluateString(&alt_json_expr, allocator);
        const round_tripped = try typedValueFromJson(&canonical, allocator, alt_json, true);
        const dense_again = try typedValueToDenseJson(&round_tripped, allocator);
        try std.testing.expect(containsString(input.expected_dense_json, dense_again));
    }

    for (input.expected_dense_json) |expected_json| {
        const round_tripped = try typedValueFromJson(&canonical, allocator, expected_json, true);
        const dense_again = try typedValueToDenseJson(&round_tripped, allocator);
        try std.testing.expect(containsString(input.expected_dense_json, dense_again));
    }
    for (input.expected_readable_json) |expected_json| {
        const round_tripped = try typedValueFromJson(&canonical, allocator, expected_json, true);
        const dense_again = try typedValueToDenseJson(&round_tripped, allocator);
        try std.testing.expect(containsString(input.expected_dense_json, dense_again));
    }

    for (input.alternative_bytes) |alt_bytes_expr| {
        const alt_bytes = try evaluateBytes(&alt_bytes_expr, allocator);
        const round_tripped = try typedValueFromBytes(&canonical, allocator, alt_bytes, false);
        const round_trip_bytes_actual = try typedValueToBytes(&round_tripped, allocator);
        try std.testing.expect(containsBytes(input.expected_bytes, round_trip_bytes_actual));
    }

    for (input.expected_bytes) |expected_bytes| {
        const round_tripped = try typedValueFromBytes(&canonical, allocator, expected_bytes, false);
        const round_trip_bytes_actual = try typedValueToBytes(&round_tripped, allocator);
        try std.testing.expect(containsBytes(input.expected_bytes, round_trip_bytes_actual));
    }

    if (input.expected_type_descriptor) |expected_td| {
        _ = try skir_client.typeDescriptorFromJson(allocator, expected_td);
    }
}

fn verifyAssertion(assertion: *const goldens.Assertion, allocator: std.mem.Allocator) !void {
    switch (assertion.*) {
        .BytesEqual => |a| try verifyBytesEqual(a, allocator),
        .BytesIn => |a| try verifyBytesIn(a, allocator),
        .StringEqual => |a| try verifyStringEqual(a, allocator),
        .StringIn => |a| try verifyStringIn(a, allocator),
        .ReserializeValue => |a| try verifyReserializeValue(a, allocator),
        .ReserializeLargeString => |a| try verifyReserializeLargeString(a, allocator),
        .ReserializeLargeArray => |a| try verifyReserializeLargeArray(a, allocator),
        .EnumAFromJsonIsConstant => |a| try verifyEnumAFromJsonIsConstant(a, allocator),
        .EnumAFromBytesIsConstant => |a| try verifyEnumAFromBytesIsConstant(a, allocator),
        .EnumBFromJsonIsWrapperB => |a| try verifyEnumBFromJsonIsWrapperB(a, allocator),
        .EnumBFromBytesIsWrapperB => |a| try verifyEnumBFromBytesIsWrapperB(a, allocator),
        .Unknown => return error.UnknownAssertion,
    }
}

test "golden tests" {
    const allocator = std.heap.page_allocator;
    const tests = goldens.unit_tests_const().*;

    try std.testing.expect(tests.len > 0);

    const first_number = tests[0].test_number;
    for (tests, 0..) |unit_test, i| {
        const expected_number = first_number + @as(i32, @intCast(i));
        try std.testing.expectEqual(expected_number, unit_test.test_number);
    }

    for (tests) |unit_test| {
        try verifyAssertion(&unit_test.assertion, allocator);
    }
}
