package skir_client

import (
	"bytes"
	"encoding/binary"
	"math"
	"strings"
	"unicode/utf8"
)

// ─────────────────────────────────────────────────────────────────────────────
// binaryOutput – write side
// ─────────────────────────────────────────────────────────────────────────────

// binaryOutput is the write-side of the skir binary wire format.
//
// buf2/buf4/buf8 are scratch arrays kept on the struct to stage multi-byte
// integer writes before calling bytes.Buffer.Write. This avoids any heap
// allocation even in edge cases where the Go compiler's escape analysis might
// not prove that a local [N]byte doesn't escape.
type binaryOutput struct {
	out  bytes.Buffer
	buf2 [2]byte
	buf4 [4]byte
	buf8 [8]byte
}

// writeUint8 writes a single unsigned byte.
func (o *binaryOutput) writeUint8(v uint8) {
	o.out.WriteByte(v)
}

// writeUint16 writes a 16-bit unsigned integer in little-endian order.
func (o *binaryOutput) writeUint16(v uint16) {
	binary.LittleEndian.PutUint16(o.buf2[:], v)
	o.out.Write(o.buf2[:])
}

// writeUint32 writes a 32-bit unsigned integer in little-endian order.
func (o *binaryOutput) writeUint32(v uint32) {
	binary.LittleEndian.PutUint32(o.buf4[:], v)
	o.out.Write(o.buf4[:])
}

// writeInt32 writes a 32-bit signed integer in little-endian order.
func (o *binaryOutput) writeInt32(v int32) {
	binary.LittleEndian.PutUint32(o.buf4[:], uint32(v))
	o.out.Write(o.buf4[:])
}

// writeHash64 writes a 64-bit unsigned integer (hash64) in little-endian order.
func (o *binaryOutput) writeHash64(v uint64) {
	binary.LittleEndian.PutUint64(o.buf8[:], v)
	o.out.Write(o.buf8[:])
}

// writeInt64 writes a 64-bit signed integer in little-endian order.
func (o *binaryOutput) writeInt64(v int64) {
	binary.LittleEndian.PutUint64(o.buf8[:], uint64(v))
	o.out.Write(o.buf8[:])
}

// writeFloat32 writes a 32-bit IEEE 754 float in little-endian order.
func (o *binaryOutput) writeFloat32(v float32) {
	binary.LittleEndian.PutUint32(o.buf4[:], math.Float32bits(v))
	o.out.Write(o.buf4[:])
}

// writeFloat64 writes a 64-bit IEEE 754 float in little-endian order.
func (o *binaryOutput) writeFloat64(v float64) {
	binary.LittleEndian.PutUint64(o.buf8[:], math.Float64bits(v))
	o.out.Write(o.buf8[:])
}

// putUtf8String writes s as UTF-8 bytes and returns the number of bytes written.
// If s contains invalid UTF-8 sequences, each invalid byte is replaced with
// the Unicode replacement character (U+FFFD) on a best-effort basis.
func (o *binaryOutput) putUtf8String(s string) int {
	if utf8.ValidString(s) {
		n, _ := o.out.WriteString(s)
		return n
	}
	safe := strings.ToValidUTF8(s, string(utf8.RuneError))
	n, _ := o.out.WriteString(safe)
	return n
}

// putBytes writes the raw bytes of b.
func (o *binaryOutput) putBytes(b Bytes) {
	// Bytes.v is a string used as an immutable byte buffer (same package).
	o.out.WriteString(b.v)
}

// ─────────────────────────────────────────────────────────────────────────────
// binaryInput – read side
// ─────────────────────────────────────────────────────────────────────────────

// binaryInput is the read-side of the skir binary wire format.
// It wraps a []byte and advances an offset on each read, mirroring the write
// methods of binaryOutput.
type binaryInput struct {
	data                   []byte
	offset                 int
	keepUnrecognizedValues bool
	overflowed             bool
}

// newBinaryInput constructs a binaryInput that reads from data.
func newBinaryInput(data []byte, keepUnrecognizedValues bool) binaryInput {
	return binaryInput{data: data, keepUnrecognizedValues: keepUnrecognizedValues}
}

// peekUint8 returns the next byte without advancing the offset.
// Returns 0 and sets overflowed if the buffer is exhausted.
func (in *binaryInput) peekUint8() uint8 {
	if in.offset+1 > len(in.data) {
		in.overflowed = true
		return 0
	}
	return in.data[in.offset]
}

// readUint8 reads and returns a single unsigned byte.
func (in *binaryInput) readUint8() uint8 {
	if in.offset+1 > len(in.data) {
		in.overflowed = true
		return 0
	}
	v := in.data[in.offset]
	in.offset++
	return v
}

// readUint16 reads a 16-bit unsigned integer in little-endian order.
func (in *binaryInput) readUint16() uint16 {
	if in.offset+2 > len(in.data) {
		in.overflowed = true
		return 0
	}
	v := binary.LittleEndian.Uint16(in.data[in.offset:])
	in.offset += 2
	return v
}

// readUint32 reads a 32-bit unsigned integer in little-endian order.
func (in *binaryInput) readUint32() uint32 {
	if in.offset+4 > len(in.data) {
		in.overflowed = true
		return 0
	}
	v := binary.LittleEndian.Uint32(in.data[in.offset:])
	in.offset += 4
	return v
}

// readInt32 reads a 32-bit signed integer in little-endian order.
func (in *binaryInput) readInt32() int32 {
	return int32(in.readUint32())
}

// readHash64 reads a 64-bit unsigned integer (hash64) in little-endian order.
func (in *binaryInput) readHash64() uint64 {
	if in.offset+8 > len(in.data) {
		in.overflowed = true
		return 0
	}
	v := binary.LittleEndian.Uint64(in.data[in.offset:])
	in.offset += 8
	return v
}

// readInt64 reads a 64-bit signed integer in little-endian order.
func (in *binaryInput) readInt64() int64 {
	return int64(in.readHash64())
}

// readFloat32 reads a 32-bit IEEE 754 float in little-endian order.
func (in *binaryInput) readFloat32() float32 {
	return math.Float32frombits(in.readUint32())
}

// readFloat64 reads a 64-bit IEEE 754 float in little-endian order.
func (in *binaryInput) readFloat64() float64 {
	return math.Float64frombits(in.readHash64())
}

// readBytes reads n raw bytes and returns them as a []byte slice backed by the
// input buffer (no copy).
func (in *binaryInput) readBytes(n int) []byte {
	if in.offset+n > len(in.data) {
		in.overflowed = true
		return nil
	}
	b := in.data[in.offset : in.offset+n]
	in.offset += n
	return b
}

// readString reads n bytes and returns them as a string (no copy).
func (in *binaryInput) readString(n int) string {
	if in.offset+n > len(in.data) {
		in.overflowed = true
		return ""
	}
	s := string(in.data[in.offset : in.offset+n])
	in.offset += n
	return s
}

// sliceBytes reads n bytes and wraps them in a Bytes value (no copy of the
// underlying array).
func (in *binaryInput) sliceBytes(n int) Bytes {
	return BytesFromSlice(in.readBytes(n))
}
