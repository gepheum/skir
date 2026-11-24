package skir_client

import (
	"testing"
)

// ─────────────────────────────────────────────────────────────────────────────
// BytesFromSlice
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesFromSlice_nil(t *testing.T) {
	b := BytesFromSlice(nil)
	if !b.IsEmpty() {
		t.Error("expected IsEmpty true for nil input")
	}
	if b.Len() != 0 {
		t.Errorf("expected Len 0, got %d", b.Len())
	}
}

func TestBytesFromSlice_empty(t *testing.T) {
	b := BytesFromSlice([]byte{})
	if !b.IsEmpty() {
		t.Error("expected IsEmpty true for empty input")
	}
}

func TestBytesFromSlice_copiesSlice(t *testing.T) {
	s := []byte{1, 2, 3}
	b := BytesFromSlice(s)
	s[0] = 99
	if b.Slice()[0] != 1 {
		t.Fatal("BytesFromSlice did not copy: mutation of source affected Bytes")
	}
}

func TestBytesFromSlice_roundTrip(t *testing.T) {
	input := []byte{0x00, 0x01, 0xFF, 0xAB}
	b := BytesFromSlice(input)
	got := b.Slice()
	if len(got) != len(input) {
		t.Fatalf("Slice len = %d, want %d", len(got), len(input))
	}
	for i := range input {
		if got[i] != input[i] {
			t.Errorf("Slice[%d] = %#x, want %#x", i, got[i], input[i])
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesFromHex
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesFromHex_valid(t *testing.T) {
	b, err := BytesFromHex("deadbeef")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if b.Len() != 4 {
		t.Fatalf("Len = %d, want 4", b.Len())
	}
	got := b.Slice()
	want := []byte{0xde, 0xad, 0xbe, 0xef}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("byte[%d] = %#x, want %#x", i, got[i], want[i])
		}
	}
}

func TestBytesFromHex_upperCase(t *testing.T) {
	b, err := BytesFromHex("DEADBEEF")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if b.Len() != 4 {
		t.Fatalf("Len = %d, want 4", b.Len())
	}
}

func TestBytesFromHex_empty(t *testing.T) {
	b, err := BytesFromHex("")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !b.IsEmpty() {
		t.Error("expected IsEmpty true for empty hex string")
	}
}

func TestBytesFromHex_invalid(t *testing.T) {
	_, err := BytesFromHex("not-hex!")
	if err == nil {
		t.Error("expected error for invalid hex, got nil")
	}
}

func TestBytesFromHex_oddLength(t *testing.T) {
	_, err := BytesFromHex("abc")
	if err == nil {
		t.Error("expected error for odd-length hex string, got nil")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Len / IsEmpty
// ─────────────────────────────────────────────────────────────────────────────

func TestBytes_Len(t *testing.T) {
	cases := []struct {
		input []byte
		want  int
	}{
		{nil, 0},
		{[]byte{}, 0},
		{[]byte{0x00}, 1},
		{[]byte{1, 2, 3}, 3},
	}
	for _, tc := range cases {
		b := BytesFromSlice(tc.input)
		if got := b.Len(); got != tc.want {
			t.Errorf("Len(%v) = %d, want %d", tc.input, got, tc.want)
		}
	}
}

func TestBytes_IsEmpty(t *testing.T) {
	if !BytesFromSlice(nil).IsEmpty() {
		t.Error("nil: expected IsEmpty true")
	}
	if !BytesFromSlice([]byte{}).IsEmpty() {
		t.Error("empty: expected IsEmpty true")
	}
	if BytesFromSlice([]byte{0}).IsEmpty() {
		t.Error("single zero byte: expected IsEmpty false")
	}
}

func TestBytes_ZeroValue(t *testing.T) {
	var b Bytes
	if !b.IsEmpty() {
		t.Error("zero-value Bytes should be empty")
	}
	if b.Len() != 0 {
		t.Errorf("zero-value Bytes Len should be 0, got %d", b.Len())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Slice
// ─────────────────────────────────────────────────────────────────────────────

func TestBytes_Slice_returnsCopy(t *testing.T) {
	b := BytesFromSlice([]byte{1, 2, 3})
	s := b.Slice()
	s[0] = 99
	// The Bytes value must be unaffected.
	if b.Slice()[0] != 1 {
		t.Fatal("Slice returned a reference to internal storage, not a copy")
	}
}

func TestBytes_Slice_empty(t *testing.T) {
	b := BytesFromSlice(nil)
	s := b.Slice()
	if len(s) != 0 {
		t.Errorf("Slice on empty Bytes: want len 0, got %d", len(s))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Equal
// ─────────────────────────────────────────────────────────────────────────────

func TestBytes_Equal_sameContent(t *testing.T) {
	a := BytesFromSlice([]byte{1, 2, 3})
	b := BytesFromSlice([]byte{1, 2, 3})
	if !a.Equal(b) {
		t.Error("Equal: expected true for same content")
	}
}

func TestBytes_Equal_differentContent(t *testing.T) {
	a := BytesFromSlice([]byte{1, 2, 3})
	b := BytesFromSlice([]byte{1, 2, 4})
	if a.Equal(b) {
		t.Error("Equal: expected false for different content")
	}
}

func TestBytes_Equal_differentLength(t *testing.T) {
	a := BytesFromSlice([]byte{1, 2})
	b := BytesFromSlice([]byte{1, 2, 3})
	if a.Equal(b) {
		t.Error("Equal: expected false for different lengths")
	}
}

func TestBytes_Equal_bothEmpty(t *testing.T) {
	a := BytesFromSlice(nil)
	b := BytesFromSlice([]byte{})
	if !a.Equal(b) {
		t.Error("Equal: expected true for two empty Bytes")
	}
}

func TestBytes_Equal_zeroValues(t *testing.T) {
	var a, b Bytes
	if !a.Equal(b) {
		t.Error("Equal: expected true for two zero-value Bytes")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Hex
// ─────────────────────────────────────────────────────────────────────────────

func TestBytes_Hex(t *testing.T) {
	cases := []struct {
		input []byte
		want  string
	}{
		{nil, ""},
		{[]byte{}, ""},
		{[]byte{0xde, 0xad, 0xbe, 0xef}, "deadbeef"},
		{[]byte{0x00}, "00"},
		{[]byte{0xFF}, "ff"},
	}
	for _, tc := range cases {
		b := BytesFromSlice(tc.input)
		if got := b.Hex(); got != tc.want {
			t.Errorf("Hex(%v) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestBytes_Hex_roundTrip(t *testing.T) {
	orig := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef}
	b := BytesFromSlice(orig)
	hex := b.Hex()
	b2, err := BytesFromHex(hex)
	if err != nil {
		t.Fatalf("BytesFromHex(%q): %v", hex, err)
	}
	if !b.Equal(b2) {
		t.Error("Hex round-trip did not preserve bytes")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// String
// ─────────────────────────────────────────────────────────────────────────────

func TestBytes_String(t *testing.T) {
	b := BytesFromSlice([]byte{0xca, 0xfe})
	got := b.String()
	want := "hex:cafe"
	if got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}
}

func TestBytes_String_empty(t *testing.T) {
	b := BytesFromSlice(nil)
	if got, want := b.String(), "hex:"; got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}
}
