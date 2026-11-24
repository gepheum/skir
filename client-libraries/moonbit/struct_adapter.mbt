///|
pub struct Internal_StructAdapter[T, Mutable] {
  priv module_path : String
  priv qualified_name : String
  priv doc : String
  priv new_mutable : () -> Mutable
  priv to_frozen : (Mutable) -> T
  priv get_unrecognized : (T) -> Internal_UnrecognizedFields?
  priv set_unrecognized : (Mutable, Internal_UnrecognizedFields?) -> Unit
  priv ordered_entries : Array[StructFieldEntry[T, Mutable]]
  priv name_to_index : @hashmap.HashMap[String, Int]
  priv slot_to_index : Array[Int?]
  priv removed_numbers : Array[Int]
}

///|
pub fn[T, Mutable] Internal_StructAdapter::new(
  module_path : String,
  qualified_name : String,
  doc : String,
  new_mutable : () -> Mutable,
  to_frozen : (Mutable) -> T,
  get_unrecognized : (T) -> Internal_UnrecognizedFields?,
  set_unrecognized : (Mutable, Internal_UnrecognizedFields?) -> Unit,
) -> Internal_StructAdapter[T, Mutable] {
  {
    module_path,
    qualified_name,
    doc,
    new_mutable,
    to_frozen,
    get_unrecognized,
    set_unrecognized,
    ordered_entries: [],
    name_to_index: @hashmap.HashMap([], capacity=16),
    slot_to_index: [],
    removed_numbers: [],
  }
}

///|
pub fn[T, Mutable, V] Internal_StructAdapter::add_field(
  self : Internal_StructAdapter[T, Mutable],
  name : String,
  number : Int,
  serializer : Serializer[V],
  getter : (T) -> V,
  setter : (Mutable, V) -> Unit,
  doc : String,
) -> Unit {
  let serializer = serializer.adapter
  let field_td = (serializer.type_descriptor)()
  let entry : StructFieldEntry[T, Mutable] = {
    number,
    name,
    doc,
    field_type: field_td.root_type,
    field_records: field_td.records,
    is_field_default: fn(input : T) { (serializer.is_default)(getter(input)) },
    field_to_dense_json: fn(input : T, out : StringBuilder) {
      (serializer.to_dense_json)(getter(input), out)
    },
    field_to_readable_json: fn(input : T) -> Json {
      (serializer.to_readable_json)(getter(input))
    },
    field_from_json: fn(
      input : Mutable,
      json : Json,
      policy : UnrecognizedValues,
    ) {
      match (serializer.from_json)(json, policy) {
        Ok(v) => {
          setter(input, v)
          Ok(())
        }
        Err(e) => Err(e)
      }
    },
    encode_field: fn(input : T, out : OutputStream) {
      (serializer.encode)(getter(input), out)
    },
    decode_field: fn(
      input : Mutable,
      in0 : InputStream,
      policy : UnrecognizedValues,
    ) {
      match (serializer.decode)(in0, policy) {
        Ok((v, tail)) => {
          setter(input, v)
          Ok(tail)
        }
        Err(e) => Err(e)
      }
    },
  }
  self.ordered_entries.push(entry)
}

///|
pub fn[T, Mutable] Internal_StructAdapter::add_removed_number(
  self : Internal_StructAdapter[T, Mutable],
  number : Int,
) -> Unit {
  self.removed_numbers.push(number)
}

///|
pub fn[T, Mutable] Internal_StructAdapter::finalize(
  self : Internal_StructAdapter[T, Mutable],
) -> Unit {
  self.name_to_index.clear()
  let mut max_field = -1
  for i in 0..<self.ordered_entries.length() {
    let e = self.ordered_entries[i]
    self.name_to_index.set(e.name, i)
    if e.number > max_field {
      max_field = e.number
    }
  }
  let mut max_removed = -1
  for n in self.removed_numbers {
    if n > max_removed {
      max_removed = n
    }
  }
  let max_number = if max_field > max_removed { max_field } else { max_removed }
  self.slot_to_index.clear()
  for _ in 0..<(max_number + 1) {
    self.slot_to_index.push(None)
  }
  for i in 0..<self.ordered_entries.length() {
    let n = self.ordered_entries[i].number
    if n >= 0 && n < self.slot_to_index.length() {
      self.slot_to_index[n] = Some(i)
    }
  }
}

///|
fn[T, Mutable] Internal_StructAdapter::get_slot_count(
  self : Internal_StructAdapter[T, Mutable],
  input : T,
) -> Int {
  let mut max_non_default = -1
  for e in self.ordered_entries {
    if !(e.is_field_default)(input) && e.number > max_non_default {
      max_non_default = e.number
    }
  }
  max_non_default + 1
}

///|
priv struct StructFieldEntry[T, Mutable] {
  number : Int
  name : String
  doc : String
  field_type : TypeSignature
  field_records : @immut_vector.Vector[RecordDescriptor]
  is_field_default : (T) -> Bool
  field_to_dense_json : (T, StringBuilder) -> Unit
  field_to_readable_json : (T) -> Json
  field_from_json : (Mutable, Json, UnrecognizedValues) -> Result[Unit, String]
  encode_field : (T, OutputStream) -> OutputStream
  decode_field : (Mutable, InputStream, UnrecognizedValues) -> Result[
    InputStream,
    String,
  ]
}

///|
fn[T, Mutable] Internal_StructAdapter::to_dense_json_impl(
  self : Internal_StructAdapter[T, Mutable],
  input : T,
  out : StringBuilder,
) -> Unit {
  let unrecognized = (self.get_unrecognized)(input)
  let mut total_slot_count = self.get_slot_count(input)
  let mut extra_values : Array[Json] = []

  match unrecognized {
    Some(u) =>
      match u.dense_json() {
        Some(Json::Array(values)) => {
          total_slot_count = u.array_len()
          extra_values = values
        }
        _ => ()
      }
    _ => ()
  }

  let recognized_max = self.slot_to_index.length()
  out.write_char('[')
  for i in 0..<struct_min(total_slot_count, recognized_max) {
    if i > 0 {
      out.write_char(',')
    }
    match self.slot_to_index[i] {
      Some(idx) => (self.ordered_entries[idx].field_to_dense_json)(input, out)
      None => out.write_char('0')
    }
  }

  if total_slot_count > recognized_max && !extra_values.is_empty() {
    for i in 0..<extra_values.length() {
      if recognized_max > 0 || i > 0 {
        out.write_char(',')
      }
      out.write_string(extra_values[i].stringify())
    }
  }
  out.write_char(']')
}

///|
fn[T, Mutable] Internal_StructAdapter::from_dense_json_impl(
  self : Internal_StructAdapter[T, Mutable],
  arr : Array[Json],
  policy : UnrecognizedValues,
) -> Result[T, String] {
  let value = (self.new_mutable)()
  for e in self.ordered_entries {
    let n = e.number
    if n < 0 || n >= arr.length() {
      continue
    }
    match (e.field_from_json)(value, arr[n], policy) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }

  if struct_should_keep_unrecognized(policy) {
    let recognized_max = self.slot_to_index.length()
    if arr.length() > recognized_max {
      let mut extra = "["
      for i in recognized_max..<arr.length() {
        if i > recognized_max {
          extra = extra + ","
        }
        extra = extra + arr[i].stringify()
      }
      extra = extra + "]"
      let ud = unrecognized_fields_from_json(arr.length(), parse_json(extra))
      (self.set_unrecognized)(value, Some(ud))
    }
  }

  Ok((self.to_frozen)(value))
}

///|
fn[T, Mutable] Internal_StructAdapter::from_readable_json_impl(
  self : Internal_StructAdapter[T, Mutable],
  json : Json,
  policy : UnrecognizedValues,
) -> Result[T, String] {
  match json {
    Json::Object(obj) => {
      let value = (self.new_mutable)()
      for e in self.ordered_entries {
        match obj.get(e.name) {
          Some(v) =>
            match (e.field_from_json)(value, v, policy) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          None => ()
        }
      }
      Ok((self.to_frozen)(value))
    }
    _ => Ok((self.to_frozen)((self.new_mutable)()))
  }
}

///|
fn struct_int_array_to_bytes(bytes : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  Bytes::from_array(out)
}

///|
fn struct_record_id(record : RecordDescriptor) -> String {
  match record {
    RecordDescriptor::Struct(value) => value.record_id
    RecordDescriptor::Enum(value) => value.record_id
  }
}

///|
fn[T, Mutable] Internal_StructAdapter::full_record_id(
  self : Internal_StructAdapter[T, Mutable],
) -> String {
  if self.qualified_name == "" {
    self.module_path
  } else {
    self.module_path + "." + self.qualified_name
  }
}

///|
fn struct_append_unique_records(
  target : Array[RecordDescriptor],
  source : @immut_vector.Vector[RecordDescriptor],
) -> Unit {
  for record in source {
    let record_id = struct_record_id(record)
    let mut seen = false
    for existing in target {
      if struct_record_id(existing) == record_id {
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
fn struct_should_keep_unrecognized(policy : UnrecognizedValues) -> Bool {
  match policy {
    UnrecognizedValues::Keep => true
    UnrecognizedValues::Drop => false
  }
}

///|
fn struct_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn skip_n_values(input : InputStream, n : Int) -> Result[InputStream, String] {
  let mut cur = input
  for _ in 0..<n {
    match skip_value(cur) {
      Ok(next) => cur = next
      Err(e) => return Err(e)
    }
  }
  Ok(cur)
}

///|
fn take_n_bytes(input : InputStream, n : Int) -> Result[InputStream, String] {
  let mut cur = input
  for _ in 0..<n {
    match cur.read_int() {
      Ok((_b, next)) => cur = next
      Err(e) => return Err(e)
    }
  }
  Ok(cur)
}

///|
fn skip_value(input : InputStream) -> Result[InputStream, String] {
  match input.read_int() {
    Ok((wire, rest)) =>
      match wire {
        0..=231 => Ok(rest)
        242 => Ok(rest)
        244 => Ok(rest)
        246 => Ok(rest)
        255 => Ok(rest)
        232 | 236 => take_n_bytes(rest, 2)
        233 | 237 | 240 => take_n_bytes(rest, 4)
        234 | 238 | 239 | 241 => take_n_bytes(rest, 8)
        235 => take_n_bytes(rest, 1)
        243 | 245 =>
          match decode_number_with_tail(rest) {
            Ok((n, tail)) if n >= 0 => take_n_bytes(tail, n.to_int())
            Ok(_) => Err("unexpected negative length in skip_value")
            Err(e) => Err(e)
          }
        247..=249 => skip_n_values(rest, wire - 246)
        250 =>
          match decode_number_with_tail(rest) {
            Ok((n, tail)) if n >= 0 => skip_n_values(tail, n.to_int())
            Ok(_) => Err("unexpected negative array length in skip_value")
            Err(e) => Err(e)
          }
        251..=254 => skip_value(rest)
        _ => Ok(rest)
      }
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Mutable] Internal_StructAdapter::serializer(
  self : Internal_StructAdapter[T, Mutable],
) -> Serializer[T] {
  new_serializer({
    is_default: fn(input : T) {
      match (self.get_unrecognized)(input) {
        Some(_) => false
        None => {
          for e in self.ordered_entries {
            if !(e.is_field_default)(input) {
              return false
            }
          }
          true
        }
      }
    },
    to_dense_json: fn(input : T, out : StringBuilder) {
      self.to_dense_json_impl(input, out)
    },
    to_readable_json: fn(input : T) {
      let entries : Array[(String, Json)] = []
      for e in self.ordered_entries {
        if (e.is_field_default)(input) {
          continue
        }
        entries.push((e.name, (e.field_to_readable_json)(input)))
      }
      Json::object(Map(entries))
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      match json {
        Json::Array(arr) => self.from_dense_json_impl(arr, policy)
        Json::Object(_) => self.from_readable_json_impl(json, policy)
        _ => Ok((self.to_frozen)((self.new_mutable)()))
      }
    },
    encode: fn(input : T, out : OutputStream) {
      let unrecognized = (self.get_unrecognized)(input)
      let mut total_slot_count = self.get_slot_count(input)
      let mut extra_bytes = Bytes::default()
      match unrecognized {
        Some(u) =>
          match u.bytes() {
            Some(values) => {
              total_slot_count = u.array_len()
              extra_bytes = values
            }
            _ => ()
          }
        _ => ()
      }

      let mut cur = out
      if total_slot_count <= 3 {
        cur = cur.write_int(246 + total_slot_count)
      } else {
        cur = cur.write_ints([250, ..encode_i32(total_slot_count)])
      }

      let recognized_count = self.slot_to_index.length()
      for i in 0..<struct_min(total_slot_count, recognized_count) {
        match self.slot_to_index[i] {
          Some(idx) =>
            cur = (self.ordered_entries[idx].encode_field)(input, cur)
          None => cur = cur.write_int(0)
        }
      }
      cur.write_bytes(extra_bytes)
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      let mut cur = input
      match cur.read_int() {
        Ok((wire, rest)) => {
          cur = rest
          if wire == 0 || wire == 246 {
            return Ok(((self.to_frozen)((self.new_mutable)()), cur))
          }

          let slot_count = if wire == 250 {
            match decode_number_with_tail(cur) {
              Ok((n, tail)) if n >= 0 => {
                cur = tail
                n.to_int()
              }
              Ok(_) => return Err("unexpected negative struct slot count")
              Err(e) => return Err(e)
            }
          } else {
            wire - 246
          }

          let value = (self.new_mutable)()
          let recognized_count = self.slot_to_index.length()
          let slots_to_fill = struct_min(slot_count, recognized_count)

          for i in 0..<slots_to_fill {
            match self.slot_to_index[i] {
              Some(idx) =>
                match
                  (self.ordered_entries[idx].decode_field)(value, cur, policy) {
                  Ok(next_stream) => cur = next_stream
                  Err(e) => return Err(e)
                }
              None =>
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
            }
          }

          if slot_count > recognized_count {
            if struct_should_keep_unrecognized(policy) {
              let before = cur.remaining_int_array()
              for _ in recognized_count..<slot_count {
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
              }
              let after_len = cur.remaining_int_array().length()
              let consumed_len = before.length() - after_len
              let captured = before[0:consumed_len].iter().to_array()
              (self.set_unrecognized)(
                value,
                Some(
                  unrecognized_fields_from_bytes(
                    slot_count,
                    struct_int_array_to_bytes(captured),
                  ),
                ),
              )
            } else {
              for _ in recognized_count..<slot_count {
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
              }
            }
          }

          Ok(((self.to_frozen)(value), cur))
        }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      let fields : Array[StructField] = []
      for e in self.ordered_entries {
        fields.push({
          name: e.name,
          number: e.number,
          field_type: e.field_type,
          doc: e.doc,
        })
      }
      let records : Array[RecordDescriptor] = []
      let record_id = self.full_record_id()
      records.push(
        RecordDescriptor::Struct({
          record_id,
          doc: self.doc,
          removed_numbers: @immut_vector.Vector::from_array(
            self.removed_numbers,
          ),
          fields: @immut_vector.Vector::from_array(fields),
        }),
      )
      for e in self.ordered_entries {
        struct_append_unique_records(records, e.field_records)
      }
      {
        root_type: TypeSignature::Record(record_id),
        records: @immut_vector.Vector::from_array(records),
      }
    },
  })
}
