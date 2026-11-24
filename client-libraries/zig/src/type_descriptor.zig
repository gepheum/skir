const std = @import("std");

// =============================================================================
// TypeDescriptor
// =============================================================================

/// All primitive Skir types.
pub const PrimitiveType = enum {
    Bool,
    Int32,
    Int64,
    Hash64,
    Float32,
    Float64,
    Timestamp,
    String,
    Bytes,

    /// Returns the canonical schema name used in descriptor JSON.
    pub fn asStr(self: PrimitiveType) []const u8 {
        return switch (self) {
            .Bool => "bool",
            .Int32 => "int32",
            .Int64 => "int64",
            .Hash64 => "hash64",
            .Float32 => "float32",
            .Float64 => "float64",
            .Timestamp => "timestamp",
            .String => "string",
            .Bytes => "bytes",
        };
    }

    fn fromStr(s: []const u8) ?PrimitiveType {
        const map = [_]struct { []const u8, PrimitiveType }{
            .{ "bool", .Bool },
            .{ "int32", .Int32 },
            .{ "int64", .Int64 },
            .{ "hash64", .Hash64 },
            .{ "float32", .Float32 },
            .{ "float64", .Float64 },
            .{ "timestamp", .Timestamp },
            .{ "string", .String },
            .{ "bytes", .Bytes },
        };
        for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

/// Describes an ordered collection of elements of a single type.
pub const ArrayDescriptor = struct {
    /// Descriptor for each element.
    item_type: *const TypeDescriptor,
    /// Optional key path for keyed collections.
    key_extractor: []const u8,
};

/// Describes a single field of a Skir struct.
pub const StructField = struct {
    name: []const u8,
    number: i32,
    /// The type of this field. `null` in the simplified compile-time descriptor
    /// produced by generated code; populated after a JSON round-trip.
    field_type: ?*const TypeDescriptor = null,
    doc: []const u8 = "",
};

/// A constant (non-wrapping) enum variant.
pub const EnumConstantVariant = struct {
    name: []const u8,
    number: i32,
    doc: []const u8 = "",
};

/// An enum variant that wraps a value of another type.
pub const EnumWrapperVariant = struct {
    name: []const u8,
    number: i32,
    variant_type: ?*const TypeDescriptor = null,
    doc: []const u8 = "",
};

/// A single variant of a Skir enum — either constant or wrapper.
pub const EnumVariant = union(enum) {
    constant: EnumConstantVariant,
    wrapper: EnumWrapperVariant,

    /// Variant name as declared in schema.
    pub fn name(self: EnumVariant) []const u8 {
        return switch (self) {
            .constant => |v| v.name,
            .wrapper => |v| v.name,
        };
    }
    /// Stable numeric identifier of the variant.
    pub fn number(self: EnumVariant) i32 {
        return switch (self) {
            .constant => |v| v.number,
            .wrapper => |v| v.number,
        };
    }
    /// Schema documentation attached to the variant.
    pub fn doc(self: EnumVariant) []const u8 {
        return switch (self) {
            .constant => |v| v.doc,
            .wrapper => |v| v.doc,
        };
    }
    /// Wrapped payload type for wrapper variants; `null` for constant variants.
    pub fn variantType(self: EnumVariant) ?*const TypeDescriptor {
        return switch (self) {
            .constant => null,
            .wrapper => |v| v.variant_type,
        };
    }
};

/// Runtime descriptor for a Skir struct type.
pub const StructDescriptor = struct {
    name: []const u8 = "",
    qualified_name: []const u8 = "",
    module_path: []const u8 = "",
    doc: []const u8 = "",
    fields: []const StructField = &.{},
    removed_numbers: []const i32 = &.{},

    /// Returns a field by schema name, or `null` when missing.
    pub fn fieldByName(self: StructDescriptor, field_name: []const u8) ?StructField {
        for (self.fields) |f| {
            if (std.mem.eql(u8, f.name, field_name)) return f;
        }
        return null;
    }

    /// Returns a field by stable field number, or `null` when missing.
    pub fn fieldByNumber(self: StructDescriptor, num: i32) ?StructField {
        for (self.fields) |f| {
            if (f.number == num) return f;
        }
        return null;
    }
};

/// Runtime descriptor for a Skir enum type.
pub const EnumDescriptor = struct {
    name: []const u8 = "",
    qualified_name: []const u8 = "",
    module_path: []const u8 = "",
    doc: []const u8 = "",
    variants: []const EnumVariant = &.{},
    removed_numbers: []const i32 = &.{},

    /// Returns a variant by schema name, or `null` when missing.
    pub fn variantByName(self: EnumDescriptor, variant_name: []const u8) ?EnumVariant {
        for (self.variants) |v| {
            if (std.mem.eql(u8, v.name(), variant_name)) return v;
        }
        return null;
    }

    /// Returns a variant by stable variant number, or `null` when missing.
    pub fn variantByNumber(self: EnumDescriptor, num: i32) ?EnumVariant {
        for (self.variants) |v| {
            if (v.number() == num) return v;
        }
        return null;
    }
};

/// Describes a Skir type at runtime.
pub const TypeDescriptor = union(enum) {
    primitive: PrimitiveType,
    optional: *const TypeDescriptor,
    array: ArrayDescriptor,
    /// Descriptor for a struct type.
    struct_record: StructDescriptor,
    /// Descriptor for an enum type.
    enum_record: EnumDescriptor,
};

// =============================================================================
// TypeDescriptor JSON serialisation
// =============================================================================

/// Serializes a `TypeDescriptor` to a pretty-printed JSON string.
///
/// The returned slice is allocated with `allocator` and must be freed by the
/// caller.
///
/// This format is intended for tooling/introspection, such as exposing
/// method request/response shapes in a service endpoint.
pub fn typeDescriptorToJson(allocator: std.mem.Allocator, td: TypeDescriptor) ![]const u8 {
    var records_list = std.ArrayList(RecordEntry){};
    defer records_list.deinit(allocator);
    var seen = std.StringHashMap(usize).init(allocator);
    defer seen.deinit();

    try collectRecords(allocator, &td, &records_list, &seen);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var root = std.json.ObjectMap.init(a);
    try root.put("type", try typeSignatureToValue(a, td));
    var records_arr = std.json.Array.init(a);
    for (records_list.items) |entry| {
        try records_arr.append(try recordEntryToValue(a, entry));
    }
    try root.put("records", .{ .array = records_arr });

    const root_val = std.json.Value{ .object = root };
    return std.json.Stringify.valueAlloc(allocator, root_val, .{ .whitespace = .indent_2 });
}

const RecordEntry = union(enum) {
    struct_record: *const StructDescriptor,
    enum_record: *const EnumDescriptor,

    fn recordId(self: RecordEntry) []const u8 {
        return switch (self) {
            .struct_record => |s| s.qualified_name,
            .enum_record => |e| e.qualified_name,
        };
    }
};

fn collectRecords(
    allocator: std.mem.Allocator,
    td: *const TypeDescriptor,
    list: *std.ArrayList(RecordEntry),
    seen: *std.StringHashMap(usize),
) error{OutOfMemory}!void {
    switch (td.*) {
        .primitive => {},
        .optional => |inner| try collectRecords(allocator, inner, list, seen),
        .array => |arr| try collectRecords(allocator, arr.item_type, list, seen),
        .struct_record => |*s| {
            const rid = s.qualified_name;
            if (seen.get(rid)) |idx| {
                const existing = list.items[idx];
                switch (existing) {
                    .struct_record => |prev| {
                        // Prefer richer struct descriptors when duplicate IDs are seen
                        // (e.g. if a partially initializing adapter produced an empty shape).
                        if (prev.fields.len < s.fields.len) {
                            list.items[idx] = .{ .struct_record = s };
                            for (s.fields) |f| {
                                if (f.field_type) |ft| try collectRecords(allocator, ft, list, seen);
                            }
                        }
                    },
                    .enum_record => {},
                }
                return;
            }
            const idx = list.items.len;
            try seen.put(rid, idx);
            try list.append(allocator, .{ .struct_record = s });
            for (s.fields) |f| {
                if (f.field_type) |ft| try collectRecords(allocator, ft, list, seen);
            }
        },
        .enum_record => |*e| {
            const rid = e.qualified_name;
            if (seen.get(rid)) |idx| {
                const existing = list.items[idx];
                switch (existing) {
                    .enum_record => |prev| {
                        // Same strategy as structs: keep the most informative descriptor.
                        if (prev.variants.len < e.variants.len) {
                            list.items[idx] = .{ .enum_record = e };
                            for (e.variants) |v| {
                                if (v.variantType()) |vt| try collectRecords(allocator, vt, list, seen);
                            }
                        }
                    },
                    .struct_record => {},
                }
                return;
            }
            const idx = list.items.len;
            try seen.put(rid, idx);
            try list.append(allocator, .{ .enum_record = e });
            for (e.variants) |v| {
                if (v.variantType()) |vt| try collectRecords(allocator, vt, list, seen);
            }
        },
    }
}

fn typeSignatureToValue(a: std.mem.Allocator, td: TypeDescriptor) !std.json.Value {
    var obj = std.json.ObjectMap.init(a);
    switch (td) {
        .primitive => |p| {
            try obj.put("kind", .{ .string = "primitive" });
            try obj.put("value", .{ .string = p.asStr() });
        },
        .optional => |inner| {
            try obj.put("kind", .{ .string = "optional" });
            try obj.put("value", try typeSignatureToValue(a, inner.*));
        },
        .array => |arr| {
            try obj.put("kind", .{ .string = "array" });
            var val_obj = std.json.ObjectMap.init(a);
            try val_obj.put("item", try typeSignatureToValue(a, arr.item_type.*));
            if (arr.key_extractor.len > 0) {
                try val_obj.put("key_extractor", .{ .string = arr.key_extractor });
            }
            try obj.put("value", .{ .object = val_obj });
        },
        .struct_record => |s| {
            try obj.put("kind", .{ .string = "record" });
            const rid = try std.fmt.allocPrint(a, "{s}:{s}", .{ s.module_path, s.qualified_name });
            try obj.put("value", .{ .string = rid });
        },
        .enum_record => |e| {
            try obj.put("kind", .{ .string = "record" });
            const rid = try std.fmt.allocPrint(a, "{s}:{s}", .{ e.module_path, e.qualified_name });
            try obj.put("value", .{ .string = rid });
        },
    }
    return .{ .object = obj };
}

fn recordEntryToValue(a: std.mem.Allocator, entry: RecordEntry) !std.json.Value {
    switch (entry) {
        .struct_record => |s| {
            var obj = std.json.ObjectMap.init(a);
            try obj.put("kind", .{ .string = "struct" });
            const record_id = try std.fmt.allocPrint(a, "{s}:{s}", .{ s.module_path, s.qualified_name });
            try obj.put("id", .{ .string = record_id });
            if (s.doc.len > 0) try obj.put("doc", .{ .string = s.doc });
            var fields_arr = std.json.Array.init(a);
            for (s.fields) |f| {
                var fobj = std.json.ObjectMap.init(a);
                try fobj.put("name", .{ .string = f.name });
                try fobj.put("number", .{ .integer = f.number });
                if (f.field_type) |ft| {
                    try fobj.put("type", try typeSignatureToValue(a, ft.*));
                } else {
                    // No type info available (lightweight compile-time descriptor):
                    // emit a stub primitive type so the JSON is well-formed.
                    var stub_type = std.json.ObjectMap.init(a);
                    try stub_type.put("kind", .{ .string = "primitive" });
                    try stub_type.put("value", .{ .string = "bytes" });
                    try fobj.put("type", .{ .object = stub_type });
                }
                if (f.doc.len > 0) try fobj.put("doc", .{ .string = f.doc });
                try fields_arr.append(.{ .object = fobj });
            }
            try obj.put("fields", .{ .array = fields_arr });
            if (s.removed_numbers.len > 0) {
                var rn_arr = std.json.Array.init(a);
                const sorted = try sortedIntegers(a, s.removed_numbers);
                for (sorted) |n| try rn_arr.append(.{ .integer = n });
                try obj.put("removed_numbers", .{ .array = rn_arr });
            }
            return .{ .object = obj };
        },
        .enum_record => |e| {
            var obj = std.json.ObjectMap.init(a);
            try obj.put("kind", .{ .string = "enum" });
            const record_id = try std.fmt.allocPrint(a, "{s}:{s}", .{ e.module_path, e.qualified_name });
            try obj.put("id", .{ .string = record_id });
            if (e.doc.len > 0) try obj.put("doc", .{ .string = e.doc });
            // Variants must be sorted by number in the JSON output.
            const sorted_variants = try a.dupe(EnumVariant, e.variants);
            std.sort.pdq(EnumVariant, sorted_variants, {}, variantLessThan);
            var variants_arr = std.json.Array.init(a);
            for (sorted_variants) |v| {
                var vobj = std.json.ObjectMap.init(a);
                try vobj.put("name", .{ .string = v.name() });
                try vobj.put("number", .{ .integer = v.number() });
                if (v.variantType()) |vt| {
                    try vobj.put("type", try typeSignatureToValue(a, vt.*));
                }
                if (v.doc().len > 0) try vobj.put("doc", .{ .string = v.doc() });
                try variants_arr.append(.{ .object = vobj });
            }
            try obj.put("variants", .{ .array = variants_arr });
            if (e.removed_numbers.len > 0) {
                var rn_arr = std.json.Array.init(a);
                const sorted = try sortedIntegers(a, e.removed_numbers);
                for (sorted) |n| try rn_arr.append(.{ .integer = n });
                try obj.put("removed_numbers", .{ .array = rn_arr });
            }
            return .{ .object = obj };
        },
    }
}

fn variantLessThan(_: void, a: EnumVariant, b: EnumVariant) bool {
    return a.number() < b.number();
}

fn sortedIntegers(allocator: std.mem.Allocator, nums: []const i32) ![]i32 {
    const copy = try allocator.dupe(i32, nums);
    std.sort.pdq(i32, copy, {}, std.sort.asc(i32));
    return copy;
}

// =============================================================================
// TypeDescriptor JSON parsing
// =============================================================================

/// Parses a `TypeDescriptor` from the JSON format produced by
/// `typeDescriptorToJson`.
///
/// All returned memory (strings, slices, nested descriptors) is owned by
/// `allocator` and must be freed by the caller.
///
/// Typical round-trip usage:
/// ```zig
/// const td = try serializer.typeDescriptor(allocator);
/// const td_json = try skir_client.typeDescriptorToJson(allocator, td);
/// defer allocator.free(td_json);
///
/// const parsed = try skir_client.typeDescriptorFromJson(allocator, td_json);
/// _ = parsed;
/// ```
pub fn typeDescriptorFromJson(allocator: std.mem.Allocator, json_code: []const u8) !TypeDescriptor {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_code, .{});
    defer parsed.deinit();
    return parseTypeDescriptorFromValue(allocator, parsed.value);
}

fn parseTypeDescriptorFromValue(allocator: std.mem.Allocator, root: std.json.Value) !TypeDescriptor {
    // ── Pass 1: allocate record skeletons ─────────────────────────────────────
    var record_map = std.StringHashMap(ParsedRecord).init(allocator);
    defer {
        var it = record_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            // name, qualified_name, module_path, doc, removed_numbers are transferred
            // into the returned TypeDescriptor and must NOT be freed here.
            entry.value_ptr.raw_items.deinit(allocator);
        }
        record_map.deinit();
    }

    if (root.object.get("records")) |recs_val| {
        for (recs_val.array.items) |rec| {
            const kind = getJsonStr(rec, "kind");
            const id_str = getJsonStr(rec, "id");
            const doc = try allocator.dupe(u8, getJsonStr(rec, "doc"));
            errdefer allocator.free(doc);
            const colon_idx = std.mem.indexOfScalar(u8, id_str, ':') orelse
                return error.MalformedRecordId;
            const module_path = try allocator.dupe(u8, id_str[0..colon_idx]);
            errdefer allocator.free(module_path);
            const qualified_name = try allocator.dupe(u8, id_str[colon_idx + 1 ..]);
            errdefer allocator.free(qualified_name);
            const short_name_start = if (std.mem.lastIndexOfScalar(u8, qualified_name, '.')) |i| i + 1 else 0;
            const name = try allocator.dupe(u8, qualified_name[short_name_start..]);
            errdefer allocator.free(name);

            const removed_numbers = try parseRemovedNumbers(allocator, rec);
            errdefer allocator.free(removed_numbers);

            const fields_or_variants: ?[]const std.json.Value = blk: {
                if (rec.object.get("fields")) |fv| break :blk fv.array.items;
                if (rec.object.get("variants")) |vv| break :blk vv.array.items;
                break :blk null;
            };

            // Deep-copy the raw variant/field JSON values so we own them.
            var raw_items = std.ArrayList(std.json.Value){};
            errdefer raw_items.deinit(allocator);
            if (fields_or_variants) |items| {
                for (items) |item| try raw_items.append(allocator, item);
            }

            const map_key = try allocator.dupe(u8, id_str);
            errdefer allocator.free(map_key);

            if (std.mem.eql(u8, kind, "struct")) {
                try record_map.put(map_key, ParsedRecord{
                    .kind = .struct_record,
                    .name = name,
                    .qualified_name = qualified_name,
                    .module_path = module_path,
                    .doc = doc,
                    .removed_numbers = removed_numbers,
                    .raw_items = raw_items,
                });
            } else if (std.mem.eql(u8, kind, "enum")) {
                try record_map.put(map_key, ParsedRecord{
                    .kind = .enum_record,
                    .name = name,
                    .qualified_name = qualified_name,
                    .module_path = module_path,
                    .doc = doc,
                    .removed_numbers = removed_numbers,
                    .raw_items = raw_items,
                });
            } else {
                allocator.free(doc);
                allocator.free(module_path);
                allocator.free(qualified_name);
                allocator.free(name);
                allocator.free(removed_numbers);
                raw_items.deinit(allocator);
                allocator.free(map_key);
                return error.UnknownRecordKind;
            }
        }
    }

    // ── Pass 2: fill in fields / variants ─────────────────────────────────────
    //
    // We iterate over keys, clone the raw_items list and descriptor info,
    // then call parseTypeSignature which may look up other entries in record_map.
    // Since parseTypeSignature only reads record_map (never writes it), and
    // we only read raw_items here, this is safe to do in a single pass.
    var field_arena = std.heap.ArenaAllocator.init(allocator);
    defer field_arena.deinit();
    const fa = field_arena.allocator();

    var struct_fields_map = std.StringHashMap([]StructField).init(allocator);
    defer {
        var it = struct_fields_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            // The []StructField slice is transferred into the returned TypeDescriptor.
        }
        struct_fields_map.deinit();
    }
    var enum_variants_map = std.StringHashMap([]EnumVariant).init(allocator);
    defer {
        var it = enum_variants_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            // The []EnumVariant slice is transferred into the returned TypeDescriptor.
        }
        enum_variants_map.deinit();
    }

    var rm_it = record_map.iterator();
    while (rm_it.next()) |entry| {
        const id = entry.key_ptr.*;
        const rec = entry.value_ptr;
        switch (rec.kind) {
            .struct_record => {
                var fields = try allocator.alloc(StructField, rec.raw_items.items.len);
                errdefer allocator.free(fields);
                for (rec.raw_items.items, 0..) |fv, i| {
                    const fname = try allocator.dupe(u8, getJsonStr(fv, "name"));
                    errdefer allocator.free(fname);
                    const fnum = getJsonI32(fv, "number");
                    const fdoc = try allocator.dupe(u8, getJsonStr(fv, "doc"));
                    errdefer allocator.free(fdoc);
                    const type_val = fv.object.get("type") orelse return error.FieldMissingType;
                    const ftype_ptr = try allocator.create(TypeDescriptor);
                    errdefer allocator.destroy(ftype_ptr);
                    ftype_ptr.* = try parseTypeSignature(allocator, fa, type_val, &record_map);
                    fields[i] = StructField{
                        .name = fname,
                        .number = fnum,
                        .field_type = ftype_ptr,
                        .doc = fdoc,
                    };
                }
                const key = try allocator.dupe(u8, id);
                errdefer allocator.free(key);
                try struct_fields_map.put(key, fields);
            },
            .enum_record => {
                var variants = try allocator.alloc(EnumVariant, rec.raw_items.items.len);
                errdefer allocator.free(variants);
                for (rec.raw_items.items, 0..) |vv, i| {
                    const vname = try allocator.dupe(u8, getJsonStr(vv, "name"));
                    errdefer allocator.free(vname);
                    const vnum = getJsonI32(vv, "number");
                    const vdoc = try allocator.dupe(u8, getJsonStr(vv, "doc"));
                    errdefer allocator.free(vdoc);
                    if (vv.object.get("type")) |type_val| {
                        const vtype_ptr = try allocator.create(TypeDescriptor);
                        errdefer allocator.destroy(vtype_ptr);
                        vtype_ptr.* = try parseTypeSignature(allocator, fa, type_val, &record_map);
                        variants[i] = EnumVariant{ .wrapper = .{
                            .name = vname,
                            .number = vnum,
                            .variant_type = vtype_ptr,
                            .doc = vdoc,
                        } };
                    } else {
                        variants[i] = EnumVariant{ .constant = .{
                            .name = vname,
                            .number = vnum,
                            .doc = vdoc,
                        } };
                    }
                }
                const key = try allocator.dupe(u8, id);
                errdefer allocator.free(key);
                try enum_variants_map.put(key, variants);
            },
        }
    }

    // ── Resolve root type ─────────────────────────────────────────────────────
    const type_val = root.object.get("type") orelse return error.MissingTypeKey;
    var resolving = std.StringHashMap(void).init(allocator);
    defer resolving.deinit();
    return parseTypeSignatureResolved(allocator, type_val, &record_map, &struct_fields_map, &enum_variants_map, &resolving);
}

const RecordKind = enum { struct_record, enum_record };

const ParsedRecord = struct {
    kind: RecordKind,
    name: []const u8,
    qualified_name: []const u8,
    module_path: []const u8,
    doc: []const u8,
    removed_numbers: []const i32,
    raw_items: std.ArrayList(std.json.Value),

    fn deinit(self: *ParsedRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.qualified_name);
        allocator.free(self.module_path);
        allocator.free(self.doc);
        allocator.free(self.removed_numbers);
        self.raw_items.deinit(allocator);
    }
};

fn parseTypeSignature(
    allocator: std.mem.Allocator,
    _: std.mem.Allocator,
    v: std.json.Value,
    record_map: *const std.StringHashMap(ParsedRecord),
) error{ OutOfMemory, UnknownPrimitive, UnknownTypeKind, UnknownRecordId, MissingValue, ArrayMissingItem, MalformedRecordId }!TypeDescriptor {
    const kind = getJsonStr(v, "kind");
    const val = v.object.get("value") orelse return error.MissingValue;

    if (std.mem.eql(u8, kind, "primitive")) {
        const s = val.string;
        const p = PrimitiveType.fromStr(s) orelse return error.UnknownPrimitive;
        return TypeDescriptor{ .primitive = p };
    } else if (std.mem.eql(u8, kind, "optional")) {
        const inner_ptr = try allocator.create(TypeDescriptor);
        inner_ptr.* = try parseTypeSignature(allocator, allocator, val, record_map);
        return TypeDescriptor{ .optional = inner_ptr };
    } else if (std.mem.eql(u8, kind, "array")) {
        const item_val = val.object.get("item") orelse return error.ArrayMissingItem;
        const item_ptr = try allocator.create(TypeDescriptor);
        item_ptr.* = try parseTypeSignature(allocator, allocator, item_val, record_map);
        const key_extractor = blk: {
            if (val.object.get("key_extractor")) |ke| {
                break :blk try allocator.dupe(u8, ke.string);
            }
            break :blk try allocator.dupe(u8, "");
        };
        return TypeDescriptor{ .array = .{ .item_type = item_ptr, .key_extractor = key_extractor } };
    } else if (std.mem.eql(u8, kind, "record")) {
        const record_id = val.string;
        const rec = record_map.get(record_id) orelse return error.UnknownRecordId;
        // Return a minimal struct/enum descriptor without fields — they will be
        // filled in during the "resolved" pass.
        switch (rec.kind) {
            .struct_record => return TypeDescriptor{ .struct_record = .{
                .name = rec.name,
                .qualified_name = rec.qualified_name,
                .module_path = rec.module_path,
                .doc = rec.doc,
                .removed_numbers = rec.removed_numbers,
            } },
            .enum_record => return TypeDescriptor{ .enum_record = .{
                .name = rec.name,
                .qualified_name = rec.qualified_name,
                .module_path = rec.module_path,
                .doc = rec.doc,
                .removed_numbers = rec.removed_numbers,
            } },
        }
    } else {
        return error.UnknownTypeKind;
    }
}

fn parseTypeSignatureResolved(
    allocator: std.mem.Allocator,
    v: std.json.Value,
    record_map: *const std.StringHashMap(ParsedRecord),
    struct_fields_map: *const std.StringHashMap([]StructField),
    enum_variants_map: *const std.StringHashMap([]EnumVariant),
    resolving: *std.StringHashMap(void),
) error{ OutOfMemory, UnknownPrimitive, UnknownTypeKind, UnknownRecordId, MissingValue, ArrayMissingItem, MalformedRecordId, FieldMissingType }!TypeDescriptor {
    const kind = getJsonStr(v, "kind");
    const val = v.object.get("value") orelse return error.MissingValue;

    if (std.mem.eql(u8, kind, "primitive")) {
        const p = PrimitiveType.fromStr(val.string) orelse return error.UnknownPrimitive;
        return TypeDescriptor{ .primitive = p };
    } else if (std.mem.eql(u8, kind, "optional")) {
        const inner_ptr = try allocator.create(TypeDescriptor);
        inner_ptr.* = try parseTypeSignatureResolved(allocator, val, record_map, struct_fields_map, enum_variants_map, resolving);
        return TypeDescriptor{ .optional = inner_ptr };
    } else if (std.mem.eql(u8, kind, "array")) {
        const item_val = val.object.get("item") orelse return error.ArrayMissingItem;
        const item_ptr = try allocator.create(TypeDescriptor);
        item_ptr.* = try parseTypeSignatureResolved(allocator, item_val, record_map, struct_fields_map, enum_variants_map, resolving);
        const key_extractor = blk: {
            if (val.object.get("key_extractor")) |ke| break :blk try allocator.dupe(u8, ke.string);
            break :blk try allocator.dupe(u8, "");
        };
        return TypeDescriptor{ .array = .{ .item_type = item_ptr, .key_extractor = key_extractor } };
    } else if (std.mem.eql(u8, kind, "record")) {
        const record_id = val.string;
        const rec = record_map.get(record_id) orelse return error.UnknownRecordId;
        if (resolving.contains(record_id)) {
            switch (rec.kind) {
                .struct_record => return TypeDescriptor{ .struct_record = .{
                    .name = rec.name,
                    .qualified_name = rec.qualified_name,
                    .module_path = rec.module_path,
                    .doc = rec.doc,
                    .removed_numbers = rec.removed_numbers,
                } },
                .enum_record => return TypeDescriptor{ .enum_record = .{
                    .name = rec.name,
                    .qualified_name = rec.qualified_name,
                    .module_path = rec.module_path,
                    .doc = rec.doc,
                    .removed_numbers = rec.removed_numbers,
                } },
            }
        }

        try resolving.put(record_id, {});
        defer _ = resolving.remove(record_id);

        switch (rec.kind) {
            .struct_record => {
                const src_fields = struct_fields_map.get(record_id) orelse &[_]StructField{};
                const fields = try allocator.alloc(StructField, src_fields.len);
                for (src_fields, 0..) |f, i| {
                    var resolved_ft: ?*const TypeDescriptor = null;
                    if (f.field_type) |ft| {
                        const ptr = try allocator.create(TypeDescriptor);
                        ptr.* = try resolveResolvedTypeDescriptor(allocator, ft.*, record_map, struct_fields_map, enum_variants_map, resolving);
                        resolved_ft = ptr;
                    }
                    fields[i] = .{
                        .name = f.name,
                        .number = f.number,
                        .field_type = resolved_ft,
                        .doc = f.doc,
                    };
                }
                return TypeDescriptor{ .struct_record = .{
                    .name = rec.name,
                    .qualified_name = rec.qualified_name,
                    .module_path = rec.module_path,
                    .doc = rec.doc,
                    .fields = fields,
                    .removed_numbers = rec.removed_numbers,
                } };
            },
            .enum_record => {
                const src_variants = enum_variants_map.get(record_id) orelse &[_]EnumVariant{};
                const variants = try allocator.alloc(EnumVariant, src_variants.len);
                for (src_variants, 0..) |variant, i| {
                    switch (variant) {
                        .constant => |c| {
                            variants[i] = .{ .constant = .{
                                .name = c.name,
                                .number = c.number,
                                .doc = c.doc,
                            } };
                        },
                        .wrapper => |w| {
                            var resolved_vt: ?*const TypeDescriptor = null;
                            if (w.variant_type) |vt| {
                                const ptr = try allocator.create(TypeDescriptor);
                                ptr.* = try resolveResolvedTypeDescriptor(allocator, vt.*, record_map, struct_fields_map, enum_variants_map, resolving);
                                resolved_vt = ptr;
                            }
                            variants[i] = .{ .wrapper = .{
                                .name = w.name,
                                .number = w.number,
                                .variant_type = resolved_vt,
                                .doc = w.doc,
                            } };
                        },
                    }
                }
                return TypeDescriptor{ .enum_record = .{
                    .name = rec.name,
                    .qualified_name = rec.qualified_name,
                    .module_path = rec.module_path,
                    .doc = rec.doc,
                    .variants = variants,
                    .removed_numbers = rec.removed_numbers,
                } };
            },
        }
    } else {
        return error.UnknownTypeKind;
    }
}

fn resolveResolvedTypeDescriptor(
    allocator: std.mem.Allocator,
    td: TypeDescriptor,
    record_map: *const std.StringHashMap(ParsedRecord),
    struct_fields_map: *const std.StringHashMap([]StructField),
    enum_variants_map: *const std.StringHashMap([]EnumVariant),
    resolving: *std.StringHashMap(void),
) error{ OutOfMemory, UnknownPrimitive, UnknownTypeKind, UnknownRecordId, MissingValue, ArrayMissingItem, MalformedRecordId, FieldMissingType }!TypeDescriptor {
    switch (td) {
        .primitive => return td,
        .optional => |inner| {
            const ptr = try allocator.create(TypeDescriptor);
            ptr.* = try resolveResolvedTypeDescriptor(allocator, inner.*, record_map, struct_fields_map, enum_variants_map, resolving);
            return TypeDescriptor{ .optional = ptr };
        },
        .array => |arr| {
            const item_ptr = try allocator.create(TypeDescriptor);
            item_ptr.* = try resolveResolvedTypeDescriptor(allocator, arr.item_type.*, record_map, struct_fields_map, enum_variants_map, resolving);
            return TypeDescriptor{ .array = .{ .item_type = item_ptr, .key_extractor = arr.key_extractor } };
        },
        .struct_record => |s| {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("kind", .{ .string = "record" });
            const rid = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ s.module_path, s.qualified_name });
            try obj.put("value", .{ .string = rid });
            return parseTypeSignatureResolved(allocator, .{ .object = obj }, record_map, struct_fields_map, enum_variants_map, resolving);
        },
        .enum_record => |e| {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("kind", .{ .string = "record" });
            const rid = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ e.module_path, e.qualified_name });
            try obj.put("value", .{ .string = rid });
            return parseTypeSignatureResolved(allocator, .{ .object = obj }, record_map, struct_fields_map, enum_variants_map, resolving);
        },
    }
}

fn parseRemovedNumbers(allocator: std.mem.Allocator, rec: std.json.Value) ![]const i32 {
    if (rec.object.get("removed_numbers")) |rn| {
        const arr = rn.array.items;
        const nums = try allocator.alloc(i32, arr.len);
        for (arr, 0..) |item, i| {
            nums[i] = @intCast(item.integer);
        }
        return nums;
    }
    return &[_]i32{};
}

fn getJsonStr(v: std.json.Value, key: []const u8) []const u8 {
    if (v.object.get(key)) |val| {
        if (val == .string) return val.string;
    }
    return "";
}

fn getJsonI32(v: std.json.Value, key: []const u8) i32 {
    if (v.object.get(key)) |val| {
        if (val == .integer) return @intCast(val.integer);
    }
    return 0;
}
