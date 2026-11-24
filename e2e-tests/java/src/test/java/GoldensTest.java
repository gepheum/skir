import build.skir.JsonFlavor;
import build.skir.Serializer;
import build.skir.Serializers;
import build.skir.UnrecognizedValuesPolicy;
import build.skir.reflection.TypeDescriptor;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import okio.ByteString;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;
import skirout.external.gepheum.skir_golden_tests.goldens.Assertion;
import skirout.external.gepheum.skir_golden_tests.goldens.BytesExpression;
import skirout.external.gepheum.skir_golden_tests.goldens.Color;
import skirout.external.gepheum.skir_golden_tests.goldens.Constants;
import skirout.external.gepheum.skir_golden_tests.goldens.EnumA;
import skirout.external.gepheum.skir_golden_tests.goldens.EnumB;
import skirout.external.gepheum.skir_golden_tests.goldens.KeyedArrays;
import skirout.external.gepheum.skir_golden_tests.goldens.MyEnum;
import skirout.external.gepheum.skir_golden_tests.goldens.Point;
import skirout.external.gepheum.skir_golden_tests.goldens.RecEnum;
import skirout.external.gepheum.skir_golden_tests.goldens.RecStruct;
import skirout.external.gepheum.skir_golden_tests.goldens.StringExpression;
import skirout.external.gepheum.skir_golden_tests.goldens.TypedValue;
import skirout.external.gepheum.skir_golden_tests.goldens.UnitTest;

public class GoldensTest {

  private static class AssertionError extends RuntimeException {
    public AssertionError(String message) {
      super(message);
    }

    public AssertionError(Object actual, Object expected, String message) {
      super(buildMessage(actual, expected, message));
    }

    private static String buildMessage(Object actual, Object expected, String message) {
      StringBuilder sb = new StringBuilder();
      if (!message.isEmpty()) {
        sb.append(message).append("\n");
      }
      sb.append("Expected: ").append(expected).append("\n");
      sb.append("  Actual: ").append(actual).append("\n");
      return sb.toString();
    }

    public void addContext(String context) {
      String newMessage = getMessage().isEmpty() ? context : getMessage() + "\n" + context;
      throw new AssertionError(newMessage);
    }
  }

  @TestFactory
  Stream<DynamicTest> goldens() {
    List<UnitTest> unitTests = Constants.UNIT_TESTS;
    for (int i = 0; i < unitTests.size(); i++) {
      UnitTest unitTest = unitTests.get(i);
      if (unitTest.testNumber() != unitTests.get(0).testNumber() + i) {
        throw new RuntimeException(
            "Test numbers are not sequential at test #"
                + i
                + ": "
                + "found "
                + unitTest.testNumber()
                + ", "
                + "expected "
                + (unitTests.get(0).testNumber() + i));
      }
    }

    return unitTests.stream()
        .map(
            unitTest ->
                DynamicTest.dynamicTest(
                    "test #" + unitTest.testNumber(),
                    () -> {
                      try {
                        verifyAssertion(unitTest.assertion());
                      } catch (AssertionError e) {
                        e.addContext("While evaluating test #" + unitTest.testNumber());
                        System.out.println(e.getMessage());
                        System.out.println("\n\n");
                        throw e;
                      }
                    }));
  }

  private void verifyAssertion(Assertion assertion) {
    switch (assertion.kind()) {
      case BYTES_EQUAL_WRAPPER -> {
        Assertion.BytesEqual value = assertion.asBytesEqual();
        String actual = evaluateBytes(value.actual()).hex();
        String expected = evaluateBytes(value.expected()).hex();
        if (!actual.equals(expected)) {
          throw new AssertionError("hex:" + actual, "hex:" + expected, "");
        }
      }
      case BYTES_IN_WRAPPER -> {
        Assertion.BytesIn value = assertion.asBytesIn();
        ByteString actual = evaluateBytes(value.actual());
        String actualHex = actual.hex();
        boolean found =
            value.expected().stream()
                .anyMatch(expectedBytes -> expectedBytes.hex().equals(actualHex));
        if (!found) {
          throw new AssertionError(
              "hex:" + actualHex,
              value.expected().stream()
                  .map(b -> "hex:" + b.hex())
                  .reduce((a, b) -> a + " or " + b)
                  .orElse(""),
              "");
        }
      }
      case STRING_EQUAL_WRAPPER -> {
        Assertion.StringEqual value = assertion.asStringEqual();
        String actual = evaluateString(value.actual());
        String expected = evaluateString(value.expected());
        if (!actual.equals(expected)) {
          throw new AssertionError(actual, expected, "Actual: " + actual);
        }
      }
      case STRING_IN_WRAPPER -> {
        Assertion.StringIn value = assertion.asStringIn();
        String actual = evaluateString(value.actual());
        if (!value.expected().contains(actual)) {
          throw new AssertionError(actual, String.join(" or ", value.expected()), "");
        }
      }
      case RESERIALIZE_VALUE_WRAPPER -> {
        Assertion.ReserializeValue value = assertion.asReserializeValue();
        reserializeValueAndVerify(value);
      }
      case RESERIALIZE_LARGE_STRING_WRAPPER -> {
        Assertion.ReserializeLargeString value = assertion.asReserializeLargeString();
        reserializeLargeStringAndVerify(value);
      }
      case RESERIALIZE_LARGE_ARRAY_WRAPPER -> {
        Assertion.ReserializeLargeArray value = assertion.asReserializeLargeArray();
        reserializeLargeArrayAndVerify(value);
      }
      case ENUM_A_FROM_JSON_IS_CONSTANT_WRAPPER -> {
        Assertion.EnumAFromJsonIsConstant value = assertion.asEnumAFromJsonIsConstant();
        String json = evaluateString(value.actual());
        EnumA actual =
            value.keepUnrecognized()
                ? fromJsonKeepUnrecognized(EnumA.SERIALIZER, json)
                : fromJsonDropUnrecognized(EnumA.SERIALIZER, json);
        if (actual.kind() != EnumA.Kind.A_CONST) {
          throw new AssertionError(
              actual.kind(), EnumA.Kind.A_CONST, "Expected EnumA to be constant A");
        }
      }
      case ENUM_A_FROM_BYTES_IS_CONSTANT_WRAPPER -> {
        Assertion.EnumAFromBytesIsConstant value = assertion.asEnumAFromBytesIsConstant();
        ByteString bytes = evaluateBytes(value.actual());
        EnumA actual =
            value.keepUnrecognized()
                ? fromBytesKeepUnrecognized(EnumA.SERIALIZER, bytes)
                : fromBytesDropUnrecognizedFields(EnumA.SERIALIZER, bytes);
        if (actual.kind() != EnumA.Kind.A_CONST) {
          throw new AssertionError(
              actual.kind(), EnumA.Kind.A_CONST, "Expected EnumA to be constant A");
        }
      }
      case ENUM_B_FROM_JSON_IS_WRAPPER_B_WRAPPER -> {
        Assertion.EnumBFromJsonIsWrapperB value = assertion.asEnumBFromJsonIsWrapperB();
        String json = evaluateString(value.actual());
        EnumB actual =
            value.keepUnrecognized()
                ? fromJsonKeepUnrecognized(EnumB.SERIALIZER, json)
                : fromJsonDropUnrecognized(EnumB.SERIALIZER, json);
        if (!actual.isB()) {
          throw new AssertionError(
              actual.kind(), EnumB.Kind.B_WRAPPER, "Expected EnumB to be wrapper b");
        }
        if (!actual.asB().equals(value.expected())) {
          throw new AssertionError(
              actual.asB(), value.expected(), "Expected EnumB.b to wrap the expected string");
        }
      }
      case ENUM_B_FROM_BYTES_IS_WRAPPER_B_WRAPPER -> {
        Assertion.EnumBFromBytesIsWrapperB value = assertion.asEnumBFromBytesIsWrapperB();
        ByteString bytes = evaluateBytes(value.actual());
        EnumB actual =
            value.keepUnrecognized()
                ? fromBytesKeepUnrecognized(EnumB.SERIALIZER, bytes)
                : fromBytesDropUnrecognizedFields(EnumB.SERIALIZER, bytes);
        if (!actual.isB()) {
          throw new AssertionError(
              actual.kind(), EnumB.Kind.B_WRAPPER, "Expected EnumB to be wrapper b");
        }
        if (!actual.asB().equals(value.expected())) {
          throw new AssertionError(
              actual.asB(), value.expected(), "Expected EnumB.b to wrap the expected string");
        }
      }
      case UNKNOWN -> throw new RuntimeException("Unknown assertion kind");
    }
  }

  private void reserializeValueAndVerify(Assertion.ReserializeValue input) {
    List<TypedValue> typedValues =
        Arrays.asList(
            input.value(),
            TypedValue.wrapRoundTripDenseJson(input.value()),
            TypedValue.wrapRoundTripReadableJson(input.value()),
            TypedValue.wrapRoundTripBytes(input.value()));

    for (TypedValue inputValue : typedValues) {
      try {
        // Verify bytes - check if actual matches any of the expected values
        verifyAssertion(
            Assertion.wrapBytesIn(
                Assertion.BytesIn.builder()
                    .setActual(BytesExpression.wrapToBytes(inputValue))
                    .setExpected(input.expectedBytes())
                    .build()));

        // Verify dense JSON - check if actual matches any of the expected values
        verifyAssertion(
            Assertion.wrapStringIn(
                Assertion.StringIn.builder()
                    .setActual(StringExpression.wrapToDenseJson(inputValue))
                    .setExpected(input.expectedDenseJson())
                    .build()));

        // Verify readable JSON - check if actual matches any of the expected values
        verifyAssertion(
            Assertion.wrapStringIn(
                Assertion.StringIn.builder()
                    .setActual(StringExpression.wrapToReadableJson(inputValue))
                    .setExpected(input.expectedReadableJson())
                    .build()));
      } catch (AssertionError e) {
        e.addContext("input value: " + inputValue);
        throw e;
      }
    }

    // Make sure the encoded value can be skipped.
    for (ByteString expectedBytes : input.expectedBytes()) {
      byte[] expectedBytesList = expectedBytes.toByteArray();
      byte[] buffer = new byte[expectedBytesList.length + 2];
      String prefix = "skir";
      byte[] prefixBytes = prefix.getBytes(StandardCharsets.UTF_8);
      System.arraycopy(prefixBytes, 0, buffer, 0, prefixBytes.length);
      buffer[4] = (byte) 248;
      System.arraycopy(
          expectedBytesList,
          prefixBytes.length,
          buffer,
          5,
          expectedBytesList.length - prefixBytes.length);
      buffer[expectedBytesList.length + 1] = 1;
      Point point = Point.SERIALIZER.fromBytes(buffer);
      if (point.x() != 1) {
        throw new AssertionError(
            "Failed to skip value: got point.x=" + point.x() + ", expected 1; input: " + input);
      }
    }

    TypedValueType<?> typedValue = evaluateTypedValue(input.value());
    for (StringExpression alternativeJson : input.alternativeJsons()) {
      try {
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) typedValue.serializer;
        String roundTripJson =
            toDenseJson(
                serializer, fromJsonKeepUnrecognized(serializer, evaluateString(alternativeJson)));
        // Check if roundTripJson matches any of the expected values
        verifyAssertion(
            Assertion.wrapStringIn(
                Assertion.StringIn.builder()
                    .setActual(StringExpression.wrapLiteral(roundTripJson))
                    .setExpected(input.expectedDenseJson())
                    .build()));
      } catch (AssertionError e) {
        e.addContext("while processing alternative JSON: " + evaluateString(alternativeJson));
        throw e;
      }
    }

    for (String json :
        Stream.concat(input.expectedDenseJson().stream(), input.expectedReadableJson().stream())
            .toList()) {
      try {
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) typedValue.serializer;
        String roundTripJson = toDenseJson(serializer, fromJsonKeepUnrecognized(serializer, json));
        // Check if roundTripJson matches any of the expected values
        verifyAssertion(
            Assertion.wrapStringIn(
                Assertion.StringIn.builder()
                    .setActual(StringExpression.wrapLiteral(roundTripJson))
                    .setExpected(input.expectedDenseJson())
                    .build()));
      } catch (AssertionError e) {
        e.addContext("while processing alternative JSON: " + json);
        throw e;
      }
    }

    for (BytesExpression alternativeBytes : input.alternativeBytes()) {
      try {
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) typedValue.serializer;
        ByteString roundTripBytes =
            toBytes(
                serializer,
                fromBytesDropUnrecognizedFields(serializer, evaluateBytes(alternativeBytes)));
        // Check if roundTripBytes matches any of the expected values
        verifyAssertion(
            Assertion.wrapBytesIn(
                Assertion.BytesIn.builder()
                    .setActual(BytesExpression.wrapLiteral(roundTripBytes))
                    .setExpected(input.expectedBytes())
                    .build()));
      } catch (AssertionError e) {
        e.addContext(
            "while processing alternative bytes: " + evaluateBytes(alternativeBytes).hex());
        throw e;
      }
    }

    for (ByteString bytes : input.expectedBytes()) {
      try {
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) typedValue.serializer;
        ByteString roundTripBytes =
            toBytes(serializer, fromBytesDropUnrecognizedFields(serializer, bytes));
        // Check if roundTripBytes matches any of the expected values
        verifyAssertion(
            Assertion.wrapBytesIn(
                Assertion.BytesIn.builder()
                    .setActual(BytesExpression.wrapLiteral(roundTripBytes))
                    .setExpected(input.expectedBytes())
                    .build()));
      } catch (AssertionError e) {
        e.addContext("while processing alternative bytes: " + bytes.hex());
        throw e;
      }
    }

    Optional<String> expectedTypeDescriptor = input.expectedTypeDescriptor();
    if (expectedTypeDescriptor.isPresent()) {
      String actual = typedValue.serializer.typeDescriptor().asJsonCode();
      verifyAssertion(
          Assertion.wrapStringEqual(
              Assertion.StringEqual.builder()
                  .setActual(StringExpression.wrapLiteral(actual))
                  .setExpected(StringExpression.wrapLiteral(expectedTypeDescriptor.get()))
                  .build()));
      verifyAssertion(
          Assertion.wrapStringEqual(
              Assertion.StringEqual.builder()
                  .setActual(
                      StringExpression.wrapLiteral(
                          TypeDescriptor.Companion.parseFromJsonCode(actual).asJsonCode()))
                  .setExpected(StringExpression.wrapLiteral(expectedTypeDescriptor.get()))
                  .build()));
      verifyAssertion(
          Assertion.wrapStringEqual(
              Assertion.StringEqual.builder()
                  .setActual(
                      StringExpression.wrapLiteral(
                          TypeDescriptor.Companion.parseFromJsonCode(actual).asJsonCode()))
                  .setExpected(StringExpression.wrapLiteral(expectedTypeDescriptor.get()))
                  .build()));
    }
  }

  private void reserializeLargeStringAndVerify(Assertion.ReserializeLargeString input) {
    String str = "a".repeat(input.numChars());

    {
      String json = toDenseJson(Serializers.string(), str);
      String roundTrip = fromJsonDropUnrecognized(Serializers.string(), json);
      if (!roundTrip.equals(str)) {
        throw new AssertionError(roundTrip, str, "");
      }
    }

    {
      String json = toReadableJson(Serializers.string(), str);
      String roundTrip = fromJsonDropUnrecognized(Serializers.string(), json);
      if (!roundTrip.equals(str)) {
        throw new AssertionError(roundTrip, str, "");
      }
    }

    {
      ByteString bytes = toBytes(Serializers.string(), str);
      if (!bytes.hex().startsWith(input.expectedBytePrefix().hex())) {
        throw new AssertionError(
            "hex:" + bytes.hex(), "hex:" + input.expectedBytePrefix().hex() + "...", "");
      }
      String roundTrip = fromBytesDropUnrecognizedFields(Serializers.string(), bytes);
      if (!roundTrip.equals(str)) {
        throw new AssertionError(roundTrip, str, "");
      }
    }
  }

  private void reserializeLargeArrayAndVerify(Assertion.ReserializeLargeArray input) {
    List<Integer> array = Stream.generate(() -> 1).limit(input.numItems()).toList();
    Serializer<List<Integer>> serializer = Serializers.list(Serializers.int32());

    {
      String json = toDenseJson(serializer, array);
      List<Integer> roundTrip = fromJsonDropUnrecognized(serializer, json);
      if (!isArray(roundTrip, input.numItems())) {
        throw new AssertionError(roundTrip, array, "");
      }
    }

    {
      String json = toReadableJson(serializer, array);
      List<Integer> roundTrip = fromJsonDropUnrecognized(serializer, json);
      if (!isArray(roundTrip, input.numItems())) {
        throw new AssertionError(roundTrip, array, "");
      }
    }

    {
      ByteString bytes = toBytes(serializer, array);
      if (!bytes.hex().startsWith(input.expectedBytePrefix().hex())) {
        throw new AssertionError(
            "hex:" + bytes.hex(), "hex:" + input.expectedBytePrefix().hex() + "...", "");
      }
      List<Integer> roundTrip = fromBytesDropUnrecognizedFields(serializer, bytes);
      if (!isArray(roundTrip, input.numItems())) {
        throw new AssertionError(roundTrip, array, "");
      }
    }
  }

  private boolean isArray(List<Integer> arr, int numItems) {
    return arr.size() == numItems && arr.stream().allMatch(i -> i == 1);
  }

  private ByteString evaluateBytes(BytesExpression expr) {
    return switch (expr.kind()) {
      case LITERAL_WRAPPER -> expr.asLiteral();
      case TO_BYTES_WRAPPER -> {
        TypedValueType<?> literal = evaluateTypedValue(expr.asToBytes());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) literal.serializer;
        yield toBytes(serializer, literal.value);
      }
      case UNKNOWN -> throw new RuntimeException("Unknown bytes expression");
    };
  }

  private String evaluateString(StringExpression expr) {
    return switch (expr.kind()) {
      case LITERAL_WRAPPER -> expr.asLiteral();
      case TO_DENSE_JSON_WRAPPER -> {
        TypedValueType<?> literal = evaluateTypedValue(expr.asToDenseJson());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) literal.serializer;
        yield toDenseJson(serializer, literal.value);
      }
      case TO_READABLE_JSON_WRAPPER -> {
        TypedValueType<?> literal = evaluateTypedValue(expr.asToReadableJson());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) literal.serializer;
        yield toReadableJson(serializer, literal.value);
      }
      case UNKNOWN -> throw new RuntimeException("Unknown string expression");
    };
  }

  private static class TypedValueType<T> {
    final T value;
    final Serializer<T> serializer;

    TypedValueType(T value, Serializer<T> serializer) {
      this.value = value;
      this.serializer = serializer;
    }
  }

  private TypedValueType<?> evaluateTypedValue(TypedValue literal) {
    return switch (literal.kind()) {
      case BOOL_WRAPPER -> new TypedValueType<>(literal.asBool(), Serializers.bool());
      case INT32_WRAPPER -> new TypedValueType<>(literal.asInt32(), Serializers.int32());
      case INT64_WRAPPER -> new TypedValueType<>(literal.asInt64(), Serializers.int64());
      case HASH64_WRAPPER -> new TypedValueType<>(literal.asHash64(), Serializers.javaHash64());
      case FLOAT32_WRAPPER -> new TypedValueType<>(literal.asFloat32(), Serializers.float32());
      case FLOAT64_WRAPPER -> new TypedValueType<>(literal.asFloat64(), Serializers.float64());
      case TIMESTAMP_WRAPPER -> new TypedValueType<>(
          literal.asTimestamp(), Serializers.timestamp());
      case STRING_WRAPPER -> new TypedValueType<>(literal.asString(), Serializers.string());
      case BYTES_WRAPPER -> new TypedValueType<>(literal.asBytes(), Serializers.bytes());
      case BOOL_OPTIONAL_WRAPPER -> new TypedValueType<>(
          literal.asBoolOptional(), Serializers.javaOptional(Serializers.bool()));
      case INTS_WRAPPER -> new TypedValueType<>(
          literal.asInts(), Serializers.list(Serializers.int32()));
      case POINT_WRAPPER -> new TypedValueType<>(literal.asPoint(), Point.SERIALIZER);
      case COLOR_WRAPPER -> new TypedValueType<>(literal.asColor(), Color.SERIALIZER);
      case MY_ENUM_WRAPPER -> new TypedValueType<>(literal.asMyEnum(), MyEnum.SERIALIZER);
      case ENUM_A_WRAPPER -> new TypedValueType<>(literal.asEnumA(), EnumA.SERIALIZER);
      case ENUM_B_WRAPPER -> new TypedValueType<>(literal.asEnumB(), EnumB.SERIALIZER);
      case KEYED_ARRAYS_WRAPPER -> new TypedValueType<>(
          literal.asKeyedArrays(), KeyedArrays.SERIALIZER);
      case REC_STRUCT_WRAPPER -> new TypedValueType<>(literal.asRecStruct(), RecStruct.SERIALIZER);
      case REC_ENUM_WRAPPER -> new TypedValueType<>(literal.asRecEnum(), RecEnum.SERIALIZER);
      case ROUND_TRIP_DENSE_JSON_WRAPPER -> {
        TypedValueType<?> other = evaluateTypedValue(literal.asRoundTripDenseJson());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) other.serializer;
        Object roundTrip =
            fromJsonDropUnrecognized(serializer, toDenseJson(serializer, other.value));
        @SuppressWarnings({"rawtypes", "unchecked"})
        TypedValueType result = new TypedValueType(roundTrip, other.serializer);
        yield result;
      }
      case ROUND_TRIP_READABLE_JSON_WRAPPER -> {
        TypedValueType<?> other = evaluateTypedValue(literal.asRoundTripReadableJson());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) other.serializer;
        Object roundTrip =
            fromJsonDropUnrecognized(serializer, toReadableJson(serializer, other.value));
        @SuppressWarnings({"rawtypes", "unchecked"})
        TypedValueType result = new TypedValueType(roundTrip, other.serializer);
        yield result;
      }
      case ROUND_TRIP_BYTES_WRAPPER -> {
        TypedValueType<?> other = evaluateTypedValue(literal.asRoundTripBytes());
        @SuppressWarnings("unchecked")
        Serializer<Object> serializer = (Serializer<Object>) other.serializer;
        Object roundTrip =
            fromBytesDropUnrecognizedFields(serializer, toBytes(serializer, other.value));
        @SuppressWarnings({"rawtypes", "unchecked"})
        TypedValueType result = new TypedValueType(roundTrip, other.serializer);
        yield result;
      }
      case POINT_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonKeepUnrecognized(
              Point.SERIALIZER, evaluateString(literal.asPointFromJsonKeepUnrecognized())),
          Point.SERIALIZER);
      case POINT_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonDropUnrecognized(
              Point.SERIALIZER, evaluateString(literal.asPointFromJsonDropUnrecognized())),
          Point.SERIALIZER);
      case POINT_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesKeepUnrecognized(
              Point.SERIALIZER, evaluateBytes(literal.asPointFromBytesKeepUnrecognized())),
          Point.SERIALIZER);
      case POINT_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesDropUnrecognizedFields(
              Point.SERIALIZER, evaluateBytes(literal.asPointFromBytesDropUnrecognized())),
          Point.SERIALIZER);
      case COLOR_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonKeepUnrecognized(
              Color.SERIALIZER, evaluateString(literal.asColorFromJsonKeepUnrecognized())),
          Color.SERIALIZER);
      case COLOR_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonDropUnrecognized(
              Color.SERIALIZER, evaluateString(literal.asColorFromJsonDropUnrecognized())),
          Color.SERIALIZER);
      case COLOR_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesKeepUnrecognized(
              Color.SERIALIZER, evaluateBytes(literal.asColorFromBytesKeepUnrecognized())),
          Color.SERIALIZER);
      case COLOR_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesDropUnrecognizedFields(
              Color.SERIALIZER, evaluateBytes(literal.asColorFromBytesDropUnrecognized())),
          Color.SERIALIZER);
      case MY_ENUM_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonKeepUnrecognized(
              MyEnum.SERIALIZER, evaluateString(literal.asMyEnumFromJsonKeepUnrecognized())),
          MyEnum.SERIALIZER);
      case MY_ENUM_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonDropUnrecognized(
              MyEnum.SERIALIZER, evaluateString(literal.asMyEnumFromJsonDropUnrecognized())),
          MyEnum.SERIALIZER);
      case MY_ENUM_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesKeepUnrecognized(
              MyEnum.SERIALIZER, evaluateBytes(literal.asMyEnumFromBytesKeepUnrecognized())),
          MyEnum.SERIALIZER);
      case MY_ENUM_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesDropUnrecognizedFields(
              MyEnum.SERIALIZER, evaluateBytes(literal.asMyEnumFromBytesDropUnrecognized())),
          MyEnum.SERIALIZER);
      case ENUM_A_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonKeepUnrecognized(
              EnumA.SERIALIZER, evaluateString(literal.asEnumAFromJsonKeepUnrecognized())),
          EnumA.SERIALIZER);
      case ENUM_A_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonDropUnrecognized(
              EnumA.SERIALIZER, evaluateString(literal.asEnumAFromJsonDropUnrecognized())),
          EnumA.SERIALIZER);
      case ENUM_A_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesKeepUnrecognized(
              EnumA.SERIALIZER, evaluateBytes(literal.asEnumAFromBytesKeepUnrecognized())),
          EnumA.SERIALIZER);
      case ENUM_A_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesDropUnrecognizedFields(
              EnumA.SERIALIZER, evaluateBytes(literal.asEnumAFromBytesDropUnrecognized())),
          EnumA.SERIALIZER);
      case ENUM_B_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonKeepUnrecognized(
              EnumB.SERIALIZER, evaluateString(literal.asEnumBFromJsonKeepUnrecognized())),
          EnumB.SERIALIZER);
      case ENUM_B_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromJsonDropUnrecognized(
              EnumB.SERIALIZER, evaluateString(literal.asEnumBFromJsonDropUnrecognized())),
          EnumB.SERIALIZER);
      case ENUM_B_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesKeepUnrecognized(
              EnumB.SERIALIZER, evaluateBytes(literal.asEnumBFromBytesKeepUnrecognized())),
          EnumB.SERIALIZER);
      case ENUM_B_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER -> new TypedValueType<>(
          fromBytesDropUnrecognizedFields(
              EnumB.SERIALIZER, evaluateBytes(literal.asEnumBFromBytesDropUnrecognized())),
          EnumB.SERIALIZER);
      case UNKNOWN -> throw new RuntimeException("Unknown typed value");
    };
  }

  private <T> String toDenseJson(Serializer<T> serializer, T input) {
    try {
      return serializer.toJsonCode(input);
    } catch (Exception e) {
      throw new AssertionError("Failed to serialize " + input + " to dense JSON: " + e);
    }
  }

  private <T> String toReadableJson(Serializer<T> serializer, T input) {
    try {
      return serializer.toJsonCode(input, JsonFlavor.READABLE);
    } catch (Exception e) {
      throw new AssertionError("Failed to serialize " + input + " to readable JSON: " + e);
    }
  }

  private <T> ByteString toBytes(Serializer<T> serializer, T input) {
    try {
      return serializer.toBytes(input);
    } catch (Exception e) {
      throw new AssertionError("Failed to serialize " + input + " to bytes: " + e);
    }
  }

  private <T> T fromJsonKeepUnrecognized(Serializer<T> serializer, String json) {
    try {
      return serializer.fromJsonCode(json, UnrecognizedValuesPolicy.KEEP);
    } catch (Exception e) {
      throw new AssertionError("Failed to deserialize " + json + ": " + e);
    }
  }

  private <T> T fromJsonDropUnrecognized(Serializer<T> serializer, String json) {
    try {
      return serializer.fromJsonCode(json);
    } catch (Exception e) {
      throw new AssertionError("Failed to deserialize " + json + ": " + e);
    }
  }

  private <T> T fromBytesDropUnrecognizedFields(Serializer<T> serializer, ByteString bytes) {
    try {
      return serializer.fromBytes(bytes.toByteArray());
    } catch (Exception e) {
      throw new AssertionError("Failed to deserialize " + bytes.hex() + ": " + e);
    }
  }

  private <T> T fromBytesKeepUnrecognized(Serializer<T> serializer, ByteString bytes) {
    try {
      return serializer.fromBytes(bytes.toByteArray(), UnrecognizedValuesPolicy.KEEP);
    } catch (Exception e) {
      throw new AssertionError("Failed to deserialize " + bytes.hex() + ": " + e);
    }
  }
}
