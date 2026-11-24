package skir_client

import (
	"encoding/hex"
	"fmt"
)

// Bytes is an immutable sequence of bytes.
//
// Unlike []byte, a Bytes value cannot be modified after creation.
type Bytes struct {
	// A Go string is used internally because it provides value semantics and
	// immutability for free, without exposing string's UTF-8 connotation to
	// callers.
	v string
}

// BytesFromSlice returns a Bytes whose content is a copy of b.
func BytesFromSlice(b []byte) Bytes {
	return Bytes{v: string(b)}
}

// BytesFromHex decodes a hex string and returns the corresponding Bytes.
// It returns an error if s is not a valid hex string.
func BytesFromHex(s string) (Bytes, error) {
	b, err := hex.DecodeString(s)
	if err != nil {
		return Bytes{}, fmt.Errorf("skir_client.BytesFromHex: %w", err)
	}
	return Bytes{v: string(b)}, nil
}

// Len returns the number of bytes.
func (b Bytes) Len() int {
	return len(b.v)
}

// IsEmpty reports whether the sequence contains no bytes.
func (b Bytes) IsEmpty() bool {
	return len(b.v) == 0
}

// Slice returns a copy of the bytes as a []byte.
func (b Bytes) Slice() []byte {
	return []byte(b.v)
}

// Equal reports whether b and other contain the same byte sequence.
func (b Bytes) Equal(other Bytes) bool {
	return b.v == other.v
}

// Hex returns the bytes encoded as a lowercase hexadecimal string.
func (b Bytes) Hex() string {
	return hex.EncodeToString([]byte(b.v))
}

// String returns the bytes encoded as a lowercase hexadecimal string.
func (b Bytes) String() string {
	return "hex:" + b.Hex()
}
