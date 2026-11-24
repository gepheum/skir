const std = @import("std");
const type_descriptor = @import("type_descriptor.zig");
const method = @import("method.zig");

const TypeDescriptor = type_descriptor.TypeDescriptor;

// =============================================================================
// SerializeFormat
// =============================================================================

/// Output format for `Serializer.serialize`.
pub const SerializeFormat = enum {
    /// Stable machine-oriented JSON format for transport/storage.
    denseJson,
    /// Human-oriented JSON format intended for debugging and logs.
    readableJson,
    /// Compact binary format for bandwidth-sensitive communication.
    binary,
};

/// Internal generic vtable type used by `Serializer(T)`.
pub fn _SerializerVTable(comptime T: type) type {
    return struct {
        isDefaultFn: *const fn (T) bool,
        cloneFn: *const fn (std.mem.Allocator, T) anyerror!T,
        toJsonFn: *const fn (std.mem.Allocator, T, ?[]const u8, *std.ArrayList(u8)) anyerror!void,
        fromJsonFn: *const fn (std.mem.Allocator, std.json.Value, bool) anyerror!T,
        encodeFn: *const fn (std.mem.Allocator, T, *std.ArrayList(u8)) anyerror!void,
        decodeFn: *const fn (std.mem.Allocator, *[]const u8, bool) anyerror!T,
        typeDescriptorFn: *const fn () *const TypeDescriptor,
    };
}

// =============================================================================
// Serializer
// =============================================================================

/// A value that can serialize and deserialize values of type `T`.
pub fn Serializer(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Value = T;

        const VTable = _SerializerVTable(T);

        fn vtableFor(comptime Impl: type) *const VTable {
            return &struct {
                fn doIsDefault(value: T) bool {
                    const impl: Impl = .{};
                    return impl.isDefault(value);
                }

                fn doTypeDescriptor() *const TypeDescriptor {
                    const impl: Impl = .{};
                    return impl.typeDescriptor();
                }

                fn doClone(alloc: std.mem.Allocator, value: T) anyerror!T {
                    const impl: Impl = .{};
                    return impl.clone(alloc, value);
                }

                fn doToJson(alloc: std.mem.Allocator, value: T, eol: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
                    const impl: Impl = .{};
                    return impl.toJson(alloc, value, eol, out);
                }

                fn doFromJson(alloc: std.mem.Allocator, json: std.json.Value, keep: bool) anyerror!T {
                    const impl: Impl = .{};
                    return impl.fromJson(alloc, json, keep);
                }

                fn doEncode(alloc: std.mem.Allocator, value: T, out: *std.ArrayList(u8)) anyerror!void {
                    const impl: Impl = .{};
                    return impl.encode(alloc, value, out);
                }

                fn doDecode(alloc: std.mem.Allocator, input: *[]const u8, keep: bool) anyerror!T {
                    const impl: Impl = .{};
                    return impl.decode(alloc, input, keep);
                }

                const vt: VTable = .{
                    .isDefaultFn = doIsDefault,
                    .cloneFn = doClone,
                    .toJsonFn = doToJson,
                    .fromJsonFn = doFromJson,
                    .encodeFn = doEncode,
                    .decodeFn = doDecode,
                    .typeDescriptorFn = doTypeDescriptor,
                };
            }.vt;
        }

        // Stub implementation for default-initialized Serializers (generated
        // record types fill this in via their own generated adapter).
        const StubImpl = struct {
            pub fn isDefault(_: @This(), _: T) bool {
                return false;
            }
            pub fn clone(_: @This(), _: std.mem.Allocator, _: T) anyerror!T {
                return error.Stub;
            }
            pub fn toJson(_: @This(), _: std.mem.Allocator, _: T, _: ?[]const u8, _: *std.ArrayList(u8)) anyerror!void {}
            pub fn fromJson(_: @This(), _: std.mem.Allocator, _: std.json.Value, _: bool) anyerror!T {
                return error.Stub;
            }
            pub fn encode(_: @This(), _: std.mem.Allocator, _: T, _: *std.ArrayList(u8)) anyerror!void {}
            pub fn decode(_: @This(), _: std.mem.Allocator, _: *[]const u8, _: bool) anyerror!T {
                return error.Stub;
            }
            pub fn typeDescriptor(_: @This()) *const TypeDescriptor {
                const static: TypeDescriptor = .{ .primitive = .Bool };
                return &static;
            }
        };

        _vtable: *const VTable = vtableFor(StubImpl),

        // ── Public API ────────────────────────────────────────────────────────

        /// Serializes `value` to the requested format.
        ///
        /// The caller owns the returned slice and must free it with
        /// `allocator.free(result)`.
        ///
        /// Common mistake: forgetting to free the returned buffer in hot paths.
        pub fn serialize(self: Self, allocator: std.mem.Allocator, value: T, opts: struct {
            format: SerializeFormat = .denseJson,
        }) ![]u8 {
            var buf: std.ArrayList(u8) = .empty;
            errdefer buf.deinit(allocator);
            switch (opts.format) {
                .denseJson => try self._vtable.toJsonFn(allocator, value, null, &buf),
                .readableJson => try self._vtable.toJsonFn(allocator, value, "\n", &buf),
                .binary => {
                    try buf.appendSlice(allocator, "skir");
                    try self._vtable.encodeFn(allocator, value, &buf);
                },
            }
            return buf.toOwnedSlice(allocator);
        }

        /// Deserializes a value from a JSON string or binary byte slice.
        ///
        /// JSON and binary formats are detected automatically.
        ///
        /// `keepUnrecognizedValues` is intended for forward compatibility. Keep
        /// it disabled by default for untrusted inputs.
        pub fn deserialize(self: Self, allocator: std.mem.Allocator, input: []const u8, opts: struct {
            keepUnrecognizedValues: bool = false,
        }) !T {
            if (input.len >= 4 and std.mem.eql(u8, input[0..4], "skir")) {
                var rest: []const u8 = input[4..];
                return self._vtable.decodeFn(allocator, &rest, opts.keepUnrecognizedValues);
            } else {
                const parsed = try std.json.parseFromSlice(std.json.Value, allocator, input, .{});
                defer parsed.deinit();
                return self._vtable.fromJsonFn(allocator, parsed.value, opts.keepUnrecognizedValues);
            }
        }

        /// Clones `value` into memory owned by `allocator`.
        pub fn clone(self: Self, allocator: std.mem.Allocator, value: T) !T {
            return self._vtable.cloneFn(allocator, value);
        }

        /// Returns a runtime `TypeDescriptor` describing the shape of `T`.
        ///
        /// This is useful for schema introspection endpoints and tooling.
        pub fn typeDescriptor(self: Self) TypeDescriptor {
            return self._vtable.typeDescriptorFn().*;
        }
    };
}

/// Internal helper that constructs a `Serializer(T)` backed by `Impl`.
pub fn _serializerFromAdapter(comptime T: type, comptime Impl: type) Serializer(T) {
    return .{ ._vtable = Serializer(T).vtableFor(Impl) };
}

// =============================================================================
// Method
// =============================================================================

pub const Method = method.Method;
