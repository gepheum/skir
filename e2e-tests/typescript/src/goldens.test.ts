import { describe } from "mocha";
import * as skir from "skir-client";
import {
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
  UNIT_TESTS,
} from "../skirout/@gepheum/skir-golden-tests/goldens.js";

class AssertionError {
  message = "";

  constructor(params: {
    actual?: unknown;
    expected?: unknown;
    message?: string;
  }) {
    this.message =
      (params.message ?? "") +
      "\n" +
      `Expected: ${JSON.stringify(params.expected)}\n` +
      `Actual: ${JSON.stringify(params.actual)}\n`;
  }

  addContext(context: string): void {
    this.message = this.message ? `${this.message}\n${context}` : context;
  }
}

describe("goldens", () => {
  for (let i = 0; i < UNIT_TESTS.length; ++i) {
    const unitTest = UNIT_TESTS[i]!;
    if (unitTest.testNumber !== UNIT_TESTS[0]!.testNumber + i) {
      throw new Error(
        `Test numbers are not sequential at test #${i}: ` +
          `found ${unitTest.testNumber}, ` +
          `expected ${UNIT_TESTS[0]!.testNumber + i}`,
      );
    }
    try {
      verifyAssertion(unitTest.assertion);
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(`While evaluating test #${unitTest.testNumber}`);
        console.error(e.message);
        console.error("\n\n");
      }
      throw e;
    }
  }
});

function verifyAssertion(assertion: Assertion): void {
  switch (assertion.union.kind) {
    case "bytes_equal": {
      const actual = evaluateBytes(assertion.union.value.actual).toBase16();
      const expected = evaluateBytes(assertion.union.value.expected).toBase16();
      if (actual !== expected) {
        throw new AssertionError({
          actual: "hex:" + actual,
          expected: "hex:" + expected,
        });
      }
      break;
    }
    case "bytes_in": {
      const actual = evaluateBytes(assertion.union.value.actual);
      const actualHex = actual.toBase16();
      const found = assertion.union.value.expected.some((expectedBytes) => {
        return expectedBytes.toBase16() === actualHex;
      });
      if (!found) {
        throw new AssertionError({
          actual: "hex:" + actualHex,
          expected: assertion.union.value.expected
            .map((b) => "hex:" + b.toBase16())
            .join(" or "),
        });
      }
      break;
    }
    case "string_equal": {
      const actual = evaluateString(assertion.union.value.actual);
      const expected = evaluateString(assertion.union.value.expected);
      if (actual !== expected) {
        throw new AssertionError({
          actual: actual,
          expected: expected,
          message: `Actual: ${JSON.stringify(actual)}`,
        });
      }
      break;
    }
    case "string_in": {
      const actual = evaluateString(assertion.union.value.actual);
      if (!assertion.union.value.expected.includes(actual)) {
        throw new AssertionError({
          actual: actual,
          expected: assertion.union.value.expected.join(" or "),
        });
      }
      break;
    }
    case "reserialize_value": {
      return reserializeValueAndVerify(assertion.union.value);
    }
    case "reserialize_large_string": {
      return reserializeLargeStringAndVerify(assertion.union.value);
    }
    case "reserialize_large_array": {
      return reserializeLargeArrayAndVerify(assertion.union.value);
    }
    case "enum_a_from_json_is_constant": {
      const value = assertion.union.value.keepUnrecognized
        ? fromJsonKeepUnrecognized(
            EnumA.serializer,
            evaluateString(assertion.union.value.actual),
          )
        : fromJsonDropUnrecognized(
            EnumA.serializer,
            evaluateString(assertion.union.value.actual),
          );
      if (value.union.kind !== "A") {
        throw new AssertionError({
          actual: value.union.kind,
          expected: "A",
        });
      }
      break;
    }
    case "enum_a_from_bytes_is_constant": {
      const value = assertion.union.value.keepUnrecognized
        ? fromBytesKeepUnrecognized(
            EnumA.serializer,
            evaluateBytes(assertion.union.value.actual),
          )
        : fromBytesDropUnrecognizedFields(
            EnumA.serializer,
            evaluateBytes(assertion.union.value.actual),
          );
      if (value.union.kind !== "A") {
        throw new AssertionError({
          actual: value.union.kind,
          expected: "A",
        });
      }
      break;
    }
    case "enum_b_from_json_is_wrapper_b": {
      const value = assertion.union.value.keepUnrecognized
        ? fromJsonKeepUnrecognized(
            EnumB.serializer,
            evaluateString(assertion.union.value.actual),
          )
        : fromJsonDropUnrecognized(
            EnumB.serializer,
            evaluateString(assertion.union.value.actual),
          );
      if (value.union.kind !== "b") {
        throw new AssertionError({
          actual: value.union.kind,
          expected: "b",
        });
      }
      if (value.union.value !== assertion.union.value.expected) {
        throw new AssertionError({
          actual: value.union.value,
          expected: assertion.union.value.expected,
        });
      }
      break;
    }
    case "enum_b_from_bytes_is_wrapper_b": {
      const value = assertion.union.value.keepUnrecognized
        ? fromBytesKeepUnrecognized(
            EnumB.serializer,
            evaluateBytes(assertion.union.value.actual),
          )
        : fromBytesDropUnrecognizedFields(
            EnumB.serializer,
            evaluateBytes(assertion.union.value.actual),
          );
      if (value.union.kind !== "b") {
        throw new AssertionError({
          actual: value.union.kind,
          expected: "b",
        });
      }
      if (value.union.value !== assertion.union.value.expected) {
        throw new AssertionError({
          actual: value.union.value,
          expected: assertion.union.value.expected,
        });
      }
      break;
    }
    case "UNKNOWN":
      throw new Error();
  }
}

function reserializeValueAndVerify(input: Assertion.ReserializeValue): void {
  const typedValues = [
    input.value,
    TypedValue.create({
      kind: "round_trip_dense_json",
      value: input.value,
    }),
    TypedValue.create({
      kind: "round_trip_readable_json",
      value: input.value,
    }),
    TypedValue.create({
      kind: "round_trip_bytes",
      value: input.value,
    }),
  ];
  for (const inputValue of typedValues) {
    try {
      // Verify bytes - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "bytes_in",
          value: {
            actual: BytesExpression.create({
              kind: "to_bytes",
              value: inputValue,
            }),
            expected: input.expectedBytes,
          },
        }),
      );

      // Verify dense JSON - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "string_in",
          value: {
            actual: StringExpression.create({
              kind: "to_dense_json",
              value: inputValue,
            }),
            expected: input.expectedDenseJson,
          },
        }),
      );

      // Verify readable JSON - check if actual matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "string_in",
          value: {
            actual: StringExpression.create({
              kind: "to_readable_json",
              value: inputValue,
            }),
            expected: input.expectedReadableJson,
          },
        }),
      );
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(`input value: ${inputValue}`);
      }
      throw e;
    }
  }

  // Make sure the encoded value can be skipped.
  for (const expectedBytes of input.expectedBytes) {
    const buffer = new ArrayBuffer(expectedBytes.byteLength + 2);
    const dataView = new DataView(buffer);
    const prefix = "skir";
    new TextEncoder().encodeInto(prefix, new Uint8Array(buffer, 0));
    dataView.setUint8(4, 248);
    new Uint8Array(buffer, 5).set(
      new Uint8Array(expectedBytes.toBuffer().slice(prefix.length)),
    );
    dataView.setUint8(expectedBytes.byteLength + 1, 1);
    const point = Point.serializer.fromBytes(buffer);
    if (point.x !== 1) {
      throw new AssertionError({
        message: `Failed to skip value: got point.x=${point.x}, expected 1; input: ${input}`,
      });
    }
  }

  const typedValue = evaluteTypedValue(input.value);
  for (const alternativeJson of input.alternativeJsons) {
    try {
      const roundTripJson = toDenseJson(
        typedValue.serializer,
        fromJsonKeepUnrecognized(
          typedValue.serializer,
          evaluateString(alternativeJson),
        ),
      );
      // Check if roundTripJson matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "string_in",
          value: {
            actual: StringExpression.create({
              kind: "literal",
              value: roundTripJson,
            }),
            expected: input.expectedDenseJson,
          },
        }),
      );
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(
          `while processing alternative JSON: ${evaluateString(alternativeJson)}`,
        );
      }
      throw e;
    }
  }
  for (const alternativeJson of input.expectedDenseJson.concat(
    input.expectedReadableJson,
  )) {
    try {
      const roundTripJson = toDenseJson(
        typedValue.serializer,
        fromJsonKeepUnrecognized(typedValue.serializer, alternativeJson),
      );
      // Check if roundTripJson matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "string_in",
          value: {
            actual: StringExpression.create({
              kind: "literal",
              value: roundTripJson,
            }),
            expected: input.expectedDenseJson,
          },
        }),
      );
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(`while processing alternative JSON: ${alternativeJson}`);
      }
      throw e;
    }
  }
  for (const alternativeBytes of input.alternativeBytes) {
    try {
      const roundTripBytes = toBytes(
        typedValue.serializer,
        fromBytesDropUnrecognizedFields(
          typedValue.serializer,
          evaluateBytes(alternativeBytes),
        ),
      );
      // Check if roundTripBytes matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "bytes_in",
          value: {
            actual: BytesExpression.create({
              kind: "literal",
              value: roundTripBytes,
            }),
            expected: input.expectedBytes,
          },
        }),
      );
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(
          `while processing alternative bytes: ${evaluateBytes(alternativeBytes).toBase16()}`,
        );
      }
      throw e;
    }
  }
  for (const alternativeBytes of input.expectedBytes) {
    try {
      const roundTripBytes = toBytes(
        typedValue.serializer,
        fromBytesDropUnrecognizedFields(
          typedValue.serializer,
          alternativeBytes,
        ),
      );
      // Check if roundTripBytes matches any of the expected values
      verifyAssertion(
        Assertion.create({
          kind: "bytes_in",
          value: {
            actual: BytesExpression.create({
              kind: "literal",
              value: roundTripBytes,
            }),
            expected: input.expectedBytes,
          },
        }),
      );
    } catch (e) {
      if (e instanceof AssertionError) {
        e.addContext(
          `while processing alternative bytes: ${alternativeBytes.toBase16()}`,
        );
      }
      throw e;
    }
  }
  if (input.expectedTypeDescriptor) {
    const actual = JSON.stringify(
      typedValue.serializer.typeDescriptor.asJson(),
      null,
      2,
    );
    verifyAssertion(
      Assertion.create({
        kind: "string_equal",
        value: {
          actual: {
            kind: "literal",
            value: actual,
          },
          expected: {
            kind: "literal",
            value: input.expectedTypeDescriptor,
          },
        },
      }),
    );
    verifyAssertion(
      Assertion.create({
        kind: "string_equal",
        value: {
          actual: {
            kind: "literal",
            value: JSON.stringify(
              skir
                .parseTypeDescriptorFromJsonCode(input.expectedTypeDescriptor)
                .asJson(),
              null,
              2,
            ),
          },
          expected: {
            kind: "literal",
            value: input.expectedTypeDescriptor,
          },
        },
      }),
    );
  }
}

function reserializeLargeStringAndVerify(
  input: Assertion.ReserializeLargeString,
): void {
  const str = "a".repeat(input.numChars);
  {
    const json = toDenseJson(skir.primitiveSerializer("string"), str);
    const roundTrip = fromJsonDropUnrecognized(
      skir.primitiveSerializer("string"),
      json,
    );
    if (roundTrip !== str) {
      throw new AssertionError({
        actual: roundTrip,
        expected: str,
      });
    }
  }
  {
    const json = toReadableJson(skir.primitiveSerializer("string"), str);
    const roundTrip = fromJsonDropUnrecognized(
      skir.primitiveSerializer("string"),
      json,
    );
    if (roundTrip !== str) {
      throw new AssertionError({
        actual: roundTrip,
        expected: str,
      });
    }
  }
  {
    const bytes = toBytes(skir.primitiveSerializer("string"), str);
    if (!bytes.toBase16().startsWith(input.expectedBytePrefix.toBase16())) {
      throw new AssertionError({
        actual: "hex:" + bytes.toBase16(),
        expected: "hex:" + input.expectedBytePrefix.toBase16() + "...",
      });
    }
    const roundTrip = fromBytesDropUnrecognizedFields(
      skir.primitiveSerializer("string"),
      bytes,
    );
    if (roundTrip !== str) {
      throw new AssertionError({
        actual: roundTrip,
        expected: str,
      });
    }
  }
}

function reserializeLargeArrayAndVerify(
  input: Assertion.ReserializeLargeArray,
): void {
  const array = Array<number>(input.numItems).fill(1);
  const serializer = skir.arraySerializer(skir.primitiveSerializer("int32"));
  const isArray = (arr: readonly number[]): boolean => {
    return arr.length === input.numItems && arr.every((v) => v === 1);
  };
  {
    const json = toDenseJson(serializer, array);
    const roundTrip = fromJsonDropUnrecognized(serializer, json);
    if (!isArray(roundTrip)) {
      throw new AssertionError({
        actual: roundTrip,
        expected: array,
      });
    }
  }
  {
    const json = toReadableJson(serializer, array);
    const roundTrip = fromJsonDropUnrecognized(serializer, json);
    if (!isArray(roundTrip)) {
      throw new AssertionError({
        actual: roundTrip,
        expected: array,
      });
    }
  }
  {
    const bytes = toBytes(serializer, array);
    if (!bytes.toBase16().startsWith(input.expectedBytePrefix.toBase16())) {
      throw new AssertionError({
        actual: "hex:" + bytes.toBase16(),
        expected: "hex:" + input.expectedBytePrefix.toBase16() + "...",
      });
    }
    const roundTrip = fromBytesDropUnrecognizedFields(serializer, bytes);
    if (!isArray(roundTrip)) {
      throw new AssertionError({
        actual: roundTrip,
        expected: array,
      });
    }
  }
}

function evaluateBytes(expr: BytesExpression): skir.ByteString {
  switch (expr.union.kind) {
    case "literal":
      return expr.union.value;
    case "to_bytes": {
      const literal = evaluteTypedValue(expr.union.value);
      return toBytes(literal.serializer, literal.value);
    }
    case "UNKNOWN":
      throw new Error();
  }
}

function evaluateString(expr: StringExpression): string {
  switch (expr.union.kind) {
    case "literal":
      return expr.union.value;
    case "to_dense_json": {
      const literal = evaluteTypedValue(expr.union.value);
      return toDenseJson(literal.serializer, literal.value);
    }
    case "to_readable_json": {
      const literal = evaluteTypedValue(expr.union.value);
      return toReadableJson(literal.serializer, literal.value);
    }
    case "UNKNOWN":
      throw new Error();
  }
}

interface TypedValueType<T> {
  value: T;
  serializer: skir.Serializer<T>;
}

function evaluteTypedValue<T>(literal: TypedValue): TypedValueType<unknown> {
  switch (literal.union.kind) {
    case "bool":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("bool"),
      };
    case "int32":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("int32"),
      };
    case "int64":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("int64"),
      };
    case "hash64":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("hash64"),
      };
    case "float32":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("float32"),
      };
    case "float64":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("float64"),
      };
    case "timestamp":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("timestamp"),
      };
    case "string":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("string"),
      };
    case "bytes":
      return {
        value: literal.union.value,
        serializer: skir.primitiveSerializer("bytes"),
      };
    case "bool_optional":
      return {
        value: literal.union.value,
        serializer: skir.optionalSerializer(skir.primitiveSerializer("bool")),
      };
    case "ints": {
      return {
        value: literal.union.value,
        serializer: skir.arraySerializer(skir.primitiveSerializer("int32")),
      };
    }
    case "point": {
      return {
        value: literal.union.value,
        serializer: Point.serializer,
      };
    }
    case "color": {
      return {
        value: literal.union.value,
        serializer: Color.serializer,
      };
    }
    case "my_enum": {
      return {
        value: literal.union.value,
        serializer: MyEnum.serializer,
      };
    }
    case "enum_a": {
      return {
        value: literal.union.value,
        serializer: EnumA.serializer,
      };
    }
    case "enum_b": {
      return {
        value: literal.union.value,
        serializer: EnumB.serializer,
      };
    }
    case "keyed_arrays": {
      return {
        value: literal.union.value,
        serializer: KeyedArrays.serializer,
      };
    }
    case "rec_struct": {
      return {
        value: literal.union.value,
        serializer: RecStruct.serializer,
      };
    }
    case "rec_enum": {
      return {
        value: literal.union.value,
        serializer: RecEnum.serializer,
      };
    }
    case "round_trip_dense_json": {
      const other = evaluteTypedValue(literal.union.value);
      return {
        value: fromJsonDropUnrecognized(
          other.serializer,
          toDenseJson(other.serializer, other.value),
        ),
        serializer: other.serializer,
      };
    }
    case "round_trip_readable_json": {
      const other = evaluteTypedValue(literal.union.value);
      return {
        value: fromJsonDropUnrecognized(
          other.serializer,
          toReadableJson(other.serializer, other.value),
        ),
        serializer: other.serializer,
      };
    }
    case "round_trip_bytes": {
      const other = evaluteTypedValue(literal.union.value);
      return {
        value: fromBytesDropUnrecognizedFields(
          other.serializer,
          toBytes(other.serializer, other.value),
        ),
        serializer: other.serializer,
      };
    }
    case "point_from_json_keep_unrecognized":
      return {
        value: fromJsonKeepUnrecognized(
          Point.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: Point.serializer,
      };
    case "point_from_json_drop_unrecognized":
      return {
        value: fromJsonDropUnrecognized(
          Point.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: Point.serializer,
      };
    case "point_from_bytes_keep_unrecognized":
      return {
        value: fromBytesKeepUnrecognized(
          Point.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: Point.serializer,
      };
    case "point_from_bytes_drop_unrecognized":
      return {
        value: fromBytesDropUnrecognizedFields(
          Point.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: Point.serializer,
      };
    case "color_from_json_keep_unrecognized":
      return {
        value: fromJsonKeepUnrecognized(
          Color.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: Color.serializer,
      };
    case "color_from_json_drop_unrecognized":
      return {
        value: fromJsonDropUnrecognized(
          Color.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: Color.serializer,
      };
    case "color_from_bytes_keep_unrecognized":
      return {
        value: fromBytesKeepUnrecognized(
          Color.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: Color.serializer,
      };
    case "color_from_bytes_drop_unrecognized":
      return {
        value: fromBytesDropUnrecognizedFields(
          Color.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: Color.serializer,
      };
    case "my_enum_from_json_keep_unrecognized":
      return {
        value: fromJsonKeepUnrecognized(
          MyEnum.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: MyEnum.serializer,
      };
    case "my_enum_from_json_drop_unrecognized":
      return {
        value: fromJsonDropUnrecognized(
          MyEnum.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: MyEnum.serializer,
      };
    case "my_enum_from_bytes_keep_unrecognized":
      return {
        value: fromBytesKeepUnrecognized(
          MyEnum.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: MyEnum.serializer,
      };
    case "my_enum_from_bytes_drop_unrecognized":
      return {
        value: fromBytesDropUnrecognizedFields(
          MyEnum.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: MyEnum.serializer,
      };
    case "enum_a_from_json_keep_unrecognized":
      return {
        value: fromJsonKeepUnrecognized(
          EnumA.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: EnumA.serializer,
      };
    case "enum_a_from_json_drop_unrecognized":
      return {
        value: fromJsonDropUnrecognized(
          EnumA.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: EnumA.serializer,
      };
    case "enum_a_from_bytes_keep_unrecognized":
      return {
        value: fromBytesKeepUnrecognized(
          EnumA.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: EnumA.serializer,
      };
    case "enum_a_from_bytes_drop_unrecognized":
      return {
        value: fromBytesDropUnrecognizedFields(
          EnumA.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: EnumA.serializer,
      };
    case "enum_b_from_json_keep_unrecognized":
      return {
        value: fromJsonKeepUnrecognized(
          EnumB.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: EnumB.serializer,
      };
    case "enum_b_from_json_drop_unrecognized":
      return {
        value: fromJsonDropUnrecognized(
          EnumB.serializer,
          evaluateString(literal.union.value),
        ),
        serializer: EnumB.serializer,
      };
    case "enum_b_from_bytes_keep_unrecognized":
      return {
        value: fromBytesKeepUnrecognized(
          EnumB.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: EnumB.serializer,
      };
    case "enum_b_from_bytes_drop_unrecognized":
      return {
        value: fromBytesDropUnrecognizedFields(
          EnumB.serializer,
          evaluateBytes(literal.union.value),
        ),
        serializer: EnumB.serializer,
      };
    case "UNKNOWN":
      throw new Error();
  }
}

function toDenseJson<T>(serializer: skir.Serializer<T>, input: T): string {
  try {
    return serializer.toJsonCode(input);
  } catch (e) {
    throw new Error(`Failed to serialize ${input} to dense JSON: ${e}`);
  }
}

function toReadableJson<T>(serializer: skir.Serializer<T>, input: T): string {
  try {
    return serializer.toJsonCode(input, "readable");
  } catch (e) {
    throw new Error(`Failed to serialize ${input} to readable JSON: ${e}`);
  }
}

function toBytes<T>(serializer: skir.Serializer<T>, input: T): skir.ByteString {
  try {
    return skir.ByteString.sliceOf(serializer.toBytes(input).toBuffer());
  } catch (e) {
    throw new Error(`Failed to serialize ${input} to bytes: ${e}`);
  }
}

function fromJsonKeepUnrecognized<T>(
  serializer: skir.Serializer<T>,
  json: string,
): T {
  try {
    return serializer.fromJsonCode(json, "keep-unrecognized-values");
  } catch (e) {
    throw new Error(`Failed to deserialize ${json}: ${e}`);
  }
}

function fromJsonDropUnrecognized<T>(
  serializer: skir.Serializer<T>,
  json: string,
): T {
  try {
    return serializer.fromJsonCode(json);
  } catch (e) {
    throw new Error(`Failed to deserialize ${json}: ${e}`);
  }
}

function fromBytesDropUnrecognizedFields<T>(
  serializer: skir.Serializer<T>,
  bytes: skir.ByteString,
): T {
  try {
    return serializer.fromBytes(bytes.toBuffer());
  } catch (e) {
    throw new Error(`Failed to deserialize ${bytes.toBase16()}: ${e}`);
  }
}

function fromBytesKeepUnrecognized<T>(
  serializer: skir.Serializer<T>,
  bytes: skir.ByteString,
): T {
  try {
    return serializer.fromBytes(bytes.toBuffer(), "keep-unrecognized-values");
  } catch (e) {
    throw new Error(`Failed to deserialize ${bytes.toBase16()}: ${e}`);
  }
}
