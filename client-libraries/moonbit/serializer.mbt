///|
/// Serializes and deserializes values of type `T` in JSON and binary formats.
pub struct Serializer[T] {
  priv adapter : TypeAdapter[T]
}

///|
/// Serializes `input` to the compact (dense) JSON representation.
///
/// Dense JSON is designed for persistence and wire efficiency.
pub fn[T] Serializer::to_dense_json_code(
  self : Serializer[T],
  input : T,
) -> String {
  let builder = StringBuilder::new()
  (self.adapter.to_dense_json)(input, builder)
  builder.to_string()
}

///|
/// Serializes `input` to the readable JSON representation.
///
/// Structs are encoded as JSON objects and enum constants as strings. This
/// format is more verbose and readable, but should not be used for
/// persistence because field names may change across schema versions.
///
/// In other words, do not store readable JSON on disk or in a database.
pub fn[T] Serializer::to_readable_json(self : Serializer[T], input : T) -> Json {
  (self.adapter.to_readable_json)(input)
}

///|
/// Deserializes a value from an already-parsed JSON value.
///
/// Set `unrecognized_values` to `UnrecognizedValues::Keep` to preserve
/// unrecognized fields/variants so they can be emitted again after
/// re-serialization.
///
/// Use `UnrecognizedValues::Drop` (the default) when input may come from
/// untrusted or malicious sources.
pub fn[T] Serializer::from_json(
  self : Serializer[T],
  json : Json,
  unrecognized_values? : UnrecognizedValues = UnrecognizedValues::Drop,
) -> Result[T, String] {
  (self.adapter.from_json)(json, unrecognized_values)
}

///|
/// Deserializes a value from JSON source code.
///
/// Set `unrecognized_values` to `UnrecognizedValues::Keep` to preserve
/// unrecognized fields/variants from newer schema versions.
///
/// Use `UnrecognizedValues::Drop` (the default) when input may come from
/// untrusted or malicious sources.
///
/// Returns `Err("invalid JSON: ...")` when parsing fails.
pub fn[T] Serializer::from_json_code(
  self : Serializer[T],
  code : String,
  unrecognized_values? : UnrecognizedValues = UnrecognizedValues::Drop,
) -> Result[T, String] {
  let root = @json.parse(code) catch {
    e => return Err("invalid JSON: " + e.to_string())
  }
  self.from_json(root, unrecognized_values~)
}

///|
/// Serializes `input` to the Skir binary wire format.
pub fn[T] Serializer::to_bytes(self : Serializer[T], input : T) -> Array[Int] {
  let mut out = OutputStream::new()
  out = out.write_int(115)
  out = out.write_int(107)
  out = out.write_int(105)
  out = out.write_int(114)
  out = (self.adapter.encode)(input, out)
  out.to_int_array()
}

///|
/// Deserializes a value from the Skir binary wire format.
///
/// Set `unrecognized_values` to `UnrecognizedValues::Keep` to preserve
/// unrecognized fields/variants from newer schema versions.
///
/// Use `UnrecognizedValues::Drop` (the default) when input may come from
/// untrusted or malicious sources.
pub fn[T] Serializer::from_bytes(
  self : Serializer[T],
  bytes : Array[Int],
  unrecognized_values? : UnrecognizedValues = UnrecognizedValues::Drop,
) -> Result[T, String] {
  match bytes {
    [115, 107, 105, 114, .. payload] =>
      match
        (self.adapter.decode)(
          InputStream::from_int_array(payload.iter().to_array()),
          unrecognized_values,
        ) {
        Ok((value, _tail)) => Ok(value)
        Err(e) => Err(e)
      }
    _ => Err("invalid binary payload")
  }
}

///|
/// Returns the type descriptor describing the schema of `T`.
pub fn[T] Serializer::type_descriptor(self : Serializer[T]) -> TypeDescriptor {
  (self.adapter.type_descriptor)()
}

///|
/// Controls how unknown fields/variants are handled during deserialization.
pub(all) enum UnrecognizedValues {
  /// Preserve unrecognized values so they can be emitted again later.
  Keep
  /// Drop unrecognized values during deserialization.
  Drop
}

///|
struct TypeAdapter[T] {
  is_default : (T) -> Bool
  to_dense_json : (T, StringBuilder) -> Unit
  to_readable_json : (T) -> Json
  from_json : (Json, UnrecognizedValues) -> Result[T, String]
  encode : (T, OutputStream) -> OutputStream
  decode : (InputStream, UnrecognizedValues) -> Result[(T, InputStream), String]
  type_descriptor : () -> TypeDescriptor
}

///|
fn[T] new_serializer(adapter : TypeAdapter[T]) -> Serializer[T] {
  let s : Serializer[T] = { adapter, }
  s
}
