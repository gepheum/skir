import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string

// =============================================================================
// PrimitiveType
// =============================================================================

pub type PrimitiveType {
  Bool
  Int32
  Int64
  Hash64
  Float32
  Float64
  Timestamp
  StringType
  Bytes
}

fn primitive_type_as_str(p: PrimitiveType) -> String {
  case p {
    Bool -> "bool"
    Int32 -> "int32"
    Int64 -> "int64"
    Hash64 -> "hash64"
    Float32 -> "float32"
    Float64 -> "float64"
    Timestamp -> "timestamp"
    StringType -> "string"
    Bytes -> "bytes"
  }
}

fn primitive_type_from_str(s: String) -> Result(PrimitiveType, String) {
  case s {
    "bool" -> Ok(Bool)
    "int32" -> Ok(Int32)
    "int64" -> Ok(Int64)
    "hash64" -> Ok(Hash64)
    "float32" -> Ok(Float32)
    "float64" -> Ok(Float64)
    "timestamp" -> Ok(Timestamp)
    "string" -> Ok(StringType)
    "bytes" -> Ok(Bytes)
    _ -> Error("unknown primitive type: " <> s)
  }
}

// =============================================================================
// TypeSignature
// =============================================================================

/// The shape of a Skir type. Records (structs and enums) are represented
/// as a `Record(id)` where `id` is the record's fully-qualified ID string
/// `"<module_path>:<qualified_name>"`. The actual record definitions live in
/// the `TypeDescriptor.records` map.
pub type TypeSignature {
  Primitive(PrimitiveType)
  Optional(TypeSignature)
  Array(item_type: TypeSignature, key_extractor: String)
  Record(String)
}

// =============================================================================
// TypeDescriptor
// =============================================================================

/// A self-describing Skir type that carries both a type signature and all
/// record definitions (structs and enums) it references, keyed by their
/// `"<module_path>:<qualified_name>"` ID.
pub type TypeDescriptor {
  TypeDescriptor(
    type_sig: TypeSignature,
    records: Dict(String, RecordDescriptor),
  )
}

/// A record definition: either a struct or an enum.
pub type RecordDescriptor {
  StructRecord(StructDescriptor)
  EnumRecord(EnumDescriptor)
}

pub type StructDescriptor {
  StructDescriptor(
    name: String,
    qualified_name: String,
    module_path: String,
    doc: String,
    removed_numbers: List(Int),
    fields: List(StructField),
  )
}

pub type StructField {
  StructField(name: String, number: Int, field_type: TypeSignature, doc: String)
}

pub type EnumDescriptor {
  EnumDescriptor(
    name: String,
    qualified_name: String,
    module_path: String,
    doc: String,
    removed_numbers: List(Int),
    variants: List(EnumVariant),
  )
}

pub type EnumVariant {
  ConstantVariant(name: String, number: Int, doc: String)
  WrapperVariant(
    name: String,
    number: Int,
    variant_type: TypeSignature,
    doc: String,
  )
}

// =============================================================================
// JSON Serialization
// =============================================================================

fn struct_record_id(s: StructDescriptor) -> String {
  s.module_path <> ":" <> s.qualified_name
}

fn enum_record_id(e: EnumDescriptor) -> String {
  e.module_path <> ":" <> e.qualified_name
}

/// Serializes a TypeDescriptor to a pretty-printed JSON string.
/// The format is compatible with the Go and Rust skir client implementations.
pub fn type_descriptor_to_json(td: TypeDescriptor) -> String {
  let type_sig_json = type_signature_to_json(td.type_sig, "  ")
  // Sort records: root type first (if it matches the top-level type sig),
  // then others alphabetically.
  let root_id = case td.type_sig {
    Record(id) -> id
    _ -> ""
  }
  let records_sorted =
    list.sort(dict.to_list(td.records), fn(a, b) {
      case a.0 == root_id, b.0 == root_id {
        True, False -> order.Lt
        False, True -> order.Gt
        _, _ -> string.compare(a.0, b.0)
      }
    })
  let records_content = case records_sorted {
    [] -> ""
    _ -> {
      let parts =
        list.map(records_sorted, fn(pair) {
          record_descriptor_to_json(pair.1, "    ")
        })
      "\n    " <> string.join(parts, ",\n    ") <> "\n  "
    }
  }
  "{\n  \"type\": "
  <> type_sig_json
  <> ",\n  \"records\": ["
  <> records_content
  <> "]\n}"
}

// Builds the JSON for a record descriptor.
fn record_descriptor_to_json(rd: RecordDescriptor, indent: String) -> String {
  case rd {
    StructRecord(s) -> struct_record_to_json(s, indent)
    EnumRecord(e) -> enum_record_to_json(e, indent)
  }
}

// Builds the JSON for a struct record definition.
// `indent` is the indentation level of the closing `}`.
fn struct_record_to_json(s: StructDescriptor, indent: String) -> String {
  let inner = indent <> "  "
  let field_indent = inner <> "  "
  let field_body = field_indent <> "  "
  let rid_json = json_escape_string(struct_record_id(s))
  let doc_part = case s.doc {
    "" -> ""
    doc -> ",\n" <> inner <> "\"doc\": " <> json_escape_string(doc)
  }
  let fields_content = case s.fields {
    [] -> ""
    fields -> {
      let parts =
        list.index_map(fields, fn(f, i) {
          let sep = case i {
            0 -> ""
            _ -> ","
          }
          let type_json = type_signature_to_json(f.field_type, field_body)
          let fdoc = case f.doc {
            "" -> ""
            doc -> ",\n" <> field_body <> "\"doc\": " <> json_escape_string(doc)
          }
          sep
          <> "\n"
          <> field_indent
          <> "{\n"
          <> field_body
          <> "\"name\": "
          <> json_escape_string(f.name)
          <> ",\n"
          <> field_body
          <> "\"number\": "
          <> int.to_string(f.number)
          <> ",\n"
          <> field_body
          <> "\"type\": "
          <> type_json
          <> fdoc
          <> "\n"
          <> field_indent
          <> "}"
        })
      string.concat(parts) <> "\n" <> inner
    }
  }
  let removed_part = case sorted_ints(s.removed_numbers) {
    [] -> ""
    nums -> {
      let num_parts =
        list.index_map(nums, fn(n, i) {
          let sep = case i {
            0 -> ""
            _ -> ","
          }
          sep <> "\n" <> field_indent <> int.to_string(n)
        })
      ",\n"
      <> inner
      <> "\"removed_numbers\": ["
      <> string.concat(num_parts)
      <> "\n"
      <> inner
      <> "]"
    }
  }
  "{\n"
  <> inner
  <> "\"kind\": \"struct\",\n"
  <> inner
  <> "\"id\": "
  <> rid_json
  <> doc_part
  <> ",\n"
  <> inner
  <> "\"fields\": ["
  <> fields_content
  <> "]"
  <> removed_part
  <> "\n"
  <> indent
  <> "}"
}

// Builds the JSON for an enum record definition.
// `indent` is the indentation level of the closing `}`.
fn enum_record_to_json(e: EnumDescriptor, indent: String) -> String {
  let inner = indent <> "  "
  let variant_indent = inner <> "  "
  let variant_body = variant_indent <> "  "
  let rid_json = json_escape_string(enum_record_id(e))
  let doc_part = case e.doc {
    "" -> ""
    doc -> ",\n" <> inner <> "\"doc\": " <> json_escape_string(doc)
  }
  let sorted_variants =
    list.sort(e.variants, fn(a, b) {
      int.compare(variant_number(a), variant_number(b))
    })
  let variants_content = case sorted_variants {
    [] -> ""
    variants -> {
      let parts =
        list.index_map(variants, fn(v, i) {
          let sep = case i {
            0 -> ""
            _ -> ","
          }
          let type_part = case v {
            WrapperVariant(variant_type:, ..) ->
              ",\n"
              <> variant_body
              <> "\"type\": "
              <> type_signature_to_json(variant_type, variant_body)
            ConstantVariant(..) -> ""
          }
          let vdoc = case variant_doc(v) {
            "" -> ""
            doc ->
              ",\n" <> variant_body <> "\"doc\": " <> json_escape_string(doc)
          }
          sep
          <> "\n"
          <> variant_indent
          <> "{\n"
          <> variant_body
          <> "\"name\": "
          <> json_escape_string(variant_name(v))
          <> ",\n"
          <> variant_body
          <> "\"number\": "
          <> int.to_string(variant_number(v))
          <> type_part
          <> vdoc
          <> "\n"
          <> variant_indent
          <> "}"
        })
      string.concat(parts) <> "\n" <> inner
    }
  }
  let removed_part = case sorted_ints(e.removed_numbers) {
    [] -> ""
    nums -> {
      let num_parts =
        list.index_map(nums, fn(n, i) {
          let sep = case i {
            0 -> ""
            _ -> ","
          }
          sep <> "\n" <> variant_indent <> int.to_string(n)
        })
      ",\n"
      <> inner
      <> "\"removed_numbers\": ["
      <> string.concat(num_parts)
      <> "\n"
      <> inner
      <> "]"
    }
  }
  "{\n"
  <> inner
  <> "\"kind\": \"enum\",\n"
  <> inner
  <> "\"id\": "
  <> rid_json
  <> doc_part
  <> ",\n"
  <> inner
  <> "\"variants\": ["
  <> variants_content
  <> "]"
  <> removed_part
  <> "\n"
  <> indent
  <> "}"
}

fn variant_name(v: EnumVariant) -> String {
  case v {
    ConstantVariant(name:, ..) -> name
    WrapperVariant(name:, ..) -> name
  }
}

fn variant_number(v: EnumVariant) -> Int {
  case v {
    ConstantVariant(number:, ..) -> number
    WrapperVariant(number:, ..) -> number
  }
}

fn variant_doc(v: EnumVariant) -> String {
  case v {
    ConstantVariant(doc:, ..) -> doc
    WrapperVariant(doc:, ..) -> doc
  }
}

// Builds the JSON for a type signature.
// `indent` is the indentation of the enclosing context.
fn type_signature_to_json(ts: TypeSignature, indent: String) -> String {
  let inner = indent <> "  "
  case ts {
    Primitive(p) ->
      "{\n"
      <> inner
      <> "\"kind\": \"primitive\",\n"
      <> inner
      <> "\"value\": \""
      <> primitive_type_as_str(p)
      <> "\"\n"
      <> indent
      <> "}"
    Optional(inner_ts) ->
      "{\n"
      <> inner
      <> "\"kind\": \"optional\",\n"
      <> inner
      <> "\"value\": "
      <> type_signature_to_json(inner_ts, inner)
      <> "\n"
      <> indent
      <> "}"
    Array(item_type:, key_extractor:) -> {
      let value_indent = inner <> "  "
      let key_ext_part = case key_extractor {
        "" -> ""
        ke ->
          ",\n"
          <> value_indent
          <> "\"key_extractor\": "
          <> json_escape_string(ke)
      }
      "{\n"
      <> inner
      <> "\"kind\": \"array\",\n"
      <> inner
      <> "\"value\": {\n"
      <> value_indent
      <> "\"item\": "
      <> type_signature_to_json(item_type, value_indent)
      <> key_ext_part
      <> "\n"
      <> inner
      <> "}\n"
      <> indent
      <> "}"
    }
    Record(id) ->
      "{\n"
      <> inner
      <> "\"kind\": \"record\",\n"
      <> inner
      <> "\"value\": "
      <> json_escape_string(id)
      <> "\n"
      <> indent
      <> "}"
  }
}

// Escapes a string for use in JSON, wrapping it in double-quotes.
fn json_escape_string(s: String) -> String {
  let escaped =
    string.concat(list.map(string.to_graphemes(s), json_escape_char))
  "\"" <> escaped <> "\""
}

fn json_escape_char(c: String) -> String {
  case c {
    "\"" -> "\\\""
    "\\" -> "\\\\"
    "\n" -> "\\n"
    "\r" -> "\\r"
    "\t" -> "\\t"
    _ -> c
  }
}

fn sorted_ints(nums: List(Int)) -> List(Int) {
  list.sort(nums, int.compare)
}

// =============================================================================
// JSON Parsing
// =============================================================================

// Internal JSON value type for parsing.
type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonInt(Int)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(List(#(String, JsonValue)))
}

/// Parses a TypeDescriptor from a JSON string produced by this module,
/// or by the equivalent Go or Rust skir client implementations.
pub fn type_descriptor_from_json(json: String) -> Result(TypeDescriptor, String) {
  case json_parse(json) {
    Error(e) -> Error("JSON parse error: " <> e)
    Ok(v) -> parse_type_descriptor_from_value(v)
  }
}

fn parse_type_descriptor_from_value(
  root: JsonValue,
) -> Result(TypeDescriptor, String) {
  let records_json = json_obj_get_array(root, "records")
  use records_map <- result.try(build_records_map(records_json, dict.new()))
  case json_obj_get_field(root, "type") {
    Error(_) -> Error("type descriptor JSON missing 'type' field")
    Ok(type_val) ->
      result.map(parse_type_signature(type_val), fn(type_sig) {
        TypeDescriptor(type_sig:, records: records_map)
      })
  }
}

fn build_records_map(
  records_json: List(JsonValue),
  records_map: Dict(String, RecordDescriptor),
) -> Result(Dict(String, RecordDescriptor), String) {
  case records_json {
    [] -> Ok(records_map)
    [rec, ..rest] -> {
      case parse_and_add_record(rec, records_map) {
        Error(e) -> Error(e)
        Ok(new_map) -> build_records_map(rest, new_map)
      }
    }
  }
}

fn parse_and_add_record(
  rec: JsonValue,
  records_map: Dict(String, RecordDescriptor),
) -> Result(Dict(String, RecordDescriptor), String) {
  let kind = json_obj_get_string(rec, "kind")
  let id = json_obj_get_string(rec, "id")
  let doc = json_obj_get_string(rec, "doc")
  let removed = json_obj_get_int_array(rec, "removed_numbers")
  case split_record_id(id) {
    Error(e) -> Error(e)
    Ok(#(module_path, qualified_name)) -> {
      let name = last_segment(qualified_name, ".")
      case kind {
        "struct" -> {
          let fields_json = json_obj_get_array(rec, "fields")
          case parse_struct_fields(fields_json) {
            Error(e) -> Error(e)
            Ok(fields) -> {
              let sd =
                StructDescriptor(
                  name: name,
                  qualified_name: qualified_name,
                  module_path: module_path,
                  doc: doc,
                  removed_numbers: removed,
                  fields: fields,
                )
              Ok(dict.insert(records_map, id, StructRecord(sd)))
            }
          }
        }
        "enum" -> {
          let variants_json = json_obj_get_array(rec, "variants")
          case parse_enum_variants(variants_json) {
            Error(e) -> Error(e)
            Ok(variants) -> {
              let ed =
                EnumDescriptor(
                  name: name,
                  qualified_name: qualified_name,
                  module_path: module_path,
                  doc: doc,
                  removed_numbers: removed,
                  variants: variants,
                )
              Ok(dict.insert(records_map, id, EnumRecord(ed)))
            }
          }
        }
        _ -> Error("unknown record kind: " <> kind)
      }
    }
  }
}

fn parse_struct_fields(
  fields_json: List(JsonValue),
) -> Result(List(StructField), String) {
  list.try_map(fields_json, fn(f) {
    let name = json_obj_get_string(f, "name")
    let number = json_obj_get_int(f, "number")
    let doc = json_obj_get_string(f, "doc")
    case json_obj_get_field(f, "type") {
      Error(_) -> Error("struct field \"" <> name <> "\" missing 'type'")
      Ok(type_val) ->
        result.map(parse_type_signature(type_val), fn(field_type) {
          StructField(
            name: name,
            number: number,
            field_type: field_type,
            doc: doc,
          )
        })
    }
  })
}

fn parse_enum_variants(
  variants_json: List(JsonValue),
) -> Result(List(EnumVariant), String) {
  list.try_map(variants_json, fn(v) {
    let name = json_obj_get_string(v, "name")
    let number = json_obj_get_int(v, "number")
    let doc = json_obj_get_string(v, "doc")
    case json_obj_get_field(v, "type") {
      Error(_) -> Ok(ConstantVariant(name: name, number: number, doc: doc))
      Ok(type_val) ->
        result.map(parse_type_signature(type_val), fn(variant_type) {
          WrapperVariant(
            name: name,
            number: number,
            variant_type: variant_type,
            doc: doc,
          )
        })
    }
  })
}

fn parse_type_signature(v: JsonValue) -> Result(TypeSignature, String) {
  let kind = json_obj_get_string(v, "kind")
  case json_obj_get_field(v, "value") {
    Error(_) -> Error("type signature missing 'value', kind=" <> kind)
    Ok(value_json) ->
      case kind {
        "primitive" ->
          case json_as_string(value_json) {
            Error(_) -> Error("primitive type 'value' must be a string")
            Ok(prim_str) ->
              result.map(primitive_type_from_str(prim_str), Primitive)
          }
        "optional" -> result.map(parse_type_signature(value_json), Optional)
        "array" -> {
          let key_ext = json_obj_get_string(value_json, "key_extractor")
          case json_obj_get_field(value_json, "item") {
            Error(_) -> Error("array type missing 'item'")
            Ok(item_val) ->
              result.map(parse_type_signature(item_val), fn(item_type) {
                Array(item_type:, key_extractor: key_ext)
              })
          }
        }
        "record" ->
          case json_as_string(value_json) {
            Error(_) -> Error("record type 'value' must be a string")
            Ok(record_id) -> Ok(Record(record_id))
          }
        _ -> Error("unknown type kind: " <> kind)
      }
  }
}

// Splits "module_path:qualified_name" into its two parts.
fn split_record_id(id: String) -> Result(#(String, String), String) {
  case string.split_once(id, ":") {
    Ok(pair) -> Ok(pair)
    Error(_) -> Error("malformed record id (expected 'path:Name'): " <> id)
  }
}

// Returns the last segment of a dotted name, e.g. "Foo.Bar" -> "Bar".
fn last_segment(s: String, sep: String) -> String {
  case string.split(s, sep) {
    [] -> s
    parts ->
      case list.last(parts) {
        Ok(last) -> last
        Error(_) -> s
      }
  }
}

// =============================================================================
// Minimal JSON Parser
// =============================================================================

fn json_parse(input: String) -> Result(JsonValue, String) {
  let chars = string.to_graphemes(input)
  case json_parse_value(chars) {
    Error(e) -> Error(e)
    Ok(#(v, _rest)) -> Ok(v)
  }
}

fn json_skip_ws(chars: List(String)) -> List(String) {
  case chars {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\r", ..rest] ->
      json_skip_ws(rest)
    other -> other
  }
}

fn json_parse_value(
  chars: List(String),
) -> Result(#(JsonValue, List(String)), String) {
  let chars = json_skip_ws(chars)
  case chars {
    ["{", ..rest] -> json_parse_object(rest)
    ["[", ..rest] -> json_parse_array(rest)
    ["\"", ..rest] ->
      case json_parse_string_chars(rest, "") {
        Error(e) -> Error(e)
        Ok(#(s, rem)) -> Ok(#(JsonString(s), rem))
      }
    ["t", "r", "u", "e", ..rest] -> Ok(#(JsonBool(True), rest))
    ["f", "a", "l", "s", "e", ..rest] -> Ok(#(JsonBool(False), rest))
    ["n", "u", "l", "l", ..rest] -> Ok(#(JsonNull, rest))
    ["-", ..] -> json_parse_number(chars)
    ["0", ..]
    | ["1", ..]
    | ["2", ..]
    | ["3", ..]
    | ["4", ..]
    | ["5", ..]
    | ["6", ..]
    | ["7", ..]
    | ["8", ..]
    | ["9", ..] -> json_parse_number(chars)
    [c, ..] -> Error("unexpected token: " <> c)
    [] -> Error("unexpected end of input")
  }
}

fn json_parse_number(
  chars: List(String),
) -> Result(#(JsonValue, List(String)), String) {
  let #(neg_prefix, chars) = case chars {
    ["-", ..rest] -> #("-", rest)
    other -> #("", other)
  }
  let #(digit_chars, rest) = take_digits(chars, [])
  case digit_chars {
    [] -> Error("expected digits in number")
    _ -> {
      let num_str = neg_prefix <> string.concat(digit_chars)
      case int.parse(num_str) {
        Ok(n) -> Ok(#(JsonInt(n), rest))
        Error(_) -> Error("invalid number: " <> num_str)
      }
    }
  }
}

// Consumes leading digit characters from chars, returning them and the remainder.
fn take_digits(
  chars: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case chars {
    [] -> #(list.reverse(acc), [])
    [c, ..rest] ->
      case c {
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ->
          take_digits(rest, [c, ..acc])
        _ -> #(list.reverse(acc), chars)
      }
  }
}

fn json_parse_string_chars(
  chars: List(String),
  acc: String,
) -> Result(#(String, List(String)), String) {
  case chars {
    ["\"", ..rest] -> Ok(#(acc, rest))
    ["\\", "\"", ..rest] -> json_parse_string_chars(rest, acc <> "\"")
    ["\\", "\\", ..rest] -> json_parse_string_chars(rest, acc <> "\\")
    ["\\", "n", ..rest] -> json_parse_string_chars(rest, acc <> "\n")
    ["\\", "r", ..rest] -> json_parse_string_chars(rest, acc <> "\r")
    ["\\", "t", ..rest] -> json_parse_string_chars(rest, acc <> "\t")
    ["\\", "b", ..rest] -> json_parse_string_chars(rest, acc <> "\u{0008}")
    ["\\", "f", ..rest] -> json_parse_string_chars(rest, acc <> "\u{000C}")
    ["\\", "u", a, b, c, d, ..rest] -> {
      let hex = a <> b <> c <> d
      case int.base_parse(hex, 16) {
        Error(_) -> Error("invalid unicode escape: \\u" <> hex)
        Ok(code) ->
          case string.utf_codepoint(code) {
            Error(_) -> Error("invalid unicode codepoint: " <> hex)
            Ok(cp) ->
              json_parse_string_chars(
                rest,
                acc <> string.from_utf_codepoints([cp]),
              )
          }
      }
    }
    ["\\", c, ..rest] -> json_parse_string_chars(rest, acc <> c)
    [c, ..rest] -> json_parse_string_chars(rest, acc <> c)
    [] -> Error("unterminated string literal")
  }
}

fn json_parse_object(
  chars: List(String),
) -> Result(#(JsonValue, List(String)), String) {
  case json_skip_ws(chars) {
    ["}", ..rest] -> Ok(#(JsonObject([]), rest))
    trimmed -> json_parse_object_members(trimmed, [])
  }
}

fn json_parse_object_members(
  chars: List(String),
  acc: List(#(String, JsonValue)),
) -> Result(#(JsonValue, List(String)), String) {
  case json_skip_ws(chars) {
    ["\"", ..rest] ->
      case json_parse_string_chars(rest, "") {
        Error(e) -> Error(e)
        Ok(#(key, chars)) ->
          case json_skip_ws(chars) {
            [":", ..chars] ->
              case json_parse_value(chars) {
                Error(e) -> Error(e)
                Ok(#(value, chars)) -> {
                  let acc = list.append(acc, [#(key, value)])
                  case json_skip_ws(chars) {
                    [",", ..chars] -> json_parse_object_members(chars, acc)
                    ["}", ..rest] -> Ok(#(JsonObject(acc), rest))
                    [c, ..] -> Error("expected ',' or '}', got: " <> c)
                    [] -> Error("unterminated object")
                  }
                }
              }
            [c, ..] -> Error("expected ':', got: " <> c)
            [] -> Error("unexpected end in object")
          }
      }
    ["}", ..rest] -> Ok(#(JsonObject(acc), rest))
    [c, ..] -> Error("expected '\"' or '}', got: " <> c)
    [] -> Error("unexpected end of object")
  }
}

fn json_parse_array(
  chars: List(String),
) -> Result(#(JsonValue, List(String)), String) {
  case json_skip_ws(chars) {
    ["]", ..rest] -> Ok(#(JsonArray([]), rest))
    trimmed -> json_parse_array_elements(trimmed, [])
  }
}

fn json_parse_array_elements(
  chars: List(String),
  acc: List(JsonValue),
) -> Result(#(JsonValue, List(String)), String) {
  case json_parse_value(chars) {
    Error(e) -> Error(e)
    Ok(#(value, chars)) -> {
      let acc = list.append(acc, [value])
      case json_skip_ws(chars) {
        [",", ..chars] -> json_parse_array_elements(chars, acc)
        ["]", ..rest] -> Ok(#(JsonArray(acc), rest))
        [c, ..] -> Error("expected ',' or ']', got: " <> c)
        [] -> Error("unterminated array")
      }
    }
  }
}

// -- JSON helper functions ----------------------------------------------------

fn json_obj_get_field(v: JsonValue, key: String) -> Result(JsonValue, Nil) {
  case v {
    JsonObject(pairs) ->
      list.find_map(pairs, fn(pair) {
        let #(k, val) = pair
        case k == key {
          True -> Ok(val)
          False -> Error(Nil)
        }
      })
    _ -> Error(Nil)
  }
}

fn json_obj_get_string(v: JsonValue, key: String) -> String {
  case json_obj_get_field(v, key) {
    Ok(JsonString(s)) -> s
    _ -> ""
  }
}

fn json_obj_get_int(v: JsonValue, key: String) -> Int {
  case json_obj_get_field(v, key) {
    Ok(JsonInt(n)) -> n
    _ -> 0
  }
}

fn json_obj_get_array(v: JsonValue, key: String) -> List(JsonValue) {
  case json_obj_get_field(v, key) {
    Ok(JsonArray(items)) -> items
    _ -> []
  }
}

fn json_obj_get_int_array(v: JsonValue, key: String) -> List(Int) {
  case json_obj_get_field(v, key) {
    Ok(JsonArray(items)) ->
      list.filter_map(items, fn(item) {
        case item {
          JsonInt(n) -> Ok(n)
          _ -> Error(Nil)
        }
      })
    _ -> []
  }
}

fn json_as_string(v: JsonValue) -> Result(String, String) {
  case v {
    JsonString(s) -> Ok(s)
    _ -> Error("expected JSON string")
  }
}
