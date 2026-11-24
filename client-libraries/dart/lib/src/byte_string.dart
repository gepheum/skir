part of "../skir_client.dart";

/// An immutable array of bytes.
class ByteString {
  final Uint8List _uint8List;

  /// An empty byte string.
  static final ByteString empty = ByteString._(Uint8List(0));

  /// Private constructor to ensure immutability.
  const ByteString._(this._uint8List);

  factory ByteString._wrap(Uint8List list) =>
      list.isEmpty ? ByteString.empty : ByteString._(list);

  factory ByteString.copy(List<int> list) =>
      ByteString._wrap(Uint8List.fromList(list));

  factory ByteString.copySlice(TypedData data, [int start = 0, int? end]) =>
      ByteString._wrap(Uint8List.sublistView(data, start, end).sublist(0));

  /// Decodes a Base64 string, which can be obtained by calling [toBase64].
  ///
  /// Throws [FormatException] if the given string is not a valid Base64 string.
  /// See https://en.wikipedia.org/wiki/Base64
  factory ByteString.fromBase64(String base64) =>
      ByteString._wrap(base64Decode(base64));

  /// Decodes a hexadecimal string, which can be obtained by calling [toBase16].
  ///
  /// Throws [FormatException] if the given string is not a valid hexadecimal string.
  factory ByteString.fromBase16(String base16) =>
      ByteString.copy(hex.decode(base16));

  /// Returns an unmodifiable view of the underlying byte data.
  ///
  /// This provides direct access to the bytes without allowing modification.
  Uint8List get asUnmodifiableList => _uint8List.asUnmodifiableView();

  /// The number of bytes in this byte string.
  int get length => _uint8List.length;

  /// Whether this byte string contains no bytes.
  bool get isEmpty => _uint8List.isEmpty;

  /// Whether this byte string contains at least one byte.
  bool get isNotEmpty => _uint8List.isNotEmpty;

  /// Returns a substring of this byte string.
  ///
  /// Creates a new ByteString containing the bytes from [start] (inclusive)
  /// to [end] (exclusive). If [end] is omitted, it defaults to the length
  /// of this byte string.
  ByteString substring(int start, [int? end]) {
    if (start == 0 && end == _uint8List.length) {
      return this;
    } else {
      return ByteString._wrap(_uint8List.sublist(start, end));
    }
  }

  /// Encodes this byte string into a Base64 string.
  ///
  /// See https://en.wikipedia.org/wiki/Base64
  String toBase64() => base64Encode(_uint8List);

  /// Encodes this byte string into a hexadecimal string.
  String toBase16() => hex.encode(_uint8List);

  @override
  String toString() {
    return 'ByteString.fromBase16("${toBase16()}")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ByteString) return false;
    return internal__listEquality.equals(_uint8List, other._uint8List);
  }

  @override
  int get hashCode => internal__listEquality.hash(_uint8List);
}
