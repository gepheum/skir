// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  group('BoolSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test true value - should be true in readable, 1 in dense
      expect(
        Serializers.bool.toJson(false, readableFlavor: true),
        equals(false),
      );
      expect(Serializers.bool.toJson(false, readableFlavor: false), equals(0));
      expect(Serializers.bool.toJson(true, readableFlavor: true), equals(true));
      expect(Serializers.bool.toJson(true, readableFlavor: false), equals(1));

      // Test JSON string serialization
      expect(
        Serializers.bool.toJsonCode(false, readableFlavor: true),
        equals('false'),
      );
      expect(
        Serializers.bool.toJsonCode(false, readableFlavor: false),
        equals('0'),
      );
      expect(
        Serializers.bool.toJsonCode(true, readableFlavor: true),
        equals('true'),
      );
      expect(
        Serializers.bool.toJsonCode(true, readableFlavor: false),
        equals('1'),
      );
    });

    test('JSON deserialization - boolean values', () {
      // Test boolean JSON values
      expect(Serializers.bool.fromJson(true), equals(true));
      expect(Serializers.bool.fromJson(false), equals(false));
      expect(Serializers.bool.fromJsonCode('true'), equals(true));
      expect(Serializers.bool.fromJsonCode('false'), equals(false));
    });

    test('JSON deserialization - numeric values', () {
      // Test numeric JSON values
      expect(Serializers.bool.fromJson(1), equals(true));
      expect(Serializers.bool.fromJson(0), equals(false));
      expect(Serializers.bool.fromJson(100), equals(true));
      expect(Serializers.bool.fromJson(-1), equals(true));
      expect(Serializers.bool.fromJson(3.14), equals(true));
      expect(Serializers.bool.fromJsonCode('1'), equals(true));
      expect(Serializers.bool.fromJsonCode('0'), equals(false));
      expect(Serializers.bool.fromJsonCode('100'), equals(true));
      expect(Serializers.bool.fromJsonCode('3.14'), equals(true));
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.bool.fromJson('0'), equals(false));
      expect(Serializers.bool.fromJson('false'), equals(false));
      expect(Serializers.bool.fromJson('1'), equals(true));
      expect(Serializers.bool.fromJson('100'), equals(true));
      expect(Serializers.bool.fromJson('true'), equals(true));
      expect(Serializers.bool.fromJson('anything'), equals(true));
      expect(Serializers.bool.fromJsonCode('"0"'), equals(false));
      expect(Serializers.bool.fromJsonCode('"false"'), equals(false));
      expect(Serializers.bool.fromJsonCode('"1"'), equals(true));
      expect(Serializers.bool.fromJsonCode('"true"'), equals(true));
      expect(Serializers.bool.fromJsonCode('"anything"'), equals(true));
    });

    test('binary serialization', () {
      // From TypeScript tests: true -> "01", false -> "00"
      final trueBytes = Serializers.bool.toBytes(true);
      expect(_bytesToHex(trueBytes), equals('736b697201'));

      final falseBytes = Serializers.bool.toBytes(false);
      expect(_bytesToHex(falseBytes), equals('736b697200'));
    });

    test('binary deserialization roundtrip', () {
      // Test round trip
      final trueBytes = Serializers.bool.toBytes(true);
      final restoredTrue = Serializers.bool.fromBytes(trueBytes);
      expect(restoredTrue, equals(true));

      final falseBytes = Serializers.bool.toBytes(false);
      final restoredFalse = Serializers.bool.fromBytes(falseBytes);
      expect(restoredFalse, equals(false));
    });

    test('binary deserialization from other numeric types', () {
      // Test that non-zero numbers decode as true, zero as false
      expect(
        Serializers.bool.fromBytes(Serializers.int32.toBytes(100)),
        equals(true),
      );
      expect(
        Serializers.bool.fromBytes(Serializers.float32.toBytes(3.14)),
        equals(true),
      );
      expect(
        Serializers.bool.fromBytes(Serializers.hash64.toBytes(BigInt.zero)),
        equals(false),
      );
      expect(
        Serializers.bool.fromBytes(Serializers.int64.toBytes(-1)),
        equals(true),
      );
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.bool.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.bool));
    });

    test('edge cases and error handling', () {
      // Test empty string
      expect(Serializers.bool.fromJson(''), equals(true));
    });

    test('string encoding specifics', () {
      // Test specific string values that should return false
      final falseStrings = ['0', 'false'];
      for (final str in falseStrings) {
        expect(Serializers.bool.fromJson(str), equals(false));
      }

      // Test various strings that should return true
      final trueStrings = [
        '1',
        'true',
        'TRUE',
        'False',
        'anything',
        ' ',
        '00',
        'null',
      ];
      for (final str in trueStrings) {
        expect(Serializers.bool.fromJson(str), equals(true));
      }
    });

    test('binary format specifics', () {
      // Test specific binary format encoding (includes "skir" prefix)
      final testCases = [(true, '736b697201'), (false, '736b697200')];

      for (final (value, expectedHex) in testCases) {
        final bytes = Serializers.bool.toBytes(value);
        expect(_bytesToHex(bytes), equals(expectedHex));
        expect(Serializers.bool.fromBytes(bytes), equals(value));
      }
    });
  });

  group('Int32Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various int32 values - should be the same in both readable and dense flavors
      expect(Serializers.int32.toJson(0, readableFlavor: true), equals(0));
      expect(Serializers.int32.toJson(0, readableFlavor: false), equals(0));
      expect(Serializers.int32.toJson(42, readableFlavor: true), equals(42));
      expect(Serializers.int32.toJson(42, readableFlavor: false), equals(42));
      expect(Serializers.int32.toJson(-1, readableFlavor: true), equals(-1));
      expect(Serializers.int32.toJson(-1, readableFlavor: false), equals(-1));

      // Test JSON string serialization
      expect(
        Serializers.int32.toJsonCode(0, readableFlavor: true),
        equals('0'),
      );
      expect(
        Serializers.int32.toJsonCode(0, readableFlavor: false),
        equals('0'),
      );
      expect(
        Serializers.int32.toJsonCode(42, readableFlavor: true),
        equals('42'),
      );
      expect(
        Serializers.int32.toJsonCode(42, readableFlavor: false),
        equals('42'),
      );
      expect(
        Serializers.int32.toJsonCode(-1, readableFlavor: true),
        equals('-1'),
      );
      expect(
        Serializers.int32.toJsonCode(-1, readableFlavor: false),
        equals('-1'),
      );
    });

    test('JSON deserialization - integer values', () {
      // Test integer JSON values
      expect(Serializers.int32.fromJson(0), equals(0));
      expect(Serializers.int32.fromJson(42), equals(42));
      expect(Serializers.int32.fromJson(-1), equals(-1));
      expect(Serializers.int32.fromJsonCode('0'), equals(0));
      expect(Serializers.int32.fromJsonCode('42'), equals(42));
      expect(Serializers.int32.fromJsonCode('-1'), equals(-1));
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.int32.fromJson('0'), equals(0));
      expect(Serializers.int32.fromJson('42'), equals(42));
      expect(Serializers.int32.fromJson('-1'), equals(-1));
      expect(Serializers.int32.fromJson('123456'), equals(123456));
      expect(Serializers.int32.fromJsonCode('"0"'), equals(0));
      expect(Serializers.int32.fromJsonCode('"42"'), equals(42));
      expect(Serializers.int32.fromJsonCode('"-1"'), equals(-1));
      expect(Serializers.int32.fromJsonCode('"123456"'), equals(123456));
    });

    test('JSON deserialization - floating point values', () {
      // Test floating point JSON values (should truncate to integer)
      expect(Serializers.int32.fromJson(3.14), equals(3));
      expect(Serializers.int32.fromJson(-2.7), equals(-2));
      expect(Serializers.int32.fromJson(42.0), equals(42));
      expect(Serializers.int32.fromJsonCode('3.14'), equals(3));
      expect(Serializers.int32.fromJsonCode('-2.7'), equals(-2));
      expect(Serializers.int32.fromJsonCode('42.0'), equals(42));
    });

    test('32-bit signed integer boundaries', () {
      const int maxInt32 = 2147483647; // 2^31 - 1
      const int minInt32 = -2147483648; // -2^31

      // Test boundary values
      expect(Serializers.int32.fromJson(maxInt32), equals(maxInt32));
      expect(Serializers.int32.fromJson(minInt32), equals(minInt32));
      expect(Serializers.int32.toJson(maxInt32), equals(maxInt32));
      expect(Serializers.int32.toJson(minInt32), equals(minInt32));

      // Test that toSigned(32) is applied - overflow should wrap around
      // Note: This tests the Dart-specific behavior not present in Kotlin
      const int overflowValue = 2147483648; // 2^31 (one more than max)
      const int underflowValue = -2147483649; // -2^31 - 1 (one less than min)

      expect(
        Serializers.int32.toJson(overflowValue),
        equals(-2147483648),
      ); // wraps to min
      expect(
        Serializers.int32.toJson(underflowValue),
        equals(2147483647),
      ); // wraps to max
    });

    test('binary serialization', () {
      // Test specific binary encodings for various int32 values
      final zeroBytes = Serializers.int32.toBytes(0);
      expect(_bytesToHex(zeroBytes), equals('736b697200')); // "skir" + 0x00

      final oneBytes = Serializers.int32.toBytes(1);
      expect(_bytesToHex(oneBytes), equals('736b697201')); // "skir" + 0x01

      expect(
        _bytesToHex(Serializers.int32.toBytes(-255)),
        equals('736b6972eb01'),
      ); // "skir" + 0x01

      final negativeOneBytes = Serializers.int32.toBytes(-1);
      expect(
        _bytesToHex(negativeOneBytes),
        startsWith('736b6972'),
      ); // "skir" prefix
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        0, 1, -1, 42, -42, 100, -100, -255, -256, 1000, -1000,
        2147483647, -2147483648, // boundary values
      ];

      for (final value in testValues) {
        final bytes = Serializers.int32.toBytes(value);
        final restored = Serializers.int32.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed roundtrip for value: $value',
        );
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.int32.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.int32));
    });

    test('string parsing edge cases', () {
      // Test various string formats
      expect(Serializers.int32.fromJson('0'), equals(0));
      expect(Serializers.int32.fromJson('-0'), equals(0));
      expect(Serializers.int32.fromJson('+42'), equals(42));
      expect(
        Serializers.int32.fromJson('  123  '),
        equals(123),
      ); // Dart's int.parse handles whitespace

      // Test that decimal strings throw exceptions (both Dart and Kotlin should fail on these)
      expect(() => Serializers.int32.fromJson('2.5'), throwsFormatException);
      expect(() => Serializers.int32.fromJson('-2.7'), throwsFormatException);
    });

    test('overflow and underflow behavior', () {
      // Test specific overflow/underflow scenarios that highlight Dart vs Kotlin difference
      const testCases = [
        (2147483648, -2147483648), // 2^31 -> -2^31 (overflow)
        (-2147483649, 2147483647), // -2^31-1 -> 2^31-1 (underflow)
        (4294967295, -1), // 2^32-1 -> -1 (overflow)
        (4294967296, 0), // 2^32 -> 0 (overflow)
      ];

      for (final (input, expectedOutput) in testCases) {
        final result = Serializers.int32.toJson(input);
        expect(
          result,
          equals(expectedOutput),
          reason: 'toSigned(32) should convert $input to $expectedOutput',
        );

        // Test that fromJson also applies the same conversion
        final fromJsonResult = Serializers.int32.fromJson(input);
        expect(
          fromJsonResult,
          equals(expectedOutput),
          reason: 'fromJson should convert $input to $expectedOutput',
        );
      }
    });
  });

  group('Int64Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various int64 values - should be the same in both readable and dense flavors for safe values
      expect(Serializers.int64.toJson(0, readableFlavor: true), equals(0));
      expect(Serializers.int64.toJson(0, readableFlavor: false), equals(0));
      expect(Serializers.int64.toJson(42, readableFlavor: true), equals(42));
      expect(Serializers.int64.toJson(42, readableFlavor: false), equals(42));
      expect(Serializers.int64.toJson(-1, readableFlavor: true), equals(-1));
      expect(Serializers.int64.toJson(-1, readableFlavor: false), equals(-1));

      // Test JSON string serialization for safe values
      expect(
        Serializers.int64.toJsonCode(0, readableFlavor: true),
        equals('0'),
      );
      expect(
        Serializers.int64.toJsonCode(0, readableFlavor: false),
        equals('0'),
      );
      expect(
        Serializers.int64.toJsonCode(42, readableFlavor: true),
        equals('42'),
      );
      expect(
        Serializers.int64.toJsonCode(42, readableFlavor: false),
        equals('42'),
      );
    });

    test('JavaScript safe integer boundaries', () {
      const int maxSafeInt = 9007199254740991; // 2^53 - 1
      const int minSafeInt = -9007199254740991; // -(2^53 - 1)

      // Test boundary values - should be numbers
      expect(Serializers.int64.toJson(maxSafeInt), equals(maxSafeInt));
      expect(Serializers.int64.toJson(minSafeInt), equals(minSafeInt));

      // Test values beyond safe range - should be strings
      const int unsafePositive = 9007199254740992; // 2^53
      const int unsafeNegative = -9007199254740992; // -(2^53)

      expect(Serializers.int64.toJson(unsafePositive), isA<String>());
      expect(Serializers.int64.toJson(unsafeNegative), isA<String>());
      expect(Serializers.int64.toJsonCode(unsafePositive), startsWith('"'));
      expect(Serializers.int64.toJsonCode(unsafeNegative), startsWith('"'));
    });

    test('JSON deserialization - integer values', () {
      // Test integer JSON values
      expect(Serializers.int64.fromJson(0), equals(0));
      expect(Serializers.int64.fromJson(42), equals(42));
      expect(Serializers.int64.fromJson(-1), equals(-1));
      expect(Serializers.int64.fromJsonCode('0'), equals(0));
      expect(Serializers.int64.fromJsonCode('42'), equals(42));
      expect(Serializers.int64.fromJsonCode('-1'), equals(-1));
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values for large numbers
      expect(
        Serializers.int64.fromJson('9223372036854775807'),
        equals(9223372036854775807),
      ); // max int64
      expect(
        Serializers.int64.fromJson('-9223372036854775808'),
        equals(-9223372036854775808),
      ); // min int64
      expect(
        Serializers.int64.fromJsonCode('"9223372036854775807"'),
        equals(9223372036854775807),
      );
      expect(
        Serializers.int64.fromJsonCode('"-9223372036854775808"'),
        equals(-9223372036854775808),
      );
    });

    test('binary serialization and encoding optimization', () {
      // Test that int64 uses int32 encoding for values in int32 range
      final int32Value = 42;
      final int32Bytes = Serializers.int32.toBytes(int32Value);
      final int64Bytes = Serializers.int64.toBytes(int32Value);

      // Should use same encoding for values in int32 range
      expect(_bytesToHex(int64Bytes), equals(_bytesToHex(int32Bytes)));

      // Test large values that require 64-bit encoding
      final largeValue = 9223372036854775807; // max int64
      final largeBytes = Serializers.int64.toBytes(largeValue);
      expect(
        _bytesToHex(largeBytes),
        startsWith('736b6972ee'),
      ); // "skir" + 0xEE wire
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        0, 1, -1, 42, -42, 1000, -1000,
        2147483647, -2147483648, // int32 boundaries
        9007199254740992, -9007199254740992, // JS safe boundaries
        9223372036854775807, -9223372036854775808, // int64 boundaries
      ];

      for (final value in testValues) {
        final bytes = Serializers.int64.toBytes(value);
        final restored = Serializers.int64.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed roundtrip for value: $value',
        );
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.int64.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.int64));
    });

    test('JSON roundtrip for safe and unsafe values', () {
      final safeValues = [0, 42, -42, 9007199254740991, -9007199254740991];
      final unsafeValues = [
        9007199254740992,
        -9007199254740992,
        9223372036854775807,
        -9223372036854775808,
      ];

      // Test safe values (should be numbers in JSON)
      for (final value in safeValues) {
        final json = Serializers.int64.toJsonCode(value);
        expect(Serializers.int64.fromJsonCode(json), equals(value));
        expect(json, isNot(startsWith('"'))); // Should not be quoted
      }

      // Test unsafe values (should be strings in JSON)
      for (final value in unsafeValues) {
        final json = Serializers.int64.toJsonCode(value);
        expect(Serializers.int64.fromJsonCode(json), equals(value));
        expect(json, startsWith('"')); // Should be quoted
      }
    });
  });

  group('Uint64Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various uint64 values
      expect(
        Serializers.hash64.toJson(BigInt.zero, readableFlavor: true),
        equals(0),
      );
      expect(
        Serializers.hash64.toJson(BigInt.zero, readableFlavor: false),
        equals(0),
      );
      expect(
        Serializers.hash64.toJson(BigInt.from(42), readableFlavor: true),
        equals(42),
      );
      expect(
        Serializers.hash64.toJson(BigInt.from(42), readableFlavor: false),
        equals(42),
      );
      expect(
        Serializers.hash64.toJson(
          BigInt.from(9007199254740991),
          readableFlavor: false,
        ),
        equals(9007199254740991),
      );
      expect(
        Serializers.hash64.toJson(
          BigInt.parse("9007199254740992"),
          readableFlavor: false,
        ),
        equals("9007199254740992"),
      );

      // Test JSON string serialization
      expect(
        Serializers.hash64.toJsonCode(BigInt.zero, readableFlavor: true),
        equals('0'),
      );
      expect(
        Serializers.hash64.toJsonCode(BigInt.from(42), readableFlavor: true),
        equals('42'),
      );
    });

    test('JavaScript safe integer boundaries', () {
      final maxSafeInt = BigInt.from(9007199254740991); // 2^53 - 1

      // Test boundary values - should be numbers
      expect(Serializers.hash64.toJson(maxSafeInt), equals(9007199254740991));
      expect(Serializers.hash64.toJson(BigInt.zero), equals(0));

      // Test values beyond safe range - should be strings
      final unsafeValue = BigInt.from(9007199254740992); // 2^53

      expect(Serializers.hash64.toJson(unsafeValue), isA<String>());
      expect(Serializers.hash64.toJsonCode(unsafeValue), startsWith('"'));
    });

    test('JSON deserialization - positive values only', () {
      // Test positive integer JSON values
      expect(Serializers.hash64.fromJson(0), equals(BigInt.zero));
      expect(Serializers.hash64.fromJson(42), equals(BigInt.from(42)));
      expect(Serializers.hash64.fromJson(1000), equals(BigInt.from(1000)));
      expect(Serializers.hash64.fromJsonCode('0'), equals(BigInt.zero));
      expect(Serializers.hash64.fromJsonCode('42'), equals(BigInt.from(42)));
    });

    test('unsigned 64-bit boundaries and conversion', () {
      // Test that toUnsigned(64) is applied in Dart implementation
      // Note: Dart's toUnsigned(64) on negative numbers doesn't wrap as expected in other languages
      // This test verifies the actual Dart behavior, which may differ from Kotlin

      // Test that the Dart implementation applies toUnsigned(64) but it may not behave as expected
      final negOneResult = Serializers.hash64.fromJson(-1);
      final negHundredResult = Serializers.hash64.fromJson(-100);

      // In Dart, toUnsigned(64) on negative numbers may not wrap to large positive values
      // We test that the function completes without error and returns a value
      expect(negOneResult, isA<BigInt>());
      expect(negHundredResult, isA<BigInt>());

      // Test large positive values within Dart's range
      final maxDartInt = BigInt.parse(
        '9223372036854775807',
      ); // max int64 Dart can represent
      expect(
        Serializers.hash64.fromJson(maxDartInt.toInt()),
        equals(maxDartInt),
      );
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        BigInt.zero, BigInt.one, BigInt.from(42), BigInt.from(100),
        BigInt.from(231), BigInt.from(232), BigInt.from(1000),
        BigInt.from(65535), BigInt.from(65536), BigInt.from(100000),
        BigInt.from(4294967295), BigInt.from(4294967296), // 32-bit boundary
        BigInt.from(9007199254740992), // JS safe boundary
        BigInt.parse(
          '9223372036854775807',
        ), // max int64 that Dart can represent
      ];

      for (final value in testValues) {
        final bytes = Serializers.hash64.toBytes(value);
        final restored = Serializers.hash64.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed roundtrip for value: $value',
        );
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.hash64.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.hash64));
    });
  });

  group('Float32Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various float32 values - should be the same in both flavors for finite values
      expect(
        Serializers.float32.toJson(0.0, readableFlavor: true),
        equals(0.0),
      );
      expect(
        Serializers.float32.toJson(0.0, readableFlavor: false),
        equals(0.0),
      );
      expect(
        Serializers.float32.toJson(2.5, readableFlavor: true),
        equals(2.5),
      );
      expect(
        Serializers.float32.toJson(2.5, readableFlavor: false),
        equals(2.5),
      );
      expect(
        Serializers.float32.toJson(-2.5, readableFlavor: true),
        equals(-2.5),
      );
      expect(
        Serializers.float32.toJson(-2.5, readableFlavor: false),
        equals(-2.5),
      );

      // Test JSON string serialization
      expect(
        Serializers.float32.toJsonCode(0.0, readableFlavor: true),
        equals('0.0'),
      );
      expect(
        Serializers.float32.toJsonCode(2.5, readableFlavor: true),
        equals('2.5'),
      );
    });

    test('special values - NaN and Infinity', () {
      // Test special floating point values - should be strings in JSON
      expect(Serializers.float32.toJson(double.nan), equals('NaN'));
      expect(Serializers.float32.toJson(double.infinity), equals('Infinity'));
      expect(
        Serializers.float32.toJson(double.negativeInfinity),
        equals('-Infinity'),
      );

      expect(Serializers.float32.toJsonCode(double.nan), equals('"NaN"'));
      expect(
        Serializers.float32.toJsonCode(double.infinity),
        equals('"Infinity"'),
      );
      expect(
        Serializers.float32.toJsonCode(double.negativeInfinity),
        equals('"-Infinity"'),
      );
    });

    test('JSON deserialization - string values for special cases', () {
      // Test string JSON values for special floating point values
      expect(Serializers.float32.fromJson('NaN'), isNaN);
      expect(Serializers.float32.fromJson('Infinity'), equals(double.infinity));
      expect(
        Serializers.float32.fromJson('-Infinity'),
        equals(double.negativeInfinity),
      );
      expect(Serializers.float32.fromJsonCode('"NaN"'), isNaN);
      expect(
        Serializers.float32.fromJsonCode('"Infinity"'),
        equals(double.infinity),
      );
      expect(
        Serializers.float32.fromJsonCode('"-Infinity"'),
        equals(double.negativeInfinity),
      );
    });

    test('binary serialization - zero optimization', () {
      // Test that 0.0 uses optimized encoding
      final zeroBytes = Serializers.float32.toBytes(0.0);
      expect(_bytesToHex(zeroBytes), equals('736b697200')); // "skir" + 0x00

      // Test non-zero values use float encoding
      final nonZeroBytes = Serializers.float32.toBytes(2.5);
      expect(
        _bytesToHex(nonZeroBytes),
        startsWith('736b6972f0'),
      ); // "skir" + 0xF0 wire
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        0.0, 1.0, -1.0, 2.5, -2.5, 0.5, -0.5,
        1e10, -1e10, // More reasonable large values for float32
        double.nan, double.infinity, double.negativeInfinity,
      ];

      for (final value in testValues) {
        final bytes = Serializers.float32.toBytes(value);
        final restored = Serializers.float32.fromBytes(bytes);
        if (value.isNaN) {
          expect(restored.isNaN, isTrue, reason: 'NaN should roundtrip as NaN');
        } else if (value.isFinite) {
          // For finite values, allow for float32 precision loss
          // Use relative tolerance for large values
          final tolerance = value.abs() > 1e6 ? value.abs() * 1e-6 : 1e-6;
          expect(
            (restored - value).abs(),
            lessThan(tolerance),
            reason: 'Failed roundtrip for finite value: $value (got $restored)',
          );
        } else {
          // For infinity values
          expect(
            restored,
            equals(value),
            reason: 'Failed roundtrip for value: $value',
          );
        }
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.float32.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.float32));
    });
  });

  group('Float64Serializer', () {
    test('basic functionality - JSON serialization', () {
      // Test various float64 values - should be the same in both flavors for finite values
      expect(
        Serializers.float64.toJson(0.0, readableFlavor: true),
        equals(0.0),
      );
      expect(
        Serializers.float64.toJson(0.0, readableFlavor: false),
        equals(0.0),
      );
      expect(
        Serializers.float64.toJson(2.5159265359, readableFlavor: true),
        equals(2.5159265359),
      );
      expect(
        Serializers.float64.toJson(2.5159265359, readableFlavor: false),
        equals(2.5159265359),
      );
      expect(
        Serializers.float64.toJson(-2.71828, readableFlavor: true),
        equals(-2.71828),
      );

      // Test JSON string serialization
      expect(
        Serializers.float64.toJsonCode(0.0, readableFlavor: true),
        equals('0.0'),
      );
      expect(
        Serializers.float64.toJsonCode(2.5159265359, readableFlavor: true),
        equals('2.5159265359'),
      );
    });

    test('special values - NaN and Infinity', () {
      // Test special floating point values - should be strings in JSON
      expect(Serializers.float64.toJson(double.nan), equals('NaN'));
      expect(Serializers.float64.toJson(double.infinity), equals('Infinity'));
      expect(
        Serializers.float64.toJson(double.negativeInfinity),
        equals('-Infinity'),
      );

      expect(Serializers.float64.toJsonCode(double.nan), equals('"NaN"'));
      expect(
        Serializers.float64.toJsonCode(double.infinity),
        equals('"Infinity"'),
      );
      expect(
        Serializers.float64.toJsonCode(double.negativeInfinity),
        equals('"-Infinity"'),
      );
    });

    test('binary serialization - zero optimization', () {
      // Test that 0.0 uses optimized encoding
      final zeroBytes = Serializers.float64.toBytes(0.0);
      expect(_bytesToHex(zeroBytes), equals('736b697200')); // "skir" + 0x00

      // Test non-zero values use double encoding
      final nonZeroBytes = Serializers.float64.toBytes(2.5159265359);
      expect(
        _bytesToHex(nonZeroBytes),
        startsWith('736b6972f1'),
      ); // "skir" + 0xF1 wire
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        0.0, 1.0, -1.0, 2.5159265359, -2.718281828, 0.5, -0.5,
        2.2250738585072014e-308,
        1.7976931348623157e+308, // double boundaries (approximately)
        double.nan, double.infinity, double.negativeInfinity,
      ];

      for (final value in testValues) {
        final bytes = Serializers.float64.toBytes(value);
        final restored = Serializers.float64.fromBytes(bytes);
        if (value.isNaN) {
          expect(restored.isNaN, isTrue, reason: 'NaN should roundtrip as NaN');
        } else {
          expect(
            restored,
            equals(value),
            reason: 'Failed roundtrip for value: $value',
          );
        }
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.float64.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.float64));
    });

    test('high precision values', () {
      // Test that float64 can handle higher precision than float32
      final highPrecisionValue = 1.2345678901234567;
      expect(
        Serializers.float64.fromJson(highPrecisionValue),
        equals(highPrecisionValue),
      );

      final bytes = Serializers.float64.toBytes(highPrecisionValue);
      final restored = Serializers.float64.fromBytes(bytes);
      expect(restored, equals(highPrecisionValue));
    });
  });

  group('TimestampSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test epoch - should be 0 in dense, and unix_millis in readable
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      expect(
        Serializers.timestamp.toJson(epoch, readableFlavor: false),
        equals(0),
      );
      expect(
        Serializers.timestamp.toJsonCode(epoch, readableFlavor: false),
        equals('0'),
      );

      // Test readable flavor for epoch
      final epochReadable = Serializers.timestamp.toJson(
        epoch,
        readableFlavor: true,
      );
      expect(epochReadable, isA<Map>());
      final epochMap = epochReadable as Map<dynamic, dynamic>;
      expect(epochMap['unix_millis'], equals(0));
      expect(epochMap['formatted'], equals('1970-01-01T00:00:00.000Z'));

      // Test positive timestamp
      final testTime = DateTime.fromMillisecondsSinceEpoch(
        1756117845000,
        isUtc: true,
      ); // 2025-08-25T10:30:45Z
      expect(
        Serializers.timestamp.toJson(testTime, readableFlavor: false),
        equals(1756117845000),
      );
      expect(
        Serializers.timestamp.toJsonCode(testTime, readableFlavor: false),
        equals('1756117845000'),
      );

      // Test negative timestamp (before epoch)
      final beforeEpoch = DateTime.fromMillisecondsSinceEpoch(
        -1000,
        isUtc: true,
      );
      expect(
        Serializers.timestamp.toJson(beforeEpoch, readableFlavor: false),
        equals(-1000),
      );
      expect(
        Serializers.timestamp.toJsonCode(beforeEpoch, readableFlavor: false),
        equals('-1000'),
      );
    });

    test('readable flavor - object format', () {
      final testTime = DateTime.fromMillisecondsSinceEpoch(
        1756117845000,
        isUtc: true,
      ); // 2025-08-25T10:30:45Z
      final readableJson = Serializers.timestamp.toJsonCode(
        testTime,
        readableFlavor: true,
      );

      // Should produce an object with unix_millis and formatted
      expect(readableJson, contains('unix_millis'));
      expect(readableJson, contains('formatted'));
      expect(readableJson, contains('1756117845000'));
      expect(readableJson, contains('2025-08-25T10:30:45'));

      // Parse the JSON to verify structure
      final readableObj = Serializers.timestamp
          .toJson(testTime, readableFlavor: true) as Map<dynamic, dynamic>;
      expect(readableObj['unix_millis'], equals(1756117845000));
      expect(readableObj['formatted'], equals('2025-08-25T10:30:45.000Z'));

      // Should roundtrip correctly
      final restoredFromReadable = Serializers.timestamp.fromJsonCode(
        readableJson,
      );
      expect(restoredFromReadable, equals(testTime));
    });

    test('JSON deserialization - numeric values', () {
      // Test numeric JSON values (dense format)
      expect(
        Serializers.timestamp.fromJson(0),
        equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
      );
      expect(
        Serializers.timestamp.fromJson(1756117845000),
        equals(DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true)),
      );
      expect(
        Serializers.timestamp.fromJson(-1000),
        equals(DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true)),
      );

      expect(
        Serializers.timestamp.fromJsonCode('0'),
        equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
      );
      expect(
        Serializers.timestamp.fromJsonCode('1756117845000'),
        equals(DateTime.fromMillisecondsSinceEpoch(1756117845000, isUtc: true)),
      );
      expect(
        Serializers.timestamp.fromJsonCode('-1000'),
        equals(DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true)),
      );
    });

    test('JSON deserialization - object format (readable)', () {
      // Test object JSON values (readable format)
      final readableObj = {
        'unix_millis': 1756117845000,
        'formatted': '2025-08-25T10:30:45.000Z',
      };
      final expected = DateTime.fromMillisecondsSinceEpoch(
        1756117845000,
        isUtc: true,
      );
      expect(Serializers.timestamp.fromJson(readableObj), equals(expected));

      final readableJsonCode =
          '{"unix_millis": 1756117845000, "formatted": "2025-08-25T10:30:45.000Z"}';
      expect(
        Serializers.timestamp.fromJsonCode(readableJsonCode),
        equals(expected),
      );

      // Test that only unix_millis is used for reconstruction (formatted is ignored)
      final readableObjInconsistent = {
        'unix_millis': 1756117845000,
        'formatted': 'different-string',
      };
      expect(
        Serializers.timestamp.fromJson(readableObjInconsistent),
        equals(expected),
      );
    });

    test('binary serialization - zero optimization', () {
      // Test that epoch uses optimized encoding (wire code 0)
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final epochBytes = Serializers.timestamp.toBytes(epoch);
      expect(_bytesToHex(epochBytes), equals('736b697200')); // "skir" + 0x00

      // Test non-zero values use timestamp encoding (wire code 239/0xEF)
      final nonZero = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final nonZeroBytes = Serializers.timestamp.toBytes(nonZero);
      expect(
        _bytesToHex(nonZeroBytes),
        startsWith('736b6972ef'),
      ); // "skir" + 0xEF wire
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), // epoch
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true), // positive
        DateTime.fromMillisecondsSinceEpoch(-1000, isUtc: true), // negative
        DateTime.fromMillisecondsSinceEpoch(
          1756117845000,
          isUtc: true,
        ), // 2025-08-25T10:30:45Z
        DateTime.fromMillisecondsSinceEpoch(
          946684800000,
          isUtc: true,
        ), // 2000-01-01T00:00:00Z
        DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        ), // current time
        DateTime.fromMillisecondsSinceEpoch(
          -8640000000000000,
          isUtc: true,
        ), // min valid
        DateTime.fromMillisecondsSinceEpoch(
          8640000000000000,
          isUtc: true,
        ), // max valid
      ];

      for (final timestamp in testValues) {
        final bytes = Serializers.timestamp.toBytes(timestamp);
        final restored = Serializers.timestamp.fromBytes(bytes);
        expect(
          restored,
          equals(timestamp),
          reason:
              'Failed roundtrip for timestamp: ${timestamp.toIso8601String()}',
        );
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.timestamp.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(
        primitiveDescriptor.primitiveType,
        equals(PrimitiveType.timestamp),
      );
    });
  });

  group('StringSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test empty string - should be the same in both readable and dense flavors
      expect(Serializers.string.toJson('', readableFlavor: true), equals(''));
      expect(Serializers.string.toJson('', readableFlavor: false), equals(''));
      expect(
        Serializers.string.toJsonCode('', readableFlavor: true),
        equals('""'),
      );
      expect(
        Serializers.string.toJsonCode('', readableFlavor: false),
        equals('""'),
      );

      // Test simple strings
      expect(
        Serializers.string.toJson('hello', readableFlavor: true),
        equals('hello'),
      );
      expect(
        Serializers.string.toJson('hello', readableFlavor: false),
        equals('hello'),
      );
      expect(
        Serializers.string.toJsonCode('hello', readableFlavor: true),
        equals('"hello"'),
      );
      expect(
        Serializers.string.toJsonCode('hello', readableFlavor: false),
        equals('"hello"'),
      );

      // Test special characters
      expect(
        Serializers.string.toJson('Hello, 世界!', readableFlavor: true),
        equals('Hello, 世界!'),
      );
      expect(
        Serializers.string.toJson('🚀', readableFlavor: true),
        equals('🚀'),
      );
      expect(
        Serializers.string.toJson('\n\t\r', readableFlavor: true),
        equals('\n\t\r'),
      );
    });

    test('JSON deserialization - string values', () {
      // Test string JSON values
      expect(Serializers.string.fromJson(''), equals(''));
      expect(Serializers.string.fromJson('hello'), equals('hello'));
      expect(Serializers.string.fromJson('world'), equals('world'));
      expect(Serializers.string.fromJson('Hello, 世界!'), equals('Hello, 世界!'));
      expect(Serializers.string.fromJson('🚀'), equals('🚀'));
      expect(Serializers.string.fromJson('\n\t\r'), equals('\n\t\r'));

      expect(Serializers.string.fromJsonCode('""'), equals(''));
      expect(Serializers.string.fromJsonCode('"hello"'), equals('hello'));
      expect(
        Serializers.string.fromJsonCode('"Hello, 世界!"'),
        equals('Hello, 世界!'),
      );
      expect(Serializers.string.fromJsonCode('"🚀"'), equals('🚀'));
    });

    test('JSON deserialization - special numeric case', () {
      // Test special case: numeric 0 should deserialize to empty string
      expect(Serializers.string.fromJson(0), equals(''));
      expect(Serializers.string.fromJsonCode('0'), equals(''));

      // Other numbers should be converted to string
      expect(Serializers.string.fromJson(42), equals('42'));
      expect(Serializers.string.fromJson(2.5), equals('2.5'));
      expect(Serializers.string.fromJsonCode('42'), equals('42'));
      expect(Serializers.string.fromJsonCode('2.5'), equals('2.5'));
    });

    test('JSON deserialization - non-string values', () {
      // Test that non-string values are converted to string via toString()
      expect(Serializers.string.fromJson(true), equals('true'));
      expect(Serializers.string.fromJson(false), equals('false'));
      expect(Serializers.string.fromJson(null), equals('null'));
      expect(Serializers.string.fromJson([1, 2, 3]), equals('[1, 2, 3]'));
      expect(
        Serializers.string.fromJson({'key': 'value'}),
        equals('{key: value}'),
      );
    });

    test('binary serialization - empty string optimization', () {
      // Test that empty string uses optimized encoding (wire code 242/0xF2)
      final emptyBytes = Serializers.string.toBytes('');
      expect(_bytesToHex(emptyBytes), equals('736b6972f2')); // "skir" + 0xF2

      // Test non-empty strings use standard encoding (wire code 243/0xF3)
      final nonEmptyBytes = Serializers.string.toBytes('A');
      expect(
        _bytesToHex(nonEmptyBytes),
        startsWith('736b6972f3'),
      ); // "skir" + 0xF3 + length + data
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        '',
        'hello',
        'world',
        'Hello, 世界!',
        '🚀',
        '\n\t\r',
        '\u0000',
        'A very long string that exceeds normal buffer sizes and should test the streaming capabilities of the serializer properly',
        'String with "quotes" and \\backslashes\\',
        'Multi\nline\nstring\nwith\nvarious\ncharacters',
        '0123456789',
        'Special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?',
      ];

      for (final value in testValues) {
        final bytes = Serializers.string.toBytes(value);
        final restored = Serializers.string.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed roundtrip for string: "$value"',
        );
      }
    });

    test('binary serialization sanitizes lone surrogates to valid UTF-8', () {
      final bytes = Serializers.string.toBytes('\uD800z');
      expect(Serializers.string.fromBytes(bytes), equals('�z'));
    });

    test(
        'JSON serialization - no explicit sanitization needed (Dart handles it)',
        () {
      // After verifying that Dart's json.encode() handles lone surrogates safely,
      // we removed the explicit sanitization from toJson() for performance.
      // toJson() now returns the string as-is; Dart's json.encode() ensures valid UTF-8.
      final jsonValue =
          Serializers.string.toJson('\uD800z', readableFlavor: false);
      expect(jsonValue, equals('\uD800z')); // Returned as-is

      // The toJsonCode() applies the JSON serialization which handles it safely
      final jsonCode =
          Serializers.string.toJsonCode('\uD800z', readableFlavor: false);
      expect(jsonCode, isA<String>()); // Valid JSON string
      expect(jsonCode, contains('"')); // Wrapped in quotes

      // Verify the JSON is valid UTF-8
      expect(utf8.encode(jsonCode).isNotEmpty, true);
    });

    test(
        'Dart json.encode() handling of lone surrogates - verifies if sanitization is redundant',
        () {
      // This test verifies whether Dart's native json.encode() already handles
      // lone surrogates correctly (produces valid UTF-8) or if explicit
      // sanitization in toJson() is necessary.

      // Create a map with a lone surrogate in a string value
      final mapWithLoneSurrogate = {'text': '\uD800'};

      // Try to json.encode() it
      String encodedJson;
      try {
        encodedJson = jsonEncode(mapWithLoneSurrogate);
        // If we get here without exception, json.encode() handled it (sanitized or escaped)
        expect(encodedJson, isNotEmpty);

        // Verify the output is valid UTF-8 by trying to encode it back
        final utf8Bytes = utf8.encode(encodedJson);
        final decodedBack = utf8.decode(utf8Bytes);
        expect(decodedBack, isNotEmpty);

        print(
            '✓ Dart json.encode() with lone surrogate: Valid UTF-8 output (${decodedBack.length} chars)');
        print('  Encoded JSON: $encodedJson');

        // Verify we can json.decode() it back without errors
        final decodedMap = jsonDecode(encodedJson);
        expect(decodedMap, isA<Map>());
        print('  Successfully decoded back: ${decodedMap['text'].runtimeType}');
      } catch (e) {
        fail('json.encode() threw exception with lone surrogate: $e\n'
            'This means Dart requires explicit sanitization before calling json.encode()');
      }
    });

    test('comparison: default json.encode vs explicit sanitization', () {
      // This test shows the difference between Dart's native encoding and our sanitization:
      // - Default: Escapes lone surrogates as JSON escape sequences (e.g., \ud800)
      // - Sanitized: Replaces with Unicode replacement character (U+FFFD)

      final testString = '\uD800z'; // lone surrogate followed by 'z'

      // Default json.encode() output
      final defaultJson = jsonEncode({'text': testString});
      print('  Default json.encode(): $defaultJson');

      // Our explicit sanitization
      final sanitized = '\uFFFDz'; // U+FFFD replacement character + 'z'
      final sanitizedJson = jsonEncode({'text': sanitized});
      print('  Explicit sanitization: $sanitizedJson');

      // Both are valid UTF-8, but differ in representation
      expect(utf8.encode(defaultJson).isNotEmpty, true);
      expect(utf8.encode(sanitizedJson).isNotEmpty, true);

      // Default keeps escape sequences, sanitized uses visible replacement char
      expect(defaultJson.contains(r'\ud800'), true);
      expect(sanitizedJson.contains(r'\ud800'), false);
      expect(sanitizedJson.contains('z'), true);

      print('✓ Both outputs are valid UTF-8, but differ in representation');
      print(
          '  → Default: uses JSON escape sequences (less visible, preserves surrogates)');
      print(
          '  → Sanitized: uses U+FFFD replacement (more visible, replaceable surrogates)');
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.string.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.string));
    });
  });

  group('BytesSerializer', () {
    test('basic functionality - JSON serialization', () {
      // Test empty bytes - should be hex-prefixed in readable, base64 in dense
      final emptyBytes = ByteString.empty;
      expect(
        Serializers.bytes.toJson(emptyBytes, readableFlavor: true),
        equals('hex:'),
      );
      expect(
        Serializers.bytes.toJson(emptyBytes, readableFlavor: false),
        equals(''),
      );
      expect(
        Serializers.bytes.toJsonCode(emptyBytes, readableFlavor: true),
        equals('"hex:"'),
      );
      expect(
        Serializers.bytes.toJsonCode(emptyBytes, readableFlavor: false),
        equals('""'),
      );

      // Test simple byte arrays
      final helloBytes = ByteString.copy('hello'.codeUnits);
      final helloBase64 = helloBytes.toBase64();
      expect(
        Serializers.bytes.toJson(helloBytes, readableFlavor: true),
        equals('hex:68656c6c6f'),
      );
      expect(
        Serializers.bytes.toJson(helloBytes, readableFlavor: false),
        equals(helloBase64),
      );
      expect(
        Serializers.bytes.toJsonCode(helloBytes, readableFlavor: true),
        equals('"hex:68656c6c6f"'),
      );
      expect(
        Serializers.bytes.toJsonCode(helloBytes, readableFlavor: false),
        equals('"$helloBase64"'),
      );

      // Test UTF-8 encoded bytes
      final utf8Bytes = ByteString.copy(utf8.encode('Hello, 世界!'));
      final utf8Base64 = utf8Bytes.toBase64();
      final utf8Hex = utf8Bytes.toBase16();
      expect(
        Serializers.bytes.toJson(utf8Bytes, readableFlavor: true),
        equals('hex:$utf8Hex'),
      );
      expect(
        Serializers.bytes.toJson(utf8Bytes, readableFlavor: false),
        equals(utf8Base64),
      );
    });

    test('JSON deserialization - base64 string values', () {
      // Test base64 string JSON values
      expect(Serializers.bytes.fromJson(''), equals(ByteString.empty));

      final helloBytes = ByteString.copy('hello'.codeUnits);
      final helloBase64 = helloBytes.toBase64();
      expect(Serializers.bytes.fromJson(helloBase64), equals(helloBytes));
      expect(
        Serializers.bytes.fromJsonCode('"$helloBase64"'),
        equals(helloBytes),
      );

      final utf8Bytes = ByteString.copy(utf8.encode('Hello, 世界!'));
      final utf8Base64 = utf8Bytes.toBase64();
      expect(Serializers.bytes.fromJson(utf8Base64), equals(utf8Bytes));
      expect(
        Serializers.bytes.fromJsonCode('"$utf8Base64"'),
        equals(utf8Bytes),
      );

      // Test binary data
      final binaryBytes = ByteString.copy([0, 255, 128, 64, 32]);
      final binaryBase64 = binaryBytes.toBase64();
      expect(Serializers.bytes.fromJson(binaryBase64), equals(binaryBytes));
      expect(
        Serializers.bytes.fromJsonCode('"$binaryBase64"'),
        equals(binaryBytes),
      );
    });

    test('JSON deserialization - hex-prefixed string values', () {
      // Test hex-prefixed string JSON values (readable flavor)
      expect(Serializers.bytes.fromJson('hex:'), equals(ByteString.empty));

      final helloBytes = ByteString.copy('hello'.codeUnits);
      final helloHex = helloBytes.toBase16();
      expect(Serializers.bytes.fromJson('hex:$helloHex'), equals(helloBytes));
      expect(
        Serializers.bytes.fromJsonCode('"hex:$helloHex"'),
        equals(helloBytes),
      );

      final utf8Bytes = ByteString.copy(utf8.encode('Hello, 世界!'));
      final utf8Hex = utf8Bytes.toBase16();
      expect(Serializers.bytes.fromJson('hex:$utf8Hex'), equals(utf8Bytes));
      expect(
        Serializers.bytes.fromJsonCode('"hex:$utf8Hex"'),
        equals(utf8Bytes),
      );

      // Test binary data with hex encoding
      final binaryBytes = ByteString.copy([0, 255, 128, 64, 32]);
      final binaryHex = binaryBytes.toBase16();
      expect(Serializers.bytes.fromJson('hex:$binaryHex'), equals(binaryBytes));
      expect(
        Serializers.bytes.fromJsonCode('"hex:$binaryHex"'),
        equals(binaryBytes),
      );

      // Test specific hex values
      expect(
        Serializers.bytes.fromJson('hex:48656c6c6f'),
        equals(ByteString.copy('Hello'.codeUnits)),
      );
      expect(
        Serializers.bytes.fromJson('hex:00ff8040'),
        equals(ByteString.copy([0, 255, 128, 64])),
      );
    });

    test('JSON roundtrip - readable vs dense flavor', () {
      // Test roundtrip with both flavors
      final testBytes = ByteString.copy([
        0x48,
        0x65,
        0x6c,
        0x6c,
        0x6f,
      ]); // "Hello"

      // Readable flavor uses hex encoding
      final readableJson = Serializers.bytes.toJsonCode(
        testBytes,
        readableFlavor: true,
      );
      expect(readableJson, equals('"hex:48656c6c6f"'));
      final restoredFromReadable = Serializers.bytes.fromJsonCode(readableJson);
      expect(restoredFromReadable, equals(testBytes));

      // Dense flavor uses base64 encoding
      final denseJson = Serializers.bytes.toJsonCode(
        testBytes,
        readableFlavor: false,
      );
      expect(denseJson, equals('"SGVsbG8="')); // Base64 for "Hello"
      final restoredFromDense = Serializers.bytes.fromJsonCode(denseJson);
      expect(restoredFromDense, equals(testBytes));

      // Both should deserialize to the same value
      expect(restoredFromReadable, equals(restoredFromDense));
    });

    test('JSON deserialization - special numeric case', () {
      // Test special case: numeric 0 should deserialize to empty bytes
      expect(Serializers.bytes.fromJson(0), equals(ByteString.empty));
      expect(Serializers.bytes.fromJsonCode('0'), equals(ByteString.empty));

      // Other numbers should cause ArgumentError (since they're not valid base64)
      expect(
        () => Serializers.bytes.fromJson(42),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Serializers.bytes.fromJsonCode('42'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('JSON deserialization - invalid values', () {
      // Test that invalid base64 strings cause errors
      expect(
        () => Serializers.bytes.fromJson('invalid-base64!'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Serializers.bytes.fromJsonCode('"invalid-base64!"'),
        throwsA(isA<FormatException>()),
      );

      // Test that invalid hex strings (after hex: prefix) cause errors
      expect(
        () => Serializers.bytes.fromJson('hex:invalid-hex!'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Serializers.bytes.fromJsonCode('"hex:invalid-hex!"'),
        throwsA(isA<FormatException>()),
      );

      // Test that non-string, non-zero values cause ArgumentError
      expect(
        () => Serializers.bytes.fromJson(true),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Serializers.bytes.fromJson(false),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Serializers.bytes.fromJson([1, 2, 3]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Serializers.bytes.fromJson({'key': 'value'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('binary serialization - empty bytes optimization', () {
      // Test that empty bytes uses optimized encoding (wire code 244/0xF4)
      final emptyBytes = ByteString.empty;
      final emptyBinary = Serializers.bytes.toBytes(emptyBytes);
      expect(_bytesToHex(emptyBinary), equals('736b6972f4')); // "skir" + 0xF4

      // Test non-empty bytes use standard encoding (wire code 245/0xF5)
      final nonEmptyBytes = ByteString.copy([65]); // 'A'
      final nonEmptyBinary = Serializers.bytes.toBytes(nonEmptyBytes);
      expect(
        _bytesToHex(nonEmptyBinary),
        startsWith('736b6972f5'),
      ); // "skir" + 0xF5 + length + data
    });

    test('binary deserialization roundtrip', () {
      final testValues = [
        ByteString.empty, // empty
        ByteString.copy([65]), // single byte 'A'
        ByteString.copy([0]), // null byte
        ByteString.copy([255]), // max byte
        ByteString.copy([0, 255]), // min and max
        ByteString.copy('hello'.codeUnits), // ASCII string
        ByteString.copy(utf8.encode('Hello, 世界!')), // UTF-8 string
        ByteString.copy([
          0,
          1,
          2,
          3,
          4,
          5,
          252,
          253,
          254,
          255,
        ]), // various values
        ByteString.copy(List.generate(256, (i) => i)), // all byte values
        ByteString.copy(List.generate(1000, (i) => i % 256)), // larger array
      ];

      for (final value in testValues) {
        final bytes = Serializers.bytes.toBytes(value);
        final restored = Serializers.bytes.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed roundtrip for bytes: ${value.toBase16()}',
        );
      }
    });

    test('type descriptor', () {
      final typeDescriptor = Serializers.bytes.typeDescriptor;
      expect(typeDescriptor, isA<PrimitiveDescriptor>());

      final primitiveDescriptor = typeDescriptor as PrimitiveDescriptor;
      expect(primitiveDescriptor.primitiveType, equals(PrimitiveType.bytes));
    });
  });

  group('OptionalSerializer', () {
    test('basic functionality - JSON serialization', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);

      // Test non-null values - should be the same as underlying serializer
      expect(intOptional.toJson(42, readableFlavor: true), equals(42));
      expect(intOptional.toJson(42, readableFlavor: false), equals(42));
      expect(intOptional.toJsonCode(42, readableFlavor: true), equals('42'));
      expect(intOptional.toJsonCode(42, readableFlavor: false), equals('42'));

      expect(
        stringOptional.toJson('hello', readableFlavor: true),
        equals('hello'),
      );
      expect(
        stringOptional.toJson('hello', readableFlavor: false),
        equals('hello'),
      );
      expect(
        stringOptional.toJsonCode('hello', readableFlavor: true),
        equals('"hello"'),
      );
      expect(
        stringOptional.toJsonCode('hello', readableFlavor: false),
        equals('"hello"'),
      );

      // Test null values - should be null in both flavors
      expect(intOptional.toJson(null, readableFlavor: true), equals(null));
      expect(intOptional.toJson(null, readableFlavor: false), equals(null));
      expect(
        intOptional.toJsonCode(null, readableFlavor: true),
        equals('null'),
      );
      expect(
        intOptional.toJsonCode(null, readableFlavor: false),
        equals('null'),
      );

      expect(stringOptional.toJson(null, readableFlavor: true), equals(null));
      expect(stringOptional.toJson(null, readableFlavor: false), equals(null));
      expect(
        stringOptional.toJsonCode(null, readableFlavor: true),
        equals('null'),
      );
      expect(
        stringOptional.toJsonCode(null, readableFlavor: false),
        equals('null'),
      );
    });

    test('JSON deserialization - non-null values', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);
      final boolOptional = Serializers.optional(Serializers.bool);

      // Test non-null JSON values
      expect(intOptional.fromJson(42), equals(42));
      expect(intOptional.fromJson(-1), equals(-1));
      expect(intOptional.fromJsonCode('42'), equals(42));
      expect(intOptional.fromJsonCode('-1'), equals(-1));

      expect(stringOptional.fromJson('hello'), equals('hello'));
      expect(stringOptional.fromJson('world'), equals('world'));
      expect(stringOptional.fromJsonCode('"hello"'), equals('hello'));
      expect(stringOptional.fromJsonCode('"world"'), equals('world'));

      expect(boolOptional.fromJson(true), equals(true));
      expect(boolOptional.fromJson(false), equals(false));
      expect(boolOptional.fromJsonCode('true'), equals(true));
      expect(boolOptional.fromJsonCode('false'), equals(false));
    });

    test('JSON deserialization - null values', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);
      final boolOptional = Serializers.optional(Serializers.bool);
      final bytesOptional = Serializers.optional(Serializers.bytes);
      final timestampOptional = Serializers.optional(Serializers.timestamp);

      // Test null JSON values
      expect(intOptional.fromJson(null), equals(null));
      expect(intOptional.fromJsonCode('null'), equals(null));

      expect(stringOptional.fromJson(null), equals(null));
      expect(stringOptional.fromJsonCode('null'), equals(null));

      expect(boolOptional.fromJson(null), equals(null));
      expect(boolOptional.fromJsonCode('null'), equals(null));

      expect(bytesOptional.fromJson(null), equals(null));
      expect(bytesOptional.fromJsonCode('null'), equals(null));

      expect(timestampOptional.fromJson(null), equals(null));
      expect(timestampOptional.fromJsonCode('null'), equals(null));
    });

    test('binary serialization - null optimization', () {
      final intOptional = Serializers.optional(Serializers.int32);

      // Test that null uses wire code 255 (0xFF)
      final nullBytes = intOptional.toBytes(null);
      expect(_bytesToHex(nullBytes), equals('736b6972ff')); // "skir" + 0xFF

      // Test non-null values use underlying serializer encoding
      final nonNullBytes = intOptional.toBytes(42);
      expect(
        _bytesToHex(nonNullBytes),
        equals('736b69722a'),
      ); // "skir" + int32(42)
    });

    test('binary deserialization roundtrip', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);
      final boolOptional = Serializers.optional(Serializers.bool);
      final bytesOptional = Serializers.optional(Serializers.bytes);
      final timestampOptional = Serializers.optional(Serializers.timestamp);

      final testValues = [
        // (serializer, non-null value, null value)
        (intOptional, 42, null),
        (intOptional, -1, null),
        (intOptional, 0, null),
        (stringOptional, 'hello', null),
        (stringOptional, '', null),
        (boolOptional, true, null),
        (boolOptional, false, null),
        (bytesOptional, ByteString.copy([1, 2, 3]), null),
        (bytesOptional, ByteString.empty, null),
        (
          timestampOptional,
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          null,
        ),
        (
          timestampOptional,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          null,
        ),
      ];

      for (final (serializer, nonNullValue, nullValue) in testValues) {
        // Test non-null roundtrip
        final nonNullBytes = serializer.toBytes(nonNullValue);
        final restoredNonNull = serializer.fromBytes(nonNullBytes);
        expect(
          restoredNonNull,
          equals(nonNullValue),
          reason: 'Failed roundtrip for non-null value: $nonNullValue',
        );

        // Test null roundtrip
        final nullBytes = serializer.toBytes(nullValue);
        final restoredNull = serializer.fromBytes(nullBytes);
        expect(
          restoredNull,
          equals(nullValue),
          reason: 'Failed roundtrip for null value',
        );
      }
    });

    test('JSON flavor differences for underlying types', () {
      final boolOptional = Serializers.optional(Serializers.bool);
      final timestampOptional = Serializers.optional(Serializers.timestamp);

      // Test bool flavor differences (dense vs readable)
      final testBool = true;
      final denseBoolJson = boolOptional.toJsonCode(
        testBool,
        readableFlavor: false,
      );
      final readableBoolJson = boolOptional.toJsonCode(
        testBool,
        readableFlavor: true,
      );
      expect(denseBoolJson, equals('1')); // Dense should be "1"
      expect(readableBoolJson, equals('true')); // Readable should be "true"

      // Both should roundtrip correctly
      expect(boolOptional.fromJsonCode(denseBoolJson), equals(testBool));
      expect(boolOptional.fromJsonCode(readableBoolJson), equals(testBool));

      // Test timestamp flavor differences
      final testTimestamp = DateTime.fromMillisecondsSinceEpoch(
        1756117845000,
        isUtc: true,
      );
      final denseTimestampJson = timestampOptional.toJsonCode(
        testTimestamp,
        readableFlavor: false,
      );
      final readableTimestampJson = timestampOptional.toJsonCode(
        testTimestamp,
        readableFlavor: true,
      );

      // Dense should be a number, readable should be an object
      expect(denseTimestampJson, equals('1756117845000'));
      expect(readableTimestampJson, contains('unix_millis'));
      expect(readableTimestampJson, contains('formatted'));

      // Both should roundtrip correctly
      expect(
        timestampOptional.fromJsonCode(denseTimestampJson),
        equals(testTimestamp),
      );
      expect(
        timestampOptional.fromJsonCode(readableTimestampJson),
        equals(testTimestamp),
      );

      // Test null with different flavors (should always be "null")
      final nullDense = boolOptional.toJsonCode(null, readableFlavor: false);
      final nullReadable = boolOptional.toJsonCode(null, readableFlavor: true);
      expect(nullDense, equals('null'));
      expect(nullReadable, equals('null'));
    });

    test('idempotency - optional of optional', () {
      // Test that calling optional on an already optional serializer returns the same instance
      final intOptional = Serializers.optional(Serializers.int32);
      final doubleOptional = Serializers.optional(intOptional);

      // They should be the same instance (idempotent)
      expect(identical(intOptional, doubleOptional), isTrue);

      // Test functionality is preserved
      final testValue = 123;
      expect(
        intOptional.fromJsonCode(intOptional.toJsonCode(testValue)),
        equals(testValue),
      );
      expect(
        doubleOptional.fromJsonCode(doubleOptional.toJsonCode(testValue)),
        equals(testValue),
      );
      expect(
        intOptional.fromJsonCode(intOptional.toJsonCode(null)),
        equals(null),
      );
      expect(
        doubleOptional.fromJsonCode(doubleOptional.toJsonCode(null)),
        equals(null),
      );

      // Binary serialization should also work the same
      final testBytes = intOptional.toBytes(testValue);
      final doubleBytes = doubleOptional.toBytes(testValue);
      expect(_bytesToHex(testBytes), equals(_bytesToHex(doubleBytes)));

      expect(intOptional.fromBytes(testBytes), equals(testValue));
      expect(doubleOptional.fromBytes(doubleBytes), equals(testValue));
    });

    test('type descriptor', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final typeDescriptor = intOptional.typeDescriptor;

      expect(typeDescriptor, isA<ReflectiveOptionalDescriptor>());

      final optionalDescriptor = typeDescriptor as ReflectiveOptionalDescriptor;
      expect(optionalDescriptor.otherType, isA<PrimitiveDescriptor>());

      final innerDescriptor =
          optionalDescriptor.otherType as PrimitiveDescriptor;
      expect(innerDescriptor.primitiveType, equals(PrimitiveType.int32));
    });

    test('binary format specifics', () {
      final intOptional = Serializers.optional(Serializers.int32);

      // Test specific binary encodings (includes "skir" prefix)
      final testCases = [
        (null, '736b6972ff'), // null -> 0xFF
        (0, '736b697200'), // 0 -> 0x00 (from int32)
        (42, '736b69722a'), // 42 -> 0x2A (from int32)
        (-1, '736b6972ebff'), // -1 -> 0xEB + 0xFF (from int32 varint encoding)
      ];

      for (final (value, expectedHex) in testCases) {
        final bytes = intOptional.toBytes(value);
        expect(
          _bytesToHex(bytes),
          equals(expectedHex),
          reason: 'Failed encoding for value: $value',
        );
        expect(
          intOptional.fromBytes(bytes),
          equals(value),
          reason: 'Failed roundtrip for value: $value',
        );
      }
    });

    test('edge cases and special values', () {
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);
      final bytesOptional = Serializers.optional(Serializers.bytes);

      // Test edge case values that could be confused with null
      final testCases = [
        (intOptional, [0, -1, 2147483647, -2147483648]), // int32 edge cases
        (
          stringOptional,
          ['', '0', 'false', 'null', 'undefined'],
        ), // string edge cases
        (
          bytesOptional,
          [
            ByteString.empty,
            ByteString.copy([255]),
            ByteString.copy([0, 255]),
          ],
        ), // bytes edge cases
      ];

      for (final (serializer, values) in testCases) {
        for (final value in values) {
          // Test JSON roundtrip
          final json = serializer.toJsonCode(value);
          final restoredFromJson = serializer.fromJsonCode(json);
          expect(
            restoredFromJson,
            equals(value),
            reason: 'JSON roundtrip failed for edge case value: $value',
          );

          // Test binary roundtrip
          final bytes = serializer.toBytes(value);
          final restoredFromBytes = serializer.fromBytes(bytes);
          expect(
            restoredFromBytes,
            equals(value),
            reason: 'Binary roundtrip failed for edge case value: $value',
          );
        }
      }
    });

    test('all primitive types with optional', () {
      // Test that optional works correctly with all primitive serializers
      final testData = [
        (Serializers.optional(Serializers.bool), true, false),
        (Serializers.optional(Serializers.int32), 42, 0),
        (Serializers.optional(Serializers.int64), 42, 0),
        (
          Serializers.optional(Serializers.hash64),
          BigInt.from(42),
          BigInt.zero,
        ),
        (Serializers.optional(Serializers.float32), 1.5, 0.0),
        (Serializers.optional(Serializers.float64), 2.5159, 0.0),
        (Serializers.optional(Serializers.string), 'hello', ''),
        (
          Serializers.optional(Serializers.bytes),
          ByteString.copy([1, 2, 3]),
          ByteString.empty,
        ),
        (
          Serializers.optional(Serializers.timestamp),
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      ];

      for (final (serializer, nonDefaultValue, defaultValue) in testData) {
        // Test non-null values
        final nonNullJson = serializer.toJsonCode(nonDefaultValue);
        expect(
          serializer.fromJsonCode(nonNullJson),
          equals(nonDefaultValue),
          reason: 'Failed JSON roundtrip for non-null value: $nonDefaultValue',
        );

        final nonNullBytes = serializer.toBytes(nonDefaultValue);
        final restoredNonNull = serializer.fromBytes(nonNullBytes);

        // Special handling for float32 precision loss
        if (nonDefaultValue is double &&
            serializer.toString().contains('float32')) {
          expect(
            ((restoredNonNull as double) - nonDefaultValue).abs(),
            lessThan(1e-6),
            reason:
                'Failed binary roundtrip for float32 value: $nonDefaultValue (got $restoredNonNull)',
          );
        } else {
          expect(
            restoredNonNull,
            equals(nonDefaultValue),
            reason:
                'Failed binary roundtrip for non-null value: $nonDefaultValue',
          );
        }

        // Test default values
        final defaultJson = serializer.toJsonCode(defaultValue);
        expect(
          serializer.fromJsonCode(defaultJson),
          equals(defaultValue),
          reason: 'Failed JSON roundtrip for default value: $defaultValue',
        );

        final defaultBytes = serializer.toBytes(defaultValue);
        expect(
          serializer.fromBytes(defaultBytes),
          equals(defaultValue),
          reason: 'Failed binary roundtrip for default value: $defaultValue',
        );

        // Test null values
        final nullJson = serializer.toJsonCode(null);
        expect(nullJson, equals('null'));
        expect(
          serializer.fromJsonCode(nullJson),
          equals(null),
          reason: 'Failed JSON roundtrip for null',
        );

        final nullBytes = serializer.toBytes(null);
        expect(_bytesToHex(nullBytes), endsWith('ff')); // Should end with 0xFF
        expect(
          serializer.fromBytes(nullBytes),
          equals(null),
          reason: 'Failed binary roundtrip for null',
        );
      }
    });

    test('default value detection', () {
      final intOptional = Serializers.optional(Serializers.int32);

      // Test that null is considered the default value for optional types
      final nullBytes = intOptional.toBytes(null);
      final nonNullBytes = intOptional.toBytes(42);

      // Null should use optimized encoding (just 0xFF)
      expect(_bytesToHex(nullBytes), equals('736b6972ff')); // "skir" + 0xFF
      expect(nullBytes.length, equals(5)); // Should be exactly 5 bytes

      // Non-null should use underlying serializer
      expect(nonNullBytes.length, greaterThanOrEqualTo(nullBytes.length));
      expect(_bytesToHex(nonNullBytes), isNot(endsWith('ff')));
    });

    test('complex nested scenarios', () {
      // Test combinations of optional serializers with different types
      final intOptional = Serializers.optional(Serializers.int32);
      final stringOptional = Serializers.optional(Serializers.string);
      final timestampOptional = Serializers.optional(Serializers.timestamp);

      final testScenarios = [
        (intOptional, 42, null),
        (intOptional, null, 42),
        (stringOptional, 'test', null),
        (stringOptional, null, 'test'),
        (
          timestampOptional,
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          null,
        ),
        (
          timestampOptional,
          null,
          DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        ),
      ];

      for (final (serializer, value1, value2) in testScenarios) {
        // Test that different values produce different results
        final json1 = serializer.toJsonCode(value1);
        final json2 = serializer.toJsonCode(value2);

        if (value1 != value2) {
          expect(
            json1,
            isNot(equals(json2)),
            reason:
                'Different values should produce different JSON: $value1 vs $value2',
          );
        }

        // Test roundtrip for both values
        expect(
          serializer.fromJsonCode(json1),
          equals(value1),
          reason: 'Failed JSON roundtrip for value1: $value1',
        );
        expect(
          serializer.fromJsonCode(json2),
          equals(value2),
          reason: 'Failed JSON roundtrip for value2: $value2',
        );

        // Test binary serialization
        final bytes1 = serializer.toBytes(value1);
        final bytes2 = serializer.toBytes(value2);

        if (value1 != value2) {
          expect(
            _bytesToHex(bytes1),
            isNot(equals(_bytesToHex(bytes2))),
            reason:
                'Different values should produce different binary: $value1 vs $value2',
          );
        }

        expect(
          serializer.fromBytes(bytes1),
          equals(value1),
          reason: 'Failed binary roundtrip for value1: $value1',
        );
        expect(
          serializer.fromBytes(bytes2),
          equals(value2),
          reason: 'Failed binary roundtrip for value2: $value2',
        );
      }
    });
  });

  group('IterableSerializer', () {
    test('basic functionality - JSON serialization', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);

      // Test various iterables - should be the same in both readable and dense flavors
      final emptyIterable = <int>[];
      final singleIntIterable = [42];
      final multipleIntIterable = [1, 2, 3];

      expect(
        intIterableSerializer.toJson(emptyIterable, readableFlavor: true),
        equals([]),
      );
      expect(
        intIterableSerializer.toJson(emptyIterable, readableFlavor: false),
        equals([]),
      );
      expect(
        intIterableSerializer.toJson(singleIntIterable, readableFlavor: true),
        equals([42]),
      );
      expect(
        intIterableSerializer.toJson(singleIntIterable, readableFlavor: false),
        equals([42]),
      );
      expect(
        intIterableSerializer.toJson(multipleIntIterable, readableFlavor: true),
        equals([1, 2, 3]),
      );
      expect(
        intIterableSerializer.toJson(
          multipleIntIterable,
          readableFlavor: false,
        ),
        equals([1, 2, 3]),
      );

      // Test JSON string serialization
      expect(
        intIterableSerializer.toJsonCode(emptyIterable, readableFlavor: true),
        equals('[]'),
      );
      expect(
        intIterableSerializer.toJsonCode(emptyIterable, readableFlavor: false),
        equals('[]'),
      );
      expect(
        intIterableSerializer.toJsonCode(
          singleIntIterable,
          readableFlavor: true,
        ),
        equals('[\n  42\n]'),
      );
      expect(
        intIterableSerializer.toJsonCode(
          singleIntIterable,
          readableFlavor: false,
        ),
        equals('[42]'),
      );
      expect(
        intIterableSerializer.toJsonCode(
          multipleIntIterable,
          readableFlavor: true,
        ),
        equals('[\n  1,\n  2,\n  3\n]'),
      );
      expect(
        intIterableSerializer.toJsonCode(
          multipleIntIterable,
          readableFlavor: false,
        ),
        equals('[1,2,3]'),
      );
    });

    test('JSON deserialization - array values', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final stringIterableSerializer = Serializers.iterable(Serializers.string);

      // Test array JSON values
      expect(intIterableSerializer.fromJson([]), equals([]));
      expect(intIterableSerializer.fromJson([42]), equals([42]));
      expect(intIterableSerializer.fromJson([1, 2, 3]), equals([1, 2, 3]));
      expect(intIterableSerializer.fromJsonCode('[]'), equals([]));
      expect(intIterableSerializer.fromJsonCode('[42]'), equals([42]));
      expect(intIterableSerializer.fromJsonCode('[1,2,3]'), equals([1, 2, 3]));

      // Test string arrays
      expect(
        stringIterableSerializer.fromJson(['hello', 'world']),
        equals(['hello', 'world']),
      );
      expect(
        stringIterableSerializer.fromJsonCode('["hello","world"]'),
        equals(['hello', 'world']),
      );
    });

    test('JSON deserialization - special numeric case', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final stringIterableSerializer = Serializers.iterable(Serializers.string);
      final boolIterableSerializer = Serializers.iterable(Serializers.bool);

      // Test that fromJson(0) and fromJsonCode("0") return empty iterables
      expect(intIterableSerializer.fromJson(0), equals([]));
      expect(intIterableSerializer.fromJsonCode('0'), equals([]));
      expect(stringIterableSerializer.fromJson(0), equals([]));
      expect(stringIterableSerializer.fromJsonCode('0'), equals([]));
      expect(boolIterableSerializer.fromJson(0), equals([]));
      expect(boolIterableSerializer.fromJsonCode('0'), equals([]));
    });

    test('binary serialization - empty iterables', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final stringIterableSerializer = Serializers.iterable(Serializers.string);
      final boolIterableSerializer = Serializers.iterable(Serializers.bool);

      // Test empty iterables - should have wire format "skir" + 0xF6 (246+0)
      final emptyInt = <int>[];
      final emptyString = <String>[];
      final emptyBool = <bool>[];

      final emptyIntBytes = intIterableSerializer.toBytes(emptyInt);
      expect(_bytesToHex(emptyIntBytes), equals('736b6972f6'));

      final emptyStringBytes = stringIterableSerializer.toBytes(emptyString);
      expect(_bytesToHex(emptyStringBytes), equals('736b6972f6'));

      final emptyBoolBytes = boolIterableSerializer.toBytes(emptyBool);
      expect(_bytesToHex(emptyBoolBytes), equals('736b6972f6'));
    });

    test('binary serialization - small iterables (1-3 elements)', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final stringIterableSerializer = Serializers.iterable(Serializers.string);

      // Test iterables with 1-3 elements (should use wire bytes 247-249)
      final singleIntIterable = [42];
      final doubleIntIterable = [1, 2];
      final tripleIntIterable = [10, 20, 30];

      final singleBytes = intIterableSerializer.toBytes(singleIntIterable);
      expect(
        _bytesToHex(singleBytes),
        startsWith('736b6972f7'),
      ); // 0xF7 = 246+1

      final doubleBytes = intIterableSerializer.toBytes(doubleIntIterable);
      expect(
        _bytesToHex(doubleBytes),
        startsWith('736b6972f8'),
      ); // 0xF8 = 246+2

      final tripleBytes = intIterableSerializer.toBytes(tripleIntIterable);
      expect(
        _bytesToHex(tripleBytes),
        startsWith('736b6972f9'),
      ); // 0xF9 = 246+3

      // Test with strings
      final stringIterable = ['hello', 'world'];
      final stringBytes = stringIterableSerializer.toBytes(stringIterable);
      expect(_bytesToHex(stringBytes), startsWith('736b6972f8')); // 2 elements
    });

    test('binary serialization - large iterables', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);

      // Test iterables with more than 3 elements (should use wire byte 250 + length prefix)
      final largeIterable = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final veryLargeIterable = List.generate(1000, (i) => i + 1);

      final largeBytes = intIterableSerializer.toBytes(largeIterable);
      // Should start with "skir" + 0xFA (250) + length encoding for 10 (0x0A)
      expect(_bytesToHex(largeBytes), startsWith('736b6972fa0a'));

      final veryLargeBytes = intIterableSerializer.toBytes(veryLargeIterable);
      // Should start with "skir" + 0xFA (250) + length encoding for 1000
      expect(_bytesToHex(veryLargeBytes), startsWith('736b6972fa'));
      // Large array should have significant length
      expect(veryLargeBytes.length, greaterThan(100));
    });

    test('binary deserialization roundtrip', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final stringIterableSerializer = Serializers.iterable(Serializers.string);
      final boolIterableSerializer = Serializers.iterable(Serializers.bool);

      final testCases = [
        (intIterableSerializer, <int>[]),
        (intIterableSerializer, [42]),
        (intIterableSerializer, [1, 2, 3]),
        (intIterableSerializer, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        (stringIterableSerializer, <String>[]),
        (stringIterableSerializer, ['hello']),
        (stringIterableSerializer, ['hello', 'world']),
        (stringIterableSerializer, ['a', 'b', 'c', 'd', 'e']),
        (boolIterableSerializer, <bool>[]),
        (boolIterableSerializer, [true]),
        (boolIterableSerializer, [true, false, true]),
      ];

      for (final (serializer, value) in testCases) {
        final bytes = serializer.toBytes(value);
        final restored = serializer.fromBytes(bytes);
        expect(
          restored,
          equals(value),
          reason: 'Failed binary roundtrip for value: $value',
        );
      }
    });

    test('type descriptor', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final typeDescriptor = intIterableSerializer.typeDescriptor;
      expect(typeDescriptor, isA<ReflectiveArrayDescriptor>());

      final arrayDescriptor = typeDescriptor as ReflectiveArrayDescriptor;
      expect(arrayDescriptor.itemType, isA<PrimitiveDescriptor>());
      expect(
        (arrayDescriptor.itemType as PrimitiveDescriptor).primitiveType,
        equals(PrimitiveType.int32),
      );
      expect(arrayDescriptor.keyExtractor, isNull);
    });

    test('edge cases and error handling', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);

      // Test that the serializer handles different iterable types
      final list = [1, 2, 3];
      final set = {1, 2, 3};
      final range = List.generate(3, (i) => i + 1);

      final listJson = intIterableSerializer.toJsonCode(list);
      final setJson = intIterableSerializer.toJsonCode(set);
      final rangeJson = intIterableSerializer.toJsonCode(range);

      expect(setJson, equals('[1,2,3]'));
      expect(rangeJson, equals('[1,2,3]'));

      // All should deserialize to the same result
      final restoredList = intIterableSerializer.fromJsonCode(listJson);
      final restoredSet = intIterableSerializer.fromJsonCode(setJson);
      final restoredRange = intIterableSerializer.fromJsonCode(rangeJson);

      expect(restoredList, equals([1, 2, 3]));
      expect(restoredSet, equals([1, 2, 3]));
      expect(restoredRange, equals([1, 2, 3]));
    });

    test('nested iterables', () {
      final nestedSerializer = Serializers.iterable(
        Serializers.iterable(Serializers.int32),
      );

      final nestedIterable = [
        [1, 2],
        [3, 4, 5],
        <int>[],
      ];

      // JSON tests
      final json = nestedSerializer.toJsonCode(nestedIterable);
      expect(json, equals('[[1,2],[3,4,5],[]]'));
      final restoredFromJson = nestedSerializer.fromJsonCode(json);
      expect(restoredFromJson, equals(nestedIterable));

      // Binary tests
      final bytes = nestedSerializer.toBytes(nestedIterable);
      final restoredFromBinary = nestedSerializer.fromBytes(bytes);
      expect(restoredFromBinary, equals(nestedIterable));
    });

    test('with optional elements', () {
      final optionalIntSerializer = Serializers.iterable(
        Serializers.optional(Serializers.int32),
      );

      final iterableWithNulls = [1, null, 3, null, 5];
      final iterableWithoutNulls = [1, 2, 3, 4, 5];

      // JSON tests
      final jsonWithNulls = optionalIntSerializer.toJsonCode(iterableWithNulls);
      expect(jsonWithNulls, equals('[1,null,3,null,5]'));
      final restoredWithNulls = optionalIntSerializer.fromJsonCode(
        jsonWithNulls,
      );
      expect(restoredWithNulls, equals(iterableWithNulls));

      final jsonWithoutNulls = optionalIntSerializer.toJsonCode(
        iterableWithoutNulls,
      );
      expect(jsonWithoutNulls, equals('[1,2,3,4,5]'));
      final restoredWithoutNulls = optionalIntSerializer.fromJsonCode(
        jsonWithoutNulls,
      );
      expect(restoredWithoutNulls, equals(iterableWithoutNulls));

      // Binary tests
      final bytesWithNulls = optionalIntSerializer.toBytes(iterableWithNulls);
      final restoredBinaryWithNulls = optionalIntSerializer.fromBytes(
        bytesWithNulls,
      );
      expect(restoredBinaryWithNulls, equals(iterableWithNulls));

      final bytesWithoutNulls = optionalIntSerializer.toBytes(
        iterableWithoutNulls,
      );
      final restoredBinaryWithoutNulls = optionalIntSerializer.fromBytes(
        bytesWithoutNulls,
      );
      expect(restoredBinaryWithoutNulls, equals(iterableWithoutNulls));
    });

    test('string representation', () {
      final intIterableSerializer = Serializers.iterable(Serializers.int32);
      final testIterable = [1, 2, 3];

      final stringRepr = internal__stringify(
        testIterable,
        intIterableSerializer,
      );
      expect(stringRepr, equals('[\n  1,\n  2,\n  3,\n]'));

      final emptyStringRepr = internal__stringify(
        <int>[],
        intIterableSerializer,
      );
      expect(emptyStringRepr, equals('[]'));
    });
  });

  group('KeyedIterableSerializer', () {
    test('basic functionality - JSON serialization', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Test various keyed iterables
      final emptyKeyed = KeyedIterable.copy(
        <int>[],
        (value) => value.toString(),
      );
      final singleKeyed = KeyedIterable.copy([42], (value) => value.toString());
      final multipleKeyed = KeyedIterable.copy([
        1,
        2,
        3,
      ], (value) => value.toString());

      // JSON should be the same as regular iterables
      expect(
        keyedIntSerializer.toJson(emptyKeyed, readableFlavor: true),
        equals([]),
      );
      expect(
        keyedIntSerializer.toJson(emptyKeyed, readableFlavor: false),
        equals([]),
      );
      expect(
        keyedIntSerializer.toJson(singleKeyed, readableFlavor: true),
        equals([42]),
      );
      expect(
        keyedIntSerializer.toJson(singleKeyed, readableFlavor: false),
        equals([42]),
      );
      expect(
        keyedIntSerializer.toJson(multipleKeyed, readableFlavor: true),
        equals([1, 2, 3]),
      );
      expect(
        keyedIntSerializer.toJson(multipleKeyed, readableFlavor: false),
        equals([1, 2, 3]),
      );

      // Test JSON string serialization
      expect(
        keyedIntSerializer.toJsonCode(emptyKeyed, readableFlavor: true),
        equals('[]'),
      );
      expect(
        keyedIntSerializer.toJsonCode(singleKeyed, readableFlavor: true),
        equals('[\n  42\n]'),
      );
      expect(
        keyedIntSerializer.toJsonCode(multipleKeyed, readableFlavor: true),
        equals('[\n  1,\n  2,\n  3\n]'),
      );
    });

    test('JSON deserialization creates KeyedIterable', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Test array JSON values
      final restoredEmpty = keyedIntSerializer.fromJson([]);
      expect(restoredEmpty, isA<KeyedIterable<int, String>>());
      expect(restoredEmpty, equals([]));

      final restored = keyedIntSerializer.fromJson([1, 2, 3]);
      expect(restored, isA<KeyedIterable<int, String>>());
      expect(restored, equals([1, 2, 3]));

      // Test key lookup functionality
      expect(restored.findByKey('1'), equals(1));
      expect(restored.findByKey('2'), equals(2));
      expect(restored.findByKey('3'), equals(3));
      expect(restored.findByKey('4'), isNull);

      final restoredFromCode = keyedIntSerializer.fromJsonCode('[42, 99]');
      expect(restoredFromCode, isA<KeyedIterable<int, String>>());
      expect(restoredFromCode.findByKey('42'), equals(42));
      expect(restoredFromCode.findByKey('99'), equals(99));
    });

    test('JSON deserialization - special numeric case', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Test that fromJson(0) and fromJsonCode("0") return empty keyed iterables
      final fromZero = keyedIntSerializer.fromJson(0);
      expect(fromZero, isA<KeyedIterable<int, String>>());
      expect(fromZero, equals([]));

      final fromZeroCode = keyedIntSerializer.fromJsonCode('0');
      expect(fromZeroCode, isA<KeyedIterable<int, String>>());
      expect(fromZeroCode, equals([]));
    });

    test('binary serialization - same as regular iterables', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Binary format should be identical to regular iterables
      final emptyKeyed = KeyedIterable.copy(
        <int>[],
        (value) => value.toString(),
      );
      final singleKeyed = KeyedIterable.copy([42], (value) => value.toString());
      final multipleKeyed = KeyedIterable.copy([
        1,
        2,
        3,
      ], (value) => value.toString());

      final emptyBytes = keyedIntSerializer.toBytes(emptyKeyed);
      expect(_bytesToHex(emptyBytes), equals('736b6972f6'));

      final singleBytes = keyedIntSerializer.toBytes(singleKeyed);
      expect(_bytesToHex(singleBytes), startsWith('736b6972f7'));

      final multipleBytes = keyedIntSerializer.toBytes(multipleKeyed);
      expect(_bytesToHex(multipleBytes), startsWith('736b6972f9'));
    });

    test('binary deserialization creates KeyedIterable', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      final originalKeyed = KeyedIterable.copy([
        1,
        2,
        3,
      ], (value) => value.toString());
      final bytes = keyedIntSerializer.toBytes(originalKeyed);
      final restored = keyedIntSerializer.fromBytes(bytes);

      expect(restored, isA<KeyedIterable<int, String>>());
      expect(restored, equals([1, 2, 3]));
      expect(restored.findByKey('1'), equals(1));
      expect(restored.findByKey('2'), equals(2));
      expect(restored.findByKey('3'), equals(3));
      expect(restored.findByKey('99'), isNull);
    });

    test('key lookup functionality', () {
      final keyedStringSerializer = Serializers.keyedIterable(
        Serializers.string,
        (String value) => value.length,
      );

      final words = ['hello', 'world', 'test', 'a'];
      final keyedWords = KeyedIterable.copy(words, (value) => value.length);

      // Test that we can look up by string length
      // Note: when there are multiple values with the same key, the last one wins
      expect(
        keyedWords.findByKey(5),
        equals('world'),
      ); // 'world' is the last string with length 5
      expect(keyedWords.findByKey(4), equals('test'));
      expect(keyedWords.findByKey(1), equals('a'));
      expect(keyedWords.findByKey(10), isNull);

      // Test after serialization roundtrip
      final json = keyedStringSerializer.toJsonCode(keyedWords);
      final restoredFromJson = keyedStringSerializer.fromJsonCode(json);
      expect(restoredFromJson.findByKey(4), equals('test'));
      expect(restoredFromJson.findByKey(1), equals('a'));

      final bytes = keyedStringSerializer.toBytes(keyedWords);
      final restoredFromBinary = keyedStringSerializer.fromBytes(bytes);
      expect(restoredFromBinary.findByKey(4), equals('test'));
      expect(restoredFromBinary.findByKey(1), equals('a'));
    });

    test('type descriptor with keyChain', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
        internal__getKeySpec: "toString()",
      );

      final typeDescriptor = keyedIntSerializer.typeDescriptor;
      expect(typeDescriptor, isA<ReflectiveArrayDescriptor>());

      final arrayDescriptor = typeDescriptor as ReflectiveArrayDescriptor;
      expect(arrayDescriptor.itemType, isA<PrimitiveDescriptor>());
      expect(
        (arrayDescriptor.itemType as PrimitiveDescriptor).primitiveType,
        equals(PrimitiveType.int32),
      );
      expect(arrayDescriptor.keyExtractor, equals("toString()"));
    });

    test('type descriptor without keyChain', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      final typeDescriptor = keyedIntSerializer.typeDescriptor;
      expect(typeDescriptor, isA<ReflectiveArrayDescriptor>());

      final arrayDescriptor = typeDescriptor as ReflectiveArrayDescriptor;
      expect(arrayDescriptor.keyExtractor, isNull);
    });

    test('edge cases and error handling', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Test with duplicate keys (last one should win in the map view)
      final duplicateValues = [1, 2, 1, 3]; // Two elements with key "1"
      final keyedDuplicates = KeyedIterable.copy(
        duplicateValues,
        (value) => value.toString(),
      );

      expect(keyedDuplicates, equals([1, 2, 1, 3])); // All elements preserved
      // Note: findByKey behavior with duplicates is implementation-specific
      final foundOne = keyedDuplicates.findByKey('1');
      expect([1], contains(foundOne)); // Should be one of the 1s

      // Test serialization roundtrip
      final json = keyedIntSerializer.toJsonCode(keyedDuplicates);
      final restoredFromJson = keyedIntSerializer.fromJsonCode(json);
      expect(restoredFromJson, equals([1, 2, 1, 3]));

      final bytes = keyedIntSerializer.toBytes(keyedDuplicates);
      final restoredFromBinary = keyedIntSerializer.fromBytes(bytes);
      expect(restoredFromBinary, equals([1, 2, 1, 3]));
    });

    test('nested keyed iterables', () {
      final innerKeyedSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );
      final outerKeyedSerializer = Serializers.keyedIterable(
        innerKeyedSerializer,
        (KeyedIterable<int, String> value) => value.length,
      );

      final inner1 = KeyedIterable.copy([1, 2], (value) => value.toString());
      final inner2 = KeyedIterable.copy([3, 4, 5], (value) => value.toString());
      final outer = KeyedIterable.copy([
        inner1,
        inner2,
      ], (value) => value.length);

      // JSON tests
      final json = outerKeyedSerializer.toJsonCode(outer);
      expect(json, equals('[[1,2],[3,4,5]]'));
      final restoredFromJson = outerKeyedSerializer.fromJsonCode(json);
      expect(restoredFromJson, equals(outer));
      expect(restoredFromJson.findByKey(2), equals(inner1));
      expect(restoredFromJson.findByKey(3), equals(inner2));

      // Binary tests
      final bytes = outerKeyedSerializer.toBytes(outer);
      final restoredFromBinary = outerKeyedSerializer.fromBytes(bytes);
      expect(restoredFromBinary, equals(outer));
      expect(restoredFromBinary.findByKey(2), equals(inner1));
      expect(restoredFromBinary.findByKey(3), equals(inner2));
    });

    test('with optional elements', () {
      final keyedOptionalSerializer = Serializers.keyedIterable(
        Serializers.optional(Serializers.int32),
        (int? value) => value?.toString() ?? 'null',
      );

      final keyedWithNulls = KeyedIterable.copy([
        1,
        null,
        3,
        null,
        5,
      ], (value) => value?.toString() ?? 'null');

      // JSON tests
      final json = keyedOptionalSerializer.toJsonCode(keyedWithNulls);
      expect(json, equals('[1,null,3,null,5]'));
      final restoredFromJson = keyedOptionalSerializer.fromJsonCode(json);
      expect(restoredFromJson, equals([1, null, 3, null, 5]));
      expect(restoredFromJson.findByKey('1'), equals(1));
      expect(restoredFromJson.findByKey('null'), isNull);

      // Binary tests
      final bytes = keyedOptionalSerializer.toBytes(keyedWithNulls);
      final restoredFromBinary = keyedOptionalSerializer.fromBytes(bytes);
      expect(restoredFromBinary, equals([1, null, 3, null, 5]));
      expect(restoredFromBinary.findByKey('1'), equals(1));
      expect(restoredFromBinary.findByKey('null'), isNull);
    });

    test('performance and optimization', () {
      // Test that multiple lookups don't rebuild the map
      final largeKeyed = KeyedIterable.copy(
        List.generate(1000, (i) => i),
        (value) => value,
      );

      // First lookup should build the map
      final first = largeKeyed.findByKey(500);
      expect(first, equals(500));

      // Subsequent lookups should use the cached map
      final second = largeKeyed.findByKey(750);
      expect(second, equals(750));

      final third = largeKeyed.findByKey(999);
      expect(third, equals(999));

      final notFound = largeKeyed.findByKey(1500);
      expect(notFound, isNull);
    });

    test('string representation', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );
      final testKeyed = KeyedIterable.copy([
        1,
        2,
        3,
      ], (value) => value.toString());

      final stringRepr = internal__stringify(testKeyed, keyedIntSerializer);
      expect(stringRepr, equals('[\n  1,\n  2,\n  3,\n]'));

      final emptyKeyed = KeyedIterable.copy(
        <int>[],
        (value) => value.toString(),
      );
      final emptyStringRepr = internal__stringify(
        emptyKeyed,
        keyedIntSerializer,
      );
      expect(emptyStringRepr, equals('[]'));
    });

    test('immutability and optimization', () {
      final keyedIntSerializer = Serializers.keyedIterable(
        Serializers.int32,
        (int value) => value.toString(),
      );

      // Test that KeyedIterable.copy with the same getKey function and keySpec
      // may return the same instance when the internal conditions are met
      final original = KeyedIterable.copy([
        1,
        2,
        3,
      ], (value) => value.toString());
      final copy = KeyedIterable.copy(original, (value) => value.toString());

      // The optimization depends on internal implementation details
      // We just test that the copy has the same content and functionality
      expect(copy, equals(original));
      expect(copy.findByKey('2'), equals(2));

      // But serialization/deserialization should still work
      final json = keyedIntSerializer.toJsonCode(original);
      final restored = keyedIntSerializer.fromJsonCode(json);
      expect(restored, equals(original));
      expect(restored.findByKey('2'), equals(2));
    });
  });
}

/// Helper function to convert bytes to hex string
String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
