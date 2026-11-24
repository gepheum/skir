import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/string_tree
import skir_client/internal/decode_utils
import skir_client/internal/json_utils
import skir_client/internal/type_adapter
import skir_client/internal/unrecognized
import skir_client/serializer
import skir_client/type_descriptor

/// Stores an unrecognized variant encountered while deserializing an enum of
/// type `t`.
pub type UnrecognizedVariant(e) {
  None
  Some(UnrecognizedVariantData(e))
}

pub opaque type UnrecognizedVariantData(e) {
  UnrecognizedVariantData(
    format: unrecognized.UnrecognizedFormat,
    number: Int,
    value: BitArray,
    phantom_t: List(e),
  )
}

fn variant_data_from_bytes(
  number: Int,
  raw_bytes: BitArray,
) -> UnrecognizedVariantData(e) {
  UnrecognizedVariantData(
    format: unrecognized.BinaryBytes,
    number:,
    value: raw_bytes,
    phantom_t: [],
  )
}

fn variant_data_from_json(
  number: Int,
  json_bytes: BitArray,
) -> UnrecognizedVariantData(e) {
  UnrecognizedVariantData(
    format: unrecognized.DenseJson,
    number:,
    value: json_bytes,
    phantom_t: [],
  )
}

// =============================================================================
// VariantAdapter
// =============================================================================

/// A type-erased adapter for a single enum variant, used by `new_serializer`.
///
/// Build one with `constant_variant` or `wrapper_variant`.
pub type VariantAdapter(e) {
  VariantAdapter(
    name: String,
    number: Int,
    doc: String,
    /// For constant variants: `Some(value)`. For wrapper variants: `None`.
    constant: Option(e),
    /// JSON representation of this variant.
    /// The given enum value MUST be this variant.
    to_json: fn(e, type_adapter.JsonFlavor) -> json.Json,
    /// Readable JSON code representation of this variant.
    to_readable_json_code: fn(e, String) -> string_tree.StringTree,
    /// For wrapper variants: decodes the payload JSON into `e`.
    /// For constant variants: returns `Ok(instance)` unconditionally.
    wrap_from_json: fn(type_adapter.UnrecognizedValues) -> decode.Decoder(e),
    /// For wrapper variants: encodes the payload onto the tree.
    /// For constant variants: returns the tree unchanged.
    encode_payload: fn(e, BytesTree) -> BytesTree,
    /// For wrapper variants: decodes the payload from binary (header already consumed).
    /// For constant variants: returns `Ok(#(instance, bits))` unconditionally.
    wrap_decode: fn(BitArray, type_adapter.UnrecognizedValues) ->
      Result(#(e, BitArray), String),
    /// For wrapper variants: returns `Some(default_value)` via the inner
    /// serializer's zero default (used when a wrapper number appears in a
    /// constant-only context).
    /// For constant variants: returns `None`.
    wrap_default: fn() -> Option(e),
    /// For wrapper variants: returns `Some(TypeDescriptor)` for the inner type.
    /// For constant variants: returns `None`.
    type_descriptor: fn() -> Option(type_descriptor.TypeDescriptor),
  )
}

// =============================================================================
// constant_variant / wrapper_variant constructors
// =============================================================================

/// Creates a `VariantAdapter` for a constant (payload-less) enum variant.
pub fn constant_variant(
  name name: String,
  number number: Int,
  doc doc: String,
  instance instance: e,
) -> VariantAdapter(e) {
  VariantAdapter(
    name:,
    number:,
    doc:,
    constant: option.Some(instance),
    to_json: fn(_e, readable) {
      case readable {
        type_adapter.Dense -> json.int(number)
        type_adapter.Readable -> json.string(name)
      }
    },
    to_readable_json_code: fn(_e, _eol_indent) {
      json.to_string_tree(json.string(name))
    },
    wrap_from_json: fn(_keep) { decode.success(instance) },
    encode_payload: fn(_e, tree) { tree },
    wrap_decode: fn(bits, _keep) { Ok(#(instance, bits)) },
    wrap_default: fn() { option.None },
    type_descriptor: fn() { option.None },
  )
}

/// Creates a `VariantAdapter` for a wrapper (payload-carrying) enum variant.
///
/// The optional `type_sig` parameter is used for recursive variant types to
/// avoid infinite recursion when computing the type descriptor. When provided,
/// the type descriptor for this variant returns `Some(TypeDescriptor(type_sig,
/// {}))` directly instead of calling `serializer_fn().internal_adapter.type_descriptor()`.
pub fn wrapper_variant(
  name name: String,
  number number: Int,
  doc doc: String,
  serializer serializer_fn: fn() -> serializer.Serializer(v),
  type_sig type_sig: Option(type_descriptor.TypeSignature),
  wrap wrap: fn(v) -> e,
  unwrap unwrap: fn(e) -> v,
) -> VariantAdapter(e) {
  VariantAdapter(
    name:,
    number:,
    doc:,
    constant: option.None,
    to_json: fn(e, readable) {
      let ta = serializer_fn().internal_adapter
      let v = unwrap(e)
      case readable {
        type_adapter.Dense ->
          json.preprocessed_array([
            json.int(number),
            ta.to_json(v, type_adapter.Dense),
          ])
        type_adapter.Readable -> {
          json.object([
            #("kind", json.string(name)),
            #("value", ta.to_json(v, type_adapter.Readable)),
          ])
        }
      }
    },
    to_readable_json_code: fn(e, eol_indent) {
      let ta = serializer_fn().internal_adapter
      let v = unwrap(e)
      let child_indent = eol_indent <> "  "
      json_utils.readable_json_object(
        [
          #("kind", json.to_string_tree(json.string(name))),
          #("value", ta.to_readable_json_code(v, child_indent)),
        ],
        eol_indent,
      )
    },
    wrap_from_json: fn(keep) {
      let ta = serializer_fn().internal_adapter
      decode.map(ta.decode_json(keep), wrap)
    },
    encode_payload: fn(e, tree) {
      let ta = serializer_fn().internal_adapter
      ta.encode(unwrap(e), tree)
    },
    wrap_decode: fn(bits, keep) {
      let ta = serializer_fn().internal_adapter
      case ta.decode(bits, keep) {
        Ok(#(v, rest)) -> Ok(#(wrap(v), rest))
        Error(e) -> Error(e)
      }
    },
    wrap_default: fn() {
      let ta = serializer_fn().internal_adapter
      case ta.decode(<<0>>, type_adapter.Drop) {
        Ok(#(v, _)) -> option.Some(wrap(v))
        Error(_) -> option.None
      }
    },
    type_descriptor: fn() {
      case type_sig {
        option.None ->
          option.Some(serializer_fn().internal_adapter.type_descriptor())
        option.Some(sig) ->
          option.Some(type_descriptor.TypeDescriptor(
            type_sig: sig,
            records: dict.new(),
          ))
      }
    },
  )
}

// =============================================================================
// new_serializer
// =============================================================================

/// Builds a `Serializer` for a Skir enum type.
///
/// For use only by code generated by the Skir Gleam code generator.
///
/// Parameters:
/// - `variants`: variant adapters in declaration order (kind ordinal 1..N).
///   Must NOT include the implicit Unknown variant (ordinal 0).
/// - `get_kind_ordinal`: maps an enum value to its kind ordinal: 0 for the
///   Unknown variant, 1 for the first declared variant, and so on.
/// - `wrap_unrecognized`: wraps an `UnrecognizedVariant(e)` into the Unknown
///   constructor.
/// - `get_unrecognized`: extracts the `UnrecognizedVariant(e)` from the
///   Unknown constructor; returns `None` for any other constructor.
pub fn new_serializer(
  name name: String,
  qualified_name qualified_name: String,
  module_path module_path: String,
  doc doc: String,
  variants variants: List(VariantAdapter(e)),
  unknown_default unknown_default: e,
  get_kind_ordinal get_kind_ordinal: fn(e) -> Int,
  wrap_unrecognized wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  get_unrecognized get_unrecognized: fn(e) -> UnrecognizedVariant(e),
  removed_numbers removed_numbers: List(Int),
) -> serializer.Serializer(e) {
  let variants_by_number =
    list.fold(variants, dict.new(), fn(acc, v) { dict.insert(acc, v.number, v) })
  let variants_by_name =
    list.fold(variants, dict.new(), fn(acc, v) { dict.insert(acc, v.name, v) })
  let variants_by_name_lower =
    list.fold(variants, dict.new(), fn(acc, v) {
      dict.insert(acc, string.lowercase(v.name), v)
    })
  serializer.Serializer(
    internal_adapter: type_adapter.TypeAdapter(
      is_default: fn(e) {
        case get_kind_ordinal(e) {
          0 ->
            case get_unrecognized(e) {
              None -> True
              Some(_) -> False
            }
          _ -> False
        }
      },
      to_json: fn(e, readable) {
        enum_append_json(
          variants,
          get_kind_ordinal,
          get_unrecognized,
          e,
          readable,
        )
      },
      to_readable_json_code: fn(e, eol_indent) {
        enum_append_readable_json_code(
          variants,
          get_kind_ordinal,
          get_unrecognized,
          e,
          eol_indent,
        )
      },
      decode_json: fn(keep) {
        use d <- decode.then(decode.dynamic)
        case
          enum_decode_json(
            variants_by_number,
            variants_by_name,
            variants_by_name_lower,
            removed_numbers,
            unknown_default,
            wrap_unrecognized,
            d,
            keep,
          )
        {
          Ok(e) -> decode.success(e)
          Error(msg) -> decode.failure(unknown_default, msg)
        }
      },
      encode: fn(e, tree) {
        enum_encode(variants, get_kind_ordinal, get_unrecognized, e, tree)
      },
      decode: fn(bits, keep) {
        enum_decode_binary(
          variants_by_number,
          removed_numbers,
          unknown_default,
          wrap_unrecognized,
          bits,
          keep,
        )
      },
      type_descriptor: fn() {
        enum_type_descriptor(
          name,
          qualified_name,
          module_path,
          doc,
          variants,
          removed_numbers,
        )
      },
    ),
  )
}

// =============================================================================
// JSON encoding
// =============================================================================

fn enum_append_json(
  variants: List(VariantAdapter(e)),
  get_kind_ordinal: fn(e) -> Int,
  get_unrecognized: fn(e) -> UnrecognizedVariant(e),
  e: e,
  readable: type_adapter.JsonFlavor,
) -> json.Json {
  case get_kind_ordinal(e) {
    0 -> unknown_to_json(get_unrecognized(e), readable)
    ko ->
      case list.drop(variants, ko - 1) |> list.first {
        Error(_) -> json.int(0)
        Ok(v) -> v.to_json(e, readable)
      }
  }
}

fn enum_append_readable_json_code(
  variants: List(VariantAdapter(e)),
  get_kind_ordinal: fn(e) -> Int,
  get_unrecognized: fn(e) -> UnrecognizedVariant(e),
  e: e,
  eol_indent: String,
) -> string_tree.StringTree {
  case get_kind_ordinal(e) {
    0 -> unknown_to_readable_json_code(get_unrecognized(e))
    ko ->
      case list.drop(variants, ko - 1) |> list.first {
        Error(_) -> json.to_string_tree(json.int(0))
        Ok(v) -> v.to_readable_json_code(e, eol_indent)
      }
  }
}

fn unknown_to_readable_json_code(
  _unrec: UnrecognizedVariant(e),
) -> string_tree.StringTree {
  json.to_string_tree(json.string("unknown"))
}

fn unknown_to_json(
  unrec: UnrecognizedVariant(e),
  readable: type_adapter.JsonFlavor,
) -> json.Json {
  case readable {
    type_adapter.Readable -> json.string("unknown")
    type_adapter.Dense ->
      case unrec {
        None -> json.int(0)
        Some(data) ->
          case data.format {
            unrecognized.DenseJson -> {
              let raw = data.value
              case bit_array.to_string(raw) {
                Ok(s) if s != "" ->
                  case json.parse(from: s, using: decode.dynamic) {
                    Ok(d) -> dynamic_to_json(d)
                    Error(_) -> json.int(0)
                  }
                _ -> json.int(0)
              }
            }
            unrecognized.BinaryBytes -> json.int(0)
          }
      }
  }
}

fn dynamic_to_json(d: dynamic.Dynamic) -> json.Json {
  case decode.run(d, decode.int) {
    Ok(n) -> json.int(n)
    _ ->
      case decode.run(d, decode.bool) {
        Ok(b) -> json.bool(b)
        _ ->
          case decode.run(d, decode.float) {
            Ok(f) -> json.float(f)
            _ ->
              case decode.run(d, decode.string) {
                Ok(s) -> json.string(s)
                _ ->
                  case decode.run(d, decode.list(decode.dynamic)) {
                    Ok(lst) ->
                      json.preprocessed_array(list.map(lst, dynamic_to_json))
                    _ ->
                      case
                        decode.run(
                          d,
                          decode.dict(decode.string, decode.dynamic),
                        )
                      {
                        Ok(obj) ->
                          json.object(
                            dict.to_list(obj)
                            |> list.map(fn(p) { #(p.0, dynamic_to_json(p.1)) }),
                          )
                        _ -> json.null()
                      }
                  }
              }
          }
      }
  }
}

// =============================================================================
// JSON decoding
// =============================================================================

// Converts a dynamic.Dynamic value (parsed from JSON) back to a JSON string.
fn dynamic_to_json_string(d: dynamic.Dynamic) -> String {
  case decode.run(d, decode.int) {
    Ok(n) -> int.to_string(n)
    _ ->
      case decode.run(d, decode.bool) {
        Ok(True) -> "true"
        Ok(False) -> "false"
        _ ->
          case decode.run(d, decode.float) {
            Ok(f) -> float.to_string(f)
            _ ->
              case decode.run(d, decode.string) {
                Ok(s) -> json.to_string(json.string(s))
                _ ->
                  case decode.run(d, decode.list(decode.dynamic)) {
                    Ok(lst) ->
                      "["
                      <> string.join(list.map(lst, dynamic_to_json_string), ",")
                      <> "]"
                    _ -> "null"
                  }
              }
          }
      }
  }
}

fn find_variant_by_name(
  variants_by_name: dict.Dict(String, VariantAdapter(e)),
  variants_by_name_lower: dict.Dict(String, VariantAdapter(e)),
  name: String,
) -> Result(VariantAdapter(e), Nil) {
  case dict.get(variants_by_name, name) {
    Ok(v) -> Ok(v)
    Error(_) -> dict.get(variants_by_name_lower, string.lowercase(name))
  }
}

fn enum_decode_json(
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  variants_by_name: dict.Dict(String, VariantAdapter(e)),
  variants_by_name_lower: dict.Dict(String, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
  wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  d: dynamic.Dynamic,
  keep: type_adapter.UnrecognizedValues,
) -> Result(e, String) {
  // Try as integer: constant variant by number (dense JSON).
  case decode.run(d, decode.int) {
    Ok(n) ->
      case
        resolve_constant_number_keep(
          n,
          variants_by_number,
          removed_numbers,
          unknown_default,
          wrap_unrecognized,
          keep,
        )
      {
        Ok(e) -> Ok(e)
        Error(e) -> Error(e)
      }
    Error(_) ->
      // Try as bool: true=1, false=0.
      case decode.run(d, decode.bool) {
        Ok(b) -> {
          let n = case b {
            True -> 1
            False -> 0
          }
          Ok(resolve_constant_number(
            n,
            variants_by_number,
            removed_numbers,
            unknown_default,
          ))
        }
        Error(_) ->
          // Try as string: constant variant by name (readable JSON).
          case decode.run(d, decode.string) {
            Ok(s) ->
              case
                find_variant_by_name(
                  variants_by_name,
                  variants_by_name_lower,
                  s,
                )
              {
                Error(_) -> Ok(unknown_default)
                Ok(v) ->
                  case v.constant {
                    option.Some(c) -> Ok(c)
                    option.None ->
                      Error(
                        "variant '"
                        <> s
                        <> "' is a wrapper variant; expected a constant",
                      )
                  }
              }
            Error(_) ->
              // Try as [number, value]: wrapper variant (dense JSON).
              case decode.run(d, decode.list(decode.dynamic)) {
                Ok([num_d, val_d, ..]) ->
                  case decode.run(num_d, decode.int) {
                    Error(_) -> Ok(unknown_default)
                    Ok(n) ->
                      case list.contains(removed_numbers, n) {
                        True -> Ok(unknown_default)
                        False ->
                          case dict.get(variants_by_number, n) {
                            Error(_) ->
                              case keep {
                                type_adapter.Drop -> Ok(unknown_default)
                                type_adapter.Keep -> {
                                  // Store as unrecognized: reconstruct JSON array
                                  let json_bytes =
                                    bit_array.from_string(
                                      "["
                                      <> int.to_string(n)
                                      <> ","
                                      <> dynamic_to_json_string(val_d)
                                      <> "]",
                                    )
                                  Ok(
                                    wrap_unrecognized(
                                      Some(variant_data_from_json(n, json_bytes)),
                                    ),
                                  )
                                }
                              }
                            Ok(v) ->
                              decode.run(val_d, v.wrap_from_json(keep))
                              |> result.map_error(
                                json_utils.decode_errors_to_string,
                              )
                          }
                      }
                  }
                Ok(_) -> Ok(unknown_default)
                Error(_) ->
                  // Try as {"kind": ..., "value": ...}: wrapper variant
                  // (readable JSON).
                  case
                    decode.run(d, decode.dict(decode.string, decode.dynamic))
                  {
                    Error(_) -> Ok(unknown_default)
                    Ok(obj) -> {
                      let name = case dict.get(obj, "kind") {
                        Error(_) -> ""
                        Ok(k) -> result.unwrap(decode.run(k, decode.string), "")
                      }
                      case
                        find_variant_by_name(
                          variants_by_name,
                          variants_by_name_lower,
                          name,
                        )
                      {
                        Error(_) -> Ok(unknown_default)
                        Ok(v) ->
                          case v.constant {
                            option.Some(c) -> Ok(c)
                            option.None ->
                              case dict.get(obj, "value") {
                                Ok(val_d) ->
                                  decode.run(val_d, v.wrap_from_json(keep))
                                  |> result.map_error(
                                    json_utils.decode_errors_to_string,
                                  )
                                Error(_) ->
                                  Ok(option.unwrap(
                                    v.wrap_default(),
                                    unknown_default,
                                  ))
                              }
                          }
                      }
                    }
                  }
              }
          }
      }
  }
}

fn resolve_constant_number(
  number: Int,
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
) -> e {
  case list.contains(removed_numbers, number) {
    True -> unknown_default
    False ->
      case dict.get(variants_by_number, number) {
        Error(_) -> unknown_default
        Ok(v) ->
          case v.constant {
            option.Some(c) -> c
            option.None ->
              // Wrapper variant seen in constant context: use default payload.
              option.unwrap(v.wrap_default(), unknown_default)
          }
      }
  }
}

fn resolve_constant_number_keep(
  number: Int,
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
  wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  keep: type_adapter.UnrecognizedValues,
) -> Result(e, String) {
  case list.contains(removed_numbers, number) {
    True -> Ok(unknown_default)
    False ->
      case dict.get(variants_by_number, number) {
        Ok(v) ->
          case v.constant {
            option.Some(c) -> Ok(c)
            option.None -> Ok(option.unwrap(v.wrap_default(), unknown_default))
          }
        Error(_) ->
          case keep {
            type_adapter.Drop -> Ok(unknown_default)
            type_adapter.Keep -> {
              let json_bytes = bit_array.from_string(int.to_string(number))
              Ok(
                wrap_unrecognized(
                  Some(variant_data_from_json(number, json_bytes)),
                ),
              )
            }
          }
      }
  }
}

// =============================================================================
// Binary encoding
// =============================================================================

fn enum_encode(
  variants: List(VariantAdapter(e)),
  get_kind_ordinal: fn(e) -> Int,
  get_unrecognized: fn(e) -> UnrecognizedVariant(e),
  e: e,
  tree: BytesTree,
) -> BytesTree {
  case get_kind_ordinal(e) {
    0 ->
      // Unknown: re-emit captured bytes if available.
      case get_unrecognized(e) {
        None -> bytes_tree.append(tree, <<0>>)
        Some(data) -> {
          let fmt = data.format
          let bytes = data.value
          case
            fmt == unrecognized.BinaryBytes && bit_array.byte_size(bytes) > 0
          {
            True -> bytes_tree.append(tree, bytes)
            False -> bytes_tree.append(tree, <<0>>)
          }
        }
      }
    ko ->
      case list.drop(variants, ko - 1) |> list.first {
        Error(_) -> bytes_tree.append(tree, <<0>>)
        Ok(v) ->
          case v.constant {
            option.Some(_) ->
              // Constant variant: encode the variant number as a varint.
              bytes_tree.append(tree, decode_utils.encode_uint32(v.number))
            option.None -> {
              // Wrapper variant: header byte(s) then the payload.
              let n = v.number
              let t1 = case n >= 1 && n <= 4 {
                True -> {
                  let header_byte = 250 + n
                  bytes_tree.append(tree, <<header_byte>>)
                }
                False ->
                  tree
                  |> bytes_tree.append(<<248>>)
                  |> bytes_tree.append(decode_utils.encode_uint32(n))
              }
              v.encode_payload(e, t1)
            }
          }
      }
  }
}

// =============================================================================
// Binary decoding
// =============================================================================

fn enum_decode_binary(
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
  wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  bits: BitArray,
  keep: type_adapter.UnrecognizedValues,
) -> Result(#(e, BitArray), String) {
  case bits {
    <<wire, rest:bits>> ->
      case wire < 242 {
        True -> {
          // Constant variant context: decode the full varint starting at `bits`.
          case decode_utils.decode_number(bits) {
            Error(e) -> Error(e)
            Ok(#(0, rest2)) -> Ok(#(unknown_default, rest2))
            Ok(#(number, rest2)) -> {
              let consumed =
                bit_array.byte_size(bits) - bit_array.byte_size(rest2)
              let raw =
                bit_array.slice(bits, 0, consumed) |> result.unwrap(<<>>)
              Ok(#(
                resolve_constant_number_bin(
                  number,
                  variants_by_number,
                  removed_numbers,
                  unknown_default,
                  wrap_unrecognized,
                  keep,
                  raw,
                ),
                rest2,
              ))
            }
          }
        }
        False ->
          // Wrapper variant context: determine the variant number from the header.
          case wire {
            248 ->
              // Number follows as a varint in `rest`.
              case decode_utils.decode_number(rest) {
                Error(e) -> Error(e)
                Ok(#(number, rest2)) ->
                  decode_wrapper_number(
                    number,
                    variants_by_number,
                    removed_numbers,
                    unknown_default,
                    wrap_unrecognized,
                    rest2,
                    keep,
                  )
              }
            251 | 252 | 253 | 254 ->
              decode_wrapper_number(
                wire - 250,
                variants_by_number,
                removed_numbers,
                unknown_default,
                wrap_unrecognized,
                rest,
                keep,
              )
            _ ->
              // Unknown wire byte (242..247, 249, 250, 255): return Unknown.
              Ok(#(unknown_default, rest))
          }
      }
    _ -> Error("unexpected end of input decoding enum")
  }
}

fn resolve_constant_number_bin(
  number: Int,
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
  wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  keep: type_adapter.UnrecognizedValues,
  raw_bits: BitArray,
) -> e {
  case list.contains(removed_numbers, number) {
    True -> unknown_default
    False ->
      case dict.get(variants_by_number, number) {
        Error(_) ->
          case keep {
            type_adapter.Drop -> unknown_default
            type_adapter.Keep -> {
              let ud = variant_data_from_bytes(number, raw_bits)
              wrap_unrecognized(Some(ud))
            }
          }
        Ok(v) ->
          case v.constant {
            option.Some(c) -> c
            option.None ->
              // Wrapper variant seen in constant context: use default payload.
              option.unwrap(v.wrap_default(), unknown_default)
          }
      }
  }
}

fn decode_wrapper_number(
  number: Int,
  variants_by_number: dict.Dict(Int, VariantAdapter(e)),
  removed_numbers: List(Int),
  unknown_default: e,
  wrap_unrecognized: fn(UnrecognizedVariant(e)) -> e,
  bits: BitArray,
  keep: type_adapter.UnrecognizedValues,
) -> Result(#(e, BitArray), String) {
  case list.contains(removed_numbers, number) {
    True ->
      case decode_utils.skip_value(bits) {
        Error(e) -> Error(e)
        Ok(rest) -> Ok(#(unknown_default, rest))
      }
    False ->
      case dict.get(variants_by_number, number) {
        Ok(v) -> v.wrap_decode(bits, keep)
        Error(_) ->
          // Unrecognized wrapper variant.
          case keep {
            type_adapter.Drop ->
              case decode_utils.skip_value(bits) {
                Error(e) -> Error(e)
                Ok(rest) -> Ok(#(unknown_default, rest))
              }
            type_adapter.Keep -> {
              let header = encode_wrapper_header(number)
              let before_size = bit_array.byte_size(bits)
              case decode_utils.skip_value(bits) {
                Error(e) -> Error(e)
                Ok(rest) -> {
                  let consumed = before_size - bit_array.byte_size(rest)
                  let payload =
                    bit_array.slice(bits, 0, consumed) |> result.unwrap(<<>>)
                  let all_bytes = bit_array.append(header, payload)
                  let ud = variant_data_from_bytes(number, all_bytes)
                  Ok(#(wrap_unrecognized(Some(ud)), rest))
                }
              }
            }
          }
      }
  }
}

// =============================================================================
// Type descriptor
// =============================================================================

fn enum_type_descriptor(
  name: String,
  qualified_name: String,
  module_path: String,
  doc: String,
  variants: List(VariantAdapter(e)),
  removed_numbers: List(Int),
) -> type_descriptor.TypeDescriptor {
  let id = module_path <> ":" <> qualified_name
  let variants_desc =
    list.map(variants, fn(v) {
      case v.type_descriptor() {
        option.None ->
          type_descriptor.ConstantVariant(
            name: v.name,
            number: v.number,
            doc: v.doc,
          )
        option.Some(td) ->
          type_descriptor.WrapperVariant(
            name: v.name,
            number: v.number,
            variant_type: td.type_sig,
            doc: v.doc,
          )
      }
    })
  let all_records =
    list.fold(variants, dict.new(), fn(acc, v) {
      case v.type_descriptor() {
        option.None -> acc
        option.Some(td) -> dict.merge(acc, td.records)
      }
    })
  let enum_descriptor =
    type_descriptor.EnumDescriptor(
      name: name,
      qualified_name: qualified_name,
      module_path: module_path,
      doc: doc,
      removed_numbers: removed_numbers,
      variants: variants_desc,
    )
  type_descriptor.TypeDescriptor(
    type_sig: type_descriptor.Record(id),
    records: dict.insert(
      all_records,
      id,
      type_descriptor.EnumRecord(enum_descriptor),
    ),
  )
}

// =============================================================================
// Internal helpers
// =============================================================================

fn encode_wrapper_header(number: Int) -> BitArray {
  case number >= 1 && number <= 4 {
    True -> {
      let header_byte = 250 + number
      <<header_byte>>
    }
    False -> bit_array.append(<<248>>, decode_utils.encode_uint32(number))
  }
}
