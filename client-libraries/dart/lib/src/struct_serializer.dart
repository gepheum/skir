part of "../skir_client.dart";

/// Specialization of a [Serializer] for generated struct types.
class StructSerializer<Frozen, Mutable> extends Serializer<Frozen> {
  StructSerializer._(_StructSerializerImpl<Frozen, Mutable> super.impl)
      : super._();

  @override
  ReflectiveStructDescriptor<Frozen, Mutable> get typeDescriptor =>
      super._impl as _StructSerializerImpl<Frozen, Mutable>;
}

class internal__StructSerializerBuilder<Frozen, Mutable> {
  final _StructSerializerImpl<Frozen, Mutable> _impl;
  final StructSerializer<Frozen, Mutable> serializer;
  bool _initialized = false;

  factory internal__StructSerializerBuilder({
    required String recordId,
    required String doc,
    required Frozen defaultInstance,
    required Mutable Function(Frozen?) newMutable,
    required Frozen Function(Mutable) toFrozen,
    required internal__UnrecognizedFields? Function(Frozen)
        getUnrecognizedFields,
    required void Function(Mutable, internal__UnrecognizedFields)
        setUnrecognizedFields,
  }) {
    final impl = _StructSerializerImpl(
      recordId: recordId,
      doc: doc,
      defaultInstance: defaultInstance,
      newMutableFn: newMutable,
      toFrozenFn: toFrozen,
      getUnrecognizedFields: getUnrecognizedFields,
      setUnrecognizedFields: setUnrecognizedFields,
    );
    return internal__StructSerializerBuilder._(impl, StructSerializer._(impl));
  }

  internal__StructSerializerBuilder._(this._impl, this.serializer);

  bool mustInitialize() {
    if (_initialized) {
      return false;
    } else {
      _initialized = true;
      return true;
    }
  }

  void addField<Value>(
    String name,
    String dartName,
    int number,
    Serializer<Value> serializer,
    String doc,
    Value Function(Frozen) getter,
    void Function(Mutable, Value) setter,
  ) {
    _impl.addField(name, dartName, number, serializer, doc, getter, setter);
  }

  void addRemovedNumber(int number) {
    _impl.addRemovedNumber(number);
  }

  void finalize() {
    _impl.finalize();
  }
}

/// Implementation of struct field
class _StructFieldImpl<Frozen, Mutable, Value>
    extends ReflectiveStructField<Frozen, Mutable, Value> {
  @override
  final String name;
  final String dartName;
  @override
  final int number;
  final Serializer<Value> serializer;
  @override
  final String doc;
  final Value Function(Frozen) getter;
  final void Function(Mutable, Value) setter;

  _StructFieldImpl(
    this.name,
    this.dartName,
    this.number,
    this.serializer,
    this.doc,
    this.getter,
    this.setter,
  ) : super._();

  bool valueIsDefault(Frozen input) {
    return serializer._impl.isDefault(getter(input));
  }

  dynamic valueToJson(Frozen input, bool readableFlavor) {
    return serializer.toJson(getter(input), readableFlavor: readableFlavor);
  }

  void valueFromJson(
    Mutable mutable,
    dynamic json,
    bool keepUnrecognizedValues,
  ) {
    final value = serializer.fromJson(
      json,
      keepUnrecognizedValues: keepUnrecognizedValues,
    );
    setter(mutable, value);
  }

  void encodeValue(Frozen input, Uint8Buffer buffer) {
    serializer._impl.encode(getter(input), buffer);
  }

  void decodeValue(
    Mutable mutable,
    _ByteStream stream,
    bool keepUnrecognizedValues,
  ) {
    final value = serializer._impl.decode(stream, keepUnrecognizedValues);
    setter(mutable, value);
  }

  void appendString(Frozen input, StringBuffer out, String eolIndent) {
    serializer._impl.appendString(getter(input), out, eolIndent);
  }

  @override
  ReflectiveTypeDescriptor<Value> get type => serializer._impl.typeDescriptor;

  @override
  void set(Mutable struct, Value value) => setter(struct, value);

  @override
  Value get(Frozen struct) => getter(struct);
}

/// Struct serializer implementation
class _StructSerializerImpl<Frozen, Mutable>
    extends ReflectiveStructDescriptor<Frozen, Mutable>
    implements _SerializerImpl<Frozen> {
  final _RecordId _recordId;
  @override
  final String doc;
  final Frozen defaultInstance;
  final Mutable Function(Frozen?) newMutableFn;
  final Frozen Function(Mutable) toFrozenFn;
  final internal__UnrecognizedFields? Function(Frozen) getUnrecognizedFields;
  final void Function(Mutable, internal__UnrecognizedFields)
      setUnrecognizedFields;

  final List<_StructFieldImpl<Frozen, Mutable, dynamic>> _mutableFields = [];
  final Set<int> _mutableRemovedNumbers = <int>{};
  final Map<String, _StructFieldImpl<Frozen, Mutable, dynamic>>
      _nameToMutableField = {};
  int _maxRemovedNumber = -1;
  // Number of slots including removed fields.
  int _slotCountInclRemoved = 0;
  // Length: _slotCountInclRemoved
  List<_StructFieldImpl<Frozen, Mutable, dynamic>?> _slotToField = [];
  // Length: _slotCountInclRemoved
  List<dynamic> _zeros = [];
  bool _finalized = false;

  _StructSerializerImpl({
    required String recordId,
    required this.doc,
    required this.defaultInstance,
    required this.newMutableFn,
    required this.toFrozenFn,
    required this.getUnrecognizedFields,
    required this.setUnrecognizedFields,
  })  : _recordId = _RecordId.parse(recordId),
        super._();

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  void addField<Value>(
    String name,
    String dartName,
    int number,
    Serializer<Value> serializer,
    String doc,
    Value Function(Frozen) getter,
    void Function(Mutable, Value) setter,
  ) {
    _checkNotFinalized();
    final field = _StructFieldImpl<Frozen, Mutable, Value>(
      name,
      dartName,
      number,
      serializer,
      doc,
      getter,
      setter,
    );
    _mutableFields.add(field);
    _nameToMutableField[field.name] = field;
  }

  void addRemovedNumber(int number) {
    _checkNotFinalized();
    _mutableRemovedNumbers.add(number);
    _maxRemovedNumber = max(_maxRemovedNumber, number);
  }

  void finalize() {
    _checkNotFinalized();
    _finalized = true;
    _mutableFields.sort((a, b) => a.number.compareTo(b.number));
    final slotCountNoRemoved =
        _mutableFields.isNotEmpty ? _mutableFields.last.number + 1 : 0;
    final slotCountInclRemoved = max(
      slotCountNoRemoved,
      _mutableRemovedNumbers.isNotEmpty
          ? _mutableRemovedNumbers.reduce(max) + 1
          : 0,
    );
    _slotCountInclRemoved = slotCountInclRemoved;
    _slotToField = List.filled(slotCountInclRemoved, null);
    for (final field in _mutableFields) {
      _slotToField[field.number] = field;
    }
    _zeros = List.filled(slotCountInclRemoved, 0);
  }

  void _checkNotFinalized() {
    if (_finalized) {
      throw StateError('Struct is already finalized');
    }
  }

  @override
  bool isDefault(Frozen value) {
    return identical(value, defaultInstance) ||
        (_mutableFields.every((field) => field.valueIsDefault(value)) &&
            getUnrecognizedFields(value) == null);
  }

  bool _isDefaultIgnoringUnrecognized(Frozen value) {
    return identical(value, defaultInstance) ||
        _mutableFields.every((field) => field.valueIsDefault(value));
  }

  @override
  dynamic toJson(Frozen input, bool readableFlavor) {
    if (readableFlavor) {
      return identical(input, defaultInstance)
          ? <String, dynamic>{}
          : _toReadableJson(input);
    } else {
      return identical(input, defaultInstance)
          ? <dynamic>[]
          : _toDenseJson(input);
    }
  }

  List<dynamic> _toDenseJson(Frozen input) {
    final unrecognizedFields = getUnrecognizedFields(input);
    if (unrecognizedFields?._jsonElements != null) {
      // Some unrecognized fields
      final elements = List<dynamic>.from(_zeros)
        ..addAll(unrecognizedFields!._jsonElements!);
      for (final field in _mutableFields) {
        elements[field.number] = field.valueToJson(input, false);
      }
      return elements;
    } else {
      // No unrecognized fields
      final slotCount = _getSlotCount(input);
      final elements = List<dynamic>.filled(slotCount, 0);
      for (int i = 0; i < slotCount; i++) {
        final field = _slotToField[i];
        elements[i] = field?.valueToJson(input, false) ?? 0;
      }
      return elements;
    }
  }

  Map<String, dynamic> _toReadableJson(Frozen input) {
    final nameToElement = <String, dynamic>{};
    for (final field in _mutableFields) {
      if (field.valueIsDefault(input)) {
        continue;
      }
      nameToElement[field.name] = field.valueToJson(input, true);
    }
    return nameToElement;
  }

  @override
  Frozen fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is int && json == 0) {
      return defaultInstance;
    } else if (json is List) {
      return _fromDenseJson(json, keepUnrecognizedValues);
    } else if (json is Map<String, dynamic>) {
      return _fromReadableJson(json);
    } else {
      throw ArgumentError('Expected: array or object');
    }
  }

  Frozen _fromDenseJson(List<dynamic> jsonArray, bool keepUnrecognizedValues) {
    final mutable = newMutableFn(null);
    final int numSlotsToFill;
    if (jsonArray.length > _slotCountInclRemoved) {
      // We have some unrecognized fields
      if (keepUnrecognizedValues) {
        final unrecognizedFields = internal__UnrecognizedFields._fromJson(
          jsonArray.length,
          jsonArray
              .sublist(_slotCountInclRemoved)
              .map((e) => _copyJson(e))
              .toList(),
        );
        setUnrecognizedFields(mutable, unrecognizedFields);
      }
      numSlotsToFill = _slotCountInclRemoved;
    } else {
      numSlotsToFill = jsonArray.length;
    }
    for (final field in _mutableFields) {
      if (field.number >= numSlotsToFill) {
        break;
      }
      field.valueFromJson(
        mutable,
        jsonArray[field.number],
        keepUnrecognizedValues,
      );
    }
    return toFrozenFn(mutable);
  }

  Frozen _fromReadableJson(Map<String, dynamic> jsonObject) {
    final mutable = newMutableFn(null);
    for (final entry in jsonObject.entries) {
      _nameToMutableField[entry.key]
          ?.valueFromJson(mutable, entry.value, false);
    }
    return toFrozenFn(mutable);
  }

  @override
  void encode(Frozen input, Uint8Buffer buffer) {
    // Total number of slots to write. Includes removed and unrecognized fields.
    final int totalSlotCount;
    // Number of slots to write including removed fields but excluding
    // unrecognized fields.
    final int recognizedSlotCount;
    final Uint8List? unrecognizedBytes;
    final unrecognizedFields = getUnrecognizedFields(input);
    if (unrecognizedFields?._bytes != null) {
      totalSlotCount = unrecognizedFields!._totalSlotCount;
      recognizedSlotCount = _slotCountInclRemoved;
      unrecognizedBytes = unrecognizedFields._bytes;
    } else {
      // No unrecognized fields
      totalSlotCount = _getSlotCount(input);
      recognizedSlotCount = totalSlotCount;
      unrecognizedBytes = null;
    }

    if (totalSlotCount <= 3) {
      buffer.add(246 + totalSlotCount);
    } else {
      buffer.add(250);
      _BinaryWriter.encodeLengthPrefix(totalSlotCount, buffer);
    }
    for (int i = 0; i < recognizedSlotCount; i++) {
      final field = _slotToField[i];
      if (field != null) {
        field.encodeValue(input, buffer);
      } else {
        // Append '0' if the field was removed
        buffer.add(0);
      }
    }
    if (unrecognizedBytes != null) {
      // Copy the unrecognized fields
      buffer.addAll(unrecognizedBytes);
    }
  }

  @override
  Frozen decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final wire = stream.readByte();
    if (wire == 0 || wire == 246) {
      return defaultInstance;
    }
    final mutable = newMutableFn(null);
    final encodedSlotCount =
        wire == 250 ? stream.decodeNumber().toInt() : wire - 246;

    // Do not read more slots than the number of recognized slots
    for (int i = 0; i < encodedSlotCount && i < _slotCountInclRemoved; i++) {
      final field = _slotToField[i];
      if (field != null) {
        field.decodeValue(mutable, stream, keepUnrecognizedValues);
      } else {
        // The field was removed
        stream.decodeUnused();
      }
    }
    if (encodedSlotCount > _slotCountInclRemoved) {
      final startPosition = stream.position;
      for (int i = _slotCountInclRemoved; i < encodedSlotCount; i++) {
        stream.decodeUnused();
      }
      // We have some unrecognized fields
      if (keepUnrecognizedValues) {
        // Capture the bytes for the unknown fields
        final unrecognizedBytes = stream.bytes.sublist(
          startPosition,
          stream.position,
        );
        final unrecognizedFields = internal__UnrecognizedFields._fromBytes(
          encodedSlotCount,
          unrecognizedBytes,
        );
        setUnrecognizedFields(mutable, unrecognizedFields);
      }
    }
    return toFrozenFn(mutable);
  }

  @override
  void appendString(Frozen input, StringBuffer out, String eolIndent) {
    final className = _recordId.qualifiedName.replaceAll(".", "_");
    out.write(className);
    if (_isDefaultIgnoringUnrecognized(input)) {
      out.write('.defaultInstance');
    } else {
      out.write('(');
      final newEolIndent = eolIndent + _indentUnit;
      for (final field in _mutableFields) {
        out.write(newEolIndent);
        out.write(field.dartName);
        out.write(': ');
        field.appendString(input, out, newEolIndent);
        out.write(',');
      }
      out.write(eolIndent);
      out.write(')');
    }
  }

  /// Returns the length of the JSON array for the given input.
  /// Assumes that `input` does not contain unrecognized fields.
  int _getSlotCount(Frozen input) {
    for (int i = _mutableFields.length - 1; i >= 0; i--) {
      final field = _mutableFields[i];
      if (!field.valueIsDefault(input)) {
        return field.number + 1;
      }
    }
    return 0;
  }

  dynamic _copyJson(dynamic input) {
    if (input is List) {
      return input.map((e) => _copyJson(e)).toList();
    } else if (input is Map) {
      return input.map((k, v) => MapEntry(k, _copyJson(v)));
    } else {
      return input;
    }
  }

  // Reflection methods
  @override
  Iterable<_StructFieldImpl<Frozen, Mutable, dynamic>> get fields =>
      List.unmodifiable(_mutableFields);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(_mutableRemovedNumbers);

  @override
  _StructFieldImpl<Frozen, Mutable, dynamic>? getFieldByName(String name) {
    return _nameToMutableField[name];
  }

  @override
  _StructFieldImpl<Frozen, Mutable, dynamic>? getFieldByNumber(int number) {
    return 0 <= number && number < _slotToField.length
        ? _slotToField[number]
        : null;
  }

  @override
  Mutable newMutable([Frozen? initializer]) => newMutableFn(initializer);

  @override
  Frozen toFrozen(Mutable mutable) => toFrozenFn(mutable);

  @override
  Frozen get defaultValue => defaultInstance;

  @override
  ReflectiveTypeDescriptor<Frozen> get typeDescriptor => this;
}
