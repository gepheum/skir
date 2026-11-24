// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

// Test data structures
class PersonFrozen {
  final String name;
  final int age;
  final String? email;
  final bool isActive;
  final List<String> tags;
  final internal__UnrecognizedFields? unrecognizedFields;

  const PersonFrozen({
    this.name = '',
    this.age = 0,
    this.email,
    this.isActive = false,
    this.tags = const [],
    this.unrecognizedFields,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonFrozen &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age &&
          email == other.email &&
          isActive == other.isActive &&
          _listEquals(tags, other.tags) &&
          unrecognizedFields == other.unrecognizedFields;

  @override
  int get hashCode =>
      name.hashCode ^
      age.hashCode ^
      email.hashCode ^
      isActive.hashCode ^
      tags.hashCode ^
      unrecognizedFields.hashCode;
}

class PersonMutable {
  String name;
  int age;
  String? email;
  bool isActive;
  List<String> tags;
  internal__UnrecognizedFields? unrecognizedFields;

  PersonMutable({
    this.name = '',
    this.age = 0,
    this.email,
    this.isActive = false,
    this.tags = const [],
    this.unrecognizedFields,
  });
}

// Helper function to compare lists
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  group('StructSerializerBuilder', () {
    const defaultPerson = PersonFrozen();
    late internal__StructSerializerBuilder<PersonFrozen, PersonMutable>
        personBuilder;
    late Serializer<PersonFrozen> personSerializer;

    setUp(() {
      personBuilder =
          internal__StructSerializerBuilder<PersonFrozen, PersonMutable>(
        recordId: 'foo:Person',
        doc: "A person",
        defaultInstance: defaultPerson,
        newMutable: (frozen) => PersonMutable(
          name: frozen?.name ?? '',
          age: frozen?.age ?? 0,
          email: frozen?.email,
          isActive: frozen?.isActive ?? false,
          tags: List.from(frozen?.tags ?? <dynamic>[]),
          unrecognizedFields: frozen?.unrecognizedFields,
        ),
        toFrozen: (mutable) => PersonFrozen(
          name: mutable.name,
          age: mutable.age,
          email: mutable.email,
          isActive: mutable.isActive,
          tags: mutable.tags,
          unrecognizedFields: mutable.unrecognizedFields,
        ),
        getUnrecognizedFields: (frozen) => frozen.unrecognizedFields,
        setUnrecognizedFields: (mutable, fields) {
          mutable.unrecognizedFields = fields;
        },
      );

      // Add fields in order by field number
      personBuilder.addField(
        'name',
        'name',
        0,
        Serializers.string,
        "Person's name",
        (person) => person.name,
        (mutable, value) => mutable.name = value,
      );
      personBuilder.addField(
        'age',
        'age',
        1,
        Serializers.int32,
        "",
        (person) => person.age,
        (mutable, value) => mutable.age = value,
      );
      personBuilder.addField(
        'email',
        'email',
        2,
        Serializers.optional(Serializers.string),
        "",
        (person) => person.email,
        (mutable, value) => mutable.email = value,
      );
      personBuilder.addField(
        'is_active',
        'isActive',
        3,
        Serializers.bool,
        "",
        (person) => person.isActive,
        (mutable, value) => mutable.isActive = value,
      );
      personBuilder.addField(
        'tags',
        'tags',
        4,
        Serializers.iterable(Serializers.string),
        "",
        (person) => person.tags,
        (mutable, value) => mutable.tags = List.from(value),
      );
      personBuilder.finalize();

      personSerializer = personBuilder.serializer;
    });

    test('struct serializer - basic serialization', () {
      // Test JSON serialization - default should be empty array/object
      final defaultDenseJson = personSerializer.toJson(
        defaultPerson,
        readableFlavor: false,
      );
      expect(defaultDenseJson, isA<List>());
      expect((defaultDenseJson as List), isEmpty);

      final defaultReadableJson = personSerializer.toJson(
        defaultPerson,
        readableFlavor: true,
      );
      expect(defaultReadableJson, isA<Map>());
      expect((defaultReadableJson as Map), isEmpty);

      // Test with empty array which should work
      final restoredFromArray = personSerializer.fromJson(
        [],
        keepUnrecognizedValues: false,
      );
      expect(restoredFromArray, equals(defaultPerson));
    });

    test('struct serializer - dense JSON format', () {
      final person = PersonFrozen(
        name: 'Alice',
        age: 30,
        email: 'alice@example.com',
        isActive: true,
        tags: ['developer', 'kotlin'],
      );

      // Test dense JSON - should be an array
      final denseJson = personSerializer.toJson(person, readableFlavor: false);
      expect(denseJson, isA<List>());

      final jsonArray = denseJson as List<dynamic>;
      expect(jsonArray[0], equals('Alice'));
      expect(jsonArray[1], equals(30));
      expect(jsonArray[2], equals('alice@example.com'));
      expect(jsonArray[3], equals(1)); // bool dense format
      expect(jsonArray[4], isA<List>()); // tags array

      // Test roundtrip
      final restored = personSerializer.fromJson(
        denseJson,
        keepUnrecognizedValues: false,
      );
      expect(restored.name, equals(person.name));
      expect(restored.age, equals(person.age));
      expect(restored.email, equals(person.email));
      expect(restored.isActive, equals(person.isActive));
      expect(restored.tags, equals(person.tags));
    });

    test('struct serializer - readable JSON format', () {
      final person = PersonFrozen(
        name: 'Bob',
        age: 25,
        email: null,
        isActive: true,
        tags: ['tester'],
      );

      // Test readable JSON - should be an object with only non-default values
      final readableJson = personSerializer.toJson(
        person,
        readableFlavor: true,
      );
      expect(readableJson, isA<Map>());

      final jsonObject = readableJson as Map<String, dynamic>;
      expect(jsonObject, containsPair('name', 'Bob'));
      expect(jsonObject, containsPair('age', 25));
      expect(
        jsonObject.containsKey('email'),
        isFalse,
      ); // null/default value should be omitted
      expect(jsonObject, containsPair('is_active', true));
      expect(jsonObject, containsPair('tags', ['tester']));

      // Test roundtrip
      final restored = personSerializer.fromJson(
        readableJson,
        keepUnrecognizedValues: false,
      );
      expect(restored.name, equals(person.name));
      expect(restored.age, equals(person.age));
      expect(restored.email, equals(person.email));
      expect(restored.isActive, equals(person.isActive));
      expect(restored.tags, equals(person.tags));
    });

    test('struct serializer - binary format roundtrip', () {
      final testPerson = PersonFrozen(
        name: 'John Doe',
        age: 42,
        email: 'john.doe@example.com',
        isActive: true,
        tags: ['senior', 'architect', 'kotlin'],
      );

      // Test binary roundtrip
      final bytes = personSerializer.toBytes(testPerson);
      final restoredFromBinary = personSerializer.fromBytes(bytes);

      expect(restoredFromBinary.name, equals(testPerson.name));
      expect(restoredFromBinary.age, equals(testPerson.age));
      expect(restoredFromBinary.email, equals(testPerson.email));
      expect(restoredFromBinary.isActive, equals(testPerson.isActive));
      expect(restoredFromBinary.tags, equals(testPerson.tags));
    });

    test('struct serializer - all field types roundtrip', () {
      final testPerson = PersonFrozen(
        name: 'John Doe',
        age: 42,
        email: 'john.doe@example.com',
        isActive: true,
        tags: ['senior', 'architect', 'kotlin'],
      );

      // Test JSON roundtrip with both flavors
      final denseJson = personSerializer.toJsonCode(
        testPerson,
        readableFlavor: false,
      );
      final readableJson = personSerializer.toJsonCode(
        testPerson,
        readableFlavor: true,
      );

      final restoredFromDense = personSerializer.fromJsonCode(denseJson);
      final restoredFromReadable = personSerializer.fromJsonCode(readableJson);

      // Both should restore to the same object
      expect(restoredFromDense.name, equals(testPerson.name));
      expect(restoredFromDense.age, equals(testPerson.age));
      expect(restoredFromDense.email, equals(testPerson.email));
      expect(restoredFromDense.isActive, equals(testPerson.isActive));
      expect(restoredFromDense.tags, equals(testPerson.tags));

      expect(restoredFromReadable.name, equals(testPerson.name));
      expect(restoredFromReadable.age, equals(testPerson.age));
      expect(restoredFromReadable.email, equals(testPerson.email));
      expect(restoredFromReadable.isActive, equals(testPerson.isActive));
      expect(restoredFromReadable.tags, equals(testPerson.tags));
    });

    test('struct serializer - error cases', () {
      // Test that finalize() can only be called once
      final testBuilder =
          internal__StructSerializerBuilder<PersonFrozen, PersonMutable>(
        recordId: 'foo:Person',
        doc: "A person",
        defaultInstance: defaultPerson,
        newMutable: (frozen) => PersonMutable(),
        toFrozen: (mutable) => PersonFrozen(),
        getUnrecognizedFields: (frozen) => null,
        setUnrecognizedFields: (mutable, fields) {},
      );

      testBuilder.addField(
        'name',
        'name',
        0,
        Serializers.string,
        "Person's name",
        (person) => person.name,
        (mutable, value) => mutable.name = value,
      );

      testBuilder.finalize();

      // Adding fields after finalization should throw
      expect(
        () => testBuilder.addField(
          'age',
          'age',
          1,
          Serializers.int32,
          "",
          (person) => person.age,
          (mutable, value) => mutable.age = value,
        ),
        throwsStateError,
      );

      // Adding removed numbers after finalization should throw
      expect(() => testBuilder.addRemovedNumber(5), throwsStateError);

      // Double finalization should throw
      expect(() => testBuilder.finalize(), throwsStateError);
    });

    test('.serializer field access', () {
      // Test that the serializer field is accessible and works correctly
      final builder =
          internal__StructSerializerBuilder<PersonFrozen, PersonMutable>(
        recordId: 'test:Person',
        doc: "A person",
        defaultInstance: defaultPerson,
        newMutable: (frozen) => PersonMutable(
          name: frozen?.name ?? '',
          age: frozen?.age ?? 0,
          email: frozen?.email,
          isActive: frozen?.isActive ?? false,
          tags: List.from(frozen?.tags ?? <dynamic>[]),
          unrecognizedFields: frozen?.unrecognizedFields,
        ),
        toFrozen: (mutable) => PersonFrozen(
          name: mutable.name,
          age: mutable.age,
          email: mutable.email,
          isActive: mutable.isActive,
          tags: mutable.tags,
          unrecognizedFields: mutable.unrecognizedFields,
        ),
        getUnrecognizedFields: (frozen) => null,
        setUnrecognizedFields: (mutable, fields) {},
      );

      builder.addField(
        'name',
        'name',
        0,
        Serializers.string,
        "Person's name",
        (person) => person.name,
        (mutable, value) => mutable.name = value,
      );
      builder.finalize();

      final serializer = builder.serializer;
      expect(serializer, isA<Serializer<PersonFrozen>>());

      // Test that the serializer works
      const testPerson = PersonFrozen(name: 'Test');
      final json = serializer.toJsonCode(testPerson);
      final restored = serializer.fromJsonCode(json);
      expect(restored.name, equals('Test'));
    });

    test('builder state management', () {
      final builder =
          internal__StructSerializerBuilder<PersonFrozen, PersonMutable>(
        recordId: 'test:Person',
        doc: "A person",
        defaultInstance: defaultPerson,
        newMutable: (frozen) => PersonMutable(
          name: frozen?.name ?? '',
          age: frozen?.age ?? 0,
          email: frozen?.email,
          isActive: frozen?.isActive ?? false,
          tags: List.from(frozen?.tags ?? <dynamic>[]),
          unrecognizedFields: frozen?.unrecognizedFields,
        ),
        toFrozen: (mutable) => PersonFrozen(
          name: mutable.name,
          age: mutable.age,
          email: mutable.email,
          isActive: mutable.isActive,
          tags: mutable.tags,
          unrecognizedFields: mutable.unrecognizedFields,
        ),
        getUnrecognizedFields: (frozen) => null,
        setUnrecognizedFields: (mutable, fields) {},
      );

      // Should be able to add fields before finalization
      builder.addField(
        'name',
        'name',
        0,
        Serializers.string,
        "Person's name",
        (person) => person.name,
        (mutable, value) => mutable.name = value,
      );

      // Should be able to add removed numbers before finalization
      builder.addRemovedNumber(5);

      // Should be able to access serializer before finalization
      final serializer1 = builder.serializer;
      expect(serializer1, isA<Serializer<PersonFrozen>>());

      // Finalize the builder
      builder.finalize();

      // Should still be able to access serializer after finalization
      final serializer2 = builder.serializer;
      expect(serializer2, isA<Serializer<PersonFrozen>>());

      // Note: In Dart implementation, serializers may not be identical instances
      // but they should have the same functionality

      // Should not be able to add fields after finalization
      expect(
        () => builder.addField(
          'age',
          'age',
          1,
          Serializers.int32,
          "Person's age",
          (person) => person.age,
          (mutable, value) => mutable.age = value,
        ),
        throwsStateError,
      );

      // Should not be able to add removed numbers after finalization
      expect(() => builder.addRemovedNumber(6), throwsStateError);

      // Should not be able to finalize again
      expect(() => builder.finalize(), throwsStateError);
    });

    test('struct serializer - type descriptor', () {
      final typeDescriptor = personSerializer.typeDescriptor;
      final actualJson = typeDescriptor.asJsonCode;

      // Test that type descriptor is properly formed
      expect(actualJson, contains('"id": "foo:Person"'));
      expect(actualJson, contains('"kind": "struct"'));
      expect(actualJson, contains('"name": "name"'));
      expect(actualJson, contains('"name": "age"'));
      expect(actualJson, contains('"name": "email"'));
      expect(actualJson, contains('"name": "is_active"'));
      expect(actualJson, contains('"name": "tags"'));
      expect(actualJson, contains('"doc": "A person"'));
      expect(actualJson, contains('"doc": "Person\'s name"'));

      // Test that parsing the type descriptor works
      final parsed = TypeDescriptor.parseFromJson(typeDescriptor.asJson);
      expect(parsed.asJsonCode, equals(actualJson));
    });
  });
}
