import gleam/option.{None, Some}
import gleeunit/should
import skir_client/serializer
import skir_client/serializers
import skir_client/timestamp
import skir_client/type_descriptor

// =============================================================================
// bool_serializer — to_dense_json
// =============================================================================

pub fn to_dense_json_true_is_1_test() {
  serializer.to_dense_json_code(serializers.bool_serializer(), True)
  |> should.equal("1")
}

pub fn to_dense_json_false_is_0_test() {
  serializer.to_dense_json_code(serializers.bool_serializer(), False)
  |> should.equal("0")
}

// =============================================================================
// bool_serializer — to_readable_json
// =============================================================================

pub fn to_readable_json_true_is_true_test() {
  serializer.to_readable_json_code(serializers.bool_serializer(), True)
  |> should.equal("true")
}

pub fn to_readable_json_false_is_false_test() {
  serializer.to_readable_json_code(serializers.bool_serializer(), False)
  |> should.equal("false")
}

// =============================================================================
// bool_serializer — from_json
// =============================================================================

pub fn from_json_bool_literal_test() {
  let s = serializers.bool_serializer()
  serializer.from_json_code(s, "true")
  |> should.be_ok
  |> should.be_true
  serializer.from_json_code(s, "false")
  |> should.be_ok
  |> should.be_false
}

pub fn from_json_number_1_and_0_test() {
  let s = serializers.bool_serializer()
  serializer.from_json_code(s, "1")
  |> should.be_ok
  |> should.be_true
  serializer.from_json_code(s, "0")
  |> should.be_ok
  |> should.be_false
}

pub fn from_json_number_nonzero_test() {
  serializer.from_json_code(serializers.bool_serializer(), "42")
  |> should.be_ok
  |> should.be_true
}

pub fn from_json_float_zero_test() {
  serializer.from_json_code(serializers.bool_serializer(), "0.0")
  |> should.be_ok
  |> should.be_false
}

pub fn from_json_string_zero_is_false_test() {
  // The JSON string "0" (three chars: quote, zero, quote) is the only falsy
  // string value.
  serializer.from_json_code(serializers.bool_serializer(), "\"0\"")
  |> should.be_ok
  |> should.be_false
}

pub fn from_json_string_nonzero_is_true_test() {
  let s = serializers.bool_serializer()
  serializer.from_json_code(s, "\"1\"")
  |> should.be_ok
  |> should.be_true
  serializer.from_json_code(s, "\"true\"")
  |> should.be_ok
  |> should.be_true
}

pub fn from_json_null_is_false_test() {
  serializer.from_json_code(serializers.bool_serializer(), "null")
  |> should.be_ok
  |> should.be_false
}

// =============================================================================
// bool_serializer — binary round-trip
// =============================================================================

pub fn binary_round_trip_true_test() {
  let s = serializers.bool_serializer()
  let bytes = serializer.to_bytes(s, True)
  serializer.from_bytes(s, bytes)
  |> should.be_ok
  |> should.be_true
}

pub fn binary_round_trip_false_test() {
  let s = serializers.bool_serializer()
  let bytes = serializer.to_bytes(s, False)
  serializer.from_bytes(s, bytes)
  |> should.be_ok
  |> should.be_false
}

pub fn binary_encoding_true_is_skir_then_1_test() {
  serializer.to_bytes(serializers.bool_serializer(), True)
  |> should.equal(<<115, 107, 105, 114, 1>>)
}

pub fn binary_encoding_false_is_skir_then_0_test() {
  serializer.to_bytes(serializers.bool_serializer(), False)
  |> should.equal(<<115, 107, 105, 114, 0>>)
}

// =============================================================================
// bool_serializer — type_descriptor
// =============================================================================

pub fn type_descriptor_is_bool_test() {
  let td = serializer.type_descriptor(serializers.bool_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"bool\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// int32_serializer — to_json
// =============================================================================

pub fn int32_to_json_zero_test() {
  serializer.to_dense_json_code(serializers.int32_serializer(), 0)
  |> should.equal("0")
}

pub fn int32_to_json_positive_test() {
  serializer.to_dense_json_code(serializers.int32_serializer(), 42)
  |> should.equal("42")
}

pub fn int32_to_json_negative_test() {
  serializer.to_dense_json_code(serializers.int32_serializer(), -1)
  |> should.equal("-1")
}

pub fn int32_to_json_same_in_readable_mode_test() {
  let s = serializers.int32_serializer()
  serializer.to_dense_json_code(s, 12_345)
  |> should.equal(serializer.to_readable_json_code(s, 12_345))
}

// =============================================================================
// int32_serializer — from_json
// =============================================================================

pub fn int32_from_json_integer_test() {
  let s = serializers.int32_serializer()
  serializer.from_json_code(s, "42") |> should.be_ok |> should.equal(42)
  serializer.from_json_code(s, "-1") |> should.be_ok |> should.equal(-1)
  serializer.from_json_code(s, "0") |> should.be_ok |> should.equal(0)
}

pub fn int32_from_json_float_truncates_test() {
  let s = serializers.int32_serializer()
  serializer.from_json_code(s, "3.9") |> should.be_ok |> should.equal(3)
  serializer.from_json_code(s, "-1.5") |> should.be_ok |> should.equal(-1)
}

pub fn int32_from_json_string_test() {
  serializer.from_json_code(serializers.int32_serializer(), "\"7\"")
  |> should.be_ok
  |> should.equal(7)
}

pub fn int32_from_json_unparseable_string_is_zero_test() {
  serializer.from_json_code(serializers.int32_serializer(), "\"abc\"")
  |> should.be_ok
  |> should.equal(0)
}

pub fn int32_from_json_null_is_zero_test() {
  serializer.from_json_code(serializers.int32_serializer(), "null")
  |> should.be_ok
  |> should.equal(0)
}

// =============================================================================
// int32_serializer — binary encoding
// =============================================================================

pub fn int32_encode_small_positive_is_single_byte_test() {
  let s = serializers.int32_serializer()
  serializer.to_bytes(s, 0) |> should.equal(<<115, 107, 105, 114, 0>>)
  serializer.to_bytes(s, 1) |> should.equal(<<115, 107, 105, 114, 1>>)
  serializer.to_bytes(s, 231) |> should.equal(<<115, 107, 105, 114, 231>>)
}

pub fn int32_encode_u16_range_test() {
  // 1000 = 0x03E8, LE: 232, 3
  let bytes = serializer.to_bytes(serializers.int32_serializer(), 1000)
  should.equal(bytes, <<115, 107, 105, 114, 232, 232, 3>>)
}

pub fn int32_encode_u32_range_test() {
  // 65536: wire 233, u32 LE: 0, 0, 1, 0
  let bytes = serializer.to_bytes(serializers.int32_serializer(), 65_536)
  should.equal(bytes, <<115, 107, 105, 114, 233, 0, 0, 1, 0>>)
}

pub fn int32_encode_small_negative_test() {
  // -1: wire 235, then (-1 + 256) = 255
  let bytes = serializer.to_bytes(serializers.int32_serializer(), -1)
  should.equal(bytes, <<115, 107, 105, 114, 235, 255>>)
}

pub fn int32_encode_medium_negative_test() {
  // -300: wire 236, then (-300 + 65536) = 65236 = 0xFED4 LE: 212, 254
  let bytes = serializer.to_bytes(serializers.int32_serializer(), -300)
  should.equal(bytes, <<115, 107, 105, 114, 236, 212, 254>>)
}

pub fn int32_encode_large_negative_test() {
  // -100_000: wire 237, then i32 LE bytes of -100000
  // -100000 as u32 = 4294867296 = 0xFFFE7960, LE: 96, 121, 254, 255
  let bytes = serializer.to_bytes(serializers.int32_serializer(), -100_000)
  should.equal(bytes, <<115, 107, 105, 114, 237, 96, 121, 254, 255>>)
}

pub fn int32_binary_round_trip_test() {
  let s = serializers.int32_serializer()
  let values = [
    0,
    1,
    42,
    231,
    232,
    300,
    65_535,
    65_536,
    -1,
    -255,
    -256,
    -65_536,
  ]
  values
  |> list_each(fn(v) {
    serializer.from_bytes(s, serializer.to_bytes(s, v))
    |> should.be_ok
    |> should.equal(v)
  })
}

// =============================================================================
// int32_serializer — type_descriptor
// =============================================================================

pub fn int32_type_descriptor_test() {
  let td = serializer.type_descriptor(serializers.int32_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"int32\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// int64_serializer — to_json
// =============================================================================

pub fn int64_to_json_safe_integer_test() {
  let s = serializers.int64_serializer()
  serializer.to_dense_json_code(s, 0) |> should.equal("0")
  serializer.to_dense_json_code(s, 9_007_199_254_740_991)
  |> should.equal("9007199254740991")
  serializer.to_dense_json_code(s, -9_007_199_254_740_991)
  |> should.equal("-9007199254740991")
}

pub fn int64_to_json_large_value_is_quoted_test() {
  let s = serializers.int64_serializer()
  serializer.to_dense_json_code(s, 9_007_199_254_740_992)
  |> should.equal("\"9007199254740992\"")
  serializer.to_dense_json_code(s, -9_007_199_254_740_992)
  |> should.equal("\"-9007199254740992\"")
}

// =============================================================================
// int64_serializer — from_json
// =============================================================================

pub fn int64_from_json_integer_test() {
  let s = serializers.int64_serializer()
  serializer.from_json_code(s, "42") |> should.be_ok |> should.equal(42)
  serializer.from_json_code(s, "-1") |> should.be_ok |> should.equal(-1)
}

pub fn int64_from_json_quoted_large_test() {
  serializer.from_json_code(
    serializers.int64_serializer(),
    "\"9007199254740992\"",
  )
  |> should.be_ok
  |> should.equal(9_007_199_254_740_992)
}

pub fn int64_from_json_null_is_zero_test() {
  serializer.from_json_code(serializers.int64_serializer(), "null")
  |> should.be_ok
  |> should.equal(0)
}

// =============================================================================
// int64_serializer — binary encoding
// =============================================================================

pub fn int64_encode_fits_i32_reuses_i32_encoding_test() {
  let s = serializers.int64_serializer()
  serializer.to_bytes(s, 0) |> should.equal(<<115, 107, 105, 114, 0>>)
  serializer.to_bytes(s, 42) |> should.equal(<<115, 107, 105, 114, 42>>)
}

pub fn int64_encode_wire_238_test() {
  // 2147483648 = i32::MAX + 1 → wire 238 + i64 LE
  let v = 2_147_483_648
  let bytes = serializer.to_bytes(serializers.int64_serializer(), v)
  // wire 238 then 8 bytes LE: 0, 0, 0, 128, 0, 0, 0, 0
  should.equal(bytes, <<115, 107, 105, 114, 238, 0, 0, 0, 128, 0, 0, 0, 0>>)
}

pub fn int64_binary_round_trip_test() {
  let s = serializers.int64_serializer()
  let values = [
    0, 1, 231, 232, 65_536, 2_147_483_647, 2_147_483_648, 9_007_199_254_740_991,
    -1, -2_147_483_648,
  ]
  values
  |> list_each(fn(v) {
    serializer.from_bytes(s, serializer.to_bytes(s, v))
    |> should.be_ok
    |> should.equal(v)
  })
}

// =============================================================================
// int64_serializer — type_descriptor
// =============================================================================

pub fn int64_type_descriptor_test() {
  let td = serializer.type_descriptor(serializers.int64_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"int64\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// hash64_serializer — to_json
// =============================================================================

pub fn hash64_to_json_safe_integer_test() {
  let s = serializers.hash64_serializer()
  serializer.to_dense_json_code(s, 0) |> should.equal("0")
  serializer.to_dense_json_code(s, 9_007_199_254_740_991)
  |> should.equal("9007199254740991")
}

pub fn hash64_to_json_large_value_is_quoted_test() {
  serializer.to_dense_json_code(
    serializers.hash64_serializer(),
    9_007_199_254_740_992,
  )
  |> should.equal("\"9007199254740992\"")
}

// =============================================================================
// hash64_serializer — from_json
// =============================================================================

pub fn hash64_from_json_integer_test() {
  serializer.from_json_code(serializers.hash64_serializer(), "42")
  |> should.be_ok
  |> should.equal(42)
}

pub fn hash64_from_json_negative_number_is_zero_test() {
  serializer.from_json_code(serializers.hash64_serializer(), "-1.0")
  |> should.be_ok
  |> should.equal(0)
}

pub fn hash64_from_json_quoted_large_test() {
  serializer.from_json_code(
    serializers.hash64_serializer(),
    "\"9007199254740992\"",
  )
  |> should.be_ok
  |> should.equal(9_007_199_254_740_992)
}

pub fn hash64_from_json_null_is_zero_test() {
  serializer.from_json_code(serializers.hash64_serializer(), "null")
  |> should.be_ok
  |> should.equal(0)
}

// =============================================================================
// hash64_serializer — binary encoding
// =============================================================================

pub fn hash64_encode_single_byte_range_test() {
  let s = serializers.hash64_serializer()
  serializer.to_bytes(s, 0) |> should.equal(<<115, 107, 105, 114, 0>>)
  serializer.to_bytes(s, 231) |> should.equal(<<115, 107, 105, 114, 231>>)
}

pub fn hash64_encode_u16_range_test() {
  // 1000 = 0x03E8 LE: 232, 3
  let bytes = serializer.to_bytes(serializers.hash64_serializer(), 1000)
  should.equal(bytes, <<115, 107, 105, 114, 232, 232, 3>>)
}

pub fn hash64_encode_u32_range_test() {
  // 65536 LE: 0, 0, 1, 0
  let bytes = serializer.to_bytes(serializers.hash64_serializer(), 65_536)
  should.equal(bytes, <<115, 107, 105, 114, 233, 0, 0, 1, 0>>)
}

pub fn hash64_encode_u64_range_test() {
  // 4_294_967_296 = 2^32; wire 234 + u64 LE
  let v = 4_294_967_296
  let bytes = serializer.to_bytes(serializers.hash64_serializer(), v)
  should.equal(bytes, <<115, 107, 105, 114, 234, 0, 0, 0, 0, 1, 0, 0, 0>>)
}

pub fn hash64_binary_round_trip_test() {
  let s = serializers.hash64_serializer()
  let values = [0, 1, 231, 232, 65_535, 65_536, 4_294_967_295, 4_294_967_296]
  values
  |> list_each(fn(v) {
    serializer.from_bytes(s, serializer.to_bytes(s, v))
    |> should.be_ok
    |> should.equal(v)
  })
}

// =============================================================================
// hash64_serializer — type_descriptor
// =============================================================================

pub fn hash64_type_descriptor_test() {
  let td = serializer.type_descriptor(serializers.hash64_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"hash64\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// float32_serializer — to_dense_json
// =============================================================================

pub fn float32_to_dense_json_zero_test() {
  serializer.to_dense_json_code(serializers.float32_serializer(), 0.0)
  |> should.equal("0")
}

pub fn float32_to_dense_json_one_test() {
  serializer.to_dense_json_code(serializers.float32_serializer(), 1.0)
  |> should.equal("1")
}

pub fn float32_to_dense_json_one_and_half_test() {
  serializer.to_dense_json_code(serializers.float32_serializer(), 1.5)
  |> should.equal("1.5")
}

pub fn float32_to_dense_json_negative_test() {
  serializer.to_dense_json_code(serializers.float32_serializer(), -3.14)
  |> should.equal("-3.14")
}

// =============================================================================
// float32_serializer — to_readable_json (identical to dense for scalars)
// =============================================================================

pub fn float32_to_readable_json_zero_test() {
  serializer.to_readable_json_code(serializers.float32_serializer(), 0.0)
  |> should.equal("0")
}

pub fn float32_to_readable_json_nonzero_test() {
  serializer.to_readable_json_code(serializers.float32_serializer(), 1.5)
  |> should.equal("1.5")
}

// =============================================================================
// float32_serializer — from_json
// =============================================================================

pub fn float32_from_json_number_test() {
  serializer.from_json_code(serializers.float32_serializer(), "1.5")
  |> should.be_ok
  |> should.equal(1.5)
}

pub fn float32_from_json_integer_test() {
  serializer.from_json_code(serializers.float32_serializer(), "3")
  |> should.be_ok
  |> should.equal(3.0)
}

pub fn float32_from_json_null_is_zero_test() {
  serializer.from_json_code(serializers.float32_serializer(), "null")
  |> should.be_ok
  |> should.equal(0.0)
}

pub fn float32_from_json_quoted_string_test() {
  serializer.from_json_code(serializers.float32_serializer(), "\"1.5\"")
  |> should.be_ok
  |> should.equal(1.5)
}

pub fn float32_from_json_infinity_is_max_float_test() {
  serializer.from_json_code(serializers.float32_serializer(), "\"Infinity\"")
  |> should.be_ok
  |> should.equal(1.7976931348623157e308)
}

pub fn float32_from_json_neg_infinity_is_min_float_test() {
  serializer.from_json_code(serializers.float32_serializer(), "\"-Infinity\"")
  |> should.be_ok
  |> should.equal(-1.7976931348623157e308)
}

pub fn float32_from_json_nan_is_zero_test() {
  serializer.from_json_code(serializers.float32_serializer(), "\"NaN\"")
  |> should.be_ok
  |> should.equal(0.0)
}

// =============================================================================
// float32_serializer — binary encoding
// =============================================================================

pub fn float32_encode_zero_is_single_byte_zero_test() {
  // "skir" magic (4 bytes) + wire 0 (1 byte)
  serializer.to_bytes(serializers.float32_serializer(), 0.0)
  |> should.equal(<<115, 107, 105, 114, 0>>)
}

pub fn float32_encode_nonzero_starts_with_wire_240_test() {
  let bytes = serializer.to_bytes(serializers.float32_serializer(), 1.5)
  // "skir" is 4 bytes, then wire byte 240
  case bytes {
    <<115, 107, 105, 114, 240, _:bits>> -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// float32_serializer — binary round-trips (exact float32 values)
// =============================================================================

pub fn float32_binary_round_trip_zero_test() {
  let s = serializers.float32_serializer()
  let value = 0.0
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float32_binary_round_trip_one_and_half_test() {
  let s = serializers.float32_serializer()
  let value = 1.5
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float32_binary_round_trip_negative_test() {
  let s = serializers.float32_serializer()
  let value = -1.5
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float32_from_bytes_infinity_is_max_float_test() {
  // Wire byte 240 + IEEE 754 +Infinity (0x7F800000 little-endian)
  serializer.from_bytes(serializers.float32_serializer(), <<
    115,
    107,
    105,
    114,
    240,
    0,
    0,
    128,
    127,
  >>)
  |> should.be_ok
  |> should.equal(1.7976931348623157e308)
}

pub fn float32_from_bytes_neg_infinity_is_min_float_test() {
  // Wire byte 240 + IEEE 754 -Infinity (0xFF800000 little-endian)
  serializer.from_bytes(serializers.float32_serializer(), <<
    115,
    107,
    105,
    114,
    240,
    0,
    0,
    128,
    255,
  >>)
  |> should.be_ok
  |> should.equal(-1.7976931348623157e308)
}

// =============================================================================
// float64_serializer — to_dense_json
// =============================================================================

pub fn float64_to_dense_json_zero_test() {
  serializer.to_dense_json_code(serializers.float64_serializer(), 0.0)
  |> should.equal("0")
}

pub fn float64_to_dense_json_one_test() {
  serializer.to_dense_json_code(serializers.float64_serializer(), 1.0)
  |> should.equal("1")
}

pub fn float64_to_dense_json_one_and_half_test() {
  serializer.to_dense_json_code(serializers.float64_serializer(), 1.5)
  |> should.equal("1.5")
}

pub fn float64_to_dense_json_negative_test() {
  serializer.to_dense_json_code(serializers.float64_serializer(), -3.14)
  |> should.equal("-3.14")
}

// =============================================================================
// float64_serializer — to_readable_json
// =============================================================================

pub fn float64_to_readable_json_zero_test() {
  serializer.to_readable_json_code(serializers.float64_serializer(), 0.0)
  |> should.equal("0")
}

pub fn float64_to_readable_json_nonzero_test() {
  serializer.to_readable_json_code(serializers.float64_serializer(), 1.5)
  |> should.equal("1.5")
}

// =============================================================================
// float64_serializer — from_json
// =============================================================================

pub fn float64_from_json_number_test() {
  serializer.from_json_code(serializers.float64_serializer(), "1.5")
  |> should.be_ok
  |> should.equal(1.5)
}

pub fn float64_from_json_integer_test() {
  serializer.from_json_code(serializers.float64_serializer(), "3")
  |> should.be_ok
  |> should.equal(3.0)
}

pub fn float64_from_json_null_is_zero_test() {
  serializer.from_json_code(serializers.float64_serializer(), "null")
  |> should.be_ok
  |> should.equal(0.0)
}

pub fn float64_from_json_quoted_string_test() {
  serializer.from_json_code(serializers.float64_serializer(), "\"1.5\"")
  |> should.be_ok
  |> should.equal(1.5)
}

pub fn float64_from_json_infinity_is_max_float_test() {
  serializer.from_json_code(serializers.float64_serializer(), "\"Infinity\"")
  |> should.be_ok
  |> should.equal(1.7976931348623157e308)
}

pub fn float64_from_json_neg_infinity_is_min_float_test() {
  serializer.from_json_code(serializers.float64_serializer(), "\"-Infinity\"")
  |> should.be_ok
  |> should.equal(-1.7976931348623157e308)
}

pub fn float64_from_json_nan_is_zero_test() {
  serializer.from_json_code(serializers.float64_serializer(), "\"NaN\"")
  |> should.be_ok
  |> should.equal(0.0)
}

// =============================================================================
// float64_serializer — binary encoding
// =============================================================================

pub fn float64_encode_zero_is_single_byte_zero_test() {
  serializer.to_bytes(serializers.float64_serializer(), 0.0)
  |> should.equal(<<115, 107, 105, 114, 0>>)
}

pub fn float64_encode_nonzero_starts_with_wire_241_test() {
  let bytes = serializer.to_bytes(serializers.float64_serializer(), 1.5)
  case bytes {
    <<115, 107, 105, 114, 241, _:bits>> -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// float64_serializer — binary round-trips
// =============================================================================

pub fn float64_binary_round_trip_zero_test() {
  let s = serializers.float64_serializer()
  let value = 0.0
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float64_binary_round_trip_nonzero_test() {
  let s = serializers.float64_serializer()
  let value = 3.141_592_653_589_793
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float64_binary_round_trip_negative_test() {
  let s = serializers.float64_serializer()
  let value = -2.718_281_828_459_045
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn float64_from_bytes_infinity_is_max_float_test() {
  // Wire byte 241 + IEEE 754 +Infinity (0x7FF0000000000000 little-endian)
  serializer.from_bytes(serializers.float64_serializer(), <<
    115,
    107,
    105,
    114,
    241,
    0,
    0,
    0,
    0,
    0,
    0,
    240,
    127,
  >>)
  |> should.be_ok
  |> should.equal(1.7976931348623157e308)
}

pub fn float64_from_bytes_neg_infinity_is_min_float_test() {
  // Wire byte 241 + IEEE 754 -Infinity (0xFFF0000000000000 little-endian)
  serializer.from_bytes(serializers.float64_serializer(), <<
    115,
    107,
    105,
    114,
    241,
    0,
    0,
    0,
    0,
    0,
    0,
    240,
    255,
  >>)
  |> should.be_ok
  |> should.equal(-1.7976931348623157e308)
}

// =============================================================================
// string_serializer — to_dense_json
// =============================================================================

pub fn to_dense_json_empty_string_test() {
  serializer.to_dense_json_code(serializers.string_serializer(), "")
  |> should.equal("\"\"")
}

pub fn to_dense_json_simple_string_test() {
  serializer.to_dense_json_code(serializers.string_serializer(), "hello")
  |> should.equal("\"hello\"")
}

pub fn to_dense_json_escapes_double_quote_test() {
  serializer.to_dense_json_code(serializers.string_serializer(), "say \"hi\"")
  |> should.equal("\"say \\\"hi\\\"\"")
}

pub fn to_dense_json_escapes_backslash_test() {
  serializer.to_dense_json_code(serializers.string_serializer(), "a\\b")
  |> should.equal("\"a\\\\b\"")
}

pub fn to_dense_json_escapes_newline_test() {
  serializer.to_dense_json_code(serializers.string_serializer(), "a\nb")
  |> should.equal("\"a\\nb\"")
}

// =============================================================================
// string_serializer — to_readable_json
// =============================================================================

pub fn to_readable_json_simple_string_test() {
  // Strings are quoted identically in dense and readable JSON.
  serializer.to_readable_json_code(serializers.string_serializer(), "hello")
  |> should.equal("\"hello\"")
}

pub fn to_readable_json_empty_string_test() {
  serializer.to_readable_json_code(serializers.string_serializer(), "")
  |> should.equal("\"\"")
}

// =============================================================================
// string_serializer — from_json
// =============================================================================

pub fn from_json_string_test() {
  serializer.from_json_code(serializers.string_serializer(), "\"hello\"")
  |> should.be_ok
  |> should.equal("hello")
}

pub fn from_json_empty_string_test() {
  serializer.from_json_code(serializers.string_serializer(), "\"\"")
  |> should.be_ok
  |> should.equal("")
}

pub fn from_json_number_yields_empty_string_test() {
  // Any number is treated as the default (empty string).
  serializer.from_json_code(serializers.string_serializer(), "0")
  |> should.be_ok
  |> should.equal("")
}

pub fn from_json_null_yields_empty_string_test() {
  serializer.from_json_code(serializers.string_serializer(), "null")
  |> should.be_ok
  |> should.equal("")
}

pub fn from_json_round_trip_test() {
  let s = serializers.string_serializer()
  let value = "round trip"
  serializer.to_dense_json_code(s, value)
  |> serializer.from_json_code(s, _)
  |> should.be_ok
  |> should.equal(value)
}

// =============================================================================
// string_serializer — binary encoding
// =============================================================================

pub fn binary_encoding_empty_is_wire_242_test() {
  // empty string → skir prefix (4 bytes) + wire 242
  serializer.to_bytes(serializers.string_serializer(), "")
  |> should.equal(<<115, 107, 105, 114, 242>>)
}

pub fn binary_encoding_hello_test() {
  // "hello" = [104,101,108,108,111], len=5 (single-byte length)
  // → skir + 243 + 5 + utf8("hello")
  serializer.to_bytes(serializers.string_serializer(), "hello")
  |> should.equal(<<115, 107, 105, 114, 243, 5, 104, 101, 108, 108, 111>>)
}

// =============================================================================
// string_serializer — binary round-trip
// =============================================================================

pub fn string_binary_round_trip_empty_test() {
  let s = serializers.string_serializer()
  serializer.to_bytes(s, "")
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal("")
}

pub fn binary_round_trip_simple_test() {
  let s = serializers.string_serializer()
  serializer.to_bytes(s, "hello")
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal("hello")
}

pub fn binary_round_trip_unicode_test() {
  let s = serializers.string_serializer()
  let value = "héllo wörld"
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

// =============================================================================
// string_serializer — type_descriptor
// =============================================================================

pub fn type_descriptor_is_string_test() {
  let td = serializer.type_descriptor(serializers.string_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"string\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// bytes_serializer — to_dense_json   (standard base64 with = padding)
// =============================================================================

pub fn to_dense_json_empty_bytes_test() {
  serializer.to_dense_json_code(serializers.bytes_serializer(), <<>>)
  |> should.equal("\"\"")
}

pub fn to_dense_json_single_byte_test() {
  // <<0>> → base64 "AA=="
  serializer.to_dense_json_code(serializers.bytes_serializer(), <<0>>)
  |> should.equal("\"AA==\"")
}

pub fn to_dense_json_two_bytes_test() {
  // <<0, 1>> → base64 "AAE="
  serializer.to_dense_json_code(serializers.bytes_serializer(), <<0, 1>>)
  |> should.equal("\"AAE=\"")
}

pub fn to_dense_json_three_bytes_test() {
  // <<0, 1, 2>> → base64 "AAEC"
  serializer.to_dense_json_code(serializers.bytes_serializer(), <<0, 1, 2>>)
  |> should.equal("\"AAEC\"")
}

pub fn to_dense_json_hello_test() {
  // "hello" in bytes → base64 "aGVsbG8="
  serializer.to_dense_json_code(serializers.bytes_serializer(), <<
    104,
    101,
    108,
    108,
    111,
  >>)
  |> should.equal("\"aGVsbG8=\"")
}

// =============================================================================
// bytes_serializer — to_readable_json   (hex: prefix)
// =============================================================================

pub fn to_readable_json_empty_bytes_test() {
  serializer.to_readable_json_code(serializers.bytes_serializer(), <<>>)
  |> should.equal("\"hex:\"")
}

pub fn to_readable_json_single_byte_test() {
  // <<0x0f>> → "hex:0f"
  serializer.to_readable_json_code(serializers.bytes_serializer(), <<15>>)
  |> should.equal("\"hex:0f\"")
}

pub fn to_readable_json_multiple_bytes_test() {
  // <<0xde, 0xad, 0xbe, 0xef>> → "hex:deadbeef"
  serializer.to_readable_json_code(serializers.bytes_serializer(), <<
    0xde,
    0xad,
    0xbe,
    0xef,
  >>)
  |> should.equal("\"hex:deadbeef\"")
}

// =============================================================================
// bytes_serializer — from_json
// =============================================================================

pub fn from_json_base64_test() {
  serializer.from_json_code(serializers.bytes_serializer(), "\"aGVsbG8=\"")
  |> should.be_ok
  |> should.equal(<<104, 101, 108, 108, 111>>)
}

pub fn from_json_empty_base64_test() {
  serializer.from_json_code(serializers.bytes_serializer(), "\"\"")
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn from_json_null_yields_empty_bytes_test() {
  serializer.from_json_code(serializers.bytes_serializer(), "null")
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn from_json_number_yields_empty_bytes_test() {
  serializer.from_json_code(serializers.bytes_serializer(), "0")
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn from_json_hex_prefix_test() {
  serializer.from_json_code(serializers.bytes_serializer(), "\"hex:deadbeef\"")
  |> should.be_ok
  |> should.equal(<<0xde, 0xad, 0xbe, 0xef>>)
}

pub fn from_json_round_trip_dense_test() {
  let s = serializers.bytes_serializer()
  let value = <<1, 2, 3, 4, 5>>
  serializer.to_dense_json_code(s, value)
  |> serializer.from_json_code(s, _)
  |> should.be_ok
  |> should.equal(value)
}

pub fn from_json_round_trip_readable_test() {
  let s = serializers.bytes_serializer()
  let value = <<0xca, 0xfe, 0xba, 0xbe>>
  serializer.to_readable_json_code(s, value)
  |> serializer.from_json_code(s, _)
  |> should.be_ok
  |> should.equal(value)
}

// =============================================================================
// bytes_serializer — binary encoding
// =============================================================================

pub fn binary_encoding_empty_is_wire_244_test() {
  // empty → skir prefix + wire 244
  serializer.to_bytes(serializers.bytes_serializer(), <<>>)
  |> should.equal(<<115, 107, 105, 114, 244>>)
}

pub fn binary_encoding_hello_bytes_test() {
  // <<104,101,108,108,111>>, len=5
  // → skir + 245 + 5 + bytes
  serializer.to_bytes(serializers.bytes_serializer(), <<
    104,
    101,
    108,
    108,
    111,
  >>)
  |> should.equal(<<115, 107, 105, 114, 245, 5, 104, 101, 108, 108, 111>>)
}

// =============================================================================
// bytes_serializer — binary round-trip
// =============================================================================

pub fn bytes_binary_round_trip_empty_test() {
  let s = serializers.bytes_serializer()
  serializer.to_bytes(s, <<>>)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn binary_round_trip_bytes_test() {
  let s = serializers.bytes_serializer()
  let value = <<1, 2, 3, 4, 5, 255, 0, 127>>
  serializer.to_bytes(s, value)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(value)
}

// =============================================================================
// bytes_serializer — type_descriptor
// =============================================================================

pub fn type_descriptor_is_bytes_test() {
  let td = serializer.type_descriptor(serializers.bytes_serializer())
  let json = type_descriptor.type_descriptor_to_json(td)
  let expected =
    "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": \"bytes\"\n  },\n  \"records\": []\n}"
  should.equal(json, expected)
}

// =============================================================================
// timestamp_serializer — to_dense_json
// =============================================================================

pub fn timestamp_to_dense_json_epoch_test() {
  let epoch = from_unix_milli(0)
  serializer.to_dense_json_code(serializers.timestamp_serializer(), epoch)
  |> should.equal("0")
}

pub fn timestamp_to_dense_json_nonzero_test() {
  // 2009-02-13T23:31:30Z = 1234567890000 ms since epoch
  let d = from_unix_milli(1_234_567_890_000)
  serializer.to_dense_json_code(serializers.timestamp_serializer(), d)
  |> should.equal("1234567890000")
}

// =============================================================================
// timestamp_serializer — to_readable_json
// =============================================================================

pub fn timestamp_to_readable_json_epoch_test() {
  let epoch = from_unix_milli(0)
  serializer.to_readable_json_code(serializers.timestamp_serializer(), epoch)
  |> should.equal(
    "{\n  \"unix_millis\": 0,\n  \"formatted\": \"1970-01-01T00:00:00Z\"\n}",
  )
}

pub fn timestamp_to_readable_json_nonzero_test() {
  let d = from_unix_milli(1_234_567_890_000)
  serializer.to_readable_json_code(serializers.timestamp_serializer(), d)
  |> should.equal(
    "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30Z\"\n}",
  )
}

// =============================================================================
// timestamp_serializer — from_json
// =============================================================================

pub fn timestamp_from_json_integer_test() {
  serializer.from_json_code(serializers.timestamp_serializer(), "1234567890000")
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(1_234_567_890_000)
}

pub fn timestamp_from_json_null_is_epoch_test() {
  serializer.from_json_code(serializers.timestamp_serializer(), "null")
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(0)
}

pub fn timestamp_from_json_object_test() {
  let json =
    "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30Z\"\n}"
  serializer.from_json_code(serializers.timestamp_serializer(), json)
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(1_234_567_890_000)
}

pub fn timestamp_from_json_quoted_millis_test() {
  serializer.from_json_code(
    serializers.timestamp_serializer(),
    "\"1234567890000\"",
  )
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(1_234_567_890_000)
}

// =============================================================================
// timestamp_serializer — binary encoding
// =============================================================================

pub fn timestamp_encode_epoch_is_single_byte_zero_test() {
  // "skir" (4 bytes) + wire 0 (1 byte) for epoch (ms = 0)
  let epoch = from_unix_milli(0)
  serializer.to_bytes(serializers.timestamp_serializer(), epoch)
  |> should.equal(<<115, 107, 105, 114, 0>>)
}

pub fn timestamp_encode_nonzero_starts_with_wire_239_test() {
  // 1234567890000 is > i32 max so wire byte 239 (64-bit LE) is used
  let d = from_unix_milli(1_234_567_890_000)
  let bytes = serializer.to_bytes(serializers.timestamp_serializer(), d)
  case bytes {
    <<115, 107, 105, 114, 239, _:bits>> -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// timestamp_serializer — binary round-trips
// =============================================================================

pub fn timestamp_binary_round_trip_epoch_test() {
  let s = serializers.timestamp_serializer()
  let epoch = from_unix_milli(0)
  serializer.to_bytes(s, epoch)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(0)
}

pub fn timestamp_binary_round_trip_nonzero_test() {
  let s = serializers.timestamp_serializer()
  let ms = 1_234_567_890_000
  let d = from_unix_milli(ms)
  serializer.to_bytes(s, d)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(ms)
}

pub fn timestamp_binary_round_trip_small_millis_test() {
  let s = serializers.timestamp_serializer()
  let ms = 42
  let d = from_unix_milli(ms)
  serializer.to_bytes(s, d)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> to_unix_milli
  |> should.equal(ms)
}

// =============================================================================
// optional_serializer — to_dense_json
// =============================================================================

pub fn optional_to_dense_json_none_test() {
  serializer.to_dense_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    None,
  )
  |> should.equal("null")
}

pub fn optional_to_dense_json_some_test() {
  serializer.to_dense_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    Some(42),
  )
  |> should.equal("42")
}

// =============================================================================
// optional_serializer — to_readable_json
// =============================================================================

pub fn optional_to_readable_json_none_test() {
  serializer.to_readable_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    None,
  )
  |> should.equal("null")
}

pub fn optional_to_readable_json_some_test() {
  serializer.to_readable_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    Some(42),
  )
  |> should.equal("42")
}

// =============================================================================
// optional_serializer — from_json
// =============================================================================

pub fn optional_from_json_null_test() {
  serializer.from_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    "null",
  )
  |> should.be_ok
  |> should.equal(None)
}

pub fn optional_from_json_value_test() {
  serializer.from_json_code(
    serializers.optional_serializer(serializers.int32_serializer()),
    "42",
  )
  |> should.be_ok
  |> should.equal(Some(42))
}

// =============================================================================
// optional_serializer — binary encoding
// =============================================================================

pub fn optional_encode_none_is_single_zero_byte_test() {
  // "skir" prefix (4 bytes) + 0xFF for None
  serializer.to_bytes(
    serializers.optional_serializer(serializers.int32_serializer()),
    None,
  )
  |> should.equal(<<115, 107, 105, 114, 255>>)
}

pub fn optional_encode_some_starts_with_one_byte_test() {
  // "skir" prefix (4 bytes) + 0x01 tag + encoded value
  let bytes =
    serializer.to_bytes(
      serializers.optional_serializer(serializers.int32_serializer()),
      Some(0),
    )
  case bytes {
    <<115, 107, 105, 114, 1, _:bits>> -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// optional_serializer — binary round-trips
// =============================================================================

pub fn optional_binary_round_trip_none_test() {
  let s = serializers.optional_serializer(serializers.int32_serializer())
  serializer.to_bytes(s, None)
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(None)
}

pub fn optional_binary_round_trip_some_test() {
  let s = serializers.optional_serializer(serializers.int32_serializer())
  serializer.to_bytes(s, Some(42))
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal(Some(42))
}

// =============================================================================
// list_serializer — to_dense_json
// =============================================================================

pub fn array_to_dense_json_empty_test() {
  serializer.to_dense_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    [],
  )
  |> should.equal("[]")
}

pub fn array_to_dense_json_nonempty_test() {
  serializer.to_dense_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    [1, 2, 3],
  )
  |> should.equal("[1,2,3]")
}

// =============================================================================
// list_serializer — to_readable_json
// =============================================================================

pub fn array_to_readable_json_empty_test() {
  serializer.to_readable_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    [],
  )
  |> should.equal("[]")
}

pub fn array_to_readable_json_nonempty_test() {
  serializer.to_readable_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    [1, 2],
  )
  |> should.equal("[\n  1,\n  2\n]")
}

// =============================================================================
// list_serializer — from_json
// =============================================================================

pub fn array_from_json_zero_is_empty_test() {
  serializer.from_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    "0",
  )
  |> should.be_ok
  |> should.equal([])
}

pub fn array_from_json_empty_test() {
  serializer.from_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    "[]",
  )
  |> should.be_ok
  |> should.equal([])
}

pub fn array_from_json_nonempty_test() {
  serializer.from_json_code(
    serializers.list_serializer(serializers.int32_serializer()),
    "[1,2,3]",
  )
  |> should.be_ok
  |> should.equal([1, 2, 3])
}

// =============================================================================
// list_serializer — binary round-trips
// =============================================================================

pub fn array_binary_round_trip_empty_test() {
  let s = serializers.list_serializer(serializers.int32_serializer())
  serializer.to_bytes(s, [])
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal([])
}

pub fn array_binary_round_trip_nonempty_test() {
  let s = serializers.list_serializer(serializers.int32_serializer())
  serializer.to_bytes(s, [1, 2, 3])
  |> serializer.from_bytes(s, _)
  |> should.be_ok
  |> should.equal([1, 2, 3])
}

// =============================================================================
// Helpers
// =============================================================================

fn list_each(list: List(a), f: fn(a) -> Nil) -> Nil {
  case list {
    [] -> Nil
    [first, ..rest] -> {
      f(first)
      list_each(rest, f)
    }
  }
}

fn from_unix_milli(ms: Int) -> timestamp.Timestamp {
  timestamp.Timestamp(unix_millis: ms)
}

fn to_unix_milli(ts: timestamp.Timestamp) -> Int {
  ts.unix_millis
}
