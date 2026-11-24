using System.Text;
using System.Text.Json;
using SkirClient.Internal;

namespace SkirClient;

/// <summary>
/// Serializes and deserializes values of type <typeparamref name="T"/>.
/// Every generated struct and enum exposes a static <c>Serializer</c> property
/// that returns an instance of this class.
/// </summary>
public sealed class Serializer<T>
{
    private readonly ITypeAdapter<T> _adapter;

    internal Serializer(ITypeAdapter<T> adapter)
    {
        _adapter = adapter;
    }

    internal ITypeAdapter<T> Adapter => _adapter;

    /// <summary>
    /// Serializes <paramref name="value"/> to JSON.
    /// <para>
    /// Use <paramref name="readable"/> = <c>false</c> (default) for storage and
    /// transport.
    /// </para>
    /// <para>
    /// Use <paramref name="readable"/> = <c>true</c> for debugging and logs.
    /// </para>
    /// </summary>
    public string ToJson(T value, MustNameArguments _ = default, bool readable = false)
    {
        var sb = new StringBuilder();
        _adapter.ToJson(value, readable ? "\n" : null, sb);
        return sb.ToString();
    }

    /// <summary>Serializes <paramref name="value"/> to compact binary format.</summary>
    public byte[] ToBytes(T value)
    {
        var output = new List<byte>(5);
        output.Add((byte)'s');
        output.Add((byte)'k');
        output.Add((byte)'i');
        output.Add((byte)'r');
        _adapter.Encode(value, output);
        return output.ToArray();
    }

    /// <summary>
    /// Deserializes a value from JSON.
    /// Accepts both dense and readable JSON.
    /// When <paramref name="keepUnrecognizedValues"/> is <c>true</c>, unknown
    /// data is preserved so a read/modify/write flow does not discard fields
    /// added by newer schema versions.
    /// </summary>
    public T FromJson(string json, MustNameArguments _ = default, bool keepUnrecognizedValues = false)
    {
        using var doc = JsonDocument.Parse(json);
        return _adapter.FromJson(doc.RootElement, keepUnrecognizedValues);
    }

    /// <summary>
    /// Deserializes a value from an already-parsed <see cref="JsonElement"/>.
    /// When <paramref name="keepUnrecognizedValues"/> is <c>true</c>, unknown
    /// data is preserved so a read/modify/write flow does not discard fields
    /// added by newer schema versions.
    /// </summary>
    public T FromJson(
        JsonElement element,
        MustNameArguments _ = default,
        bool keepUnrecognizedValues = false)
    {
        return _adapter.FromJson(element, keepUnrecognizedValues);
    }

    /// <summary>
    /// Deserializes a value from binary format.
    /// When <paramref name="keepUnrecognizedValues"/> is <c>true</c>, unknown
    /// data is preserved for forward-compatible round trips.
    /// </summary>
    public T FromBytes(byte[] bytes, MustNameArguments _ = default, bool keepUnrecognizedValues = false)
    {
        if (bytes.Length >= 4 &&
            bytes[0] == 's' && bytes[1] == 'k' &&
            bytes[2] == 'i' && bytes[3] == 'r')
        {
            int offset = 4;
            return _adapter.Decode(bytes, ref offset, keepUnrecognizedValues);
        }
        // No magic prefix - treat payload as UTF-8 JSON.
        return FromJson(
            System.Text.Encoding.UTF8.GetString(bytes),
            keepUnrecognizedValues: keepUnrecognizedValues);
    }

    /// <summary>Reflection descriptor for this type's schema.</summary>
    public TypeDescriptor TypeDescriptor => _adapter.TypeDescriptor;
}
