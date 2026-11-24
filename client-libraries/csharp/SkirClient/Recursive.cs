namespace SkirClient;

/// <summary>
/// Wraps a recursive struct field value.
/// <para>
/// Use <see cref="Default"/> to represent the field's default state
/// (no wrapped value).
/// </para>
/// <para>
/// Use <see cref="FromValue(T)"/> to create a value-bearing instance, then
/// check <see cref="HasValue"/> before reading <see cref="Value"/>.
/// </para>
/// </summary>
public readonly struct Recursive<T>
{
    // Keep wrapped values behind a reference so Recursive<Foo> can be used
    // even when Foo is a struct (breaks value-type layout cycles).
    private sealed class Box(T value)
    {
        public T Value { get; } = value;

        public override bool Equals(object? obj) =>
            obj is Box other && global::System.Collections.Generic.EqualityComparer<T>.Default.Equals(Value, other.Value);

        public override int GetHashCode() =>
            global::System.Collections.Generic.EqualityComparer<T>.Default.GetHashCode(Value!);

        public override string ToString() => Value?.ToString() ?? "";
    }

    private readonly Box? _box;

    private Recursive(Box? box)
    {
        _box = box;
    }

    /// <summary>
    /// True when this instance contains a wrapped value.
    /// </summary>
    public bool HasValue => _box is not null;

    /// <summary>
    /// The wrapped value.
    /// Throws when called on <see cref="Default"/>.
    /// </summary>
    public T Value =>
        HasValue
            ? _box!.Value
            : throw new global::System.InvalidOperationException(
                "Recursive value is default and has no wrapped value.");

    /// <summary>
    /// Returns the default state (no wrapped value).
    /// </summary>
    public static readonly Recursive<T> Default = new(box: null);

    /// <summary>
    /// Returns an instance with a wrapped value.
    /// </summary>
    public static Recursive<T> FromValue(T value)
    {
        if (value is null)
            throw new global::System.ArgumentNullException(nameof(value));
        return new Recursive<T>(box: new Box(value));
    }

    /// <summary>
    /// Returns the wrapped value's string representation, or an empty string for <see cref="Default"/>.
    /// </summary>
    public override string ToString() => _box?.ToString() ?? "";
}
