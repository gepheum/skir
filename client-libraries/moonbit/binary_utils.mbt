///|
priv struct OutputStream {
  bytes : Array[Byte]
  offset : Int
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
fn OutputStream::write_int(self : OutputStream, b : Int) -> OutputStream {
  self.write_byte(b.to_byte())
}

///|
fn OutputStream::write_ints(
  self : OutputStream,
  bytes : Array[Int],
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
fn OutputStream::to_int_array(self : OutputStream) -> Array[Int] {
  let bytes : Array[Int] = []
  for b in self.bytes {
    bytes.push(b.to_int())
  }
  bytes
}

///|
priv struct InputStream {
  bytes : Array[Byte]
  offset : Int
}

///|
fn InputStream::from_int_array(bytes : Array[Int]) -> InputStream {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  { bytes: out, offset: 0, }
}

///|
fn InputStream::read_int(
  self : InputStream,
) -> Result[(Int, InputStream), String] {
  match self.bytes.get(self.offset) {
    Some(b) => Ok((b.to_int(), { bytes: self.bytes, offset: self.offset + 1, }))
    None => Err("unexpected end of input")
  }
}

///|
fn InputStream::peek_int(self : InputStream) -> Result[Int, String] {
  match self.bytes.get(self.offset) {
    Some(b) => Ok(b.to_int())
    None => Err("unexpected end of input")
  }
}

///|
fn InputStream::remaining_int_array(self : InputStream) -> Array[Int] {
  let out : Array[Int] = []
  for i in self.offset..<self.bytes.length() {
    out.push(self.bytes[i].to_int())
  }
  out
}
