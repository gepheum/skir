part of "../skir_client.dart";

/// Specialization of a [Serializer] for generated enum types.
class EnumSerializer<E> extends Serializer<E> {
  EnumSerializer._(_EnumSerializerImpl<E> super.impl) : super._();

  @override
  ReflectiveEnumDescriptor<E> get typeDescriptor =>
      super._impl as _EnumSerializerImpl<E>;
}

class internal__EnumSerializerBuilder<E> {
  final _EnumSerializerImpl<E> _impl;
  final EnumSerializer<E> serializer;
  bool _initialized = false;

  internal__EnumSerializerBuilder._(this._impl, this.serializer);

  static internal__EnumSerializerBuilder<E> create<E, Unknown extends E>({
    required String recordId,
    required String doc,
    required Unknown unknownInstance,
    required E enumInstance, // For type inference, not used at runtime
    required int Function(E) getOrdinal,
    required E Function(internal__UnrecognizedVariant) wrapUnrecognized,
    required internal__UnrecognizedVariant? Function(Unknown) getUnrecognized,
  }) {
    final String dartClassName = _RecordId.parse(
      recordId,
    ).qualifiedName.replaceAll(".", "_");
    final impl = _EnumSerializerImpl._(
      recordId,
      doc,
      dartClassName,
      _EnumUnknownVariant<E>(
        unknownInstance,
        wrapUnrecognized,
        (E e) => e is Unknown ? getUnrecognized(e) : null,
        "$dartClassName.unknown",
      ),
      getOrdinal,
    );
    return internal__EnumSerializerBuilder<E>._(
      impl,
      EnumSerializer._(impl),
    );
  }

  bool mustInitialize() {
    if (_initialized) {
      return false;
    } else {
      _initialized = true;
      return true;
    }
  }

  void addConstantVariant(
    int number,
    String name,
    String dartName,
    String doc,
    E instance,
  ) {
    _impl.addConstantVariant(number, name, dartName, doc, instance);
  }

  void addWrapperVariant<Wrapper extends E, Value>(
    int number,
    String name,
    String dartName,
    Serializer<Value> valueSerializer,
    String doc,
    Wrapper Function(Value) wrap,
    Value Function(Wrapper) getValue, {
    required int ordinal,
  }) {
    _impl.addWrapperVariant<Wrapper, Value>(
      number,
      name,
      dartName,
      valueSerializer,
      doc,
      wrap,
      getValue,
      ordinal: ordinal,
    );
  }

  void addRemovedNumber(int number) {
    _impl.addRemovedNumber(number);
  }

  void finalize() {
    _impl.finalize();
  }
}

/// Enum serializer implementation
class _EnumSerializerImpl<E> extends ReflectiveEnumDescriptor<E>
    implements _SerializerImpl<E> {
  final _RecordId recordId;
  @override
  final String doc;
  final String dartClassName;
  final _EnumUnknownVariant<E> unknown;
  final int Function(E) getOrdinal;

  _EnumSerializerImpl._(
    String recordId,
    this.doc,
    this.dartClassName,
    this.unknown,
    this.getOrdinal,
  )   : recordId = _RecordId.parse(recordId),
        super._();

  @override
  String get name => recordId.name;

  @override
  String get qualifiedName => recordId.qualifiedName;

  @override
  String get modulePath => recordId.modulePath;

  void addConstantVariant(
    int number,
    String name,
    String dartName,
    String doc,
    E instance,
  ) {
    checkNotFinalized();
    final ordinal = getOrdinal(instance);
    final asString = '$dartClassName.$dartName';
    addVariantImpl(
      ordinal: ordinal,
      variant: _EnumConstantVariant<E>(number, name, doc, instance, asString),
    );
  }

  void addWrapperVariant<W extends E, V>(
    int number,
    String name,
    String dartName,
    Serializer<V> valueSerializer,
    String doc,
    W Function(V) wrap,
    V Function(W) getValue, {
    required int ordinal,
  }) {
    checkNotFinalized();
    final wrapFunctionName = '$dartClassName.$dartName';
    addVariantImpl(
      ordinal: ordinal,
      variant: _WrapperVariant<E, W, V>(
        number,
        name,
        valueSerializer,
        doc,
        wrap,
        getValue,
        wrapFunctionName,
      ),
    );
  }

  void addRemovedNumber(int number) {
    checkNotFinalized();
    mutableRemovedNumbers.add(number);
    numberToVariant[number] = _EnumRemovedNumber<E>(number);
  }

  void finalize() {
    checkNotFinalized();
    addVariantImpl(ordinal: 0, variant: unknown);
    // Create variantArray from ordinalToVariant
    for (int ordinal = 0;; ++ordinal) {
      final variant = ordinalToVariant[ordinal];
      if (variant != null) {
        variantArray.add(variant);
      } else {
        break;
      }
    }
    finalized = true;
  }

  void checkNotFinalized() {
    if (finalized) {
      throw StateError('Enum is already finalized');
    }
  }

  void addVariantImpl({
    required int ordinal,
    required _EnumVariant<E> variant,
  }) {
    mutableVariants.add(variant);
    numberToVariant[variant.number] = variant;
    ordinalToVariant[ordinal] = variant;
    nameToVariant[variant.name] = variant;
    // Register case aliases for constants and UNKNOWN so that both UPPER_CASE
    // and lower_case names are accepted when parsing readable JSON.
    if (variant is _EnumConstantVariant<E> ||
        variant is _EnumUnknownVariant<E>) {
      {
        final nameUpper = variant.name.toUpperCase();
        if (nameUpper != variant.name) nameToVariant[nameUpper] = variant;
      }
      {
        final nameLower = variant.name.toLowerCase();
        if (nameLower != variant.name) nameToVariant[nameLower] = variant;
      }
    }
  }

  final List<_EnumVariant<E>> mutableVariants = [];
  final Set<int> mutableRemovedNumbers = <int>{};
  final Map<int, _EnumVariantOrRemovedNumber<E>> numberToVariant = {};
  final Map<int, _EnumVariant<E>> ordinalToVariant = {};
  final Map<String, _EnumVariant<E>> nameToVariant = {};
  // The index is the ordinal
  var variantArray = <_EnumVariant<E>?>[];
  bool finalized = false;

  @override
  bool isDefault(E value) => identical(value, unknown.constant);

  @override
  dynamic toJson(E input, bool readableFlavor) {
    final variant = variantArray[getOrdinal(input)]!;
    return variant.toJson(input, readableFlavor);
  }

  @override
  E fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is int || (json is String && int.tryParse(json) != null)) {
      final number = json is int ? json : int.parse(json as String);
      final variant = numberToVariant[number];
      switch (variant) {
        case _EnumUnknownVariant<E>():
          return unknown.constant;
        case final _EnumConstantVariant<E> v:
          return v.constant;
        case _EnumRemovedNumber<E>():
          return unknown.constant;
        case final _WrapperVariant<E, E, dynamic> v:
          return v.wrapDefault();
        default:
          if (keepUnrecognizedValues) {
            return unknown.wrapUnrecognized(
              internal__UnrecognizedVariant._fromJson(json),
            );
          } else {
            return unknown.constant;
          }
      }
    } else if (json is String) {
      final variant = nameToVariant[json];
      if (variant is _EnumConstantVariant<E>) {
        return variant.constant;
      } else if (variant is _WrapperVariant<E, E, dynamic>) {
        return variant.wrapDefault();
      } else {
        return unknown.constant;
      }
    } else if (json is List && json.length >= 2) {
      final first = json[0];
      final number =
          first is int ? first : (first is String ? int.tryParse(first) : null);
      if (number != null) {
        final variant = numberToVariant[number];
        if (variant is _WrapperVariant<E, E, dynamic>) {
          final second = json[1];
          return variant.wrapFromJson(second, keepUnrecognizedValues);
        } else if (variant is _EnumConstantVariant<E>) {
          return variant.constant;
        } else if (variant is _EnumRemovedNumber<E>) {
          return unknown.constant;
        } else {
          if (keepUnrecognizedValues) {
            return unknown.wrapUnrecognized(
              internal__UnrecognizedVariant._fromJson(json),
            );
          } else {
            return unknown.constant;
          }
        }
      }
    } else if (json is Map<String, dynamic>) {
      final name = json['kind'] as String?;
      final value = json['value'];
      if (name != null && value != null) {
        final variant = nameToVariant[name];
        if (variant is _WrapperVariant<E, E, dynamic>) {
          return variant.wrapFromJson(value, keepUnrecognizedValues);
        }
      }
    }
    return unknown.constant;
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final variant = variantArray[getOrdinal(input)]!;
    variant.encode(input, buffer);
  }

  @override
  E decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final wire = stream.readByte();
    late E result;

    if (wire < 242) {
      // A number: rewind and decode
      final int startPosition;
      final int number;
      if (wire < 232) {
        startPosition = stream.position - 1;
        number = wire;
      } else {
        startPosition = --stream.position;
        number = stream.decodeNumber().toInt();
      }
      final variant = numberToVariant[number];

      switch (variant) {
        case final _EnumConstantVariant<E> v:
          result = v.constant;
        case _EnumRemovedNumber<E>():
          result = unknown.constant;
        case final _WrapperVariant<E, E, dynamic> v:
          result = v.wrapDefault();
        default:
          {
            if (keepUnrecognizedValues) {
              // Capture the bytes for the unknown enum
              final unrecognizedBytes = stream.bytes.sublist(
                startPosition,
                stream.position,
              );
              result = unknown.wrapUnrecognized(
                internal__UnrecognizedVariant._fromBytes(unrecognizedBytes),
              );
            } else {
              result = unknown.constant;
            }
          }
      }
    } else {
      final startPosition = stream.position - 1;
      final number = wire == 248 ? stream.decodeNumber().toInt() : wire - 250;
      final variant = numberToVariant[number];

      if (variant is _WrapperVariant<E, E, dynamic>) {
        result = variant.wrapDecoded(stream, keepUnrecognizedValues);
      } else if (variant is _EnumConstantVariant<E>) {
        stream.decodeUnused();
        result = variant.constant;
      } else if (variant is _EnumRemovedNumber<E>) {
        stream.decodeUnused();
        result = unknown.constant;
      } else {
        stream.decodeUnused();
        if (keepUnrecognizedValues) {
          // For unknown wrapper variants, we'll just return the unknown constant
          // since reconstructing the full bytes is complex
          final unrecognizedBytes = stream.bytes.sublist(
            startPosition,
            stream.position,
          );
          result = unknown.wrapUnrecognized(
            internal__UnrecognizedVariant._fromBytes(unrecognizedBytes),
          );
        } else {
          result = unknown.constant;
        }
      }
    }

    return result;
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final variant = variantArray[getOrdinal(input)]!;
    variant.appendString(input, out, eolIndent);
  }

  @override
  Iterable<ReflectiveEnumVariant<E>> get variants => mutableVariants
      .where((f) => f.number != 0)
      .map((f) => f.asVariant)
      .toList(growable: false);

  @override
  UnmodifiableSetView<int> get removedNumbers =>
      UnmodifiableSetView(mutableRemovedNumbers);

  @override
  ReflectiveEnumVariant<E>? getVariantByName(String name) =>
      nameToVariant[name]?.asVariant;

  @override
  ReflectiveEnumVariant<E>? getVariantByNumber(int number) {
    final variant = numberToVariant[number];
    return switch (variant) {
      _EnumVariant<E> f => f.asVariant,
      _EnumRemovedNumber<E>() => null,
      null => null,
    };
  }

  @override
  ReflectiveEnumVariant<E> getVariant(E e) {
    final variant = variantArray[getOrdinal(e)]!;
    return variant.asVariant;
  }

  @override
  E get defaultValue => unknown.constant;

  @override
  ReflectiveTypeDescriptor<E> get typeDescriptor => this;
}

// Abstract base class for enum variant implementations
sealed class _EnumVariantOrRemovedNumber<E> {
  int get number;
}

sealed class _EnumVariant<E> extends _EnumVariantOrRemovedNumber<E>
    implements FieldOrVariant {
  @override
  final String name;

  _EnumVariant(this.name);

  ReflectiveEnumVariant<E> get asVariant;

  dynamic toJson(E input, bool readableFlavor);
  void encode(E input, Uint8Buffer buffer);
  void appendString(E input, StringBuffer out, String eolIndent);
}

class _EnumUnknownVariant<E> extends _EnumVariant<E>
    implements ReflectiveEnumConstantVariant<E> {
  @override
  final E constant;
  final E Function(internal__UnrecognizedVariant) wrapUnrecognized;
  final internal__UnrecognizedVariant? Function(E) getUnrecognized;
  final String asString;

  @override
  final String doc = "";

  _EnumUnknownVariant(
    this.constant,
    this.wrapUnrecognized,
    this.getUnrecognized,
    this.asString,
  ) : super('UNKNOWN');

  @override
  int get number => 0;

  @override
  ReflectiveEnumVariant<E> get asVariant => this;

  @override
  dynamic toJson(E input, bool readableFlavor) {
    if (readableFlavor) {
      return 'unknown';
    } else {
      final unrecognized = getUnrecognized(input);
      return unrecognized?._jsonElement ?? 0;
    }
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final unrecognized = getUnrecognized(input);
    if (unrecognized?._bytes != null) {
      buffer.addAll(unrecognized!._bytes!);
    } else {
      buffer.add(0);
    }
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    out.write(asString);
  }
}

class _EnumConstantVariant<E> extends _EnumVariant<E>
    implements ReflectiveEnumConstantVariant<E> {
  @override
  final int number;
  @override
  final String doc;
  @override
  final E constant;
  final String asString;

  _EnumConstantVariant(
    this.number,
    String name,
    this.doc,
    this.constant,
    this.asString,
  ) : super(name);

  @override
  ReflectiveEnumVariant<E> get asVariant => this;

  @override
  dynamic toJson(E input, bool readableFlavor) =>
      readableFlavor ? name : number;

  @override
  void encode(E input, Uint8Buffer buffer) =>
      _BinaryWriter.encodeInt32(number, buffer);

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    out.write(asString);
  }
}

// E: enum type
// W: wrapped enum type (for wrapper variants)
// V: value type
class _WrapperVariant<E, W extends E, V> extends _EnumVariant<E>
    implements ReflectiveEnumWrapperVariant<E, V> {
  @override
  final int number;
  final Serializer<V> valueSerializer;
  @override
  final String doc;
  final W Function(V) wrapFn;
  final V Function(W) getValue;
  final String wrapFunctionName;

  _WrapperVariant(
    this.number,
    String name,
    this.valueSerializer,
    this.doc,
    this.wrapFn,
    this.getValue,
    this.wrapFunctionName,
  ) : super(name);

  @override
  ReflectiveEnumVariant<E> get asVariant => this;

  @override
  dynamic toJson(E input, bool readableFlavor) {
    final value = getValue(input as W);
    final valueToJson = valueSerializer.toJson(
      value,
      readableFlavor: readableFlavor,
    );
    if (readableFlavor) {
      return {'kind': name, 'value': valueToJson};
    } else {
      return [number, valueToJson];
    }
  }

  @override
  void encode(E input, Uint8Buffer buffer) {
    final value = getValue(input as W);
    if (number < 5) {
      buffer.add(250 + number);
    } else {
      buffer.add(248);
      _BinaryWriter.encodeInt32(number, buffer);
    }
    valueSerializer._impl.encode(value, buffer);
  }

  @override
  void appendString(E input, StringBuffer out, String eolIndent) {
    final newEolIndent = eolIndent + _indentUnit;
    out.write("$wrapFunctionName($newEolIndent");
    final value = getValue(input as W);
    valueSerializer._impl.appendString(value, out, newEolIndent);
    out.write("$eolIndent)");
  }

  @override
  ReflectiveTypeDescriptor<V> get type => valueSerializer._impl.typeDescriptor;

  @override
  bool test(E e) => e is W;

  @override
  V get(E e) => getValue(e as W);

  @override
  W wrap(V value) => wrapFn(value);

  @override
  E mapValue(E e, ReflectiveTransformer transformer) {
    final value = get(e);
    final transformedValue = transformer.transform(value, type);
    if (identical(transformedValue, value)) {
      return e;
    } else {
      return wrap(transformedValue);
    }
  }

  W wrapFromJson(dynamic json, bool keepUnrecognizedValues) {
    final value = valueSerializer.fromJson(
      json,
      keepUnrecognizedValues: keepUnrecognizedValues,
    );
    return wrap(value);
  }

  W wrapDecoded(_ByteStream stream, bool keepUnrecognizedValues) {
    final value = valueSerializer._impl.decode(stream, keepUnrecognizedValues);
    return wrap(value);
  }

  W wrapDefault() {
    final value = valueSerializer.fromJson(0, keepUnrecognizedValues: false);
    return wrap(value);
  }
}

class _EnumRemovedNumber<E> extends _EnumVariantOrRemovedNumber<E> {
  @override
  final int number;

  _EnumRemovedNumber(this.number);
}
