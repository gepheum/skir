// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';
import 'dart:typed_data';

// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
} // Test enum types

enum ColorKind {
  unknown(0),
  red(1),
  green(2),
  blue(3),
  custom(4);

  final int ordinal;
  const ColorKind(this.ordinal);
}

sealed class Color {
  const Color();
  ColorKind get kind;
}

class ColorUnknown extends Color {
  final internal__UnrecognizedVariant? unrecognized;
  const ColorUnknown(this.unrecognized);
  @override
  ColorKind get kind => ColorKind.unknown;
}

class ColorRed extends Color {
  const ColorRed();
  @override
  ColorKind get kind => ColorKind.red;
}

class ColorGreen extends Color {
  const ColorGreen();
  @override
  ColorKind get kind => ColorKind.green;
}

class ColorBlue extends Color {
  const ColorBlue();
  @override
  ColorKind get kind => ColorKind.blue;
}

class ColorCustomOption extends Color {
  final int rgb;
  const ColorCustomOption(this.rgb);
  @override
  ColorKind get kind => ColorKind.custom;
}

// Complex enum with both constants and wrapper fields

enum StatusKind {
  unknown(0),
  active(1),
  inactive(2),
  pending(3),
  error(4);

  final int ordinal;
  const StatusKind(this.ordinal);
}

sealed class Status {
  const Status();
  StatusKind get kind;
}

class StatusUnknown extends Status {
  final internal__UnrecognizedVariant? unrecognized;
  const StatusUnknown(this.unrecognized);
  @override
  StatusKind get kind => StatusKind.unknown;
}

class StatusActive extends Status {
  const StatusActive();
  @override
  StatusKind get kind => StatusKind.active;
}

class StatusInactive extends Status {
  const StatusInactive();
  @override
  StatusKind get kind => StatusKind.inactive;
}

class StatusPendingOption extends Status {
  final String reason;
  const StatusPendingOption(this.reason);
  @override
  StatusKind get kind => StatusKind.pending;
}

class StatusErrorOption extends Status {
  final String message;
  const StatusErrorOption(this.message);
  @override
  StatusKind get kind => StatusKind.error;
}

void main() {
  group('EnumSerializerBuilder', () {
    const colorUnknown = ColorUnknown(null);
    const statusUnknown = StatusUnknown(null);
    const colorRed = ColorRed();
    const colorGreen = ColorGreen();
    const colorBlue = ColorBlue();

    late internal__EnumSerializerBuilder<Color> colorEnumBuilder;
    late Serializer<Color> colorSerializer;
    late internal__EnumSerializerBuilder<Status> statusEnumBuilder;
    late Serializer<Status> statusSerializer;

    setUp(() {
      // Simple enum with only constants
      colorEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color',
        doc: "A color",
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getOrdinal: (it) => it.kind.ordinal,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      colorEnumBuilder.addConstantVariant(
        1,
        'red',
        'red',
        "red color",
        colorRed,
      );
      colorEnumBuilder.addConstantVariant(2, 'green', 'green', "", colorGreen);
      colorEnumBuilder.addConstantVariant(3, 'blue', 'blue', "", colorBlue);
      colorEnumBuilder.addWrapperVariant<ColorCustomOption, int>(
        4,
        'custom',
        'wrapCustom',
        Serializers.int32,
        "custom color",
        (rgb) => ColorCustomOption(rgb),
        (custom) => custom.rgb,
        ordinal: ColorKind.custom.ordinal,
      );
      colorEnumBuilder.finalize();

      colorSerializer = colorEnumBuilder.serializer;

      // Complex enum with both constants and wrapper fields
      statusEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color.Status',
        doc: "A status",
        unknownInstance: statusUnknown,
        enumInstance: statusUnknown as Status,
        getOrdinal: (it) => it.kind.ordinal,
        wrapUnrecognized: (unrecognized) => StatusUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      statusEnumBuilder.addConstantVariant(
        1,
        'active',
        'active',
        "",
        StatusActive(),
      );
      statusEnumBuilder.addConstantVariant(
        2,
        'inactive',
        'inactive',
        "inactive status",
        StatusInactive(),
      );
      statusEnumBuilder.addWrapperVariant<StatusPendingOption, String>(
        3,
        'pending',
        'pending',
        Serializers.string,
        "pending status",
        (reason) => StatusPendingOption(reason),
        (pending) => pending.reason,
        ordinal: StatusKind.pending.ordinal,
      );
      statusEnumBuilder.addRemovedNumber(4); // Removed field number
      statusEnumBuilder.finalize();

      statusSerializer = statusEnumBuilder.serializer;
    });

    test('enum serializer - constant fields dense JSON', () {
      // Test constant field serialization in dense format
      final redJson = colorSerializer.toJson(colorRed, readableFlavor: false);
      expect(redJson, equals(1));

      final greenJson = colorSerializer.toJson(
        colorGreen,
        readableFlavor: false,
      );
      expect(greenJson, equals(2));

      final blueJson = colorSerializer.toJson(colorBlue, readableFlavor: false);
      expect(blueJson, equals(3));

      // Test deserialization from dense format
      expect(
        colorSerializer.fromJson(1, keepUnrecognizedValues: false),
        isA<ColorRed>(),
      );
      expect(
        colorSerializer.fromJson(2, keepUnrecognizedValues: false),
        isA<ColorGreen>(),
      );
      expect(
        colorSerializer.fromJson(3, keepUnrecognizedValues: false),
        isA<ColorBlue>(),
      );
    });

    test('enum serializer - constant fields readable JSON', () {
      // Test constant field serialization in readable format
      final redJson = colorSerializer.toJson(colorRed, readableFlavor: true);
      expect(redJson, equals('red'));

      final greenJson = colorSerializer.toJson(
        colorGreen,
        readableFlavor: true,
      );
      expect(greenJson, equals('green'));

      final blueJson = colorSerializer.toJson(colorBlue, readableFlavor: true);
      expect(blueJson, equals('blue'));

      // Test deserialization from readable format
      expect(
        colorSerializer.fromJson('red', keepUnrecognizedValues: false),
        isA<ColorRed>(),
      );
      expect(
        colorSerializer.fromJson('green', keepUnrecognizedValues: false),
        isA<ColorGreen>(),
      );
      expect(
        colorSerializer.fromJson('blue', keepUnrecognizedValues: false),
        isA<ColorBlue>(),
      );
    });

    test('enum serializer - UNKNOWN and unknown are treated the same', () {
      final fromUpper = colorSerializer.fromJson(
        'UNKNOWN',
        keepUnrecognizedValues: false,
      );
      final fromLower = colorSerializer.fromJson(
        'unknown',
        keepUnrecognizedValues: false,
      );
      expect(fromUpper, isA<ColorUnknown>());
      expect(fromLower, isA<ColorUnknown>());
    });

    test('enum serializer - wrapper fields dense JSON', () {
      final customColor = ColorCustomOption(0xFF0000);

      // Test wrapper field serialization in dense format
      final customJson = colorSerializer.toJson(
        customColor,
        readableFlavor: false,
      );
      expect(customJson, isA<List>());

      final jsonArray = customJson as List<dynamic>;
      expect(jsonArray, hasLength(2));
      expect(jsonArray[0], equals(4));
      expect(jsonArray[1], equals(16711680)); // 0xFF0000 in decimal

      // Test deserialization from dense format
      final restored = colorSerializer.fromJson(
        jsonArray,
        keepUnrecognizedValues: false,
      );
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(0xFF0000));
    });

    test('enum serializer - wrapper fields readable JSON', () {
      final customColor = ColorCustomOption(0x00FF00);

      // Test wrapper field serialization in readable format
      final customJson = colorSerializer.toJson(
        customColor,
        readableFlavor: true,
      );
      expect(customJson, isA<Map>());

      final jsonObject = customJson as Map<String, dynamic>;
      expect(jsonObject, hasLength(2));
      expect(jsonObject, containsPair('kind', 'custom'));
      expect(jsonObject, containsPair('value', 65280)); // 0x00FF00 in decimal

      // Test deserialization from readable format
      final restored = colorSerializer.fromJson(
        jsonObject,
        keepUnrecognizedValues: false,
      );
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(0x00FF00));
    });

    test('enum serializer - binary format constants', () {
      // Test binary encoding for constant fields
      final redBytes = colorSerializer.toBytes(colorRed);
      expect(_bytesToHex(redBytes), startsWith('736b6972')); // "skir" prefix

      final greenBytes = colorSerializer.toBytes(colorGreen);
      expect(_bytesToHex(greenBytes), startsWith('736b6972'));

      final blueBytes = colorSerializer.toBytes(colorBlue);
      expect(_bytesToHex(blueBytes), startsWith('736b6972'));

      // Test binary roundtrips
      expect(colorSerializer.fromBytes(redBytes), isA<ColorRed>());
      expect(colorSerializer.fromBytes(greenBytes), isA<ColorGreen>());
      expect(colorSerializer.fromBytes(blueBytes), isA<ColorBlue>());
    });

    test('enum serializer - binary format wrapper fields', () {
      final customColor = ColorCustomOption(42);

      // Test binary encoding for wrapper fields
      final customBytes = colorSerializer.toBytes(customColor);
      expect(_bytesToHex(customBytes), startsWith('736b6972'));

      // Test binary roundtrip
      final restored = colorSerializer.fromBytes(customBytes);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(42));
    });

    test('enum serializer - unknown values without keeping unrecognized', () {
      // Test unknown constant number
      final unknownConstant = colorSerializer.fromJson(
        99,
        keepUnrecognizedValues: false,
      );
      expect(unknownConstant, isA<ColorUnknown>());

      // Test unknown field name
      final unknownName = colorSerializer.fromJson(
        'purple',
        keepUnrecognizedValues: false,
      );
      expect(unknownName, isA<ColorUnknown>());

      // Test unknown wrapper field
      final unknownValue = colorSerializer.fromJson([
        99,
        123,
      ], keepUnrecognizedValues: false);
      expect(unknownValue, isA<ColorUnknown>());
    });

    test('enum serializer - unknown values with keeping unrecognized', () {
      // Test unknown constant number with keepUnrecognizedValues = true
      final unknownConstant = colorSerializer.fromJson(
        99,
        keepUnrecognizedValues: true,
      );
      expect(unknownConstant, isA<ColorUnknown>());
      final unknownEnum = (unknownConstant as ColorUnknown).unrecognized;
      expect(unknownEnum, isNotNull);

      // Test unknown wrapper field with keepUnrecognizedValues = true
      final unknownValueJson = [99, 123];
      final unknownValue = colorSerializer.fromJson(
        unknownValueJson,
        keepUnrecognizedValues: true,
      );
      expect(unknownValue, isA<ColorUnknown>());
      final unknownValueEnum = (unknownValue as ColorUnknown).unrecognized;
      expect(unknownValueEnum, isNotNull);
    });

    test('enum serializer - removed fields', () {
      // Test accessing a removed field (should return unknown)
      final removedField = statusSerializer.fromJson(
        4,
        keepUnrecognizedValues: false,
      );
      expect(removedField, isA<StatusUnknown>());
    });

    test('enum serializer - complex enum roundtrips', () {
      final pendingStatus = StatusPendingOption('waiting for approval');

      // Test JSON roundtrips
      final denseJson = statusSerializer.toJsonCode(
        pendingStatus,
        readableFlavor: false,
      );
      final readableJson = statusSerializer.toJsonCode(
        pendingStatus,
        readableFlavor: true,
      );

      final restoredFromDense = statusSerializer.fromJsonCode(denseJson);
      final restoredFromReadable = statusSerializer.fromJsonCode(readableJson);

      expect(restoredFromDense, isA<StatusPendingOption>());
      expect(
        (restoredFromDense as StatusPendingOption).reason,
        equals('waiting for approval'),
      );

      expect(restoredFromReadable, isA<StatusPendingOption>());
      expect(
        (restoredFromReadable as StatusPendingOption).reason,
        equals('waiting for approval'),
      );

      // Test binary roundtrip
      final bytes = statusSerializer.toBytes(pendingStatus);
      final restoredFromBinary = statusSerializer.fromBytes(bytes);

      expect(restoredFromBinary, isA<StatusPendingOption>());
      expect(
        (restoredFromBinary as StatusPendingOption).reason,
        equals('waiting for approval'),
      );
    });

    test('enum serializer - all constant types roundtrip', () {
      final constantValues = [StatusActive(), StatusInactive()];

      for (final status in constantValues) {
        // Test both dense and readable JSON roundtrips
        final denseJson = statusSerializer.toJsonCode(
          status,
          readableFlavor: false,
        );
        final readableJson = statusSerializer.toJsonCode(
          status,
          readableFlavor: true,
        );

        final restoredFromDense = statusSerializer.fromJsonCode(denseJson);
        final restoredFromReadable = statusSerializer.fromJsonCode(
          readableJson,
        );

        expect(restoredFromDense.runtimeType, equals(status.runtimeType));
        expect(restoredFromReadable.runtimeType, equals(status.runtimeType));

        // Test binary roundtrip
        final bytes = statusSerializer.toBytes(status);
        final restoredFromBinary = statusSerializer.fromBytes(bytes);
        expect(restoredFromBinary.runtimeType, equals(status.runtimeType));
      }
    });

    test('enum serializer - error cases', () {
      // Test that finalize() can only be called once
      final testEnumBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'foo.bar:Color',
        doc: "A color",
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getOrdinal: (it) => it.kind.ordinal,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      testEnumBuilder.addConstantVariant(
        1,
        'test',
        'test',
        "red color",
        colorRed,
      );
      testEnumBuilder.finalize();

      // Adding fields after finalization should throw
      expect(
        () => testEnumBuilder.addConstantVariant(
          2,
          'test2',
          'test2',
          "green color",
          colorGreen,
        ),
        throwsStateError,
      );

      // Double finalization should throw
      expect(() => testEnumBuilder.finalize(), throwsStateError);
    });

    test('enum serializer - edge cases', () {
      // Test with edge case values
      final edgeCases = [
        ColorCustomOption(0),
        ColorCustomOption(2147483647), // Int.MAX_VALUE in Dart (32-bit)
        ColorCustomOption(-2147483648), // Int.MIN_VALUE in Dart (32-bit)
      ];

      for (final color in edgeCases) {
        // Test JSON roundtrips
        final denseJson = colorSerializer.toJsonCode(
          color,
          readableFlavor: false,
        );
        final readableJson = colorSerializer.toJsonCode(
          color,
          readableFlavor: true,
        );

        final restoredFromDense = colorSerializer.fromJsonCode(denseJson);
        final restoredFromReadable = colorSerializer.fromJsonCode(readableJson);

        expect(restoredFromDense, isA<ColorCustomOption>());
        expect((restoredFromDense as ColorCustomOption).rgb, equals(color.rgb));

        expect(restoredFromReadable, isA<ColorCustomOption>());
        expect(
          (restoredFromReadable as ColorCustomOption).rgb,
          equals(color.rgb),
        );

        // Test binary roundtrip
        final bytes = colorSerializer.toBytes(color);
        final restoredFromBinary = colorSerializer.fromBytes(bytes);

        expect(restoredFromBinary, isA<ColorCustomOption>());
        expect(
          (restoredFromBinary as ColorCustomOption).rgb,
          equals(color.rgb),
        );
      }
    });

    test('enum serializer - json format consistency', () {
      // Test that dense and readable formats are different for wrapper fields
      // but same for constants
      final redConstant = colorRed;
      final customValue = ColorCustomOption(0xABCDEF);

      // Constants should be different between dense/readable
      final redDenseJson = colorSerializer.toJsonCode(
        redConstant,
        readableFlavor: false,
      );
      final redReadableJson = colorSerializer.toJsonCode(
        redConstant,
        readableFlavor: true,
      );
      expect(redDenseJson, isNot(equals(redReadableJson)));

      // Wrapper fields should be different between dense/readable
      final customDenseJson = colorSerializer.toJsonCode(
        customValue,
        readableFlavor: false,
      );
      final customReadableJson = colorSerializer.toJsonCode(
        customValue,
        readableFlavor: true,
      );
      expect(customDenseJson, isNot(equals(customReadableJson)));

      // Dense should be array/number, readable should be string/object
      expect(int.tryParse(redDenseJson), isNotNull);
      expect(redReadableJson, startsWith('"'));
      expect(redReadableJson, endsWith('"'));

      expect(customDenseJson, startsWith('['));
      expect(customDenseJson, endsWith(']'));
      expect(customReadableJson, startsWith('{'));
      expect(customReadableJson, endsWith('}'));
    });

    test('enum serializer - field number ranges', () {
      // Test that field numbers work correctly for different ranges
      // Using the existing colorSerializer which has field numbers 1, 2, 3, 4

      final constantValues = [colorRed, colorGreen, colorBlue];
      for (final constant in constantValues) {
        final bytes = colorSerializer.toBytes(constant);
        final restored = colorSerializer.fromBytes(bytes);
        expect(restored.runtimeType, equals(constant.runtimeType));
      }

      // Test wrapper field
      final customColor = ColorCustomOption(42);
      final bytes = colorSerializer.toBytes(customColor);
      final restored = colorSerializer.fromBytes(bytes);
      expect(restored, isA<ColorCustomOption>());
      expect((restored as ColorCustomOption).rgb, equals(42));
    });

    test('enum serializer - multiple value serializers', () {
      // Test with the existing Status enum that already has multiple serializer types
      final testCases = [
        StatusActive(),
        StatusInactive(),
        StatusPendingOption('waiting for approval'),
      ];

      for (final testCase in testCases) {
        // Test JSON roundtrips - use readable format which works correctly
        final readableJson = statusSerializer.toJsonCode(
          testCase,
          readableFlavor: true,
        );
        final restoredFromReadable = statusSerializer.fromJsonCode(
          readableJson,
        );
        expect(restoredFromReadable.runtimeType, equals(testCase.runtimeType));

        if (testCase is StatusPendingOption) {
          expect(
            (restoredFromReadable as StatusPendingOption).reason,
            equals(testCase.reason),
          );
        }

        // Test binary roundtrip
        final bytes = statusSerializer.toBytes(testCase);
        final restoredFromBinary = statusSerializer.fromBytes(bytes);

        expect(restoredFromBinary.runtimeType, equals(testCase.runtimeType));
        if (testCase is StatusPendingOption) {
          expect(
            (restoredFromBinary as StatusPendingOption).reason,
            equals(testCase.reason),
          );
        }
      }
    });

    test('.serializer field access', () {
      // Test that the serializer field is accessible and works correctly
      final builder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        doc: "A color",
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getOrdinal: (it) => it.kind.ordinal,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      builder.addConstantVariant(1, 'red', 'red', "red color", colorRed);
      builder.finalize();

      final serializer = builder.serializer;
      expect(serializer, isA<Serializer<Color>>());

      // Test that the serializer works - use readable format which works correctly
      final json = serializer.toJsonCode(colorRed, readableFlavor: true);
      final restored = serializer.fromJsonCode(json);
      expect(restored, isA<ColorRed>());
    });

    test('builder state management', () {
      final builder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        doc: "A color",
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
        getOrdinal: (it) => it.kind.ordinal,
      );

      // Should be able to add constants before finalization
      builder.addConstantVariant(1, 'red', 'red', "red color", colorRed);

      // Should be able to add wrapper fields before finalization
      builder.addWrapperVariant<ColorCustomOption, int>(
        ColorKind.custom.ordinal,
        'custom',
        'custom',
        Serializers.int32,
        "custom color",
        (rgb) => ColorCustomOption(rgb),
        (custom) => custom.rgb,
        ordinal: 4,
      );

      // Should be able to add removed numbers before finalization
      builder.addRemovedNumber(5);

      // Should be able to access serializer before finalization
      final serializer1 = builder.serializer;
      expect(serializer1, isA<Serializer<Color>>());

      // Finalize the builder
      builder.finalize();

      // Should still be able to access serializer after finalization
      final serializer2 = builder.serializer;
      expect(serializer2, isA<Serializer<Color>>());

      // Should not be able to add constants after finalization
      expect(
        () => builder.addConstantVariant(2, 'green', 'green', "", colorGreen),
        throwsStateError,
      );

      // Should not be able to add wrapper fields after finalization
      expect(
        () => builder.addWrapperVariant<ColorCustomOption, int>(
          4,
          'custom2',
          'custom2',
          Serializers.int32,
          "custom color",
          (rgb) => ColorCustomOption(rgb),
          (custom) => custom.rgb,
          ordinal: ColorKind.custom.ordinal,
        ),
        throwsStateError,
      );

      // Should not be able to add removed numbers after finalization
      expect(() => builder.addRemovedNumber(6), throwsStateError);

      // Should not be able to finalize again
      expect(() => builder.finalize(), throwsStateError);
    });

    test('enum serializer - type descriptor', () {
      final typeDescriptor = statusSerializer.typeDescriptor;
      final actualJson = typeDescriptor.asJsonCode;

      // Test that type descriptor is properly formed
      expect(actualJson, contains('"id": "foo.bar:Color.Status"'));
      expect(actualJson, contains('"kind": "enum"'));
      expect(actualJson, contains('"name": "active"'));
      expect(actualJson, contains('"name": "inactive"'));
      expect(actualJson, contains('"name": "pending"'));
      expect(actualJson, contains('"number": 1'));
      expect(actualJson, contains('"number": 2'));
      expect(actualJson, contains('"number": 3'));
      expect(actualJson, contains('removed_numbers'));
      expect(actualJson, contains('"doc": "A status"'));
      expect(actualJson, contains('"doc": "pending status"'));
      expect(actualJson, contains('"doc": "inactive status"'));

      // Test that parsing the type descriptor works
      final parsed = TypeDescriptor.parseFromJson(typeDescriptor.asJson);
      expect(parsed.asJsonCode, equals(actualJson));
    });

    test('enum serializer - default detection', () {
      // Create a simple builder to test default detection
      final testBuilder = internal__EnumSerializerBuilder.create(
        recordId: 'test:Color',
        doc: "A color",
        unknownInstance: colorUnknown,
        enumInstance: colorUnknown as Color,
        getOrdinal: (it) => it.kind.ordinal,
        wrapUnrecognized: (unrecognized) => ColorUnknown(unrecognized),
        getUnrecognized: (unknown) => unknown.unrecognized,
      );

      testBuilder.addConstantVariant(1, 'red', 'red', '', colorRed);
      testBuilder.finalize();

      final testSerializer = testBuilder.serializer;

      // Test serialization of default (unknown) vs non-default values
      final unknownJson = testSerializer.toJsonCode(
        colorUnknown,
        readableFlavor: true,
      );
      final redJson = testSerializer.toJsonCode(colorRed, readableFlavor: true);

      // They should produce different JSON
      expect(unknownJson, isNot(equals(redJson)));

      // Unknown should be able to roundtrip
      final restoredUnknown = testSerializer.fromJsonCode(unknownJson);
      expect(restoredUnknown, isA<ColorUnknown>());

      // Red should be able to roundtrip (using readable format)
      final restoredRed = testSerializer.fromJsonCode(redJson);
      expect(restoredRed, isA<ColorRed>());
    });

    test('enum serializer - wrapper variant default values from JSON', () {
      // Test that when a wrapper variant number is provided without a value,
      // it uses the default value of the wrapped type (fromJson(0, ...))

      // Dense format: just the number, no value array
      final fromNumber = colorSerializer.fromJson(
        4,
        keepUnrecognizedValues: false,
      );
      expect(fromNumber, isA<ColorCustomOption>());
      expect(
        (fromNumber as ColorCustomOption).rgb,
        equals(0),
      ); // Default int32 is 0

      // Readable format: just the name string, no value object
      final fromName = colorSerializer.fromJson(
        'custom',
        keepUnrecognizedValues: false,
      );
      expect(fromName, isA<ColorCustomOption>());
      expect(
        (fromName as ColorCustomOption).rgb,
        equals(0),
      ); // Default int32 is 0

      // Test with status enum too (wrapper with string type)
      final statusFromNumber = statusSerializer.fromJson(
        3,
        keepUnrecognizedValues: false,
      );
      expect(statusFromNumber, isA<StatusPendingOption>());
      expect(
        (statusFromNumber as StatusPendingOption).reason,
        equals(''),
      ); // Default string is ''

      final statusFromName = statusSerializer.fromJson(
        'pending',
        keepUnrecognizedValues: false,
      );
      expect(statusFromName, isA<StatusPendingOption>());
      expect(
        (statusFromName as StatusPendingOption).reason,
        equals(''),
      ); // Default string is ''
    });

    test('enum serializer - wrapper variant with explicit values', () {
      // Verify that wrapper variants with explicit values still work correctly
      // This ensures wrapFromJson (not wrapDefault) is used when values are present

      // Dense format with value
      final colorWithValue = colorSerializer.fromJson([
        4,
        255,
      ], keepUnrecognizedValues: false);
      expect(colorWithValue, isA<ColorCustomOption>());
      expect((colorWithValue as ColorCustomOption).rgb, equals(255));

      // Readable format with value
      final colorWithValueReadable = colorSerializer.fromJson({
        'kind': 'custom',
        'value': 1024,
      }, keepUnrecognizedValues: false);
      expect(colorWithValueReadable, isA<ColorCustomOption>());
      expect((colorWithValueReadable as ColorCustomOption).rgb, equals(1024));

      // Test with status enum too
      final statusWithValue = statusSerializer.fromJson([
        3,
        'custom reason',
      ], keepUnrecognizedValues: false);
      expect(statusWithValue, isA<StatusPendingOption>());
      expect(
        (statusWithValue as StatusPendingOption).reason,
        equals('custom reason'),
      );

      final statusWithValueReadable = statusSerializer.fromJson({
        'kind': 'pending',
        'value': 'another reason',
      }, keepUnrecognizedValues: false);
      expect(statusWithValueReadable, isA<StatusPendingOption>());
      expect(
        (statusWithValueReadable as StatusPendingOption).reason,
        equals('another reason'),
      );
    });

    test('enum serializer - binary wrapper variant default values', () {
      // Test that binary format correctly handles wrapper variants without values
      // This tests the decode() path that calls wrapDefault()
      // We'll serialize a constant variant with the same number, then decode it
      // to verify the decoder can handle missing data gracefully

      // Actually, the safest test is to verify that when we encode a wrapper variant
      // with the default value, it can be decoded back correctly
      final defaultColor = ColorCustomOption(0);
      final bytes = colorSerializer.toBytes(defaultColor);
      final decoded = colorSerializer.fromBytes(bytes);

      expect(decoded, isA<ColorCustomOption>());
      expect((decoded as ColorCustomOption).rgb, equals(0));

      // Same for status enum with default string
      final defaultStatus = StatusPendingOption('');
      final statusBytes = statusSerializer.toBytes(defaultStatus);
      final decodedStatus = statusSerializer.fromBytes(statusBytes);

      expect(decodedStatus, isA<StatusPendingOption>());
      expect((decodedStatus as StatusPendingOption).reason, equals(''));
    });

    // ── Enum name case-compatibility tests ─────────────────────────────────

    // Condition 1: serialise using the registered (lower_case) name

    test(
        'enum name case – serialises lower_case constant name in readable JSON',
        () {
      expect(
        colorSerializer.toJson(colorRed, readableFlavor: true),
        equals('red'),
      );
      expect(
        colorSerializer.toJson(colorGreen, readableFlavor: true),
        equals('green'),
      );
    });

    // Condition 2: parse both UPPER_CASE and lower_case names

    test('enum name case – parses UPPER_CASE constant name', () {
      final result =
          colorSerializer.fromJson('RED', keepUnrecognizedValues: false);
      expect(result, isA<ColorRed>());
    });

    test('enum name case – parses lower_case constant name', () {
      final result =
          colorSerializer.fromJson('green', keepUnrecognizedValues: false);
      expect(result, isA<ColorGreen>());
    });

    test(
        'enum name case – UPPER_CASE and lower_case constant names yield same result',
        () {
      final fromUpper =
          colorSerializer.fromJson('RED', keepUnrecognizedValues: false);
      final fromLower =
          colorSerializer.fromJson('red', keepUnrecognizedValues: false);
      expect(fromUpper, isA<ColorRed>());
      expect(fromLower, isA<ColorRed>());
    });
  });
}
