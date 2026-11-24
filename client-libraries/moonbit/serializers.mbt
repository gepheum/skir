///|
pub fn bool_serializer() -> Serializer[Bool] {
  new_serializer({
    is_default: fn(input : Bool) { !input },
    to_dense_json: fn(input : Bool, builder : StringBuilder) {
      builder.write_string(if input { "1" } else { "0" })
    },
    to_readable_json: fn(input : Bool) {
      parse_json(if input { "true" } else { "false" })
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::True => Ok(true)
        Json::False => Ok(false)
        Json::Number(n, ..) => Ok(n.to_int() != 0)
        Json::String(s) => Ok(s != "0")
        _ => Ok(false)
      }
    },
    encode: fn(input : Bool, out : OutputStream) {
      if input {
        out.write_int(1)
      } else {
        out.write_int(0)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input.read_int() {
        Ok((b, tail)) => Ok((b != 0, tail))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Bool),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
let max_safe_int64_json : Int64 = 9007199254740991L

///|
let max_safe_hash64_json : UInt64 = 9007199254740991UL

///|
fn parse_json(code : String) -> Json {
  @json.parse(code) catch {
    _ => panic()
  }
}

///|
fn hex_digit(n : Int) -> Char {
  match n {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

///|
fn append_json_string(builder : StringBuilder, s : String) -> Unit {
  builder.write_char('"')
  for ch in s.iter() {
    match ch {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\b' => builder.write_string("\\b")
      '\f' => builder.write_string("\\f")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => {
        let code = ch.to_int()
        if code < 0x20 {
          builder.write_string("\\u00")
          builder.write_char(hex_digit((code >> 4) & 0xF))
          builder.write_char(hex_digit(code & 0xF))
        } else {
          builder.write_char(ch)
        }
      }
    }
  }
  builder.write_char('"')
}

///|
fn json_quoted_string(s : String) -> String {
  let builder = StringBuilder()
  append_json_string(builder, s)
  builder.to_string()
}

///|
fn read_n_bytes(
  input : InputStream,
  length : Int,
) -> Result[(Bytes, InputStream), String] {
  let mut cur = input
  let out : Array[Byte] = []
  for _ in 0..<length {
    match cur.read_int() {
      Ok((b, next)) => {
        out.push(b.to_byte())
        cur = next
      }
      Err(e) => return Err(e)
    }
  }
  Ok((Bytes::from_array(out), cur))
}

///|
fn encode_length_prefixed_bytes(
  out : OutputStream,
  wire : Int,
  length : Int,
) -> OutputStream {
  if length < 232 {
    out.write_ints([wire, length])
  } else if length < 65536 {
    out.write_ints([wire, 232, length & 0xFF, (length >> 8) & 0xFF])
  } else {
    out.write_ints([
      wire,
      233,
      length & 0xFF,
      (length >> 8) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 24) & 0xFF,
    ])
  }
}

///|
fn json_number_or_quoted_string(code : String) -> Json {
  if code == "Infinity" || code == "-Infinity" || code == "NaN" {
    parse_json("\"" + code + "\"")
  } else {
    parse_json(code)
  }
}

///|
fn decode_number_with_tail(
  input : InputStream,
) -> Result[(Int64, InputStream), String] {
  match input.read_int() {
    Ok((wire, rest)) => decode_number_body(wire, rest)
    Err(e) => Err(e)
  }
}

///|
fn bytes_to_hex_string(bytes : Bytes) -> String {
  let builder = StringBuilder()
  for byte in bytes.to_array() {
    let n = byte.to_int()
    builder.write_char(hex_digit((n >> 4) & 0xF))
    builder.write_char(hex_digit(n & 0xF))
  }
  builder.to_string()
}

///|
pub fn string_serializer() -> Serializer[String] {
  new_serializer({
    is_default: fn(input : String) { input == "" },
    to_dense_json: fn(input : String, builder : StringBuilder) {
      append_json_string(builder, input)
    },
    to_readable_json: fn(input : String) {
      parse_json(json_quoted_string(input))
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::String(s) => Ok(s)
        Json::Number(n, ..) =>
          if n == 0.0 {
            Ok("")
          } else {
            Err("expected string")
          }
        _ => Err("expected string")
      }
    },
    encode: fn(input : String, out : OutputStream) {
      let bytes = @utf8.encode(input)
      if bytes.is_empty() {
        out.write_int(242)
      } else {
        let out = encode_length_prefixed_bytes(out, 243, bytes.length())
        out.write_bytes(bytes)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input.read_int() {
        Ok((wire, rest)) =>
          match wire {
            0 => Ok(("", rest))
            242 => Ok(("", rest))
            243 =>
              match decode_number_with_tail(rest) {
                Ok((length, tail)) =>
                  match read_n_bytes(tail, length.to_int()) {
                    Ok((bytes, next)) =>
                      Ok((@utf8.decode(bytes[:]), next)) catch {
                        _ => Err("invalid UTF-8")
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            _ => Err("expected string")
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::String),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn bytes_serializer() -> Serializer[Bytes] {
  new_serializer({
    is_default: fn(input : Bytes) { input.is_empty() },
    to_dense_json: fn(input : Bytes, builder : StringBuilder) {
      append_json_string(builder, @base64.encode(input))
    },
    to_readable_json: fn(input : Bytes) {
      parse_json(json_quoted_string("hex:" + bytes_to_hex_string(input)))
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::String(s) =>
          if s.has_prefix("hex:") {
            let hex = s[4:]
            if hex.length() == 0 {
              Ok(Bytes::default())
            } else if hex.length() % 2 != 0 {
              Err("invalid hex bytes")
            } else {
              let mut cur = 0
              let out : Array[Byte] = []
              while cur < hex.length() {
                let byte_text = hex[cur:cur + 2]
                try {
                  let value = @string.parse_uint(byte_text, base=16)
                  out.push(value.to_byte())
                } catch {
                  _ => return Err("invalid hex bytes")
                }
                cur = cur + 2
              }
              Ok(Bytes::from_array(out))
            }
          } else {
            Ok(@base64.decode(s)) catch {
              _ => Err("invalid base64 bytes")
            }
          }
        Json::Number(n, ..) =>
          if n == 0.0 {
            Ok(Bytes::default())
          } else {
            Err("expected bytes")
          }
        _ => Err("expected bytes")
      }
    },
    encode: fn(input : Bytes, out : OutputStream) {
      if input.is_empty() {
        out.write_int(244)
      } else {
        let out = encode_length_prefixed_bytes(out, 245, input.length())
        out.write_bytes(input)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input.read_int() {
        Ok((wire, rest)) =>
          match wire {
            0 => Ok((Bytes::default(), rest))
            244 => Ok((Bytes::default(), rest))
            245 =>
              match decode_number_with_tail(rest) {
                Ok((length, tail)) =>
                  match read_n_bytes(tail, length.to_int()) {
                    Ok((bytes, next)) => Ok((bytes, next))
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            _ => Err("expected bytes")
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Bytes),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
fn encode_u16_le(v : Int) -> Array[Int] {
  [v & 0xFF, (v >> 8) & 0xFF]
}

///|
fn encode_u32_le(v : Int) -> Array[Int] {
  [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]
}

///|
fn encode_i64_le(v : Int64) -> Array[Int] {
  encode_u64_le(v.reinterpret_as_uint64())
}

///|
fn encode_u64_le(v : UInt64) -> Array[Int] {
  [
    (v & 0xFFUL).to_int(),
    ((v >> 8) & 0xFFUL).to_int(),
    ((v >> 16) & 0xFFUL).to_int(),
    ((v >> 24) & 0xFFUL).to_int(),
    ((v >> 32) & 0xFFUL).to_int(),
    ((v >> 40) & 0xFFUL).to_int(),
    ((v >> 48) & 0xFFUL).to_int(),
    ((v >> 56) & 0xFFUL).to_int(),
  ]
}

///|
fn encode_i32(v : Int) -> Array[Int] {
  if v < -65536 {
    [237, ..encode_u32_le(v)]
  } else if v < -256 {
    [236, ..encode_u16_le(v)]
  } else if v < 0 {
    [235, v & 0xFF]
  } else if v <= 231 {
    [v]
  } else if v <= 65535 {
    [232, ..encode_u16_le(v)]
  } else {
    [233, ..encode_u32_le(v)]
  }
}

///|
fn read_u16(input : InputStream) -> Result[(Int, InputStream), String] {
  match input.read_int() {
    Ok((b0, tail0)) =>
      match tail0.read_int() {
        Ok((b1, tail1)) => Ok((b0 | (b1 << 8), tail1))
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

///|
fn read_u32(input : InputStream) -> Result[(Int64, InputStream), String] {
  match input.read_int() {
    Ok((b0, tail0)) =>
      match tail0.read_int() {
        Ok((b1, tail1)) =>
          match tail1.read_int() {
            Ok((b2, tail2)) =>
              match tail2.read_int() {
                Ok((b3, tail3)) => {
                  let v = Int64::from_int(b0) |
                    (Int64::from_int(b1) << 8) |
                    (Int64::from_int(b2) << 16) |
                    (Int64::from_int(b3) << 24)
                  Ok((v, tail3))
                }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

///|
fn read_i32(input : InputStream) -> Result[(Int, InputStream), String] {
  match read_u32(input) {
    Ok((u, rest)) =>
      if u >= 2147483648L {
        Ok(((u - 4294967296L).to_int(), rest))
      } else {
        Ok((u.to_int(), rest))
      }
    Err(e) => Err(e)
  }
}

///|
fn read_i64(input : InputStream) -> Result[(Int64, InputStream), String] {
  match input.read_int() {
    Ok((b0, tail0)) =>
      match tail0.read_int() {
        Ok((b1, tail1)) =>
          match tail1.read_int() {
            Ok((b2, tail2)) =>
              match tail2.read_int() {
                Ok((b3, tail3)) =>
                  match tail3.read_int() {
                    Ok((b4, tail4)) =>
                      match tail4.read_int() {
                        Ok((b5, tail5)) =>
                          match tail5.read_int() {
                            Ok((b6, tail6)) =>
                              match tail6.read_int() {
                                Ok((b7, tail7)) => {
                                  let v = Int64::from_int(b0) |
                                    (Int64::from_int(b1) << 8) |
                                    (Int64::from_int(b2) << 16) |
                                    (Int64::from_int(b3) << 24) |
                                    (Int64::from_int(b4) << 32) |
                                    (Int64::from_int(b5) << 40) |
                                    (Int64::from_int(b6) << 48) |
                                    (Int64::from_int(b7) << 56)
                                  Ok((v, tail7))
                                }
                                Err(e) => Err(e)
                              }
                            Err(e) => Err(e)
                          }
                        Err(e) => Err(e)
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

///|
fn read_u64(input : InputStream) -> Result[(UInt64, InputStream), String] {
  match input.read_int() {
    Ok((b0, tail0)) =>
      match tail0.read_int() {
        Ok((b1, tail1)) =>
          match tail1.read_int() {
            Ok((b2, tail2)) =>
              match tail2.read_int() {
                Ok((b3, tail3)) =>
                  match tail3.read_int() {
                    Ok((b4, tail4)) =>
                      match tail4.read_int() {
                        Ok((b5, tail5)) =>
                          match tail5.read_int() {
                            Ok((b6, tail6)) =>
                              match tail6.read_int() {
                                Ok((b7, tail7)) => {
                                  let v = b0.to_uint64() |
                                    (b1.to_uint64() << 8) |
                                    (b2.to_uint64() << 16) |
                                    (b3.to_uint64() << 24) |
                                    (b4.to_uint64() << 32) |
                                    (b5.to_uint64() << 40) |
                                    (b6.to_uint64() << 48) |
                                    (b7.to_uint64() << 56)
                                  Ok((v, tail7))
                                }
                                Err(e) => Err(e)
                              }
                            Err(e) => Err(e)
                          }
                        Err(e) => Err(e)
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

///|
fn decode_number_body(
  wire : Int,
  input : InputStream,
) -> Result[(Int64, InputStream), String] {
  match wire {
    0..=231 => Ok((Int64::from_int(wire), input))
    232 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v), rest))
        Err(e) => Err(e)
      }
    233 =>
      match read_u32(input) {
        Ok((v, rest)) => Ok((v, rest))
        Err(e) => Err(e)
      }
    234 =>
      match read_u64(input) {
        Ok((v, rest)) => Ok((v.reinterpret_as_int64(), rest))
        Err(e) => Err(e)
      }
    235 =>
      match input.read_int() {
        Ok((b, rest)) => Ok((Int64::from_int(b - 256), rest))
        Err(e) => Err(e)
      }
    236 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v - 65536), rest))
        Err(e) => Err(e)
      }
    237 =>
      match read_i32(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v), rest))
        Err(e) => Err(e)
      }
    238 => read_i64(input)
    239 => read_i64(input)
    240 =>
      match input.read_int() {
        Ok((b0, tail0)) =>
          match tail0.read_int() {
            Ok((b1, tail1)) =>
              match tail1.read_int() {
                Ok((b2, tail2)) =>
                  match tail2.read_int() {
                    Ok((b3, tail3)) => {
                      let bits = b0.reinterpret_as_uint() |
                        (b1.reinterpret_as_uint() << 8) |
                        (b2.reinterpret_as_uint() << 16) |
                        (b3.reinterpret_as_uint() << 24)
                      let f = Float::reinterpret_from_uint(bits)
                      Ok((Int64::from_int(f.trunc().to_int()), tail3))
                    }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    241 =>
      match read_i64(input) {
        Ok((bits, rest)) => {
          let d = bits.reinterpret_as_double()
          Ok((d.trunc().to_int64(), rest))
        }
        Err(e) => Err(e)
      }
    _ => Ok((0L, input))
  }
}

///|
fn parse_double_or_zero(s : String) -> Double {
  @string.parse_double(s) catch {
    _ => 0.0
  }
}

///|
fn parse_int64_or_zero(s : String) -> Int64 {
  @string.parse_int64(s) catch {
    _ => 0L
  }
}

///|
fn json_number_looks_integral(raw : String) -> Bool {
  for ch in raw.iter() {
    if ch == '.' || ch == 'e' || ch == 'E' {
      return false
    }
  }
  true
}

///|
fn parse_uint64_or_zero(s : String) -> UInt64 {
  @string.parse_uint64(s) catch {
    _ => 0UL
  }
}

///|
fn decode_number_as_double_body(
  wire : Int,
  input : InputStream,
) -> Result[(Double, InputStream), String] {
  match wire {
    0..=231 => Ok((wire.to_double(), input))
    232 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    233 =>
      match read_u32(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    234 =>
      match read_u64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    235 =>
      match input.read_int() {
        Ok((b, rest)) => Ok(((b - 256).to_double(), rest))
        Err(e) => Err(e)
      }
    236 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok(((v - 65536).to_double(), rest))
        Err(e) => Err(e)
      }
    237 =>
      match read_i32(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    238 =>
      match read_i64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    239 =>
      match read_i64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    240 =>
      match input.read_int() {
        Ok((b0, tail0)) =>
          match tail0.read_int() {
            Ok((b1, tail1)) =>
              match tail1.read_int() {
                Ok((b2, tail2)) =>
                  match tail2.read_int() {
                    Ok((b3, tail3)) => {
                      let bits = b0.reinterpret_as_uint() |
                        (b1.reinterpret_as_uint() << 8) |
                        (b2.reinterpret_as_uint() << 16) |
                        (b3.reinterpret_as_uint() << 24)
                      let f = Float::reinterpret_from_uint(bits)
                      Ok((f.to_double(), tail3))
                    }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    241 =>
      match read_i64(input) {
        Ok((bits, rest)) => Ok((bits.reinterpret_as_double(), rest))
        Err(e) => Err(e)
      }
    _ => Ok((0.0, input))
  }
}

///|
fn decode_number_as_double_with_tail(
  input : InputStream,
) -> Result[(Double, InputStream), String] {
  match input.read_int() {
    Ok((wire, rest)) => decode_number_as_double_body(wire, rest)
    Err(e) => Err(e)
  }
}

///|
pub fn int32_serializer() -> Serializer[Int] {
  new_serializer({
    is_default: fn(input : Int) { input == 0 },
    to_dense_json: fn(input : Int, builder : StringBuilder) {
      builder.write_string(input.to_string())
    },
    to_readable_json: fn(input : Int) { parse_json(input.to_string()) },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(n.to_int())
        Json::String(s) => Ok(parse_double_or_zero(s).to_int())
        _ => Ok(0)
      }
    },
    encode: fn(input : Int, out : OutputStream) {
      out.write_ints(encode_i32(input))
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number_with_tail(input) {
        Ok((v, tail)) => Ok((v.to_int(), tail))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Int32),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn int64_serializer() -> Serializer[Int64] {
  new_serializer({
    is_default: fn(input : Int64) { input == 0L },
    to_dense_json: fn(input : Int64, builder : StringBuilder) {
      if input >= -max_safe_int64_json && input <= max_safe_int64_json {
        builder.write_string(input.to_string())
      } else {
        builder.write_string("\"" + input.to_string() + "\"")
      }
    },
    to_readable_json: fn(input : Int64) {
      if input >= -max_safe_int64_json && input <= max_safe_int64_json {
        parse_json(input.to_string())
      } else {
        parse_json("\"" + input.to_string() + "\"")
      }
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => {
          let raw = json.stringify()
          if json_number_looks_integral(raw) {
            Ok(parse_int64_or_zero(raw))
          } else {
            Ok(n.round().to_int64())
          }
        }
        Json::String(s) => Ok(parse_int64_or_zero(s))
        _ => Ok(0L)
      }
    },
    encode: fn(input : Int64, out : OutputStream) {
      if input >= Int64::from_int(-2147483648) &&
        input <= Int64::from_int(2147483647) {
        out.write_ints(encode_i32(input.to_int()))
      } else {
        out.write_ints([238, ..encode_i64_le(input)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      decode_number_with_tail(input)
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Int64),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn hash64_serializer() -> Serializer[UInt64] {
  new_serializer({
    is_default: fn(input : UInt64) { input == 0UL },
    to_dense_json: fn(input : UInt64, builder : StringBuilder) {
      if input <= max_safe_hash64_json {
        builder.write_string(input.to_string())
      } else {
        builder.write_string("\"" + input.to_string() + "\"")
      }
    },
    to_readable_json: fn(input : UInt64) {
      if input <= max_safe_hash64_json {
        parse_json(input.to_string())
      } else {
        parse_json("\"" + input.to_string() + "\"")
      }
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) =>
          if n < 0.0 {
            Ok(0UL)
          } else {
            Ok(n.round().to_uint64())
          }
        Json::String(s) => Ok(parse_uint64_or_zero(s))
        _ => Ok(0UL)
      }
    },
    encode: fn(input : UInt64, out : OutputStream) {
      if input <= 231UL {
        out.write_ints([input.to_int()])
      } else if input <= 65535UL {
        out.write_ints([232, ..encode_u16_le(input.to_int())])
      } else if input <= 4294967295UL {
        out.write_ints([233, ..encode_u32_le(input.to_int())])
      } else {
        out.write_ints([234, ..encode_u64_le(input)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number_with_tail(input) {
        Ok((v, tail)) => Ok((v.reinterpret_as_uint64(), tail))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Hash64),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn float32_serializer() -> Serializer[Float] {
  new_serializer({
    is_default: fn(input : Float) { input == 0.0 },
    to_dense_json: fn(input : Float, builder : StringBuilder) {
      let code = input.to_string()
      if code == "Infinity" || code == "-Infinity" || code == "NaN" {
        builder.write_string("\"" + code + "\"")
      } else {
        builder.write_string(code)
      }
    },
    to_readable_json: fn(input : Float) {
      json_number_or_quoted_string(input.to_string())
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(Float::from_double(n))
        Json::String(s) => Ok(Float::from_double(parse_double_or_zero(s)))
        _ => Ok(Float::from_double(0.0))
      }
    },
    encode: fn(input : Float, out : OutputStream) {
      if input == 0.0 {
        out.write_int(0)
      } else {
        let bits = input.reinterpret_as_int()
        out.write_ints([
          240,
          bits & 0xFF,
          (bits >> 8) & 0xFF,
          (bits >> 16) & 0xFF,
          (bits >> 24) & 0xFF,
        ])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number_as_double_with_tail(input) {
        Ok((v, tail)) => Ok((Float::from_double(v), tail))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Float32),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn float64_serializer() -> Serializer[Double] {
  new_serializer({
    is_default: fn(input : Double) { input == 0.0 },
    to_dense_json: fn(input : Double, builder : StringBuilder) {
      let code = input.to_string()
      if code == "Infinity" || code == "-Infinity" || code == "NaN" {
        builder.write_string("\"" + code + "\"")
      } else {
        builder.write_string(code)
      }
    },
    to_readable_json: fn(input : Double) {
      json_number_or_quoted_string(input.to_string())
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(n)
        Json::String(s) => Ok(parse_double_or_zero(s))
        _ => Ok(0.0)
      }
    },
    encode: fn(input : Double, out : OutputStream) {
      if input == 0.0 {
        out.write_int(0)
      } else {
        out.write_ints([241, ..encode_i64_le(input.reinterpret_as_int64())])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      decode_number_as_double_with_tail(input)
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Float64),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
fn timestamp_json_to_millis(json : Json) -> Int64 {
  match json {
    Json::Number(n, ..) => n.round().to_int64()
    Json::String(s) => parse_double_or_zero(s).round().to_int64()
    Json::Object(obj) =>
      match obj.get("unix_millis") {
        Some(field) => timestamp_json_to_millis(field)
        None => 0L
      }
    _ => 0L
  }
}

///|
pub fn timestamp_serializer() -> Serializer[Timestamp] {
  new_serializer({
    is_default: fn(input : Timestamp) { input.unix_millis() == 0L },
    to_dense_json: fn(input : Timestamp, builder : StringBuilder) {
      let ts = Timestamp::from_unix_millis(input.unix_millis())
      let ms = ts.unix_millis()
      builder.write_string(ms.to_string())
    },
    to_readable_json: fn(input : Timestamp) {
      let ts = Timestamp::from_unix_millis(input.unix_millis())
      let ms = ts.unix_millis()
      parse_json(
        "{\n  \"unix_millis\": " +
        ms.to_string() +
        ",\n  \"formatted\": \"" +
        ts.to_iso8601() +
        "\"\n}",
      )
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      Ok(Timestamp::from_unix_millis(timestamp_json_to_millis(json)))
    },
    encode: fn(input : Timestamp, out : OutputStream) {
      let ms = Timestamp::from_unix_millis(input.unix_millis()).unix_millis()
      if ms == 0L {
        out.write_int(0)
      } else {
        out.write_ints([239, ..encode_i64_le(ms)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number_with_tail(input) {
        Ok((ms, tail)) => Ok((Timestamp::from_unix_millis(ms), tail))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Timestamp),
        records: @immut_vector.Vector::new(),
      }
    },
  })
}

///|
pub fn[T] optional_serializer(other : Serializer[T]) -> Serializer[T?] {
  let other = other.adapter
  new_serializer({
    is_default: fn(input : T?) {
      match input {
        None => true
        Some(_) => false
      }
    },
    to_dense_json: fn(input : T?, builder : StringBuilder) {
      match input {
        None => builder.write_string("null")
        Some(v) => (other.to_dense_json)(v, builder)
      }
    },
    to_readable_json: fn(input : T?) {
      match input {
        None => parse_json("null")
        Some(v) => (other.to_readable_json)(v)
      }
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      match json {
        Json::Null => Ok(None)
        _ =>
          match (other.from_json)(json, policy) {
            Ok(v) => Ok(Some(v))
            Err(e) => Err(e)
          }
      }
    },
    encode: fn(input : T?, out : OutputStream) {
      match input {
        None => out.write_int(255)
        Some(v) => (other.encode)(v, out)
      }
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      match input.peek_int() {
        Ok(255) =>
          match input.read_int() {
            Ok((_wire, rest)) => Ok((None, rest))
            Err(e) => Err(e)
          }
        Ok(_) =>
          match (other.decode)(input, policy) {
            Ok((v, tail)) => Ok((Some(v), tail))
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      let inner = (other.type_descriptor)()
      {
        root_type: TypeSignature::Optional(inner.root_type),
        records: inner.records,
      }
    },
  })
}

///|
pub fn[T] recursive_serializer(
  other : Serializer[T],
) -> Serializer[Recursive[T]] {
  let other = other.adapter
  new_serializer({
    is_default: fn(input : Recursive[T]) {
      match input {
        Recursive::Default => true
        Recursive::Some(v) => (other.is_default)(v)
      }
    },
    to_dense_json: fn(input : Recursive[T], builder : StringBuilder) {
      match input {
        Recursive::Default => builder.write_string("[]")
        Recursive::Some(v) => (other.to_dense_json)(v, builder)
      }
    },
    to_readable_json: fn(input : Recursive[T]) {
      match input {
        Recursive::Default => parse_json("{}")
        Recursive::Some(v) => (other.to_readable_json)(v)
      }
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      match json {
        Json::Array(arr) if arr.length() == 0 => Ok(Recursive::Default)
        Json::Object(obj) if obj.is_empty() => Ok(Recursive::Default)
        _ =>
          match (other.from_json)(json, policy) {
            Ok(v) => Ok(Recursive::Some(v))
            Err(e) => Err(e)
          }
      }
    },
    encode: fn(input : Recursive[T], out : OutputStream) {
      match input {
        Recursive::Default => out.write_int(246)
        Recursive::Some(v) => (other.encode)(v, out)
      }
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      match input.peek_int() {
        Ok(246) =>
          match input.read_int() {
            Ok((_wire, rest)) => Ok((Recursive::Default, rest))
            Err(e) => Err(e)
          }
        Ok(_) =>
          match (other.decode)(input, policy) {
            Ok((v, tail)) => Ok((Recursive::Some(v), tail))
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() { (other.type_descriptor)() },
  })
}

///|
fn[T] vector_serializer_impl(
  item_serializer : Serializer[T],
  key_extractor : String,
) -> Serializer[@immut_vector.Vector[T]] {
  let item_serializer = item_serializer.adapter
  new_serializer({
    is_default: fn(input : @immut_vector.Vector[T]) { input.is_empty() },
    to_dense_json: fn(
      input : @immut_vector.Vector[T],
      builder : StringBuilder,
    ) {
      builder.write_char('[')
      let mut i = 0
      for item in input.iter() {
        if i > 0 {
          builder.write_char(',')
        }
        (item_serializer.to_dense_json)(item, builder)
        i = i + 1
      }
      builder.write_char(']')
    },
    to_readable_json: fn(input : @immut_vector.Vector[T]) {
      let builder = StringBuilder()
      builder.write_char('[')
      let mut i = 0
      for item in input.iter() {
        if i > 0 {
          builder.write_char(',')
        }
        builder.write_string(
          (item_serializer.to_readable_json)(item).stringify(),
        )
        i = i + 1
      }
      builder.write_char(']')
      parse_json(builder.to_string())
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      match json {
        Json::Array(arr) => {
          let out : Array[T] = []
          for item in arr {
            match (item_serializer.from_json)(item, policy) {
              Ok(v) => out.push(v)
              Err(e) => return Err(e)
            }
          }
          Ok(@immut_vector.Vector::from_array(out))
        }
        _ => Ok(@immut_vector.Vector::new())
      }
    },
    encode: fn(input : @immut_vector.Vector[T], out : OutputStream) {
      let n = input.length()
      let mut cur = out
      if n <= 3 {
        cur = cur.write_int(246 + n)
      } else {
        cur = cur.write_ints([250, ..encode_i32(n)])
      }
      for item in input.iter() {
        cur = (item_serializer.encode)(item, cur)
      }
      cur
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      match input.read_int() {
        Ok((wire, rest)) => {
          if wire == 0 || wire == 246 {
            return Ok((@immut_vector.Vector::new(), rest))
          }
          let mut cur = rest
          let n = if wire == 250 {
            match decode_number_with_tail(cur) {
              Ok((n64, next)) => {
                cur = next
                n64.to_int()
              }
              Err(e) => return Err(e)
            }
          } else if wire >= 247 && wire <= 249 {
            wire - 246
          } else {
            return Err("expected array")
          }
          let out : Array[T] = []
          for _ in 0..<n {
            match (item_serializer.decode)(cur, policy) {
              Ok((item, next)) => {
                out.push(item)
                cur = next
              }
              Err(e) => return Err(e)
            }
          }
          Ok((@immut_vector.Vector::from_array(out), cur))
        }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      let item_td = (item_serializer.type_descriptor)()
      {
        root_type: TypeSignature::Array({
          item_type: item_td.root_type,
          key_extractor,
        }),
        records: item_td.records,
      }
    },
  })
}

///|
pub fn[T] vector_serializer(
  item_serializer : Serializer[T],
) -> Serializer[@immut_vector.Vector[T]] {
  vector_serializer_impl(item_serializer, "")
}

///|
pub fn[T] keyed_vector_serializer(
  item_serializer : Serializer[T],
  key_extractor : String,
) -> Serializer[@immut_vector.Vector[T]] {
  vector_serializer_impl(item_serializer, key_extractor)
}

///|
fn[T] immut_from_array(items : Array[T]) -> @immut_vector.Vector[T] {
  @immut_vector.Vector::from_array(items)
}

///|
fn expect_ok_bool(r : Result[Bool, String]) -> Bool {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_int(r : Result[Int, String]) -> Int {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_int64(r : Result[Int64, String]) -> Int64 {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_uint64(r : Result[UInt64, String]) -> UInt64 {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_float(r : Result[Float, String]) -> Float {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_double(r : Result[Double, String]) -> Double {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_timestamp(r : Result[Timestamp, String]) -> Timestamp {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_optional_int(r : Result[Int?, String]) -> Int? {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn expect_ok_recursive_int(
  r : Result[Recursive[Int], String],
) -> Recursive[Int] {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn assert_recursive_int_eq(lhs : Recursive[Int], rhs : Recursive[Int]) -> Unit {
  match lhs {
    Recursive::Default =>
      match rhs {
        Recursive::Default => ()
        _ => panic()
      }
    Recursive::Some(a) =>
      match rhs {
        Recursive::Some(b) => assert_eq(a, b)
        _ => panic()
      }
  }
}

///|
fn expect_ok_immut_int_array(
  r : Result[@immut_vector.Vector[Int], String],
) -> @immut_vector.Vector[Int] {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

///|
fn[T : Eq] assert_eq(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

///|
test "to_json_dense_true" {
  assert_eq(bool_serializer().to_dense_json_code(true), "1")
}

///|
test "to_json_dense_false" {
  assert_eq(bool_serializer().to_dense_json_code(false), "0")
}

///|
test "to_json_readable_true" {
  assert_eq(bool_serializer().to_readable_json(true), parse_json("true"))
}

///|
test "to_json_readable_false" {
  assert_eq(bool_serializer().to_readable_json(false), parse_json("false"))
}

///|
test "from_json_bool_literal" {
  let s = bool_serializer()
  assert_eq(expect_ok_bool(s.from_json(parse_json("true"))), true)
  assert_eq(expect_ok_bool(s.from_json(parse_json("false"))), false)
}

///|
test "from_json_number_1_and_0" {
  let s = bool_serializer()
  assert_eq(expect_ok_bool(s.from_json(parse_json("1"))), true)
  assert_eq(expect_ok_bool(s.from_json(parse_json("0"))), false)
  assert_eq(
    expect_ok_bool(
      s.from_json(parse_json("1"), unrecognized_values=UnrecognizedValues::Keep),
    ),
    true,
  )
}

///|
test "from_json_number_nonzero" {
  assert_eq(expect_ok_bool(bool_serializer().from_json(parse_json("42"))), true)
}

///|
test "from_json_float_zero" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json(parse_json("0.0"))),
    false,
  )
}

///|
test "from_json_string_zero_is_false" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json(parse_json("\"0\""))),
    false,
  )
}

///|
test "from_json_string_nonzero_is_true" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json(parse_json("\"1\""))),
    true,
  )
  assert_eq(
    expect_ok_bool(bool_serializer().from_json(parse_json("\"true\""))),
    true,
  )
}

///|
test "from_json_null_is_false" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json(parse_json("null"))),
    false,
  )
}

///|
test "binary_round_trip_true" {
  let s = bool_serializer()
  let bytes = s.to_bytes(true)
  assert_eq(expect_ok_bool(s.from_bytes(bytes)), true)
}

///|
test "binary_round_trip_false" {
  let s = bool_serializer()
  let bytes = s.to_bytes(false)
  assert_eq(expect_ok_bool(s.from_bytes(bytes)), false)
}

///|
test "binary_encoding_true_is_skir_then_1" {
  assert_eq(bool_serializer().to_bytes(true), [115, 107, 105, 114, 1])
}

///|
test "binary_encoding_false_is_skir_then_0" {
  assert_eq(bool_serializer().to_bytes(false), [115, 107, 105, 114, 0])
}

///|
test "type_descriptor_is_bool" {
  let td = bool_serializer().type_descriptor()
  assert_eq(td.as_json(), {
    "type": { "kind": "primitive", "value": "bool" },
    "records": [],
  })
}

///|
test "int32_to_json_positive" {
  assert_eq(int32_serializer().to_dense_json_code(42), "42")
}

///|
test "int32_from_json_float_truncates" {
  assert_eq(expect_ok_int(int32_serializer().from_json(parse_json("3.9"))), 3)
  assert_eq(expect_ok_int(int32_serializer().from_json(parse_json("-1.5"))), -1)
}

///|
test "int32_binary_round_trip" {
  let s = int32_serializer()
  for
    v in [
      0, 1, 42, 231, 232, 300, 65535, 65536, -1, -255, -256, -65536, -100000,
    ] {
    assert_eq(expect_ok_int(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "int64_to_json_large_value_is_quoted" {
  assert_eq(
    int64_serializer().to_dense_json_code(9007199254740992L),
    "\"9007199254740992\"",
  )
}

///|
test "int64_from_json_quoted_large" {
  assert_eq(
    expect_ok_int64(
      int64_serializer().from_json(parse_json("\"9007199254740992\"")),
    ),
    9007199254740992L,
  )
}

///|
test "int64_binary_round_trip" {
  let s = int64_serializer()
  for
    v in [
      0L, 1L, 231L, 232L, 65536L, 2147483647L, 2147483648L, -1L, -2147483648L, -2147483649L,
    ] {
    assert_eq(expect_ok_int64(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "hash64_to_json_large_value_is_quoted" {
  assert_eq(
    hash64_serializer().to_dense_json_code(9007199254740992UL),
    "\"9007199254740992\"",
  )
}

///|
test "hash64_from_json_negative_number_is_zero" {
  assert_eq(
    expect_ok_uint64(hash64_serializer().from_json(parse_json("-1.0"))),
    0UL,
  )
}

///|
test "hash64_binary_round_trip" {
  let s = hash64_serializer()
  for
    v in [0UL, 1UL, 231UL, 232UL, 65535UL, 65536UL, 4294967295UL, 4294967296UL] {
    assert_eq(expect_ok_uint64(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "float32_to_json" {
  assert_eq(
    float32_serializer().to_dense_json_code(Float::from_double(1.5)),
    "1.5",
  )
}

///|
test "float32_from_json_string" {
  assert_eq(
    expect_ok_float(float32_serializer().from_json(parse_json("\"3.25\""))),
    Float::from_double(3.25),
  )
}

///|
test "float32_binary_round_trip" {
  let s = float32_serializer()
  for
    v in [
      Float::from_double(0.0),
      Float::from_double(1.5),
      Float::from_double(-2.25),
    ] {
    assert_eq(expect_ok_float(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "float32_binary_encoding_1_5" {
  assert_eq(float32_serializer().to_bytes(Float::from_double(1.5)), [
    115, 107, 105, 114, 240, 0, 0, 192, 63,
  ])
}

///|
test "float64_to_json" {
  assert_eq(float64_serializer().to_dense_json_code(1.5), "1.5")
}

///|
test "float64_from_json_string" {
  assert_eq(
    expect_ok_double(float64_serializer().from_json(parse_json("\"3.25\""))),
    3.25,
  )
}

///|
test "float64_binary_round_trip" {
  let s = float64_serializer()
  for v in [0.0, 1.5, -2.25, 123456789.125] {
    assert_eq(expect_ok_double(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "float64_binary_encoding_1_5" {
  assert_eq(float64_serializer().to_bytes(1.5), [
    115, 107, 105, 114, 241, 0, 0, 0, 0, 0, 0, 248, 63,
  ])
}

///|
test "timestamp_to_json_dense_epoch" {
  let epoch = Timestamp::from_unix_millis(0L)
  assert_eq(timestamp_serializer().to_dense_json_code(epoch), "0")
}

///|
test "timestamp_to_json_readable" {
  let ts = Timestamp::from_unix_millis(1234567890000L)
  assert_eq(
    timestamp_serializer().to_readable_json(ts),
    parse_json(
      "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30.000Z\"\n}",
    ),
  )
}

///|
test "timestamp_from_json_object_readable" {
  let json = parse_json(
    "{\"unix_millis\":1234567890000,\"formatted\":\"ignored\"}",
  )
  let parsed = expect_ok_timestamp(timestamp_serializer().from_json(json))
  assert_eq(parsed.unix_millis(), 1234567890000L)
}

///|
test "timestamp_binary_round_trip" {
  let s = timestamp_serializer()
  for ms in [0L, 1L, 1234567890000L, -1000L] {
    let ts = Timestamp::from_unix_millis(ms)
    let decoded = expect_ok_timestamp(s.from_bytes(s.to_bytes(ts))).unix_millis()
    assert_eq(decoded, Timestamp::from_unix_millis(ms).unix_millis())
  }
}

///|
test "timestamp_comparison_operators" {
  let a = Timestamp::from_unix_millis(1000L)
  let b = Timestamp::from_unix_millis(2000L)
  let c = Timestamp::from_unix_millis(1000L)

  assert_eq(a == c, true)
  assert_eq(a < b, true)
  assert_eq(a <= c, true)
  assert_eq(b > a, true)
  assert_eq(b >= c, true)
}

///|
test "array_to_json_dense_nonempty" {
  let s = vector_serializer(int32_serializer())
  assert_eq(s.to_dense_json_code(immut_from_array([1, 2, 3])), "[1,2,3]")
}

///|
test "array_from_json_null_is_empty" {
  let s = vector_serializer(int32_serializer())
  assert_eq(
    expect_ok_immut_int_array(s.from_json(parse_json("null"))),
    @immut_vector.Vector::new(),
  )
}

///|
test "array_encode_empty_is_wire_246" {
  let s = vector_serializer(int32_serializer())
  assert_eq(s.to_bytes(@immut_vector.Vector::new()), [115, 107, 105, 114, 246])
}

///|
test "array_binary_round_trip" {
  let s = vector_serializer(int32_serializer())
  for
    v in [
      @immut_vector.Vector::new(),
      immut_from_array([0]),
      immut_from_array([1, 2, 3]),
      immut_from_array([-1, 0, 1]),
    ] {
    assert_eq(expect_ok_immut_int_array(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "optional_to_json_none_is_null" {
  assert_eq(
    optional_serializer(int32_serializer()).to_dense_json_code(None),
    "null",
  )
}

///|
test "optional_to_json_some_delegates" {
  assert_eq(
    optional_serializer(int32_serializer()).to_dense_json_code(Some(42)),
    "42",
  )
}

///|
test "optional_from_json_value_is_some" {
  assert_eq(
    expect_ok_optional_int(
      optional_serializer(int32_serializer()).from_json(parse_json("7")),
    ),
    Some(7),
  )
}

///|
test "optional_encode_none_is_wire_255" {
  assert_eq(optional_serializer(int32_serializer()).to_bytes(None), [
    115, 107, 105, 114, 255,
  ])
}

///|
test "optional_binary_round_trip" {
  let s = optional_serializer(int32_serializer())
  for v in [None, Some(0), Some(42), Some(-1)] {
    assert_eq(expect_ok_optional_int(s.from_bytes(s.to_bytes(v))), v)
  }
}

///|
test "recursive_to_json_dense_default_is_empty_array" {
  assert_eq(
    recursive_serializer(int32_serializer()).to_dense_json_code(
      Recursive::Default,
    ),
    "[]",
  )
}

///|
test "recursive_to_json_readable_default_is_empty_object" {
  assert_eq(
    recursive_serializer(int32_serializer()).to_readable_json(
      Recursive::Default,
    ),
    parse_json("{}"),
  )
}

///|
test "recursive_from_json_empty_array_is_default" {
  assert_recursive_int_eq(
    expect_ok_recursive_int(
      recursive_serializer(int32_serializer()).from_json(parse_json("[]")),
    ),
    Recursive::Default,
  )
}

///|
test "recursive_from_json_empty_object_is_default" {
  assert_recursive_int_eq(
    expect_ok_recursive_int(
      recursive_serializer(int32_serializer()).from_json(parse_json("{}")),
    ),
    Recursive::Default,
  )
}

///|
test "recursive_encode_default_is_wire_246" {
  assert_eq(
    recursive_serializer(int32_serializer()).to_bytes(Recursive::Default),
    [115, 107, 105, 114, 246],
  )
}

///|
test "recursive_binary_round_trip" {
  let s = recursive_serializer(int32_serializer())
  for
    v in [
      Recursive::Default,
      Recursive::Some(0),
      Recursive::Some(42),
      Recursive::Some(-1),
    ] {
    assert_recursive_int_eq(
      expect_ok_recursive_int(s.from_bytes(s.to_bytes(v))),
      v,
    )
  }
}
