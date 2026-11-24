import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string_tree
import skir_client/internal/json_utils
import skir_client/internal/type_adapter
import skir_client/type_descriptor.{type TypeDescriptor}

// =============================================================================
// Serializer
// =============================================================================

/// A value that can serialize and deserialize values of type `a` to/from JSON
/// and binary formats.
///
/// Do not construct this directly, use the `*_serializer()` functions.
pub type Serializer(a) {
  Serializer(internal_adapter: type_adapter.TypeAdapter(a))
}

// =============================================================================
// Core serialization API
// =============================================================================

/// Serializes a value to dense (field-index-based) JSON value.
pub fn to_dense_json(serializer: Serializer(a), value: a) -> json.Json {
  serializer.internal_adapter.to_json(value, type_adapter.Dense)
}

/// Serializes a value to dense (field-index-based) JSON code.
/// Dense JSON is safe for persistent storage: renaming a field does not break
/// deserialization.
pub fn to_dense_json_code(serializer: Serializer(a), value: a) -> String {
  serializer.internal_adapter.to_json(value, type_adapter.Dense)
  |> json.to_string()
}

/// Serializes a value to readable (field-name-based) JSON value.
pub fn to_readable_json(serializer: Serializer(a), value: a) -> json.Json {
  serializer.internal_adapter.to_json(value, type_adapter.Readable)
}

/// Serializes a value to readable (field-name-based, indented) JSON code.
/// Uses 2-space indentation.
pub fn to_readable_json_code(serializer: Serializer(a), value: a) -> String {
  serializer.internal_adapter.to_readable_json_code(value, "\n")
  |> string_tree.to_string
}

/// Deserializes a value from a JSON string. Accepts both dense and readable
/// JSON. Unrecognized fields are dropped.
pub fn from_json_code(
  serializer: Serializer(a),
  json_code: String,
) -> Result(a, String) {
  from_json_code_with_options(
    serializer,
    json_code,
    keep_unrecognized_values: False,
  )
}

/// Deserializes a value from a JSON string.
/// When `keep_unrecognized_values` is `True`, field data that this client
/// does not recognise is preserved in `unrecognized_fields_` so that
/// re-serializing the value does not silently discard forward-compatible
/// fields.
pub fn from_json_code_with_options(
  serializer: Serializer(a),
  json_code: String,
  keep_unrecognized_values keep_unrecognized_values: Bool,
) -> Result(a, String) {
  let keep = bool_to_keep_unrecognized_values(keep_unrecognized_values)
  use d <- result.try(parse_json_code_to_dynamic(json_code))
  decode.run(d, serializer.internal_adapter.decode_json(keep))
  |> result.map_error(json_utils.decode_errors_to_string)
}

/// Returns a JSON decoder for this serializer (Drop mode).
pub fn json_decoder(serializer: Serializer(a)) -> decode.Decoder(a) {
  json_decoder_with_options(serializer, keep_unrecognized_values: False)
}

/// Returns a JSON decoder for this serializer with configurable keep/drop mode.
pub fn json_decoder_with_options(
  serializer: Serializer(a),
  keep_unrecognized_values keep_unrecognized_values: Bool,
) -> decode.Decoder(a) {
  let keep = bool_to_keep_unrecognized_values(keep_unrecognized_values)
  serializer.internal_adapter.decode_json(keep)
}

/// Serializes a value to a compact binary format.
pub fn to_bytes(serializer: Serializer(a), value: a) -> BitArray {
  bytes_tree.from_string("skir")
  |> serializer.internal_adapter.encode(value, _)
  |> bytes_tree.to_bit_array()
}

/// Deserializes a value from binary format. Unrecognized fields are dropped.
pub fn from_bytes(
  serializer: Serializer(a),
  bytes: BitArray,
) -> Result(a, String) {
  from_bytes_with_options(serializer, bytes, keep_unrecognized_values: False)
}

/// Deserializes a value from binary format.
/// When `keep_unrecognized_values` is `True`, field data that this client
/// does not recognise is preserved in `unrecognized_fields_`.
pub fn from_bytes_with_options(
  serializer: Serializer(a),
  bytes: BitArray,
  keep_unrecognized_values keep_unrecognized_values: Bool,
) -> Result(a, String) {
  let keep = bool_to_keep_unrecognized_values(keep_unrecognized_values)
  case bytes {
    <<115, 107, 105, 114, rest:bits>> ->
      case serializer.internal_adapter.decode(rest, keep) {
        Ok(#(value, _)) -> Ok(value)
        Error(e) -> Error(e)
      }
    _ ->
      case bit_array.to_string(bytes) {
        Ok(s) ->
          from_json_code_with_options(
            serializer,
            s,
            keep_unrecognized_values: keep_unrecognized_values,
          )
        Error(_) -> Error("invalid bytes: not skir binary and not valid UTF-8")
      }
  }
}

/// Returns the TypeDescriptor for the type this serializer handles.
pub fn type_descriptor(serializer: Serializer(a)) -> TypeDescriptor {
  serializer.internal_adapter.type_descriptor()
}

// =============================================================================
// Internal helpers
// =============================================================================

fn json_decode_error_to_string(e: json.DecodeError) -> String {
  case e {
    json.UnexpectedEndOfInput -> "unexpected end of JSON input"
    json.UnexpectedByte(b) -> "unexpected byte in JSON: " <> b
    json.UnexpectedSequence(s) -> "unexpected sequence in JSON: " <> s
    json.UnableToDecode(_) -> "unable to decode JSON value"
  }
}

fn parse_json_code_to_dynamic(
  json_code: String,
) -> Result(dynamic.Dynamic, String) {
  case json.parse(from: json_code, using: decode.dynamic) {
    Ok(d) -> Ok(d)
    Error(e) -> Error(json_decode_error_to_string(e))
  }
}

fn bool_to_keep_unrecognized_values(
  keep_unrecognized_values: Bool,
) -> type_adapter.UnrecognizedValues {
  case keep_unrecognized_values {
    True -> type_adapter.Keep
    False -> type_adapter.Drop
  }
}
