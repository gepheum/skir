part of "../skir_client.dart";

class internal__UnrecognizedFields {
  final int _totalSlotCount;
  final List<dynamic>? _jsonElements;
  final Uint8List? _bytes;

  internal__UnrecognizedFields._fromJson(
    this._totalSlotCount,
    this._jsonElements,
  ) : _bytes = null;

  internal__UnrecognizedFields._fromBytes(this._totalSlotCount, this._bytes)
      : _jsonElements = null;
}

class internal__UnrecognizedVariant {
  final dynamic _jsonElement;
  final Uint8List? _bytes;

  internal__UnrecognizedVariant._fromJson(this._jsonElement) : _bytes = null;

  internal__UnrecognizedVariant._fromBytes(this._bytes) : _jsonElement = null;
}
