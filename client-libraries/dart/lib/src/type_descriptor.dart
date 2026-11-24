part of "../skir_client.dart";

/// 🪞 Base interface for all type descriptors
abstract class _TypeDescriptorBase {
  Map<String, dynamic> get asJson;

  String get asJsonCode;
}

/// 🪞 Describes a skir type.
///
/// Type descriptors provide metadata about skir types, enabling schema
/// introspection. They don't let you inspect, modify or create skir values at
/// runtime; for this, you have to use [ReflectiveTypeDescriptor].
sealed class TypeDescriptor implements _TypeDescriptorBase {
  /// Returns the JSON representation of this type descriptor.
  @override
  Map<String, dynamic> get asJson => _typeDescriptorAsJsonImpl(this);

  /// Returns the stringified JSON representation of this type descriptor.
  @override
  String get asJsonCode => _typeDescriptorAsJsonCodeImpl(this);

  /// Parses a type descriptor from its JSON representation, as returned by
  /// [asJson].
  static TypeDescriptor parseFromJson(dynamic json) {
    return _parseTypeDescriptor(json);
  }

  /// Parses a type descriptor from its JSON string representation, as returned
  /// by [asJsonCode].
  static TypeDescriptor parseFromJsonCode(String jsonCode) {
    final json = jsonDecode(jsonCode);
    return _parseTypeDescriptor(json);
  }
}

/// 🪞 Base class for reflective type descriptors that provide runtime type
/// information.
///
/// Reflective type descriptors offer enhanced introspection capabilities
/// compared to their non-reflective counterparts, enabling runtime manipulation
/// and analysis of skir values.
sealed class ReflectiveTypeDescriptor<T> implements _TypeDescriptorBase {
  /// Returns a non-reflective type descriptor equivalent to this reflective
  /// descriptor.
  TypeDescriptor get notReflective => _notReflectiveImpl(this);

  /// Returns the JSON representation of this type descriptor.
  @override
  Map<String, dynamic> get asJson => notReflective.asJson;

  /// Returns the stringified JSON representation of this type descriptor.
  @override
  String get asJsonCode => notReflective.asJsonCode;

  T get defaultValue;

  /// Accepts a [visitor] to perform operations based on the specific skir type:
  /// struct, enum, primitive, array, optional.
  ///
  /// See a complete example at
  /// https://github.com/gepheum/skir-dart-example/blob/main/lib/all_strings_to_upper_case.dart
  void accept(ReflectiveTypeVisitor<T> visitor) {
    _acceptImpl(this, visitor);
  }
}

/// 🪞 Enumeration of all primitive types supported by skir.
enum PrimitiveType {
  bool,
  int32,
  int64,
  hash64,
  float32,
  float64,
  timestamp,
  string,
  bytes,
}

/// 🪞 Describes a primitive skir type.
sealed class PrimitiveDescriptor<T> extends TypeDescriptor
    implements ReflectiveTypeDescriptor<T> {
  /// The specific primitive type being described.
  final PrimitiveType primitiveType;

  PrimitiveDescriptor._(this.primitiveType);

  @override
  PrimitiveDescriptor<T> get notReflective => this;
  @override
  void accept(ReflectiveTypeVisitor<T> visitor) {
    _acceptImpl(this, visitor);
  }
}

/// 🪞 Describes the `bool` primitive type.
class BoolDescriptor extends PrimitiveDescriptor<bool> {
  static final instance = BoolDescriptor._();

  @override
  bool get defaultValue => false;

  BoolDescriptor._() : super._(PrimitiveType.bool);
}

/// 🪞 Describes the `int32` primitive type.
class Int32Descriptor extends PrimitiveDescriptor<int> {
  static final instance = Int32Descriptor._();

  @override
  int get defaultValue => 0;

  Int32Descriptor._() : super._(PrimitiveType.int32);
}

/// 🪞 Describes the `int64` primitive type.
class Int64Descriptor extends PrimitiveDescriptor<int> {
  static final instance = Int64Descriptor._();

  @override
  int get defaultValue => 0;

  Int64Descriptor._() : super._(PrimitiveType.int64);
}

/// 🪞 Describes the `hash64` primitive type.
class Hash64Descriptor extends PrimitiveDescriptor<BigInt> {
  static final instance = Hash64Descriptor._();

  @override
  BigInt get defaultValue => BigInt.zero;

  Hash64Descriptor._() : super._(PrimitiveType.hash64);
}

/// 🪞 Describes the `float32` primitive type.
class Float32Descriptor extends PrimitiveDescriptor<double> {
  static final instance = Float32Descriptor._();

  @override
  double get defaultValue => 0.0;

  Float32Descriptor._() : super._(PrimitiveType.float32);
}

/// 🪞 Describes the `float64` primitive type.
class Float64Descriptor extends PrimitiveDescriptor<double> {
  static final instance = Float64Descriptor._();

  @override
  double get defaultValue => 0.0;

  Float64Descriptor._() : super._(PrimitiveType.float64);
}

/// 🪞 Describes the `timestamp` primitive type.
class TimestampDescriptor extends PrimitiveDescriptor<DateTime> {
  static final instance = TimestampDescriptor._();

  @override
  DateTime get defaultValue => unixEpoch;

  TimestampDescriptor._() : super._(PrimitiveType.timestamp);
}

/// 🪞 Describes the `string` primitive type.
class StringDescriptor extends PrimitiveDescriptor<String> {
  static final instance = StringDescriptor._();

  @override
  String get defaultValue => '';

  StringDescriptor._() : super._(PrimitiveType.string);
}

/// 🪞 Describes the `bytes` primitive type.
class BytesDescriptor extends PrimitiveDescriptor<ByteString> {
  static final instance = BytesDescriptor._();

  @override
  ByteString get defaultValue => ByteString.empty;

  BytesDescriptor._() : super._(PrimitiveType.bytes);
}

abstract class _OptionalDescriptorBase<OtherType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  OtherType get otherType;
}

/// 🪞 Describes an optional type that can hold either a value of the wrapped
/// type or null.
class OptionalDescriptor extends TypeDescriptor
    implements _OptionalDescriptorBase<TypeDescriptor> {
  @override
  final TypeDescriptor otherType;

  OptionalDescriptor(this.otherType);
}

/// 🪞 Describes an optional type that can hold either a value of the wrapped
/// type or null.
abstract class ReflectiveOptionalDescriptor<NotNull>
    extends ReflectiveTypeDescriptor<NotNull?>
    implements _OptionalDescriptorBase<ReflectiveTypeDescriptor<NotNull>> {
  @override
  ReflectiveTypeDescriptor<NotNull> get otherType;

  /// Transforms the wrapped value if present, preserving null values.
  NotNull? map(NotNull? input, ReflectiveTransformer transformer) {
    if (input == null) {
      return null;
    } else {
      return transformer.transform<NotNull>(input, otherType);
    }
  }

  ReflectiveOptionalDescriptor._();
}

abstract class _ArrayDescriptorBase<ItemType extends _TypeDescriptorBase>
    implements _TypeDescriptorBase {
  /// Describes the type of the array items.
  ItemType get itemType;

  /// Optional key chain for keyed lists that support fast lookup by key.
  String? get keyExtractor;
}

/// 🪞 Describes an array type.
class ArrayDescriptor extends TypeDescriptor
    implements _ArrayDescriptorBase<TypeDescriptor> {
  /// Describes the type of the array elements.
  @override
  final TypeDescriptor itemType;

  /// Optional key chain specified in the '.skir' file after the pipe character.
  @override
  final String? keyExtractor;

  ArrayDescriptor(this.itemType, this.keyExtractor);
}

/// 🪞 Describes an array type.
abstract class ReflectiveArrayDescriptor<E, Collection extends Iterable<E>>
    extends ReflectiveTypeDescriptor<Collection>
    implements _ArrayDescriptorBase<ReflectiveTypeDescriptor<E>> {
  @override
  ReflectiveTypeDescriptor<E> get itemType;

  @override
  String? get keyExtractor;

  Collection toCollection(Iterable<E> iterable);

  /// Transforms each element in the collection using [transformer].
  /// Returns a new collection of the same type containing the transformed
  /// elements.
  Collection map(Collection collection, ReflectiveTransformer transformer) {
    final newCollection = collection.map(
      (e) => transformer.transform(e, itemType),
    );
    return toCollection(newCollection);
  }

  ReflectiveArrayDescriptor._();
}

/// 🪞 Describes a field in a struct or a variant in an enum.
abstract class FieldOrVariant {
  /// Name as specified in the '.skir' file, for example 'user_id' or 'MONDAY'.
  String get name;

  /// Field or variant number used for serialization.
  int get number;

  /// Documentation for this field/variant, extracted from doc comments in the
  /// '.skir' file.
  String get doc;

  FieldOrVariant._();
}

abstract class _RecordDescriptorBase implements _TypeDescriptorBase {
  /// Name of the record as specified in the '.skir' file.
  String get name;

  /// A string containing all the names in the hierarchical sequence above and
  /// including the record. For example: "Foo.Bar" if "Bar" is nested within a
  /// type called "Foo", or simply "Bar" if "Bar" is defined at the top-level of
  /// the module.
  String get qualifiedName;

  /// Path to the module where the record is defined, relative to the root of the
  /// project.
  String get modulePath;

  /// Documentation for this record, extracted from doc comments in the '.skir'.
  String get doc;

  /// The field numbers marked as removed.
  UnmodifiableSetView<int> get removedNumbers;
}

abstract class _StructDescriptorBase<F extends FieldOrVariant>
    extends _RecordDescriptorBase {
  /// List of all fields in this struct.
  Iterable<F> get fields;

  /// Looks up a field by name.
  F? getFieldByName(String name);

  /// Looks up a field by number.
  F? getFieldByNumber(int number);
}

abstract class _EnumDescriptorBase<V extends FieldOrVariant>
    extends _RecordDescriptorBase {
  /// List of all variants in this enum.
  Iterable<V> get variants;

  /// Looks up a variant by name.
  V? getVariantByName(String name);

  /// Looks up a variant by number.
  V? getVariantByNumber(int number);
}

String _getRecordId(_RecordDescriptorBase record) {
  return '${record.modulePath}:${record.qualifiedName}';
}

/// 🪞 Describes a record type (struct or enum).
sealed class RecordDescriptor extends TypeDescriptor
    implements _RecordDescriptorBase {}

/// 🪞 Describes a skir record: struct or enum.
sealed class ReflectiveRecordDescriptor<T> extends ReflectiveTypeDescriptor<T>
    implements _RecordDescriptorBase {}

abstract class _StructFieldBase<T extends _TypeDescriptorBase>
    implements FieldOrVariant {
  /// Describes the field type.
  T get type;
}

/// 🪞 Describes a field in a struct.
class StructField implements _StructFieldBase<TypeDescriptor> {
  /// The field name.
  @override
  final String name;

  /// The field number.
  @override
  final int number;

  /// The type descriptor for this field's value type.
  @override
  final TypeDescriptor type;

  /// Documentation for this field, extracted from doc comments in the '.skir'
  /// file.
  @override
  final String doc;

  StructField(this.name, this.number, this.type, this.doc);
}

/// 🪞 Describes a field in a struct.
abstract class ReflectiveStructField<Frozen, Mutable, Value>
    implements _StructFieldBase<ReflectiveTypeDescriptor<Value>> {
  /// Extracts the value of the field from the given struct.
  Value get(Frozen struct);

  /// Assigns the given value to the field of the given struct.
  void set(Mutable struct, Value value);

  /// Copies this field's value from [source] to [target].
  /// If a [transformer] is provided, it is applied to the value before setting
  /// it.
  void copy(
    Frozen source,
    Mutable target, {
    ReflectiveTransformer transformer = ReflectiveTransformer.identity,
  }) {
    set(target, transformer.transform(get(source), type));
  }

  ReflectiveStructField._();
}

/// 🪞 Describes a skir struct.
class StructDescriptor extends RecordDescriptor
    implements _StructDescriptorBase<StructField> {
  final _RecordId _recordId;

  @override
  final UnmodifiableSetView<int> removedNumbers;

  @override
  final String doc;

  Iterable<StructField> _fields;

  @override
  Iterable<StructField> get fields => _fields;

  StructDescriptor._(
    this._recordId,
    this.doc,
    this.removedNumbers,
    this._fields,
  );

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  @override
  StructField? getFieldByName(String name) {
    _nameToField ??= {for (var f in fields) f.name: f};
    return _nameToField![name];
  }

  @override
  StructField? getFieldByNumber(int number) {
    _numberToField ??= {for (var f in fields) f.number: f};
    return _numberToField![number];
  }

  Map<String, StructField>? _nameToField;
  Map<int, StructField>? _numberToField;
}

/// 🪞 Describes a skir struct.
abstract class ReflectiveStructDescriptor<Frozen, Mutable>
    extends ReflectiveRecordDescriptor<Frozen>
    implements
        _StructDescriptorBase<ReflectiveStructField<Frozen, Mutable, dynamic>> {
  /// Returns a new instance of the generated mutable class for a struct.
  /// Performs a shallow copy of `initializer` if `initializer` is specified.
  Mutable newMutable([Frozen? initializer]);

  /// Converts a mutable struct instance to its frozen (immutable) form.
  Frozen toFrozen(Mutable mutable);

  /// Applies [transformer] to each field value in [struct]. Returns a frozen
  /// struct containing the transformed field values.
  Frozen mapFields(Frozen struct, ReflectiveTransformer transformer) {
    final mutable = newMutable();
    for (final field in fields) {
      field.copy(struct, mutable, transformer: transformer);
    }
    return toFrozen(mutable);
  }

  @override
  ReflectiveStructField<Frozen, Mutable, dynamic>? getFieldByName(String name) {
    _nameToField ??= {for (var f in fields) f.name: f};
    return _nameToField![name];
  }

  @override
  ReflectiveStructField<Frozen, Mutable, dynamic>? getFieldByNumber(
    int number,
  ) {
    _numberToField ??= {for (var f in fields) f.number: f};
    return _numberToField![number];
  }

  Map<String, ReflectiveStructField<Frozen, Mutable, dynamic>>? _nameToField;
  Map<int, ReflectiveStructField<Frozen, Mutable, dynamic>>? _numberToField;

  ReflectiveStructDescriptor._();
}

/// 🪞 Describes a variant in an enum.
sealed class EnumVariant implements FieldOrVariant {}

/// 🪞 Describes a variant in an enum.
sealed class ReflectiveEnumVariant<E> implements FieldOrVariant {}

/// 🪞 Describes an enum constant variant.
class EnumConstantVariant implements EnumVariant {
  /// The variant name.
  @override
  final String name;

  /// The variant number.
  @override
  final int number;

  /// Documentation for this constant, extracted from doc comments in the
  /// '.skir' file.
  @override
  final String doc;

  EnumConstantVariant(this.name, this.number, this.doc);
}

/// 🪞 Describes an enum constant variant.
abstract class ReflectiveEnumConstantVariant<E>
    implements ReflectiveEnumVariant<E> {
  /// The constant value represented by this variant.
  E get constant;

  ReflectiveEnumConstantVariant._();
}

abstract class _EnumWrapperVariantBase<T extends _TypeDescriptorBase>
    implements FieldOrVariant {
  /// The type of the value associated with this enum variant.
  T get type;
}

/// 🪞 Describes an enum wrapper variant.
class EnumWrapperVariant
    implements EnumVariant, _EnumWrapperVariantBase<TypeDescriptor> {
  /// The variant name.
  @override
  final String name;

  /// The variant number.
  @override
  final int number;

  /// The type descriptor for the associated value type.
  @override
  final TypeDescriptor type;

  /// Documentation for this wrapper variant, extracted from doc comments in the
  /// '.skir' file.
  @override
  final String doc;

  EnumWrapperVariant(this.name, this.number, this.type, this.doc);
}

/// 🪞 Describes an enum wrapper variant. Every instance of this variant wraps
/// around a value of type [Value].
abstract class ReflectiveEnumWrapperVariant<E, Value>
    implements
        ReflectiveEnumVariant<E>,
        _EnumWrapperVariantBase<ReflectiveTypeDescriptor<Value>> {
  /// Returns whether the given enum instance is of this wrapper variant.
  bool test(E e);

  /// Extracts the value wrapped  by the given enum instance assuming its variant
  /// matches this variant. Throws an exception if `test(e)` is false.
  Value get(E e);

  /// Extracts the value wrapped by the given enum instance.
  /// Throws an exception if the enum instance is not of this wrapper variant
  /// (i.e., if `test(e)` returns false).
  E wrap(Value value);

  /// Applies [transformer] to the wrapped value and returns a new enum instance
  /// wrapping around it. Throws an exception if `test(e)` is false.
  E mapValue(E e, ReflectiveTransformer transformer);

  ReflectiveEnumWrapperVariant._();
}

/// 🪞 Describes a skir enum.
class EnumDescriptor extends RecordDescriptor
    implements _EnumDescriptorBase<EnumVariant> {
  final _RecordId _recordId;

  @override
  final String doc;

  @override
  final UnmodifiableSetView<int> removedNumbers;

  Iterable<EnumVariant> _variants;

  @override
  Iterable<EnumVariant> get variants => _variants;

  EnumDescriptor._(
    this._recordId,
    this.doc,
    this.removedNumbers,
    this._variants,
  );

  @override
  String get name => _recordId.name;

  @override
  String get qualifiedName => _recordId.qualifiedName;

  @override
  String get modulePath => _recordId.modulePath;

  @override
  EnumVariant? getVariantByName(String name) {
    _nameToVariant ??= {for (var v in variants) v.name: v};
    return _nameToVariant![name];
  }

  @override
  EnumVariant? getVariantByNumber(int number) {
    _numberToVariant ??= {for (var v in variants) v.number: v};
    return _numberToVariant![number];
  }

  Map<String, EnumVariant>? _nameToVariant;
  Map<int, EnumVariant>? _numberToVariant;
}

/// 🪞 Describes a skir enum.
abstract class ReflectiveEnumDescriptor<E> extends ReflectiveRecordDescriptor<E>
    implements _EnumDescriptorBase<ReflectiveEnumVariant<E>> {
  /// Looks up the variant corresponding to the given instance of Enum.
  ReflectiveEnumVariant<E> getVariant(E e);

  /// If [e] wraps around a value (wrapper variant), extracts the value,
  /// transforms it and returns a new enum instance wrapping around it.
  /// Otherwise, returns [e] unchanged.
  E mapValue(E e, ReflectiveTransformer transformer) {
    final variant = getVariant(e);
    if (variant is ReflectiveEnumWrapperVariant<E, dynamic>) {
      return variant.mapValue(e, transformer);
    } else {
      return e;
    }
  }

  @override
  ReflectiveEnumVariant<E>? getVariantByName(String name) {
    _nameToVariant ??= {for (var v in variants) v.name: v};
    return _nameToVariant![name];
  }

  @override
  ReflectiveEnumVariant<E>? getVariantByNumber(int number) {
    _numberToVariant ??= {for (var v in variants) v.number: v};
    return _numberToVariant![number];
  }

  Map<String, ReflectiveEnumVariant<E>>? _nameToVariant;
  Map<int, ReflectiveEnumVariant<E>>? _numberToVariant;

  ReflectiveEnumDescriptor._();
}

/// 🪞 Converts a reflective type descriptor to a non-reflective one.
TypeDescriptor _notReflectiveImpl(
  ReflectiveTypeDescriptor<dynamic> reflective, [
  Map<ReflectiveTypeDescriptor<dynamic>, TypeDescriptor>? inProgress,
]) {
  inProgress ??= {};
  {
    final inProgressResult = inProgress[reflective];
    if (inProgressResult != null) {
      return inProgressResult;
    }
  }
  return switch (reflective) {
    PrimitiveDescriptor() => reflective,
    ReflectiveOptionalDescriptor() => OptionalDescriptor(
        _notReflectiveImpl(reflective.otherType, inProgress),
      ),
    ReflectiveArrayDescriptor() => ArrayDescriptor(
        _notReflectiveImpl(reflective.itemType, inProgress),
        reflective.keyExtractor,
      ),
    ReflectiveStructDescriptor() => () {
        final result = StructDescriptor._(
          _RecordId.parse(_getRecordId(reflective)),
          reflective.doc,
          reflective.removedNumbers,
          [],
        );
        inProgress![reflective] = result;
        result._fields = reflective.fields.map((f) {
          return StructField(
            f.name,
            f.number,
            _notReflectiveImpl(f.type, inProgress),
            f.doc,
          );
        }).toList();
        return result;
      }(),
    ReflectiveEnumDescriptor() => () {
        final result = EnumDescriptor._(
          _RecordId.parse(_getRecordId(reflective)),
          reflective.doc,
          reflective.removedNumbers,
          [],
        );
        inProgress![reflective] = result;
        result._variants = reflective.variants.map((v) {
          if (v is ReflectiveEnumWrapperVariant) {
            return EnumWrapperVariant(
              v.name,
              v.number,
              _notReflectiveImpl(v.type, inProgress),
              v.doc,
            );
          } else {
            return EnumConstantVariant(v.name, v.number, v.doc);
          }
        }).toList();
        return result;
      }(),
  };
}

/// 🪞 Converts this type descriptor to its JSON representation.
Map<String, dynamic> _typeDescriptorAsJsonImpl(TypeDescriptor descriptor) {
  final recordIdToDefinition = <String, Map<String, dynamic>>{};
  _addRecordDefinitions(descriptor, recordIdToDefinition);
  return {
    'type': _getTypeSignature(descriptor),
    'records': recordIdToDefinition.values.toList(),
  };
}

/// 🪞 Converts this type descriptor to its stringified JSON representation.
String _typeDescriptorAsJsonCodeImpl(TypeDescriptor descriptor) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(_typeDescriptorAsJsonImpl(descriptor));
}

Map<String, dynamic> _getTypeSignature(TypeDescriptor typeDescriptor) {
  return switch (typeDescriptor) {
    PrimitiveDescriptor(:final primitiveType) => {
        'kind': 'primitive',
        'value': _primitiveTypeToString(primitiveType),
      },
    OptionalDescriptor(:final otherType) => {
        'kind': 'optional',
        'value': _getTypeSignature(otherType),
      },
    ArrayDescriptor(:final itemType, keyExtractor: final keyExtractor) => () {
        final value = <String, dynamic>{'item': _getTypeSignature(itemType)};
        if ((keyExtractor ?? "").isNotEmpty) {
          value['key_extractor'] = keyExtractor;
        }
        return {'kind': 'array', 'value': value};
      }(), // The `()` immediately calls the anonymous function
    RecordDescriptor(:final modulePath, :final qualifiedName) => {
        'kind': 'record',
        'value': '$modulePath:$qualifiedName',
      },
  };
}

String _primitiveTypeToString(PrimitiveType type) {
  switch (type) {
    case PrimitiveType.bool:
      return 'bool';
    case PrimitiveType.int32:
      return 'int32';
    case PrimitiveType.int64:
      return 'int64';
    case PrimitiveType.hash64:
      return 'hash64';
    case PrimitiveType.float32:
      return 'float32';
    case PrimitiveType.float64:
      return 'float64';
    case PrimitiveType.timestamp:
      return 'timestamp';
    case PrimitiveType.string:
      return 'string';
    case PrimitiveType.bytes:
      return 'bytes';
  }
}

void _addRecordDefinitions(
  TypeDescriptor typeDescriptor,
  Map<String, Map<String, dynamic>> recordIdToDefinition,
) {
  if (typeDescriptor is PrimitiveDescriptor) {
    // No definitions to add
  } else if (typeDescriptor is OptionalDescriptor) {
    _addRecordDefinitions(typeDescriptor.otherType, recordIdToDefinition);
  } else if (typeDescriptor is ArrayDescriptor) {
    _addRecordDefinitions(typeDescriptor.itemType, recordIdToDefinition);
  } else if (typeDescriptor is StructDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    if (recordIdToDefinition.containsKey(recordId)) {
      return;
    }

    final removedNumbers = typeDescriptor.removedNumbers.toList();
    removedNumbers.sort();
    final recordDefinition = _JsonObjectBuilder()
        .put('kind', 'struct')
        .put('id', recordId)
        .putIf("doc", typeDescriptor.doc, (doc) => doc.isNotEmpty)
        .put(
          'fields',
          typeDescriptor.fields
              .map(
                (f) => _JsonObjectBuilder()
                    .put('name', f.name)
                    .put('number', f.number)
                    .put('type', _getTypeSignature(f.type))
                    .putIf("doc", f.doc, (doc) => doc.isNotEmpty)
                    .build(),
              )
              .toList(),
        )
        .putIf(
          "removed_numbers",
          removedNumbers,
          (removedNumbers) => removedNumbers.isNotEmpty,
        )
        .build();
    recordIdToDefinition[recordId] = recordDefinition;

    for (final field in typeDescriptor.fields) {
      _addRecordDefinitions(field.type, recordIdToDefinition);
    }
  } else if (typeDescriptor is EnumDescriptor) {
    final recordId = _getRecordId(typeDescriptor);
    if (recordIdToDefinition.containsKey(recordId)) {
      return;
    }

    final removedNumbers = typeDescriptor.removedNumbers.toList();
    removedNumbers.sort();
    final recordDefinition = _JsonObjectBuilder()
        .put('kind', 'enum')
        .put('id', recordId)
        .putIf("doc", typeDescriptor.doc, (doc) => doc.isNotEmpty)
        .put(
          'variants',
          typeDescriptor.variants
              .map(
                (v) => _JsonObjectBuilder()
                    .put('name', v.name)
                    .put('number', v.number)
                    .putIf(
                      "type",
                      v is EnumWrapperVariant
                          ? _getTypeSignature(v.type)
                          : null,
                      (type) => type != null,
                    )
                    .putIf("doc", v.doc, (doc) => doc.isNotEmpty)
                    .build(),
              )
              .toList(),
        )
        .putIf(
          "removed_numbers",
          removedNumbers,
          (removedNumbers) => removedNumbers.isNotEmpty,
        )
        .build();
    recordIdToDefinition[recordId] = recordDefinition;

    for (final variant in typeDescriptor.variants) {
      if (variant is EnumWrapperVariant) {
        _addRecordDefinitions(variant.type, recordIdToDefinition);
      }
    }
  }
}
