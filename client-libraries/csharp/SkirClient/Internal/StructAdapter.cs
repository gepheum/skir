using System.Text;
using System.Text.Json;

namespace SkirClient.Internal;

public sealed class StructAdapter<T, TBuilder> : ITypeAdapter<T> where T : struct
{
    // ---- per-field type-erased interface ------------------------------------

    private interface IFieldEntry
    {
        string Name { get; }
        int Number { get; }
        string Doc { get; }
        TypeDescriptor FieldType { get; }
        bool IsDefault(T value);
        void ToJson(T value, string? eolIndent, StringBuilder sb);
        void SetFromJson(TBuilder builder, JsonElement json, bool keep);
        void Encode(T value, List<byte> output);
        void SetFromBytes(TBuilder builder, byte[] data, ref int offset, bool keep);
    }

    private sealed class TypedField<V>(
        string name, int number, string doc, ITypeAdapter<V> adapter,
        Func<T, V> getter, Action<TBuilder, V> setter) : IFieldEntry
    {
        public string Name => name;
        public int Number => number;
        public string Doc => doc;
        public TypeDescriptor FieldType => adapter.TypeDescriptor;
        public bool IsDefault(T v) => adapter.IsDefault(getter(v));
        public void ToJson(T v, string? eolIndent, StringBuilder sb) =>
            adapter.ToJson(getter(v), eolIndent, sb);
        public void SetFromJson(TBuilder b, JsonElement json, bool keep)
            => setter(b, adapter.FromJson(json, keep));
        public void Encode(T v, List<byte> output) =>
            adapter.Encode(getter(v), output);
        public void SetFromBytes(TBuilder b, byte[] data, ref int offset, bool keep)
            => setter(b, adapter.Decode(data, ref offset, keep));
    }

    // ---- state -------------------------------------------------------------

    private readonly T _default;
    private readonly string _modulePath;
    private readonly string _qualifiedName;
    private readonly Func<TBuilder> _newBuilder;
    private readonly Func<TBuilder, T> _build;
    private readonly List<IFieldEntry> _orderedFields = [];
    private readonly Func<T, UnrecognizedFields<T>?> _getUnrecognized;
    private readonly Action<TBuilder, UnrecognizedFields<T>?> _setUnrecognized;
    private readonly Dictionary<string, int> _nameToIndex = [];
    private readonly HashSet<int> _removedNumbers = [];
    private List<int?> _slotToIndex = [];
    private readonly StructDescriptor _descriptor;

    /// <summary>Creates a struct adapter used by generated struct serializers.</summary>
    public StructAdapter(T defaultValue, string modulePath, string qualifiedName, string structDoc,
        Func<TBuilder> newBuilder, Func<TBuilder, T> build,
        Func<T, UnrecognizedFields<T>?> getUnrecognized,
        Action<TBuilder, UnrecognizedFields<T>?> setUnrecognized)
    {
        _default = defaultValue;
        _modulePath = modulePath;
        _qualifiedName = qualifiedName;
        _newBuilder = newBuilder;
        _build = build;
        _descriptor = new StructDescriptor(modulePath, qualifiedName, structDoc);
        _getUnrecognized = getUnrecognized;
        _setUnrecognized = setUnrecognized;
    }

    // ---- builder -----------------------------------------------------------

    /// <summary>Registers a struct field. Must be called before <see cref="Finalize_"/>.</summary>
    public void AddField<V>(string name, int number, Serializer<V> serializer,
        Func<T, V> getter, Action<TBuilder, V> setter, string doc = "")
    {
        int idx = _orderedFields.Count;
        _orderedFields.Add(new TypedField<V>(name, number, doc, serializer.Adapter, getter, setter));
        _nameToIndex[name] = idx;
    }

    /// <summary>Marks a slot number as removed. Must be called before <see cref="Finalize_"/>.</summary>
    public void AddRemovedNumber(int number) => _removedNumbers.Add(number);

    /// <summary>
    /// Finalizes the adapter. Must be called exactly once, after all
    /// <see cref="AddField{V}"/> and <see cref="AddRemovedNumber"/> calls.
    /// </summary>
    public void Finalize_()
    {
        _orderedFields.Sort((a, b) => a.Number.CompareTo(b.Number));
        _nameToIndex.Clear();
        for (int i = 0; i < _orderedFields.Count; i++)
            _nameToIndex[_orderedFields[i].Name] = i;

        int maxSlot = -1;
        foreach (var f in _orderedFields) if (f.Number > maxSlot) maxSlot = f.Number;
        foreach (int r in _removedNumbers) if (r > maxSlot) maxSlot = r;

        _slotToIndex = new List<int?>(new int?[maxSlot + 1]);
        for (int i = 0; i < _orderedFields.Count; i++)
            _slotToIndex[_orderedFields[i].Number] = i;

        var fields = _orderedFields
            .Select(f => new StructField(f.Name, f.Number, f.FieldType, f.Doc))
            .ToList();
        _descriptor.SetFields(fields);
        _descriptor.SetRemovedNumbers(_removedNumbers);
    }

    public TypeDescriptor TypeDescriptor => _descriptor;

    public Serializer<T> ToSerializer() => new(this);

    public bool IsDefault(T value)
    {
        foreach (var f in _orderedFields)
            if (!f.IsDefault(value)) return false;
        return true;
    }

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
        if (eolIndent != null)
        {
            sb.Append('{');
            string childIndent = eolIndent + "  ";
            bool first = true;
            foreach (var f in _orderedFields)
            {
                if (f.IsDefault(value)) continue;
                if (!first) sb.Append(',');
                first = false;
                sb.Append(childIndent);
                Serializers.WriteJsonString_(f.Name, sb);
                sb.Append(": ");
                f.ToJson(value, childIndent, sb);
            }
            if (!first) sb.Append(eolIndent);
            sb.Append('}');
        }
        else
        {
            sb.Append('[');
            int recognizedSlotCount = 0;
            for (int i = _orderedFields.Count - 1; i >= 0; i--)
            {
                if (!_orderedFields[i].IsDefault(value))
                {
                    recognizedSlotCount = _orderedFields[i].Number + 1;
                    break;
                }
            }
            var u = _getUnrecognized(value);
            int slotCount = recognizedSlotCount;
            if (u != null && u.Format == UnrecognizedFormat.DenseJson)
                slotCount = Math.Max(slotCount, (int)u.ArrayLen);
            JsonElement[]? unrecArr = null;
            if (u != null && u.Format == UnrecognizedFormat.DenseJson && u.Values.Length > 0)
                unrecArr = JsonDocument.Parse(u.Values).RootElement.EnumerateArray().ToArray();
            for (int i = 0; i < slotCount; i++)
            {
                if (i > 0) sb.Append(',');
                if (i < _slotToIndex.Count && _slotToIndex[i] is int idx)
                    _orderedFields[idx].ToJson(value, null, sb);
                else
                {
                    int unrecIdx = i - _slotToIndex.Count;
                    if (unrecArr != null && unrecIdx >= 0 && unrecIdx < unrecArr.Length)
                        sb.Append(unrecArr[unrecIdx].GetRawText());
                    else
                        sb.Append('0');
                }
            }
            sb.Append(']');
        }
    }

    private T FromJsonImpl(JsonElement json, bool keep) =>
        json.ValueKind switch
        {
            JsonValueKind.Number => _default,
            JsonValueKind.Array => FromDenseJson(json, keep),
            JsonValueKind.Object => FromReadableJson(json),
            _ => _default,
        };

    private T FromDenseJson(JsonElement arr, bool keep)
    {
        var b = _newBuilder();
        int arrLen = arr.GetArrayLength();
        int fill = Math.Min(arrLen, _slotToIndex.Count);
        int i = 0;
        foreach (var item in arr.EnumerateArray())
        {
            if (i >= fill) break;
            if (_slotToIndex[i] is int idx)
                _orderedFields[idx].SetFromJson(b, item, keep);
            i++;
        }
        if (keep && arrLen > _slotToIndex.Count)
        {
            var sb = new StringBuilder("[");
            bool first = true;
            int j = 0;
            foreach (var item in arr.EnumerateArray())
            {
                if (j++ < _slotToIndex.Count) continue;
                if (!first) sb.Append(',');
                first = false;
                sb.Append(item.GetRawText());
            }
            sb.Append(']');
            _setUnrecognized(b, UnrecognizedFields<T>.FromJson(
                (uint)arrLen, Encoding.UTF8.GetBytes(sb.ToString())));
        }
        return _build(b);
    }

    private T FromReadableJson(JsonElement obj)
    {
        var b = _newBuilder();
        foreach (var prop in obj.EnumerateObject())
            if (_nameToIndex.TryGetValue(prop.Name, out int idx))
                _orderedFields[idx].SetFromJson(b, prop.Value, false);
        return _build(b);
    }

    // ---- Binary encode / decode --------------------------------------------

    private void EncodeImpl(T value, List<byte> output)
    {
        int slotCount = GetSlotCount(value);
        if (slotCount == 0) { output.Add(246); return; }
        if (slotCount <= 3) output.Add((byte)(246 + slotCount));
        else { output.Add(250); Serializers.EncodeUint32_((uint)slotCount, output); }

        int recognized = _slotToIndex.Count;
        for (int i = 0; i < Math.Min(slotCount, recognized); i++)
        {
            if (_slotToIndex[i] is int idx)
                _orderedFields[idx].Encode(value, output);
            else
                output.Add(0);
        }
        if (slotCount > recognized)
        {
            var u = _getUnrecognized(value);
            if (u != null && u.Format == UnrecognizedFormat.BinaryBytes && u.Values.Length > 0)
                output.AddRange(u.Values);
            else
                for (int i = recognized; i < slotCount; i++) output.Add(0);
        }
    }

    private T DecodeImpl(byte[] data, ref int offset, bool keep)
    {
        if (offset >= data.Length) return _default;
        byte wire = Serializers.ReadU8_(data, ref offset);
        if (wire == 0 || wire == 246) return _default;

        int encodedSlotCount = wire == 250
            ? (int)Serializers.DecodeNumber(data, ref offset)
            : wire - 246;

        var b = _newBuilder();
        int recognized = _slotToIndex.Count;
        int fill = Math.Min(encodedSlotCount, recognized);

        for (int i = 0; i < fill; i++)
        {
            if (_slotToIndex[i] is int idx)
                _orderedFields[idx].SetFromBytes(b, data, ref offset, keep);
            else
                Serializers.SkipValue_(data, ref offset);
        }
        if (keep && encodedSlotCount > recognized)
        {
            int before = offset;
            for (int i = fill; i < encodedSlotCount; i++)
                Serializers.SkipValue_(data, ref offset);
            _setUnrecognized(b, UnrecognizedFields<T>.FromBytes(
                (uint)encodedSlotCount, data[before..offset]));
        }
        else
        {
            for (int i = fill; i < encodedSlotCount; i++)
                Serializers.SkipValue_(data, ref offset);
        }
        return _build(b);
    }

    private int GetSlotCount(T value)
    {
        int recognized = 0;
        for (int i = _orderedFields.Count - 1; i >= 0; i--)
            if (!_orderedFields[i].IsDefault(value)) { recognized = _orderedFields[i].Number + 1; break; }
        var u = _getUnrecognized(value);
        return (u != null && u.Format == UnrecognizedFormat.BinaryBytes)
            ? Math.Max(recognized, (int)u.ArrayLen)
            : recognized;
    }
}
