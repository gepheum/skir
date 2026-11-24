const std = @import("std");
const s = @import("serializer.zig");
const td = @import("type_descriptor.zig");
const decode_utils = @import("decode_utils.zig");
const unrecognized = @import("unrecognized.zig");
const skipValue = decode_utils.skipValue;
const writeJsonEscapedString = decode_utils.writeJsonEscapedString;
const readU8 = decode_utils.readU8;
const readU16Le = decode_utils.readU16Le;
const readU32Le = decode_utils.readU32Le;
const readU64Le = decode_utils.readU64Le;
const decodeNumberBody = decode_utils.decodeNumberBody;
const decodeNumber = decode_utils.decodeNumber;
const encodeUint32 = decode_utils.encodeUint32;

pub fn EnumAdapter(comptime T: type) type {
    return struct {
        const Self = @This();

        const AnyEntry = union(enum) {
            removed,
            constant: usize,
            wrapper: usize,
        };

        const VariantEntry = struct {
            name: []const u8,
            number: i32,
            kind_ordinal: usize,
            doc: []const u8,
            ctx: *anyopaque,
            is_constant_fn: *const fn (*const anyopaque) bool,
            constant_fn: *const fn (*const anyopaque) T,
            clone_fn: *const fn (*const anyopaque, std.mem.Allocator, *const T) anyerror!T,
            to_json_fn: *const fn (*const anyopaque, std.mem.Allocator, *const T, ?[]const u8, *std.ArrayList(u8)) anyerror!void,
            wrap_from_json_fn: *const fn (*const anyopaque, std.mem.Allocator, std.json.Value, bool) anyerror!T,
            encode_value_fn: *const fn (*const anyopaque, std.mem.Allocator, *const T, *std.ArrayList(u8)) anyerror!void,
            wrap_decode_fn: *const fn (*const anyopaque, std.mem.Allocator, *[]const u8, bool) anyerror!T,
            wrap_default_fn: *const fn (*const anyopaque, std.mem.Allocator) ?T,
            variant_type_fn: ?*const fn () *const td.TypeDescriptor,
        };

        allocator: std.mem.Allocator,
        module_path: []const u8,
        qualified_name: []const u8,
        doc: []const u8,

        get_kind_ordinal: *const fn (*const T) usize,
        wrap_unrecognized: *const fn (*const unrecognized.UnrecognizedVariant(T)) T,
        get_unrecognized: *const fn (*const T) ?*const unrecognized.UnrecognizedVariant(T),

        number_to_entry: std.AutoHashMap(i32, AnyEntry),
        removed_numbers: std.ArrayList(i32),
        name_to_kind_ordinal: std.StringHashMap(usize),
        kind_ordinal_to_entry: std.ArrayList(?VariantEntry),
        desc_variants: std.ArrayList(td.EnumVariant),
        descriptor: td.TypeDescriptor,

        pub fn init(
            allocator: std.mem.Allocator,
            module_path: []const u8,
            qualified_name: []const u8,
            doc: []const u8,
            get_kind_ordinal: *const fn (*const T) usize,
            wrap_unrecognized: *const fn (*const unrecognized.UnrecognizedVariant(T)) T,
            get_unrecognized: *const fn (*const T) ?*const unrecognized.UnrecognizedVariant(T),
        ) !Self {
            var kind_entries: std.ArrayList(?VariantEntry) = .empty;
            try kind_entries.append(allocator, null); // kind ordinal 0 = UNKNOWN pseudo-entry

            return .{
                .allocator = allocator,
                .module_path = try allocator.dupe(u8, module_path),
                .qualified_name = try allocator.dupe(u8, qualified_name),
                .doc = try allocator.dupe(u8, doc),
                .get_kind_ordinal = get_kind_ordinal,
                .wrap_unrecognized = wrap_unrecognized,
                .get_unrecognized = get_unrecognized,
                .number_to_entry = std.AutoHashMap(i32, AnyEntry).init(allocator),
                .removed_numbers = .empty,
                .name_to_kind_ordinal = std.StringHashMap(usize).init(allocator),
                .kind_ordinal_to_entry = kind_entries,
                .desc_variants = .empty,
                .descriptor = .{ .enum_record = .{} },
            };
        }

        pub fn addRemovedNumber(self: *Self, number: i32) !void {
            try self.number_to_entry.put(number, .removed);
            try self.removed_numbers.append(self.allocator, number);
        }

        pub fn addConstantVariant(
            self: *Self,
            name: []const u8,
            number: i32,
            kind_ordinal: usize,
            doc: []const u8,
            instance: T,
        ) !void {
            const Ctx = struct {
                instance: T,
                name: []const u8,
                number: i32,
            };
            const Ops = struct {
                fn isConstant(_: *const anyopaque) bool {
                    return true;
                }

                fn constant(ctx_ptr: *const anyopaque) T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.instance;
                }

                fn toJson(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, _: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    if (eol_indent != null) {
                        try writeJsonEscapedString(ctx.name, allocator, out);
                    } else {
                        var buf: [32]u8 = undefined;
                        const n_str = std.fmt.bufPrint(&buf, "{d}", .{ctx.number}) catch unreachable;
                        try out.appendSlice(allocator, n_str);
                    }
                }

                fn clone(ctx_ptr: *const anyopaque, _: std.mem.Allocator, _: *const T) anyerror!T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.instance;
                }

                fn wrapFromJson(_: *const anyopaque, _: std.mem.Allocator, _: std.json.Value, _: bool) anyerror!T {
                    return error.ExpectedConstantVariant;
                }

                fn encodeValue(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, _: *const T, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    try encodeUint32(@intCast(ctx.number), allocator, out);
                }

                fn wrapDecode(_: *const anyopaque, _: std.mem.Allocator, _: *[]const u8, _: bool) anyerror!T {
                    return error.ExpectedConstantVariant;
                }

                fn wrapDefault(ctx_ptr: *const anyopaque, _: std.mem.Allocator) ?T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.instance;
                }
            };

            const ctx = try self.allocator.create(Ctx);
            ctx.* = .{ .instance = instance, .name = name, .number = number };

            const entry = VariantEntry{
                .name = try self.allocator.dupe(u8, name),
                .number = number,
                .kind_ordinal = kind_ordinal,
                .doc = try self.allocator.dupe(u8, doc),
                .ctx = ctx,
                .is_constant_fn = Ops.isConstant,
                .constant_fn = Ops.constant,
                .clone_fn = Ops.clone,
                .to_json_fn = Ops.toJson,
                .wrap_from_json_fn = Ops.wrapFromJson,
                .encode_value_fn = Ops.encodeValue,
                .wrap_decode_fn = Ops.wrapDecode,
                .wrap_default_fn = Ops.wrapDefault,
                .variant_type_fn = null,
            };

            try self.installVariantEntry(entry);
            try self.number_to_entry.put(number, .{ .constant = kind_ordinal });
            try self.insertNameAlias(name, kind_ordinal);

            try self.desc_variants.append(self.allocator, .{ .constant = .{
                .name = try self.allocator.dupe(u8, name),
                .number = number,
                .doc = try self.allocator.dupe(u8, doc),
            } });
        }

        pub fn addWrapperVariant(
            self: *Self,
            comptime V: type,
            name: []const u8,
            number: i32,
            kind_ordinal: usize,
            ser: s.Serializer(V),
            doc: []const u8,
            wrap: *const fn (V) T,
            get_value: *const fn (*const T) V,
        ) !void {
            const Ctx = struct {
                ser: s.Serializer(V),
                wrap: *const fn (V) T,
                get_value: *const fn (*const T) V,
                name: []const u8,
                number: i32,
            };
            const Ops = struct {
                fn isConstant(_: *const anyopaque) bool {
                    return false;
                }

                fn constant(_: *const anyopaque) T {
                    return T.unknown;
                }

                fn toJson(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, input: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const v = ctx.get_value(input);

                    if (eol_indent) |indent| {
                        var child_buf: [256]u8 = undefined;
                        const child_len = @min(indent.len + 2, child_buf.len);
                        @memcpy(child_buf[0..indent.len], indent);
                        child_buf[indent.len] = ' ';
                        if (indent.len + 1 < child_buf.len) child_buf[indent.len + 1] = ' ';
                        const child = child_buf[0..child_len];

                        try out.append(allocator, '{');
                        try out.appendSlice(allocator, child);
                        try out.appendSlice(allocator, "\"kind\": ");
                        try writeJsonEscapedString(ctx.name, allocator, out);
                        try out.append(allocator, ',');
                        try out.appendSlice(allocator, child);
                        try out.appendSlice(allocator, "\"value\": ");
                        try ctx.ser._vtable.toJsonFn(allocator, v, child, out);
                        try out.appendSlice(allocator, indent);
                        try out.append(allocator, '}');
                    } else {
                        try out.append(allocator, '[');
                        var num_buf: [32]u8 = undefined;
                        const n_str = std.fmt.bufPrint(&num_buf, "{d}", .{ctx.number}) catch unreachable;
                        try out.appendSlice(allocator, n_str);
                        try out.append(allocator, ',');
                        try ctx.ser._vtable.toJsonFn(allocator, v, null, out);
                        try out.append(allocator, ']');
                    }
                }

                fn clone(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, input: *const T) anyerror!T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const inner = try ctx.ser._vtable.cloneFn(allocator, ctx.get_value(input));
                    return ctx.wrap(inner);
                }

                fn wrapFromJson(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, json: std.json.Value, keep_unrecognized: bool) anyerror!T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const inner = try ctx.ser._vtable.fromJsonFn(allocator, json, keep_unrecognized);
                    return ctx.wrap(inner);
                }

                fn encodeValue(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, input: *const T, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.ser._vtable.encodeFn(allocator, ctx.get_value(input), out);
                }

                fn wrapDecode(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator, input: *[]const u8, keep_unrecognized: bool) anyerror!T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const inner = try ctx.ser._vtable.decodeFn(allocator, input, keep_unrecognized);
                    return ctx.wrap(inner);
                }

                fn wrapDefault(ctx_ptr: *const anyopaque, allocator: std.mem.Allocator) ?T {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const inner = ctx.ser._vtable.fromJsonFn(allocator, .{ .integer = 0 }, false) catch return null;
                    return ctx.wrap(inner);
                }
            };

            const ctx = try self.allocator.create(Ctx);
            ctx.* = .{
                .ser = ser,
                .wrap = wrap,
                .get_value = get_value,
                .name = name,
                .number = number,
            };

            const entry = VariantEntry{
                .name = try self.allocator.dupe(u8, name),
                .number = number,
                .kind_ordinal = kind_ordinal,
                .doc = try self.allocator.dupe(u8, doc),
                .ctx = ctx,
                .is_constant_fn = Ops.isConstant,
                .constant_fn = Ops.constant,
                .clone_fn = Ops.clone,
                .to_json_fn = Ops.toJson,
                .wrap_from_json_fn = Ops.wrapFromJson,
                .encode_value_fn = Ops.encodeValue,
                .wrap_decode_fn = Ops.wrapDecode,
                .wrap_default_fn = Ops.wrapDefault,
                .variant_type_fn = ser._vtable.typeDescriptorFn,
            };

            try self.installVariantEntry(entry);
            try self.number_to_entry.put(number, .{ .wrapper = kind_ordinal });
            try self.insertNameAlias(name, kind_ordinal);

            try self.desc_variants.append(self.allocator, .{ .wrapper = .{
                .name = try self.allocator.dupe(u8, name),
                .number = number,
                .variant_type = null,
                .doc = try self.allocator.dupe(u8, doc),
            } });
        }

        fn installVariantEntry(self: *Self, entry: VariantEntry) !void {
            if (entry.kind_ordinal >= self.kind_ordinal_to_entry.items.len) {
                const new_len = entry.kind_ordinal + 1;
                const old_len = self.kind_ordinal_to_entry.items.len;
                try self.kind_ordinal_to_entry.resize(self.allocator, new_len);
                for (old_len..new_len) |idx| self.kind_ordinal_to_entry.items[idx] = null;
            }
            self.kind_ordinal_to_entry.items[entry.kind_ordinal] = entry;
        }

        fn insertNameAlias(self: *Self, name: []const u8, kind_ordinal: usize) !void {
            const key = try self.allocator.dupe(u8, name);
            try self.name_to_kind_ordinal.put(key, kind_ordinal);

            const upper = try std.ascii.allocUpperString(self.allocator, name);
            if (!std.mem.eql(u8, upper, name)) {
                try self.name_to_kind_ordinal.put(upper, kind_ordinal);
            } else {
                self.allocator.free(upper);
            }

            const lower = try std.ascii.allocLowerString(self.allocator, name);
            if (!std.mem.eql(u8, lower, name)) {
                try self.name_to_kind_ordinal.put(lower, kind_ordinal);
            } else {
                self.allocator.free(lower);
            }
        }

        pub fn finalize(self: *Self) !void {
            std.sort.pdq(td.EnumVariant, self.desc_variants.items, {}, struct {
                fn lessThan(_: void, a: td.EnumVariant, b: td.EnumVariant) bool {
                    return a.number() < b.number();
                }
            }.lessThan);

            const variants = try self.allocator.alloc(td.EnumVariant, self.desc_variants.items.len);
            for (self.desc_variants.items, 0..) |v, idx| {
                switch (v) {
                    .constant => |c| {
                        variants[idx] = .{ .constant = .{
                            .name = c.name,
                            .number = c.number,
                            .doc = c.doc,
                        } };
                    },
                    .wrapper => |w| {
                        var vt_ptr: ?*const td.TypeDescriptor = null;
                        if (self.number_to_entry.get(w.number)) |nk| {
                            switch (nk) {
                                .wrapper => |kind_ordinal| {
                                    if (kind_ordinal < self.kind_ordinal_to_entry.items.len) {
                                        if (self.kind_ordinal_to_entry.items[kind_ordinal]) |entry| {
                                            vt_ptr = if (entry.variant_type_fn) |f| f() else null;
                                        }
                                    }
                                },
                                .constant => {},
                                .removed => {},
                            }
                        }
                        variants[idx] = .{ .wrapper = .{
                            .name = w.name,
                            .number = w.number,
                            .variant_type = vt_ptr,
                            .doc = w.doc,
                        } };
                    },
                }
            }
            const removed = try self.allocator.dupe(i32, self.removed_numbers.items);
            self.descriptor = .{ .enum_record = .{
                .name = shortName(self.qualified_name),
                .qualified_name = self.qualified_name,
                .module_path = self.module_path,
                .doc = self.doc,
                .variants = variants,
                .removed_numbers = removed,
            } };
        }

        pub fn isDefault(self: *const Self, input: *const T) bool {
            return self.get_kind_ordinal(input) == 0;
        }

        pub fn toJson(self: *const Self, allocator: std.mem.Allocator, input: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            const ko = self.get_kind_ordinal(input);
            if (ko == 0) {
                return self.unknownToJson(allocator, input, eol_indent, out);
            }

            if (ko < self.kind_ordinal_to_entry.items.len) {
                if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                    return entry.to_json_fn(entry.ctx, allocator, input, eol_indent, out);
                }
            }

            if (eol_indent != null) {
                try out.appendSlice(allocator, "\"unknown\"");
            } else {
                try out.append(allocator, '0');
            }
        }

        fn unknownToJson(self: *const Self, allocator: std.mem.Allocator, input: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            const u = self.get_unrecognized(input) orelse {
                if (eol_indent != null) {
                    try out.appendSlice(allocator, "\"unknown\"");
                } else {
                    try out.append(allocator, '0');
                }
                return;
            };
            if (eol_indent != null) {
                try out.appendSlice(allocator, "\"unknown\"");
            } else {
                if (u.from_wire) {
                    try out.append(allocator, '0');
                    return;
                }

                if (u.payload_json) |payload_json| {
                    var buf: [64]u8 = undefined;
                    const n_text = std.fmt.bufPrint(&buf, "{d}", .{u.number}) catch unreachable;
                    try out.append(allocator, '[');
                    try out.appendSlice(allocator, n_text);
                    try out.append(allocator, ',');
                    try out.appendSlice(allocator, payload_json);
                    try out.append(allocator, ']');
                    return;
                }

                if (u.payload_wire) |payload_wire| {
                    var buf: [64]u8 = undefined;
                    const n_text = std.fmt.bufPrint(&buf, "{d}", .{u.number}) catch unreachable;
                    try out.append(allocator, '[');
                    try out.appendSlice(allocator, n_text);
                    try out.append(allocator, ',');
                    try appendUnknownPayloadWireAsDenseJson(allocator, payload_wire, out);
                    try out.append(allocator, ']');
                    return;
                }

                var buf: [64]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "{d}", .{u.number}) catch unreachable;
                try out.appendSlice(allocator, text);
            }
        }

        pub fn fromJson(self: *const Self, allocator: std.mem.Allocator, json: std.json.Value, keep_unrecognized: bool) anyerror!T {
            return switch (json) {
                .integer => |n| try self.resolveConstantLookup(allocator, @intCast(n), keep_unrecognized, false),
                .float => |f| try self.resolveConstantLookup(allocator, @intFromFloat(@round(f)), keep_unrecognized, false),
                .bool => |b| try self.resolveConstantLookup(allocator, if (b) 1 else 0, keep_unrecognized, false),
                .string => |str| blk: {
                    if (self.name_to_kind_ordinal.get(str)) |ko| {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                if (entry.is_constant_fn(entry.ctx)) {
                                    break :blk entry.constant_fn(entry.ctx);
                                }
                                if (entry.wrap_default_fn(entry.ctx, allocator)) |v| break :blk v;
                            }
                        }
                    }
                    break :blk T.unknown;
                },
                .array => |arr| blk: {
                    if (arr.items.len != 2) break :blk T.unknown;
                    const number: i32 = switch (arr.items[0]) {
                        .integer => |n| @intCast(n),
                        .float => |f| @intFromFloat(@round(f)),
                        else => 0,
                    };
                    break :blk try self.fromNumberAndPayload(allocator, number, arr.items[1], keep_unrecognized);
                },
                .object => |obj| blk: {
                    const kind_val = obj.get("kind") orelse break :blk T.unknown;
                    const payload = obj.get("value") orelse std.json.Value{ .null = {} };
                    const kind_name = switch (kind_val) {
                        .string => |s_name| s_name,
                        else => break :blk T.unknown,
                    };
                    if (self.name_to_kind_ordinal.get(kind_name)) |ko| {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                if (entry.is_constant_fn(entry.ctx)) {
                                    break :blk entry.constant_fn(entry.ctx);
                                }
                                break :blk try entry.wrap_from_json_fn(entry.ctx, allocator, payload, keep_unrecognized);
                            }
                        }
                    }
                    break :blk T.unknown;
                },
                else => T.unknown,
            };
        }

        fn fromNumberAndPayload(self: *const Self, allocator: std.mem.Allocator, number: i32, payload: std.json.Value, keep_unrecognized: bool) anyerror!T {
            if (self.number_to_entry.get(number)) |any| {
                return switch (any) {
                    .removed => if (keep_unrecognized) blk: {
                        const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                        uv.* = .{ .number = number, .from_wire = false };
                        break :blk self.wrap_unrecognized(uv);
                    } else T.unknown,
                    .constant => |ko| blk: {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                break :blk entry.constant_fn(entry.ctx);
                            }
                        }
                        break :blk T.unknown;
                    },
                    .wrapper => |ko| blk: {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                break :blk try entry.wrap_from_json_fn(entry.ctx, allocator, payload, keep_unrecognized);
                            }
                        }
                        break :blk T.unknown;
                    },
                };
            }

            if (keep_unrecognized) {
                const payload_json = try std.json.Stringify.valueAlloc(allocator, payload, .{});
                const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                uv.* = .{ .number = number, .from_wire = false, .payload_json = payload_json, .payload_wire = null };
                return self.wrap_unrecognized(uv);
            }
            return T.unknown;
        }

        fn resolveConstantLookup(self: *const Self, allocator: std.mem.Allocator, number: i32, keep_unrecognized: bool, from_wire: bool) anyerror!T {
            if (self.number_to_entry.get(number)) |any| {
                return switch (any) {
                    .removed => if (keep_unrecognized) blk: {
                        const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                        uv.* = .{ .number = number, .from_wire = from_wire };
                        break :blk self.wrap_unrecognized(uv);
                    } else T.unknown,
                    .constant => |ko| blk: {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                break :blk entry.constant_fn(entry.ctx);
                            }
                        }
                        break :blk T.unknown;
                    },
                    .wrapper => |ko| blk: {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                if (entry.wrap_default_fn(entry.ctx, allocator)) |v| break :blk v;
                                if (keep_unrecognized) {
                                    const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                                    uv.* = .{ .number = number, .from_wire = from_wire };
                                    break :blk self.wrap_unrecognized(uv);
                                }
                            }
                        }
                        break :blk T.unknown;
                    },
                };
            }

            if (keep_unrecognized) {
                const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                uv.* = .{ .number = number, .from_wire = from_wire };
                return self.wrap_unrecognized(uv);
            }
            return T.unknown;
        }

        fn encodeI64Compat(v: i64, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
            if (v >= std.math.minInt(i32) and v <= -65537) {
                try out.append(allocator, 237);
                try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i32, @intCast(v))));
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
            } else if (v <= std.math.maxInt(i32)) {
                try out.append(allocator, 233);
                try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(u32, @bitCast(@as(i32, @intCast(v))))));
            } else {
                try out.append(allocator, 238);
                try out.appendSlice(allocator, &std.mem.toBytes(std.mem.nativeToLittle(i64, v)));
            }
        }

        fn emitWrapperHeader(number: i32, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) anyerror!void {
            if (number >= 1 and number <= 4) {
                try out.append(allocator, @intCast(250 + number));
            } else {
                try out.append(allocator, 248);
                try encodeUint32(@intCast(number), allocator, out);
            }
        }

        fn encodeUnknownJsonPayloadValue(allocator: std.mem.Allocator, value: std.json.Value, out: *std.ArrayList(u8)) anyerror!void {
            switch (value) {
                .null => try out.append(allocator, 0),
                .bool => |b| try out.append(allocator, if (b) 1 else 0),
                .integer => |n| try encodeI64Compat(n, allocator, out),
                .float => |f| try encodeI64Compat(@intFromFloat(@round(f)), allocator, out),
                .number_string => |snum| {
                    if (std.fmt.parseInt(i64, snum, 10)) |n| {
                        try encodeI64Compat(n, allocator, out);
                    } else |_| {
                        if (std.fmt.parseFloat(f64, snum)) |f| {
                            try encodeI64Compat(@intFromFloat(@round(f)), allocator, out);
                        } else |_| {
                            try out.append(allocator, 0);
                        }
                    }
                },
                .string => |str| {
                    if (str.len == 0) {
                        try out.append(allocator, 242);
                    } else {
                        try out.append(allocator, 243);
                        try encodeUint32(@intCast(str.len), allocator, out);
                        try out.appendSlice(allocator, str);
                    }
                },
                .array => |arr| {
                    const n = arr.items.len;
                    if (n == 0) {
                        try out.append(allocator, 246);
                    } else if (n <= 3) {
                        try out.append(allocator, @intCast(246 + n));
                    } else {
                        try out.append(allocator, 250);
                        try encodeUint32(@intCast(n), allocator, out);
                    }
                    for (arr.items) |item| {
                        try encodeUnknownJsonPayloadValue(allocator, item, out);
                    }
                },
                else => try out.append(allocator, 0),
            }
        }

        fn encodeUnknownJsonPayloadSnippet(allocator: std.mem.Allocator, payload_json: []const u8, out: *std.ArrayList(u8)) anyerror!void {
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, payload_json, .{});
            defer parsed.deinit();
            try encodeUnknownJsonPayloadValue(allocator, parsed.value, out);
        }

        fn appendUnknownPayloadWireAsDenseJson(allocator: std.mem.Allocator, payload_wire: []const u8, out: *std.ArrayList(u8)) anyerror!void {
            var input = payload_wire;
            const wire = try readU8(&input);
            switch (wire) {
                0...241 => {
                    const n = try decodeNumberBody(wire, &input);
                    var buf: [64]u8 = undefined;
                    const text = std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable;
                    try out.appendSlice(allocator, text);
                },
                242 => try out.appendSlice(allocator, "\"\""),
                246 => try out.appendSlice(allocator, "[]"),
                else => try out.append(allocator, '0'),
            }
        }

        pub fn encode(self: *const Self, allocator: std.mem.Allocator, input: *const T, out: *std.ArrayList(u8)) anyerror!void {
            const ko = self.get_kind_ordinal(input);
            if (ko == 0) {
                if (self.get_unrecognized(input)) |u| {
                    if (u.from_wire) {
                        if (u.payload_wire) |payload_wire| {
                            try emitWrapperHeader(u.number, allocator, out);
                            try out.appendSlice(allocator, payload_wire);
                            return;
                        }
                        try encodeI64Compat(u.number, allocator, out);
                        return;
                    }

                    // Unknown variants parsed from JSON are not re-encoded into
                    // binary unknown payloads; they collapse to the default value.
                    try out.append(allocator, 0);
                } else {
                    try out.append(allocator, 0);
                }
                return;
            }

            if (ko < self.kind_ordinal_to_entry.items.len) {
                if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                    if (entry.is_constant_fn(entry.ctx)) {
                        return entry.encode_value_fn(entry.ctx, allocator, input, out);
                    }

                    const n = entry.number;
                    if (n >= 1 and n <= 4) {
                        try out.append(allocator, @intCast(250 + n));
                    } else {
                        try out.append(allocator, 248);
                        try encodeUint32(@intCast(n), allocator, out);
                    }
                    return entry.encode_value_fn(entry.ctx, allocator, input, out);
                }
            }

            try out.append(allocator, 0);
        }

        pub fn decode(self: *const Self, allocator: std.mem.Allocator, input: *[]const u8, keep_unrecognized: bool) anyerror!T {
            const wire = try readU8(input);

            if (wire < 242) {
                const n: i32 = @intCast(try decodeNumberBody(wire, input));
                return try self.resolveConstantLookup(allocator, n, keep_unrecognized, true);
            }

            const wrapper_number: i32 = if (wire == 248)
                @intCast(try decodeNumber(input))
            else if (wire >= 251 and wire <= 254)
                @as(i32, wire) - 250
            else
                return T.unknown;

            if (self.number_to_entry.get(wrapper_number)) |any| {
                return switch (any) {
                    .wrapper => |ko| blk: {
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                break :blk try entry.wrap_decode_fn(entry.ctx, allocator, input, false);
                            }
                        }
                        try skipValue(input);
                        break :blk T.unknown;
                    },
                    .removed => blk: {
                        try skipValue(input);
                        break :blk T.unknown;
                    },
                    .constant => |ko| blk: {
                        try skipValue(input);
                        if (ko < self.kind_ordinal_to_entry.items.len) {
                            if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                                break :blk entry.constant_fn(entry.ctx);
                            }
                        }
                        break :blk T.unknown;
                    },
                };
            }

            if (keep_unrecognized) {
                const before = input.*;
                try skipValue(input);
                const consumed = before.len - input.*.len;
                const payload_wire = try allocator.dupe(u8, before[0..consumed]);
                const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                uv.* = .{ .number = wrapper_number, .from_wire = true, .payload_json = null, .payload_wire = payload_wire };
                return self.wrap_unrecognized(uv);
            }
            try skipValue(input);
            return T.unknown;
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator, input: *const T) anyerror!T {
            const ko = self.get_kind_ordinal(input);
            if (ko == 0) {
                if (self.get_unrecognized(input)) |u| {
                    const uv = try allocator.create(unrecognized.UnrecognizedVariant(T));
                    uv.* = try u.clone(allocator);
                    return self.wrap_unrecognized(uv);
                } else {
                    return T.unknown;
                }
            }

            if (ko < self.kind_ordinal_to_entry.items.len) {
                if (self.kind_ordinal_to_entry.items[ko]) |entry| {
                    return entry.clone_fn(entry.ctx, allocator, input);
                }
            }

            return T.unknown;
        }

        pub fn typeDescriptor(self: *const Self) *const td.TypeDescriptor {
            return &self.descriptor;
        }

        fn shortName(qualified_name: []const u8) []const u8 {
            if (std.mem.lastIndexOfScalar(u8, qualified_name, '.')) |idx| {
                return qualified_name[idx + 1 ..];
            }
            return qualified_name;
        }
    };
}

pub fn _enumSerializerFromStatic(comptime T: type, comptime get_adapter: *const fn () *EnumAdapter(T)) s.Serializer(T) {
    const Impl = struct {
        pub fn isDefault(_: @This(), input: T) bool {
            return get_adapter().isDefault(&input);
        }

        pub fn toJson(_: @This(), allocator: std.mem.Allocator, input: T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            return get_adapter().toJson(allocator, &input, eol_indent, out);
        }

        pub fn fromJson(_: @This(), allocator: std.mem.Allocator, json: std.json.Value, keep_unrecognized: bool) anyerror!T {
            return get_adapter().fromJson(allocator, json, keep_unrecognized);
        }

        pub fn encode(_: @This(), allocator: std.mem.Allocator, input: T, out: *std.ArrayList(u8)) anyerror!void {
            return get_adapter().encode(allocator, &input, out);
        }

        pub fn decode(_: @This(), allocator: std.mem.Allocator, input: *[]const u8, keep_unrecognized: bool) anyerror!T {
            return get_adapter().decode(allocator, input, keep_unrecognized);
        }

        pub fn clone(_: @This(), allocator: std.mem.Allocator, input: T) anyerror!T {
            return get_adapter().clone(allocator, &input);
        }

        pub fn typeDescriptor(_: @This()) *const td.TypeDescriptor {
            return get_adapter().typeDescriptor();
        }
    };

    return s._serializerFromAdapter(T, Impl);
}
