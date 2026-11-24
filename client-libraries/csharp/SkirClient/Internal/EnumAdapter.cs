using System.Text;
using System.Text.Json;

namespace SkirClient.Internal;

public sealed class EnumAdapter<T> : ITypeAdapter<T> where T : class
{
    // ---- per-variant type-erased interface ---------------------------------

    private interface IVariantEntry
    {
        string Name { get; }
        int Number { get; }
        string Doc { get; }
        TypeDescriptor? VariantType { get; }
        /// <summary>Returns the constant instance, or null for wrapper variants.</summary>
        T? Constant { get; }
        void ToJson(T value, string? eolIndent, StringBuilder sb);
        void Encode(T value, List<byte> output);
        T WrapFromJson(JsonElement json, bool keep);
        T DecodeWrap(byte[] data, ref int offset, bool keep);
    }

    private sealed class ConstantEntry(string name, int number, string doc, T instance) : IVariantEntry
    {
        public string Name => name;
        public int Number => number;
        public string Doc => doc;
        public TypeDescriptor? VariantType => null;
        public T? Constant => instance;

        public void ToJson(T value, string? eolIndent, StringBuilder sb)
        {
            if (eolIndent != null)
                Serializers.WriteJsonString_(name, sb);
            else
                sb.Append(number);
        }

        public void Encode(T value, List<byte> output) =>
            Serializers.EncodeUint32_((uint)number, output);

        public T WrapFromJson(JsonElement json, bool keep) =>
            throw new InvalidOperationException($"Variant '{name}' is a constant, not a wrapper.");

        public T DecodeWrap(byte[] data, ref int offset, bool keep) =>
            throw new InvalidOperationException($"Variant '{name}' is a constant, not a wrapper.");
    }

    private sealed class WrapperEntry<V>(
        string name, int number, string doc, ITypeAdapter<V> adapter,
        Func<V, T> wrap, Func<T, V> getValue) : IVariantEntry
    {
        public string Name => name;
        public int Number => number;
        public string Doc => doc;
        public TypeDescriptor? VariantType => adapter.TypeDescriptor;
        public T? Constant => null;

        public void ToJson(T value, string? eolIndent, StringBuilder sb)
        {
            V payload = getValue(value);
            if (eolIndent != null)
            {
                string childIndent = eolIndent + "  ";
                sb.Append('{');
                sb.Append(childIndent);
                sb.Append("\"kind\": ");
                Serializers.WriteJsonString_(name, sb);
                sb.Append(',');
                sb.Append(childIndent);
                sb.Append("\"value\": ");
                adapter.ToJson(payload, childIndent, sb);
                sb.Append(eolIndent);
                sb.Append('}');
            }
            else
            {
                sb.Append('[');
                sb.Append(number);
                sb.Append(',');
                adapter.ToJson(payload, null, sb);
                sb.Append(']');
            }
        }

        public void Encode(T value, List<byte> output)
        {
            // Write wrapper header
            if (number >= 1 && number <= 4)
                output.Add((byte)(250 + number));
            else
            {
                output.Add(248);
                Serializers.EncodeUint32_((uint)number, output);
            }
            // Write payload
            adapter.Encode(getValue(value), output);
        }

        public T WrapFromJson(JsonElement json, bool keep) =>
            wrap(adapter.FromJson(json, keep));

        public T DecodeWrap(byte[] data, ref int offset, bool keep) =>
            wrap(adapter.Decode(data, ref offset, keep));
    }

    // ---- entry lookup bookkeeping ------------------------------------------

    private enum EntryKind { Removed, Constant, Wrapper }
    private readonly record struct AnyEntry(EntryKind Kind, int KindOrdinal);

    // ---- state -------------------------------------------------------------

    private readonly Func<T, int> _getKindOrdinal;
    private readonly Func<UnrecognizedVariant<T>, T> _wrapUnrecognized;
    private readonly Func<T, UnrecognizedVariant<T>?> _getUnrecognized;
    private readonly T _default;
    private readonly string _modulePath;
    private readonly string _qualifiedName;

    private readonly Dictionary<int, AnyEntry> _numberToEntry = [];
    private readonly Dictionary<string, int> _nameToKindOrdinal = [];
    // Index 0 = UNKNOWN (always null entry)
    private readonly List<IVariantEntry?> _kindOrdinalToEntry = [null];
    private readonly HashSet<int> _removedNumbers = [];
    private readonly EnumDescriptor _descriptor;

    /// <summary>Creates an enum adapter used by generated enum serializers.</summary>
    public EnumAdapter(
        Func<T, int> getKindOrdinal,
        Func<UnrecognizedVariant<T>, T> wrapUnrecognized,
        Func<T, UnrecognizedVariant<T>?> getUnrecognized,
        T defaultValue,
        string modulePath,
        string qualifiedName,
        string enumDoc)
    {
        _getKindOrdinal = getKindOrdinal;
        _wrapUnrecognized = wrapUnrecognized;
        _getUnrecognized = getUnrecognized;
        _default = defaultValue;
        _modulePath = modulePath;
        _qualifiedName = qualifiedName;
        _descriptor = new EnumDescriptor(modulePath, qualifiedName, enumDoc);
    }

    // ---- builder -----------------------------------------------------------

    /// <summary>Registers a constant enum variant.</summary>
    public void AddConstantVariant(string name, int number, int kindOrdinal, T instance, string doc = "")
    {
        _numberToEntry[number] = new AnyEntry(EntryKind.Constant, kindOrdinal);
        _nameToKindOrdinal[name] = kindOrdinal;
        var upper = name.ToUpperInvariant();
        if (upper != name) _nameToKindOrdinal[upper] = kindOrdinal;
        var lower = name.ToLowerInvariant();
        if (lower != name) _nameToKindOrdinal[lower] = kindOrdinal;
        while (_kindOrdinalToEntry.Count <= kindOrdinal) _kindOrdinalToEntry.Add(null);
        _kindOrdinalToEntry[kindOrdinal] = new ConstantEntry(name, number, doc, instance);
    }

    /// <summary>Registers a wrapper enum variant.</summary>
    public void AddWrapperVariant<V>(string name, int number, int kindOrdinal,
        Serializer<V> serializer, Func<V, T> wrap, Func<T, V> getValue, string doc = "")
    {
        _numberToEntry[number] = new AnyEntry(EntryKind.Wrapper, kindOrdinal);
        _nameToKindOrdinal[name] = kindOrdinal;
        var upper = name.ToUpperInvariant();
        if (upper != name) _nameToKindOrdinal[upper] = kindOrdinal;
        while (_kindOrdinalToEntry.Count <= kindOrdinal) _kindOrdinalToEntry.Add(null);
        _kindOrdinalToEntry[kindOrdinal] = new WrapperEntry<V>(name, number, doc, serializer.Adapter, wrap, getValue);
    }

    /// <summary>Marks a variant number as removed.</summary>
    public void AddRemovedNumber(int number)
    {
        _numberToEntry[number] = new AnyEntry(EntryKind.Removed, 0);
        _removedNumbers.Add(number);
    }

    /// <summary>Finalizes registration and freezes lookup tables.</summary>
    public void Finalize_()
    {
        _nameToKindOrdinal["UNKNOWN"] = 0;
        _nameToKindOrdinal["unknown"] = 0;

        var variants = new List<EnumVariant>();
        for (int ko = 1; ko < _kindOrdinalToEntry.Count; ko++)
        {
            if (_kindOrdinalToEntry[ko] is IVariantEntry entry)
            {
                if (entry.Constant != null)
                    variants.Add(new EnumConstantVariant(entry.Name, entry.Number, entry.Doc));
                else if (entry.VariantType != null)
                    variants.Add(new EnumWrapperVariant(entry.Name, entry.Number, entry.VariantType, entry.Doc));
            }
        }
        variants.Sort((a, b) => a.Number.CompareTo(b.Number));
        _descriptor.SetVariants(variants);
        _descriptor.SetRemovedNumbers(_removedNumbers);
    }

    public TypeDescriptor TypeDescriptor => _descriptor;

    public Serializer<T> ToSerializer() => new(this);

    public bool IsDefault(T value) => _getKindOrdinal(value) == 0;

    public void ToJson(T value, string? eolIndent, StringBuilder output) =>
        ToJsonImpl(value, eolIndent, output);

    public T FromJson(JsonElement json, bool keepUnrecognized) =>
        FromJsonImpl(json, keepUnrecognized);

    public void Encode(T value, List<byte> output) =>
        EncodeImpl(value, output);

    public T Decode(byte[] data, ref int offset, bool keepUnrecognized) =>
        DecodeImpl(data, ref offset, keepUnrecognized);

    // ---- JSON impl ---------------------------------------------------------

    private void ToJsonImpl(T value, string? eolIndent, StringBuilder sb)
    {
        int ko = _getKindOrdinal(value);
        if (ko == 0)
        {
            UnrecognizedToJson(value, eolIndent, sb);
            return;
        }
        if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
            entry.ToJson(value, eolIndent, sb);
        else
            sb.Append(eolIndent != null ? "\"unknown\"" : "0");
    }

    private void UnrecognizedToJson(T value, string? eolIndent, StringBuilder sb)
    {
        if (eolIndent != null) { sb.Append("\"unknown\""); return; }
        var u = _getUnrecognized(value);
        if (u != null && u.Format == UnrecognizedFormat.DenseJson && u.Value.Length > 0)
        {
            sb.Append(Encoding.UTF8.GetString(u.Value));
            return;
        }
        sb.Append('0');
    }

    private T UnknownFromJson(int number) =>
        _wrapUnrecognized(UnrecognizedVariant<T>.FromJson(number, Array.Empty<byte>()));

    private T UnknownFromBytes(int number) =>
        _wrapUnrecognized(UnrecognizedVariant<T>.FromBytes(number, Array.Empty<byte>()));

    private T FromJsonImpl(JsonElement json, bool keep)
    {
        switch (json.ValueKind)
        {
            case JsonValueKind.Number:
                {
                    int num = json.TryGetInt32(out int i) ? i : (int)json.GetDouble();
                    return ResolveConstantLookup(num, keep, json);
                }
            case JsonValueKind.True:
                return ResolveConstantLookup(1, keep, json);
            case JsonValueKind.False:
                return ResolveConstantLookup(0, keep, json);
            case JsonValueKind.String:
                {
                    string s = json.GetString()!;
                    if (!_nameToKindOrdinal.TryGetValue(s, out int ko))
                        return UnknownFromJson(0);
                    if (ko == 0) return UnknownFromJson(0);
                    if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
                    {
                        if (entry.Constant is T c) return c;
                        // Constant-context for a wrapper: return default payload wrapped
                        return _default;
                    }
                    return _default;
                }
            case JsonValueKind.Array when json.GetArrayLength() == 2:
                {
                    var arr = json.EnumerateArray().ToArray();
                    int num = arr[0].TryGetInt32(out int i) ? i : (int)arr[0].GetDouble();
                    return ResolveWrapperFromJson(num, arr[1], keep, json);
                }
            case JsonValueKind.Object:
                {
                    string kindName = json.TryGetProperty("kind", out var kp) && kp.ValueKind == JsonValueKind.String
                        ? kp.GetString()! : "";
                    var valJson = json.TryGetProperty("value", out var vp) ? vp : default;
                    if (!_nameToKindOrdinal.TryGetValue(kindName, out int ko))
                        return UnknownFromJson(0);
                    if (ko == 0) return UnknownFromJson(0);
                    if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
                    {
                        if (entry.Constant is T c) return c;
                        if (valJson.ValueKind != JsonValueKind.Undefined)
                            return entry.WrapFromJson(valJson, keep);
                    }
                    return _default;
                }
            default:
                return _default;
        }
    }

    private T ResolveConstantLookup(int number, bool keep, JsonElement rawJson)
    {
        if (!_numberToEntry.TryGetValue(number, out var ae))
        {
            if (keep)
            {
                byte[] bytes = Encoding.UTF8.GetBytes(rawJson.GetRawText());
                return _wrapUnrecognized(UnrecognizedVariant<T>.FromJson(number, bytes));
            }
            return UnknownFromJson(number);
        }
        if (ae.Kind == EntryKind.Removed) return _default;
        var ko = ae.KindOrdinal;
        if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
        {
            if (entry.Constant is T c) return c;
            // Wrapper encountered in constant context: return its default payload
            var defaultJson = JsonDocument.Parse("0").RootElement;
            try { return entry.WrapFromJson(defaultJson, false); } catch { return _default; }
        }
        return _default;
    }

    private T ResolveWrapperFromJson(int number, JsonElement payloadJson, bool keep, JsonElement rawJson)
    {
        if (!_numberToEntry.TryGetValue(number, out var ae))
        {
            if (keep)
            {
                byte[] bytes = Encoding.UTF8.GetBytes(rawJson.GetRawText());
                return _wrapUnrecognized(UnrecognizedVariant<T>.FromJson(number, bytes));
            }
            return UnknownFromJson(number);
        }
        if (ae.Kind == EntryKind.Removed) return _default;
        var ko = ae.KindOrdinal;
        if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
        {
            if (entry.Constant is T c) return c;
            return entry.WrapFromJson(payloadJson, keep);
        }
        return _default;
    }

    // ---- Binary encode / decode --------------------------------------------

    private void EncodeImpl(T value, List<byte> output)
    {
        int ko = _getKindOrdinal(value);
        if (ko == 0)
        {
            var u = _getUnrecognized(value);
            if (u != null && u.Format == UnrecognizedFormat.BinaryBytes && u.Value.Length > 0)
            {
                output.AddRange(u.Value);
                return;
            }
            output.Add(0);
            return;
        }
        if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
            entry.Encode(value, output);
        else
            output.Add(0);
    }

    private T DecodeImpl(byte[] data, ref int offset, bool keep)
    {
        if (offset >= data.Length) return _default;
        byte wire = Serializers.ReadU8_(data, ref offset);

        if (wire < 242)
        {
            // Constant variant: decode number from wire bytes
            long n = Serializers.DecodeNumberBody_(wire, data, ref offset);
            return ResolveConstantFromBytes((int)n, keep);
        }

        // Wrapper variant
        int number;
        if (wire == 248)
            number = (int)Serializers.DecodeNumber(data, ref offset);
        else if (wire >= 251 && wire <= 254)
            number = wire - 250;
        else
            return _default; // invalid/reserved wire byte

        if (!_numberToEntry.TryGetValue(number, out var ae))
        {
            if (keep)
            {
                // Capture header + payload bytes for round-trip
                var header = new List<byte>();
                if (number >= 1 && number <= 4)
                    header.Add((byte)(250 + number));
                else
                {
                    header.Add(248);
                    Serializers.EncodeUint32_((uint)number, header);
                }
                int before = offset;
                Serializers.SkipValue_(data, ref offset);
                int consumed = offset - before;
                byte[] allBytes = [.. header, .. data[before..offset]];
                return _wrapUnrecognized(UnrecognizedVariant<T>.FromBytes(number, allBytes));
            }
            Serializers.SkipValue_(data, ref offset);
            return UnknownFromBytes(number);
        }

        if (ae.Kind == EntryKind.Removed)
        {
            Serializers.SkipValue_(data, ref offset);
            return _default;
        }

        var kindOrdinal = ae.KindOrdinal;
        if (kindOrdinal < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[kindOrdinal] is IVariantEntry resolvedEntry)
        {
            if (resolvedEntry.Constant is T c)
            {
                Serializers.SkipValue_(data, ref offset);
                return c;
            }
            return resolvedEntry.DecodeWrap(data, ref offset, keep);
        }
        Serializers.SkipValue_(data, ref offset);
        return _default;
    }

    private T ResolveConstantFromBytes(int number, bool keep)
    {
        if (!_numberToEntry.TryGetValue(number, out var ae))
        {
            if (keep)
            {
                var buf = new List<byte>();
                Serializers.EncodeUint32_((uint)number, buf);
                return _wrapUnrecognized(UnrecognizedVariant<T>.FromBytes(number, [.. buf]));
            }
            return UnknownFromBytes(number);
        }
        if (ae.Kind == EntryKind.Removed) return _default;
        var ko = ae.KindOrdinal;
        if (ko < _kindOrdinalToEntry.Count && _kindOrdinalToEntry[ko] is IVariantEntry entry)
        {
            if (entry.Constant is T c) return c;
            // Wrapper in constant context (no payload bytes available): produce wrapper with default payload.
            var zeroJson = JsonDocument.Parse("0").RootElement;
            try { return entry.WrapFromJson(zeroJson, false); } catch { return _default; }
        }
        return _default;
    }
}
