pub fn decode_number(bits: BitArray) -> Result(#(Int, BitArray), String) {
  case bits {
    <<w, rest:bits>> ->
      case w {
        _ if w <= 231 -> Ok(#(w, rest))
        232 ->
          case rest {
            <<v:size(16)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        233 ->
          case rest {
            <<v:size(32)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        234 ->
          case rest {
            <<v:size(64)-little, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        235 ->
          case rest {
            <<b, r:bits>> -> Ok(#(b - 256, r))
            _ -> Error("unexpected end of input")
          }
        236 ->
          case rest {
            <<v:size(16)-little, r:bits>> -> Ok(#(v - 65_536, r))
            _ -> Error("unexpected end of input")
          }
        237 ->
          case rest {
            <<v:size(32)-little-signed, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        238 | 239 ->
          case rest {
            <<v:size(64)-little-signed, r:bits>> -> Ok(#(v, r))
            _ -> Error("unexpected end of input")
          }
        _ -> Ok(#(0, rest))
      }
    _ -> Error("unexpected end of input")
  }
}

pub fn skip_value(bits: BitArray) -> Result(BitArray, String) {
  case bits {
    <<w, rest:bits>> ->
      case w {
        _ if w <= 231 -> Ok(rest)
        232 | 236 ->
          case rest {
            <<_:size(16), r:bits>> -> Ok(r)
            _ -> Error("unexpected end of input in skip_value")
          }
        233 | 237 | 240 ->
          case rest {
            <<_:size(32), r:bits>> -> Ok(r)
            _ -> Error("unexpected end of input in skip_value")
          }
        234 | 238 | 239 | 241 ->
          case rest {
            <<_:size(64), r:bits>> -> Ok(r)
            _ -> Error("unexpected end of input in skip_value")
          }
        235 ->
          case rest {
            <<_, r:bits>> -> Ok(r)
            _ -> Error("unexpected end of input in skip_value")
          }
        242 | 244 | 246 -> Ok(rest)
        243 | 245 ->
          case decode_number(rest) {
            Error(e) -> Error(e)
            Ok(#(n, after_len)) ->
              case after_len {
                <<_:bytes-size(n), r:bits>> -> Ok(r)
                _ -> Error("unexpected end of input in skip_value")
              }
          }
        247 | 248 | 249 -> skip_n_values(w - 246, rest)
        250 ->
          case decode_number(rest) {
            Error(e) -> Error(e)
            Ok(#(n, after_n)) -> skip_n_values(n, after_n)
          }
        // Enum wrapper variants (251-254): skip the following payload value
        251 | 252 | 253 | 254 -> skip_value(rest)
        255 -> Ok(rest)
        _ -> Ok(rest)
      }
    _ -> Error("unexpected end of input in skip_value")
  }
}

pub fn skip_n_values(n: Int, bits: BitArray) -> Result(BitArray, String) {
  case n {
    0 -> Ok(bits)
    _ ->
      case skip_value(bits) {
        Error(e) -> Error(e)
        Ok(rest) -> skip_n_values(n - 1, rest)
      }
  }
}

// Encodes an unsigned integer using the skir variable-length wire format.
// 0..=231:        single byte (the value itself)
// 232..=65535:    wire 232, then value as u16 LE
// >= 65536:       wire 233, then value as u32 LE
pub fn encode_uint32(n: Int) -> BitArray {
  case n {
    _ if n <= 231 -> <<n>>
    _ if n <= 65_535 -> <<232, n:size(16)-little>>
    _ -> <<233, n:size(32)-little>>
  }
}
