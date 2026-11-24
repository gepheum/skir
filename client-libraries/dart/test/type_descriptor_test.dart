// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'dart:convert';
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

void main() {
  group('PrimitiveType', () {
    test('enum contains all expected primitive types', () {
      expect(PrimitiveType.values, hasLength(9));
      expect(PrimitiveType.values, contains(PrimitiveType.bool));
      expect(PrimitiveType.values, contains(PrimitiveType.int32));
      expect(PrimitiveType.values, contains(PrimitiveType.int64));
      expect(PrimitiveType.values, contains(PrimitiveType.hash64));
      expect(PrimitiveType.values, contains(PrimitiveType.float32));
      expect(PrimitiveType.values, contains(PrimitiveType.float64));
      expect(PrimitiveType.values, contains(PrimitiveType.timestamp));
      expect(PrimitiveType.values, contains(PrimitiveType.string));
      expect(PrimitiveType.values, contains(PrimitiveType.bytes));
    });
  });

  group('PrimitiveDescriptor', () {
    test('asJsonCode produces valid JSON string', () {
      final descriptor = StringDescriptor.instance;
      final jsonCode = descriptor.asJsonCode;

      expect(jsonCode, isA<String>());
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));

      // Should be able to parse back
      expect(() => jsonDecode(jsonCode), returnsNormally);
    });
  });

  group('OptionalDescriptor', () {
    test('wraps another type descriptor', () {
      // Create a simple primitive descriptor for testing
      final innerType = StringDescriptor.instance;
      final optional = OptionalDescriptor(innerType);

      expect(optional.otherType, equals(innerType));
    });

    test('can nest optional types', () {
      final innerType = Float32Descriptor.instance;
      final optionalInner = OptionalDescriptor(innerType);
      final optionalOuter = OptionalDescriptor(optionalInner);

      expect(optionalOuter.otherType, equals(optionalInner));
      expect(
        (optionalOuter.otherType as OptionalDescriptor).otherType,
        equals(innerType),
      );
    });

    test('asJson works correctly for optional types', () {
      final innerType = Int32Descriptor.instance;
      final optional = OptionalDescriptor(innerType);
      final json = optional.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json;
      expect(jsonMap['records'] ?? <dynamic>[], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('optional'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['kind'], equals('primitive'));
      expect(valueMap['value'], equals('int32'));
    });
  });

  group('ReflectiveOptionalDescriptor', () {
    test('asJson works correctly for reflective optional types', () {
      final reflectiveOptional = Serializers.optional(
        Serializers.bool,
      ).typeDescriptor;
      final json = reflectiveOptional.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json;
      expect(jsonMap['records'] ?? <dynamic>[], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('optional'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['kind'], equals('primitive'));
      expect(valueMap['value'], equals('bool'));
    });
  });

  group('ListDescriptor', () {
    test('describes list with item type', () {
      final itemType = StringDescriptor.instance;
      final listDesc = ArrayDescriptor(itemType, null);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyExtractor, isNull);
    });

    test('supports key chain for keyed lists', () {
      final itemType = Int32Descriptor.instance;
      const keyChain = 'id';
      final listDesc = ArrayDescriptor(itemType, keyChain);

      expect(listDesc.itemType, equals(itemType));
      expect(listDesc.keyExtractor, equals(keyChain));
    });

    test('asJson works correctly for list types', () {
      final itemType = Float64Descriptor.instance;
      final listDesc = ArrayDescriptor(itemType, null);
      final json = listDesc.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json;
      expect(jsonMap['records'] ?? <dynamic>[], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('array'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['item'], isA<Map<String, dynamic>>());
      expect(valueMap.containsKey('key_extractor'), isFalse);

      final itemMap = valueMap['item'] as Map<String, dynamic>;
      expect(itemMap['kind'], equals('primitive'));
      expect(itemMap['value'], equals('float64'));
    });

    test('asJson includes key_extractor when present', () {
      final itemType = StringDescriptor.instance;
      const keyChain = 'user_id';
      final listDesc = ArrayDescriptor(itemType, keyChain);
      final json = listDesc.asJson;

      final jsonMap = json;
      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      final valueMap = typeMap['value'] as Map<String, dynamic>;

      expect(valueMap['key_extractor'], equals(keyChain));
    });
  });

  group('ReflectiveArrayDescriptor', () {
    test('asJson works correctly for reflective list types', () {
      final reflectiveArray = Serializers.iterable(
        Serializers.int64,
      ).typeDescriptor;
      final json = reflectiveArray.asJson;

      expect(json, isA<Map<String, dynamic>>());
      final jsonMap = json;
      expect(jsonMap['records'] ?? <dynamic>[], isEmpty);
      expect(jsonMap['type'], isA<Map<String, dynamic>>());

      final typeMap = jsonMap['type'] as Map<String, dynamic>;
      expect(typeMap['kind'], equals('array'));
      expect(typeMap['value'], isA<Map<String, dynamic>>());

      final valueMap = typeMap['value'] as Map<String, dynamic>;
      expect(valueMap['item'], isA<Map<String, dynamic>>());

      final itemMap = valueMap['item'] as Map<String, dynamic>;
      expect(itemMap['kind'], equals('primitive'));
      expect(itemMap['value'], equals('int64'));
    });
  });

  group('StructField', () {
    test('creates field with name, number, and type', () {
      const name = 'username';
      const number = 1;
      final type = StringDescriptor.instance;
      final field = StructField(name, number, type, "the doc");

      expect(field.name, equals(name));
      expect(field.number, equals(number));
      expect(field.type, equals(type));
      expect(field.doc, equals("the doc"));
    });
  });

  group('EnumConstantField', () {
    test('creates constant field with name and number', () {
      const name = 'ACTIVE';
      const number = 1;
      final field = EnumConstantVariant(name, number, "the doc");

      expect(field.name, equals(name));
      expect(field.number, equals(number));
      expect(field.doc, equals("the doc"));
    });
  });

  group('EnumWrapperField', () {
    test('creates wrapper field with name, number, and type', () {
      const name = 'custom_value';
      const number = 100;
      final type = Int32Descriptor.instance;
      final field = EnumWrapperVariant(name, number, type, "the doc");

      expect(field.name, equals(name));
      expect(field.number, equals(number));
      expect(field.type, equals(type));
      expect(field.doc, equals("the doc"));
    });
  });

  group('TypeDescriptor JSON parsing', () {
    test('parseFromJsonCode creates descriptor from JSON string', () {
      const jsonCode = '''
      {
        "records": [],
        "type": {
          "kind": "primitive",
          "value": "string"
        }
      }
      ''';

      final descriptor = TypeDescriptor.parseFromJsonCode(jsonCode);

      expect(descriptor, isA<PrimitiveDescriptor>());
      final primitiveDesc = descriptor as PrimitiveDescriptor;
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.string));
    });

    test('parseFromJson creates descriptor from JSON object', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'primitive', 'value': 'int32'},
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<PrimitiveDescriptor>());
      final primitiveDesc = descriptor as PrimitiveDescriptor;
      expect(primitiveDesc.primitiveType, equals(PrimitiveType.int32));
    });

    test('parseFromJson handles optional types', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'optional',
          'value': {'kind': 'primitive', 'value': 'bool'},
        },
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<OptionalDescriptor>());
      final optionalDesc = descriptor as OptionalDescriptor;
      expect(optionalDesc.otherType, isA<PrimitiveDescriptor>());
      final innerDesc = optionalDesc.otherType as PrimitiveDescriptor;
      expect(innerDesc.primitiveType, equals(PrimitiveType.bool));
    });

    test('parseFromJson handles array types', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'array',
          'value': {
            'item': {'kind': 'primitive', 'value': 'float64'},
          },
        },
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<ArrayDescriptor>());
      final listDesc = descriptor as ArrayDescriptor;
      expect(listDesc.itemType, isA<PrimitiveDescriptor>());
      expect(listDesc.keyExtractor, isNull);

      final itemDesc = listDesc.itemType as PrimitiveDescriptor;
      expect(itemDesc.primitiveType, equals(PrimitiveType.float64));
    });

    test('parseFromJson handles array types with key chain', () {
      final json = {
        'records': <dynamic>[],
        'type': {
          'kind': 'array',
          'value': {
            'item': {'kind': 'primitive', 'value': 'string'},
            'key_extractor': 'id',
          },
        },
      };

      final descriptor = TypeDescriptor.parseFromJson(json);

      expect(descriptor, isA<ArrayDescriptor>());
      final listDesc = descriptor as ArrayDescriptor;
      expect(listDesc.keyExtractor, equals('id'));
    });

    test('parseFromJson handles all primitive types', () {
      final primitiveTestCases = {
        'bool': PrimitiveType.bool,
        'int32': PrimitiveType.int32,
        'int64': PrimitiveType.int64,
        'hash64': PrimitiveType.hash64,
        'float32': PrimitiveType.float32,
        'float64': PrimitiveType.float64,
        'timestamp': PrimitiveType.timestamp,
        'string': PrimitiveType.string,
        'bytes': PrimitiveType.bytes,
      };

      for (final entry in primitiveTestCases.entries) {
        final json = {
          'records': <dynamic>[],
          'type': {'kind': 'primitive', 'value': entry.key},
        };

        final descriptor = TypeDescriptor.parseFromJson(json);
        expect(descriptor, isA<PrimitiveDescriptor>());

        final primitiveDesc = descriptor as PrimitiveDescriptor;
        expect(
          primitiveDesc.primitiveType,
          equals(entry.value),
          reason: 'Failed for primitive type: ${entry.key}',
        );
      }
    });
  });

  group('Error handling', () {
    test('parseFromJson throws on unknown primitive type', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'primitive', 'value': 'unknown_type'},
      };

      expect(() => TypeDescriptor.parseFromJson(json), throwsArgumentError);
    });

    test('parseFromJson throws on unknown type kind', () {
      final json = {
        'records': <dynamic>[],
        'type': {'kind': 'unknown_kind', 'value': 'something'},
      };

      expect(() => TypeDescriptor.parseFromJson(json), throwsArgumentError);
    });

    test('parseFromJsonCode throws on invalid JSON', () {
      const invalidJson = '{ invalid json }';

      expect(
        () => TypeDescriptor.parseFromJsonCode(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Complex type structures', () {
    test('can create nested complex types', () {
      // Create a complex nested type: List<Optional<String>>
      final stringType = StringDescriptor.instance;
      final optionalString = OptionalDescriptor(stringType);
      final listOfOptionalStrings = ArrayDescriptor(optionalString, 'key');

      expect(listOfOptionalStrings.itemType, equals(optionalString));
      expect(listOfOptionalStrings.keyExtractor, equals('key'));
      expect(optionalString.otherType, equals(stringType));
    });

    test('field types work correctly', () {
      final stringType = StringDescriptor.instance;
      final structField = StructField('name', 1, stringType, "the doc");
      final enumWrapperField = EnumWrapperVariant(
        'value',
        2,
        stringType,
        "the doc",
      );
      final enumConstantField = EnumConstantVariant('CONSTANT', 3, "the doc");

      expect(structField.type, equals(stringType));
      expect(enumWrapperField.type, equals(stringType));
      expect(enumConstantField.name, equals('CONSTANT'));
      expect(enumConstantField.number, equals(3));
      expect(structField.doc, equals("the doc"));
      expect(enumWrapperField.doc, equals("the doc"));
      expect(enumConstantField.doc, equals("the doc"));
    });

    test('asJson works for complex nested types without infinite loops', () {
      // This test specifically verifies that the infinite loop bug has been fixed
      final stringType = StringDescriptor.instance;
      final optionalString = OptionalDescriptor(stringType);
      final listOfOptionalStrings = ArrayDescriptor(optionalString, 'key');

      // These calls should complete without infinite loops
      final json = listOfOptionalStrings.asJson;
      final jsonCode = listOfOptionalStrings.asJsonCode;

      expect(json, isA<Map<String, dynamic>>());
      expect(jsonCode, isA<String>());
      expect(jsonCode, contains('"kind": "array"'));
      expect(jsonCode, contains('"kind": "optional"'));
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));
      expect(jsonCode, contains('"key_extractor": "key"'));

      // Should be able to parse back to verify valid JSON
      final parsedJson = jsonDecode(jsonCode);
      expect(parsedJson, isA<Map<String, dynamic>>());
    });

    test('asJsonCode produces properly formatted JSON', () {
      final boolType = BoolDescriptor.instance;
      final optionalBool = OptionalDescriptor(boolType);

      final jsonCode = optionalBool.asJsonCode;

      // Should be pretty-printed JSON
      expect(jsonCode, contains('\n'));
      expect(jsonCode, contains('  '));

      // Should be parseable
      final parsed = jsonDecode(jsonCode);
      expect(parsed, isA<Map<String, dynamic>>());

      final parsedMap = parsed as Map<String, dynamic>;
      expect(parsedMap['records'] ?? <dynamic>[], isA<List>());
      expect(parsedMap['type'], isA<Map<String, dynamic>>());
    });
  });

  group('Infinite loop regression tests', () {
    test('primitive asJson does not cause infinite loop', () {
      final descriptor = StringDescriptor.instance;

      // This should complete quickly without hanging
      final json = descriptor.asJson;
      final jsonCode = descriptor.asJsonCode;

      expect(json, isNotNull);
      expect(jsonCode, isNotNull);
      expect(jsonCode, contains('"kind": "primitive"'));
      expect(jsonCode, contains('"value": "string"'));
    });

    test('multiple calls to asJson work correctly', () {
      final descriptor = Int32Descriptor.instance;

      // Multiple calls should all work without issues
      final json1 = descriptor.asJson;
      final json2 = descriptor.asJson;
      final jsonCode1 = descriptor.asJsonCode;
      final jsonCode2 = descriptor.asJsonCode;

      expect(json1, equals(json2));
      expect(jsonCode1, equals(jsonCode2));
    });

    test('all primitive types work with asJson', () {
      // Test that every primitive type can successfully generate JSON
      for (final descriptor in [
        Int32Descriptor.instance,
        Int64Descriptor.instance,
        Hash64Descriptor.instance,
        BoolDescriptor.instance,
        Float32Descriptor.instance,
        Float64Descriptor.instance,
        TimestampDescriptor.instance,
        StringDescriptor.instance,
        BytesDescriptor.instance,
      ]) {
        // These should all complete without infinite loops
        expect(() => descriptor.asJson, returnsNormally);
        expect(() => descriptor.asJsonCode, returnsNormally);

        final json = descriptor.asJson;
        expect(json, isA<Map<String, dynamic>>());

        final jsonCode = descriptor.asJsonCode;
        expect(jsonCode, isA<String>());
        expect(jsonCode.length, greaterThan(0));
      }
    });
  });
}
