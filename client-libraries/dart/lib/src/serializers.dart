part of "../skir_client.dart";

/// Provides serializers for all primitive types and utilities for creating
/// composite serializers such as optional and iterable serializers.
class Serializers {
  Serializers._();

  /// Serializer for 32-bit signed integers.
  static final Serializer<int> int32 = Serializer._(_Int32Serializer());

  /// Serializer for 64-bit signed integers.
  static final Serializer<int> int64 = Serializer._(_Int64Serializer());

  /// Serializer for 64-bit unsigned integers.
  static final Serializer<BigInt> hash64 = Serializer._(_Hash64Serializer());

  /// Serializer for 32-bit floating-point numbers.
  static final Serializer<double> float32 = Serializer._(_Float32Serializer());

  /// Serializer for 64-bit floating-point numbers.
  static final Serializer<double> float64 = Serializer._(_Float64Serializer());

  /// Serializer for UTF-8 strings.
  static final Serializer<String> string = Serializer._(_StringSerializer());

  /// Serializer for binary data (byte arrays).
  static final Serializer<ByteString> bytes = Serializer._(_BytesSerializer());

  /// Serializer for timestamp values.
  static final Serializer<DateTime> timestamp = Serializer._(
    _TimestampSerializer(),
  );

  /// Serializer for boolean values.
  static final bool = Serializer._(_BoolSerializer());

  /// Creates a serializer for optional values of type [T]?.
  static Serializer<T?> optional<T>(Serializer<T> other) {
    final otherImpl = other._impl;
    if (otherImpl is _OptionalSerializer<T>) {
      return other;
    } else {
      return Serializer._(_OptionalSerializer<T>(otherImpl));
    }
  }

  /// Creates a serializer for iterables of elements of type [E].
  static Serializer<Iterable<E>> iterable<E>(Serializer<E> item) {
    return Serializer._(_IterableSerializer.iterable(item._impl));
  }

  /// Creates a serializer for keyed iterables that support fast lookup by key.
  static Serializer<KeyedIterable<E, K>> keyedIterable<E, K>(
    Serializer<E> item,
    K Function(E) getKey, {
    String? internal__getKeySpec,
  }) {
    return Serializer._(
      _IterableSerializer.keyedIterable(
        item._impl,
        internal__getKeySpec,
        getKey,
      ),
    );
  }
}
