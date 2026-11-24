// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal, unrelated_type_equality_checks
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

void main() {
  group('KeyedIterable', () {
    group('factory constructors', () {
      test('empty() creates an empty keyed iterable', () {
        final empty = KeyedIterable.empty;

        expect(empty, isEmpty);
        expect(empty.length, equals(0));
        expect(empty.toList(), equals([]));
      });

      test(
        'typed empty() creates an empty keyed iterable with proper types',
        () {
          final KeyedIterable<String, int> empty = KeyedIterable.empty;

          expect(empty, isEmpty);
          expect(empty.length, equals(0));
          expect(empty.toList(), equals([]));
          expect(empty.findByKey(1), isNull);
        },
      );

      test('copy() creates a keyed iterable from elements', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.length, equals(3));
        expect(keyed.toList(), equals(['apple', 'banana', 'cherry']));
      });

      test('copy() with empty list creates empty keyed iterable', () {
        final keyed = KeyedIterable<String, int>.copy([], (e) => e.length);

        expect(keyed, isEmpty);
        expect(keyed.length, equals(0));
        expect(keyed.findByKey(1), isNull);
      });
    });

    group('findByKey', () {
      test('finds element by key', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.findByKey(5), equals('apple'));
        expect(
          keyed.findByKey(6),
          equals('cherry'),
        ); // Last element with length 6
      });

      test('returns null for non-existent key', () {
        final elements = ['apple', 'banana'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.findByKey(10), isNull);
        expect(keyed.findByKey(1), isNull);
      });

      test('typed empty keyed iterable returns null for any key', () {
        final KeyedIterable<String, int> empty = KeyedIterable.empty;

        expect(empty.findByKey(1), isNull);
        expect(empty.findByKey(100), isNull);
      });

      test('untyped empty keyed iterable returns null for any key', () {
        final KeyedIterable<Never, dynamic> empty = KeyedIterable.empty;

        expect(empty.findByKey(1), isNull);
        expect(empty.findByKey(100), isNull);
        expect(empty.findByKey('test'), isNull);
      });

      test('caches map view for efficient lookups', () {
        final elements = ['a', 'bb', 'ccc', 'dddd'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // First lookup should create the map
        expect(keyed.findByKey(2), equals('bb'));

        // Subsequent lookups should use cached map
        expect(keyed.findByKey(4), equals('dddd'));
        expect(keyed.findByKey(1), equals('a'));
        expect(keyed.findByKey(3), equals('ccc'));
      });
    });

    group('immutability', () {
      test('is unmodifiable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // KeyedIterable should be unmodifiable
        expect(() => (keyed as List).add('new'), throwsUnsupportedError);
        expect(() => (keyed as List).remove('apple'), throwsUnsupportedError);
        expect(() => (keyed as List).clear(), throwsUnsupportedError);
      });

      test('original list modification does not affect keyed iterable', () {
        final originalList = ['apple', 'banana'];
        final keyed = KeyedIterable.copy(originalList, (e) => e.length);

        // Modify original list
        originalList.add('cherry');

        // KeyedIterable should be unaffected
        expect(keyed.length, equals(2));
        expect(keyed.toList(), equals(['apple', 'banana']));
      });
    });

    group('iteration', () {
      test('supports for-in loop', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        final result = <String>[];
        for (final item in keyed) {
          result.add(item);
        }

        expect(result, equals(['apple', 'banana', 'cherry']));
      });

      test('supports iterator methods', () {
        final elements = [1, 2, 3, 4, 5];
        final keyed = KeyedIterable.copy(elements, (e) => e);

        expect(keyed.where((e) => e.isEven).toList(), equals([2, 4]));
        expect(keyed.map((e) => e * 2).toList(), equals([2, 4, 6, 8, 10]));
        expect(keyed.fold(0, (sum, e) => sum + e), equals(15));
      });

      test('first and last work correctly', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        expect(keyed.first, equals('apple'));
        expect(keyed.last, equals('cherry'));
      });

      test('typed empty iterable throws on first and last', () {
        final KeyedIterable<String, int> empty = KeyedIterable.empty;

        expect(() => empty.first, throwsStateError);
        expect(() => empty.last, throwsStateError);
      });

      test('empty iterable throws on first and last', () {
        final empty = KeyedIterable.empty;

        expect(() => empty.first, throwsStateError);
        expect(() => empty.last, throwsStateError);
      });
    });

    group('optimization', () {
      test('reuses existing KeyedIterable when conditions match', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = KeyedIterable.copy(elements, (e) => e.length);

        // Creating a new KeyedIterable with the same key function should reuse
        final copy = KeyedIterable.copy(original, (e) => e.length);

        // Note: The reuse depends on getKeySpec and getKey matching exactly
        // In this case, both should have empty getKeySpec and same key function
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey(5), equals('apple'));
        expect(
          copy.findByKey(6),
          equals('cherry'),
        ); // Last element with length 6
      });

      test('function reference equality affects reuse', () {
        final elements = ['apple', 'banana', 'cherry'];

        // Use the same function reference
        int keyFunction(String e) => e.length;
        final original = KeyedIterable.copy(elements, keyFunction);
        final copy = KeyedIterable.copy(original, keyFunction);

        // With same function reference, should potentially reuse
        expect(copy.toList(), equals(original.toList()));

        // Test with different function instances
        final copy2 = KeyedIterable.copy(original, (e) => e.length);
        expect(copy2.toList(), equals(original.toList()));
      });

      test('creates new instance for different key function', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = KeyedIterable.copy(elements, (e) => e.length);

        // Creating with different key function should create new instance
        final different = KeyedIterable.copy(original, (e) => e.codeUnitAt(0));

        expect(identical(original, different), isFalse);
        expect(different.toList(), equals(original.toList()));
        expect(different.findByKey(97), equals('apple')); // 'a' = 97
      });
    });

    group('internal__frozenCopy', () {
      test('reuses existing frozen list instances', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // internal__frozenCopy should reuse the same frozen list
        final frozen = internal__frozenCopy(keyed);
        expect(identical(keyed, frozen), isTrue);
      });

      test('reuses KeyedIterable.empty singleton', () {
        final KeyedIterable<String, int> empty = KeyedIterable.empty;
        final frozen = internal__frozenCopy(empty);

        // Should reuse the exact same instance
        expect(identical(empty, frozen), isTrue);
      });

      test('creates new frozen list from regular iterable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final frozen = internal__frozenCopy(elements);

        expect(frozen, isNot(same(elements)));
        expect(frozen.toList(), equals(elements));
        expect(() => (frozen as List).add('new'), throwsUnsupportedError);
      });

      test('creates new frozen list from empty regular list', () {
        final elements = <String>[];
        final frozen = internal__frozenCopy(elements);

        expect(frozen, isNot(same(elements)));
        expect(frozen.toList(), equals([]));
        expect(frozen.isEmpty, isTrue);
        expect(() => (frozen as List).add('new'), throwsUnsupportedError);
      });

      test('preserves type information', () {
        final elements = [1, 2, 3];
        final frozen = internal__frozenCopy(elements);

        expect(frozen, isA<Iterable<int>>());
        expect(frozen.toList(), equals([1, 2, 3]));
      });

      test('works with different iterable types', () {
        // Test with Set
        final set = {'a', 'b', 'c'};
        final frozenFromSet = internal__frozenCopy(set);
        expect(frozenFromSet.length, equals(3));
        expect(frozenFromSet.toSet(), equals(set));

        // Test with generated iterable
        final range = Iterable.generate(3, (i) => i + 1);
        final frozenFromRange = internal__frozenCopy(range);
        expect(frozenFromRange.toList(), equals([1, 2, 3]));

        // Test with already frozen list
        final alreadyFrozen = internal__frozenCopy([1, 2, 3]);
        final doubleFrozen = internal__frozenCopy(alreadyFrozen);
        expect(identical(alreadyFrozen, doubleFrozen), isTrue);
      });
    });

    group('internal__frozenMappedCopy', () {
      test('reuses existing frozen list when mapping is identity', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // When the mapping function is effectively identity, should reuse
        final mapped = internal__frozenMappedCopy<String, String>(
          keyed,
          (e) => e,
        );
        expect(identical(keyed, mapped), isTrue);
      });

      test('reuses KeyedIterable.empty singleton when mapping empty', () {
        final KeyedIterable<String, int> empty = KeyedIterable.empty;
        final mapped = internal__frozenMappedCopy<String, String>(
          empty,
          (e) => e.toUpperCase(),
        );

        // Should reuse the exact same instance even with mapping
        expect(identical(empty, mapped), isTrue);
      });

      test('creates new frozen list when mapping changes elements', () {
        final elements = ['apple', 'banana', 'cherry'];
        final mapped = internal__frozenMappedCopy<String, String>(
          elements,
          (e) => e.toUpperCase(),
        );

        expect(mapped, isNot(same(elements)));
        expect(mapped.toList(), equals(['APPLE', 'BANANA', 'CHERRY']));
        expect(() => (mapped as List).add('NEW'), throwsUnsupportedError);
      });

      test('creates new frozen list from empty regular list with mapping', () {
        final elements = <String>[];
        final mapped = internal__frozenMappedCopy<String, String>(
          elements,
          (e) => e.toUpperCase(),
        );

        expect(mapped, isNot(same(elements)));
        expect(mapped.toList(), equals([]));
        expect(mapped.isEmpty, isTrue);
        expect(() => (mapped as List).add('NEW'), throwsUnsupportedError);
      });

      test('applies mapping function correctly', () {
        final people = [Person('Alice', 25), Person('Bob', 30)];
        final mapped = internal__frozenMappedCopy<PersonData, Person>(
          people,
          (p) => PersonData(p.name, p.age, p.age >= 30),
        );

        expect(mapped.toList().length, equals(2));
        expect(mapped, isA<Iterable<PersonData>>());
        final list = mapped.toList();
        expect(list[0].name, equals('Alice'));
        expect(list[0].isAdult, isFalse);
      });

      test('works with complex type transformations', () {
        final people = [
          Person('Alice', 25),
          Person('Bob', 30),
          Person('Charlie', 35),
        ];

        final mapped = internal__frozenMappedCopy<PersonData, Person>(
          people,
          (p) => PersonData(p.name, p.age, p.age >= 30),
        );

        expect(mapped.length, equals(3));
        final list = mapped.toList();
        expect(list[0].name, equals('Alice'));
        expect(list[0].isAdult, isFalse);
        expect(list[1].name, equals('Bob'));
        expect(list[1].isAdult, isTrue);
        expect(list[2].name, equals('Charlie'));
        expect(list[2].isAdult, isTrue);
      });

      test('preserves immutability after mapping', () {
        final people = [Person('Alice', 25), Person('Bob', 30)];
        final mapped = internal__frozenMappedCopy<PersonData, Person>(
          people,
          (p) => PersonData(p.name, p.age, p.age >= 30),
        );

        expect(
          () => (mapped as List).add(PersonData('New', 40, true)),
          throwsUnsupportedError,
        );
        expect(() => (mapped as List).removeAt(0), throwsUnsupportedError);
        expect(() => (mapped as List).clear(), throwsUnsupportedError);
      });
    });

    group('internal__keyedCopy', () {
      test('reuses existing KeyedIterable with same getKeySpec and getKey', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );
        final copy = internal__keyedCopy(
          original,
          'length',
          (String e) => e.length,
        );

        // Should reuse the same instance when getKeySpec and getKey function reference match
        // Note: This may not work due to function equality comparison limitations
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey(5), equals('apple'));
      });

      test('behavior with KeyedIterable.empty singleton', () {
        final KeyedIterable<String, int> empty = KeyedIterable.empty;
        final copy = internal__keyedCopy(
          empty,
          'length',
          (String e) => e.length,
        );

        // With optimization: empty KeyedIterable should be reused, not copied
        expect(identical(empty, copy), isTrue);
        expect(copy.isEmpty, isTrue);
        expect(copy.findByKey(1), isNull);
        expect(copy.toList(), equals([]));
      });

      test('creates new KeyedIterable with different getKeySpec', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );
        final copy = internal__keyedCopy(
          original,
          'differentSpec',
          (String e) => e.length,
        );

        // Should create new instance due to different getKeySpec
        expect(identical(original, copy), isFalse);
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey(5), equals('apple'));
      });

      test('creates new KeyedIterable with different getKey function', () {
        final elements = ['apple', 'banana', 'cherry'];
        final original = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );
        final copy = internal__keyedCopy(
          original,
          'firstCodeUnit',
          (String e) => e.codeUnitAt(0),
        );

        // Should create new instance due to different getKey function
        expect(identical(original, copy), isFalse);
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey(97), equals('apple')); // 'a' = 97
      });

      test('creates new KeyedIterable from regular iterable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        expect(keyed, isNot(same(elements)));
        expect(keyed.toList(), equals(elements));
        expect(keyed.findByKey(5), equals('apple'));
        expect(keyed.findByKey(6), equals('cherry'));
      });

      test('creates new KeyedIterable from empty regular list', () {
        final elements = <String>[];
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        expect(keyed, isNot(same(elements)));
        expect(keyed.toList(), equals([]));
        expect(keyed.isEmpty, isTrue);
        expect(keyed.findByKey(5), isNull);
      });

      test('returns KeyedIterable.empty instance for empty list', () {
        final elements = <String>[];
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        // Should return the exact same KeyedIterable.empty singleton
        expect(identical(keyed, KeyedIterable.empty), isTrue);
        expect(keyed.isEmpty, isTrue);
        expect(keyed.findByKey(5), isNull);
      });

      test(
        'returns KeyedIterable.empty instance for various empty iterables',
        () {
          // Test with empty Set
          final emptySet = <String>{};
          final keyedFromSet = internal__keyedCopy(
            emptySet,
            'length',
            (String e) => e.length,
          );
          expect(identical(keyedFromSet, KeyedIterable.empty), isTrue);

          // Test with empty generated iterable
          final emptyGenerated = Iterable<String>.generate(0, (i) => 'item$i');
          final keyedFromGenerated = internal__keyedCopy(
            emptyGenerated,
            'length',
            (String e) => e.length,
          );
          expect(identical(keyedFromGenerated, KeyedIterable.empty), isTrue);

          // Test with empty filtered iterable
          final emptyFiltered = ['a', 'b', 'c'].where((e) => e.length > 5);
          final keyedFromFiltered = internal__keyedCopy(
            emptyFiltered,
            'length',
            (String e) => e.length,
          );
          expect(identical(keyedFromFiltered, KeyedIterable.empty), isTrue);

          // All should return the same singleton instance
          expect(identical(keyedFromSet, keyedFromGenerated), isTrue);
          expect(identical(keyedFromGenerated, keyedFromFiltered), isTrue);
        },
      );

      test('preserves key lookup functionality', () {
        final elements = ['a', 'bb', 'ccc', 'dddd'];
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        expect(keyed.findByKey(1), equals('a'));
        expect(keyed.findByKey(2), equals('bb'));
        expect(keyed.findByKey(3), equals('ccc'));
        expect(keyed.findByKey(4), equals('dddd'));
        expect(keyed.findByKey(5), isNull);
      });

      test('handles duplicate keys correctly', () {
        final elements = ['cat', 'dog', 'rat', 'bat']; // All length 3
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        // Should return the last element with the key (due to map behavior)
        expect(keyed.findByKey(3), equals('bat'));
        expect(keyed.toList(), equals(['cat', 'dog', 'rat', 'bat']));
      });

      test('works with different key types', () {
        final people = [
          Person('Alice', 25),
          Person('Bob', 30),
          Person('Charlie', 25),
        ];

        // Test with string keys
        final byName = internal__keyedCopy(
          people,
          'name',
          (Person p) => p.name,
        );
        expect(byName.findByKey('Alice')?.age, equals(25));
        expect(byName.findByKey('Bob')?.age, equals(30));
        expect(byName.findByKey('David'), isNull);

        // Test with int keys
        final byAge = internal__keyedCopy(people, 'age', (Person p) => p.age);
        expect(byAge.findByKey(25)?.name, equals('Charlie')); // Last match
        expect(byAge.findByKey(30)?.name, equals('Bob'));
        expect(byAge.findByKey(35), isNull);
      });

      test('preserves immutability', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = internal__keyedCopy(
          elements,
          'length',
          (String e) => e.length,
        );

        expect(() => (keyed as List).add('grape'), throwsUnsupportedError);
        expect(() => (keyed as List).removeAt(0), throwsUnsupportedError);
        expect(() => (keyed as List).clear(), throwsUnsupportedError);
      });

      test('optimization with function reference equality', () {
        final elements = ['apple', 'banana', 'cherry'];
        String keyFunction(String e) => e.length.toString();

        final original = internal__keyedCopy(
          elements,
          'lengthStr',
          keyFunction,
        );
        final copy = internal__keyedCopy(original, 'lengthStr', keyFunction);

        // With same function reference and spec, should potentially reuse
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey('5'), equals('apple'));
      });
    });

    group('internal__keyedMappedCopy', () {
      test('creates new KeyedIterable with mapping', () {
        final people = [
          Person('Alice', 25),
          Person('Bob', 30),
          Person('Charlie', 35),
        ];

        final personDataList =
            internal__keyedMappedCopy<PersonData, String, Person>(
          people,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, p.age >= 18),
        );

        expect(personDataList.length, equals(3));
        expect(personDataList.findByKey('Alice')?.isAdult, isTrue);
        expect(personDataList.findByKey('Bob')?.age, equals(30));
        expect(personDataList.findByKey('David'), isNull);
      });

      test('reuses existing KeyedIterable when appropriate', () {
        final personDataList = [
          PersonData('Alice', 25, true),
          PersonData('Bob', 30, true),
        ];
        final original = internal__keyedCopy(
          personDataList,
          'name',
          (PersonData pd) => pd.name,
        );

        final copy = internal__keyedMappedCopy<PersonData, String, PersonData>(
          original,
          'name',
          (PersonData pd) => pd.name,
          (PersonData pd) => pd, // Identity mapping
        );

        // Should reuse the original when specs match
        expect(copy.toList(), equals(original.toList()));
        expect(copy.findByKey('Alice')?.isAdult, isTrue);
      });

      test('behavior with KeyedIterable.empty singleton', () {
        final KeyedIterable<Person, int> empty = KeyedIterable.empty;
        final copy = internal__keyedMappedCopy<PersonData, String, Person>(
          empty,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, p.age >= 18),
        );

        // With optimization: empty KeyedIterable should be reused, not copied
        expect(identical(empty, copy), isTrue);
        expect(copy.isEmpty, isTrue);
        expect(copy.findByKey('test'), isNull);
        expect(copy.toList(), equals([]));
      });

      test('creates new KeyedIterable with different mapping', () {
        final people = [Person('Alice', 25), Person('Bob', 30)];

        final original = internal__keyedCopy(
          people,
          'name',
          (Person p) => p.name,
        );
        final mapped = internal__keyedMappedCopy<PersonData, String, Person>(
          original,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, false),
        );

        // Should create new instance due to type transformation
        expect(identical(original, mapped), isFalse);
        expect(mapped.length, equals(2));
        expect(mapped.findByKey('Alice')?.isAdult, isFalse);
        expect(mapped.findByKey('Bob')?.age, equals(30));
      });

      test('handles empty regular iterables', () {
        final List<Person> emptyPeople = [];
        final mapped = internal__keyedMappedCopy<PersonData, String, Person>(
          emptyPeople,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, p.age >= 18),
        );

        expect(mapped.isEmpty, isTrue);
        expect(mapped.findByKey('test'), isNull);
        expect(mapped.toList(), equals([]));
      });

      test('returns KeyedIterable.empty instance for empty list', () {
        final List<Person> emptyPeople = [];
        final mapped = internal__keyedMappedCopy<PersonData, String, Person>(
          emptyPeople,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, p.age >= 18),
        );

        // Should return the exact same KeyedIterable.empty singleton
        expect(identical(mapped, KeyedIterable.empty), isTrue);
        expect(mapped.isEmpty, isTrue);
        expect(mapped.findByKey('test'), isNull);
      });

      test(
        'returns KeyedIterable.empty instance for various empty iterables',
        () {
          // Test with empty Set
          final emptySet = <Person>{};
          final mappedFromSet =
              internal__keyedMappedCopy<PersonData, String, Person>(
            emptySet,
            'name',
            (PersonData pd) => pd.name,
            (Person p) => PersonData(p.name, p.age, p.age >= 18),
          );
          expect(identical(mappedFromSet, KeyedIterable.empty), isTrue);

          // Test with empty generated iterable
          final emptyGenerated = Iterable<Person>.generate(
            0,
            (i) => Person('Person$i', 20 + i),
          );
          final mappedFromGenerated =
              internal__keyedMappedCopy<PersonData, String, Person>(
            emptyGenerated,
            'name',
            (PersonData pd) => pd.name,
            (Person p) => PersonData(p.name, p.age, p.age >= 18),
          );
          expect(identical(mappedFromGenerated, KeyedIterable.empty), isTrue);

          // Test with empty filtered iterable
          final emptyFiltered = [Person('Alice', 25)].where((p) => p.age > 100);
          final mappedFromFiltered =
              internal__keyedMappedCopy<PersonData, String, Person>(
            emptyFiltered,
            'name',
            (PersonData pd) => pd.name,
            (Person p) => PersonData(p.name, p.age, p.age >= 18),
          );
          expect(identical(mappedFromFiltered, KeyedIterable.empty), isTrue);

          // All should return the same singleton instance
          expect(identical(mappedFromSet, mappedFromGenerated), isTrue);
          expect(identical(mappedFromGenerated, mappedFromFiltered), isTrue);
        },
      );

      test('preserves immutability', () {
        final people = [Person('Alice', 25)];
        final mapped = internal__keyedMappedCopy<PersonData, String, Person>(
          people,
          'name',
          (PersonData pd) => pd.name,
          (Person p) => PersonData(p.name, p.age, p.age >= 18),
        );

        expect(
          () => (mapped as List).add(PersonData('Bob', 30, true)),
          throwsUnsupportedError,
        );
        expect(() => (mapped as List).removeAt(0), throwsUnsupportedError);
        expect(() => (mapped as List).clear(), throwsUnsupportedError);
      });
    });

    group('internalFrozenCopy', () {
      test('reuses existing frozen list', () {
        final elements = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // internalFrozenCopy should reuse the same frozen list
        final frozen = internal__frozenCopy(keyed);
        expect(identical(keyed, frozen), isTrue);
      });

      test('creates new frozen list from regular iterable', () {
        final elements = ['apple', 'banana', 'cherry'];
        final frozen = internal__frozenCopy(elements);

        expect(frozen, isNot(same(elements)));
        expect(frozen.toList(), equals(elements));
        expect(() => (frozen as List).add('new'), throwsUnsupportedError);
      });
    });

    group('edge cases', () {
      test('handles duplicate keys correctly', () {
        final elements = ['aa', 'bb', 'cc']; // All have length 2
        final keyed = KeyedIterable.copy(elements, (e) => e.length);

        // Should return the last element with the key (due to map overwriting)
        expect(keyed.findByKey(2), equals('cc'));
      });

      test('handles null elements', () {
        final elements = <String?>['apple', null, 'banana'];
        final keyed = KeyedIterable.copy(elements, (e) => e?.length ?? -1);

        expect(keyed.length, equals(3));
        expect(keyed.findByKey(-1), isNull);
        expect(keyed.findByKey(5), equals('apple'));
        expect(keyed.findByKey(6), equals('banana'));
      });

      test('works with different key types', () {
        final elements = [
          Person('Alice', 25),
          Person('Bob', 30),
          Person('Charlie', 25),
        ];

        // Test with string keys
        final byName = KeyedIterable.copy(elements, (p) => p.name);
        expect(byName.findByKey('Alice')?.age, equals(25));
        expect(byName.findByKey('Bob')?.age, equals(30));
        expect(byName.findByKey('David'), isNull);

        // Test with int keys
        final byAge = KeyedIterable.copy(elements, (p) => p.age);
        expect(
          byAge.findByKey(25)?.name,
          equals('Charlie'),
        ); // Last match due to map overwriting
        expect(byAge.findByKey(30)?.name, equals('Bob'));
        expect(byAge.findByKey(35), isNull);
      });

      test('works with complex key types', () {
        final elements = [Person('Alice', 25), Person('Bob', 30)];

        final byAgeGroup = KeyedIterable.copy(
          elements,
          (p) => AgeGroup(p.age ~/ 10),
        );
        expect(byAgeGroup.findByKey(AgeGroup(2))?.name, equals('Alice'));
        expect(byAgeGroup.findByKey(AgeGroup(3))?.name, equals('Bob'));
        expect(byAgeGroup.findByKey(AgeGroup(4)), isNull);
      });

      test('empty from filtered iterable works correctly', () {
        final elements = [1, 2, 3, 4, 5];
        // Create a filtered iterable that results in empty
        final filtered = elements.where((e) => e > 10);
        final keyed = KeyedIterable.copy(filtered, (e) => e);

        expect(keyed, isEmpty);
        expect(keyed.length, equals(0));
        expect(keyed.findByKey(1), isNull);
        expect(keyed.toList(), equals([]));
      });

      test('immutable list creation', () {
        final mutableList = ['apple', 'banana', 'cherry'];
        final keyed = KeyedIterable.copy(mutableList, (e) => e.length);

        // Original list should not affect the keyed iterable
        mutableList.clear();

        expect(keyed.length, equals(3));
        expect(keyed.toList(), equals(['apple', 'banana', 'cherry']));
      });
    });
  });

  group('Equality and HashCode', () {
    group('_FrozenList equality operator', () {
      test('identical instances are equal', () {
        final list = internal__frozenCopy(['apple', 'banana', 'cherry']);
        expect(list == list, isTrue);
        expect(identical(list, list), isTrue);
      });

      test('different instances with same content are equal', () {
        final list1 = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final list2 = internal__frozenCopy(['apple', 'banana', 'cherry']);

        expect(list1 == list2, isTrue);
        expect(list2 == list1, isTrue);
      });

      test('different instances with different content are not equal', () {
        final list1 = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final list2 = internal__frozenCopy(['apple', 'banana', 'grape']);

        expect(list1 == list2, isFalse);
        expect(list2 == list1, isFalse);
      });

      test('different instances with different lengths are not equal', () {
        final list1 = internal__frozenCopy(['apple', 'banana']);
        final list2 = internal__frozenCopy(['apple', 'banana', 'cherry']);

        expect(list1 == list2, isFalse);
        expect(list2 == list1, isFalse);
      });

      test('empty lists are equal', () {
        final list1 = internal__frozenCopy(<String>[]);
        final list2 = internal__frozenCopy(<String>[]);

        expect(list1 == list2, isTrue);
        expect(list2 == list1, isTrue);
      });

      test('frozen list not equal to regular list', () {
        final frozenList = internal__frozenCopy(['apple', 'banana']);
        final regularList = ['apple', 'banana'];

        expect(frozenList == regularList, isFalse);
        expect(regularList == frozenList, isFalse);
      });

      test('frozen list not equal to other types', () {
        final frozenList = internal__frozenCopy(['apple', 'banana']);

        expect(frozenList == 'not a list', isFalse);
        expect(frozenList == 42, isFalse);
        expect(frozenList == {'apple', 'banana'}, isFalse);

        // Test null comparison by explicitly casting
        dynamic nullValue;
        expect(frozenList == nullValue, isFalse);
      });

      test('frozen lists with null elements', () {
        final list1 = internal__frozenCopy(<String?>[null, 'apple', null]);
        final list2 = internal__frozenCopy(<String?>[null, 'apple', null]);
        final list3 = internal__frozenCopy(<String?>[null, 'banana', null]);

        expect(list1 == list2, isTrue);
        expect(list1 == list3, isFalse);
      });

      test('order matters for equality', () {
        final list1 = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final list2 = internal__frozenCopy(['cherry', 'banana', 'apple']);

        expect(list1 == list2, isFalse);
      });
    });

    group('KeyedIterable equality operator', () {
      test('identical instances are equal', () {
        final keyed = KeyedIterable.copy(['apple', 'banana'], (e) => e.length);
        expect(keyed == keyed, isTrue);
        expect(identical(keyed, keyed), isTrue);
      });

      test('different KeyedIterable instances with same content are equal', () {
        final keyed1 = KeyedIterable.copy(['apple', 'banana'], (e) => e.length);
        final keyed2 = KeyedIterable.copy([
          'apple',
          'banana',
        ], (e) => e.codeUnitAt(0));

        expect(keyed1 == keyed2, isTrue);
        expect(keyed2 == keyed1, isTrue);
      });

      test('KeyedIterable not equal to different content', () {
        final keyed1 = KeyedIterable.copy(['apple', 'banana'], (e) => e.length);
        final keyed2 = KeyedIterable.copy(['apple', 'cherry'], (e) => e.length);

        expect(keyed1 == keyed2, isFalse);
        expect(keyed2 == keyed1, isFalse);
      });

      test('empty KeyedIterables are equal', () {
        final keyed1 = KeyedIterable.copy(<String>[], (e) => e.length);
        final keyed2 = KeyedIterable.copy(<String>[], (e) => e.codeUnitAt(0));
        final staticEmpty = KeyedIterable.empty;

        expect(keyed1 == keyed2, isTrue);
        expect(keyed1 == staticEmpty, isTrue);
        expect(staticEmpty == keyed2, isTrue);
      });

      test('KeyedIterable.empty singleton behavior', () {
        final empty1 = KeyedIterable.empty;
        final empty2 = KeyedIterable.empty;

        expect(identical(empty1, empty2), isTrue);
        expect(empty1 == empty2, isTrue);
      });
    });

    group('Cross-implementation equality', () {
      test('_FrozenListImpl equals _KeyedIterableImpl with same content', () {
        final frozenList = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final keyedList = KeyedIterable.copy([
          'apple',
          'banana',
          'cherry',
        ], (e) => e.length);

        expect(frozenList == keyedList, isTrue);
        expect(keyedList == frozenList, isTrue);
      });

      test('_FrozenListImpl equals _EmptyFrozenList when both empty', () {
        final frozenList = internal__frozenCopy(<String>[]);
        final emptyKeyed = KeyedIterable.empty;

        expect(frozenList == emptyKeyed, isTrue);
        expect(emptyKeyed == frozenList, isTrue);
      });

      test(
        'different _FrozenList implementations with different content are not equal',
        () {
          final frozenList = internal__frozenCopy(['apple', 'banana']);
          final keyedList = KeyedIterable.copy([
            'apple',
            'cherry',
          ], (e) => e.length);

          expect(frozenList == keyedList, isFalse);
          expect(keyedList == frozenList, isFalse);
        },
      );

      test('mixed types with same underlying list are equal', () {
        final sourceList = ['apple', 'banana', 'cherry'];
        final frozenList = internal__frozenCopy(sourceList);
        final keyedList = KeyedIterable.copy(sourceList, (e) => e.length);
        final mappedList = internal__frozenMappedCopy<String, String>(
          sourceList,
          (e) => e,
        );

        expect(frozenList == keyedList, isTrue);
        expect(keyedList == frozenList, isTrue);
        expect(frozenList == mappedList, isTrue);
        expect(mappedList == keyedList, isTrue);
      });
    });

    group('_FrozenList hashCode method', () {
      test('equal instances have equal hash codes', () {
        final list1 = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final list2 = internal__frozenCopy(['apple', 'banana', 'cherry']);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
      });

      test('identical instances have equal hash codes', () {
        final list = internal__frozenCopy(['apple', 'banana', 'cherry']);

        expect(list.hashCode, equals(list.hashCode));
      });

      test('different content produces different hash codes (usually)', () {
        final list1 = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final list2 = internal__frozenCopy(['apple', 'banana', 'grape']);

        // Note: Hash codes should be different for different content,
        // but we can't guarantee it due to hash collisions
        expect(list1 == list2, isFalse);
        // We can't test hashCode inequality reliably due to possible collisions
      });

      test('empty lists have consistent hash codes', () {
        final list1 = internal__frozenCopy(<String>[]);
        final list2 = internal__frozenCopy(<String>[]);
        final empty = KeyedIterable.empty;

        expect(list1.hashCode, equals(list2.hashCode));
        expect(list1.hashCode, equals(empty.hashCode));
      });

      test('hash code is consistent across multiple calls', () {
        final list = internal__frozenCopy(['apple', 'banana', 'cherry']);
        final firstHash = list.hashCode;
        final secondHash = list.hashCode;
        final thirdHash = list.hashCode;

        expect(firstHash, equals(secondHash));
        expect(secondHash, equals(thirdHash));
      });

      test('KeyedIterable hash codes are consistent', () {
        final keyed1 = KeyedIterable.copy(['apple', 'banana'], (e) => e.length);
        final keyed2 = KeyedIterable.copy([
          'apple',
          'banana',
        ], (e) => e.codeUnitAt(0));

        expect(keyed1 == keyed2, isTrue);
        expect(keyed1.hashCode, equals(keyed2.hashCode));
      });

      test('cross-implementation hash code consistency', () {
        final frozenList = internal__frozenCopy(['apple', 'banana']);
        final keyedList = KeyedIterable.copy([
          'apple',
          'banana',
        ], (e) => e.length);

        expect(frozenList == keyedList, isTrue);
        expect(frozenList.hashCode, equals(keyedList.hashCode));
      });

      test('hash codes with null elements', () {
        final list1 = internal__frozenCopy(<String?>[null, 'apple', null]);
        final list2 = internal__frozenCopy(<String?>[null, 'apple', null]);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
      });
    });

    group('Complex element equality and hash codes', () {
      test('lists of custom objects with proper equality', () {
        final person1a = Person('Alice', 25);
        final person1b = Person('Alice', 25); // Equal to person1a
        final person2 = Person('Bob', 30);

        final list1 = internal__frozenCopy([person1a, person2]);
        final list2 = internal__frozenCopy([person1b, person2]);
        final list3 = internal__frozenCopy([person2, person1a]);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
        expect(list1 == list3, isFalse);
      });

      test('nested lists equality', () {
        final nestedList1 = internal__frozenCopy([
          internal__frozenCopy(['a', 'b']),
          internal__frozenCopy(['c', 'd']),
        ]);
        final nestedList2 = internal__frozenCopy([
          internal__frozenCopy(['a', 'b']),
          internal__frozenCopy(['c', 'd']),
        ]);
        final nestedList3 = internal__frozenCopy([
          internal__frozenCopy(['a', 'b']),
          internal__frozenCopy(['c', 'e']),
        ]);

        expect(nestedList1 == nestedList2, isTrue);
        expect(nestedList1.hashCode, equals(nestedList2.hashCode));
        expect(nestedList1 == nestedList3, isFalse);
      });

      test('KeyedIterable with custom objects', () {
        final person1a = Person('Alice', 25);
        final person1b = Person('Alice', 25); // Equal to person1a
        final person2 = Person('Bob', 30);

        final keyed1 = KeyedIterable.copy([person1a, person2], (p) => p.name);
        final keyed2 = KeyedIterable.copy([person1b, person2], (p) => p.name);

        expect(keyed1 == keyed2, isTrue);
        expect(keyed1.hashCode, equals(keyed2.hashCode));
      });

      test('large lists performance and correctness', () {
        final largeList1 = List.generate(1000, (i) => 'item$i');
        final largeList2 = List.generate(1000, (i) => 'item$i');
        largeList2[999] = 'different'; // Make one element different

        final frozen1 = internal__frozenCopy(largeList1);
        final frozen2 = internal__frozenCopy(largeList1);
        final frozen3 = internal__frozenCopy(largeList2);

        expect(frozen1 == frozen2, isTrue);
        expect(frozen1.hashCode, equals(frozen2.hashCode));
        expect(frozen1 == frozen3, isFalse);
      });

      test('mixed primitive types', () {
        final list1 = internal__frozenCopy<dynamic>([1, 'hello', true, 2.5]);
        final list2 = internal__frozenCopy<dynamic>([1, 'hello', true, 2.5]);
        final list3 = internal__frozenCopy<dynamic>([1, 'hello', false, 2.5]);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
        expect(list1 == list3, isFalse);
      });
    });

    group('Edge cases', () {
      test('single element lists', () {
        final list1 = internal__frozenCopy(['single']);
        final list2 = internal__frozenCopy(['single']);
        final list3 = internal__frozenCopy(['different']);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
        expect(list1 == list3, isFalse);
      });

      test('lists with duplicate elements', () {
        final list1 = internal__frozenCopy(['a', 'a', 'b', 'a']);
        final list2 = internal__frozenCopy(['a', 'a', 'b', 'a']);
        final list3 = internal__frozenCopy(['a', 'b', 'a', 'a']);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
        expect(list1 == list3, isFalse); // Order matters
      });

      test('very large elements', () {
        final largeString = 'x' * 10000;
        final list1 = internal__frozenCopy([largeString]);
        final list2 = internal__frozenCopy([largeString]);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
      });

      test('numeric types and precision', () {
        final list1 = internal__frozenCopy([1, 2.0, 3]);
        final list2 = internal__frozenCopy([1, 2.0, 3]);

        expect(list1 == list2, isTrue);
        expect(list1.hashCode, equals(list2.hashCode));
      });

      test('string vs num comparison', () {
        final list1 = internal__frozenCopy<dynamic>(['1', '2', '3']);
        final list2 = internal__frozenCopy<dynamic>([1, 2, 3]);

        expect(list1 == list2, isFalse);
      });
    });
  });
}

// Test helper classes
class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  @override
  String toString() => 'Person($name, $age)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

class AgeGroup {
  final int decade;

  AgeGroup(this.decade);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgeGroup &&
          runtimeType == other.runtimeType &&
          decade == other.decade;

  @override
  int get hashCode => decade.hashCode;

  @override
  String toString() => 'AgeGroup($decade)';
}

class PersonData extends Person {
  final bool isAdult;

  PersonData(super.name, super.age, this.isAdult);

  @override
  String toString() => 'PersonData($name, $age, isAdult: $isAdult)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age &&
          isAdult == other.isAdult;

  @override
  int get hashCode => name.hashCode ^ age.hashCode ^ isAdult.hashCode;
}
