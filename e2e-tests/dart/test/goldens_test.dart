import "dart:convert" show jsonEncode;
import "dart:typed_data" show Uint8List, ByteData;

import "package:test/test.dart";
import "package:skir_client/skir_client.dart" as skir;

import "../skirout/@gepheum/skir-golden-tests/goldens.dart";

class AssertionError implements Exception {
  String message = "";

  AssertionError({
    Object? actual,
    Object? expected,
    String? message,
  }) {
    this.message = (message ?? "") +
        "\n" +
        "Expected: ${jsonEncode(expected)}\n" +
        "  Actual: ${jsonEncode(actual)}\n";
  }

  void addContext(String context) {
    message = message.isNotEmpty ? "$message\n$context" : context;
  }
}

void main() {
  group("goldens", () {
    for (var i = 0; i < unitTests.length; ++i) {
      final unitTest = unitTests.elementAt(i);
      if (unitTest.testNumber != unitTests.first.testNumber + i) {
        throw Exception(
          "Test numbers are not sequential at test #$i: " +
              "found ${unitTest.testNumber}, " +
              "expected ${unitTests.first.testNumber + i}",
        );
      }
      test("test #${unitTest.testNumber}", () {
        try {
          verifyAssertion(unitTest.assertion);
        } catch (e) {
          if (e is AssertionError) {
            e.addContext("While evaluating test #${unitTest.testNumber}");
            print(e.message);
            print("\n\n");
          }
          rethrow;
        }
      });
    }
  });
}

void verifyAssertion(Assertion assertion) {
  switch (assertion.kind) {
    case Assertion_kind.bytesEqualWrapper:
      {
        final value = (assertion as Assertion_bytesEqualWrapper).value;
        final actual = evaluateBytes(value.actual).toBase16();
        final expected = evaluateBytes(value.expected).toBase16();
        if (actual != expected) {
          throw AssertionError(
            actual: "hex:$actual",
            expected: "hex:$expected",
          );
        }
        break;
      }
    case Assertion_kind.bytesInWrapper:
      {
        final value = (assertion as Assertion_bytesInWrapper).value;
        final actual = evaluateBytes(value.actual);
        final actualHex = actual.toBase16();
        final found = value.expected.any((expectedBytes) {
          return expectedBytes.toBase16() == actualHex;
        });
        if (!found) {
          throw AssertionError(
            actual: "hex:$actualHex",
            expected:
                value.expected.map((b) => "hex:${b.toBase16()}").join(" or "),
          );
        }
        break;
      }
    case Assertion_kind.stringEqualWrapper:
      {
        final value = (assertion as Assertion_stringEqualWrapper).value;
        final actual = evaluateString(value.actual);
        final expected = evaluateString(value.expected);
        if (actual != expected) {
          throw AssertionError(
            actual: actual,
            expected: expected,
            message: "Actual: ${jsonEncode(actual)}",
          );
        }
        break;
      }
    case Assertion_kind.stringInWrapper:
      {
        final value = (assertion as Assertion_stringInWrapper).value;
        final actual = evaluateString(value.actual);
        if (!value.expected.contains(actual)) {
          throw AssertionError(
            actual: actual,
            expected: value.expected.join(" or "),
          );
        }
        break;
      }
    case Assertion_kind.reserializeValueWrapper:
      {
        final value = (assertion as Assertion_reserializeValueWrapper).value;
        return reserializeValueAndVerify(value);
      }
    case Assertion_kind.reserializeLargeStringWrapper:
      {
        final value =
            (assertion as Assertion_reserializeLargeStringWrapper).value;
        return reserializeLargeStringAndVerify(value);
      }
    case Assertion_kind.reserializeLargeArrayWrapper:
      {
        final value =
            (assertion as Assertion_reserializeLargeArrayWrapper).value;
        return reserializeLargeArrayAndVerify(value);
      }
    case Assertion_kind.enumAFromJsonIsConstantWrapper:
      {
        final value =
            (assertion as Assertion_enumAFromJsonIsConstantWrapper).value;
        final parsed = value.keepUnrecognized
            ? fromJsonKeepUnrecognized(
                EnumA.serializer,
                evaluateString(value.actual),
              )
            : fromJsonDropUnrecognized(
                EnumA.serializer,
                evaluateString(value.actual),
              );
        final actual = fromJsonDropUnrecognized(
          EnumA.serializer,
          toDenseJson(EnumA.serializer, parsed),
        );
        if (!_isEnumAConstant(actual)) {
          throw AssertionError(
            actual: actual,
            expected: "EnumA constant A",
          );
        }
        break;
      }
    case Assertion_kind.enumAFromBytesIsConstantWrapper:
      {
        final value =
            (assertion as Assertion_enumAFromBytesIsConstantWrapper).value;
        final parsed = value.keepUnrecognized
            ? fromBytesKeepUnrecognized(
                EnumA.serializer,
                evaluateBytes(value.actual),
              )
            : fromBytesDropUnrecognizedFields(
                EnumA.serializer,
                evaluateBytes(value.actual),
              );
        final actual = fromBytesDropUnrecognizedFields(
          EnumA.serializer,
          toBytes(EnumA.serializer, parsed),
        );
        if (!_isEnumAConstant(actual)) {
          throw AssertionError(
            actual: actual,
            expected: "EnumA constant A",
          );
        }
        break;
      }
    case Assertion_kind.enumBFromJsonIsWrapperBWrapper:
      {
        final value =
            (assertion as Assertion_enumBFromJsonIsWrapperBWrapper).value;
        final actual = value.keepUnrecognized
            ? fromJsonKeepUnrecognized(
                EnumB.serializer,
                evaluateString(value.actual),
              )
            : fromJsonDropUnrecognized(
                EnumB.serializer,
                evaluateString(value.actual),
              );
        final actualValue = _enumBWrapperValue(actual);
        if (actualValue != value.expected) {
          throw AssertionError(
            actual: actualValue,
            expected: value.expected,
          );
        }
        break;
      }
    case Assertion_kind.enumBFromBytesIsWrapperBWrapper:
      {
        final value =
            (assertion as Assertion_enumBFromBytesIsWrapperBWrapper).value;
        final actual = value.keepUnrecognized
            ? fromBytesKeepUnrecognized(
                EnumB.serializer,
                evaluateBytes(value.actual),
              )
            : fromBytesDropUnrecognizedFields(
                EnumB.serializer,
                evaluateBytes(value.actual),
              );
        final actualValue = _enumBWrapperValue(actual);
        if (actualValue != value.expected) {
          throw AssertionError(
            actual: actualValue,
            expected: value.expected,
          );
        }
        break;
      }
    case Assertion_kind.unknown:
      throw Exception("Unknown assertion kind");
  }
}

bool _isEnumAConstant(EnumA value) {
  return value.kind == EnumA_kind.aConst;
}

String _enumBWrapperValue(EnumB value) {
  return switch (value) {
    EnumB_bWrapper(:var value) => value,
    _ => "",
  };
}

void reserializeValueAndVerify(Assertion_ReserializeValue input) {
  final typedValues = [
    input.value,
    TypedValue.wrapRoundTripDenseJson(input.value),
    TypedValue.wrapRoundTripReadableJson(input.value),
    TypedValue.wrapRoundTripBytes(input.value),
  ];

  for (final inputValue in typedValues) {
    try {
      // Verify bytes - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.createBytesIn(
          actual: BytesExpression.wrapToBytes(inputValue),
          expected: input.expectedBytes,
        ),
      );

      // Verify dense JSON - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.createStringIn(
          actual: StringExpression.wrapToDenseJson(inputValue),
          expected: input.expectedDenseJson,
        ),
      );

      // Verify readable JSON - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.createStringIn(
          actual: StringExpression.wrapToReadableJson(inputValue),
          expected: input.expectedReadableJson,
        ),
      );
    } catch (e) {
      if (e is AssertionError) {
        e.addContext("input value: $inputValue");
      }
      rethrow;
    }
  }

  // Make sure the encoded value can be skipped.
  for (final expectedBytes in input.expectedBytes) {
    final expectedBytesList = expectedBytes.asUnmodifiableList;
    final buffer = Uint8List(expectedBytesList.length + 2);
    final dataView = ByteData.view(buffer.buffer);
    final prefix = "skir";
    buffer.setRange(0, prefix.length, prefix.codeUnits);
    dataView.setUint8(4, 248);
    buffer.setRange(
      5,
      expectedBytesList.length + 1,
      expectedBytesList.skip(prefix.length),
    );
    dataView.setUint8(expectedBytesList.length + 1, 1);
    final point = Point.serializer.fromBytes(buffer);
    if (point.x != 1) {
      throw AssertionError(
        message:
            "Failed to skip value: got point.x=${point.x}, expected 1; input: $input",
      );
    }
  }

  final typedValue = evaluateTypedValue(input.value);
  for (final alternativeJson in input.alternativeJsons) {
    try {
      final roundTripJson = toDenseJson(
        typedValue.serializer,
        fromJsonKeepUnrecognized(
          typedValue.serializer,
          evaluateString(alternativeJson),
        ),
      );
      // Check if roundTripJson matches any of the expected values
      verifyAssertion(
        Assertion.createStringIn(
          actual: StringExpression.wrapLiteral(roundTripJson),
          expected: input.expectedDenseJson,
        ),
      );
    } catch (e) {
      if (e is AssertionError) {
        e.addContext(
          "while processing alternative JSON: ${evaluateString(alternativeJson)}",
        );
      }
      rethrow;
    }
  }
  for (final json in List.of(input.expectedDenseJson) +
      List.of(input.expectedReadableJson)) {
    try {
      final roundTripJson = toDenseJson(
        typedValue.serializer,
        fromJsonKeepUnrecognized(
          typedValue.serializer,
          json,
        ),
      );
      // Check if roundTripJson matches any of the expected values
      verifyAssertion(
        Assertion.createStringIn(
          actual: StringExpression.wrapLiteral(roundTripJson),
          expected: input.expectedDenseJson,
        ),
      );
    } catch (e) {
      if (e is AssertionError) {
        e.addContext(
          "while processing alternative JSON: ${json}",
        );
      }
      rethrow;
    }
  }

  for (final alternativeBytes in input.alternativeBytes) {
    try {
      final roundTripBytes = toBytes(
        typedValue.serializer,
        fromBytesDropUnrecognizedFields(
          typedValue.serializer,
          evaluateBytes(alternativeBytes),
        ),
      );
      // Check if roundTripBytes matches any of the expected values
      verifyAssertion(
        Assertion.createBytesIn(
          actual: BytesExpression.wrapLiteral(roundTripBytes),
          expected: input.expectedBytes,
        ),
      );
    } catch (e) {
      if (e is AssertionError) {
        e.addContext(
          "while processing alternative bytes: ${evaluateBytes(alternativeBytes).toBase16()}",
        );
      }
      rethrow;
    }
  }
  for (final bytes in input.expectedBytes) {
    try {
      final roundTripBytes = toBytes(
        typedValue.serializer,
        fromBytesDropUnrecognizedFields(
          typedValue.serializer,
          bytes,
        ),
      );
      // Check if roundTripBytes matches any of the expected values
      verifyAssertion(
        Assertion.createBytesIn(
          actual: BytesExpression.wrapLiteral(roundTripBytes),
          expected: input.expectedBytes,
        ),
      );
    } catch (e) {
      if (e is AssertionError) {
        e.addContext(
          "while processing alternative bytes: ${bytes.toBase16()}",
        );
      }
      rethrow;
    }
  }

  if (input.expectedTypeDescriptor != null) {
    final actual = typedValue.serializer.typeDescriptor.asJsonCode;
    verifyAssertion(
      Assertion.createStringEqual(
        actual: StringExpression.wrapLiteral(actual),
        expected: StringExpression.wrapLiteral(input.expectedTypeDescriptor!),
      ),
    );
    verifyAssertion(
      Assertion.createStringEqual(
        actual: StringExpression.wrapLiteral(
          skir.TypeDescriptor.parseFromJsonCode(actual).asJsonCode,
        ),
        expected: StringExpression.wrapLiteral(input.expectedTypeDescriptor!),
      ),
    );
  }
}

void reserializeLargeStringAndVerify(Assertion_ReserializeLargeString input) {
  final str = "a" * input.numChars;
  {
    final json = toDenseJson(skir.Serializers.string, str);
    final roundTrip = fromJsonDropUnrecognized(skir.Serializers.string, json);
    if (roundTrip != str) {
      throw AssertionError(
        actual: roundTrip,
        expected: str,
      );
    }
  }
  {
    final json = toReadableJson(skir.Serializers.string, str);
    final roundTrip = fromJsonDropUnrecognized(skir.Serializers.string, json);
    if (roundTrip != str) {
      throw AssertionError(
        actual: roundTrip,
        expected: str,
      );
    }
  }
  {
    final bytes = toBytes(skir.Serializers.string, str);
    if (!bytes.toBase16().startsWith(input.expectedBytePrefix.toBase16())) {
      throw AssertionError(
        actual: "hex:${bytes.toBase16()}",
        expected: "hex:${input.expectedBytePrefix.toBase16()}...",
      );
    }
    final roundTrip = fromBytesDropUnrecognizedFields(
      skir.Serializers.string,
      bytes,
    );
    if (roundTrip != str) {
      throw AssertionError(
        actual: roundTrip,
        expected: str,
      );
    }
  }
}

void reserializeLargeArrayAndVerify(Assertion_ReserializeLargeArray input) {
  final array = List<int>.filled(input.numItems, 1);
  final serializer = skir.Serializers.iterable(skir.Serializers.int32);

  bool isArray(Iterable<int> arr) {
    return arr.length == input.numItems && arr.every((v) => v == 1);
  }

  {
    final json = toDenseJson(serializer, array);
    final roundTrip = fromJsonDropUnrecognized(serializer, json);
    if (!isArray(roundTrip)) {
      throw AssertionError(
        actual: roundTrip,
        expected: array,
      );
    }
  }
  {
    final json = toReadableJson(serializer, array);
    final roundTrip = fromJsonDropUnrecognized(serializer, json);
    if (!isArray(roundTrip)) {
      throw AssertionError(
        actual: roundTrip,
        expected: array,
      );
    }
  }
  {
    final bytes = toBytes(serializer, array);
    if (!bytes.toBase16().startsWith(input.expectedBytePrefix.toBase16())) {
      throw AssertionError(
        actual: "hex:${bytes.toBase16()}",
        expected: "hex:${input.expectedBytePrefix.toBase16()}...",
      );
    }
    final roundTrip = fromBytesDropUnrecognizedFields(serializer, bytes);
    if (!isArray(roundTrip)) {
      throw AssertionError(
        actual: roundTrip,
        expected: array,
      );
    }
  }
}

skir.ByteString evaluateBytes(BytesExpression expr) {
  switch (expr.kind) {
    case BytesExpression_kind.literalWrapper:
      return (expr as BytesExpression_literalWrapper).value;
    case BytesExpression_kind.toBytesWrapper:
      {
        final literal =
            evaluateTypedValue((expr as BytesExpression_toBytesWrapper).value);
        return toBytes(literal.serializer, literal.value);
      }
    case BytesExpression_kind.unknown:
      throw Exception("Unknown bytes expression");
  }
}

String evaluateString(StringExpression expr) {
  switch (expr.kind) {
    case StringExpression_kind.literalWrapper:
      return (expr as StringExpression_literalWrapper).value;
    case StringExpression_kind.toDenseJsonWrapper:
      {
        final literal = evaluateTypedValue(
            (expr as StringExpression_toDenseJsonWrapper).value);
        return toDenseJson(literal.serializer, literal.value);
      }
    case StringExpression_kind.toReadableJsonWrapper:
      {
        final literal = evaluateTypedValue(
            (expr as StringExpression_toReadableJsonWrapper).value);
        return toReadableJson(literal.serializer, literal.value);
      }
    case StringExpression_kind.unknown:
      throw Exception("Unknown string expression");
  }
}

class TypedValueType<T> {
  final T value;
  final skir.Serializer<T> serializer;

  TypedValueType(this.value, this.serializer);
}

TypedValueType<dynamic> evaluateTypedValue(TypedValue literal) {
  switch (literal.kind) {
    case TypedValue_kind.boolWrapper:
      return TypedValueType(
        (literal as TypedValue_boolWrapper).value,
        skir.Serializers.bool,
      );
    case TypedValue_kind.int32Wrapper:
      return TypedValueType(
        (literal as TypedValue_int32Wrapper).value,
        skir.Serializers.int32,
      );
    case TypedValue_kind.int64Wrapper:
      return TypedValueType(
        (literal as TypedValue_int64Wrapper).value,
        skir.Serializers.int64,
      );
    case TypedValue_kind.hash64Wrapper:
      return TypedValueType(
        (literal as TypedValue_hash64Wrapper).value,
        skir.Serializers.hash64,
      );
    case TypedValue_kind.float32Wrapper:
      return TypedValueType(
        (literal as TypedValue_float32Wrapper).value,
        skir.Serializers.float32,
      );
    case TypedValue_kind.float64Wrapper:
      return TypedValueType(
        (literal as TypedValue_float64Wrapper).value,
        skir.Serializers.float64,
      );
    case TypedValue_kind.timestampWrapper:
      return TypedValueType(
        (literal as TypedValue_timestampWrapper).value,
        skir.Serializers.timestamp,
      );
    case TypedValue_kind.stringWrapper:
      return TypedValueType(
        (literal as TypedValue_stringWrapper).value,
        skir.Serializers.string,
      );
    case TypedValue_kind.bytesWrapper:
      return TypedValueType(
        (literal as TypedValue_bytesWrapper).value,
        skir.Serializers.bytes,
      );
    case TypedValue_kind.boolOptionalWrapper:
      return TypedValueType(
        (literal as TypedValue_boolOptionalWrapper).value,
        skir.Serializers.optional(skir.Serializers.bool),
      );
    case TypedValue_kind.intsWrapper:
      return TypedValueType(
        (literal as TypedValue_intsWrapper).value,
        skir.Serializers.iterable(skir.Serializers.int32),
      );
    case TypedValue_kind.pointWrapper:
      return TypedValueType(
        (literal as TypedValue_pointWrapper).value,
        Point.serializer,
      );
    case TypedValue_kind.colorWrapper:
      return TypedValueType(
        (literal as TypedValue_colorWrapper).value,
        Color.serializer,
      );
    case TypedValue_kind.myEnumWrapper:
      return TypedValueType(
        (literal as TypedValue_myEnumWrapper).value,
        MyEnum.serializer,
      );
    case TypedValue_kind.enumAWrapper:
      return TypedValueType(
        (literal as TypedValue_enumAWrapper).value,
        EnumA.serializer,
      );
    case TypedValue_kind.enumBWrapper:
      return TypedValueType(
        (literal as TypedValue_enumBWrapper).value,
        EnumB.serializer,
      );
    case TypedValue_kind.keyedArraysWrapper:
      return TypedValueType(
        (literal as TypedValue_keyedArraysWrapper).value,
        KeyedArrays.serializer,
      );
    case TypedValue_kind.recStructWrapper:
      return TypedValueType(
        (literal as TypedValue_recStructWrapper).value,
        RecStruct.serializer,
      );
    case TypedValue_kind.recEnumWrapper:
      return TypedValueType(
        (literal as TypedValue_recEnumWrapper).value,
        RecEnum.serializer,
      );
    case TypedValue_kind.roundTripDenseJsonWrapper:
      {
        final other = evaluateTypedValue(
            (literal as TypedValue_roundTripDenseJsonWrapper).value);
        return TypedValueType(
          fromJsonDropUnrecognized(
            other.serializer,
            toDenseJson(other.serializer, other.value),
          ),
          other.serializer,
        );
      }
    case TypedValue_kind.roundTripReadableJsonWrapper:
      {
        final other = evaluateTypedValue(
            (literal as TypedValue_roundTripReadableJsonWrapper).value);
        return TypedValueType(
          fromJsonDropUnrecognized(
            other.serializer,
            toReadableJson(other.serializer, other.value),
          ),
          other.serializer,
        );
      }
    case TypedValue_kind.roundTripBytesWrapper:
      {
        final other = evaluateTypedValue(
            (literal as TypedValue_roundTripBytesWrapper).value);
        return TypedValueType(
          fromBytesDropUnrecognizedFields(
            other.serializer,
            toBytes(other.serializer, other.value),
          ),
          other.serializer,
        );
      }
    case TypedValue_kind.pointFromJsonKeepUnrecognizedWrapper:
      return TypedValueType(
        fromJsonKeepUnrecognized(
          Point.serializer,
          evaluateString(
              (literal as TypedValue_pointFromJsonKeepUnrecognizedWrapper)
                  .value),
        ),
        Point.serializer,
      );
    case TypedValue_kind.pointFromJsonDropUnrecognizedWrapper:
      return TypedValueType(
        fromJsonDropUnrecognized(
          Point.serializer,
          evaluateString(
              (literal as TypedValue_pointFromJsonDropUnrecognizedWrapper)
                  .value),
        ),
        Point.serializer,
      );
    case TypedValue_kind.pointFromBytesKeepUnrecognizedWrapper:
      return TypedValueType(
        fromBytesKeepUnrecognized(
          Point.serializer,
          evaluateBytes(
              (literal as TypedValue_pointFromBytesKeepUnrecognizedWrapper)
                  .value),
        ),
        Point.serializer,
      );
    case TypedValue_kind.pointFromBytesDropUnrecognizedWrapper:
      return TypedValueType(
        fromBytesDropUnrecognizedFields(
          Point.serializer,
          evaluateBytes(
              (literal as TypedValue_pointFromBytesDropUnrecognizedWrapper)
                  .value),
        ),
        Point.serializer,
      );
    case TypedValue_kind.colorFromJsonKeepUnrecognizedWrapper:
      return TypedValueType(
        fromJsonKeepUnrecognized(
          Color.serializer,
          evaluateString(
              (literal as TypedValue_colorFromJsonKeepUnrecognizedWrapper)
                  .value),
        ),
        Color.serializer,
      );
    case TypedValue_kind.colorFromJsonDropUnrecognizedWrapper:
      return TypedValueType(
        fromJsonDropUnrecognized(
          Color.serializer,
          evaluateString(
              (literal as TypedValue_colorFromJsonDropUnrecognizedWrapper)
                  .value),
        ),
        Color.serializer,
      );
    case TypedValue_kind.colorFromBytesKeepUnrecognizedWrapper:
      return TypedValueType(
        fromBytesKeepUnrecognized(
          Color.serializer,
          evaluateBytes(
              (literal as TypedValue_colorFromBytesKeepUnrecognizedWrapper)
                  .value),
        ),
        Color.serializer,
      );
    case TypedValue_kind.colorFromBytesDropUnrecognizedWrapper:
      return TypedValueType(
        fromBytesDropUnrecognizedFields(
          Color.serializer,
          evaluateBytes(
              (literal as TypedValue_colorFromBytesDropUnrecognizedWrapper)
                  .value),
        ),
        Color.serializer,
      );
    case TypedValue_kind.myEnumFromJsonKeepUnrecognizedWrapper:
      return TypedValueType(
        fromJsonKeepUnrecognized(
          MyEnum.serializer,
          evaluateString(
              (literal as TypedValue_myEnumFromJsonKeepUnrecognizedWrapper)
                  .value),
        ),
        MyEnum.serializer,
      );
    case TypedValue_kind.myEnumFromJsonDropUnrecognizedWrapper:
      return TypedValueType(
        fromJsonDropUnrecognized(
          MyEnum.serializer,
          evaluateString(
              (literal as TypedValue_myEnumFromJsonDropUnrecognizedWrapper)
                  .value),
        ),
        MyEnum.serializer,
      );
    case TypedValue_kind.myEnumFromBytesKeepUnrecognizedWrapper:
      return TypedValueType(
        fromBytesKeepUnrecognized(
          MyEnum.serializer,
          evaluateBytes(
              (literal as TypedValue_myEnumFromBytesKeepUnrecognizedWrapper)
                  .value),
        ),
        MyEnum.serializer,
      );
    case TypedValue_kind.myEnumFromBytesDropUnrecognizedWrapper:
      return TypedValueType(
        fromBytesDropUnrecognizedFields(
          MyEnum.serializer,
          evaluateBytes(
              (literal as TypedValue_myEnumFromBytesDropUnrecognizedWrapper)
                  .value),
        ),
        MyEnum.serializer,
      );
    case TypedValue_kind.enumAFromJsonKeepUnrecognizedWrapper:
      return TypedValueType(
        fromJsonKeepUnrecognized(
          EnumA.serializer,
          evaluateString(
              (literal as TypedValue_enumAFromJsonKeepUnrecognizedWrapper)
                  .value),
        ),
        EnumA.serializer,
      );
    case TypedValue_kind.enumAFromJsonDropUnrecognizedWrapper:
      return TypedValueType(
        fromJsonDropUnrecognized(
          EnumA.serializer,
          evaluateString(
              (literal as TypedValue_enumAFromJsonDropUnrecognizedWrapper)
                  .value),
        ),
        EnumA.serializer,
      );
    case TypedValue_kind.enumAFromBytesKeepUnrecognizedWrapper:
      return TypedValueType(
        fromBytesKeepUnrecognized(
          EnumA.serializer,
          evaluateBytes(
              (literal as TypedValue_enumAFromBytesKeepUnrecognizedWrapper)
                  .value),
        ),
        EnumA.serializer,
      );
    case TypedValue_kind.enumAFromBytesDropUnrecognizedWrapper:
      return TypedValueType(
        fromBytesDropUnrecognizedFields(
          EnumA.serializer,
          evaluateBytes(
              (literal as TypedValue_enumAFromBytesDropUnrecognizedWrapper)
                  .value),
        ),
        EnumA.serializer,
      );
    case TypedValue_kind.enumBFromJsonKeepUnrecognizedWrapper:
      return TypedValueType(
        fromJsonKeepUnrecognized(
          EnumB.serializer,
          evaluateString(
              (literal as TypedValue_enumBFromJsonKeepUnrecognizedWrapper)
                  .value),
        ),
        EnumB.serializer,
      );
    case TypedValue_kind.enumBFromJsonDropUnrecognizedWrapper:
      return TypedValueType(
        fromJsonDropUnrecognized(
          EnumB.serializer,
          evaluateString(
              (literal as TypedValue_enumBFromJsonDropUnrecognizedWrapper)
                  .value),
        ),
        EnumB.serializer,
      );
    case TypedValue_kind.enumBFromBytesKeepUnrecognizedWrapper:
      return TypedValueType(
        fromBytesKeepUnrecognized(
          EnumB.serializer,
          evaluateBytes(
              (literal as TypedValue_enumBFromBytesKeepUnrecognizedWrapper)
                  .value),
        ),
        EnumB.serializer,
      );
    case TypedValue_kind.enumBFromBytesDropUnrecognizedWrapper:
      return TypedValueType(
        fromBytesDropUnrecognizedFields(
          EnumB.serializer,
          evaluateBytes(
              (literal as TypedValue_enumBFromBytesDropUnrecognizedWrapper)
                  .value),
        ),
        EnumB.serializer,
      );
    case TypedValue_kind.unknown:
      throw Exception("Unknown typed value");
  }
}

String toDenseJson<T>(skir.Serializer<T> serializer, T input) {
  try {
    return serializer.toJsonCode(input);
  } catch (e) {
    throw AssertionError(
        message: "Failed to serialize $input to dense JSON: $e");
  }
}

String toReadableJson<T>(skir.Serializer<T> serializer, T input) {
  try {
    return serializer.toJsonCode(input, readableFlavor: true);
  } catch (e) {
    throw AssertionError(
        message: "Failed to serialize $input to readable JSON: $e");
  }
}

skir.ByteString toBytes<T>(skir.Serializer<T> serializer, T input) {
  try {
    return skir.ByteString.copy(serializer.toBytes(input));
  } catch (e) {
    throw AssertionError(message: "Failed to serialize $input to bytes: $e");
  }
}

T fromJsonKeepUnrecognized<T>(skir.Serializer<T> serializer, String json) {
  try {
    return serializer.fromJsonCode(json, keepUnrecognizedValues: true);
  } catch (e) {
    throw AssertionError(message: "Failed to deserialize $json: $e");
  }
}

T fromJsonDropUnrecognized<T>(skir.Serializer<T> serializer, String json) {
  try {
    return serializer.fromJsonCode(json);
  } catch (e) {
    throw AssertionError(message: "Failed to deserialize $json: $e");
  }
}

T fromBytesDropUnrecognizedFields<T>(
  skir.Serializer<T> serializer,
  skir.ByteString bytes,
) {
  try {
    return serializer.fromBytes(Uint8List.fromList(bytes.asUnmodifiableList));
  } catch (e) {
    throw AssertionError(
        message: "Failed to deserialize ${bytes.toBase16()}: $e");
  }
}

T fromBytesKeepUnrecognized<T>(
  skir.Serializer<T> serializer,
  skir.ByteString bytes,
) {
  try {
    return serializer.fromBytes(Uint8List.fromList(bytes.asUnmodifiableList),
        keepUnrecognizedValues: true);
  } catch (e) {
    throw AssertionError(
        message: "Failed to deserialize ${bytes.toBase16()}: $e");
  }
}
