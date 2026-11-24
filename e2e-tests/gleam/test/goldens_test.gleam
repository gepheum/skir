import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import skir_client as skir_client_
import skir_client/type_descriptor
import skirout/gepheum/skir_golden_tests/goldens

// =============================================================================
// EvaluatedValue — type-erased bundle of a deserialised value and its serializer
// =============================================================================

type EvaluatedValue {
  EvaluatedValue(
    to_bytes: fn() -> BitArray,
    to_dense_json: fn() -> String,
    to_readable_json: fn() -> String,
    type_descriptor_json: fn() -> String,
    from_json_keep: fn(String) -> Result(EvaluatedValue, String),
    from_json_drop: fn(String) -> Result(EvaluatedValue, String),
    from_bytes_drop: fn(BitArray) -> Result(EvaluatedValue, String),
  )
}

fn make_ev(value: a, ser: skir_client_.Serializer(a)) -> EvaluatedValue {
  EvaluatedValue(
    to_bytes: fn() { skir_client_.to_bytes(ser, value) },
    to_dense_json: fn() { skir_client_.to_dense_json_code(ser, value) },
    to_readable_json: fn() { skir_client_.to_readable_json_code(ser, value) },
    type_descriptor_json: fn() {
      type_descriptor.type_descriptor_to_json(skir_client_.type_descriptor(ser))
    },
    from_json_keep: fn(json) {
      case
        skir_client_.from_json_code_with_options(
          ser,
          json,
          keep_unrecognized_values: True,
        )
      {
        Ok(v) -> Ok(make_ev(v, ser))
        Error(e) -> Error(e)
      }
    },
    from_json_drop: fn(json) {
      case skir_client_.from_json_code(ser, json) {
        Ok(v) -> Ok(make_ev(v, ser))
        Error(e) -> Error(e)
      }
    },
    from_bytes_drop: fn(bytes) {
      case skir_client_.from_bytes(ser, bytes) {
        Ok(v) -> Ok(make_ev(v, ser))
        Error(e) -> Error(e)
      }
    },
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn to_hex(bytes: BitArray) -> String {
  bit_array.base16_encode(bytes)
}

fn starts_with(bytes: BitArray, prefix: BitArray) -> Bool {
  let prefix_size = bit_array.byte_size(prefix)
  case bit_array.slice(bytes, 0, prefix_size) {
    Ok(head) -> head == prefix
    Error(_) -> False
  }
}

fn join_or(items: List(String)) -> String {
  string.join(items, " or ")
}

// =============================================================================
// Expression evaluators
// =============================================================================

fn evaluate_bytes(expr: goldens.BytesExpression) -> Result(BitArray, String) {
  case expr {
    goldens.BytesExpressionLiteral(b) -> Ok(b)
    goldens.BytesExpressionToBytes(tv) -> {
      use ev <- result.try(evaluate_typed_value(tv))
      Ok(ev.to_bytes())
    }
    goldens.BytesExpressionUnknown(_) ->
      Error("unknown BytesExpression variant")
  }
}

fn evaluate_string(expr: goldens.StringExpression) -> Result(String, String) {
  case expr {
    goldens.StringExpressionLiteral(s) -> Ok(s)
    goldens.StringExpressionToDenseJson(tv) -> {
      use ev <- result.try(evaluate_typed_value(tv))
      Ok(ev.to_dense_json())
    }
    goldens.StringExpressionToReadableJson(tv) -> {
      use ev <- result.try(evaluate_typed_value(tv))
      Ok(ev.to_readable_json())
    }
    goldens.StringExpressionUnknown(_) ->
      Error("unknown StringExpression variant")
  }
}

fn evaluate_typed_value(
  tv: goldens.TypedValue,
) -> Result(EvaluatedValue, String) {
  case tv {
    goldens.TypedValueUnknown(_) -> Error("unknown TypedValue variant")
    goldens.TypedValueBool(v) -> Ok(make_ev(v, skir_client_.bool_serializer()))
    goldens.TypedValueInt32(v) ->
      Ok(make_ev(v, skir_client_.int32_serializer()))
    goldens.TypedValueInt64(v) ->
      Ok(make_ev(v, skir_client_.int64_serializer()))
    goldens.TypedValueHash64(v) ->
      Ok(make_ev(v, skir_client_.hash64_serializer()))
    goldens.TypedValueFloat32(v) ->
      Ok(make_ev(v, skir_client_.float32_serializer()))
    goldens.TypedValueFloat64(v) ->
      Ok(make_ev(v, skir_client_.float64_serializer()))
    goldens.TypedValueTimestamp(v) ->
      Ok(make_ev(v, skir_client_.timestamp_serializer()))
    goldens.TypedValueString(v) ->
      Ok(make_ev(v, skir_client_.string_serializer()))
    goldens.TypedValueBytes(v) ->
      Ok(make_ev(v, skir_client_.bytes_serializer()))
    goldens.TypedValueBoolOptional(v) ->
      Ok(make_ev(
        v,
        skir_client_.optional_serializer(skir_client_.bool_serializer()),
      ))
    goldens.TypedValueInts(v) ->
      Ok(make_ev(
        v,
        skir_client_.list_serializer(skir_client_.int32_serializer()),
      ))
    goldens.TypedValuePoint(v) -> Ok(make_ev(v, goldens.point_serializer()))
    goldens.TypedValueColor(v) -> Ok(make_ev(v, goldens.color_serializer()))
    goldens.TypedValueMyEnum(v) -> Ok(make_ev(v, goldens.my_enum_serializer()))
    goldens.TypedValueEnumA(v) -> Ok(make_ev(v, goldens.enum_a_serializer()))
    goldens.TypedValueEnumB(v) -> Ok(make_ev(v, goldens.enum_b_serializer()))
    goldens.TypedValueKeyedArrays(v) ->
      Ok(make_ev(v, goldens.keyed_arrays_serializer()))
    goldens.TypedValueRecStruct(v) ->
      Ok(make_ev(v, goldens.rec_struct_serializer()))
    goldens.TypedValueRecEnum(v) ->
      Ok(make_ev(v, goldens.rec_enum_serializer()))
    goldens.TypedValueRoundTripDenseJson(inner) -> {
      use ev <- result.try(evaluate_typed_value(inner))
      ev.from_json_drop(ev.to_dense_json())
    }
    goldens.TypedValueRoundTripReadableJson(inner) -> {
      use ev <- result.try(evaluate_typed_value(inner))
      ev.from_json_drop(ev.to_readable_json())
    }
    goldens.TypedValueRoundTripBytes(inner) -> {
      use ev <- result.try(evaluate_typed_value(inner))
      ev.from_bytes_drop(ev.to_bytes())
    }
    goldens.TypedValuePointFromJsonKeepUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code_with_options(
        goldens.point_serializer(),
        json,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.point_serializer()) })
      |> result.map_error(fn(e) { "PointFromJsonKeepUnrecognized: " <> e })
    }
    goldens.TypedValuePointFromJsonDropUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code(goldens.point_serializer(), json)
      |> result.map(fn(v) { make_ev(v, goldens.point_serializer()) })
      |> result.map_error(fn(e) { "PointFromJsonDropUnrecognized: " <> e })
    }
    goldens.TypedValuePointFromBytesKeepUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes_with_options(
        goldens.point_serializer(),
        bytes,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.point_serializer()) })
      |> result.map_error(fn(e) { "PointFromBytesKeepUnrecognized: " <> e })
    }
    goldens.TypedValuePointFromBytesDropUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes(goldens.point_serializer(), bytes)
      |> result.map(fn(v) { make_ev(v, goldens.point_serializer()) })
      |> result.map_error(fn(e) { "PointFromBytesDropUnrecognized: " <> e })
    }
    goldens.TypedValueColorFromJsonKeepUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code_with_options(
        goldens.color_serializer(),
        json,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.color_serializer()) })
      |> result.map_error(fn(e) { "ColorFromJsonKeepUnrecognized: " <> e })
    }
    goldens.TypedValueColorFromJsonDropUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code(goldens.color_serializer(), json)
      |> result.map(fn(v) { make_ev(v, goldens.color_serializer()) })
      |> result.map_error(fn(e) { "ColorFromJsonDropUnrecognized: " <> e })
    }
    goldens.TypedValueColorFromBytesKeepUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes_with_options(
        goldens.color_serializer(),
        bytes,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.color_serializer()) })
      |> result.map_error(fn(e) { "ColorFromBytesKeepUnrecognized: " <> e })
    }
    goldens.TypedValueColorFromBytesDropUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes(goldens.color_serializer(), bytes)
      |> result.map(fn(v) { make_ev(v, goldens.color_serializer()) })
      |> result.map_error(fn(e) { "ColorFromBytesDropUnrecognized: " <> e })
    }
    goldens.TypedValueMyEnumFromJsonKeepUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code_with_options(
        goldens.my_enum_serializer(),
        json,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.my_enum_serializer()) })
      |> result.map_error(fn(e) { "MyEnumFromJsonKeepUnrecognized: " <> e })
    }
    goldens.TypedValueMyEnumFromJsonDropUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code(goldens.my_enum_serializer(), json)
      |> result.map(fn(v) { make_ev(v, goldens.my_enum_serializer()) })
      |> result.map_error(fn(e) { "MyEnumFromJsonDropUnrecognized: " <> e })
    }
    goldens.TypedValueMyEnumFromBytesKeepUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes_with_options(
        goldens.my_enum_serializer(),
        bytes,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.my_enum_serializer()) })
      |> result.map_error(fn(e) { "MyEnumFromBytesKeepUnrecognized: " <> e })
    }
    goldens.TypedValueMyEnumFromBytesDropUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes(goldens.my_enum_serializer(), bytes)
      |> result.map(fn(v) { make_ev(v, goldens.my_enum_serializer()) })
      |> result.map_error(fn(e) { "MyEnumFromBytesDropUnrecognized: " <> e })
    }
    goldens.TypedValueEnumAFromJsonKeepUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code_with_options(
        goldens.enum_a_serializer(),
        json,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.enum_a_serializer()) })
      |> result.map_error(fn(e) { "EnumAFromJsonKeepUnrecognized: " <> e })
    }
    goldens.TypedValueEnumAFromJsonDropUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code(goldens.enum_a_serializer(), json)
      |> result.map(fn(v) { make_ev(v, goldens.enum_a_serializer()) })
      |> result.map_error(fn(e) { "EnumAFromJsonDropUnrecognized: " <> e })
    }
    goldens.TypedValueEnumAFromBytesKeepUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes_with_options(
        goldens.enum_a_serializer(),
        bytes,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.enum_a_serializer()) })
      |> result.map_error(fn(e) { "EnumAFromBytesKeepUnrecognized: " <> e })
    }
    goldens.TypedValueEnumAFromBytesDropUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes(goldens.enum_a_serializer(), bytes)
      |> result.map(fn(v) { make_ev(v, goldens.enum_a_serializer()) })
      |> result.map_error(fn(e) { "EnumAFromBytesDropUnrecognized: " <> e })
    }
    goldens.TypedValueEnumBFromJsonKeepUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code_with_options(
        goldens.enum_b_serializer(),
        json,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.enum_b_serializer()) })
      |> result.map_error(fn(e) { "EnumBFromJsonKeepUnrecognized: " <> e })
    }
    goldens.TypedValueEnumBFromJsonDropUnrecognized(expr) -> {
      use json <- result.try(evaluate_string(expr))
      skir_client_.from_json_code(goldens.enum_b_serializer(), json)
      |> result.map(fn(v) { make_ev(v, goldens.enum_b_serializer()) })
      |> result.map_error(fn(e) { "EnumBFromJsonDropUnrecognized: " <> e })
    }
    goldens.TypedValueEnumBFromBytesKeepUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes_with_options(
        goldens.enum_b_serializer(),
        bytes,
        keep_unrecognized_values: True,
      )
      |> result.map(fn(v) { make_ev(v, goldens.enum_b_serializer()) })
      |> result.map_error(fn(e) { "EnumBFromBytesKeepUnrecognized: " <> e })
    }
    goldens.TypedValueEnumBFromBytesDropUnrecognized(expr) -> {
      use bytes <- result.try(evaluate_bytes(expr))
      skir_client_.from_bytes(goldens.enum_b_serializer(), bytes)
      |> result.map(fn(v) { make_ev(v, goldens.enum_b_serializer()) })
      |> result.map_error(fn(e) { "EnumBFromBytesDropUnrecognized: " <> e })
    }
  }
}

// =============================================================================
// Assertion verifiers
// =============================================================================

fn verify_assertion(assertion: goldens.Assertion) -> Result(Nil, String) {
  case assertion {
    goldens.AssertionUnknown(_) -> Error("unknown Assertion variant")
    goldens.AssertionBytesEqualX(a) -> verify_bytes_equal(a)
    goldens.AssertionBytesInX(a) -> verify_bytes_in(a)
    goldens.AssertionStringEqualX(a) -> verify_string_equal(a)
    goldens.AssertionStringInX(a) -> verify_string_in(a)
    goldens.AssertionReserializeValueX(a) -> verify_reserialize_value(a)
    goldens.AssertionReserializeLargeStringX(a) ->
      verify_reserialize_large_string(a)
    goldens.AssertionReserializeLargeArrayX(a) ->
      verify_reserialize_large_array(a)
    goldens.AssertionEnumAFromJsonIsConstantX(a) ->
      verify_enum_a_from_json_is_constant(a)
    goldens.AssertionEnumAFromBytesIsConstantX(a) ->
      verify_enum_a_from_bytes_is_constant(a)
    goldens.AssertionEnumBFromJsonIsWrapperBX(a) ->
      verify_enum_b_from_json_is_wrapper_b(a)
    goldens.AssertionEnumBFromBytesIsWrapperBX(a) ->
      verify_enum_b_from_bytes_is_wrapper_b(a)
  }
}

fn verify_bytes_equal(a: goldens.AssertionBytesEqual) -> Result(Nil, String) {
  use actual <- result.try(evaluate_bytes(a.actual))
  use expected <- result.try(evaluate_bytes(a.expected))
  case actual == expected {
    True -> Ok(Nil)
    False ->
      Error(
        "bytes mismatch\n  actual:   hex:"
        <> to_hex(actual)
        <> "\n  expected: hex:"
        <> to_hex(expected),
      )
  }
}

fn verify_bytes_in(a: goldens.AssertionBytesIn) -> Result(Nil, String) {
  use actual <- result.try(evaluate_bytes(a.actual))
  case list.any(a.expected, fn(exp) { exp == actual }) {
    True -> Ok(Nil)
    False -> {
      let expected_hex =
        list.map(a.expected, fn(b) { "hex:" <> to_hex(b) })
        |> join_or
      Error(
        "bytes not in expected set\n  actual:   hex:"
        <> to_hex(actual)
        <> "\n  expected: "
        <> expected_hex,
      )
    }
  }
}

fn verify_string_equal(a: goldens.AssertionStringEqual) -> Result(Nil, String) {
  use actual <- result.try(evaluate_string(a.actual))
  use expected <- result.try(evaluate_string(a.expected))
  case actual == expected {
    True -> Ok(Nil)
    False ->
      Error(
        "string mismatch\n  actual:   "
        <> string.inspect(actual)
        <> "\n  expected: "
        <> string.inspect(expected),
      )
  }
}

fn verify_string_in(a: goldens.AssertionStringIn) -> Result(Nil, String) {
  use actual <- result.try(evaluate_string(a.actual))
  case list.contains(a.expected, actual) {
    True -> Ok(Nil)
    False -> {
      let expected_list =
        list.map(a.expected, fn(s) { string.inspect(s) })
        |> join_or
      Error(
        "string not in expected set\n  actual:   "
        <> string.inspect(actual)
        <> "\n  expected: "
        <> expected_list,
      )
    }
  }
}

fn verify_reserialize_value(
  input: goldens.AssertionReserializeValue,
) -> Result(Nil, String) {
  // Build the 4 input values: original + 3 round-trip variants
  let round_trips = [
    goldens.TypedValueRoundTripDenseJson(input.value),
    goldens.TypedValueRoundTripReadableJson(input.value),
    goldens.TypedValueRoundTripBytes(input.value),
  ]
  let all_values = [input.value, ..round_trips]

  // Verify each of the 4 variants
  use _ <- result.try(
    list.fold_until(all_values, Ok(Nil), fn(_, tv) {
      case verify_reserialize_one(tv, input) {
        Ok(_) -> list.Continue(Ok(Nil))
        Error(e) ->
          list.Stop(Error(e <> "\n  (while evaluating round-trip variant)"))
      }
    }),
  )

  // Verify that encoded values can be skipped during decoding.
  // Build: "skir" + 0xF8 + expected_bytes[4:] + 0x01
  // The 0x01 encodes x=1 for Point (field 0, small positive varint).
  // After decoding as Point, x must equal 1 (skipped the embedded value).
  use _ <- result.try(
    list.fold_until(input.expected_bytes, Ok(Nil), fn(_, expected_bytes) {
      let payload_size = bit_array.byte_size(expected_bytes) - 4
      case bit_array.slice(expected_bytes, 4, payload_size) {
        Error(_) ->
          list.Stop(Error("skip-value test: expected_bytes too short"))
        Ok(payload) -> {
          let buf =
            bit_array.append(
              bit_array.append(<<"skir">>, <<248>>),
              bit_array.append(payload, <<1>>),
            )
          case
            skir_client_.from_bytes_with_options(
              goldens.point_serializer(),
              buf,
              keep_unrecognized_values: False,
            )
          {
            Error(e) ->
              list.Stop(Error("skip-value test failed to parse Point: " <> e))
            Ok(point) ->
              case point.x == 1 {
                True -> list.Continue(Ok(Nil))
                False ->
                  list.Stop(Error(
                    "skip-value test: expected point.x == 1, got "
                    <> int.to_string(point.x),
                  ))
              }
          }
        }
      }
    }),
  )

  // Get the canonical evaluated value for round-trip tests
  use typed_ev <- result.try(evaluate_typed_value(input.value))

  // Round-trip alternative JSONs through the canonical serializer (keep)
  use _ <- result.try(
    list.fold_until(input.alternative_jsons, Ok(Nil), fn(_, alt_json_expr) {
      case evaluate_string(alt_json_expr) {
        Error(e) -> list.Stop(Error(e))
        Ok(alt_json) ->
          case typed_ev.from_json_keep(alt_json) {
            Error(e) ->
              list.Stop(Error(
                e
                <> "\n  (while processing alternative JSON: "
                <> string.inspect(alt_json)
                <> ")",
              ))
            Ok(round_tripped) -> {
              let round_trip_json = round_tripped.to_dense_json()
              case list.contains(input.expected_dense_json, round_trip_json) {
                True -> list.Continue(Ok(Nil))
                False -> {
                  let expected_list =
                    list.map(input.expected_dense_json, fn(s) {
                      string.inspect(s)
                    })
                    |> join_or
                  list.Stop(Error(
                    "alternative JSON round-trip mismatch\n  got: "
                    <> string.inspect(round_trip_json)
                    <> "\n  expected: "
                    <> expected_list
                    <> "\n  (while processing alternative JSON: "
                    <> string.inspect(alt_json)
                    <> ")",
                  ))
                }
              }
            }
          }
      }
    }),
  )

  // Round-trip expected dense and readable JSONs (keep)
  let all_expected_jsons =
    list.append(input.expected_dense_json, input.expected_readable_json)
  use _ <- result.try(
    list.fold_until(all_expected_jsons, Ok(Nil), fn(_, alt_json) {
      case typed_ev.from_json_keep(alt_json) {
        Error(e) ->
          list.Stop(Error(
            e
            <> "\n  (while processing expected JSON: "
            <> string.inspect(alt_json)
            <> ")",
          ))
        Ok(round_tripped) -> {
          let round_trip_json = round_tripped.to_dense_json()
          case list.contains(input.expected_dense_json, round_trip_json) {
            True -> list.Continue(Ok(Nil))
            False -> {
              let expected_list =
                list.map(input.expected_dense_json, fn(s) { string.inspect(s) })
                |> join_or
              list.Stop(Error(
                "expected JSON round-trip mismatch\n  got: "
                <> string.inspect(round_trip_json)
                <> "\n  expected: "
                <> expected_list
                <> "\n  (while processing expected JSON: "
                <> string.inspect(alt_json)
                <> ")",
              ))
            }
          }
        }
      }
    }),
  )

  // Round-trip alternative bytes (drop)
  use _ <- result.try(
    list.fold_until(input.alternative_bytes, Ok(Nil), fn(_, alt_bytes_expr) {
      case evaluate_bytes(alt_bytes_expr) {
        Error(e) -> list.Stop(Error(e))
        Ok(alt_bytes) ->
          case typed_ev.from_bytes_drop(alt_bytes) {
            Error(e) ->
              list.Stop(Error(
                e
                <> "\n  (while processing alternative bytes: hex:"
                <> to_hex(alt_bytes)
                <> ")",
              ))
            Ok(round_tripped) -> {
              let round_trip_bytes = round_tripped.to_bytes()
              case
                list.any(input.expected_bytes, fn(exp) {
                  exp == round_trip_bytes
                })
              {
                True -> list.Continue(Ok(Nil))
                False -> {
                  let expected_hex =
                    list.map(input.expected_bytes, fn(b) { "hex:" <> to_hex(b) })
                    |> join_or
                  list.Stop(Error(
                    "alternative bytes round-trip mismatch\n  got:      hex:"
                    <> to_hex(round_trip_bytes)
                    <> "\n  expected: "
                    <> expected_hex
                    <> "\n  (while processing alternative bytes: hex:"
                    <> to_hex(alt_bytes)
                    <> ")",
                  ))
                }
              }
            }
          }
      }
    }),
  )

  // Round-trip expected bytes (drop)
  use _ <- result.try(
    list.fold_until(input.expected_bytes, Ok(Nil), fn(_, alt_bytes) {
      case typed_ev.from_bytes_drop(alt_bytes) {
        Error(e) ->
          list.Stop(Error(
            e
            <> "\n  (while processing expected bytes: hex:"
            <> to_hex(alt_bytes)
            <> ")",
          ))
        Ok(round_tripped) -> {
          let round_trip_bytes = round_tripped.to_bytes()
          case
            list.any(input.expected_bytes, fn(exp) { exp == round_trip_bytes })
          {
            True -> list.Continue(Ok(Nil))
            False -> {
              let expected_hex =
                list.map(input.expected_bytes, fn(b) { "hex:" <> to_hex(b) })
                |> join_or
              list.Stop(Error(
                "expected bytes round-trip mismatch\n  got:      hex:"
                <> to_hex(round_trip_bytes)
                <> "\n  expected: "
                <> expected_hex
                <> "\n  (while processing expected bytes: hex:"
                <> to_hex(alt_bytes)
                <> ")",
              ))
            }
          }
        }
      }
    }),
  )

  // Type descriptor check
  case input.expected_type_descriptor {
    option.None -> Ok(Nil)
    option.Some(expected_td) -> {
      let actual_td = typed_ev.type_descriptor_json()
      case actual_td == expected_td {
        False ->
          Error(
            "type descriptor mismatch\n  actual:   "
            <> string.inspect(actual_td)
            <> "\n  expected: "
            <> string.inspect(expected_td),
          )
        True ->
          // Also round-trip the type descriptor itself
          case type_descriptor.type_descriptor_from_json(expected_td) {
            Error(e) -> Error("failed to parse type descriptor: " <> e)
            Ok(parsed) -> {
              let reparsed_td = type_descriptor.type_descriptor_to_json(parsed)
              case reparsed_td == expected_td {
                True -> Ok(Nil)
                False ->
                  Error(
                    "type descriptor round-trip mismatch\n  actual:   "
                    <> string.inspect(reparsed_td)
                    <> "\n  expected: "
                    <> string.inspect(expected_td),
                  )
              }
            }
          }
      }
    }
  }
}

fn verify_reserialize_one(
  tv: goldens.TypedValue,
  input: goldens.AssertionReserializeValue,
) -> Result(Nil, String) {
  use ev <- result.try(evaluate_typed_value(tv))

  // Verify bytes
  let actual_bytes = ev.to_bytes()
  use _ <- result.try(
    case list.any(input.expected_bytes, fn(exp) { exp == actual_bytes }) {
      True -> Ok(Nil)
      False -> {
        let expected_hex =
          list.map(input.expected_bytes, fn(b) { "hex:" <> to_hex(b) })
          |> join_or
        Error(
          "bytes not in expected set\n  actual:   hex:"
          <> to_hex(actual_bytes)
          <> "\n  expected: "
          <> expected_hex,
        )
      }
    },
  )

  // Verify dense JSON
  let dense_json = ev.to_dense_json()
  use _ <- result.try(
    case list.contains(input.expected_dense_json, dense_json) {
      True -> Ok(Nil)
      False -> {
        let expected_list =
          list.map(input.expected_dense_json, fn(s) { string.inspect(s) })
          |> join_or
        Error(
          "dense JSON not in expected set\n  actual:   "
          <> string.inspect(dense_json)
          <> "\n  expected: "
          <> expected_list,
        )
      }
    },
  )

  // Verify readable JSON
  let readable_json = ev.to_readable_json()
  case list.contains(input.expected_readable_json, readable_json) {
    True -> Ok(Nil)
    False -> {
      let expected_list =
        list.map(input.expected_readable_json, fn(s) { string.inspect(s) })
        |> join_or
      Error(
        "readable JSON not in expected set\n  actual:   "
        <> string.inspect(readable_json)
        <> "\n  expected: "
        <> expected_list,
      )
    }
  }
}

fn verify_reserialize_large_string(
  input: goldens.AssertionReserializeLargeString,
) -> Result(Nil, String) {
  let s = string.repeat("a", input.num_chars)
  let ser = skir_client_.string_serializer()

  // Dense JSON round-trip
  use _ <- result.try({
    let json = skir_client_.to_dense_json_code(ser, s)
    case skir_client_.from_json_code(ser, json) {
      Error(e) -> Error("large string dense JSON round-trip: " <> e)
      Ok(round_trip) ->
        case round_trip == s {
          True -> Ok(Nil)
          False ->
            Error(
              "large string dense JSON round-trip mismatch\n  actual len: "
              <> int.to_string(string.length(round_trip))
              <> "\n  expected len: "
              <> int.to_string(string.length(s)),
            )
        }
    }
  })

  // Readable JSON round-trip
  use _ <- result.try({
    let json = skir_client_.to_readable_json_code(ser, s)
    case skir_client_.from_json_code(ser, json) {
      Error(e) -> Error("large string readable JSON round-trip: " <> e)
      Ok(round_trip) ->
        case round_trip == s {
          True -> Ok(Nil)
          False ->
            Error(
              "large string readable JSON round-trip mismatch\n  actual len: "
              <> int.to_string(string.length(round_trip))
              <> "\n  expected len: "
              <> int.to_string(string.length(s)),
            )
        }
    }
  })

  // Binary round-trip + prefix check
  let bytes = skir_client_.to_bytes(ser, s)
  let prefix = input.expected_byte_prefix
  use _ <- result.try(case starts_with(bytes, prefix) {
    True -> Ok(Nil)
    False -> {
      let shown_size =
        bit_array.byte_size(bytes) |> int.min(bit_array.byte_size(prefix) + 8)
      let shown = bit_array.slice(bytes, 0, shown_size) |> result.unwrap(<<>>)
      Error(
        "large string byte prefix mismatch\n  actual:          hex:"
        <> to_hex(shown)
        <> "...\n  expected prefix: hex:"
        <> to_hex(prefix),
      )
    }
  })
  case skir_client_.from_bytes(ser, bytes) {
    Error(e) -> Error("large string bytes round-trip: " <> e)
    Ok(round_trip) ->
      case round_trip == s {
        True -> Ok(Nil)
        False ->
          Error(
            "large string bytes round-trip mismatch\n  actual len: "
            <> int.to_string(string.length(round_trip))
            <> "\n  expected len: "
            <> int.to_string(string.length(s)),
          )
      }
  }
}

fn verify_reserialize_large_array(
  input: goldens.AssertionReserializeLargeArray,
) -> Result(Nil, String) {
  let n = input.num_items
  let array = list.repeat(1, n)
  let ser = skir_client_.list_serializer(skir_client_.int32_serializer())
  let is_correct = fn(v: List(Int)) -> Bool {
    list.length(v) == n && list.all(v, fn(x) { x == 1 })
  }

  // Dense JSON round-trip
  use _ <- result.try({
    let json = skir_client_.to_dense_json_code(ser, array)
    case skir_client_.from_json_code(ser, json) {
      Error(e) -> Error("large array dense JSON round-trip: " <> e)
      Ok(round_trip) ->
        case is_correct(round_trip) {
          True -> Ok(Nil)
          False ->
            Error(
              "large array dense JSON round-trip mismatch (len="
              <> int.to_string(list.length(round_trip))
              <> ", all_ones="
              <> string.inspect(list.all(round_trip, fn(x) { x == 1 }))
              <> ")",
            )
        }
    }
  })

  // Readable JSON round-trip
  use _ <- result.try({
    let json = skir_client_.to_readable_json_code(ser, array)
    case skir_client_.from_json_code(ser, json) {
      Error(e) -> Error("large array readable JSON round-trip: " <> e)
      Ok(round_trip) ->
        case is_correct(round_trip) {
          True -> Ok(Nil)
          False ->
            Error(
              "large array readable JSON round-trip mismatch (len="
              <> int.to_string(list.length(round_trip))
              <> ", all_ones="
              <> string.inspect(list.all(round_trip, fn(x) { x == 1 }))
              <> ")",
            )
        }
    }
  })

  // Binary round-trip + prefix check
  let bytes = skir_client_.to_bytes(ser, array)
  let prefix = input.expected_byte_prefix
  use _ <- result.try(case starts_with(bytes, prefix) {
    True -> Ok(Nil)
    False -> {
      let shown_size =
        bit_array.byte_size(bytes) |> int.min(bit_array.byte_size(prefix) + 8)
      let shown = bit_array.slice(bytes, 0, shown_size) |> result.unwrap(<<>>)
      Error(
        "large array byte prefix mismatch\n  actual:          hex:"
        <> to_hex(shown)
        <> "...\n  expected prefix: hex:"
        <> to_hex(prefix),
      )
    }
  })
  case skir_client_.from_bytes(ser, bytes) {
    Error(e) -> Error("large array bytes round-trip: " <> e)
    Ok(round_trip) ->
      case is_correct(round_trip) {
        True -> Ok(Nil)
        False ->
          Error(
            "large array bytes round-trip mismatch (len="
            <> int.to_string(list.length(round_trip))
            <> ", all_ones="
            <> string.inspect(list.all(round_trip, fn(x) { x == 1 }))
            <> ")",
          )
      }
  }
}

fn verify_enum_a_from_json_is_constant(
  a: goldens.AssertionEnumAFromJsonIsConstant,
) -> Result(Nil, String) {
  use actual <- result.try(evaluate_string(a.actual))
  case
    skir_client_.from_json_code_with_options(
      goldens.enum_a_serializer(),
      actual,
      keep_unrecognized_values: a.keep_unrecognized,
    )
  {
    Error(e) -> Error("enum_a_from_json_is_constant parse error: " <> e)
    Ok(value) ->
      case value {
        goldens.EnumAA -> Ok(Nil)
        _ ->
          Error(
            "enum_a_from_json_is_constant mismatch\n  actual json: "
            <> string.inspect(actual)
            <> "\n  expected: EnumAA",
          )
      }
  }
}

fn verify_enum_a_from_bytes_is_constant(
  a: goldens.AssertionEnumAFromBytesIsConstant,
) -> Result(Nil, String) {
  use actual <- result.try(evaluate_bytes(a.actual))
  case
    skir_client_.from_bytes_with_options(
      goldens.enum_a_serializer(),
      actual,
      keep_unrecognized_values: a.keep_unrecognized,
    )
  {
    Error(e) -> Error("enum_a_from_bytes_is_constant parse error: " <> e)
    Ok(value) ->
      case value {
        goldens.EnumAA -> Ok(Nil)
        _ ->
          Error(
            "enum_a_from_bytes_is_constant mismatch\n  actual bytes: hex:"
            <> to_hex(actual)
            <> "\n  expected: EnumAA",
          )
      }
  }
}

fn verify_enum_b_from_json_is_wrapper_b(
  a: goldens.AssertionEnumBFromJsonIsWrapperB,
) -> Result(Nil, String) {
  use actual <- result.try(evaluate_string(a.actual))
  case
    skir_client_.from_json_code_with_options(
      goldens.enum_b_serializer(),
      actual,
      keep_unrecognized_values: a.keep_unrecognized,
    )
  {
    Error(e) -> Error("enum_b_from_json_is_wrapper_b parse error: " <> e)
    Ok(value) ->
      case value {
        goldens.EnumBB(v) if v == a.expected -> Ok(Nil)
        _ ->
          Error(
            "enum_b_from_json_is_wrapper_b mismatch\n  actual json: "
            <> string.inspect(actual)
            <> "\n  expected: EnumBB("
            <> string.inspect(a.expected)
            <> ")",
          )
      }
  }
}

fn verify_enum_b_from_bytes_is_wrapper_b(
  a: goldens.AssertionEnumBFromBytesIsWrapperB,
) -> Result(Nil, String) {
  use actual <- result.try(evaluate_bytes(a.actual))
  case
    skir_client_.from_bytes_with_options(
      goldens.enum_b_serializer(),
      actual,
      keep_unrecognized_values: a.keep_unrecognized,
    )
  {
    Error(e) -> Error("enum_b_from_bytes_is_wrapper_b parse error: " <> e)
    Ok(value) ->
      case value {
        goldens.EnumBB(v) if v == a.expected -> Ok(Nil)
        _ ->
          Error(
            "enum_b_from_bytes_is_wrapper_b mismatch\n  actual bytes: hex:"
            <> to_hex(actual)
            <> "\n  expected: EnumBB("
            <> string.inspect(a.expected)
            <> ")",
          )
      }
  }
}

// =============================================================================
// Test entry point
// =============================================================================

pub fn run_golden_tests_test() {
  let unit_tests = goldens.unit_tests_const

  // Verify the list is non-empty
  let assert [first, ..] = unit_tests

  // Verify test numbers are sequential
  list.index_fold(unit_tests, Nil, fn(_, ut, i) {
    ut.test_number
    |> should.equal(first.test_number + i)
  })

  // Run each test, collect failures
  let failures =
    list.filter_map(unit_tests, fn(ut) {
      // Tests 1082 and 1083 test float Infinity/-Infinity round-tripping, which
      // is not possible on Erlang (IEEE infinity is not representable). Skip.
      case ut.test_number == 1082 || ut.test_number == 1083 {
        True -> Error(Nil)
        False ->
          case verify_assertion(ut.assertion) {
            Ok(_) -> Error(Nil)
            Error(msg) ->
              Ok(#(
                ut.test_number,
                "Test #" <> int.to_string(ut.test_number) <> ": " <> msg,
              ))
          }
      }
    })

  case failures {
    [] -> Nil
    _ -> {
      let msg =
        list.map(failures, fn(f) { f.1 })
        |> string.join("\n\n")
      panic as {
        int.to_string(list.length(failures))
        <> " golden test(s) failed:\n\n"
        <> msg
      }
    }
  }
}
