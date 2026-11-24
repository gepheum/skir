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

pub fn StructAdapter(comptime T: type) type {
    return struct {
        const Self = @This();

        const FieldEntry = struct {
            name: []const u8,
            number: i32,
            doc: []const u8,
            ctx: *anyopaque,
            is_default_fn: *const fn (*const anyopaque, *const T) bool,
            clone_into_fn: *const fn (*const anyopaque, std.mem.Allocator, *T, *const T) anyerror!void,
            to_json_fn: *const fn (*const anyopaque, std.mem.Allocator, *const T, ?[]const u8, *std.ArrayList(u8)) anyerror!void,
            set_from_json_fn: *const fn (*const anyopaque, std.mem.Allocator, *T, std.json.Value, bool) anyerror!void,
            encode_fn: *const fn (*const anyopaque, std.mem.Allocator, *const T, *std.ArrayList(u8)) anyerror!void,
            decode_into_fn: *const fn (*const anyopaque, std.mem.Allocator, *T, *[]const u8, bool) anyerror!void,
            field_type_fn: *const fn () *const td.TypeDescriptor,
        };

        allocator: std.mem.Allocator,
        module_path: []const u8,
        qualified_name: []const u8,
        doc: []const u8,
        get_unrecognized: *const fn (*const T) ?*const unrecognized.UnrecognizedFields(T),
        set_unrecognized: *const fn (*T, ?*const unrecognized.UnrecognizedFields(T)) void,

        ordered_entries: std.ArrayList(FieldEntry),
        name_to_index: std.StringHashMap(usize),
        slot_to_index: std.ArrayList(?usize),
        removed_numbers: std.ArrayList(i32),
        max_number: i32,
        descriptor: td.TypeDescriptor,

        pub fn init(
            allocator: std.mem.Allocator,
            module_path: []const u8,
            qualified_name: []const u8,
            doc: []const u8,
            get_unrecognized: *const fn (*const T) ?*const unrecognized.UnrecognizedFields(T),
            set_unrecognized: *const fn (*T, ?*const unrecognized.UnrecognizedFields(T)) void,
        ) !Self {
            return .{
                .allocator = allocator,
                .module_path = try allocator.dupe(u8, module_path),
                .qualified_name = try allocator.dupe(u8, qualified_name),
                .doc = try allocator.dupe(u8, doc),
                .get_unrecognized = get_unrecognized,
                .set_unrecognized = set_unrecognized,
                .ordered_entries = .empty,
                .name_to_index = std.StringHashMap(usize).init(allocator),
                .slot_to_index = .empty,
                .removed_numbers = .empty,
                .max_number = -1,
                .descriptor = .{ .struct_record = .{} },
            };
        }

        pub fn addField(
            self: *Self,
            comptime V: type,
            name: []const u8,
            number: i32,
            ser: s.Serializer(V),
            doc: []const u8,
            getter: *const fn (*const T) V,
            setter: *const fn (*T, V) void,
        ) !void {
            const Ctx = struct {
                ser: s.Serializer(V),
                getter: *const fn (*const T) V,
                setter: *const fn (*T, V) void,
            };
            const Ops = struct {
                fn isDefault(ctx_ptr: *const anyopaque, value: *const T) bool {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.ser._vtable.isDefaultFn(ctx.getter(value));
                }

                fn toJson(ctx_ptr: *const anyopaque, alloc: std.mem.Allocator, value: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.ser._vtable.toJsonFn(alloc, ctx.getter(value), eol_indent, out);
                }

                fn cloneInto(ctx_ptr: *const anyopaque, alloc: std.mem.Allocator, out_value: *T, in_value: *const T) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const v = try ctx.ser._vtable.cloneFn(alloc, ctx.getter(in_value));
                    ctx.setter(out_value, v);
                }

                fn setFromJson(ctx_ptr: *const anyopaque, alloc: std.mem.Allocator, value: *T, json: std.json.Value, keep_unrecognized: bool) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const v = try ctx.ser._vtable.fromJsonFn(alloc, json, keep_unrecognized);
                    ctx.setter(value, v);
                }

                fn encode(ctx_ptr: *const anyopaque, alloc: std.mem.Allocator, value: *const T, out: *std.ArrayList(u8)) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    return ctx.ser._vtable.encodeFn(alloc, ctx.getter(value), out);
                }

                fn decodeInto(ctx_ptr: *const anyopaque, alloc: std.mem.Allocator, value: *T, input: *[]const u8, keep_unrecognized: bool) anyerror!void {
                    const ctx: *const Ctx = @ptrCast(@alignCast(ctx_ptr));
                    const v = try ctx.ser._vtable.decodeFn(alloc, input, keep_unrecognized);
                    ctx.setter(value, v);
                }
            };

            const ctx = try self.allocator.create(Ctx);
            ctx.* = .{
                .ser = ser,
                .getter = getter,
                .setter = setter,
            };

            const entry: FieldEntry = .{
                .name = try self.allocator.dupe(u8, name),
                .number = number,
                .doc = try self.allocator.dupe(u8, doc),
                .ctx = ctx,
                .is_default_fn = Ops.isDefault,
                .clone_into_fn = Ops.cloneInto,
                .to_json_fn = Ops.toJson,
                .set_from_json_fn = Ops.setFromJson,
                .encode_fn = Ops.encode,
                .decode_into_fn = Ops.decodeInto,
                .field_type_fn = ser._vtable.typeDescriptorFn,
            };

            const idx = self.ordered_entries.items.len;
            try self.ordered_entries.append(self.allocator, entry);

            const map_key = try self.allocator.dupe(u8, name);
            try self.name_to_index.put(map_key, idx);

            if (number > self.max_number) self.max_number = number;
        }

        pub fn addRemovedNumber(self: *Self, number: i32) !void {
            try self.removed_numbers.append(self.allocator, number);
            if (number > self.max_number) self.max_number = number;
        }

        pub fn finalize(self: *Self) !void {
            std.sort.pdq(FieldEntry, self.ordered_entries.items, {}, struct {
                fn lessThan(_: void, a: FieldEntry, b: FieldEntry) bool {
                    return a.number < b.number;
                }
            }.lessThan);

            self.name_to_index.clearRetainingCapacity();
            for (self.ordered_entries.items, 0..) |entry, idx| {
                const k = try self.allocator.dupe(u8, entry.name);
                try self.name_to_index.put(k, idx);
            }

            self.slot_to_index.clearRetainingCapacity();
            if (self.max_number >= 0) {
                try self.slot_to_index.resize(self.allocator, @intCast(self.max_number + 1));
                for (self.slot_to_index.items) |*slot| slot.* = null;
                for (self.ordered_entries.items, 0..) |entry, idx| {
                    self.slot_to_index.items[@intCast(entry.number)] = idx;
                }
            }

            const fields = try self.allocator.alloc(td.StructField, self.ordered_entries.items.len);
            for (self.ordered_entries.items, 0..) |entry, idx| {
                fields[idx] = .{
                    .name = entry.name,
                    .number = entry.number,
                    .field_type = entry.field_type_fn(),
                    .doc = entry.doc,
                };
            }
            const removed = try self.allocator.dupe(i32, self.removed_numbers.items);

            self.descriptor = .{ .struct_record = .{
                .name = shortName(self.qualified_name),
                .qualified_name = self.qualified_name,
                .module_path = self.module_path,
                .doc = self.doc,
                .fields = fields,
                .removed_numbers = removed,
            } };
        }

        pub fn isDefault(self: *const Self, input: *const T) bool {
            if (self.get_unrecognized(input) != null) return false;
            for (self.ordered_entries.items) |entry| {
                if (!entry.is_default_fn(entry.ctx, input)) return false;
            }
            return true;
        }

        pub fn toJson(self: *const Self, allocator: std.mem.Allocator, input: *const T, eol_indent: ?[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            if (eol_indent) |indent| {
                return self.toReadableJson(allocator, input, indent, out);
            }
            return self.toDenseJson(allocator, input, out);
        }

        fn toDenseJson(self: *const Self, allocator: std.mem.Allocator, input: *const T, out: *std.ArrayList(u8)) anyerror!void {
            try out.append(allocator, '[');
            const slot_count = self.getSlotCount(input);
            const recognized_count = self.slot_to_index.items.len;
            const maybe_unrecognized = self.get_unrecognized(input);
            for (0..slot_count) |slot| {
                if (slot > 0) try out.append(allocator, ',');
                if (slot < recognized_count) {
                    if (self.slot_to_index.items[slot]) |idx| {
                        const e = self.ordered_entries.items[idx];
                        try e.to_json_fn(e.ctx, allocator, input, null, out);
                    } else {
                        try out.append(allocator, '0');
                    }
                } else {
                    if (maybe_unrecognized) |u| {
                        const tail_index = slot - recognized_count;
                        if (u.dense_tail_wire) |tail_wire| {
                            if (tail_index < tail_wire.len) {
                                try appendWireValueAsDenseJson(allocator, tail_wire[tail_index], out);
                                continue;
                            }
                        }
                        if (u.dense_tail_json) |tail| {
                            if (tail_index < tail.len) {
                                try out.appendSlice(allocator, tail[tail_index]);
                                continue;
                            }
                        }
                    }
                    try out.append(allocator, '0');
                }
            }
            try out.append(allocator, ']');
        }

        fn appendWireValueAsDenseJson(allocator: std.mem.Allocator, raw: []const u8, out: *std.ArrayList(u8)) anyerror!void {
            var rest = raw;
            try appendWireValueAsDenseJsonFromInput(allocator, &rest, out);
        }

        fn appendWireValueAsDenseJsonFromInput(allocator: std.mem.Allocator, input: *[]const u8, out: *std.ArrayList(u8)) anyerror!void {
            const wire = try readU8(input);
            switch (wire) {
                0...241 => {
                    const n = try decodeNumberBody(wire, input);
                    var buf: [64]u8 = undefined;
                    const text = std.fmt.bufPrint(&buf, "{d}", .{n}) catch unreachable;
                    try out.appendSlice(allocator, text);
                },
                242 => try out.appendSlice(allocator, "\"\""),
                243 => {
                    const n: usize = @intCast(try decodeNumber(input));
                    if (input.*.len < n) return error.UnexpectedEndOfInput;
                    const sbytes = input.*[0..n];
                    input.* = input.*[n..];
                    try writeJsonEscapedString(sbytes, allocator, out);
                },
                246 => try out.appendSlice(allocator, "[]"),
                247...249 => {
                    const n: usize = @intCast(wire - 246);
                    try out.append(allocator, '[');
                    for (0..n) |i| {
                        if (i > 0) try out.append(allocator, ',');
                        try appendWireValueAsDenseJsonFromInput(allocator, input, out);
                    }
                    try out.append(allocator, ']');
                },
                250 => {
                    const n: usize = @intCast(try decodeNumber(input));
                    try out.append(allocator, '[');
                    for (0..n) |i| {
                        if (i > 0) try out.append(allocator, ',');
                        try appendWireValueAsDenseJsonFromInput(allocator, input, out);
                    }
                    try out.append(allocator, ']');
                },
                else => try out.append(allocator, '0'),
            }
        }

        fn toReadableJson(self: *const Self, allocator: std.mem.Allocator, input: *const T, eol_indent: []const u8, out: *std.ArrayList(u8)) anyerror!void {
            try out.append(allocator, '{');

            var child_buf: [256]u8 = undefined;
            const child_len = @min(eol_indent.len + 2, child_buf.len);
            @memcpy(child_buf[0..eol_indent.len], eol_indent);
            child_buf[eol_indent.len] = ' ';
            if (eol_indent.len + 1 < child_buf.len) child_buf[eol_indent.len + 1] = ' ';
            const child_eol = child_buf[0..child_len];

            var first = true;
            for (self.ordered_entries.items) |entry| {
                if (entry.is_default_fn(entry.ctx, input)) continue;
                if (!first) try out.append(allocator, ',');
                first = false;
                try out.appendSlice(allocator, child_eol);
                try writeJsonEscapedString(entry.name, allocator, out);
                try out.appendSlice(allocator, ": ");
                try entry.to_json_fn(entry.ctx, allocator, input, child_eol, out);
            }

            if (!first) try out.appendSlice(allocator, eol_indent);
            try out.append(allocator, '}');
        }

        fn getKnownSlotCount(self: *const Self, input: *const T) usize {
            var i = self.ordered_entries.items.len;
            while (i > 0) {
                i -= 1;
                const e = self.ordered_entries.items[i];
                if (!e.is_default_fn(e.ctx, input)) {
                    return @intCast(e.number + 1);
                }
            }
            return 0;
        }

        fn getSlotCount(self: *const Self, input: *const T) usize {
            const known_slots = self.getKnownSlotCount(input);

            if (self.get_unrecognized(input)) |u| {
                const preserve = if (u.dense_tail_json != null)
                    true
                else
                    self.canPreserveUnknownDenseTail();
                if (preserve) {
                    const preserved_slots = self.slot_to_index.items.len + u.dense_extra_count;
                    return @max(known_slots, preserved_slots);
                }
            }

            return known_slots;
        }

        fn maxFieldSlotCount(self: *const Self) usize {
            var max_slot: usize = 0;
            for (self.ordered_entries.items) |e| {
                const slot: usize = @intCast(e.number + 1);
                if (slot > max_slot) max_slot = slot;
            }
            return max_slot;
        }

        fn canPreserveUnknownDenseTail(self: *const Self) bool {
            // Preserve unknown tail only when there are no trailing removed slots.
            return self.slot_to_index.items.len == self.maxFieldSlotCount();
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

        fn encodeUnknownJsonValue(allocator: std.mem.Allocator, value: std.json.Value, out: *std.ArrayList(u8)) anyerror!void {
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
                        try encodeUnknownJsonValue(allocator, item, out);
                    }
                },
                else => try out.append(allocator, 0),
            }
        }

        fn encodeUnknownJsonSnippet(allocator: std.mem.Allocator, json_snippet: []const u8, out: *std.ArrayList(u8)) anyerror!void {
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_snippet, .{});
            defer parsed.deinit();
            try encodeUnknownJsonValue(allocator, parsed.value, out);
        }

        pub fn fromJson(self: *const Self, allocator: std.mem.Allocator, json: std.json.Value, keep_unrecognized: bool) anyerror!T {
            return switch (json) {
                .integer, .float => T.default,
                .array => |arr| self.fromDenseJson(allocator, arr.items, keep_unrecognized),
                .object => |obj| self.fromReadableJson(allocator, obj, keep_unrecognized),
                else => T.default,
            };
        }

        fn fromDenseJson(self: *const Self, allocator: std.mem.Allocator, items: []const std.json.Value, keep_unrecognized: bool) anyerror!T {
            var t = T.default;
            const recognized_count = self.slot_to_index.items.len;
            var n = items.len;

            if (n > recognized_count) {
                if (keep_unrecognized) {
                    const extra = items[recognized_count..n];
                    var rendered = try allocator.alloc([]const u8, extra.len);
                    errdefer allocator.free(rendered);

                    for (extra, 0..) |value, idx| {
                        rendered[idx] = try std.json.Stringify.valueAlloc(allocator, value, .{});
                    }

                    const unrec = try allocator.create(unrecognized.UnrecognizedFields(T));
                    unrec.* = .{
                        .dense_tail_json = rendered,
                        .dense_extra_count = extra.len,
                        .dense_tail_wire = null,
                    };
                    self.set_unrecognized(&t, unrec);
                }
                n = recognized_count;
            }

            for (self.ordered_entries.items) |entry| {
                const slot: usize = @intCast(entry.number);
                if (slot >= n) break;
                try entry.set_from_json_fn(entry.ctx, allocator, &t, items[slot], keep_unrecognized);
            }

            return t;
        }

        fn fromReadableJson(self: *const Self, allocator: std.mem.Allocator, obj: std.json.ObjectMap, keep_unrecognized: bool) anyerror!T {
            var t = T.default;
            var it = obj.iterator();
            while (it.next()) |kv| {
                const key = kv.key_ptr.*;
                const value = kv.value_ptr.*;
                if (self.name_to_index.get(key)) |idx| {
                    const e = self.ordered_entries.items[idx];
                    try e.set_from_json_fn(e.ctx, allocator, &t, value, keep_unrecognized);
                }
            }
            return t;
        }

        pub fn encode(self: *const Self, allocator: std.mem.Allocator, input: *const T, out: *std.ArrayList(u8)) anyerror!void {
            var slot_count = self.getKnownSlotCount(input);
            const recognized_count = self.slot_to_index.items.len;
            const maybe_unrecognized = self.get_unrecognized(input);
            if (maybe_unrecognized) |u| {
                if (u.dense_tail_wire != null) {
                    const preserved_slots = recognized_count + u.dense_extra_count;
                    slot_count = @max(slot_count, preserved_slots);
                } else if (u.dense_tail_json != null and self.canPreserveUnknownDenseTail()) {
                    const preserved_slots = recognized_count + u.dense_extra_count;
                    slot_count = @max(slot_count, preserved_slots);
                }
            }
            if (slot_count <= 3) {
                try out.append(allocator, @intCast(246 + slot_count));
            } else {
                try out.append(allocator, 250);
                try encodeUint32(@intCast(slot_count), allocator, out);
            }

            for (0..slot_count) |slot| {
                if (slot < recognized_count) {
                    if (self.slot_to_index.items[slot]) |idx| {
                        const e = self.ordered_entries.items[idx];
                        try e.encode_fn(e.ctx, allocator, input, out);
                    } else {
                        try out.append(allocator, 0);
                    }
                } else {
                    if (maybe_unrecognized) |u| {
                        const tail_index = slot - recognized_count;
                        if (u.dense_tail_wire) |tail_wire| {
                            if (tail_index < tail_wire.len) {
                                try out.appendSlice(allocator, tail_wire[tail_index]);
                                continue;
                            }
                        }
                        if (u.dense_tail_json) |tail| {
                            if (tail_index < tail.len) {
                                try encodeUnknownJsonSnippet(allocator, tail[tail_index], out);
                                continue;
                            }
                        }
                    }
                    try out.append(allocator, 0);
                }
            }
        }

        pub fn decode(self: *const Self, allocator: std.mem.Allocator, input: *[]const u8, keep_unrecognized: bool) anyerror!T {
            const wire = try readU8(input);
            if (wire == 0 or wire == 246) return T.default;

            const encoded_slot_count: usize = if (wire == 250)
                @intCast(try decodeNumber(input))
            else if (wire >= 247 and wire <= 249)
                @intCast(wire - 246)
            else
                return T.default;

            var t = T.default;
            const recognized_count = self.slot_to_index.items.len;
            const slots_to_fill = @min(encoded_slot_count, recognized_count);

            var i: usize = 0;
            while (i < slots_to_fill) : (i += 1) {
                if (self.slot_to_index.items[i]) |idx| {
                    const e = self.ordered_entries.items[idx];
                    try e.decode_into_fn(e.ctx, allocator, &t, input, keep_unrecognized);
                } else {
                    try skipValue(input);
                }
            }

            if (encoded_slot_count > recognized_count) {
                if (keep_unrecognized) {
                    const extra_count = encoded_slot_count - recognized_count;
                    var tail_wire = try allocator.alloc([]const u8, extra_count);
                    errdefer allocator.free(tail_wire);

                    var j: usize = recognized_count;
                    while (j < encoded_slot_count) : (j += 1) {
                        const idx = j - recognized_count;
                        const before = input.*;
                        try skipValue(input);
                        const consumed = before.len - input.*.len;
                        tail_wire[idx] = try allocator.dupe(u8, before[0..consumed]);
                    }

                    const unrec = try allocator.create(unrecognized.UnrecognizedFields(T));
                    unrec.* = .{
                        .dense_tail_json = null,
                        .dense_extra_count = extra_count,
                        .dense_tail_wire = tail_wire,
                    };
                    self.set_unrecognized(&t, unrec);
                } else {
                    var j: usize = recognized_count;
                    while (j < encoded_slot_count) : (j += 1) {
                        try skipValue(input);
                    }
                }
            }

            return t;
        }

        pub fn clone(self: *const Self, allocator: std.mem.Allocator, input: *const T) anyerror!T {
            var out = T.default;
            for (self.ordered_entries.items) |entry| {
                try entry.clone_into_fn(entry.ctx, allocator, &out, input);
            }

            if (self.get_unrecognized(input)) |u| {
                const unrec = try allocator.create(unrecognized.UnrecognizedFields(T));
                unrec.* = try u.clone(allocator);
                self.set_unrecognized(&out, unrec);
            }

            return out;
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

pub fn _structSerializerFromStatic(comptime T: type, comptime get_adapter: *const fn () *StructAdapter(T)) s.Serializer(T) {
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
