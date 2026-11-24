namespace SkirClient.Internal;

// =============================================================================
// UnrecognizedFields<T>
// =============================================================================

/// <summary>
/// Stores unrecognized fields encountered while deserializing a struct of type
/// <typeparamref name="T"/>. Preserved on re-serialization so that a value
/// round-tripped by an older client does not silently drop fields added by a
/// newer schema. Completely opaque to user code: you never construct or inspect
/// this type directly.
/// </summary>
/// <typeparam name="T">The struct type that owns this instance.</typeparam>
public sealed class UnrecognizedFields<T>
{
    internal UnrecognizedFormat Format { get; }

    /// <summary>Full slot count (recognized + unrecognized).</summary>
    internal uint ArrayLen { get; }

    /// <summary>Raw bytes of the unrecognized field values.</summary>
    internal byte[] Values { get; }

    private UnrecognizedFields(UnrecognizedFormat format, uint arrayLen, byte[] values)
    {
        Format = format;
        ArrayLen = arrayLen;
        Values = values;
    }

    /// <summary>
    /// Creates an <see cref="UnrecognizedFields{T}"/> from a dense JSON array.
    /// <paramref name="arrayLen"/> is the full slot count (recognized + unrecognized);
    /// <paramref name="jsonBytes"/> is the serialized JSON of the extra elements
    /// as a JSON array string (e.g. <c>[1,"foo"]</c>).
    /// </summary>
    internal static UnrecognizedFields<T> FromJson(uint arrayLen, byte[] jsonBytes) =>
        new(UnrecognizedFormat.DenseJson, arrayLen, jsonBytes);

    /// <summary>
    /// Creates an <see cref="UnrecognizedFields{T}"/> from raw binary wire bytes for
    /// extra slots from a binary-encoded struct.
    /// </summary>
    internal static UnrecognizedFields<T> FromBytes(uint arrayLen, byte[] rawBytes) =>
        new(UnrecognizedFormat.BinaryBytes, arrayLen, rawBytes);
}

// =============================================================================
// UnrecognizedVariant<T>
// =============================================================================

/// <summary>
/// Stores an unrecognized enum variant encountered while deserializing an enum
/// of type <typeparamref name="T"/>. Preserved on re-serialization for round-trip
/// fidelity. Completely opaque to user code: you never construct or inspect
/// this type directly.
/// </summary>
/// <typeparam name="T">The enum type that owns this instance.</typeparam>
public sealed class UnrecognizedVariant<T>
{
    internal UnrecognizedFormat Format { get; }

    /// <summary>Wire number of the unrecognized variant.</summary>
    internal int Number { get; }

    /// <summary>
    /// Raw bytes of the variant payload. Empty when the unrecognized variant is a
    /// constant variant (number only, no associated value).
    /// </summary>
    internal byte[] Value { get; }

    private UnrecognizedVariant(UnrecognizedFormat format, int number, byte[] value)
    {
        Format = format;
        Number = number;
        Value = value;
    }

    /// <summary>
    /// Creates an <see cref="UnrecognizedVariant{T}"/> for an unrecognized variant
    /// carrying a JSON-encoded value (wrapper variant or raw JSON element).
    /// </summary>
    internal static UnrecognizedVariant<T> FromJson(int number, byte[] jsonBytes) =>
        new(UnrecognizedFormat.DenseJson, number, jsonBytes);

    /// <summary>
    /// Creates an <see cref="UnrecognizedVariant{T}"/> for an unrecognized constant
    /// variant. <paramref name="rawBytes"/> is the re-encoded wire number.
    /// </summary>
    internal static UnrecognizedVariant<T> FromBytes(int number, byte[] rawBytes) =>
        new(UnrecognizedFormat.BinaryBytes, number, rawBytes);
}

// =============================================================================
// UnrecognizedFormat
// =============================================================================


/// <summary>The serialization format used to capture unrecognized data.</summary>
internal enum UnrecognizedFormat
{
    DenseJson,
    BinaryBytes,
}
