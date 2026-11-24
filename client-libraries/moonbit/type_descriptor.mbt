///|
pub enum PrimitiveType {
  Bool
  Int32
  Int64
  Hash64
  Float32
  Float64
  Timestamp
  String
  Bytes
}

///|
pub struct TypeDescriptor {
  root_type : TypeSignature
  records : @immut_vector.Vector[RecordDescriptor]
}

///|
pub enum TypeSignature {
  Primitive(PrimitiveType)
  Optional(TypeSignature)
  Array(ArraySignature)
  Record(String)
}

///|
pub struct ArraySignature {
  item_type : TypeSignature
  key_extractor : String
}

///|
pub enum RecordDescriptor {
  Struct(StructRecordDescriptor)
  Enum(EnumRecordDescriptor)
}

///|
pub struct StructRecordDescriptor {
  record_id : String
  doc : String
  removed_numbers : @immut_vector.Vector[Int]
  fields : @immut_vector.Vector[StructField]
}

///|
pub struct EnumRecordDescriptor {
  record_id : String
  doc : String
  removed_numbers : @immut_vector.Vector[Int]
  variants : @immut_vector.Vector[EnumVariant]
}

///|
pub struct StructField {
  name : String
  number : Int
  field_type : TypeSignature
  doc : String
}

///|
pub enum EnumVariant {
  Constant(EnumConstantVariant)
  Wrapper(EnumWrapperVariant)
}

///|
pub struct EnumConstantVariant {
  name : String
  number : Int
  doc : String
}

///|
pub struct EnumWrapperVariant {
  name : String
  number : Int
  variant_type : TypeSignature
  doc : String
}

///|
pub fn TypeDescriptor::as_json(self : TypeDescriptor) -> Json {
  let type_json = type_signature_to_json(self.root_type, "  ")
  let records_json = records_to_json(self.records)
  let json_code = "{\n  \"type\": " +
    type_json +
    ",\n  \"records\": " +
    records_json +
    "\n}"
  // The serializer only emits valid JSON. This fallback is defensive.
  @json.parse(json_code) catch {
    _ => panic()
  }
}

///|
pub fn parse_from_json(root : Json) -> Result[TypeDescriptor, String] {
  parse_document(root)
}

///|
fn parse_document(root : Json) -> Result[TypeDescriptor, String] {
  let type_json = match get_object_field(root, "type") {
    Some(v) => v
    None => return Err("type descriptor JSON is missing 'type'")
  }
  let root_type = match parse_type_signature(type_json) {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  let records = match get_object_field(root, "records") {
    Some(Json::Array(items)) =>
      match parse_records(items) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
    Some(_) => return Err("'records' must be an array")
    None => @immut_vector.Vector::new()
  }

  Ok({ root_type, records, })
}

///|
fn parse_records(
  items : Array[Json],
) -> Result[@immut_vector.Vector[RecordDescriptor], String] {
  let out : Array[RecordDescriptor] = []
  for item in items {
    match parse_record(item) {
      Ok(v) => out.push(v)
      Err(e) => return Err(e)
    }
  }
  Ok(@immut_vector.Vector::from_array(out))
}

///|
fn parse_record(item : Json) -> Result[RecordDescriptor, String] {
  let kind = match get_required_string(item, "kind") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let record_id = match get_required_string(item, "id") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let doc = get_optional_string(item, "doc")
  let removed_numbers = match get_optional_int_vector(item, "removed_numbers") {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  if kind == "struct" {
    let fields_json = match get_required_array(item, "fields") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let fields : Array[StructField] = []
    for f in fields_json {
      let name = match get_required_string(f, "name") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let number = match get_required_int(f, "number") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let field_type_json = match get_object_field(f, "type") {
        Some(v) => v
        None => return Err("struct field is missing 'type'")
      }
      let field_type = match parse_type_signature(field_type_json) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let field_doc = get_optional_string(f, "doc")
      fields.push({ name, number, field_type, doc: field_doc, })
    }
    Ok(
      RecordDescriptor::Struct({
        record_id,
        doc,
        removed_numbers,
        fields: @immut_vector.Vector::from_array(fields),
      }),
    )
  } else if kind == "enum" {
    let variants_json = match get_required_array(item, "variants") {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let variants : Array[EnumVariant] = []
    for v in variants_json {
      let name = match get_required_string(v, "name") {
        Ok(v0) => v0
        Err(e) => return Err(e)
      }
      let number = match get_required_int(v, "number") {
        Ok(v0) => v0
        Err(e) => return Err(e)
      }
      let variant_doc = get_optional_string(v, "doc")
      match get_object_field(v, "type") {
        Some(type_json) => {
          let variant_type = match parse_type_signature(type_json) {
            Ok(v0) => v0
            Err(e) => return Err(e)
          }
          variants.push(
            EnumVariant::Wrapper({
              name,
              number,
              variant_type,
              doc: variant_doc,
            }),
          )
        }
        None =>
          variants.push(
            EnumVariant::Constant({ name, number, doc: variant_doc, }),
          )
      }
    }
    Ok(
      RecordDescriptor::Enum({
        record_id,
        doc,
        removed_numbers,
        variants: @immut_vector.Vector::from_array(variants),
      }),
    )
  } else {
    Err("unknown record kind")
  }
}

///|
fn parse_type_signature(v : Json) -> Result[TypeSignature, String] {
  let kind = match get_required_string(v, "kind") {
    Ok(v0) => v0
    Err(e) => return Err(e)
  }
  let value = match get_object_field(v, "value") {
    Some(x) => x
    None => return Err("type signature missing 'value'")
  }

  if kind == "primitive" {
    let primitive_name = match json_as_string(value) {
      Ok(v0) => v0
      Err(e) => return Err(e)
    }
    match parse_primitive_type(primitive_name) {
      Ok(p) => Ok(TypeSignature::Primitive(p))
      Err(e) => Err(e)
    }
  } else if kind == "optional" {
    let inner = match parse_type_signature(value) {
      Ok(v0) => v0
      Err(e) => return Err(e)
    }
    Ok(TypeSignature::Optional(inner))
  } else if kind == "array" {
    let item_json = match get_object_field(value, "item") {
      Some(x) => x
      None => return Err("array type signature missing 'item'")
    }
    let item_type = match parse_type_signature(item_json) {
      Ok(v0) => v0
      Err(e) => return Err(e)
    }
    let key_extractor = get_optional_string(value, "key_extractor")
    Ok(TypeSignature::Array({ item_type, key_extractor, }))
  } else if kind == "record" {
    let record_id = match json_as_string(value) {
      Ok(v0) => v0
      Err(e) => return Err(e)
    }
    Ok(TypeSignature::Record(record_id))
  } else {
    Err("unknown type kind")
  }
}

///|
fn parse_primitive_type(name : String) -> Result[PrimitiveType, String] {
  if name == "bool" {
    Ok(PrimitiveType::Bool)
  } else if name == "int32" {
    Ok(PrimitiveType::Int32)
  } else if name == "int64" {
    Ok(PrimitiveType::Int64)
  } else if name == "hash64" {
    Ok(PrimitiveType::Hash64)
  } else if name == "float32" {
    Ok(PrimitiveType::Float32)
  } else if name == "float64" {
    Ok(PrimitiveType::Float64)
  } else if name == "timestamp" {
    Ok(PrimitiveType::Timestamp)
  } else if name == "string" {
    Ok(PrimitiveType::String)
  } else if name == "bytes" {
    Ok(PrimitiveType::Bytes)
  } else {
    Err("unknown primitive type")
  }
}

///|
fn primitive_type_to_string(p : PrimitiveType) -> String {
  match p {
    PrimitiveType::Bool => "bool"
    PrimitiveType::Int32 => "int32"
    PrimitiveType::Int64 => "int64"
    PrimitiveType::Hash64 => "hash64"
    PrimitiveType::Float32 => "float32"
    PrimitiveType::Float64 => "float64"
    PrimitiveType::Timestamp => "timestamp"
    PrimitiveType::String => "string"
    PrimitiveType::Bytes => "bytes"
  }
}

///|
fn records_to_json(records : @immut_vector.Vector[RecordDescriptor]) -> String {
  if records.is_empty() {
    return "[]"
  }
  let parts : Array[String] = []
  for r in records.iter() {
    parts.push(record_to_json(r, "    "))
  }
  "[\n" + join_with_prefix(parts, "    ") + "\n  ]"
}

///|
fn record_to_json(r : RecordDescriptor, indent : String) -> String {
  match r {
    RecordDescriptor::Struct(s) => struct_record_to_json(s, indent)
    RecordDescriptor::Enum(e) => enum_record_to_json(e, indent)
  }
}

///|
fn struct_record_to_json(s : StructRecordDescriptor, indent : String) -> String {
  let inner = indent + "  "
  let lines : Array[String] = []
  lines.push(inner + "\"kind\": \"struct\"")
  lines.push(inner + "\"id\": " + quote_json_string(s.record_id))
  if s.doc != "" {
    lines.push(inner + "\"doc\": " + quote_json_string(s.doc))
  }

  let fields_parts : Array[String] = []
  for f in s.fields.iter() {
    fields_parts.push(struct_field_to_json(f, inner + "  "))
  }
  let fields_json = if fields_parts.is_empty() {
    "[]"
  } else {
    "[\n" + join_with_prefix(fields_parts, inner + "  ") + "\n" + inner + "]"
  }
  lines.push(inner + "\"fields\": " + fields_json)

  if !s.removed_numbers.is_empty() {
    lines.push(
      inner +
      "\"removed_numbers\": [" +
      join_int_vector(s.removed_numbers) +
      "]",
    )
  }

  "{\n" + join_lines(lines) + "\n" + indent + "}"
}

///|
fn enum_record_to_json(e : EnumRecordDescriptor, indent : String) -> String {
  let inner = indent + "  "
  let lines : Array[String] = []
  lines.push(inner + "\"kind\": \"enum\"")
  lines.push(inner + "\"id\": " + quote_json_string(e.record_id))
  if e.doc != "" {
    lines.push(inner + "\"doc\": " + quote_json_string(e.doc))
  }

  let variants_parts : Array[String] = []
  for v in e.variants.iter() {
    variants_parts.push(enum_variant_to_json(v, inner + "  "))
  }
  let variants_json = if variants_parts.is_empty() {
    "[]"
  } else {
    "[\n" + join_with_prefix(variants_parts, inner + "  ") + "\n" + inner + "]"
  }
  lines.push(inner + "\"variants\": " + variants_json)

  if !e.removed_numbers.is_empty() {
    lines.push(
      inner +
      "\"removed_numbers\": [" +
      join_int_vector(e.removed_numbers) +
      "]",
    )
  }

  "{\n" + join_lines(lines) + "\n" + indent + "}"
}

///|
fn struct_field_to_json(f : StructField, indent : String) -> String {
  let inner = indent + "  "
  let lines : Array[String] = []
  lines.push(inner + "\"name\": " + quote_json_string(f.name))
  lines.push(inner + "\"number\": " + f.number.to_string())
  lines.push(inner + "\"type\": " + type_signature_to_json(f.field_type, inner))
  if f.doc != "" {
    lines.push(inner + "\"doc\": " + quote_json_string(f.doc))
  }
  "{\n" + join_lines(lines) + "\n" + indent + "}"
}

///|
fn enum_variant_to_json(v : EnumVariant, indent : String) -> String {
  let inner = indent + "  "
  match v {
    EnumVariant::Constant(c) => {
      let lines : Array[String] = []
      lines.push(inner + "\"name\": " + quote_json_string(c.name))
      lines.push(inner + "\"number\": " + c.number.to_string())
      if c.doc != "" {
        lines.push(inner + "\"doc\": " + quote_json_string(c.doc))
      }
      "{\n" + join_lines(lines) + "\n" + indent + "}"
    }
    EnumVariant::Wrapper(w) => {
      let lines : Array[String] = []
      lines.push(inner + "\"name\": " + quote_json_string(w.name))
      lines.push(inner + "\"number\": " + w.number.to_string())
      lines.push(
        inner + "\"type\": " + type_signature_to_json(w.variant_type, inner),
      )
      if w.doc != "" {
        lines.push(inner + "\"doc\": " + quote_json_string(w.doc))
      }
      "{\n" + join_lines(lines) + "\n" + indent + "}"
    }
  }
}

///|
fn type_signature_to_json(sig : TypeSignature, indent : String) -> String {
  let inner = indent + "  "
  match sig {
    TypeSignature::Primitive(p) =>
      "{\n" +
      inner +
      "\"kind\": \"primitive\",\n" +
      inner +
      "\"value\": " +
      quote_json_string(primitive_type_to_string(p)) +
      "\n" +
      indent +
      "}"
    TypeSignature::Optional(other) =>
      "{\n" +
      inner +
      "\"kind\": \"optional\",\n" +
      inner +
      "\"value\": " +
      type_signature_to_json(other, inner) +
      "\n" +
      indent +
      "}"
    TypeSignature::Array(array_sig) => {
      let value_indent = inner + "  "
      let value_lines : Array[String] = []
      value_lines.push(
        value_indent +
        "\"item\": " +
        type_signature_to_json(array_sig.item_type, value_indent),
      )
      if array_sig.key_extractor != "" {
        value_lines.push(
          value_indent +
          "\"key_extractor\": " +
          quote_json_string(array_sig.key_extractor),
        )
      }
      "{\n" +
      inner +
      "\"kind\": \"array\",\n" +
      inner +
      "\"value\": {\n" +
      join_lines(value_lines) +
      "\n" +
      inner +
      "}\n" +
      indent +
      "}"
    }
    TypeSignature::Record(record_id) =>
      "{\n" +
      inner +
      "\"kind\": \"record\",\n" +
      inner +
      "\"value\": " +
      quote_json_string(record_id) +
      "\n" +
      indent +
      "}"
  }
}

///|
fn get_object_field(v : Json, key : String) -> Json? {
  match v {
    Json::Object(obj) => obj.get(key)
    _ => None
  }
}

///|
fn get_required_string(v : Json, key : String) -> Result[String, String] {
  match get_object_field(v, key) {
    Some(raw) => json_as_string(raw)
    None => Err("missing string field")
  }
}

///|
fn get_optional_string(v : Json, key : String) -> String {
  match get_object_field(v, key) {
    Some(Json::String(s)) => s
    _ => ""
  }
}

///|
fn get_required_array(v : Json, key : String) -> Result[Array[Json], String] {
  match get_object_field(v, key) {
    Some(Json::Array(arr)) => Ok(arr)
    Some(_) => Err("field is not an array")
    None => Err("missing array field")
  }
}

///|
fn get_required_int(v : Json, key : String) -> Result[Int, String] {
  match get_object_field(v, key) {
    Some(raw) => json_as_int(raw)
    None => Err("missing integer field")
  }
}

///|
fn get_optional_int_vector(
  v : Json,
  key : String,
) -> Result[@immut_vector.Vector[Int], String] {
  match get_object_field(v, key) {
    Some(Json::Array(arr)) => {
      let out : Array[Int] = []
      for item in arr {
        match json_as_int(item) {
          Ok(v0) => out.push(v0)
          Err(e) => return Err(e)
        }
      }
      Ok(@immut_vector.Vector::from_array(out))
    }
    Some(_) => Err("field is not an integer array")
    None => Ok(@immut_vector.Vector::new())
  }
}

///|
fn json_as_string(v : Json) -> Result[String, String] {
  match v {
    Json::String(s) => Ok(s)
    _ => Err("expected JSON string")
  }
}

///|
fn json_as_int(v : Json) -> Result[Int, String] {
  match v {
    Json::Number(n, ..) => Ok(n.to_int())
    _ => Err("expected JSON number")
  }
}

///|
fn quote_json_string(s : String) -> String {
  "\"" + s + "\""
}

///|
fn join_int_vector(items : @immut_vector.Vector[Int]) -> String {
  let mut out = ""
  let mut first = true
  for i in items.iter() {
    if first {
      first = false
      out = i.to_string()
    } else {
      out = out + ", " + i.to_string()
    }
  }
  out
}

///|
fn join_lines(lines : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for line in lines {
    if first {
      first = false
      out = line
    } else {
      out = out + ",\n" + line
    }
  }
  out
}

///|
fn join_with_prefix(parts : Array[String], _prefix : String) -> String {
  let mut out = ""
  let mut first = true
  for part in parts {
    if first {
      first = false
      out = part
    } else {
      out = out + ",\n" + part
    }
  }
  out
}
