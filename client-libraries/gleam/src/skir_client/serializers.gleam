import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import gleam/time/calendar
import gleam/time/timestamp as gleam_timestamp
import skir_client/internal/json_utils
import skir_client/internal/type_adapter
import skir_client/recursive
import skir_client/serializer as serializer_
import skir_client/timestamp as skir_timestamp
import skir_client/type_descriptor

// =============================================================================
// Primitive Serializers
// =============================================================================

fn bool_adapter() -> type_adapter.TypeAdapter(Bool) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { !v },
    to_json: fn(v, readable) {
      case readable {
        type_adapter.Readable -> json.bool(v)
        type_adapter.Dense ->
          json.int(case v {
            True -> 1
            False -> 0
          })
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      json.to_string_tree(json.bool(v))
    },
    decode_json: fn(_) {
      decode.one_of(decode.bool, [
        decode.int |> decode.map(fn(n) { n != 0 }),
        decode.float |> decode.map(fn(f) { f != 0.0 }),
        decode.string |> decode.map(fn(s) { s != "0" }),
        decode.optional(decode.bool)
          |> decode.map(fn(opt) { option.unwrap(opt, False) }),
      ])
    },
    encode: fn(v, acc) {
      bytes_tree.append(acc, case v {
        True -> <<1>>
        False -> <<0>>
      })
    },
    decode: fn(bits, _) {
      case bits {
        <<b, rest:bits>> -> Ok(#(b != 0, rest))
        _ -> Error("expected at least 1 byte for bool")
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Bool),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for Bool values.
pub fn bool_serializer() -> serializer_.Serializer(Bool) {
  serializer_.Serializer(internal_adapter: bool_adapter())
}

// -----------------------------------------------------------------------------
// Binary encoding helpers shared by all integer adapters
// -----------------------------------------------------------------------------

// Encodes an i32 using the skir variable-length wire format.
// 0..=231:        single byte (the value itself)
// 232..=65535:    wire 232, then value as u16 LE
// >= 65536:       wire 233, then value as u32 LE
// -256..=-1:      wire 235, then (value + 256) as u8
// -65536..=-257:  wire 236, then (value + 65536) as u16 LE
// < -65536:       wire 237, then value as i32 LE (4 bytes)
fn encode_i32(v: Int) -> BitArray {
  case v {
    _ if v >= 0 && v <= 231 -> <<v>>
    _ if v >= 232 && v <= 65_535 -> <<232, v:size(16)-little>>
    _ if v >= 65_536 -> <<233, v:size(32)-little>>
    _ if v >= -256 && v < 0 -> {
      let b = v + 256
      <<235, b>>
    }
    _ if v >= -65_536 && v < -256 -> {
      let u = v + 65_536
      <<236, u:size(16)-little>>
    }
    _ -> {
      let u = int.bitwise_and(v, 0xFFFF_FFFF)
      <<237, u:size(32)-little>>
    }
  }
}

// Decodes a variable-length number from a BitArray.
// Returns Ok(#(value, rest)) or Error(message).
fn decode_number(bits: BitArray) -> Result(#(Int, BitArray), String) {
  case bits {
    <<wire, rest:bits>> ->
      case wire {
        _ if wire <= 231 -> Ok(#(wire, rest))
        232 ->
          case rest {
            <<v:size(16)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        233 ->
          case rest {
            <<v:size(32)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        234 ->
          case rest {
            <<v:size(64)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        235 ->
          case rest {
            <<b, r:bits>> -> Ok(#(b - 256, r))
            _ -> Error("unexpected end of input")
          }
        236 ->
          case rest {
            <<v:size(16)-little, r:bits>> -> Ok(#(v - 65_536, r))
            _ -> Error("unexpected end of input")
          }
        237 ->
          case rest {
            <<v:size(32)-little-signed, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        238 | 239 ->
          case rest {
            <<v:size(64)-little-signed, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        240 ->
          // float32 wire: read 4 bytes, truncate to int
          case rest {
            <<v:float-size(32)-little, r:bits>> -> Ok(#(float.truncate(v), r))
            _ -> Error("unexpected end of input")
          }
        241 ->
          // float64 wire: read 8 bytes, truncate to int
          case rest {
            <<v:float-size(64)-little, r:bits>> -> Ok(#(float.truncate(v), r))
            _ -> Error("unexpected end of input")
          }
        _ -> Ok(#(0, rest))
      }
    _ -> Error("unexpected end of input")
  }
}

// Parses a JSON string that should represent an integer.
// Handles: integer literal ("42"), float literal ("3.9" → 3), else 0.
fn int32_from_json_str(s: String) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) ->
      case float.parse(s) {
        Ok(f) -> float.truncate(f)
        Error(_) -> 0
      }
  }
}

fn int32_adapter() -> type_adapter.TypeAdapter(Int) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == 0 },
    to_json: fn(v, _) { json.int(v) },
    to_readable_json_code: fn(v, _eol_indent) {
      json.to_string_tree(json.int(v))
    },
    decode_json: fn(_) {
      decode.one_of(decode.int, [
        decode.float |> decode.map(float.truncate),
        decode.string |> decode.map(int32_from_json_str),
        decode.optional(decode.int)
          |> decode.map(fn(opt) { option.unwrap(opt, 0) }),
      ])
    },
    encode: fn(v, acc) { bytes_tree.append(acc, encode_i32(v)) },
    decode: fn(bits, _) { decode_number(bits) },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Int32),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for Int (int32) values.
pub fn int32_serializer() -> serializer_.Serializer(Int) {
  serializer_.Serializer(internal_adapter: int32_adapter())
}

// -----------------------------------------------------------------------------
// Int64 adapter
// Max safe integer for JSON: 9_007_199_254_740_991 (2^53 - 1)
// Values within [-MAX, MAX] → JSON number; outside → quoted string.
// -----------------------------------------------------------------------------

const max_safe_int64_json: Int = 9_007_199_254_740_991

fn int64_adapter() -> type_adapter.TypeAdapter(Int) {
  let parse_string = fn(s) {
    case int.parse(s) {
      Ok(n) -> n
      Error(_) ->
        case float.parse(s) {
          Ok(f) -> float.round(f)
          Error(_) -> 0
        }
    }
  }
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == 0 },
    to_json: fn(v, _) {
      case v >= -max_safe_int64_json && v <= max_safe_int64_json {
        True -> json.int(v)
        False -> json.string(int.to_string(v))
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      case v >= -max_safe_int64_json && v <= max_safe_int64_json {
        True -> json.to_string_tree(json.int(v))
        False -> json.to_string_tree(json.string(int.to_string(v)))
      }
    },
    decode_json: fn(_) {
      decode.one_of(decode.int, [
        decode.float |> decode.map(float.round),
        decode.string |> decode.map(parse_string),
        decode.optional(decode.int)
          |> decode.map(fn(opt) { option.unwrap(opt, 0) }),
      ])
    },
    encode: fn(v, acc) { bytes_tree.append(acc, encode_i64(v)) },
    decode: fn(bits, _) { decode_number(bits) },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Int64),
        records: dict.new(),
      )
    },
  )
}

// Encodes an i64.  Values in i32 range reuse i32 encoding; others use wire 238.
fn encode_i64(v: Int) -> BitArray {
  case v >= -2_147_483_648 && v <= 2_147_483_647 {
    True -> encode_i32(v)
    False -> {
      let u = int.bitwise_and(v, 0xFFFF_FFFF_FFFF_FFFF)
      <<238, u:size(64)-little>>
    }
  }
}

/// Returns the serializer for Int (int64) values.
pub fn int64_serializer() -> serializer_.Serializer(Int) {
  serializer_.Serializer(internal_adapter: int64_adapter())
}

// -----------------------------------------------------------------------------
// Hash64 adapter  (unsigned 64-bit integer, stored as Gleam Int)
// Wire format: same variable-length uint scheme used by encode_uint32, extended
// to u64: 0-231 single byte; 232-65535 wire232+u16LE; 65536-4294967295
// wire233+u32LE; >= 2^32 wire234+u64LE.
// -----------------------------------------------------------------------------

const max_safe_hash64_json: Int = 9_007_199_254_740_991

fn hash64_adapter() -> type_adapter.TypeAdapter(Int) {
  let parse_string = fn(s) {
    case int.parse(s) {
      Ok(n) -> n
      Error(_) ->
        case float.parse(s) {
          Ok(f) -> float.round(f)
          Error(_) -> 0
        }
    }
  }
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == 0 },
    to_json: fn(v, _) {
      case v <= max_safe_hash64_json {
        True -> json.int(v)
        False -> json.string(int.to_string(v))
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      case v <= max_safe_hash64_json {
        True -> json.to_string_tree(json.int(v))
        False -> json.to_string_tree(json.string(int.to_string(v)))
      }
    },
    decode_json: fn(_) {
      decode.one_of(decode.int, [
        decode.float
          |> decode.map(fn(f) {
            case f <. 0.0 {
              True -> 0
              False -> float.round(f)
            }
          }),
        decode.string |> decode.map(parse_string),
        decode.optional(decode.int)
          |> decode.map(fn(opt) { option.unwrap(opt, 0) }),
      ])
    },
    encode: fn(v, acc) { bytes_tree.append(acc, encode_uint64(v)) },
    decode: fn(bits, _) { decode_number(bits) },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Hash64),
        records: dict.new(),
      )
    },
  )
}

fn encode_uint64(v: Int) -> BitArray {
  case v {
    _ if v <= 231 -> <<v>>
    _ if v <= 65_535 -> <<232, v:size(16)-little>>
    _ if v <= 4_294_967_295 -> <<233, v:size(32)-little>>
    _ -> <<234, v:size(64)-little>>
  }
}

/// Returns the serializer for Int (hash64) values.
pub fn hash64_serializer() -> serializer_.Serializer(Int) {
  serializer_.Serializer(internal_adapter: hash64_adapter())
}

// ---------------------------------------------------------------------------
// Float helpers
// ---------------------------------------------------------------------------

// Converts a float to a JSON string, stripping the trailing ".0" that
// Erlang's float formatter adds to whole-number floats (e.g. 1.0 → "1").
fn float_to_json_str(f: Float) -> String {
  let s = float.to_string(f)
  case string.ends_with(s, ".0") {
    True -> string.drop_end(s, 2)
    False -> s
  }
}

// Returns the maximum representable Float (used in place of +Infinity,
// which is not representable in Erlang).
fn float_max() -> Float {
  1.7976931348623157e308
}

// Returns the minimum representable Float (used in place of -Infinity,
// which is not representable in Erlang).
fn float_min() -> Float {
  -1.7976931348623157e308
}

fn float_decode_json() -> decode.Decoder(Float) {
  decode.one_of(decode.float, [
    decode.int |> decode.map(int.to_float),
    decode.string
      |> decode.map(fn(s) {
        case s {
          "NaN" -> 0.0
          "Infinity" -> float_max()
          "-Infinity" -> float_min()
          _ ->
            case float.parse(s) {
              Ok(f) -> f
              Error(_) ->
                case int.parse(s) {
                  Ok(n) -> int.to_float(n)
                  Error(_) -> 0.0
                }
            }
        }
      }),
    decode.optional(decode.float)
      |> decode.map(fn(opt) { option.unwrap(opt, 0.0) }),
  ])
}

fn float32_adapter() -> type_adapter.TypeAdapter(Float) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == 0.0 },
    to_json: fn(v, _) {
      let s = float_to_json_str(v)
      case int.parse(s) {
        Ok(n) -> json.int(n)
        Error(_) -> json.float(v)
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      let s = float_to_json_str(v)
      case int.parse(s) {
        Ok(n) -> json.to_string_tree(json.int(n))
        Error(_) -> json.to_string_tree(json.float(v))
      }
    },
    decode_json: fn(_) { float_decode_json() },
    encode: fn(v, acc) {
      bytes_tree.append(acc, case v {
        0.0 -> <<0>>
        _ -> <<240, v:float-size(32)-little>>
      })
    },
    decode: fn(bits, _) {
      case bits {
        <<240, rest:bits>> ->
          case rest {
            // +Infinity: 0x7F800000 little-endian
            <<0, 0, 128, 127, remaining:bits>> -> Ok(#(float_max(), remaining))
            // -Infinity: 0xFF800000 little-endian
            <<0, 0, 128, 255, remaining:bits>> -> Ok(#(float_min(), remaining))
            <<v:float-size(32)-little, remaining:bits>> -> Ok(#(v, remaining))
            _ -> Error("truncated float32 data")
          }
        _ ->
          case decode_number(bits) {
            Ok(#(n, rest)) -> Ok(#(int.to_float(n), rest))
            Error(e) -> Error(e)
          }
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Float32),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for Float (float32) values.
pub fn float32_serializer() -> serializer_.Serializer(Float) {
  serializer_.Serializer(internal_adapter: float32_adapter())
}

fn float64_adapter() -> type_adapter.TypeAdapter(Float) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == 0.0 },
    to_json: fn(v, _) {
      let s = float_to_json_str(v)
      case int.parse(s) {
        Ok(n) -> json.int(n)
        Error(_) -> json.float(v)
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      let s = float_to_json_str(v)
      case int.parse(s) {
        Ok(n) -> json.to_string_tree(json.int(n))
        Error(_) -> json.to_string_tree(json.float(v))
      }
    },
    decode_json: fn(_) { float_decode_json() },
    encode: fn(v, acc) {
      bytes_tree.append(acc, case v {
        0.0 -> <<0>>
        _ -> <<241, v:float-size(64)-little>>
      })
    },
    decode: fn(bits, _) {
      case bits {
        <<241, rest:bits>> ->
          case rest {
            // +Infinity: 0x7FF0000000000000 little-endian
            <<0, 0, 0, 0, 0, 0, 240, 127, remaining:bits>> ->
              Ok(#(float_max(), remaining))
            // -Infinity: 0xFFF0000000000000 little-endian
            <<0, 0, 0, 0, 0, 0, 240, 255, remaining:bits>> ->
              Ok(#(float_min(), remaining))
            <<v:float-size(64)-little, remaining:bits>> -> Ok(#(v, remaining))
            _ -> Error("truncated float64 data")
          }
        _ ->
          case decode_number(bits) {
            Ok(#(n, rest)) -> Ok(#(int.to_float(n), rest))
            Error(e) -> Error(e)
          }
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Float64),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for Float (float64) values.
pub fn float64_serializer() -> serializer_.Serializer(Float) {
  serializer_.Serializer(internal_adapter: float64_adapter())
}

// ---------------------------------------------------------------------------
// Base64 and hex helpers (used by bytes_adapter)
// ---------------------------------------------------------------------------

const base64_alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

fn base64_char(i: Int) -> String {
  string.slice(base64_alphabet, i, 1)
}

fn encode_base64(bs: BitArray) -> String {
  encode_base64_acc(bs, string_tree.new()) |> string_tree.to_string
}

fn encode_base64_acc(bs: BitArray, acc) -> _ {
  case bs {
    <<>> -> acc
    <<a:size(6), b:size(6), c:size(6), d:size(6), rest:bits>> ->
      encode_base64_acc(
        rest,
        acc
          |> string_tree.append(base64_char(a))
          |> string_tree.append(base64_char(b))
          |> string_tree.append(base64_char(c))
          |> string_tree.append(base64_char(d)),
      )
    <<a:size(6), b:size(6), c:size(4)>> ->
      acc
      |> string_tree.append(base64_char(a))
      |> string_tree.append(base64_char(b))
      |> string_tree.append(base64_char(int.bitwise_shift_left(c, 2)))
      |> string_tree.append("=")
    <<a:size(6), b:size(2)>> ->
      acc
      |> string_tree.append(base64_char(a))
      |> string_tree.append(base64_char(int.bitwise_shift_left(b, 4)))
      |> string_tree.append("==")
    _ -> acc
  }
}

fn base64_char_to_int(c: Int) -> Result(Int, String) {
  case c {
    _ if c >= 65 && c <= 90 -> Ok(c - 65)
    _ if c >= 97 && c <= 122 -> Ok(c - 71)
    _ if c >= 48 && c <= 57 -> Ok(c + 4)
    43 -> Ok(62)
    47 -> Ok(63)
    _ -> Error("invalid base64 character")
  }
}

fn strip_base64_padding(s: String) -> String {
  case string.ends_with(s, "==") {
    True -> string.drop_end(s, 2)
    False ->
      case string.ends_with(s, "=") {
        True -> string.drop_end(s, 1)
        False -> s
      }
  }
}

fn decode_base64(s: String) -> Result(BitArray, String) {
  do_decode_base64(
    bit_array.from_string(strip_base64_padding(s)),
    bytes_tree.new(),
  )
}

fn do_decode_base64(chars: BitArray, acc) -> Result(BitArray, String) {
  case chars {
    <<>> -> Ok(bytes_tree.to_bit_array(acc))
    <<a, b, c, d, rest:bits>> ->
      case base64_char_to_int(a) {
        Error(e) -> Error(e)
        Ok(va) ->
          case base64_char_to_int(b) {
            Error(e) -> Error(e)
            Ok(vb) ->
              case base64_char_to_int(c) {
                Error(e) -> Error(e)
                Ok(vc) ->
                  case base64_char_to_int(d) {
                    Error(e) -> Error(e)
                    Ok(vd) -> {
                      let n =
                        int.bitwise_or(
                          int.bitwise_or(
                            int.bitwise_or(
                              int.bitwise_shift_left(va, 18),
                              int.bitwise_shift_left(vb, 12),
                            ),
                            int.bitwise_shift_left(vc, 6),
                          ),
                          vd,
                        )
                      let b1 =
                        int.bitwise_shift_right(n, 16)
                        |> int.bitwise_and(0xFF)
                      let b2 =
                        int.bitwise_shift_right(n, 8)
                        |> int.bitwise_and(0xFF)
                      let b3 = int.bitwise_and(n, 0xFF)
                      do_decode_base64(
                        rest,
                        bytes_tree.append(acc, <<b1, b2, b3>>),
                      )
                    }
                  }
              }
          }
      }
    <<a, b, c>> ->
      case base64_char_to_int(a) {
        Error(e) -> Error(e)
        Ok(va) ->
          case base64_char_to_int(b) {
            Error(e) -> Error(e)
            Ok(vb) ->
              case base64_char_to_int(c) {
                Error(e) -> Error(e)
                Ok(vc) -> {
                  let n =
                    int.bitwise_or(
                      int.bitwise_or(
                        int.bitwise_shift_left(va, 18),
                        int.bitwise_shift_left(vb, 12),
                      ),
                      int.bitwise_shift_left(vc, 6),
                    )
                  let b1 =
                    int.bitwise_shift_right(n, 16) |> int.bitwise_and(0xFF)
                  let b2 =
                    int.bitwise_shift_right(n, 8) |> int.bitwise_and(0xFF)
                  Ok(
                    bytes_tree.to_bit_array(bytes_tree.append(acc, <<b1, b2>>)),
                  )
                }
              }
          }
      }
    <<a, b>> ->
      case base64_char_to_int(a) {
        Error(e) -> Error(e)
        Ok(va) ->
          case base64_char_to_int(b) {
            Error(e) -> Error(e)
            Ok(vb) -> {
              let n =
                int.bitwise_or(
                  int.bitwise_shift_left(va, 18),
                  int.bitwise_shift_left(vb, 12),
                )
              let b1 = int.bitwise_shift_right(n, 16) |> int.bitwise_and(0xFF)
              Ok(bytes_tree.to_bit_array(bytes_tree.append(acc, <<b1>>)))
            }
          }
      }
    _ -> Error("invalid base64 data")
  }
}

fn encode_hex(bs: BitArray) -> String {
  encode_hex_acc(bs, string_tree.new()) |> string_tree.to_string
}

fn encode_hex_acc(bs: BitArray, acc) -> _ {
  case bs {
    <<>> -> acc
    <<b, rest:bits>> ->
      encode_hex_acc(
        rest,
        acc
          |> string_tree.append(hex_digit(b / 16))
          |> string_tree.append(hex_digit(b % 16)),
      )
    _ -> acc
  }
}

fn hex_digit(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    _ -> "f"
  }
}

fn decode_hex(s: String) -> Result(BitArray, String) {
  let n = string.length(s)
  case n % 2 {
    0 -> do_decode_hex(bit_array.from_string(s), bytes_tree.new())
    _ -> Error("odd hex string length: " <> int.to_string(n))
  }
}

fn do_decode_hex(bs: BitArray, acc) -> Result(BitArray, String) {
  case bs {
    <<>> -> Ok(bytes_tree.to_bit_array(acc))
    <<hi, lo, rest:bits>> ->
      case hex_char_to_int(hi) {
        Error(e) -> Error(e)
        Ok(h) ->
          case hex_char_to_int(lo) {
            Error(e) -> Error(e)
            Ok(l) -> {
              let byte = h * 16 + l
              do_decode_hex(rest, bytes_tree.append(acc, <<byte>>))
            }
          }
      }
    _ -> Error("unexpected end of hex input")
  }
}

fn hex_char_to_int(c: Int) -> Result(Int, String) {
  case c {
    _ if c >= 48 && c <= 57 -> Ok(c - 48)
    _ if c >= 65 && c <= 70 -> Ok(c - 55)
    _ if c >= 97 && c <= 102 -> Ok(c - 87)
    _ -> Error("invalid hex character")
  }
}

// ---------------------------------------------------------------------------
// String adapter
// ---------------------------------------------------------------------------

fn string_adapter() -> type_adapter.TypeAdapter(String) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == "" },
    to_json: fn(v, _) { json.string(v) },
    to_readable_json_code: fn(v, _eol_indent) {
      json.to_string_tree(json.string(v))
    },
    decode_json: fn(_) {
      decode.one_of(decode.string, [
        decode.int |> decode.map(fn(_) { "" }),
        decode.float |> decode.map(fn(_) { "" }),
        decode.optional(decode.string)
          |> decode.map(fn(opt) { option.unwrap(opt, "") }),
      ])
    },
    encode: fn(v, acc) {
      case v {
        "" -> bytes_tree.append(acc, <<242>>)
        _ -> {
          let bs = bit_array.from_string(v)
          let len = bit_array.byte_size(bs)
          acc
          |> bytes_tree.append(<<243>>)
          |> bytes_tree.append(encode_uint64(len))
          |> bytes_tree.append(bs)
        }
      }
    },
    decode: fn(bits, _) {
      case bits {
        <<wire, rest:bits>> ->
          case wire {
            0 | 242 -> Ok(#("", rest))
            _ ->
              case decode_number(rest) {
                Error(e) -> Error(e)
                Ok(#(n, after_len)) ->
                  case n {
                    0 -> Ok(#("", after_len))
                    _ ->
                      case after_len {
                        <<data:bytes-size(n), remaining:bits>> ->
                          case bit_array.to_string(data) {
                            Ok(s) -> Ok(#(s, remaining))
                            Error(_) -> Error("invalid UTF-8 in string data")
                          }
                        _ -> Error("not enough data for string field")
                      }
                  }
              }
          }
        _ -> Error("unexpected end of input")
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.StringType),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for String values.
pub fn string_serializer() -> serializer_.Serializer(String) {
  serializer_.Serializer(internal_adapter: string_adapter())
}

// ---------------------------------------------------------------------------
// Bytes adapter
// ---------------------------------------------------------------------------

fn bytes_adapter() -> type_adapter.TypeAdapter(BitArray) {
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == <<>> },
    to_json: fn(v, readable) {
      case readable {
        type_adapter.Readable -> json.string("hex:" <> encode_hex(v))
        type_adapter.Dense -> json.string(encode_base64(v))
      }
    },
    to_readable_json_code: fn(v, _eol_indent) {
      json.to_string_tree(json.string("hex:" <> encode_hex(v)))
    },
    decode_json: fn(_) {
      decode.one_of(
        decode.string
          |> decode.then(fn(s) {
            let r = case string.starts_with(s, "hex:") {
              True -> decode_hex(string.drop_start(s, 4))
              False -> decode_base64(s)
            }
            case r {
              Ok(bs) -> decode.success(bs)
              Error(e) -> decode.failure(<<>>, e)
            }
          }),
        [
          decode.int |> decode.map(fn(_) { <<>> }),
          decode.float |> decode.map(fn(_) { <<>> }),
          decode.optional(decode.string) |> decode.map(fn(_) { <<>> }),
        ],
      )
    },
    encode: fn(v, acc) {
      case v {
        <<>> -> bytes_tree.append(acc, <<244>>)
        _ -> {
          let len = bit_array.byte_size(v)
          acc
          |> bytes_tree.append(<<245>>)
          |> bytes_tree.append(encode_uint64(len))
          |> bytes_tree.append(v)
        }
      }
    },
    decode: fn(bits, _) {
      case bits {
        <<wire, rest:bits>> ->
          case wire {
            0 | 244 -> Ok(#(<<>>, rest))
            _ ->
              case decode_number(rest) {
                Error(e) -> Error(e)
                Ok(#(n, after_len)) ->
                  case n {
                    0 -> Ok(#(<<>>, after_len))
                    _ ->
                      case after_len {
                        <<data:bytes-size(n), remaining:bits>> ->
                          Ok(#(data, remaining))
                        _ -> Error("not enough data for bytes field")
                      }
                  }
              }
          }
        _ -> Error("unexpected end of input")
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Bytes),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for BitArray (bytes) values.
pub fn bytes_serializer() -> serializer_.Serializer(BitArray) {
  serializer_.Serializer(internal_adapter: bytes_adapter())
}

// ---------------------------------------------------------------------------
// Timestamp helpers
// ---------------------------------------------------------------------------

// Encodes unix milliseconds. Values in i32 range reuse i32 encoding;
// others use wire 239 (decoded identically to wire 238, 64-bit signed LE).
fn encode_timestamp(ms: Int) -> BitArray {
  case ms >= -2_147_483_648 && ms <= 2_147_483_647 {
    True -> encode_i32(ms)
    False -> {
      let u = int.bitwise_and(ms, 0xFFFF_FFFF_FFFF_FFFF)
      <<239, u:size(64)-little>>
    }
  }
}

fn timestamp_adapter() -> type_adapter.TypeAdapter(skir_timestamp.Timestamp) {
  let parse_millis_string = fn(s) {
    case int.parse(s) {
      Ok(n) -> n
      Error(_) ->
        case float.parse(s) {
          Ok(f) -> float.round(f)
          Error(_) -> 0
        }
    }
  }
  type_adapter.TypeAdapter(
    is_default: fn(v: skir_timestamp.Timestamp) { v.unix_millis == 0 },
    to_json: fn(v: skir_timestamp.Timestamp, readable) {
      let ms = v.unix_millis
      case readable {
        type_adapter.Dense -> json.int(ms)
        type_adapter.Readable -> {
          let iso =
            gleam_timestamp.to_rfc3339(
              skir_timestamp.to_gleam_timestamp(v),
              calendar.utc_offset,
            )
          json.object([
            #("unix_millis", json.int(ms)),
            #("formatted", json.string(iso)),
          ])
        }
      }
    },
    to_readable_json_code: fn(v: skir_timestamp.Timestamp, eol_indent) {
      let ms = v.unix_millis
      let iso =
        gleam_timestamp.to_rfc3339(
          skir_timestamp.to_gleam_timestamp(v),
          calendar.utc_offset,
        )
      json_utils.readable_json_object(
        [
          #("unix_millis", json.to_string_tree(json.int(ms))),
          #("formatted", json.to_string_tree(json.string(iso))),
        ],
        eol_indent,
      )
    },
    decode_json: fn(_) {
      decode.one_of(
        decode.int
          |> decode.map(fn(ms) { skir_timestamp.Timestamp(unix_millis: ms) }),
        [
          decode.float
            |> decode.map(fn(f) {
              skir_timestamp.Timestamp(unix_millis: float.round(f))
            }),
          {
            use unix_millis <- decode.field("unix_millis", decode.int)
            decode.success(skir_timestamp.Timestamp(unix_millis: unix_millis))
          },
          decode.string
            |> decode.map(fn(s) {
              skir_timestamp.Timestamp(unix_millis: parse_millis_string(s))
            }),
          decode.optional(decode.int)
            |> decode.map(fn(opt) {
              skir_timestamp.Timestamp(unix_millis: option.unwrap(opt, 0))
            }),
        ],
      )
    },
    encode: fn(v: skir_timestamp.Timestamp, acc) {
      bytes_tree.append(acc, encode_timestamp(v.unix_millis))
    },
    decode: fn(bits, _) {
      case decode_number(bits) {
        Ok(#(ms, rest)) ->
          Ok(#(skir_timestamp.Timestamp(unix_millis: ms), rest))
        Error(e) -> Error(e)
      }
    },
    type_descriptor: fn() {
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Primitive(type_descriptor.Timestamp),
        records: dict.new(),
      )
    },
  )
}

/// Returns the serializer for Timestamp values.
pub fn timestamp_serializer() -> serializer_.Serializer(
  skir_timestamp.Timestamp,
) {
  serializer_.Serializer(internal_adapter: timestamp_adapter())
}

// =============================================================================
// Composite Serializers
// =============================================================================

fn optional_adapter(
  item_serializer: serializer_.Serializer(a),
) -> type_adapter.TypeAdapter(Option(a)) {
  let item = item_serializer.internal_adapter
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == None },
    to_json: fn(v, readable) {
      case v {
        None -> json.null()
        Some(x) -> item.to_json(x, readable)
      }
    },
    to_readable_json_code: fn(v, eol_indent) {
      case v {
        None -> json.to_string_tree(json.null())
        Some(x) -> item.to_readable_json_code(x, eol_indent)
      }
    },
    decode_json: fn(keep) { decode.optional(item.decode_json(keep)) },
    encode: fn(v, acc) {
      case v {
        None -> bytes_tree.append(acc, <<255>>)
        Some(x) -> item.encode(x, bytes_tree.append(acc, <<1>>))
      }
    },
    decode: fn(bits, keep) {
      case bits {
        <<0, rest:bits>> -> Ok(#(None, rest))
        <<255, rest:bits>> -> Ok(#(None, rest))
        <<1, rest:bits>> ->
          case item.decode(rest, keep) {
            Ok(#(x, remaining)) -> Ok(#(Some(x), remaining))
            Error(e) -> Error(e)
          }
        _ -> Error("expected 0, 1, or 255 byte for optional tag")
      }
    },
    type_descriptor: fn() {
      let item_td = item.type_descriptor()
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Optional(item_td.type_sig),
        records: item_td.records,
      )
    },
  )
}

/// Returns a serializer for Option(a) values.
pub fn optional_serializer(
  item_serializer: serializer_.Serializer(a),
) -> serializer_.Serializer(Option(a)) {
  serializer_.Serializer(internal_adapter: optional_adapter(item_serializer))
}

fn recursive_adapter(
  item_serializer: serializer_.Serializer(a),
) -> type_adapter.TypeAdapter(recursive.Recursive(a)) {
  let item = item_serializer.internal_adapter
  type_adapter.TypeAdapter(
    is_default: fn(v) {
      case v {
        recursive.Default -> True
        recursive.Some(x) -> item.is_default(x)
      }
    },
    to_json: fn(v, readable) {
      case v {
        recursive.Default ->
          case readable {
            type_adapter.Readable -> json.object([])
            type_adapter.Dense -> json.preprocessed_array([])
          }
        recursive.Some(x) -> item.to_json(x, readable)
      }
    },
    to_readable_json_code: fn(v, eol_indent) {
      case v {
        recursive.Default -> json.to_string_tree(json.object([]))
        recursive.Some(x) -> item.to_readable_json_code(x, eol_indent)
      }
    },
    decode_json: fn(keep) {
      item.decode_json(keep) |> decode.map(recursive.Some)
    },
    encode: fn(v, acc) {
      case v {
        // In struct slot encoding, preceding default values still need an on-wire
        // placeholder when a later slot is active. For recursive struct fields,
        // that placeholder is the default empty-struct wire byte.
        recursive.Default -> bytes_tree.append(acc, <<246>>)
        recursive.Some(x) -> item.encode(x, acc)
      }
    },
    decode: fn(bits, keep) {
      case item.decode(bits, keep) {
        Ok(#(x, remaining)) -> Ok(#(recursive.Some(x), remaining))
        Error(e) -> Error(e)
      }
    },
    type_descriptor: fn() { item.type_descriptor() },
  )
}

/// Returns a serializer for Recursive(a) values.
pub fn recursive_serializer(
  item_serializer: serializer_.Serializer(a),
) -> serializer_.Serializer(recursive.Recursive(a)) {
  serializer_.Serializer(internal_adapter: recursive_adapter(item_serializer))
}

fn list_adapter(
  item_serializer: serializer_.Serializer(a),
  key_extractor: String,
) -> type_adapter.TypeAdapter(List(a)) {
  let item = item_serializer.internal_adapter
  type_adapter.TypeAdapter(
    is_default: fn(v) { v == [] },
    to_json: fn(v, readable) {
      json.array(v, fn(item_val) { item.to_json(item_val, readable) })
    },
    to_readable_json_code: fn(v, eol_indent) {
      let child_indent = eol_indent <> "  "
      readable_json_array(
        list.map(v, fn(item_val) {
          item.to_readable_json_code(item_val, child_indent)
        }),
        eol_indent,
      )
    },
    decode_json: fn(keep) {
      decode.one_of(decode.list(item.decode_json(keep)), [
        decode.int |> decode.map(fn(_) { [] }),
      ])
    },
    encode: fn(v, acc) {
      let count = list.fold(v, 0, fn(n, _) { n + 1 })
      let acc = bytes_tree.append(acc, encode_list_count(count))
      list.fold(v, acc, fn(bytes_acc, item_val) {
        item.encode(item_val, bytes_acc)
      })
    },
    decode: fn(bits, keep) {
      case decode_list_count(bits) {
        Error(e) -> Error(e)
        Ok(#(count, rest)) -> decode_list_items(item, count, rest, keep, [])
      }
    },
    type_descriptor: fn() {
      let item_td = item.type_descriptor()
      type_descriptor.TypeDescriptor(
        type_sig: type_descriptor.Array(
          item_type: item_td.type_sig,
          key_extractor: key_extractor,
        ),
        records: item_td.records,
      )
    },
  )
}

/// Returns a serializer for List(a) values.
pub fn list_serializer(
  item_serializer: serializer_.Serializer(a),
) -> serializer_.Serializer(List(a)) {
  keyed_list_serializer(item_serializer, "")
}

pub fn keyed_list_serializer(
  item_serializer: serializer_.Serializer(a),
  key_extractor: String,
) -> serializer_.Serializer(List(a)) {
  serializer_.Serializer(internal_adapter: list_adapter(
    item_serializer,
    key_extractor,
  ))
}

// =============================================================================
// Internal helpers
// =============================================================================

// Encodes a list count using the slot-count wire format:
// 0 → 246, 1 → 247, 2 → 248, 3 → 249, n>3 → 250 + encode_uint32(n)
fn encode_list_count(n: Int) -> BitArray {
  case n {
    0 -> <<246>>
    1 -> <<247>>
    2 -> <<248>>
    3 -> <<249>>
    _ -> bit_array.append(<<250>>, encode_uint32(n))
  }
}

fn encode_uint32(n: Int) -> BitArray {
  case n {
    _ if n <= 231 -> <<n>>
    _ if n <= 65_535 -> <<232, n:size(16)-little>>
    _ -> <<233, n:size(32)-little>>
  }
}

// Decodes a list count from the slot-count wire format (246-250) or legacy
// uint64 format (0-234).
fn decode_list_count(bits: BitArray) -> Result(#(Int, BitArray), String) {
  case bits {
    <<w, rest:bits>> ->
      case w {
        246 -> Ok(#(0, rest))
        247 -> Ok(#(1, rest))
        248 -> Ok(#(2, rest))
        249 -> Ok(#(3, rest))
        250 ->
          case decode_number(rest) {
            Error(e) -> Error(e)
            Ok(#(n, rest2)) -> Ok(#(n, rest2))
          }
        // Legacy: 0-231 single byte count
        _ if w <= 231 -> Ok(#(w, rest))
        232 ->
          case rest {
            <<v:size(16)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input in decode_list_count")
          }
        233 ->
          case rest {
            <<v:size(32)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input in decode_list_count")
          }
        234 ->
          case rest {
            <<v:size(64)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input in decode_list_count")
          }
        _ ->
          Error(
            "unexpected wire byte in decode_list_count: " <> int.to_string(w),
          )
      }
    _ -> Error("unexpected end of input in decode_list_count")
  }
}

fn readable_json_array(
  items: List(string_tree.StringTree),
  eol_indent: String,
) -> string_tree.StringTree {
  case items {
    [] -> string_tree.from_string("[]")
    _ -> {
      let child_indent = eol_indent <> "  "
      let indented_items =
        list.map(items, fn(item) {
          string_tree.concat([
            string_tree.from_string(child_indent),
            item,
          ])
        })
      string_tree.concat([
        string_tree.from_string("["),
        string_tree.join(indented_items, ","),
        string_tree.from_string(eol_indent <> "]"),
      ])
    }
  }
}

fn decode_list_items(
  item: type_adapter.TypeAdapter(a),
  count: Int,
  bits: BitArray,
  keep: type_adapter.UnrecognizedValues,
  acc: List(a),
) -> Result(#(List(a), BitArray), String) {
  case count {
    0 -> Ok(#(list.reverse(acc), bits))
    _ ->
      case item.decode(bits, keep) {
        Error(e) -> Error(e)
        Ok(#(v, rest)) ->
          decode_list_items(item, count - 1, rest, keep, [v, ..acc])
      }
  }
}
