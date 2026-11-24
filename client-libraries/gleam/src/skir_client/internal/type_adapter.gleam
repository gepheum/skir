import gleam/bytes_tree.{type BytesTree}
import gleam/dynamic/decode
import gleam/json
import gleam/string_tree
import skir_client/type_descriptor.{type TypeDescriptor}

// =============================================================================
// UnrecognizedValues
// =============================================================================

/// Controls whether unrecognized fields/variants encountered during
/// deserialization are preserved for round-tripping.
pub type UnrecognizedValues {
  /// Preserve unrecognized fields/variants so they survive a round-trip.
  Keep
  /// Discard unrecognized fields/variants.
  Drop
}

/// Selects which JSON representation to produce.
pub type JsonFlavor {
  Dense
  Readable
}

// =============================================================================
// TypeAdapter
// =============================================================================

/// An internal adapter that provides the type-specific logic for serialization
/// and deserialization. Used by `Serializer`.
pub type TypeAdapter(a) {
  TypeAdapter(
    is_default: fn(a) -> Bool,
    to_json: fn(a, JsonFlavor) -> json.Json,
    to_readable_json_code: fn(a, String) -> string_tree.StringTree,
    decode_json: fn(UnrecognizedValues) -> decode.Decoder(a),
    encode: fn(a, BytesTree) -> BytesTree,
    decode: fn(BitArray, UnrecognizedValues) -> Result(#(a, BitArray), String),
    type_descriptor: fn() -> TypeDescriptor,
  )
}
