///|
pub struct Internal_EnumAdapter[T] {
  priv module_path : String
  priv qualified_name : String
  priv doc : String
  priv default_value : T
  priv get_kind_ordinal : (T) -> Int32
  priv wrap_unrecognized : (Internal_UnrecognizedVariant) -> T
  priv get_unrecognized : (T) -> Internal_UnrecognizedVariant?
  priv number_to_entry : @hashmap.HashMap[Int32, EnumAnyEntry]
  priv removed_numbers : Array[Int32]
  priv name_to_kind_ordinal : @hashmap.HashMap[String, Int32]
  priv kind_ordinal_to_entry : Array[EnumVariantEntry[T]?]
  priv desc_variants : Array[EnumVariant]
}

///|
pub fn[T] Internal_EnumAdapter::new(
  module_path : String,
  qualified_name : String,
  doc : String,
  default_value : T,
  get_kind_ordinal : (T) -> Int32,
  wrap_unrecognized : (Internal_UnrecognizedVariant) -> T,
  get_unrecognized : (T) -> Internal_UnrecognizedVariant?,
) -> Internal_EnumAdapter[T] {
  {
    module_path,
    qualified_name,
    doc,
    default_value,
    get_kind_ordinal,
    wrap_unrecognized,
    get_unrecognized,
    number_to_entry: @hashmap.HashMap([], capacity=16),
    removed_numbers: [],
    name_to_kind_ordinal: @hashmap.HashMap([], capacity=16),
    kind_ordinal_to_entry: [None],
    desc_variants: [],
  }
}

///|
pub fn[T] Internal_EnumAdapter::add_constant_variant(
  self : Internal_EnumAdapter[T],
  name : String,
  number : Int32,
  kind_ordinal : Int32,
  doc : String,
  instance : T,
) -> Unit {
  self.number_to_entry.set(number, EnumAnyEntry::Constant(kind_ordinal))
  self.name_to_kind_ordinal.set(name, kind_ordinal)
  let upper = name.to_upper()
  if upper != name {
    self.name_to_kind_ordinal.set(upper, kind_ordinal)
  }
  let lower = name.to_lower()
  if lower != name {
    self.name_to_kind_ordinal.set(lower, kind_ordinal)
  }

  let entry : EnumVariantEntry[T] = {
    constant: fn() { Some(instance) },
    wrapper_default: fn() { self.default_value },
    variant_to_dense_json: fn(_input : T, out : StringBuilder) {
      out.write_string(number.to_string())
    },
    variant_to_readable_json: fn(_input : T) { Json::string(name) },
    encode_value: fn(_input : T, out0 : OutputStream) {
      let out = out0
      out.write_ints(encode_i32(number))
    },
    wrap_from_json: fn(_json, _policy) {
      Err("variant '" + name + "' is a constant, not a wrapper")
    },
    wrap_decode: fn(_input, _policy) {
      Err("variant '" + name + "' is a constant, not a wrapper")
    },
    descriptor_variant: EnumVariant::Constant({ name, number, doc, }),
    child_records: @immut_vector.Vector::new(),
  }
  self.set_kind_ordinal_entry(kind_ordinal, entry)
  self.desc_variants.push(entry.descriptor_variant)
}

///|
pub fn[T, V] Internal_EnumAdapter::add_wrapper_variant(
  self : Internal_EnumAdapter[T],
  name : String,
  number : Int32,
  kind_ordinal : Int32,
  serializer : Serializer[V],
  doc : String,
  wrap : (V) -> T,
  get_value : (T) -> V,
) -> Unit {
  let serializer = serializer.adapter
  self.number_to_entry.set(number, EnumAnyEntry::Wrapper(kind_ordinal))
  self.name_to_kind_ordinal.set(name, kind_ordinal)
  let variant_td = (serializer.type_descriptor)()

  let entry : EnumVariantEntry[T] = {
    constant: fn() { None },
    wrapper_default: fn() {
      match (serializer.from_json)(parse_json("0"), UnrecognizedValues::Drop) {
        Ok(v) => wrap(v)
        Err(_) => self.default_value
      }
    },
    variant_to_dense_json: fn(input : T, out : StringBuilder) {
      let value = get_value(input)
      out.write_char('[')
      out.write_string(number.to_string())
      out.write_char(',')
      (serializer.to_dense_json)(value, out)
      out.write_char(']')
    },
    variant_to_readable_json: fn(input : T) {
      let value = get_value(input)
      Json::object(
        Map([
          ("kind", Json::string(name)),
          ("value", (serializer.to_readable_json)(value)),
        ]),
      )
    },
    encode_value: fn(input : T, out0 : OutputStream) {
      let mut out = out0
      if number >= 1 && number <= 4 {
        out = out.write_int(250 + number)
      } else {
        out = out.write_int(248)
        out = out.write_ints(encode_i32(number))
      }
      (serializer.encode)(get_value(input), out)
    },
    wrap_from_json: fn(json : Json, policy : UnrecognizedValues) {
      match (serializer.from_json)(json, policy) {
        Ok(v) => Ok(wrap(v))
        Err(e) => Err(e)
      }
    },
    wrap_decode: fn(input : InputStream, policy : UnrecognizedValues) {
      match (serializer.decode)(input, policy) {
        Ok((v, tail)) => Ok((wrap(v), tail))
        Err(e) => Err(e)
      }
    },
    descriptor_variant: EnumVariant::Wrapper({
      name,
      number,
      variant_type: variant_td.root_type,
      doc,
    }),
    child_records: variant_td.records,
  }

  self.set_kind_ordinal_entry(kind_ordinal, entry)
  self.desc_variants.push(entry.descriptor_variant)
}

///|
pub fn[T] Internal_EnumAdapter::add_removed_number(
  self : Internal_EnumAdapter[T],
  number : Int32,
) -> Unit {
  self.number_to_entry.set(number, EnumAnyEntry::Removed)
  self.removed_numbers.push(number)
}

///|
pub fn[T] Internal_EnumAdapter::finalize(
  self : Internal_EnumAdapter[T],
) -> Unit {
  self.name_to_kind_ordinal.set("UNKNOWN", 0)
  self.name_to_kind_ordinal.set("unknown", 0)
}

///|
priv enum EnumAnyEntry {
  Removed
  Constant(Int32)
  Wrapper(Int32)
}

///|
priv struct EnumVariantEntry[T] {
  constant : () -> T?
  wrapper_default : () -> T
  variant_to_dense_json : (T, StringBuilder) -> Unit
  variant_to_readable_json : (T) -> Json
  encode_value : (T, OutputStream) -> OutputStream
  wrap_from_json : (Json, UnrecognizedValues) -> Result[T, String]
  wrap_decode : (InputStream, UnrecognizedValues) -> Result[
    (T, InputStream),
    String,
  ]
  descriptor_variant : EnumVariant
  child_records : @immut_vector.Vector[RecordDescriptor]
}

///|
fn[T] Internal_EnumAdapter::set_kind_ordinal_entry(
  self : Internal_EnumAdapter[T],
  kind_ordinal : Int32,
  entry : EnumVariantEntry[T],
) -> Unit {
  while self.kind_ordinal_to_entry.length() <= kind_ordinal {
    self.kind_ordinal_to_entry.push(None)
  }
  self.kind_ordinal_to_entry[kind_ordinal] = Some(entry)
}

///|
fn[T] Internal_EnumAdapter::contains_removed(
  self : Internal_EnumAdapter[T],
  number : Int32,
) -> Bool {
  for n in self.removed_numbers {
    if n == number {
      return true
    }
  }
  false
}

///|
fn enum_is_keep(policy : UnrecognizedValues) -> Bool {
  match policy {
    UnrecognizedValues::Keep => true
    UnrecognizedValues::Drop => false
  }
}

///|
fn[T] Internal_EnumAdapter::entry_at_kind(
  self : Internal_EnumAdapter[T],
  ko : Int32,
) -> EnumVariantEntry[T]? {
  if ko >= 0 && ko < self.kind_ordinal_to_entry.length() {
    self.kind_ordinal_to_entry[ko]
  } else {
    None
  }
}

///|
fn enum_int_array_to_bytes(bytes : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  Bytes::from_array(out)
}

///|
fn enum_record_id(record : RecordDescriptor) -> String {
  match record {
    RecordDescriptor::Struct(value) => value.record_id
    RecordDescriptor::Enum(value) => value.record_id
  }
}

///|
fn[T] Internal_EnumAdapter::full_record_id(
  self : Internal_EnumAdapter[T],
) -> String {
  if self.qualified_name == "" {
    self.module_path
  } else {
    self.module_path + "." + self.qualified_name
  }
}

///|
fn enum_append_unique_records(
  target : Array[RecordDescriptor],
  source : @immut_vector.Vector[RecordDescriptor],
) -> Unit {
  for record in source {
    let record_id = enum_record_id(record)
    let mut seen = false
    for existing in target {
      if enum_record_id(existing) == record_id {
        seen = true
        break
      }
    }
    if !seen {
      target.push(record)
    }
  }
}

///|
pub fn[T] Internal_EnumAdapter::serializer(
  self : Internal_EnumAdapter[T],
) -> Serializer[T] {
  new_serializer({
    is_default: fn(input : T) { (self.get_kind_ordinal)(input) == 0 },
    to_dense_json: fn(input : T, out : StringBuilder) {
      let ko = (self.get_kind_ordinal)(input)
      if ko == 0 {
        match (self.get_unrecognized)(input) {
          Some(u) =>
            match u.dense_json() {
              Some(json) => {
                out.write_string(json.stringify())
                return
              }
              None =>
                match u.bytes() {
                  Some(bytes) =>
                    if !bytes.is_empty() {
                      match self.number_to_entry.get(u.number()) {
                        Some(_) => {
                          out.write_string(u.number().to_string())
                          return
                        }
                        None => ()
                      }
                    }
                  None => ()
                }
            }
          None => ()
        }
        out.write_char('0')
        return
      }

      match self.entry_at_kind(ko) {
        Some(e) => (e.variant_to_dense_json)(input, out)
        None => out.write_char('0')
      }
    },
    to_readable_json: fn(input : T) {
      let ko = (self.get_kind_ordinal)(input)
      if ko == 0 {
        Json::string("unknown")
      } else {
        match self.entry_at_kind(ko) {
          Some(e) => (e.variant_to_readable_json)(input)
          None => Json::string("unknown")
        }
      }
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      let keep = enum_is_keep(policy)
      match json {
        Json::Number(n, ..) => {
          let number = n.to_int()
          match self.number_to_entry.get(number) {
            Some(EnumAnyEntry::Removed) => Ok(self.default_value)
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            Some(EnumAnyEntry::Wrapper(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) => Ok((e.wrapper_default)())
                None => Ok(self.default_value)
              }
            None =>
              if keep {
                Ok(
                  (self.wrap_unrecognized)(
                    unrecognized_variant_from_json(number, json),
                  ),
                )
              } else {
                Ok(self.default_value)
              }
          }
        }
        Json::True =>
          match self.number_to_entry.get(1) {
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            _ => Ok(self.default_value)
          }
        Json::False =>
          match self.number_to_entry.get(0) {
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            _ => Ok(self.default_value)
          }
        Json::String(s) =>
          match self.name_to_kind_ordinal.get(s) {
            Some(ko) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok((e.wrapper_default)())
                  }
                None => Ok(self.default_value)
              }
            None => Ok(self.default_value)
          }
        Json::Array(arr) if arr.length() == 2 => {
          let number = match arr[0] {
            Json::Number(n, ..) => n.to_int()
            _ => 0
          }
          match self.number_to_entry.get(number) {
            Some(EnumAnyEntry::Removed) => Ok(self.default_value)
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            Some(EnumAnyEntry::Wrapper(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) => (e.wrap_from_json)(arr[1], policy)
                None => Ok(self.default_value)
              }
            None =>
              if keep {
                Ok(
                  (self.wrap_unrecognized)(
                    unrecognized_variant_from_json(number, json),
                  ),
                )
              } else {
                Ok(self.default_value)
              }
          }
        }
        Json::Object(obj) => {
          let name = match obj.get("kind") {
            Some(Json::String(s)) => s
            _ => ""
          }
          let value_json_opt = obj.get("value")
          match self.name_to_kind_ordinal.get(name) {
            Some(ko) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None =>
                      match value_json_opt {
                        Some(value_json) =>
                          (e.wrap_from_json)(value_json, policy)
                        None => (e.wrap_from_json)(parse_json("null"), policy)
                      }
                  }
                None => Ok(self.default_value)
              }
            None => Ok(self.default_value)
          }
        }
        _ => Ok(self.default_value)
      }
    },
    encode: fn(input : T, out0 : OutputStream) {
      let ko = (self.get_kind_ordinal)(input)
      if ko == 0 {
        match (self.get_unrecognized)(input) {
          Some(u) =>
            match u.bytes() {
              Some(bytes) if !bytes.is_empty() => {
                let out = out0
                out.write_bytes(bytes)
              }
              _ => out0.write_int(0)
            }
          _ => out0.write_int(0)
        }
      } else {
        match self.entry_at_kind(ko) {
          Some(e) => (e.encode_value)(input, out0)
          None => out0.write_int(0)
        }
      }
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      let keep = enum_is_keep(policy)
      let before = input.remaining_int_array()
      match input.read_int() {
        Ok((wire, rest)) =>
          if wire < 242 {
            match decode_number_body(wire, rest) {
              Ok((n, tail)) => {
                let number = n.to_int()
                match self.number_to_entry.get(number) {
                  Some(EnumAnyEntry::Removed) => Ok((self.default_value, tail))
                  Some(EnumAnyEntry::Constant(ko)) =>
                    match self.entry_at_kind(ko) {
                      Some(e) =>
                        match (e.constant)() {
                          Some(v) => Ok((v, tail))
                          None => Ok((self.default_value, tail))
                        }
                      None => Ok((self.default_value, tail))
                    }
                  Some(EnumAnyEntry::Wrapper(ko)) =>
                    match self.entry_at_kind(ko) {
                      Some(e) => Ok(((e.wrapper_default)(), tail))
                      None => Ok((self.default_value, tail))
                    }
                  None =>
                    if keep && !self.contains_removed(number) {
                      let consumed_len = before.length() -
                        tail.remaining_int_array().length()
                      let captured = before[0:consumed_len]
                      Ok(
                        (
                          (self.wrap_unrecognized)(
                            unrecognized_variant_from_bytes(
                              number,
                              enum_int_array_to_bytes(
                                captured.iter().to_array(),
                              ),
                            ),
                          ),
                          tail,
                        ),
                      )
                    } else {
                      Ok((self.default_value, tail))
                    }
                }
              }
              Err(e) => Err(e)
            }
          } else {
            let mut number = 0
            let mut cur = rest
            if wire == 248 {
              match decode_number_with_tail(cur) {
                Ok((n, tail)) => {
                  number = n.to_int()
                  cur = tail
                }
                Err(e) => return Err(e)
              }
            } else {
              number = wire - 250
            }

            match self.number_to_entry.get(number) {
              Some(EnumAnyEntry::Removed) =>
                match skip_value(cur) {
                  Ok(next) => Ok((self.default_value, next))
                  Err(e) => Err(e)
                }
              Some(EnumAnyEntry::Constant(ko)) =>
                match skip_value(cur) {
                  Ok(next) =>
                    match self.entry_at_kind(ko) {
                      Some(e) =>
                        match (e.constant)() {
                          Some(v) => Ok((v, next))
                          None => Ok((self.default_value, next))
                        }
                      None => Ok((self.default_value, next))
                    }
                  Err(e) => Err(e)
                }
              Some(EnumAnyEntry::Wrapper(ko)) =>
                match self.entry_at_kind(ko) {
                  Some(e) => (e.wrap_decode)(cur, policy)
                  None => Ok((self.default_value, cur))
                }
              None =>
                match skip_value(cur) {
                  Ok(next) =>
                    if keep && !self.contains_removed(number) {
                      let consumed_len = before.length() -
                        next.remaining_int_array().length()
                      let captured = before[0:consumed_len]
                      Ok(
                        (
                          (self.wrap_unrecognized)(
                            unrecognized_variant_from_bytes(
                              number,
                              enum_int_array_to_bytes(
                                captured.iter().to_array(),
                              ),
                            ),
                          ),
                          next,
                        ),
                      )
                    } else {
                      Ok((self.default_value, next))
                    }
                  Err(e) => Err(e)
                }
            }
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      let records : Array[RecordDescriptor] = []
      let record_id = self.full_record_id()
      records.push(
        RecordDescriptor::Enum({
          record_id,
          doc: self.doc,
          removed_numbers: @immut_vector.Vector::from_array(
            self.removed_numbers,
          ),
          variants: @immut_vector.Vector::from_array(self.desc_variants),
        }),
      )
      for entry_opt in self.kind_ordinal_to_entry {
        match entry_opt {
          Some(entry) =>
            enum_append_unique_records(records, entry.child_records)
          None => ()
        }
      }
      {
        root_type: TypeSignature::Record(record_id),
        records: @immut_vector.Vector::from_array(records),
      }
    },
  })
}
