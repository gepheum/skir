// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

void main() {
  group('ByteString', () {
    group('factory constructors', () {
      test('empty() creates an empty byte string', () {
        final empty = ByteString.empty;

        expect(empty.isEmpty, isTrue);
        expect(empty.isNotEmpty, isFalse);
        expect(empty.length, equals(0));
        expect(empty.asUnmodifiableList, isEmpty);
      });

      test('copy() creates a byte string from a list of integers', () {
        final list = [72, 101, 108, 108, 111]; // "Hello" in ASCII
        final byteString = ByteString.copy(list);

        expect(byteString.length, equals(5));
        expect(byteString.asUnmodifiableList, equals(list));
        expect(byteString.isEmpty, isFalse);
        expect(byteString.isNotEmpty, isTrue);
      });

      test('copy() with empty list creates empty byte string', () {
        final byteString = ByteString.copy([]);

        expect(identical(byteString, ByteString.empty), isTrue);
        expect(byteString.isEmpty, isTrue);
        expect(byteString.length, equals(0));
      });

      test('copy() handles values beyond byte range', () {
        final list = [256, 257, 300]; // Values > 255
        final byteString = ByteString.copy(list);

        expect(byteString.length, equals(3));
        // Values should be truncated to byte range (0-255)
        expect(byteString.asUnmodifiableList, equals([0, 1, 44]));
      });

      test('copySlice() creates a byte string from typed data slice', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final byteString = ByteString.copySlice(data, 2, 5);

        expect(byteString.length, equals(3));
        expect(byteString.asUnmodifiableList, equals([3, 4, 5]));
      });

      test('copySlice() with default parameters copies entire data', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final byteString = ByteString.copySlice(data);

        expect(byteString.length, equals(4));
        expect(byteString.asUnmodifiableList, equals([1, 2, 3, 4]));
      });

      test('copySlice() with start parameter only', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final byteString = ByteString.copySlice(data, 2);

        expect(byteString.length, equals(3));
        expect(byteString.asUnmodifiableList, equals([3, 4, 5]));
      });

      test('copySlice() with empty slice creates empty byte string', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        final byteString = ByteString.copySlice(data, 2, 2);

        expect(identical(byteString, ByteString.empty), isTrue);
        expect(byteString.isEmpty, isTrue);
      });

      test('copySlice() with different typed data types', () {
        final int16Data = Int16List.fromList([0x0102, 0x0304]);
        final byteString = ByteString.copySlice(int16Data, 0, 1);

        expect(byteString.length, equals(2));
        // Should extract the bytes from the Int16 value
        expect(byteString.asUnmodifiableList.length, equals(2));
      });
    });

    group('fromBase64', () {
      test('decodes valid Base64 string', () {
        final base64 = 'SGVsbG8='; // "Hello" in Base64
        final byteString = ByteString.fromBase64(base64);

        expect(byteString.length, equals(5));
        expect(byteString.asUnmodifiableList, equals([72, 101, 108, 108, 111]));
      });

      test('decodes empty Base64 string', () {
        final byteString = ByteString.fromBase64('');

        expect(identical(byteString, ByteString.empty), isTrue);
        expect(byteString.isEmpty, isTrue);
      });

      test('throws FormatException for invalid Base64', () {
        expect(
          () => ByteString.fromBase64('Invalid@Base64!'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => ByteString.fromBase64('SGVsbG'),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles Base64 with padding', () {
        final withPadding = 'SGVsbG8gV29ybGQ='; // "Hello World"
        final byteString = ByteString.fromBase64(withPadding);

        expect(byteString.length, equals(11));
        expect(byteString.toBase64(), equals(withPadding));
      });

      test('handles Base64 without padding (throws FormatException)', () {
        // Dart's base64Decode requires proper padding
        expect(
          () => ByteString.fromBase64('SGVsbG8'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('fromBase16', () {
      test('decodes valid hexadecimal string', () {
        final hex = '48656c6c6f'; // "Hello" in hex
        final byteString = ByteString.fromBase16(hex);

        expect(byteString.length, equals(5));
        expect(byteString.asUnmodifiableList, equals([72, 101, 108, 108, 111]));
      });

      test('decodes uppercase hexadecimal string', () {
        final hex = '48656C6C6F'; // "Hello" in uppercase hex
        final byteString = ByteString.fromBase16(hex);

        expect(byteString.length, equals(5));
        expect(byteString.asUnmodifiableList, equals([72, 101, 108, 108, 111]));
      });

      test('decodes empty hexadecimal string', () {
        final byteString = ByteString.fromBase16('');

        expect(byteString.isEmpty, isTrue);
        expect(byteString.length, equals(0));
      });

      test('throws FormatException for invalid hexadecimal', () {
        expect(
          () => ByteString.fromBase16('invalid'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => ByteString.fromBase16('123'),
          throwsA(isA<FormatException>()),
        ); // Odd length
        expect(
          () => ByteString.fromBase16('12GH'),
          throwsA(isA<FormatException>()),
        ); // Invalid characters
      });

      test('handles all valid hex characters', () {
        final hex = '0123456789abcdefABCDEF';
        final byteString = ByteString.fromBase16(hex);

        expect(byteString.length, equals(11));
        expect(byteString.toBase16(), equals('0123456789abcdefabcdef'));
      });
    });

    group('properties', () {
      test('length returns correct byte count', () {
        expect(ByteString.empty.length, equals(0));
        expect(ByteString.copy([1, 2, 3]).length, equals(3));
        expect(ByteString.copy(List.filled(100, 42)).length, equals(100));
      });

      test('isEmpty returns true only for empty byte strings', () {
        expect(ByteString.empty.isEmpty, isTrue);
        expect(ByteString.copy([]).isEmpty, isTrue);
        expect(ByteString.copy([1]).isEmpty, isFalse);
        expect(ByteString.copy([1, 2, 3]).isEmpty, isFalse);
      });

      test('isNotEmpty returns false only for empty byte strings', () {
        expect(ByteString.empty.isNotEmpty, isFalse);
        expect(ByteString.copy([]).isNotEmpty, isFalse);
        expect(ByteString.copy([1]).isNotEmpty, isTrue);
        expect(ByteString.copy([1, 2, 3]).isNotEmpty, isTrue);
      });

      test('asUnmodifiableList returns unmodifiable view', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final list = byteString.asUnmodifiableList;

        expect(list, equals([1, 2, 3, 4, 5]));
        expect(() => list.add(6), throwsUnsupportedError);
        expect(() => list.removeAt(0), throwsUnsupportedError);
        expect(() => list.clear(), throwsUnsupportedError);
        expect(() => list[0] = 10, throwsUnsupportedError);
      });
    });

    group('substring', () {
      test('returns substring with start and end', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final substring = byteString.substring(1, 4);

        expect(substring.length, equals(3));
        expect(substring.asUnmodifiableList, equals([2, 3, 4]));
      });

      test('returns substring with start only', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final substring = byteString.substring(2);

        expect(substring.length, equals(3));
        expect(substring.asUnmodifiableList, equals([3, 4, 5]));
      });

      test('returns same instance when full range requested', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final substring = byteString.substring(0, 5);

        expect(identical(byteString, substring), isTrue);
      });

      test('returns same instance when start is 0 and end is length', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final substring = byteString.substring(0, byteString.length);

        expect(identical(byteString, substring), isTrue);
      });

      test('returns empty byte string for empty range', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final substring = byteString.substring(2, 2);

        expect(substring.isEmpty, isTrue);
        expect(substring.length, equals(0));
      });

      test('handles edge cases', () {
        final byteString = ByteString.copy([1, 2, 3]);

        // Start at beginning
        expect(byteString.substring(0, 1).asUnmodifiableList, equals([1]));

        // End at last element
        expect(byteString.substring(2, 3).asUnmodifiableList, equals([3]));

        // Single element
        expect(byteString.substring(1, 2).asUnmodifiableList, equals([2]));
      });
    });

    group('toBase64', () {
      test('encodes bytes to Base64 string', () {
        final byteString = ByteString.copy([72, 101, 108, 108, 111]);
        final base64 = byteString.toBase64();

        expect(base64, equals('SGVsbG8='));
      });

      test('encodes empty byte string to empty string', () {
        final base64 = ByteString.empty.toBase64();

        expect(base64, equals(''));
      });

      test('round-trip conversion preserves data', () {
        final original = [1, 2, 3, 4, 5, 255, 0, 128];
        final byteString = ByteString.copy(original);
        final base64 = byteString.toBase64();
        final decoded = ByteString.fromBase64(base64);

        expect(decoded.asUnmodifiableList, equals(original));
      });

      test('handles all byte values', () {
        final allBytes = List.generate(256, (i) => i);
        final byteString = ByteString.copy(allBytes);
        final base64 = byteString.toBase64();
        final decoded = ByteString.fromBase64(base64);

        expect(decoded.asUnmodifiableList, equals(allBytes));
      });
    });

    group('toBase16', () {
      test('encodes bytes to hexadecimal string', () {
        final byteString = ByteString.copy([72, 101, 108, 108, 111]);
        final hex = byteString.toBase16();

        expect(hex, equals('48656c6c6f'));
      });

      test('encodes empty byte string to empty string', () {
        final hex = ByteString.empty.toBase16();

        expect(hex, equals(''));
      });

      test('uses lowercase hexadecimal digits', () {
        final byteString = ByteString.copy([255, 171, 205]);
        final hex = byteString.toBase16();

        expect(hex, equals('ffabcd'));
        expect(hex.contains(RegExp(r'[A-F]')), isFalse); // No uppercase
      });

      test('round-trip conversion preserves data', () {
        final original = [1, 2, 3, 4, 5, 255, 0, 128];
        final byteString = ByteString.copy(original);
        final hex = byteString.toBase16();
        final decoded = ByteString.fromBase16(hex);

        expect(decoded.asUnmodifiableList, equals(original));
      });

      test('handles all byte values', () {
        final allBytes = List.generate(256, (i) => i);
        final byteString = ByteString.copy(allBytes);
        final hex = byteString.toBase16();
        final decoded = ByteString.fromBase16(hex);

        expect(decoded.asUnmodifiableList, equals(allBytes));
      });

      test('pads single-digit hex values with zero', () {
        final byteString = ByteString.copy([0, 1, 15, 16]);
        final hex = byteString.toBase16();

        expect(hex, equals('00010f10'));
      });
    });

    group('toString', () {
      test('returns string representation using base16', () {
        final byteString = ByteString.copy([72, 101, 108, 108, 111]);
        final str = byteString.toString();

        expect(str, equals('ByteString.fromBase16("48656c6c6f")'));
      });

      test('handles empty byte string', () {
        final str = ByteString.empty.toString();

        expect(str, equals('ByteString.fromBase16("")'));
      });

      test('handles single byte', () {
        final byteString = ByteString.copy([255]);
        final str = byteString.toString();

        expect(str, equals('ByteString.fromBase16("ff")'));
      });
    });

    group('equality and hashCode', () {
      test('equal byte strings have same hash code', () {
        final byteString1 = ByteString.copy([1, 2, 3, 4, 5]);
        final byteString2 = ByteString.copy([1, 2, 3, 4, 5]);

        expect(byteString1 == byteString2, isTrue);
        expect(byteString1.hashCode, equals(byteString2.hashCode));
      });

      test('different byte strings are not equal', () {
        final byteString1 = ByteString.copy([1, 2, 3]);
        final byteString2 = ByteString.copy([1, 2, 4]);
        final byteString3 = ByteString.copy([1, 2]);

        expect(byteString1, isNot(equals(byteString2)));
        expect(byteString1, isNot(equals(byteString3)));
        expect(byteString2, isNot(equals(byteString3)));
      });

      test('empty byte strings are equal', () {
        final empty1 = ByteString.empty;
        final empty2 = ByteString.copy([]);

        expect(empty1, equals(empty2));
        expect(empty1.hashCode, equals(empty2.hashCode));
      });

      test('identity equality works', () {
        final byteString = ByteString.copy([1, 2, 3]);

        expect(byteString, equals(byteString));
        expect(identical(byteString, byteString), isTrue);
      });

      test('equality with non-ByteString objects returns false', () {
        final byteString = ByteString.copy([1, 2, 3]);

        expect(byteString, isNot(equals([1, 2, 3])));
        expect(byteString, isNot(equals('123')));
        expect(byteString, isNot(equals(null)));
        expect(byteString, isNot(equals(123)));
      });

      test('hash code is consistent', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final hash1 = byteString.hashCode;
        final hash2 = byteString.hashCode;

        expect(hash1, equals(hash2));
      });

      test('hash code differs from Uint8List hash code', () {
        final list = [1, 2, 3, 4, 5];
        final byteString = ByteString.copy(list);
        final uint8List = Uint8List.fromList(list);

        // ByteString adds an offset to differentiate from raw Uint8List
        expect(byteString.hashCode, isNot(equals(uint8List.hashCode)));
      });
    });

    group('immutability', () {
      test('modifying source list does not affect byte string', () {
        final sourceList = [1, 2, 3, 4, 5];
        final byteString = ByteString.copy(sourceList);

        sourceList.clear();
        sourceList.addAll([10, 20, 30]);

        expect(byteString.length, equals(5));
        expect(byteString.asUnmodifiableList, equals([1, 2, 3, 4, 5]));
      });

      test('asUnmodifiableList cannot be modified', () {
        final byteString = ByteString.copy([1, 2, 3, 4, 5]);
        final list = byteString.asUnmodifiableList;

        expect(() => list.add(6), throwsUnsupportedError);
        expect(() => list[0] = 10, throwsUnsupportedError);
        expect(() => list.removeAt(0), throwsUnsupportedError);
        expect(() => list.clear(), throwsUnsupportedError);
        expect(() => list.insert(0, 0), throwsUnsupportedError);
      });

      test('multiple calls to asUnmodifiableList return equivalent views', () {
        final byteString = ByteString.copy([1, 2, 3]);
        final list1 = byteString.asUnmodifiableList;
        final list2 = byteString.asUnmodifiableList;

        // Views might not be identical objects, but should have same content
        expect(list1, equals(list2));
        expect(list1.length, equals(list2.length));
      });
    });

    group('edge cases and special values', () {
      test('handles maximum byte value', () {
        final byteString = ByteString.copy([255]);

        expect(byteString.length, equals(1));
        expect(byteString.asUnmodifiableList, equals([255]));
        expect(byteString.toBase16(), equals('ff'));
      });

      test('handles zero byte value', () {
        final byteString = ByteString.copy([0]);

        expect(byteString.length, equals(1));
        expect(byteString.asUnmodifiableList, equals([0]));
        expect(byteString.toBase16(), equals('00'));
      });

      test('handles large byte strings', () {
        final largeList = List.generate(10000, (i) => i % 256);
        final byteString = ByteString.copy(largeList);

        expect(byteString.length, equals(10000));
        expect(byteString.asUnmodifiableList, equals(largeList));
      });

      test('handles mixed byte values', () {
        final mixed = [0, 1, 127, 128, 254, 255];
        final byteString = ByteString.copy(mixed);

        expect(byteString.length, equals(6));
        expect(byteString.asUnmodifiableList, equals(mixed));
        expect(byteString.toBase16(), equals('00017f80feff'));
      });
    });

    group('factory constructor optimization', () {
      test('empty factory returns singleton instance', () {
        final empty1 = ByteString.empty;
        final empty2 = ByteString.empty;

        expect(identical(empty1, empty2), isTrue);
      });

      test('copy with empty list returns empty singleton', () {
        final empty = ByteString.copy([]);

        expect(identical(empty, ByteString.empty), isTrue);
      });

      test('copySlice with empty range returns empty singleton', () {
        final data = Uint8List.fromList([1, 2, 3]);
        final empty = ByteString.copySlice(data, 1, 1);

        expect(identical(empty, ByteString.empty), isTrue);
      });

      test('fromBase64 with empty string returns empty singleton', () {
        final empty = ByteString.fromBase64('');

        expect(identical(empty, ByteString.empty), isTrue);
      });
    });

    group('integration tests', () {
      test('complete workflow with different encodings', () {
        // Start with a meaningful byte sequence
        final original = 'Hello, 世界! 🌍'.codeUnits;
        final byteString = ByteString.copy(original);

        // Test Base64 round-trip
        final base64 = byteString.toBase64();
        final fromBase64 = ByteString.fromBase64(base64);
        expect(fromBase64 == byteString, isTrue);

        // Test Base16 round-trip
        final base16 = byteString.toBase16();
        final fromBase16 = ByteString.fromBase16(base16);
        expect(fromBase16 == byteString, isTrue);

        // Test substring operations
        final substring = byteString.substring(0, 5);
        expect(substring.length, equals(5));
        expect(substring.asUnmodifiableList, equals(original.take(5).toList()));
      });

      test('various constructors produce equivalent results', () {
        final data = [72, 101, 108, 108, 111]; // "Hello"

        final fromCopy = ByteString.copy(data);
        final fromSlice = ByteString.copySlice(Uint8List.fromList(data));
        final fromBase64 = ByteString.fromBase64('SGVsbG8=');
        final fromBase16 = ByteString.fromBase16('48656c6c6f');

        expect(fromCopy == fromSlice, isTrue);
        expect(fromSlice == fromBase64, isTrue);
        expect(fromBase64 == fromBase16, isTrue);
        expect(fromBase16 == fromCopy, isTrue);
      });
    });
  });
}
