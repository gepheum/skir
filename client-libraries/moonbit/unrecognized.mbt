///|
pub struct Internal_UnrecognizedFields {
  priv format : UnrecognizedFormat
  priv array_len : Int
}

///|
pub struct Internal_UnrecognizedVariant {
  priv format : UnrecognizedFormat
  priv number : Int
}

///|
priv enum UnrecognizedFormat {
  DenseJson(Json)
  Bytes(Bytes)
} derive(Eq, Debug)

///|
fn unrecognized_fields_from_json(
  array_len : Int,
  json : Json,
) -> Internal_UnrecognizedFields {
  { format: UnrecognizedFormat::DenseJson(json), array_len, }
}

///|
fn unrecognized_fields_from_bytes(
  array_len : Int,
  raw_bytes : Bytes,
) -> Internal_UnrecognizedFields {
  { format: UnrecognizedFormat::Bytes(raw_bytes), array_len, }
}

///|
fn Internal_UnrecognizedFields::array_len(
  self : Internal_UnrecognizedFields,
) -> Int {
  self.array_len
}

///|
fn Internal_UnrecognizedFields::dense_json(
  self : Internal_UnrecognizedFields,
) -> Json? {
  match self.format {
    UnrecognizedFormat::DenseJson(json) => Some(json)
    _ => None
  }
}

///|
fn Internal_UnrecognizedFields::bytes(
  self : Internal_UnrecognizedFields,
) -> Bytes? {
  match self.format {
    UnrecognizedFormat::Bytes(bytes) => Some(bytes)
    _ => None
  }
}

///|
fn unrecognized_variant_from_bytes(
  number : Int,
  raw_bytes : Bytes,
) -> Internal_UnrecognizedVariant {
  { format: UnrecognizedFormat::Bytes(raw_bytes), number, }
}

///|
fn unrecognized_variant_from_json(
  number : Int,
  json : Json,
) -> Internal_UnrecognizedVariant {
  { format: UnrecognizedFormat::DenseJson(json), number, }
}

///|
fn Internal_UnrecognizedVariant::number(
  self : Internal_UnrecognizedVariant,
) -> Int {
  self.number
}

///|
fn Internal_UnrecognizedVariant::dense_json(
  self : Internal_UnrecognizedVariant,
) -> Json? {
  match self.format {
    UnrecognizedFormat::DenseJson(json) => Some(json)
    _ => None
  }
}

///|
fn Internal_UnrecognizedVariant::bytes(
  self : Internal_UnrecognizedVariant,
) -> Bytes? {
  match self.format {
    UnrecognizedFormat::Bytes(bytes) => Some(bytes)
    _ => None
  }
}

///|
pub impl Eq for Internal_UnrecognizedFields with fn equal(self, other) {
  self.format == other.format && self.array_len == other.array_len
}

///|
pub impl Debug for Internal_UnrecognizedFields with fn to_repr(self) {
  Debug::to_repr(self.format)
}

///|
pub impl Eq for Internal_UnrecognizedVariant with fn equal(self, other) {
  self.format == other.format && self.number == other.number
}

///|
pub impl Debug for Internal_UnrecognizedVariant with fn to_repr(self) {
  Debug::to_repr(self.format)
}
