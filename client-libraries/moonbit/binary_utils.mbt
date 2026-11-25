///|
priv struct OutputStream {
  bytes : Array[Byte]
  offset : Int32
}

///|
fn OutputStream::new() -> OutputStream {
  { bytes: [], offset: 0, }
}

///|
fn OutputStream::write_byte(self : OutputStream, b : Byte) -> OutputStream {
  self.bytes.push(b)
  { bytes: self.bytes, offset: self.offset + 1, }
}

///|
fn OutputStream::write_int(self : OutputStream, b : Int32) -> OutputStream {
  self.write_byte(b.to_byte())
}

///|
fn OutputStream::write_ints(
  self : OutputStream,
  bytes : Array[Int32],
) -> OutputStream {
  let mut cur = self
  for b in bytes {
    cur = cur.write_int(b)
  }
  cur
}

///|
fn OutputStream::write_bytes(
  self : OutputStream,
  bytes : Bytes,
) -> OutputStream {
  let mut cur = self
  for byte in bytes.to_array() {
    cur = cur.write_byte(byte)
  }
  cur
}

///|
fn OutputStream::to_int_array(self : OutputStream) -> Array[Int32] {
  let bytes : Array[Int32] = []
  for b in self.bytes {
    bytes.push(b.to_int())
  }
  bytes
}

///|
priv struct InputStream {
  bytes : Array[Byte]
  offset : Int32
}

///|
fn InputStream::from_int_array(bytes : Array[Int32]) -> InputStream {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  { bytes: out, offset: 0, }
}

///|
fn InputStream::read_int(
  self : InputStream,
) -> Result[(Int32, InputStream), String] {
  match self.bytes.get(self.offset) {
    Some(b) => Ok((b.to_int(), { bytes: self.bytes, offset: self.offset + 1, }))
    None => Err("unexpected end of input")
  }
}

///|
fn InputStream::peek_int(self : InputStream) -> Result[Int32, String] {
  match self.bytes.get(self.offset) {
    Some(b) => Ok(b.to_int())
    None => Err("unexpected end of input")
  }
}

///|
fn InputStream::remaining_int_array(self : InputStream) -> Array[Int32] {
  let out : Array[Int32] = []
  for i in self.offset..<self.bytes.length() {
    out.push(self.bytes[i].to_int())
  }
  out
}
