import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/time/timestamp as gleam_timestamp
import skir_client/recursive
import skir_client/serializer as serializer_
import skir_client/serializers as serializers_
import skir_client/timestamp
import skir_client/type_descriptor.{type TypeDescriptor}

/// A value that can serialize and deserialize values of type `a` to/from JSON
/// and binary formats.
///
/// Do not construct this directly, use the `*_serializer()` functions.
pub type Serializer(a) =
  serializer_.Serializer(a)

/// Serializes a value to dense (field-index-based) JSON value.
pub fn to_dense_json(serializer: Serializer(a), value: a) -> json.Json {
  serializer_.to_dense_json(serializer, value)
}

/// Serializes a value to dense (field-index-based) JSON code.
/// Dense JSON is safe for persistent storage: renaming a field does not break
/// deserialization.
pub fn to_dense_json_code(serializer: Serializer(a), value: a) -> String {
  serializer_.to_dense_json_code(serializer, value)
}

/// Serializes a value to readable (field-name-based) JSON value.
pub fn to_readable_json(serializer: Serializer(a), value: a) -> json.Json {
  serializer_.to_readable_json(serializer, value)
}

/// Serializes a value to readable (field-name-based, indented) JSON code.
/// Uses 2-space indentation.
pub fn to_readable_json_code(serializer: Serializer(a), value: a) -> String {
  serializer_.to_readable_json_code(serializer, value)
}

/// Deserializes a value from a JSON string. Accepts both dense and readable
/// JSON. Unrecognized fields are dropped.
pub fn from_json_code(
  serializer: Serializer(a),
  json_code: String,
) -> Result(a, String) {
  serializer_.from_json_code(serializer, json_code)
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
  serializer_.from_json_code_with_options(
    serializer,
    json_code,
    keep_unrecognized_values: keep_unrecognized_values,
  )
}

/// Returns a JSON decoder for this serializer (Drop mode).
pub fn json_decoder(serializer: Serializer(a)) -> decode.Decoder(a) {
  serializer_.json_decoder(serializer)
}

/// Returns a JSON decoder for this serializer with configurable keep/drop mode.
pub fn json_decoder_with_options(
  serializer: Serializer(a),
  keep_unrecognized_values keep_unrecognized_values: Bool,
) -> decode.Decoder(a) {
  serializer_.json_decoder_with_options(
    serializer,
    keep_unrecognized_values: keep_unrecognized_values,
  )
}

/// Serializes a value to a compact binary format.
pub fn to_bytes(serializer: Serializer(a), value: a) -> BitArray {
  serializer_.to_bytes(serializer, value)
}

/// Deserializes a value from binary format. Unrecognized fields are dropped.
pub fn from_bytes(
  serializer: Serializer(a),
  bytes: BitArray,
) -> Result(a, String) {
  serializer_.from_bytes(serializer, bytes)
}

/// Deserializes a value from binary format.
/// When `keep_unrecognized_values` is `True`, field data that this client
/// does not recognise is preserved in `unrecognized_fields_`.
pub fn from_bytes_with_options(
  serializer: Serializer(a),
  bytes: BitArray,
  keep_unrecognized_values keep_unrecognized_values: Bool,
) -> Result(a, String) {
  serializer_.from_bytes_with_options(
    serializer,
    bytes,
    keep_unrecognized_values: keep_unrecognized_values,
  )
}

/// Returns the TypeDescriptor for the type this serializer handles.
pub fn type_descriptor(serializer: Serializer(a)) -> TypeDescriptor {
  serializer_.type_descriptor(serializer)
}

/// Returns the serializer for Bool values.
pub fn bool_serializer() -> Serializer(Bool) {
  serializers_.bool_serializer()
}

/// Returns the serializer for Int (int32) values.
pub fn int32_serializer() -> Serializer(Int) {
  serializers_.int32_serializer()
}

/// Returns the serializer for Int (int64) values.
pub fn int64_serializer() -> Serializer(Int) {
  serializers_.int64_serializer()
}

/// Returns the serializer for Int (hash64) values.
pub fn hash64_serializer() -> Serializer(Int) {
  serializers_.hash64_serializer()
}

/// Returns the serializer for Float (float32) values.
pub fn float32_serializer() -> Serializer(Float) {
  serializers_.float32_serializer()
}

/// Returns the serializer for Float (float64) values.
pub fn float64_serializer() -> Serializer(Float) {
  serializers_.float64_serializer()
}

/// Returns the serializer for String values.
pub fn string_serializer() -> Serializer(String) {
  serializers_.string_serializer()
}

/// Returns the serializer for BitArray (bytes) values.
pub fn bytes_serializer() -> Serializer(BitArray) {
  serializers_.bytes_serializer()
}

/// Returns the serializer for Timestamp values.
pub fn timestamp_serializer() -> Serializer(Timestamp) {
  serializers_.timestamp_serializer()
}

/// Returns a serializer for Option(a) values.
pub fn optional_serializer(
  item_serializer: Serializer(a),
) -> Serializer(Option(a)) {
  serializers_.optional_serializer(item_serializer)
}

/// Returns a serializer for Recursive(a) values.
pub fn recursive_serializer(
  item_serializer: Serializer(a),
) -> Serializer(recursive.Recursive(a)) {
  serializers_.recursive_serializer(item_serializer)
}

/// Returns a serializer for List(a) values.
pub fn list_serializer(item_serializer: Serializer(a)) -> Serializer(List(a)) {
  serializers_.list_serializer(item_serializer)
}

/// Returns a keyed serializer for List(a) values.
pub fn keyed_list_serializer(
  item_serializer: Serializer(a),
  key_extractor: String,
) -> Serializer(List(a)) {
  serializers_.keyed_list_serializer(item_serializer, key_extractor)
}

/// A timestamp represented as milliseconds since the Unix epoch
/// (1970-01-01T00:00:00Z).
pub type Timestamp =
  timestamp.Timestamp

/// The default Timestamp: the Unix epoch (1970-01-01T00:00:00Z).
pub const unix_epoch = timestamp.unix_epoch

/// Converts a Skir Timestamp to a Gleam Timestamp.
pub fn to_gleam_timestamp(t: Timestamp) -> gleam_timestamp.Timestamp {
  timestamp.to_gleam_timestamp(t)
}

/// Converts a Gleam Timestamp to a Skir Timestamp.
pub fn from_gleam_timestamp(t: gleam_timestamp.Timestamp) -> Timestamp {
  timestamp.from_gleam_timestamp(t)
}
