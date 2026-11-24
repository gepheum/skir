import json
import unittest
from dataclasses import dataclass
from typing import Any, Generic, TypeVar

import skir.reflection
from skirout.external.gepheum.skir_golden_tests.goldens_skir import (
    UNIT_TESTS,
    Assertion,
    BytesExpression,
    Color,
    EnumA,
    EnumB,
    KeyedArrays,
    MyEnum,
    Point,
    RecEnum,
    RecStruct,
    StringExpression,
    TypedValue,
)

import skir


class AssertionError(Exception):
    def __init__(self, actual=None, expected=None, message=None):
        self.actual = actual
        self.expected = expected
        self._message = message or f"Actual: {actual}, Expected: {expected}"
        super().__init__(self._message)

    def add_context(self, context: str):
        if self._message:
            self._message = f"{self._message}\n{context}"
        else:
            self._message = context
        self.args = (self._message,)


class GoldensTestCase(unittest.TestCase):
    def test_goldens(self):
        for unit_test in UNIT_TESTS:
            try:
                verify_assertion(unit_test.assertion)
            except AssertionError as e:
                e.add_context(f"While evaluating test #{unit_test.test_number}")
                raise


def verify_assertion(assertion: Assertion):
    if assertion.union.kind == "bytes_equal":
        actual = evaluate_bytes(assertion.union.value.actual).hex()
        expected = evaluate_bytes(assertion.union.value.expected).hex()
        if actual != expected:
            raise AssertionError(
                actual=f"hex:{actual}",
                expected=f"hex:{expected}",
            )
    elif assertion.union.kind == "bytes_in":
        actual = evaluate_bytes(assertion.union.value.actual)
        actual_hex = actual.hex()
        found = any(
            expected_bytes.hex() == actual_hex
            for expected_bytes in assertion.union.value.expected
        )
        if not found:
            raise AssertionError(
                actual=f"hex:{actual_hex}",
                expected=" or ".join(
                    f"hex:{b.hex()}" for b in assertion.union.value.expected
                ),
            )
    elif assertion.union.kind == "string_equal":
        actual = evaluate_string(assertion.union.value.actual)
        expected = evaluate_string(assertion.union.value.expected)
        if actual != expected:
            raise AssertionError(
                actual=actual,
                expected=expected,
                message=f"Actual: {json.dumps(actual)}",
            )
    elif assertion.union.kind == "string_in":
        actual = evaluate_string(assertion.union.value.actual)
        if actual not in assertion.union.value.expected:
            raise AssertionError(
                actual=actual,
                expected=" or ".join(assertion.union.value.expected),
            )
    elif assertion.union.kind == "reserialize_value":
        return reserialize_value_and_verify(assertion.union.value)
    elif assertion.union.kind == "reserialize_large_string":
        return reserialize_large_string_and_verify(assertion.union.value)
    elif assertion.union.kind == "reserialize_large_array":
        return reserialize_large_array_and_verify(assertion.union.value)
    elif assertion.union.kind == "UNKNOWN":
        raise ValueError("Unknown assertion kind")
    elif assertion.union.kind == "enum_a_from_json_is_constant":
        json_code = evaluate_string(assertion.union.value.actual)
        if assertion.union.value.keep_unrecognized:
            value = from_json_keep_unrecognized(EnumA.serializer, json_code)
        else:
            value = from_json_drop_unrecognized(EnumA.serializer, json_code)
        if value.union.kind != "A":
            raise AssertionError(
                actual=value.union.kind,
                expected="A",
                message=f"Expected EnumA from JSON to be constant A, but got kind={value.union.kind}",
            )
    elif assertion.union.kind == "enum_a_from_bytes_is_constant":
        data = evaluate_bytes(assertion.union.value.actual)
        if assertion.union.value.keep_unrecognized:
            value = from_bytes_keep_unrecognized(EnumA.serializer, data)
        else:
            value = from_bytes_drop_unrecognized_fields(EnumA.serializer, data)
        if value.union.kind != "A":
            raise AssertionError(
                actual=value.union.kind,
                expected="A",
                message=f"Expected EnumA from bytes to be constant A, but got kind={value.union.kind}",
            )
    elif assertion.union.kind == "enum_b_from_json_is_wrapper_b":
        json_code = evaluate_string(assertion.union.value.actual)
        if assertion.union.value.keep_unrecognized:
            value = from_json_keep_unrecognized(EnumB.serializer, json_code)
        else:
            value = from_json_drop_unrecognized(EnumB.serializer, json_code)
        if value.union.kind != "b":
            raise AssertionError(
                actual=value.union.kind,
                expected="b",
                message=f"Expected EnumB from JSON to be wrapper b, but got kind={value.union.kind}",
            )
        if value.union.value != assertion.union.value.expected:
            raise AssertionError(
                actual=value.union.value,
                expected=assertion.union.value.expected,
                message=f"Expected EnumB.b from JSON to wrap {assertion.union.value.expected!r}, but got {value.union.value!r}",
            )
    elif assertion.union.kind == "enum_b_from_bytes_is_wrapper_b":
        data = evaluate_bytes(assertion.union.value.actual)
        if assertion.union.value.keep_unrecognized:
            value = from_bytes_keep_unrecognized(EnumB.serializer, data)
        else:
            value = from_bytes_drop_unrecognized_fields(EnumB.serializer, data)
        if value.union.kind != "b":
            raise AssertionError(
                actual=value.union.kind,
                expected="b",
                message=f"Expected EnumB from bytes to be wrapper b, but got kind={value.union.kind}",
            )
        if value.union.value != assertion.union.value.expected:
            raise AssertionError(
                actual=value.union.value,
                expected=assertion.union.value.expected,
                message=f"Expected EnumB.b from bytes to wrap {assertion.union.value.expected!r}, but got {value.union.value!r}",
            )
    else:
        raise ValueError(f"Unhandled assertion kind: {assertion.union.kind}")


def reserialize_value_and_verify(input_value: Assertion.ReserializeValue):
    typed_values = [
        input_value.value,
        TypedValue.wrap_round_trip_dense_json(input_value.value),
        TypedValue.wrap_round_trip_readable_json(input_value.value),
        TypedValue.wrap_round_trip_bytes(input_value.value),
    ]
    for typed_value_input in typed_values:
        try:
            # Verify bytes - check if actual matches any of the expected values
            verify_assertion(
                Assertion.create_bytes_in(
                    actual=BytesExpression.wrap_to_bytes(typed_value_input),
                    expected=input_value.expected_bytes,
                )
            )

            # Verify dense JSON - check if actual matches any of the expected values
            verify_assertion(
                Assertion.create_string_in(
                    actual=StringExpression.wrap_to_dense_json(typed_value_input),
                    expected=input_value.expected_dense_json,
                )
            )

            # Verify readable JSON - check if actual matches any of the expected values
            verify_assertion(
                Assertion.create_string_in(
                    actual=StringExpression.wrap_to_readable_json(typed_value_input),
                    expected=input_value.expected_readable_json,
                )
            )
        except AssertionError as e:
            e.add_context(f"input value: {typed_value_input}")
            raise

    # Make sure the encoded value can be skipped.
    for expected_bytes in input_value.expected_bytes:
        buffer = bytearray(len(expected_bytes) + 2)
        prefix = b"skir"
        buffer[0:4] = prefix
        buffer[4] = 248
        buffer[5 : len(expected_bytes) + 1] = expected_bytes[len(prefix) :]
        buffer[len(expected_bytes) + 1] = 1
        point = Point.serializer.from_bytes(bytes(buffer))
        if point.x != 1:
            raise AssertionError(
                message=f"Failed to skip value: got point.x={point.x}, expected 1; input: {input_value}"
            )

    typed_value = evaluate_typed_value(input_value.value)
    for alternative_json in input_value.alternative_jsons:
        try:
            round_trip_json = to_dense_json(
                typed_value.serializer,
                from_json_keep_unrecognized(
                    typed_value.serializer,
                    evaluate_string(alternative_json),
                ),
            )
            # Check if round_trip_json matches any of the expected values
            verify_assertion(
                Assertion.create_string_in(
                    actual=StringExpression.wrap_literal(round_trip_json),
                    expected=input_value.expected_dense_json,
                )
            )
        except AssertionError as e:
            e.add_context(
                f"while processing alternative JSON: {evaluate_string(alternative_json)}"
            )
            raise
    for alternative_json in (
        input_value.expected_dense_json + input_value.expected_readable_json
    ):
        try:
            round_trip_json = to_dense_json(
                typed_value.serializer,
                from_json_keep_unrecognized(
                    typed_value.serializer,
                    alternative_json,
                ),
            )
            # Check if round_trip_json matches any of the expected values
            verify_assertion(
                Assertion.create_string_in(
                    actual=StringExpression.wrap_literal(round_trip_json),
                    expected=input_value.expected_dense_json,
                )
            )
        except AssertionError as e:
            e.add_context(f"while processing alternative JSON: {alternative_json}")
            raise

    for alternative_bytes in input_value.alternative_bytes:
        try:
            round_trip_bytes = to_bytes(
                typed_value.serializer,
                from_bytes_drop_unrecognized_fields(
                    typed_value.serializer,
                    evaluate_bytes(alternative_bytes),
                ),
            )
            # Check if round_trip_bytes matches any of the expected values
            verify_assertion(
                Assertion.create_bytes_in(
                    actual=BytesExpression.wrap_literal(round_trip_bytes),
                    expected=input_value.expected_bytes,
                )
            )
        except AssertionError as e:
            e.add_context(
                f"while processing alternative bytes: {evaluate_bytes(alternative_bytes).hex()}"
            )
            raise
    for alternative_bytes in input_value.expected_bytes:
        try:
            round_trip_bytes = to_bytes(
                typed_value.serializer,
                from_bytes_drop_unrecognized_fields(
                    typed_value.serializer,
                    alternative_bytes,
                ),
            )
            # Check if round_trip_bytes matches any of the expected values
            verify_assertion(
                Assertion.create_bytes_in(
                    actual=BytesExpression.wrap_literal(round_trip_bytes),
                    expected=input_value.expected_bytes,
                )
            )
        except AssertionError as e:
            e.add_context(
                f"while processing alternative bytes: {alternative_bytes.hex()}"
            )
            raise

    if input_value.expected_type_descriptor:
        actual = typed_value.serializer.type_descriptor.as_json_code()
        verify_assertion(
            Assertion.create_string_equal(
                actual=StringExpression.wrap_literal(actual),
                expected=StringExpression.wrap_literal(
                    input_value.expected_type_descriptor
                ),
            )
        )
        verify_assertion(
            Assertion.create_string_equal(
                actual=StringExpression.wrap_literal(
                    skir.reflection.TypeDescriptor.from_json_code(actual).as_json_code()
                ),
                expected=StringExpression.wrap_literal(actual),
            )
        )


def reserialize_large_string_and_verify(input_value: Assertion.ReserializeLargeString):
    string = "a" * input_value.num_chars

    # Test dense JSON
    json_dense = to_dense_json(skir.primitive_serializer("string"), string)
    round_trip = from_json_drop_unrecognized(
        skir.primitive_serializer("string"), json_dense
    )
    if round_trip != string:
        raise AssertionError(
            actual=round_trip,
            expected=string,
        )

    # Test readable JSON
    json_readable = to_readable_json(skir.primitive_serializer("string"), string)
    round_trip = from_json_drop_unrecognized(
        skir.primitive_serializer("string"), json_readable
    )
    if round_trip != string:
        raise AssertionError(
            actual=round_trip,
            expected=string,
        )

    # Test bytes
    byte_data = to_bytes(skir.primitive_serializer("string"), string)
    if not byte_data.hex().startswith(input_value.expected_byte_prefix.hex()):
        raise AssertionError(
            actual=f"hex:{byte_data.hex()}",
            expected=f"hex:{input_value.expected_byte_prefix.hex()}...",
        )
    round_trip = from_bytes_drop_unrecognized_fields(
        skir.primitive_serializer("string"), byte_data
    )
    if round_trip != string:
        raise AssertionError(
            actual=round_trip,
            expected=string,
        )


def reserialize_large_array_and_verify(input_value: Assertion.ReserializeLargeArray):
    array = (1,) * input_value.num_items
    serializer = skir.array_serializer(skir.primitive_serializer("int32"))

    def is_array_valid(arr):
        return len(arr) == input_value.num_items and all(v == 1 for v in arr)

    # Test dense JSON
    json_dense = to_dense_json(serializer, array)
    round_trip = from_json_drop_unrecognized(serializer, json_dense)
    if not is_array_valid(round_trip):
        raise AssertionError(
            actual=round_trip,
            expected=array,
        )

    # Test readable JSON
    json_readable = to_readable_json(serializer, array)
    round_trip = from_json_drop_unrecognized(serializer, json_readable)
    if not is_array_valid(round_trip):
        raise AssertionError(
            actual=round_trip,
            expected=array,
        )

    # Test bytes
    byte_data = to_bytes(serializer, array)
    if not byte_data.hex().startswith(input_value.expected_byte_prefix.hex()):
        raise AssertionError(
            actual=f"hex:{byte_data.hex()}",
            expected=f"hex:{input_value.expected_byte_prefix.hex()}...",
        )
    round_trip = from_bytes_drop_unrecognized_fields(serializer, byte_data)
    if not is_array_valid(round_trip):
        raise AssertionError(
            actual=round_trip,
            expected=array,
        )


def evaluate_bytes(expr: BytesExpression) -> bytes:
    if expr.union.kind == "literal":
        return expr.union.value
    elif expr.union.kind == "to_bytes":
        literal = evaluate_typed_value(expr.union.value)
        return to_bytes(literal.serializer, literal.value)
    elif expr.union.kind == "UNKNOWN":
        raise ValueError("Unknown BytesExpression kind")
    else:
        raise ValueError(f"Unexpected BytesExpression kind: {expr.union.kind}")


def evaluate_string(expr: StringExpression) -> str:
    if expr.union.kind == "literal":
        return expr.union.value
    elif expr.union.kind == "to_dense_json":
        literal = evaluate_typed_value(expr.union.value)
        return to_dense_json(literal.serializer, literal.value)
    elif expr.union.kind == "to_readable_json":
        literal = evaluate_typed_value(expr.union.value)
        return to_readable_json(literal.serializer, literal.value)
    elif expr.union.kind == "UNKNOWN":
        raise ValueError("Unknown StringExpression kind")
    else:
        raise ValueError(f"Unexpected StringExpression kind: {expr.union.kind}")


T = TypeVar("T")


@dataclass(frozen=True)
class TypedValueType(Generic[T]):
    value: T
    serializer: skir.Serializer[T]


def evaluate_typed_value(literal: TypedValue) -> TypedValueType[Any]:
    if literal.union.kind == "bool":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("bool"),
        )
    elif literal.union.kind == "int32":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("int32"),
        )
    elif literal.union.kind == "int64":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("int64"),
        )
    elif literal.union.kind == "hash64":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("hash64"),
        )
    elif literal.union.kind == "float32":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("float32"),
        )
    elif literal.union.kind == "float64":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("float64"),
        )
    elif literal.union.kind == "timestamp":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("timestamp"),
        )
    elif literal.union.kind == "string":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("string"),
        )
    elif literal.union.kind == "bytes":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.primitive_serializer("bytes"),
        )
    elif literal.union.kind == "bool_optional":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.optional_serializer(skir.primitive_serializer("bool")),
        )
    elif literal.union.kind == "ints":
        return TypedValueType(
            value=literal.union.value,
            serializer=skir.array_serializer(skir.primitive_serializer("int32")),
        )
    elif literal.union.kind == "point":
        return TypedValueType(
            value=literal.union.value,
            serializer=Point.serializer,
        )
    elif literal.union.kind == "color":
        return TypedValueType(
            value=literal.union.value,
            serializer=Color.serializer,
        )
    elif literal.union.kind == "my_enum":
        return TypedValueType(
            value=literal.union.value,
            serializer=MyEnum.serializer,
        )
    elif literal.union.kind == "keyed_arrays":
        return TypedValueType(
            value=literal.union.value,
            serializer=KeyedArrays.serializer,
        )
    elif literal.union.kind == "rec_struct":
        return TypedValueType(
            value=literal.union.value,
            serializer=RecStruct.serializer,
        )
    elif literal.union.kind == "rec_enum":
        return TypedValueType(
            value=literal.union.value,
            serializer=RecEnum.serializer,
        )
    elif literal.union.kind == "round_trip_dense_json":
        other = evaluate_typed_value(literal.union.value)
        return TypedValueType(
            value=from_json_drop_unrecognized(
                other.serializer, to_dense_json(other.serializer, other.value)
            ),
            serializer=other.serializer,
        )
    elif literal.union.kind == "round_trip_readable_json":
        other = evaluate_typed_value(literal.union.value)
        return TypedValueType(
            value=from_json_drop_unrecognized(
                other.serializer, to_readable_json(other.serializer, other.value)
            ),
            serializer=other.serializer,
        )
    elif literal.union.kind == "round_trip_bytes":
        other = evaluate_typed_value(literal.union.value)
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                other.serializer, to_bytes(other.serializer, other.value)
            ),
            serializer=other.serializer,
        )
    elif literal.union.kind == "point_from_json_keep_unrecognized":
        return TypedValueType(
            value=from_json_keep_unrecognized(
                Point.serializer, evaluate_string(literal.union.value)
            ),
            serializer=Point.serializer,
        )
    elif literal.union.kind == "point_from_json_drop_unrecognized":
        return TypedValueType(
            value=from_json_drop_unrecognized(
                Point.serializer, evaluate_string(literal.union.value)
            ),
            serializer=Point.serializer,
        )
    elif literal.union.kind == "point_from_bytes_keep_unrecognized":
        return TypedValueType(
            value=from_bytes_keep_unrecognized(
                Point.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=Point.serializer,
        )
    elif literal.union.kind == "point_from_bytes_drop_unrecognized":
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                Point.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=Point.serializer,
        )
    elif literal.union.kind == "color_from_json_keep_unrecognized":
        return TypedValueType(
            value=from_json_keep_unrecognized(
                Color.serializer, evaluate_string(literal.union.value)
            ),
            serializer=Color.serializer,
        )
    elif literal.union.kind == "color_from_json_drop_unrecognized":
        return TypedValueType(
            value=from_json_drop_unrecognized(
                Color.serializer, evaluate_string(literal.union.value)
            ),
            serializer=Color.serializer,
        )
    elif literal.union.kind == "color_from_bytes_keep_unrecognized":
        return TypedValueType(
            value=from_bytes_keep_unrecognized(
                Color.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=Color.serializer,
        )
    elif literal.union.kind == "color_from_bytes_drop_unrecognized":
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                Color.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=Color.serializer,
        )
    elif literal.union.kind == "my_enum_from_json_keep_unrecognized":
        return TypedValueType(
            value=from_json_keep_unrecognized(
                MyEnum.serializer, evaluate_string(literal.union.value)
            ),
            serializer=MyEnum.serializer,
        )
    elif literal.union.kind == "my_enum_from_json_drop_unrecognized":
        return TypedValueType(
            value=from_json_drop_unrecognized(
                MyEnum.serializer, evaluate_string(literal.union.value)
            ),
            serializer=MyEnum.serializer,
        )
    elif literal.union.kind == "my_enum_from_bytes_keep_unrecognized":
        return TypedValueType(
            value=from_bytes_keep_unrecognized(
                MyEnum.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=MyEnum.serializer,
        )
    elif literal.union.kind == "my_enum_from_bytes_drop_unrecognized":
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                MyEnum.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=MyEnum.serializer,
        )
    elif literal.union.kind == "enum_a":
        return TypedValueType(
            value=literal.union.value,
            serializer=EnumA.serializer,
        )
    elif literal.union.kind == "enum_b":
        return TypedValueType(
            value=literal.union.value,
            serializer=EnumB.serializer,
        )
    elif literal.union.kind == "enum_a_from_json_keep_unrecognized":
        return TypedValueType(
            value=from_json_keep_unrecognized(
                EnumA.serializer, evaluate_string(literal.union.value)
            ),
            serializer=EnumA.serializer,
        )
    elif literal.union.kind == "enum_a_from_json_drop_unrecognized":
        return TypedValueType(
            value=from_json_drop_unrecognized(
                EnumA.serializer, evaluate_string(literal.union.value)
            ),
            serializer=EnumA.serializer,
        )
    elif literal.union.kind == "enum_a_from_bytes_keep_unrecognized":
        return TypedValueType(
            value=from_bytes_keep_unrecognized(
                EnumA.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=EnumA.serializer,
        )
    elif literal.union.kind == "enum_a_from_bytes_drop_unrecognized":
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                EnumA.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=EnumA.serializer,
        )
    elif literal.union.kind == "enum_b_from_json_keep_unrecognized":
        return TypedValueType(
            value=from_json_keep_unrecognized(
                EnumB.serializer, evaluate_string(literal.union.value)
            ),
            serializer=EnumB.serializer,
        )
    elif literal.union.kind == "enum_b_from_json_drop_unrecognized":
        return TypedValueType(
            value=from_json_drop_unrecognized(
                EnumB.serializer, evaluate_string(literal.union.value)
            ),
            serializer=EnumB.serializer,
        )
    elif literal.union.kind == "enum_b_from_bytes_keep_unrecognized":
        return TypedValueType(
            value=from_bytes_keep_unrecognized(
                EnumB.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=EnumB.serializer,
        )
    elif literal.union.kind == "enum_b_from_bytes_drop_unrecognized":
        return TypedValueType(
            value=from_bytes_drop_unrecognized_fields(
                EnumB.serializer, evaluate_bytes(literal.union.value)
            ),
            serializer=EnumB.serializer,
        )
    elif literal.union.kind == "UNKNOWN":
        raise ValueError("Unknown TypedValue kind")
    else:
        raise ValueError(f"Unexpected TypedValue kind: {literal.union.kind}")


def to_dense_json(serializer: skir.Serializer[T], input: T) -> str:
    try:
        return serializer.to_json_code(input)
    except Exception as e:
        raise AssertionError(f"Failed to serialize {input} to dense JSON: {e}")


def to_readable_json(serializer: skir.Serializer[T], input: T) -> str:
    try:
        return serializer.to_json_code(input, readable=True)
    except Exception as e:
        raise AssertionError(f"Failed to serialize {input} to readable JSON: {e}")


def to_bytes(serializer: skir.Serializer[T], input: T) -> bytes:
    try:
        return serializer.to_bytes(input)
    except Exception as e:
        raise AssertionError(f"Failed to serialize {input} to bytes: {e}")


def from_json_keep_unrecognized(serializer: skir.Serializer[T], json_code: str) -> T:
    try:
        return serializer.from_json_code(json_code, keep_unrecognized_values=True)
    except Exception as e:
        raise AssertionError(f"Failed to deserialize {json_code}: {e}")


def from_json_drop_unrecognized(serializer: skir.Serializer[T], json_code: str) -> T:
    try:
        return serializer.from_json_code(json_code)
    except Exception as e:
        raise AssertionError(f"Failed to deserialize {json_code}: {e}")


def from_bytes_drop_unrecognized_fields(
    serializer: skir.Serializer[T], data: bytes
) -> T:
    try:
        return serializer.from_bytes(data)
    except Exception as e:
        raise AssertionError(f"Failed to deserialize {data.hex()}: {e}")


def from_bytes_keep_unrecognized(serializer: skir.Serializer[T], data: bytes) -> T:
    try:
        return serializer.from_bytes(data, keep_unrecognized_values=True)
    except Exception as e:
        raise AssertionError(f"Failed to deserialize {data.hex()}: {e}")


if __name__ == "__main__":
    unittest.main()
