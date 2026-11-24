part of "../skir_client.dart";

/// Parses a type descriptor from its JSON representation.
///
/// This function takes a JSON element containing a serialized type descriptor
/// and reconstructs the corresponding TypeDescriptor object.
///
/// [json] The JSON element containing the type descriptor data
/// Returns the parsed TypeDescriptor
TypeDescriptor _parseTypeDescriptor(dynamic json) {
  final jsonObject = json as Map<String, dynamic>;
  final records = (jsonObject['records'] as List<dynamic>?) ?? [];
  final recordIdToBundle = <String, _RecordBundle>{};

  for (final record in records) {
    final recordObject = record as Map<String, dynamic>;
    final recordDescriptor = _parseRecordDescriptorPartial(recordObject);
    final recordId =
        '${recordDescriptor.modulePath}:${recordDescriptor.qualifiedName}';
    final fields = (recordObject['fields'] as List<dynamic>?) ??
        (recordObject['variants'] as List<dynamic>?) ??
        [];
    recordIdToBundle[recordId] = _RecordBundle(recordDescriptor, fields);
  }

  for (final bundle in recordIdToBundle.values) {
    final recordDescriptor = bundle.recordDescriptor;
    if (recordDescriptor is StructDescriptor) {
      recordDescriptor._fields = bundle.fieldsOrVariants.map((it) {
        final fieldObject = it as Map<String, dynamic>;
        final name = fieldObject['name'] as String;
        final number = fieldObject['number'] as int;
        final type = _parseTypeDescriptorImpl(
          fieldObject['type']!,
          recordIdToBundle,
        );
        final doc = fieldObject['doc'] as String? ?? '';
        return StructField(name, number, type, doc);
      });
    } else if (recordDescriptor is EnumDescriptor) {
      recordDescriptor._variants = bundle.fieldsOrVariants.map((it) {
        final variantObject = it as Map<String, dynamic>;
        final name = variantObject['name'] as String;
        final number = variantObject['number'] as int;
        final typeJson = variantObject['type'];
        final doc = variantObject['doc'] as String? ?? '';
        if (typeJson != null) {
          final type = _parseTypeDescriptorImpl(typeJson, recordIdToBundle);
          return EnumWrapperVariant(name, number, type, doc);
        } else {
          return EnumConstantVariant(name, number, doc);
        }
      });
    }
  }

  final type = jsonObject['type']!;
  return _parseTypeDescriptorImpl(type, recordIdToBundle);
}

class _RecordBundle {
  final RecordDescriptor recordDescriptor;
  final List<dynamic> fieldsOrVariants;

  _RecordBundle(this.recordDescriptor, this.fieldsOrVariants);
}

RecordDescriptor _parseRecordDescriptorPartial(Map<String, dynamic> json) {
  final kind = json['kind'] as String;
  final recordId = _RecordId.parse(json['id'] as String);
  final doc = json['doc'] as String? ?? '';
  final removedNumbers = UnmodifiableSetView(
    (json['removed_numbers'] as List<dynamic>?)
            ?.map((it) => it as int)
            .toSet() ??
        <int>{},
  );

  switch (kind) {
    case 'struct':
      return StructDescriptor._(recordId, doc, removedNumbers, <StructField>[]);
    case 'enum':
      return EnumDescriptor._(recordId, doc, removedNumbers, <EnumVariant>[]);
    default:
      throw ArgumentError('unknown kind: $kind');
  }
}

TypeDescriptor _parseTypeDescriptorImpl(
  dynamic typeSignature,
  Map<String, _RecordBundle> recordIdToBundle,
) {
  final jsonObject = typeSignature as Map<String, dynamic>;
  final kind = jsonObject['kind'] as String;
  final value = jsonObject['value']!;

  switch (kind) {
    case 'primitive':
      final primitiveValue = value as String;
      switch (primitiveValue) {
        case 'bool':
          return BoolDescriptor._();
        case 'int32':
          return Int32Descriptor._();
        case 'int64':
          return Int64Descriptor._();
        case 'hash64':
          return Hash64Descriptor._();
        case 'float32':
          return Float32Descriptor._();
        case 'float64':
          return Float64Descriptor._();
        case 'timestamp':
          return TimestampDescriptor._();
        case 'string':
          return StringDescriptor._();
        case 'bytes':
          return BytesDescriptor._();
        default:
          throw ArgumentError('unknown primitive: $primitiveValue');
      }
    case 'optional':
      return OptionalDescriptor(
        _parseTypeDescriptorImpl(value, recordIdToBundle),
      );
    case 'array':
      final valueObject = value as Map<String, dynamic>;
      final itemType = _parseTypeDescriptorImpl(
        valueObject['item']!,
        recordIdToBundle,
      );
      final keyChain = valueObject['key_extractor'] as String?;
      return ArrayDescriptor(itemType, keyChain);
    case 'record':
      final recordId = value as String;
      final recordBundle = recordIdToBundle[recordId]!;
      return recordBundle.recordDescriptor;
    default:
      throw ArgumentError('unknown type: $kind');
  }
}
