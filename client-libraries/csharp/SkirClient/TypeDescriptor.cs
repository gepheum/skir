// Defines the TypeDescriptor type hierarchy and its JSON round-trip
// serialization.  The JSON format is byte-for-byte identical to the Rust and
// Go implementations so that a descriptor serialized in one language can be
// deserialized in another.

using System.Text.Json;
using System.Text.Json.Nodes;

namespace SkirClient;

// =============================================================================
// PrimitiveType
// =============================================================================

/// <summary>Enumerates all primitive types supported by Skir.</summary>
public enum PrimitiveType
{
    /// <summary>Boolean value.</summary>
    Bool,

    /// <summary>32-bit signed integer.</summary>
    Int32,

    /// <summary>64-bit signed integer.</summary>
    Int64,

    /// <summary>64-bit unsigned hash identifier.</summary>
    Hash64,

    /// <summary>32-bit floating-point number.</summary>
    Float32,

    /// <summary>64-bit floating-point number.</summary>
    Float64,

    /// <summary>Timestamp value.</summary>
    Timestamp,

    /// <summary>UTF-8 string value.</summary>
    String,

    /// <summary>Byte sequence value.</summary>
    Bytes,
}

/// <summary>
/// Internal helpers for converting <see cref="PrimitiveType"/> values to and
/// from their schema string names.
/// </summary>
internal static class PrimitiveTypeHelper
{
    public static string AsString(this PrimitiveType p) =>
        p switch
        {
            PrimitiveType.Bool => "bool",
            PrimitiveType.Int32 => "int32",
            PrimitiveType.Int64 => "int64",
            PrimitiveType.Hash64 => "hash64",
            PrimitiveType.Float32 => "float32",
            PrimitiveType.Float64 => "float64",
            PrimitiveType.Timestamp => "timestamp",
            PrimitiveType.String => "string",
            PrimitiveType.Bytes => "bytes",
            _ => throw new ArgumentOutOfRangeException(nameof(p), p, null),
        };

    public static PrimitiveType FromString(string s) =>
        s switch
        {
            "bool" => PrimitiveType.Bool,
            "int32" => PrimitiveType.Int32,
            "int64" => PrimitiveType.Int64,
            "hash64" => PrimitiveType.Hash64,
            "float32" => PrimitiveType.Float32,
            "float64" => PrimitiveType.Float64,
            "timestamp" => PrimitiveType.Timestamp,
            "string" => PrimitiveType.String,
            "bytes" => PrimitiveType.Bytes,
            _ => throw new ArgumentException($"Unknown primitive type: \"{s}\"", nameof(s)),
        };
}

// =============================================================================
// TypeDescriptor
// =============================================================================

/// <summary>
/// Describes a Skir type.  Concrete subclasses:
/// <see cref="PrimitiveDescriptor"/>, <see cref="OptionalDescriptor"/>,
/// <see cref="ArrayDescriptor"/>, <see cref="StructDescriptor"/>,
/// <see cref="EnumDescriptor"/>.
/// </summary>
public abstract class TypeDescriptor
{
    private protected TypeDescriptor() { }

    /// <summary>
    /// Returns the complete, self-describing JSON representation of this
    /// descriptor, as produced and consumed by <see cref="ParseFromJson(string)"/>.
    /// </summary>
    public string AsJson() => TypeDescriptorJson.Serialize(this);

    /// <summary>
    /// Parses a <see cref="TypeDescriptor"/> from its JSON representation,
    /// as produced by <see cref="AsJson"/>.
    /// </summary>
    public static TypeDescriptor ParseFromJson(string json) =>
        TypeDescriptorJson.Deserialize(json);

    /// <summary>
    /// Parses a <see cref="TypeDescriptor"/> from a <see cref="JsonElement"/>
    /// containing its JSON representation, as produced by <see cref="AsJson"/>.
    /// </summary>
    public static TypeDescriptor ParseFromJson(JsonElement element) =>
        TypeDescriptorJson.Deserialize(element);
}

// =============================================================================
// PrimitiveDescriptor
// =============================================================================

/// <summary>Describes a Skir primitive type.</summary>
public sealed class PrimitiveDescriptor : TypeDescriptor
{
    /// <summary>The primitive type represented by this descriptor.</summary>
    public PrimitiveType PrimitiveType { get; }

    public PrimitiveDescriptor(PrimitiveType primitiveType) =>
        PrimitiveType = primitiveType;

    /// <summary>
    /// Backward-compatible constructor that accepts a type-name string
    /// (e.g. <c>"bool"</c>, <c>"int32"</c>).
    /// </summary>
    public PrimitiveDescriptor(string typeName)
        : this(PrimitiveTypeHelper.FromString(typeName)) { }
}

// =============================================================================
// OptionalDescriptor
// =============================================================================

/// <summary>Describes an optional (nullable) Skir type.</summary>
public sealed class OptionalDescriptor : TypeDescriptor
{
    /// <summary>The non-null type that the optional may contain.</summary>
    public TypeDescriptor OtherType { get; }

    public OptionalDescriptor(TypeDescriptor otherType) => OtherType = otherType;

    // Backward-compat alias used by existing Serializers code.
    public TypeDescriptor ItemDescriptor => OtherType;
}

// =============================================================================
// ArrayDescriptor
// =============================================================================

/// <summary>Describes an ordered collection of elements of a single Skir type.</summary>
public sealed class ArrayDescriptor : TypeDescriptor
{
    /// <summary>The type of each element in the array.</summary>
    public TypeDescriptor ItemType { get; }

    /// <summary>
    /// The key extractor string (e.g. <c>"id"</c> or <c>"address.zip"</c>),
    /// or an empty string if none.
    /// </summary>
    public string KeyExtractor { get; }

    public ArrayDescriptor(TypeDescriptor itemType, string keyExtractor = "") =>
        (ItemType, KeyExtractor) = (itemType, keyExtractor ?? string.Empty);

    // Backward-compat alias used by existing Serializers code.
    public TypeDescriptor ItemDescriptor => ItemType;
}

// =============================================================================
// StructField
// =============================================================================

/// <summary>Describes a single field of a Skir struct.</summary>
public sealed class StructField
{
    /// <summary>Field name.</summary>
    public string Name { get; }

    /// <summary>Numeric field identifier.</summary>
    public int Number { get; }

    /// <summary>Field type descriptor.</summary>
    public TypeDescriptor FieldType { get; }

    /// <summary>Field documentation text from the schema.</summary>
    public string Doc { get; }

    /// <summary>Creates a struct-field descriptor.</summary>
    public StructField(string name, int number, TypeDescriptor fieldType, string doc = "") =>
        (Name, Number, FieldType, Doc) = (name, number, fieldType, doc ?? string.Empty);
}

// =============================================================================
// EnumVariant
// =============================================================================

/// <summary>
/// A Skir enum variant.  Either a <see cref="EnumConstantVariant"/>
/// (no wrapped value) or a <see cref="EnumWrapperVariant"/> (wraps a value).
/// </summary>
public abstract class EnumVariant
{
    /// <summary>Variant name.</summary>
    public abstract string Name { get; }

    /// <summary>Numeric variant identifier.</summary>
    public abstract int Number { get; }

    /// <summary>Variant documentation text from the schema.</summary>
    public abstract string Doc { get; }

    /// <summary>The wrapped type, or <c>null</c> for constant variants.</summary>
    public abstract TypeDescriptor? VariantType { get; }
}

/// <summary>A constant (non-wrapping) Skir enum variant.</summary>
public sealed class EnumConstantVariant : EnumVariant
{
    public override string Name { get; }
    public override int Number { get; }
    public override string Doc { get; }
    public override TypeDescriptor? VariantType => null;

    /// <summary>Creates a constant-variant descriptor.</summary>
    public EnumConstantVariant(string name, int number, string doc = "") =>
        (Name, Number, Doc) = (name, number, doc ?? string.Empty);
}

/// <summary>A Skir enum variant that wraps a value of a specific type.</summary>
public sealed class EnumWrapperVariant : EnumVariant
{
    public override string Name { get; }
    public override int Number { get; }
    public override TypeDescriptor? VariantType { get; }
    public override string Doc { get; }

    /// <summary>Creates a wrapper-variant descriptor.</summary>
    public EnumWrapperVariant(
        string name,
        int number,
        TypeDescriptor variantType,
        string doc = ""
    ) => (Name, Number, VariantType, Doc) = (name, number, variantType, doc ?? string.Empty);
}

// =============================================================================
// StructDescriptor
// =============================================================================

/// <summary>Describes a Skir struct type.</summary>
public sealed class StructDescriptor : TypeDescriptor
{
    /// <summary>The simple name (last component of <see cref="QualifiedName"/>).</summary>
    public string Name { get; }

    /// <summary>
    /// The fully-qualified name within a module, e.g. <c>"Foo.Bar"</c> when
    /// <c>Bar</c> is nested inside <c>Foo</c>, or simply <c>"Bar"</c> for a
    /// top-level struct.
    /// </summary>
    public string QualifiedName { get; }

    /// <summary>Path to the <c>.skir</c> file relative to the skir source root.</summary>
    public string ModulePath { get; }

    /// <summary>Documentation extracted from doc comments in the <c>.skir</c> file.</summary>
    public string Doc { get; }

    /// <summary>Field numbers that have been marked as removed (reserved).</summary>
    public IReadOnlySet<int> RemovedNumbers =>
        _removedNumbers ?? (IReadOnlySet<int>)_emptySet;

    /// <summary>All fields declared in this struct.</summary>
    public IReadOnlyList<StructField> Fields =>
        _fields
        ?? throw new InvalidOperationException(
            $"StructDescriptor '{RecordId}' fields have not been initialized."
        );

    /// <summary>Identifier used in JSON: <c>modulePath:qualifiedName</c>.</summary>
    public string RecordId => $"{ModulePath}:{QualifiedName}";

    private IReadOnlySet<int>? _removedNumbers;
    private IReadOnlyList<StructField>? _fields;
    private static readonly HashSet<int> _emptySet = [];

    /// <summary>Creates a fully-initialized struct descriptor.</summary>
    public StructDescriptor(
        string modulePath,
        string qualifiedName,
        string doc,
        IReadOnlySet<int> removedNumbers,
        IReadOnlyList<StructField> fields
    )
    {
        var dot = qualifiedName.LastIndexOf('.');
        Name = dot >= 0 ? qualifiedName[(dot + 1)..] : qualifiedName;
        QualifiedName = qualifiedName;
        ModulePath = modulePath ?? string.Empty;
        Doc = doc ?? string.Empty;
        _removedNumbers = removedNumbers;
        _fields = fields;
    }

    /// <summary>
    /// Creates an uninitialized stub for the two-phase JSON parser.
    /// Call <see cref="SetFields"/> and <see cref="SetRemovedNumbers"/> to complete.
    /// </summary>
    internal StructDescriptor(string modulePath, string qualifiedName, string doc)
    {
        var dot = qualifiedName.LastIndexOf('.');
        Name = dot >= 0 ? qualifiedName[(dot + 1)..] : qualifiedName;
        QualifiedName = qualifiedName;
        ModulePath = modulePath ?? string.Empty;
        Doc = doc ?? string.Empty;
    }

    internal void SetFields(IReadOnlyList<StructField> fields) => _fields = fields;

    internal void SetRemovedNumbers(IReadOnlySet<int> removed) => _removedNumbers = removed;

    /// <summary>Returns the field with the given name, or <c>null</c> if not found.</summary>
    public StructField? FieldByName(string name) => Fields.FirstOrDefault(f => f.Name == name);

    /// <summary>Returns the field with the given number, or <c>null</c> if not found.</summary>
    public StructField? FieldByNumber(int number) => Fields.FirstOrDefault(f => f.Number == number);
}

// =============================================================================
// EnumDescriptor
// =============================================================================

/// <summary>Describes a Skir enum type.</summary>
public sealed class EnumDescriptor : TypeDescriptor
{
    /// <summary>The simple name (last component of <see cref="QualifiedName"/>).</summary>
    public string Name { get; }

    /// <summary>The fully-qualified name within a module.</summary>
    public string QualifiedName { get; }

    /// <summary>Path to the <c>.skir</c> file relative to the skir source root.</summary>
    public string ModulePath { get; }

    /// <summary>Documentation extracted from doc comments in the <c>.skir</c> file.</summary>
    public string Doc { get; }

    /// <summary>Variant numbers that have been marked as removed (reserved).</summary>
    public IReadOnlySet<int> RemovedNumbers =>
        _removedNumbers ?? (IReadOnlySet<int>)_emptySet;

    /// <summary>All variants declared in this enum.</summary>
    public IReadOnlyList<EnumVariant> Variants =>
        _variants
        ?? throw new InvalidOperationException(
            $"EnumDescriptor '{RecordId}' variants have not been initialized."
        );

    /// <summary>Identifier used in JSON: <c>modulePath:qualifiedName</c>.</summary>
    public string RecordId => $"{ModulePath}:{QualifiedName}";

    private IReadOnlySet<int>? _removedNumbers;
    private IReadOnlyList<EnumVariant>? _variants;
    private static readonly HashSet<int> _emptySet = [];

    /// <summary>Creates a fully-initialized enum descriptor.</summary>
    public EnumDescriptor(
        string modulePath,
        string qualifiedName,
        string doc,
        IReadOnlySet<int> removedNumbers,
        IReadOnlyList<EnumVariant> variants
    )
    {
        var dot = qualifiedName.LastIndexOf('.');
        Name = dot >= 0 ? qualifiedName[(dot + 1)..] : qualifiedName;
        QualifiedName = qualifiedName;
        ModulePath = modulePath ?? string.Empty;
        Doc = doc ?? string.Empty;
        _removedNumbers = removedNumbers;
        _variants = variants;
    }

    /// <summary>
    /// Creates an uninitialized stub for the two-phase JSON parser.
    /// Call <see cref="SetVariants"/> and <see cref="SetRemovedNumbers"/> to complete.
    /// </summary>
    internal EnumDescriptor(string modulePath, string qualifiedName, string doc)
    {
        var dot = qualifiedName.LastIndexOf('.');
        Name = dot >= 0 ? qualifiedName[(dot + 1)..] : qualifiedName;
        QualifiedName = qualifiedName;
        ModulePath = modulePath ?? string.Empty;
        Doc = doc ?? string.Empty;
    }

    internal void SetVariants(IReadOnlyList<EnumVariant> variants) => _variants = variants;

    internal void SetRemovedNumbers(IReadOnlySet<int> removed) => _removedNumbers = removed;

    /// <summary>Returns the variant with the given name, or <c>null</c> if not found.</summary>
    public EnumVariant? VariantByName(string name) =>
        Variants.FirstOrDefault(v => v.Name == name);

    /// <summary>Returns the variant with the given number, or <c>null</c> if not found.</summary>
    public EnumVariant? VariantByNumber(int number) =>
        Variants.FirstOrDefault(v => v.Number == number);
}

// =============================================================================
// JSON serialization / deserialization  (internal implementation)
// =============================================================================

/// <summary>
/// Internal JSON round-trip implementation for <see cref="TypeDescriptor"/>.
/// </summary>
internal static class TypeDescriptorJson
{
    private static readonly JsonSerializerOptions IndentedOptions = new() { WriteIndented = true };

    // ── Serialization ─────────────────────────────────────────────────────────

    public static string Serialize(TypeDescriptor td)
    {
        var order = new List<string>();
        var seen = new Dictionary<string, JsonObject>();
        CollectRecords(td, order, seen);

        var records = new JsonArray();
        foreach (var id in order)
            records.Add(seen[id]);

        var root = new JsonObject { ["type"] = TypeSignatureToNode(td), ["records"] = records };
        return root.ToJsonString(IndentedOptions);
    }

    private static void CollectRecords(
        TypeDescriptor td,
        List<string> order,
        Dictionary<string, JsonObject> seen
    )
    {
        switch (td)
        {
            case PrimitiveDescriptor:
                return;
            case OptionalDescriptor opt:
                CollectRecords(opt.OtherType, order, seen);
                return;
            case ArrayDescriptor arr:
                CollectRecords(arr.ItemType, order, seen);
                return;
            case StructDescriptor s:
                {
                    var rid = s.RecordId;
                    if (seen.ContainsKey(rid))
                        return; // already visited or cycle guard
                    seen[rid] = new JsonObject(); // placeholder to break cycles
                    seen[rid] = StructRecordToNode(s);
                    order.Add(rid);
                    foreach (var f in s.Fields)
                        CollectRecords(f.FieldType, order, seen);
                    return;
                }
            case EnumDescriptor e:
                {
                    var rid = e.RecordId;
                    if (seen.ContainsKey(rid))
                        return;
                    seen[rid] = new JsonObject();
                    seen[rid] = EnumRecordToNode(e);
                    order.Add(rid);
                    foreach (var v in e.Variants)
                        if (v.VariantType is { } vt)
                            CollectRecords(vt, order, seen);
                    return;
                }
        }
    }

    private static JsonObject StructRecordToNode(StructDescriptor s)
    {
        var obj = new JsonObject { ["kind"] = "struct", ["id"] = s.RecordId };
        if (s.Doc.Length > 0)
            obj["doc"] = s.Doc;

        var fields = new JsonArray();
        foreach (var f in s.Fields)
        {
            var fNode = new JsonObject
            {
                ["name"] = f.Name,
                ["number"] = f.Number,
                ["type"] = TypeSignatureToNode(f.FieldType),
            };
            if (f.Doc.Length > 0)
                fNode["doc"] = f.Doc;
            fields.Add(fNode);
        }
        obj["fields"] = fields;

        var removed = s.RemovedNumbers.OrderBy(n => n).ToList();
        if (removed.Count > 0)
        {
            var arr = new JsonArray();
            foreach (var n in removed)
                arr.Add(n);
            obj["removed_numbers"] = arr;
        }
        return obj;
    }

    private static JsonObject EnumRecordToNode(EnumDescriptor e)
    {
        var obj = new JsonObject { ["kind"] = "enum", ["id"] = e.RecordId };
        if (e.Doc.Length > 0)
            obj["doc"] = e.Doc;

        var variants = new JsonArray();
        foreach (var v in e.Variants.OrderBy(v => v.Number))
        {
            var vNode = new JsonObject { ["name"] = v.Name, ["number"] = v.Number };
            if (v.VariantType is { } vt)
                vNode["type"] = TypeSignatureToNode(vt);
            if (v.Doc.Length > 0)
                vNode["doc"] = v.Doc;
            variants.Add(vNode);
        }
        obj["variants"] = variants;

        var removed = e.RemovedNumbers.OrderBy(n => n).ToList();
        if (removed.Count > 0)
        {
            var arr = new JsonArray();
            foreach (var n in removed)
                arr.Add(n);
            obj["removed_numbers"] = arr;
        }
        return obj;
    }

    private static JsonObject TypeSignatureToNode(TypeDescriptor td)
    {
        switch (td)
        {
            case PrimitiveDescriptor prim:
                return new JsonObject
                {
                    ["kind"] = "primitive",
                    ["value"] = prim.PrimitiveType.AsString(),
                };
            case OptionalDescriptor opt:
                return new JsonObject
                {
                    ["kind"] = "optional",
                    ["value"] = TypeSignatureToNode(opt.OtherType),
                };
            case ArrayDescriptor arr:
                {
                    var valueObj = new JsonObject { ["item"] = TypeSignatureToNode(arr.ItemType) };
                    if (arr.KeyExtractor.Length > 0)
                        valueObj["key_extractor"] = arr.KeyExtractor;
                    return new JsonObject { ["kind"] = "array", ["value"] = valueObj };
                }
            case StructDescriptor s:
                return new JsonObject { ["kind"] = "record", ["value"] = s.RecordId };
            case EnumDescriptor e:
                return new JsonObject { ["kind"] = "record", ["value"] = e.RecordId };
            default:
                throw new InvalidOperationException(
                    $"Unknown TypeDescriptor subtype: {td.GetType()}"
                );
        }
    }

    // ── Deserialization ────────────────────────────────────────────────────────

    public static TypeDescriptor Deserialize(string json)
    {
        var root =
            JsonNode.Parse(json)?.AsObject()
            ?? throw new FormatException("TypeDescriptor JSON must be a JSON object.");
        return ParseFromValue(root);
    }

    public static TypeDescriptor Deserialize(JsonElement element)
    {
        var root =
            JsonObject.Create(element)
            ?? throw new FormatException("TypeDescriptor JSON must be a JSON object.");
        return ParseFromValue(root);
    }

    private static TypeDescriptor ParseFromValue(JsonObject root)
    {
        // ── Pass 1: create stub descriptors (without fields / variants) ───────
        //   The stubs are the FINAL objects; fields are set in-place in pass 2.
        //   This lets forward references and mutual recursion work correctly.
        var idToDescriptor = new Dictionary<string, TypeDescriptor>();
        var records = root["records"]?.AsArray() ?? [];

        foreach (var recNode in records)
        {
            var rec = recNode!.AsObject();
            var kind = GetStr(rec, "kind");
            var id = GetStr(rec, "id");
            var doc = GetStr(rec, "doc");
            var (modulePath, qualifiedName) = SplitRecordId(id);

            TypeDescriptor stub = kind switch
            {
                "struct" => new StructDescriptor(modulePath, qualifiedName, doc),
                "enum" => new EnumDescriptor(modulePath, qualifiedName, doc),
                _ => throw new FormatException($"Unknown record kind: \"{kind}\""),
            };
            idToDescriptor[id] = stub;
        }

        // ── Pass 2: fill in fields / variants ─────────────────────────────────
        foreach (var recNode in records)
        {
            var rec = recNode!.AsObject();
            var id = GetStr(rec, "id");
            var removedNumbers = ParseRemovedNumbers(rec);
            var descriptor = idToDescriptor[id];

            switch (descriptor)
            {
                case StructDescriptor s:
                    {
                        s.SetRemovedNumbers(removedNumbers);
                        var fields = new List<StructField>();
                        foreach (var fNode in rec["fields"]?.AsArray() ?? [])
                        {
                            var f = fNode!.AsObject();
                            var name = GetStr(f, "name");
                            var number = GetInt(f["number"]);
                            var typeObj =
                                f["type"]?.AsObject()
                                ?? throw new FormatException(
                                    $"Struct field \"{name}\" is missing \"type\"."
                                );
                            var fieldType = ParseTypeSignature(typeObj, idToDescriptor);
                            var fDoc = GetStr(f, "doc");
                            fields.Add(new StructField(name, number, fieldType, fDoc));
                        }
                        s.SetFields(fields);
                        break;
                    }
                case EnumDescriptor e:
                    {
                        e.SetRemovedNumbers(removedNumbers);
                        var variants = new List<EnumVariant>();
                        foreach (var vNode in rec["variants"]?.AsArray() ?? [])
                        {
                            var v = vNode!.AsObject();
                            var name = GetStr(v, "name");
                            var number = GetInt(v["number"]);
                            var vDoc = GetStr(v, "doc");
                            if (v["type"]?.AsObject() is { } typeObj)
                            {
                                var vType = ParseTypeSignature(typeObj, idToDescriptor);
                                variants.Add(new EnumWrapperVariant(name, number, vType, vDoc));
                            }
                            else
                            {
                                variants.Add(new EnumConstantVariant(name, number, vDoc));
                            }
                        }
                        e.SetVariants(variants);
                        break;
                    }
            }
        }

        // ── Resolve the root type signature ───────────────────────────────────
        var typeObj2 =
            root["type"]?.AsObject()
            ?? throw new FormatException("TypeDescriptor JSON is missing \"type\".");
        return ParseTypeSignature(typeObj2, idToDescriptor);
    }

    private static TypeDescriptor ParseTypeSignature(
        JsonObject v,
        Dictionary<string, TypeDescriptor> records
    )
    {
        var kind = GetStr(v, "kind");
        var val =
            v["value"]
            ?? throw new FormatException(
                $"Type signature is missing \"value\" (kind=\"{kind}\")."
            );

        switch (kind)
        {
            case "primitive":
                return new PrimitiveDescriptor(
                    PrimitiveTypeHelper.FromString(val.GetValue<string>())
                );
            case "optional":
                return new OptionalDescriptor(
                    ParseTypeSignature(val.AsObject(), records)
                );
            case "array":
                {
                    var valObj = val.AsObject();
                    var itemObj =
                        valObj["item"]?.AsObject()
                        ?? throw new FormatException("Array type signature is missing \"item\".");
                    var item = ParseTypeSignature(itemObj, records);
                    var key = valObj["key_extractor"]?.GetValue<string>() ?? string.Empty;
                    return new ArrayDescriptor(item, key);
                }
            case "record":
                {
                    var recordId = val.GetValue<string>();
                    return records.TryGetValue(recordId, out var desc)
                        ? desc
                        : throw new FormatException($"Unknown record id \"{recordId}\".");
                }
            default:
                throw new FormatException($"Unknown type kind: \"{kind}\".");
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static string GetStr(JsonObject obj, string key) =>
        obj[key]?.GetValue<string>() ?? string.Empty;

    private static int GetInt(JsonNode? node)
    {
        if (node is null)
            return 0;
        // JSON numbers may be deserialized as long; cast to int.
        return (int)node.GetValue<long>();
    }

    private static HashSet<int> ParseRemovedNumbers(JsonObject obj)
    {
        var set = new HashSet<int>();
        if (obj["removed_numbers"]?.AsArray() is { } arr)
            foreach (var n in arr)
                if (n is not null)
                    set.Add((int)n.GetValue<long>());
        return set;
    }

    private static (string modulePath, string qualifiedName) SplitRecordId(string id)
    {
        var colon = id.IndexOf(':');
        if (colon < 0)
            throw new FormatException(
                $"Malformed record id \"{id}\" (expected \"modulePath:qualifiedName\")."
            );
        return (id[..colon], id[(colon + 1)..]);
    }
}
