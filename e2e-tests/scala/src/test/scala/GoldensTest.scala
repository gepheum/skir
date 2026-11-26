import build.skir.JsonFlavor
import build.skir.Serializer
import build.skir.Serializers
import build.skir.UnrecognizedValuesPolicy
import build.skir.reflection.TypeDescriptor
import okio.ByteString
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import skirout.external.gepheum.skir_golden_tests.goldens.Assertion
import skirout.external.gepheum.skir_golden_tests.goldens.BytesExpression
import skirout.external.gepheum.skir_golden_tests.goldens.Color
import skirout.external.gepheum.skir_golden_tests.goldens.EnumA
import skirout.external.gepheum.skir_golden_tests.goldens.EnumB
import skirout.external.gepheum.skir_golden_tests.goldens.KeyedArrays
import skirout.external.gepheum.skir_golden_tests.goldens.MyEnum
import skirout.external.gepheum.skir_golden_tests.goldens.Point
import skirout.external.gepheum.skir_golden_tests.goldens.RecEnum
import skirout.external.gepheum.skir_golden_tests.goldens.RecStruct
import skirout.external.gepheum.skir_golden_tests.goldens.StringExpression
import skirout.external.gepheum.skir_golden_tests.goldens.TypedValue
import skirout.external.gepheum.skir_golden_tests.goldens.UNIT_TESTS
import scala.jdk.CollectionConverters.*

class GoldenAssertionError(
  override val getMessage: String,
) extends Exception(getMessage) {
  def this(actual: Any, expected: Any, message: String) =
    this(
      (if (message.nonEmpty) s"$message\n" else "") +
        s"Expected: $expected\n  Actual: $actual\n",
    )

  def this(actual: Any, expected: Any) = this(actual, expected, "")

  def addContext(context: String): Nothing =
    throw new GoldenAssertionError(
      if (getMessage.nonEmpty) s"$getMessage\n$context" else context,
    )
}

class GoldensTest {
  @TestFactory
  def goldens(): java.util.List[DynamicTest] = {
    val tests = UNIT_TESTS.asScala.toSeq
    tests.zipWithIndex.map { case (unitTest, i) =>
      if (unitTest.testNumber != tests.head.testNumber + i) {
        throw new RuntimeException(
          s"Test numbers are not sequential at test #$i: " +
            s"found ${unitTest.testNumber}, " +
            s"expected ${tests.head.testNumber + i}",
        )
      }
      DynamicTest.dynamicTest(
        s"test #${unitTest.testNumber}",
        () => {
          try {
            verifyAssertion(unitTest.assertion)
          } catch {
            case e: GoldenAssertionError =>
              e.addContext(s"While evaluating test #${unitTest.testNumber}")
          }
        },
      )
    }.asJava
  }

  private def verifyAssertion(assertion: Assertion): Unit =
    assertion.kind match {
      case Assertion.Kind.BYTES_EQUAL_WRAPPER =>
        val value = assertion.asInstanceOf[Assertion.BytesEqualWrapper].value
        val actual = evaluateBytes(value.actual).hex()
        val expected = evaluateBytes(value.expected).hex()
        if (actual != expected) {
          throw new GoldenAssertionError(s"hex:$actual", s"hex:$expected")
        }
      case Assertion.Kind.BYTES_IN_WRAPPER =>
        val value = assertion.asInstanceOf[Assertion.BytesInWrapper].value
        val actual = evaluateBytes(value.actual)
        val actualHex = actual.hex()
        val expectedList = value.expected.asScala
        val found = expectedList.exists(_.hex() == actualHex)
        if (!found) {
          throw new GoldenAssertionError(
            s"hex:$actualHex",
            expectedList.map(b => s"hex:${b.hex()}").mkString(" or "),
          )
        }
      case Assertion.Kind.STRING_EQUAL_WRAPPER =>
        val value = assertion.asInstanceOf[Assertion.StringEqualWrapper].value
        val actual = evaluateString(value.actual)
        val expected = evaluateString(value.expected)
        if (actual != expected) {
          throw new GoldenAssertionError(actual, expected, s"Actual: $actual")
        }
      case Assertion.Kind.STRING_IN_WRAPPER =>
        val value = assertion.asInstanceOf[Assertion.StringInWrapper].value
        val actual = evaluateString(value.actual)
        val expectedList = value.expected.asScala
        if (!expectedList.contains(actual)) {
          throw new GoldenAssertionError(actual, expectedList.mkString(" or "))
        }
      case Assertion.Kind.RESERIALIZE_VALUE_WRAPPER =>
        val value =
          assertion.asInstanceOf[Assertion.ReserializeValueWrapper].value
        reserializeValueAndVerify(value)
      case Assertion.Kind.RESERIALIZE_LARGE_STRING_WRAPPER =>
        val value =
          assertion.asInstanceOf[Assertion.ReserializeLargeStringWrapper].value
        reserializeLargeStringAndVerify(value)
      case Assertion.Kind.RESERIALIZE_LARGE_ARRAY_WRAPPER =>
        val value =
          assertion.asInstanceOf[Assertion.ReserializeLargeArrayWrapper].value
        reserializeLargeArrayAndVerify(value)
      case Assertion.Kind.ENUM_A_FROM_JSON_IS_CONSTANT_WRAPPER =>
        val value =
          assertion.asInstanceOf[Assertion.EnumAFromJsonIsConstantWrapper].value
        val jsonString = evaluateString(value.actual)
        val actual =
          if (value.keepUnrecognized)
            fromJsonKeepUnrecognized(EnumA.serializer, jsonString)
          else
            fromJsonDropUnrecognized(EnumA.serializer, jsonString)
        if (actual.kind != EnumA.Kind.A_CONST) {
          throw new GoldenAssertionError(
            actual.kind,
            EnumA.Kind.A_CONST,
            "Expected EnumA to be constant A",
          )
        }
      case Assertion.Kind.ENUM_A_FROM_BYTES_IS_CONSTANT_WRAPPER =>
        val value =
          assertion
            .asInstanceOf[Assertion.EnumAFromBytesIsConstantWrapper]
            .value
        val bytes = evaluateBytes(value.actual)
        val actual =
          if (value.keepUnrecognized)
            fromBytesKeepUnrecognized(EnumA.serializer, bytes)
          else
            fromBytesDropUnrecognizedFields(EnumA.serializer, bytes)
        if (actual.kind != EnumA.Kind.A_CONST) {
          throw new GoldenAssertionError(
            actual.kind,
            EnumA.Kind.A_CONST,
            "Expected EnumA to be constant A",
          )
        }
      case Assertion.Kind.ENUM_B_FROM_JSON_IS_WRAPPER_B_WRAPPER =>
        val value =
          assertion.asInstanceOf[Assertion.EnumBFromJsonIsWrapperBWrapper].value
        val jsonString = evaluateString(value.actual)
        val actual =
          if (value.keepUnrecognized)
            fromJsonKeepUnrecognized(EnumB.serializer, jsonString)
          else
            fromJsonDropUnrecognized(EnumB.serializer, jsonString)
        if (!actual.isInstanceOf[EnumB.BWrapper]) {
          throw new GoldenAssertionError(
            actual.kind,
            EnumB.Kind.B_WRAPPER,
            "Expected EnumB to be wrapper b",
          )
        }
        val bVal = actual.asInstanceOf[EnumB.BWrapper].value
        if (bVal != value.expected) {
          throw new GoldenAssertionError(
            bVal,
            value.expected,
            "Expected EnumB.b to wrap the expected string",
          )
        }
      case Assertion.Kind.ENUM_B_FROM_BYTES_IS_WRAPPER_B_WRAPPER =>
        val value =
          assertion
            .asInstanceOf[Assertion.EnumBFromBytesIsWrapperBWrapper]
            .value
        val bytes = evaluateBytes(value.actual)
        val actual =
          if (value.keepUnrecognized)
            fromBytesKeepUnrecognized(EnumB.serializer, bytes)
          else
            fromBytesDropUnrecognizedFields(EnumB.serializer, bytes)
        if (!actual.isInstanceOf[EnumB.BWrapper]) {
          throw new GoldenAssertionError(
            actual.kind,
            EnumB.Kind.B_WRAPPER,
            "Expected EnumB to be wrapper b",
          )
        }
        val bVal = actual.asInstanceOf[EnumB.BWrapper].value
        if (bVal != value.expected) {
          throw new GoldenAssertionError(
            bVal,
            value.expected,
            "Expected EnumB.b to wrap the expected string",
          )
        }
      case Assertion.Kind.UNKNOWN =>
        throw new RuntimeException("Unknown assertion kind")
    }

  private def reserializeValueAndVerify(
    input: Assertion.ReserializeValue,
  ): Unit = {
    val typedValues = Seq(
      input.value,
      TypedValue.RoundTripDenseJsonWrapper(input.value),
      TypedValue.RoundTripReadableJsonWrapper(input.value),
      TypedValue.RoundTripBytesWrapper(input.value),
    )

    for (inputValue <- typedValues) {
      try {
        verifyAssertion(
          Assertion.createBytesIn(
            actual = BytesExpression.ToBytesWrapper(inputValue),
            expected = input.expectedBytes,
          ),
        )
        verifyAssertion(
          Assertion.createStringIn(
            actual = StringExpression.ToDenseJsonWrapper(inputValue),
            expected = input.expectedDenseJson,
          ),
        )
        verifyAssertion(
          Assertion.createStringIn(
            actual = StringExpression.ToReadableJsonWrapper(inputValue),
            expected = input.expectedReadableJson,
          ),
        )
      } catch {
        case e: GoldenAssertionError =>
          e.addContext(s"input value: $inputValue")
      }
    }

    // Make sure the encoded value can be skipped.
    for (expectedBytes <- input.expectedBytes.asScala) {
      val expectedBytesList = expectedBytes.toByteArray()
      val buffer = new Array[Byte](expectedBytesList.length + 2)
      val prefix = "skir".getBytes()
      System.arraycopy(prefix, 0, buffer, 0, prefix.length)
      buffer(4) = 248.toByte
      System.arraycopy(
        expectedBytesList,
        prefix.length,
        buffer,
        5,
        expectedBytesList.length - prefix.length,
      )
      buffer(expectedBytesList.length + 1) = 1.toByte
      val point = Point.serializer.fromBytes(buffer)
      if (point.x != 1) {
        throw new GoldenAssertionError(
          s"Failed to skip value: got point.x=${point.x}, expected 1; input: $input",
        )
      }
    }

    val typedValue = evaluateTypedValue(input.value)
    val anySerializer = typedValue.serializer.asInstanceOf[Serializer[Any]]

    for (alternativeJson <- input.alternativeJsons.asScala) {
      try {
        val roundTripJson = toDenseJson(
          anySerializer,
          fromJsonKeepUnrecognized(
            anySerializer,
            evaluateString(alternativeJson),
          ),
        )
        verifyAssertion(
          Assertion.createStringIn(
            actual = StringExpression.LiteralWrapper(roundTripJson),
            expected = input.expectedDenseJson,
          ),
        )
      } catch {
        case e: GoldenAssertionError =>
          e.addContext(
            s"while processing alternative JSON: ${evaluateString(alternativeJson)}",
          )
      }
    }

    for (
      json <-
        input.expectedDenseJson.asScala ++ input.expectedReadableJson.asScala
    ) {
      try {
        val roundTripJson = toDenseJson(
          anySerializer,
          fromJsonKeepUnrecognized(anySerializer, json),
        )
        verifyAssertion(
          Assertion.createStringIn(
            actual = StringExpression.LiteralWrapper(roundTripJson),
            expected = input.expectedDenseJson,
          ),
        )
      } catch {
        case e: GoldenAssertionError =>
          e.addContext(s"while processing alternative JSON: $json")
      }
    }

    for (alternativeBytes <- input.alternativeBytes.asScala) {
      try {
        val roundTripBytes = toBytes(
          anySerializer,
          fromBytesDropUnrecognizedFields(
            anySerializer,
            evaluateBytes(alternativeBytes),
          ),
        )
        verifyAssertion(
          Assertion.createBytesIn(
            actual = BytesExpression.LiteralWrapper(roundTripBytes),
            expected = input.expectedBytes,
          ),
        )
      } catch {
        case e: GoldenAssertionError =>
          e.addContext(
            s"while processing alternative bytes: ${evaluateBytes(alternativeBytes).hex()}",
          )
      }
    }

    for (bytes <- input.expectedBytes.asScala) {
      try {
        val roundTripBytes = toBytes(
          anySerializer,
          fromBytesDropUnrecognizedFields(anySerializer, bytes),
        )
        verifyAssertion(
          Assertion.createBytesIn(
            actual = BytesExpression.LiteralWrapper(roundTripBytes),
            expected = input.expectedBytes,
          ),
        )
      } catch {
        case e: GoldenAssertionError =>
          e.addContext(s"while processing alternative bytes: ${bytes.hex()}")
      }
    }

    if (input.expectedTypeDescriptor.isPresent) {
      val expectedTypeDescriptor = input.expectedTypeDescriptor.get()
      val actual = typedValue.serializer.typeDescriptor().asJsonCode()
      verifyAssertion(
        Assertion.createStringEqual(
          actual = StringExpression.LiteralWrapper(actual),
          expected = StringExpression.LiteralWrapper(expectedTypeDescriptor),
        ),
      )
      verifyAssertion(
        Assertion.createStringEqual(
          actual = StringExpression.LiteralWrapper(
            TypeDescriptor.Companion.parseFromJsonCode(actual).asJsonCode(),
          ),
          expected = StringExpression.LiteralWrapper(expectedTypeDescriptor),
        ),
      )
    }
  }

  private def reserializeLargeStringAndVerify(
    input: Assertion.ReserializeLargeString,
  ): Unit = {
    val str = "a" * input.numChars

    {
      val json = toDenseJson(Serializers.string(), str)
      val roundTrip = fromJsonDropUnrecognized(Serializers.string(), json)
      if (roundTrip != str) {
        throw new GoldenAssertionError(roundTrip, str)
      }
    }

    {
      val json = toReadableJson(Serializers.string(), str)
      val roundTrip = fromJsonDropUnrecognized(Serializers.string(), json)
      if (roundTrip != str) {
        throw new GoldenAssertionError(roundTrip, str)
      }
    }

    {
      val bytes = toBytes(Serializers.string(), str)
      if (!bytes.hex().startsWith(input.expectedBytePrefix.hex())) {
        throw new GoldenAssertionError(
          s"hex:${bytes.hex()}",
          s"hex:${input.expectedBytePrefix.hex()}...",
        )
      }
      val roundTrip =
        fromBytesDropUnrecognizedFields(Serializers.string(), bytes)
      if (roundTrip != str) {
        throw new GoldenAssertionError(roundTrip, str)
      }
    }
  }

  private def reserializeLargeArrayAndVerify(
    input: Assertion.ReserializeLargeArray,
  ): Unit = {
    val array: java.util.List[java.lang.Integer] =
      Seq.fill(input.numItems)(java.lang.Integer.valueOf(1)).asJava
    val serializer = Serializers.list(Serializers.int32())

    def isArray(arr: java.util.List[java.lang.Integer]): Boolean =
      arr.size() == input.numItems && arr.asScala.forall(_.intValue() == 1)

    {
      val json = toDenseJson(serializer, array)
      val roundTrip = fromJsonDropUnrecognized(serializer, json)
      if (!isArray(roundTrip)) {
        throw new GoldenAssertionError(roundTrip, array)
      }
    }

    {
      val json = toReadableJson(serializer, array)
      val roundTrip = fromJsonDropUnrecognized(serializer, json)
      if (!isArray(roundTrip)) {
        throw new GoldenAssertionError(roundTrip, array)
      }
    }

    {
      val bytes = toBytes(serializer, array)
      if (!bytes.hex().startsWith(input.expectedBytePrefix.hex())) {
        throw new GoldenAssertionError(
          s"hex:${bytes.hex()}",
          s"hex:${input.expectedBytePrefix.hex()}...",
        )
      }
      val roundTrip = fromBytesDropUnrecognizedFields(serializer, bytes)
      if (!isArray(roundTrip)) {
        throw new GoldenAssertionError(roundTrip, array)
      }
    }
  }

  private def evaluateBytes(expr: BytesExpression): ByteString =
    expr.kind match {
      case BytesExpression.Kind.LITERAL_WRAPPER =>
        expr.asInstanceOf[BytesExpression.LiteralWrapper].value
      case BytesExpression.Kind.TO_BYTES_WRAPPER =>
        val literal = evaluateTypedValue(
          expr.asInstanceOf[BytesExpression.ToBytesWrapper].value,
        )
        toBytes(literal.serializer.asInstanceOf[Serializer[Any]], literal.value)
      case BytesExpression.Kind.UNKNOWN =>
        throw new RuntimeException("Unknown bytes expression")
    }

  private def evaluateString(expr: StringExpression): String =
    expr.kind match {
      case StringExpression.Kind.LITERAL_WRAPPER =>
        expr.asInstanceOf[StringExpression.LiteralWrapper].value
      case StringExpression.Kind.TO_DENSE_JSON_WRAPPER =>
        val literal = evaluateTypedValue(
          expr.asInstanceOf[StringExpression.ToDenseJsonWrapper].value,
        )
        toDenseJson(
          literal.serializer.asInstanceOf[Serializer[Any]],
          literal.value,
        )
      case StringExpression.Kind.TO_READABLE_JSON_WRAPPER =>
        val literal = evaluateTypedValue(
          expr.asInstanceOf[StringExpression.ToReadableJsonWrapper].value,
        )
        toReadableJson(
          literal.serializer.asInstanceOf[Serializer[Any]],
          literal.value,
        )
      case StringExpression.Kind.UNKNOWN =>
        throw new RuntimeException("Unknown string expression")
    }

  private case class TypedValueType[T](
    value: T,
    serializer: Serializer[T],
  )

  private def evaluateTypedValue(literal: TypedValue): TypedValueType[?] =
    literal.kind match {
      case TypedValue.Kind.BOOL_WRAPPER =>
        TypedValueType(
          java.lang.Boolean.valueOf(
            literal.asInstanceOf[TypedValue.BoolWrapper].value,
          ),
          Serializers.bool(),
        )
      case TypedValue.Kind.INT32_WRAPPER =>
        TypedValueType(
          java.lang.Integer.valueOf(
            literal.asInstanceOf[TypedValue.Int32Wrapper].value,
          ),
          Serializers.int32(),
        )
      case TypedValue.Kind.INT64_WRAPPER =>
        TypedValueType(
          java.lang.Long.valueOf(
            literal.asInstanceOf[TypedValue.Int64Wrapper].value,
          ),
          Serializers.int64(),
        )
      case TypedValue.Kind.HASH64_WRAPPER =>
        TypedValueType(
          java.lang.Long.valueOf(
            literal.asInstanceOf[TypedValue.Hash64Wrapper].value,
          ),
          Serializers.javaHash64(),
        )
      case TypedValue.Kind.FLOAT32_WRAPPER =>
        TypedValueType(
          java.lang.Float.valueOf(
            literal.asInstanceOf[TypedValue.Float32Wrapper].value,
          ),
          Serializers.float32(),
        )
      case TypedValue.Kind.FLOAT64_WRAPPER =>
        TypedValueType(
          java.lang.Double.valueOf(
            literal.asInstanceOf[TypedValue.Float64Wrapper].value,
          ),
          Serializers.float64(),
        )
      case TypedValue.Kind.TIMESTAMP_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.TimestampWrapper].value,
          Serializers.timestamp(),
        )
      case TypedValue.Kind.STRING_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.StringWrapper].value,
          Serializers.string(),
        )
      case TypedValue.Kind.BYTES_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.BytesWrapper].value,
          Serializers.bytes(),
        )
      case TypedValue.Kind.BOOL_OPTIONAL_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.BoolOptionalWrapper].value,
          Serializers.javaOptional(Serializers.bool()),
        )
      case TypedValue.Kind.INTS_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.IntsWrapper].value,
          Serializers.list(Serializers.int32()),
        )
      case TypedValue.Kind.POINT_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.PointWrapper].value,
          Point.serializer,
        )
      case TypedValue.Kind.COLOR_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.ColorWrapper].value,
          Color.serializer,
        )
      case TypedValue.Kind.MY_ENUM_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.MyEnumWrapper].value,
          MyEnum.serializer,
        )
      case TypedValue.Kind.ENUM_A_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.EnumAWrapper].value,
          EnumA.serializer,
        )
      case TypedValue.Kind.ENUM_B_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.EnumBWrapper].value,
          EnumB.serializer,
        )
      case TypedValue.Kind.KEYED_ARRAYS_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.KeyedArraysWrapper].value,
          KeyedArrays.serializer,
        )
      case TypedValue.Kind.REC_STRUCT_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.RecStructWrapper].value,
          RecStruct.serializer,
        )
      case TypedValue.Kind.REC_ENUM_WRAPPER =>
        TypedValueType(
          literal.asInstanceOf[TypedValue.RecEnumWrapper].value,
          RecEnum.serializer,
        )
      case TypedValue.Kind.ROUND_TRIP_DENSE_JSON_WRAPPER =>
        val other = evaluateTypedValue(
          literal.asInstanceOf[TypedValue.RoundTripDenseJsonWrapper].value,
        )
        val s = other.serializer.asInstanceOf[Serializer[Any]]
        TypedValueType(
          fromJsonDropUnrecognized(s, toDenseJson(s, other.value)),
          s,
        )
      case TypedValue.Kind.ROUND_TRIP_READABLE_JSON_WRAPPER =>
        val other = evaluateTypedValue(
          literal.asInstanceOf[TypedValue.RoundTripReadableJsonWrapper].value,
        )
        val s = other.serializer.asInstanceOf[Serializer[Any]]
        TypedValueType(
          fromJsonDropUnrecognized(s, toReadableJson(s, other.value)),
          s,
        )
      case TypedValue.Kind.ROUND_TRIP_BYTES_WRAPPER =>
        val other = evaluateTypedValue(
          literal.asInstanceOf[TypedValue.RoundTripBytesWrapper].value,
        )
        val s = other.serializer.asInstanceOf[Serializer[Any]]
        TypedValueType(
          fromBytesDropUnrecognizedFields(s, toBytes(s, other.value)),
          s,
        )
      case TypedValue.Kind.POINT_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonKeepUnrecognized(
            Point.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.PointFromJsonKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          Point.serializer,
        )
      case TypedValue.Kind.POINT_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonDropUnrecognized(
            Point.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.PointFromJsonDropUnrecognizedWrapper]
                .value,
            ),
          ),
          Point.serializer,
        )
      case TypedValue.Kind.POINT_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesKeepUnrecognized(
            Point.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.PointFromBytesKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          Point.serializer,
        )
      case TypedValue.Kind.POINT_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesDropUnrecognizedFields(
            Point.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.PointFromBytesDropUnrecognizedWrapper]
                .value,
            ),
          ),
          Point.serializer,
        )
      case TypedValue.Kind.COLOR_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonKeepUnrecognized(
            Color.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.ColorFromJsonKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          Color.serializer,
        )
      case TypedValue.Kind.COLOR_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonDropUnrecognized(
            Color.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.ColorFromJsonDropUnrecognizedWrapper]
                .value,
            ),
          ),
          Color.serializer,
        )
      case TypedValue.Kind.COLOR_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesKeepUnrecognized(
            Color.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.ColorFromBytesKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          Color.serializer,
        )
      case TypedValue.Kind.COLOR_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesDropUnrecognizedFields(
            Color.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.ColorFromBytesDropUnrecognizedWrapper]
                .value,
            ),
          ),
          Color.serializer,
        )
      case TypedValue.Kind.MY_ENUM_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonKeepUnrecognized(
            MyEnum.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.MyEnumFromJsonKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          MyEnum.serializer,
        )
      case TypedValue.Kind.MY_ENUM_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonDropUnrecognized(
            MyEnum.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.MyEnumFromJsonDropUnrecognizedWrapper]
                .value,
            ),
          ),
          MyEnum.serializer,
        )
      case TypedValue.Kind.MY_ENUM_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesKeepUnrecognized(
            MyEnum.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.MyEnumFromBytesKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          MyEnum.serializer,
        )
      case TypedValue.Kind.MY_ENUM_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesDropUnrecognizedFields(
            MyEnum.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.MyEnumFromBytesDropUnrecognizedWrapper]
                .value,
            ),
          ),
          MyEnum.serializer,
        )
      case TypedValue.Kind.ENUM_A_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonKeepUnrecognized(
            EnumA.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.EnumAFromJsonKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumA.serializer,
        )
      case TypedValue.Kind.ENUM_A_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonDropUnrecognized(
            EnumA.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.EnumAFromJsonDropUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumA.serializer,
        )
      case TypedValue.Kind.ENUM_A_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesKeepUnrecognized(
            EnumA.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.EnumAFromBytesKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumA.serializer,
        )
      case TypedValue.Kind.ENUM_A_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesDropUnrecognizedFields(
            EnumA.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.EnumAFromBytesDropUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumA.serializer,
        )
      case TypedValue.Kind.ENUM_B_FROM_JSON_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonKeepUnrecognized(
            EnumB.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.EnumBFromJsonKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumB.serializer,
        )
      case TypedValue.Kind.ENUM_B_FROM_JSON_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromJsonDropUnrecognized(
            EnumB.serializer,
            evaluateString(
              literal
                .asInstanceOf[TypedValue.EnumBFromJsonDropUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumB.serializer,
        )
      case TypedValue.Kind.ENUM_B_FROM_BYTES_KEEP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesKeepUnrecognized(
            EnumB.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.EnumBFromBytesKeepUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumB.serializer,
        )
      case TypedValue.Kind.ENUM_B_FROM_BYTES_DROP_UNRECOGNIZED_WRAPPER =>
        TypedValueType(
          fromBytesDropUnrecognizedFields(
            EnumB.serializer,
            evaluateBytes(
              literal
                .asInstanceOf[TypedValue.EnumBFromBytesDropUnrecognizedWrapper]
                .value,
            ),
          ),
          EnumB.serializer,
        )
      case TypedValue.Kind.UNKNOWN =>
        throw new RuntimeException("Unknown typed value")
    }

  private def toDenseJson[T](serializer: Serializer[T], input: T): String =
    try serializer.toJsonCode(input)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(
          s"Failed to serialize $input to dense JSON: $e",
        )
    }

  private def toReadableJson[T](serializer: Serializer[T], input: T): String =
    try serializer.toJsonCode(input, JsonFlavor.READABLE)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(
          s"Failed to serialize $input to readable JSON: $e",
        )
    }

  private def toBytes[T](serializer: Serializer[T], input: T): ByteString =
    try serializer.toBytes(input)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(
          s"Failed to serialize $input to bytes: $e",
        )
    }

  private def fromJsonKeepUnrecognized[T](
    serializer: Serializer[T],
    json: String,
  ): T =
    try serializer.fromJsonCode(json, UnrecognizedValuesPolicy.KEEP)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(s"Failed to deserialize $json: $e")
    }

  private def fromJsonDropUnrecognized[T](
    serializer: Serializer[T],
    json: String,
  ): T =
    try serializer.fromJsonCode(json)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(s"Failed to deserialize $json: $e")
    }

  private def fromBytesDropUnrecognizedFields[T](
    serializer: Serializer[T],
    bytes: ByteString,
  ): T =
    try serializer.fromBytes(bytes.toByteArray())
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(
          s"Failed to deserialize ${bytes.hex()}: $e",
        )
    }

  private def fromBytesKeepUnrecognized[T](
    serializer: Serializer[T],
    bytes: ByteString,
  ): T =
    try
      serializer.fromBytes(bytes.toByteArray(), UnrecognizedValuesPolicy.KEEP)
    catch {
      case e: Exception =>
        throw new GoldenAssertionError(
          s"Failed to deserialize ${bytes.hex()}: $e",
        )
    }
}
