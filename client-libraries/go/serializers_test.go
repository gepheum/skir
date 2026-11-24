package skir_client

import (
	"math"
	"testing"
	"time"
)

// helpers shared by serializer tests
func mustFromJson[T any](t *testing.T, s Serializer[T], code string) T {
	t.Helper()
	v, err := s.FromJson(code)
	if err != nil {
		t.Fatalf("FromJson(%q): %v", code, err)
	}
	return v
}

func mustFromBytes[T any](t *testing.T, s Serializer[T], b []byte) T {
	t.Helper()
	v, err := s.FromBytes(b)
	if err != nil {
		t.Fatalf("FromBytes: %v", err)
	}
	return v
}

// ─────────────────────────────────────────────────────────────────────────────
// BoolSerializer – ToJson / FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestBoolSerializer_ToJson(t *testing.T) {
	s := BoolSerializer()
	if got := s.ToJson(true); got != "1" {
		t.Errorf("ToJson(true) = %q, want %q", got, "1")
	}
	if got := s.ToJson(false); got != "0" {
		t.Errorf("ToJson(false) = %q, want %q", got, "0")
	}
}

func TestBoolSerializer_FromJson_trueFalse(t *testing.T) {
	s := BoolSerializer()
	if got := mustFromJson(t, s, "true"); got != true {
		t.Error("FromJson('true') = false, want true")
	}
	if got := mustFromJson(t, s, "false"); got != false {
		t.Error("FromJson('false') = true, want false")
	}
}

func TestBoolSerializer_FromJson_numericOneZero(t *testing.T) {
	s := BoolSerializer()
	if got := mustFromJson(t, s, "1"); !got {
		t.Error("FromJson('1') = false, want true")
	}
	if got := mustFromJson(t, s, "0"); got {
		t.Error("FromJson('0') = true, want false")
	}
}

func TestBoolSerializer_FromJson_nonZeroNumber(t *testing.T) {
	s := BoolSerializer()
	if got := mustFromJson(t, s, "42"); !got {
		t.Error("FromJson('42') = false, want true")
	}
	if got := mustFromJson(t, s, "-1"); !got {
		t.Error("FromJson('-1') = false, want true")
	}
}

func TestBoolSerializer_FromJson_invalidJson(t *testing.T) {
	_, err := BoolSerializer().FromJson("not-json")
	if err == nil {
		t.Error("expected error for invalid JSON, got nil")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BoolSerializer – ToJson / FromJson round-trip
// ─────────────────────────────────────────────────────────────────────────────

func TestBoolSerializer_JsonRoundTrip(t *testing.T) {
	s := BoolSerializer()
	for _, v := range []bool{true, false} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if got != v {
			t.Errorf("JSON round-trip(%v): got %v", v, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BoolSerializer – ToBytes / FromBytes
// ─────────────────────────────────────────────────────────────────────────────

func TestBoolSerializer_ToBytes_hasSkírPrefix(t *testing.T) {
	s := BoolSerializer()
	b := s.ToBytes(true)
	if len(b) < 4 || string(b[:4]) != "skir" {
		t.Errorf("ToBytes: missing 'skir' prefix, got %v", b)
	}
}

func TestBoolSerializer_ToBytes_trueEncoding(t *testing.T) {
	s := BoolSerializer()
	b := s.ToBytes(true)
	// "skir" (4 bytes) + one byte payload: 0x01
	if len(b) != 5 {
		t.Fatalf("ToBytes(true) len = %d, want 5", len(b))
	}
	if b[4] != 0x01 {
		t.Errorf("ToBytes(true) payload = %#x, want 0x01", b[4])
	}
}

func TestBoolSerializer_ToBytes_falseEncoding(t *testing.T) {
	s := BoolSerializer()
	b := s.ToBytes(false)
	if len(b) != 5 {
		t.Fatalf("ToBytes(false) len = %d, want 5", len(b))
	}
	if b[4] != 0x00 {
		t.Errorf("ToBytes(false) payload = %#x, want 0x00", b[4])
	}
}

func TestBoolSerializer_BinaryRoundTrip(t *testing.T) {
	s := BoolSerializer()
	for _, v := range []bool{true, false} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if got != v {
			t.Errorf("binary round-trip(%v): got %v", v, got)
		}
	}
}

func TestBoolSerializer_FromBytes_fallsBackToJson(t *testing.T) {
	// FromBytes treats payloads without the "skir" prefix as JSON.
	s := BoolSerializer()
	if got := mustFromBytes(t, s, []byte("true")); !got {
		t.Error("FromBytes('true' as JSON) = false, want true")
	}
	if got := mustFromBytes(t, s, []byte("false")); got {
		t.Error("FromBytes('false' as JSON) = true, want false")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BoolSerializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestBoolSerializer_TypeDescriptor(t *testing.T) {
	d := BoolSerializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeBool {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeBool", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BoolSerializer – Readable{} flavor
// ─────────────────────────────────────────────────────────────────────────────

func TestBoolSerializer_ToJson_readableFlavor(t *testing.T) {
	s := BoolSerializer()
	if got := s.ToJson(true, Readable{}); got != "true" {
		t.Errorf("ToJson(true, Readable{}) = %q, want %q", got, "true")
	}
	if got := s.ToJson(false, Readable{}); got != "false" {
		t.Errorf("ToJson(false, Readable{}) = %q, want %q", got, "false")
	}
}

func TestBoolSerializer_ToJson_denseAndReadableDiffer(t *testing.T) {
	s := BoolSerializer()
	for _, v := range []bool{true, false} {
		dense := s.ToJson(v)
		readable := s.ToJson(v, Readable{})
		if dense == readable {
			t.Errorf("bool %v: dense=%q readable=%q, expected different", v, dense, readable)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Int32Serializer
// ─────────────────────────────────────────────────────────────────────────────

func TestInt32Serializer_ToJson(t *testing.T) {
	s := Int32Serializer()
	cases := []struct {
		v    int32
		want string
	}{
		{0, "0"},
		{1, "1"},
		{-1, "-1"},
		{2147483647, "2147483647"},
		{-2147483648, "-2147483648"},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.v); got != tc.want {
			t.Errorf("ToJson(%d) = %q, want %q", tc.v, got, tc.want)
		}
	}
}

func TestInt32Serializer_FromJson(t *testing.T) {
	s := Int32Serializer()
	cases := []struct {
		code string
		want int32
	}{
		{"0", 0},
		{"42", 42},
		{"-1", -1},
		{"2147483647", 2147483647},
		{"-2147483648", -2147483648},
		// string input
		{`"100"`, 100},
		{`"-5"`, -5},
		// unknown JSON type → 0
		{"null", 0},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%q) = %d, want %d", tc.code, got, tc.want)
		}
	}
}

func TestInt32Serializer_JsonRoundTrip(t *testing.T) {
	s := Int32Serializer()
	for _, v := range []int32{0, 1, -1, 231, 232, 255, 256, 65535, 65536, 2147483647, -256, -257, -65536, -65537, -2147483648} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if got != v {
			t.Errorf("JSON round-trip(%d): got %d", v, got)
		}
	}
}

func TestInt32Serializer_BinaryRoundTrip(t *testing.T) {
	s := Int32Serializer()
	// covers all wire-format branches
	for _, v := range []int32{0, 1, 231, 232, 65535, 65536, 2147483647, -1, -255, -256, -257, -65535, -65536, -65537, -2147483648} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if got != v {
			t.Errorf("binary round-trip(%d): got %d", v, got)
		}
	}
}

func TestInt32Serializer_TypeDescriptor(t *testing.T) {
	d := Int32Serializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeInt32 {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeInt32", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Int64Serializer
// ─────────────────────────────────────────────────────────────────────────────

func TestInt64Serializer_ToJson_safeIntegers(t *testing.T) {
	s := Int64Serializer()
	// Only assert exact JSON text for values fastjson emits as plain integers.
	cases := []struct {
		v    int64
		want string
	}{
		{0, "0"},
		{1, "1"},
		{-1, "-1"},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.v); got != tc.want {
			t.Errorf("ToJson(%d) = %q, want %q", tc.v, got, tc.want)
		}
	}
	// Values within the safe range must NOT be wrapped in quotes.
	for _, v := range []int64{9007199254740991, -9007199254740991} {
		code := s.ToJson(v)
		if len(code) > 0 && code[0] == '"' {
			t.Errorf("ToJson(%d) = %q: safe integer should not be quoted", v, code)
		}
	}
}

func TestInt64Serializer_ToJson_unsafeIntegers(t *testing.T) {
	s := Int64Serializer()
	// Values outside safe range → JSON string
	cases := []struct {
		v    int64
		want string
	}{
		{9007199254740991, "9007199254740991"},
		{-9007199254740991, "-9007199254740991"},
		{9007199254740992, `"9007199254740992"`},
		{-9007199254740992, `"-9007199254740992"`},
		{9223372036854775807, `"9223372036854775807"`},   // math.MaxInt64
		{-9223372036854775808, `"-9223372036854775808"`}, // math.MinInt64
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.v); got != tc.want {
			t.Errorf("ToJson(%d) = %q, want %q", tc.v, got, tc.want)
		}
	}
}

func TestInt64Serializer_FromJson(t *testing.T) {
	s := Int64Serializer()
	cases := []struct {
		code string
		want int64
	}{
		{"0", 0},
		{"42", 42},
		{"-1", -1},
		// large value encoded as string
		{`"9007199254740992"`, 9007199254740992},
		{`"-9007199254740992"`, -9007199254740992},
		{`"9223372036854775807"`, 9223372036854775807},
		// unknown type → 0
		{"null", 0},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%q) = %d, want %d", tc.code, got, tc.want)
		}
	}
}

func TestInt64Serializer_JsonRoundTrip(t *testing.T) {
	s := Int64Serializer()
	for _, v := range []int64{0, 1, -1, 9007199254740991, -9007199254740991, 9007199254740992, -9007199254740992, 9223372036854775807, -9223372036854775808} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if got != v {
			t.Errorf("JSON round-trip(%d): got %d", v, got)
		}
	}
}

func TestInt64Serializer_BinaryRoundTrip(t *testing.T) {
	s := Int64Serializer()
	// covers: zero, int32 range reuse, wire-238 large values
	for _, v := range []int64{0, 1, -1, 231, 232, 2147483647, -2147483648, 2147483648, -2147483649, 9223372036854775807, -9223372036854775808} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if got != v {
			t.Errorf("binary round-trip(%d): got %d", v, got)
		}
	}
}

func TestInt64Serializer_TypeDescriptor(t *testing.T) {
	d := Int64Serializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeInt64 {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeInt64", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Hash64Serializer
// ─────────────────────────────────────────────────────────────────────────────

func TestHash64Serializer_ToJson_safeIntegers(t *testing.T) {
	s := Hash64Serializer()
	// Only assert exact JSON text for values fastjson emits as plain integers.
	cases := []struct {
		v    uint64
		want string
	}{
		{0, "0"},
		{1, "1"},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.v); got != tc.want {
			t.Errorf("ToJson(%d) = %q, want %q", tc.v, got, tc.want)
		}
	}
	// MAX_SAFE_INTEGER must NOT be wrapped in quotes.
	code := s.ToJson(9007199254740991)
	if len(code) > 0 && code[0] == '"' {
		t.Errorf("ToJson(MAX_SAFE_INTEGER) = %q: should not be quoted", code)
	}
}

func TestHash64Serializer_ToJson_unsafeIntegers(t *testing.T) {
	s := Hash64Serializer()
	cases := []struct {
		v    uint64
		want string
	}{
		{9007199254740992, `"9007199254740992"`},
		{18446744073709551615, `"18446744073709551615"`}, // math.MaxUint64
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.v); got != tc.want {
			t.Errorf("ToJson(%d) = %q, want %q", tc.v, got, tc.want)
		}
	}
}

func TestHash64Serializer_FromJson(t *testing.T) {
	s := Hash64Serializer()
	cases := []struct {
		code string
		want uint64
	}{
		{"0", 0},
		{"255", 255},
		// negative number → 0
		{"-1", 0},
		// large value as string
		{`"9007199254740992"`, 9007199254740992},
		{`"18446744073709551615"`, 18446744073709551615},
		// unknown type → 0
		{"null", 0},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%q) = %d, want %d", tc.code, got, tc.want)
		}
	}
}

func TestHash64Serializer_JsonRoundTrip(t *testing.T) {
	s := Hash64Serializer()
	for _, v := range []uint64{0, 1, 231, 9007199254740991, 9007199254740992, 18446744073709551615} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if got != v {
			t.Errorf("JSON round-trip(%d): got %d", v, got)
		}
	}
}

func TestHash64Serializer_BinaryRoundTrip(t *testing.T) {
	s := Hash64Serializer()
	// covers all wire branches: single-byte, uint16, uint32, uint64
	for _, v := range []uint64{0, 1, 231, 232, 65535, 65536, 4294967295, 4294967296, 18446744073709551615} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if got != v {
			t.Errorf("binary round-trip(%d): got %d", v, got)
		}
	}
}

func TestHash64Serializer_TypeDescriptor(t *testing.T) {
	d := Hash64Serializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeHash64 {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeHash64", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float32Serializer – ToJson
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat32Serializer_ToJson_finiteValues(t *testing.T) {
	s := Float32Serializer()
	cases := []struct {
		input float32
		want  string
	}{
		{0, "0"},
		{float32(math.Copysign(0, -1)), "-0"},
		{1, "1"},
		{-1, "-1"},
		{3.14, "3.14"},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%v) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

func TestFloat32Serializer_ToJson_nonFiniteValues(t *testing.T) {
	s := Float32Serializer()
	cases := []struct {
		input float32
		want  string
	}{
		{float32(math.Inf(1)), `"Infinity"`},
		{float32(math.Inf(-1)), `"-Infinity"`},
		{float32(math.NaN()), `"NaN"`},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%v) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float32Serializer – FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat32Serializer_FromJson_numbers(t *testing.T) {
	s := Float32Serializer()
	cases := []struct {
		code string
		want float32
	}{
		{"0", 0},
		{"1", 1},
		{"-1", -1},
		{"3.14", float32(3.14)},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%s) = %v, want %v", tc.code, got, tc.want)
		}
	}
}

func TestFloat32Serializer_FromJson_specialStringTokens(t *testing.T) {
	s := Float32Serializer()
	inf := mustFromJson(t, s, `"Infinity"`)
	if !math.IsInf(float64(inf), 1) {
		t.Errorf(`FromJson("Infinity") = %v, want +Inf`, inf)
	}
	negInf := mustFromJson(t, s, `"-Infinity"`)
	if !math.IsInf(float64(negInf), -1) {
		t.Errorf(`FromJson("-Infinity") = %v, want -Inf`, negInf)
	}
	nan := mustFromJson(t, s, `"NaN"`)
	if !math.IsNaN(float64(nan)) {
		t.Errorf(`FromJson("NaN") = %v, want NaN`, nan)
	}
}

func TestFloat32Serializer_JsonRoundTrip(t *testing.T) {
	s := Float32Serializer()
	for _, v := range []float32{0, -0, 1, -1, 3.14, float32(math.Inf(1)), float32(math.Inf(-1))} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		// Use bits comparison so -0 round-trips correctly.
		if math.Float32bits(got) != math.Float32bits(v) {
			t.Errorf("round-trip(%v): got %v (bits %08x), want bits %08x",
				v, got, math.Float32bits(got), math.Float32bits(v))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float32Serializer – binary encode / decode
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat32Serializer_ToBytes_zero(t *testing.T) {
	b := Float32Serializer().ToBytes(0)
	// "skir" prefix + wire 0x00 for default value
	if len(b) != 5 || string(b[:4]) != "skir" || b[4] != 0x00 {
		t.Errorf("ToBytes(0) = %x, want skir+[00]", b)
	}
}

func TestFloat32Serializer_ToBytes_nonZero(t *testing.T) {
	b := Float32Serializer().ToBytes(1.0)
	// "skir" prefix + wire 0xf0 + 4-byte little-endian IEEE 754: 0x3f800000
	if len(b) != 9 || string(b[:4]) != "skir" || b[4] != 0xf0 {
		t.Errorf("ToBytes(1.0) = %x, unexpected layout", b)
	}
	// 1.0f as little-endian bytes: 00 00 80 3f
	wantPayload := []byte{0x00, 0x00, 0x80, 0x3f}
	for i, wb := range wantPayload {
		if b[5+i] != wb {
			t.Errorf("ToBytes(1.0) payload byte[%d] = %02x, want %02x", i, b[5+i], wb)
		}
	}
}

func TestFloat32Serializer_BinaryRoundTrip(t *testing.T) {
	s := Float32Serializer()
	for _, v := range []float32{0, 1, -1, 3.14, float32(math.Inf(1)), float32(math.Inf(-1))} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if math.Float32bits(got) != math.Float32bits(v) {
			t.Errorf("binary round-trip(%v): got %v", v, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float32Serializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat32Serializer_TypeDescriptor(t *testing.T) {
	d := Float32Serializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeFloat32 {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeFloat32", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float64Serializer – ToJson
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat64Serializer_ToJson_finiteValues(t *testing.T) {
	s := Float64Serializer()
	cases := []struct {
		input float64
		want  string
	}{
		{0, "0"},
		{math.Copysign(0, -1), "-0"},
		{1, "1"},
		{-1, "-1"},
		{3.14, "3.14"},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%v) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

func TestFloat64Serializer_ToJson_nonFiniteValues(t *testing.T) {
	s := Float64Serializer()
	cases := []struct {
		input float64
		want  string
	}{
		{math.Inf(1), `"Infinity"`},
		{math.Inf(-1), `"-Infinity"`},
		{math.NaN(), `"NaN"`},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%v) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float64Serializer – FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat64Serializer_FromJson_numbers(t *testing.T) {
	s := Float64Serializer()
	cases := []struct {
		code string
		want float64
	}{
		{"0", 0},
		{"1", 1},
		{"-1", -1},
		{"3.14", 3.14},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%s) = %v, want %v", tc.code, got, tc.want)
		}
	}
}

func TestFloat64Serializer_FromJson_specialStringTokens(t *testing.T) {
	s := Float64Serializer()
	inf := mustFromJson(t, s, `"Infinity"`)
	if !math.IsInf(inf, 1) {
		t.Errorf(`FromJson("Infinity") = %v, want +Inf`, inf)
	}
	negInf := mustFromJson(t, s, `"-Infinity"`)
	if !math.IsInf(negInf, -1) {
		t.Errorf(`FromJson("-Infinity") = %v, want -Inf`, negInf)
	}
	nan := mustFromJson(t, s, `"NaN"`)
	if !math.IsNaN(nan) {
		t.Errorf(`FromJson("NaN") = %v, want NaN`, nan)
	}
}

func TestFloat64Serializer_JsonRoundTrip(t *testing.T) {
	s := Float64Serializer()
	for _, v := range []float64{0, -0, 1, -1, 3.14, math.Inf(1), math.Inf(-1)} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if math.Float64bits(got) != math.Float64bits(v) {
			t.Errorf("round-trip(%v): got %v (bits %016x), want bits %016x",
				v, got, math.Float64bits(got), math.Float64bits(v))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float64Serializer – binary encode / decode
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat64Serializer_ToBytes_zero(t *testing.T) {
	b := Float64Serializer().ToBytes(0)
	// "skir" prefix + wire 0x00 for default value
	if len(b) != 5 || string(b[:4]) != "skir" || b[4] != 0x00 {
		t.Errorf("ToBytes(0) = %x, want skir+[00]", b)
	}
}

func TestFloat64Serializer_ToBytes_nonZero(t *testing.T) {
	b := Float64Serializer().ToBytes(1.0)
	// "skir" prefix + wire 0xf1 + 8-byte little-endian IEEE 754: 0x3ff0000000000000
	if len(b) != 13 || string(b[:4]) != "skir" || b[4] != 0xf1 {
		t.Errorf("ToBytes(1.0) = %x, unexpected layout", b)
	}
	// 1.0 as little-endian bytes: 00 00 00 00 00 00 f0 3f
	wantPayload := []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x3f}
	for i, wb := range wantPayload {
		if b[5+i] != wb {
			t.Errorf("ToBytes(1.0) payload byte[%d] = %02x, want %02x", i, b[5+i], wb)
		}
	}
}

func TestFloat64Serializer_BinaryRoundTrip(t *testing.T) {
	s := Float64Serializer()
	for _, v := range []float64{0, 1, -1, 3.14, math.Inf(1), math.Inf(-1)} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if math.Float64bits(got) != math.Float64bits(v) {
			t.Errorf("binary round-trip(%v): got %v", v, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Float64Serializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestFloat64Serializer_TypeDescriptor(t *testing.T) {
	d := Float64Serializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeFloat64 {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeFloat64", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TimestampSerializer – ToJson
// ─────────────────────────────────────────────────────────────────────────────

func TestTimestampSerializer_ToJson_epochIsZero(t *testing.T) {
	s := TimestampSerializer()
	epoch := time.UnixMilli(0).UTC()
	if got := s.ToJson(epoch); got != "0" {
		t.Errorf("ToJson(epoch) = %s, want 0", got)
	}
}

func TestTimestampSerializer_ToJson_denseIsUnixMillis(t *testing.T) {
	s := TimestampSerializer()
	cases := []struct {
		ms   int64
		want string
	}{
		{1738619881001, "1738619881001"},
		{-1, "-1"},
		{8640000000000000, "8640000000000000"},
		{-8640000000000000, "-8640000000000000"},
	}
	for _, tc := range cases {
		got := s.ToJson(time.UnixMilli(tc.ms).UTC())
		if got != tc.want {
			t.Errorf("ToJson(%d ms) = %s, want %s", tc.ms, got, tc.want)
		}
	}
}

func TestTimestampSerializer_ToJson_readableFlavor(t *testing.T) {
	s := TimestampSerializer()
	epoch := time.UnixMilli(0).UTC()
	got := s.ToJson(epoch, Readable{})
	// Must contain both fields.
	if !containsStr(got, `"unix_millis"`) || !containsStr(got, `"formatted"`) {
		t.Errorf("readable JSON missing fields: %s", got)
	}
	// Epoch formatted as ISO-8601.
	if !containsStr(got, "1970-01-01T00:00:00.000Z") {
		t.Errorf("readable JSON missing formatted epoch: %s", got)
	}
}

func TestTimestampSerializer_ToJson_readableFormatted(t *testing.T) {
	s := TimestampSerializer()
	// 2025-02-03T21:58:01.001Z = 1738619881001 ms
	ts := time.UnixMilli(1738619881001).UTC()
	got := s.ToJson(ts, Readable{})
	if !containsStr(got, "2025-02-03T21:58:01.001Z") {
		t.Errorf("readable JSON formatted = %s, want 2025-02-03T21:58:01.001Z", got)
	}
}

// containsStr is a helper used by multiple test functions.
func containsStr(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 ||
		func() bool {
			for i := 0; i+len(substr) <= len(s); i++ {
				if s[i:i+len(substr)] == substr {
					return true
				}
			}
			return false
		}())
}

// ─────────────────────────────────────────────────────────────────────────────
// TimestampSerializer – FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestTimestampSerializer_FromJson_number(t *testing.T) {
	s := TimestampSerializer()
	cases := []struct {
		code string
		ms   int64
	}{
		{"0", 0},
		{"1738619881001", 1738619881001},
		{"-1", -1},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got.UnixMilli() != tc.ms {
			t.Errorf("FromJson(%s).UnixMilli() = %d, want %d", tc.code, got.UnixMilli(), tc.ms)
		}
	}
}

func TestTimestampSerializer_FromJson_readableObject(t *testing.T) {
	s := TimestampSerializer()
	// Readable flavor: object with unix_millis field; formatted is ignored.
	got := mustFromJson(t, s, `{"unix_millis": 1000, "formatted": "ignored"}`)
	if got.UnixMilli() != 1000 {
		t.Errorf("FromJson(readable object).UnixMilli() = %d, want 1000", got.UnixMilli())
	}
}

func TestTimestampSerializer_FromJson_clampsBelowMin(t *testing.T) {
	s := TimestampSerializer()
	got := mustFromJson(t, s, "-9999999999999999")
	if got.UnixMilli() != -8640000000000000 {
		t.Errorf("clamped millis = %d, want -8640000000000000", got.UnixMilli())
	}
}

func TestTimestampSerializer_FromJson_clampsAboveMax(t *testing.T) {
	s := TimestampSerializer()
	got := mustFromJson(t, s, "9999999999999999")
	if got.UnixMilli() != 8640000000000000 {
		t.Errorf("clamped millis = %d, want 8640000000000000", got.UnixMilli())
	}
}

func TestTimestampSerializer_JsonRoundTrip(t *testing.T) {
	s := TimestampSerializer()
	for _, ms := range []int64{0, 1, -1, 1738619881001, 8640000000000000, -8640000000000000} {
		ts := time.UnixMilli(ms).UTC()
		code := s.ToJson(ts)
		got := mustFromJson(t, s, code)
		if got.UnixMilli() != ms {
			t.Errorf("round-trip(%d ms): got %d", ms, got.UnixMilli())
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TimestampSerializer – binary encode / decode
// ─────────────────────────────────────────────────────────────────────────────

func TestTimestampSerializer_ToBytes_epoch(t *testing.T) {
	b := TimestampSerializer().ToBytes(time.UnixMilli(0).UTC())
	// "skir" prefix + wire 0x00 for default value
	if len(b) != 5 || string(b[:4]) != "skir" || b[4] != 0x00 {
		t.Errorf("ToBytes(epoch) = %x, want skir+[00]", b)
	}
}

func TestTimestampSerializer_ToBytes_nonZero(t *testing.T) {
	b := TimestampSerializer().ToBytes(time.UnixMilli(1738619881001).UTC())
	// "skir" prefix + wire 0xef (239) + 8-byte little-endian int64
	if len(b) != 13 || string(b[:4]) != "skir" || b[4] != 0xef {
		t.Errorf("ToBytes(1738619881001) = %x, unexpected layout", b)
	}
}

func TestTimestampSerializer_BinaryRoundTrip(t *testing.T) {
	s := TimestampSerializer()
	for _, ms := range []int64{0, 1, -1, 1738619881001, 8640000000000000, -8640000000000000} {
		ts := time.UnixMilli(ms).UTC()
		b := s.ToBytes(ts)
		got := mustFromBytes(t, s, b)
		if got.UnixMilli() != ms {
			t.Errorf("binary round-trip(%d ms): got %d", ms, got.UnixMilli())
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TimestampSerializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestTimestampSerializer_TypeDescriptor(t *testing.T) {
	d := TimestampSerializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeTimestamp {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeTimestamp", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesSerializer – ToJson
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesSerializer_ToJson_emptyIsDenseBase64(t *testing.T) {
	got := BytesSerializer().ToJson(Bytes{})
	if got != `""` {
		t.Errorf("ToJson(empty) dense = %s, want %q", got, "")
	}
}

func TestBytesSerializer_ToJson_denseIsBase64(t *testing.T) {
	s := BytesSerializer()
	b := BytesFromSlice([]byte{0x00, 0x08, 0xff})
	if got := s.ToJson(b); got != `"AAj/"` {
		t.Errorf("ToJson dense = %s, want %q", got, "AAj/")
	}
}

func TestBytesSerializer_ToJson_readableEmptyIsHexColon(t *testing.T) {
	got := BytesSerializer().ToJson(Bytes{}, Readable{})
	if got != `"hex:"` {
		t.Errorf("ToJson(empty) readable = %s, want %q", got, "hex:")
	}
}

func TestBytesSerializer_ToJson_readableIsHex(t *testing.T) {
	s := BytesSerializer()
	b := BytesFromSlice([]byte{0x00, 0x08, 0xff})
	if got := s.ToJson(b, Readable{}); got != `"hex:0008ff"` {
		t.Errorf("ToJson readable = %s, want %q", got, "hex:0008ff")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesSerializer – FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesSerializer_FromJson_base64(t *testing.T) {
	s := BytesSerializer()
	got := mustFromJson(t, s, `"AAj/"`)
	want := BytesFromSlice([]byte{0x00, 0x08, 0xff})
	if !got.Equal(want) {
		t.Errorf("FromJson base64 = %v, want %v", got, want)
	}
}

func TestBytesSerializer_FromJson_hexPrefix(t *testing.T) {
	s := BytesSerializer()
	got := mustFromJson(t, s, `"hex:0008ff"`)
	want := BytesFromSlice([]byte{0x00, 0x08, 0xff})
	if !got.Equal(want) {
		t.Errorf("FromJson hex = %v, want %v", got, want)
	}
}

func TestBytesSerializer_FromJson_emptyBase64(t *testing.T) {
	got := mustFromJson(t, BytesSerializer(), `""`)
	if !got.IsEmpty() {
		t.Errorf("FromJson empty base64: got non-empty %v", got)
	}
}

func TestBytesSerializer_FromJson_emptyHex(t *testing.T) {
	got := mustFromJson(t, BytesSerializer(), `"hex:"`)
	if !got.IsEmpty() {
		t.Errorf("FromJson hex: empty: got non-empty %v", got)
	}
}

func TestBytesSerializer_FromJson_zeroIsEmpty(t *testing.T) {
	got := mustFromJson(t, BytesSerializer(), "0")
	if !got.IsEmpty() {
		t.Errorf("FromJson(0) = %v, want empty", got)
	}
}

func TestBytesSerializer_JsonRoundTrip(t *testing.T) {
	s := BytesSerializer()
	cases := []Bytes{
		{},
		BytesFromSlice([]byte{0x00, 0x08, 0xff}),
		BytesFromSlice([]byte{0xde, 0xad, 0xbe, 0xef}),
	}
	for _, b := range cases {
		code := s.ToJson(b)
		got := mustFromJson(t, s, code)
		if !got.Equal(b) {
			t.Errorf("round-trip(%v): got %v", b, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesSerializer – binary encode / decode
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesSerializer_ToBytes_empty(t *testing.T) {
	b := BytesSerializer().ToBytes(Bytes{})
	// "skir" prefix + wire 0xf4 (244) for empty Bytes
	if len(b) != 5 || string(b[:4]) != "skir" || b[4] != 0xf4 {
		t.Errorf("ToBytes(empty) = %x, want skir+[f4]", b)
	}
}

func TestBytesSerializer_ToBytes_nonEmpty(t *testing.T) {
	payload := []byte{0x00, 0x08, 0xff}
	b := BytesSerializer().ToBytes(BytesFromSlice(payload))
	// "skir" prefix + wire 0xf5 (245) + length (3) + raw bytes
	if len(b) != 9 || string(b[:4]) != "skir" || b[4] != 0xf5 {
		t.Errorf("ToBytes non-empty = %x, unexpected layout", b)
	}
	// length byte is 3 (fits in single-byte encodeUint32)
	if b[5] != 0x03 {
		t.Errorf("length byte = %02x, want 03", b[5])
	}
	for i, wb := range payload {
		if b[6+i] != wb {
			t.Errorf("payload byte[%d] = %02x, want %02x", i, b[6+i], wb)
		}
	}
}

func TestBytesSerializer_FromBytes_wireZeroIsEmpty(t *testing.T) {
	// Wire 0x00 = default, should decode to empty Bytes (needs "skir" prefix).
	got := mustFromBytes(t, BytesSerializer(), []byte("skir\x00"))
	if !got.IsEmpty() {
		t.Errorf("FromBytes(skir+[00]) = %v, want empty", got)
	}
}

func TestBytesSerializer_FromBytes_wire244IsEmpty(t *testing.T) {
	got := mustFromBytes(t, BytesSerializer(), []byte("skir\xf4"))
	if !got.IsEmpty() {
		t.Errorf("FromBytes(skir+[f4]) = %v, want empty", got)
	}
}

func TestBytesSerializer_BinaryRoundTrip(t *testing.T) {
	s := BytesSerializer()
	cases := []Bytes{
		{},
		BytesFromSlice([]byte{0x00, 0x08, 0xff}),
		BytesFromSlice([]byte{0xde, 0xad, 0xbe, 0xef}),
	}
	for _, b := range cases {
		enc := s.ToBytes(b)
		got := mustFromBytes(t, s, enc)
		if !got.Equal(b) {
			t.Errorf("binary round-trip(%v): got %v", b, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesSerializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestBytesSerializer_TypeDescriptor(t *testing.T) {
	d := BytesSerializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeBytes {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeBytes", pd.PrimitiveType())
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// StringSerializer – ToJson / JSON escaping
// ─────────────────────────────────────────────────────────────────────────────

func TestStringSerializer_ToJson_emptyAndPlain(t *testing.T) {
	s := StringSerializer()
	cases := []struct {
		input string
		want  string
	}{
		{"", `""`},
		{"hello", `"hello"`},
		{"pokémon", `"pokémon"`},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%q) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

func TestStringSerializer_ToJson_mustEscapeChars(t *testing.T) {
	s := StringSerializer()
	cases := []struct {
		input string
		want  string
	}{
		// JSON-mandated escape sequences
		{"\n", `"\n"`},
		{"\r", `"\r"`},
		{"\t", `"\t"`},
		{"\b", `"\b"`},
		{"\f", `"\f"`},
		{`"`, `"\""`},
		{`\`, `"\\"`},
		// Combined
		{"\"\n", `"\"` + `\n"`},
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%q) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

// Single quote must NOT be escaped (matches C++ skir::ToDenseJson behavior).
func TestStringSerializer_ToJson_singleQuoteNotEscaped(t *testing.T) {
	s := StringSerializer()
	if got := s.ToJson("'"); got != `"'"` {
		t.Errorf(`ToJson("'") = %s, want "'"`, got)
	}
}

func TestStringSerializer_ToJson_controlCharEscaping(t *testing.T) {
	s := StringSerializer()
	// Low ASCII control characters (0x00–0x1F excluding named escapes) and DEL
	// are written as \uXXXX with lowercase hex digits.
	cases := []struct {
		input string
		want  string
	}{
		{"\x00", `"\u0000"`},           // NUL
		{"\x01", `"\u0001"`},           // SOH
		{"\x1a", `"\u001a"`},           // SUB  (C++ uses uppercase \u001A; Go is lowercase)
		{"\x1f", `"\u001f"`},           // US
		{"\x7f", `"\u007f"`},           // DEL
		{"\x00\x00", `"\u0000\u0000"`}, // two NUL bytes (from C++ test)
	}
	for _, tc := range cases {
		if got := s.ToJson(tc.input); got != tc.want {
			t.Errorf("ToJson(%q) = %s, want %s", tc.input, got, tc.want)
		}
	}
}

func TestStringSerializer_ToJson_validUtf8PassedThrough(t *testing.T) {
	s := StringSerializer()
	// Multi-byte UTF-8 sequences are passed through verbatim (not \uXXXX-escaped).
	cases := []struct {
		desc  string
		input string
		want  string
	}{
		{"2-byte U+00E9", "é", `"é"`},
		{"multi-char", "pokémon", `"pokémon"`},
		{"CJK", "这是什么", `"这是什么"`},
		{"4-byte U+1033C 𐌼", "\xf0\x90\x8c\xbc", `"` + "\xf0\x90\x8c\xbc" + `"`},
		{"emoji 😊", "😊", `"😊"`},
	}
	for _, tc := range cases {
		t.Run(tc.desc, func(t *testing.T) {
			if got := s.ToJson(tc.input); got != tc.want {
				t.Errorf("ToJson = %s, want %s", got, tc.want)
			}
		})
	}
}

func TestStringSerializer_ToJson_invalidUtf8ReplacedWithEscape(t *testing.T) {
	s := StringSerializer()
	// Invalid UTF-8 bytes are replaced with the JSON escape \ufffd.
	const ufffd = `\ufffd`
	cases := []struct {
		desc  string
		input string
		want  string
	}{
		// Lone continuation bytes
		{"lone continuation bytes", "\xa0\xa1", `"` + ufffd + ufffd + `"`},
		// Incomplete 2-byte sequence followed by ASCII
		{"incomplete 2-byte + ASCII", "\xc3z", `"` + ufffd + `z"`},
		// Two incomplete 2-byte sequences
		{"two incomplete 2-byte", "\xc3\xc3", `"` + ufffd + ufffd + `"`},
		// Incomplete 3-byte sequence: \xe2\x28 – \x28 is not a continuation byte
		{"incomplete 3-byte", "\xe2\x28\xa1", `"` + ufffd + `(` + ufffd + `"`},
	}
	for _, tc := range cases {
		t.Run(tc.desc, func(t *testing.T) {
			if got := s.ToJson(tc.input); got != tc.want {
				t.Errorf("ToJson(%q) = %s, want %s", tc.input, got, tc.want)
			}
		})
	}
}

// Dense and readable flavors produce the same JSON for strings.
func TestStringSerializer_ToJson_readableFlavorSameAsDense(t *testing.T) {
	s := StringSerializer()
	for _, v := range []string{"", "hello", "pokémon", "a\nb"} {
		dense := s.ToJson(v)
		readable := s.ToJson(v, Readable{})
		if dense != readable {
			t.Errorf("ToJson(%q): dense=%s readable=%s (should be equal)", v, dense, readable)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// StringSerializer – FromJson
// ─────────────────────────────────────────────────────────────────────────────

func TestStringSerializer_FromJson(t *testing.T) {
	s := StringSerializer()
	cases := []struct {
		code string
		want string
	}{
		{`""`, ""},
		{`"hello"`, "hello"},
		{`"pokémon"`, "pokémon"},
		// Escaped sequences are decoded
		{`"\"\\n\""`, "\"\\" + "n\""},
		{`"\n"`, "\n"},
		{`"\t"`, "\t"},
		{`"\u0041"`, "A"},
	}
	for _, tc := range cases {
		got := mustFromJson(t, s, tc.code)
		if got != tc.want {
			t.Errorf("FromJson(%s) = %q, want %q", tc.code, got, tc.want)
		}
	}
}

// The number 0 is the dense default representation for the empty string.
func TestStringSerializer_FromJson_zeroIsEmptyString(t *testing.T) {
	got := mustFromJson(t, StringSerializer(), "0")
	if got != "" {
		t.Errorf(`FromJson("0") = %q, want ""`, got)
	}
}

func TestStringSerializer_FromJson_roundTrip(t *testing.T) {
	s := StringSerializer()
	for _, v := range []string{"", "hello", "pokémon", "\n\t\"\\", "这是什么"} {
		code := s.ToJson(v)
		got := mustFromJson(t, s, code)
		if got != v {
			t.Errorf("round-trip(%q): got %q", v, got)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// StringSerializer – binary encode / decode
// ─────────────────────────────────────────────────────────────────────────────

func TestStringSerializer_ToBytes_empty(t *testing.T) {
	b := StringSerializer().ToBytes("")
	// "skir" prefix (4 bytes) + wire 242 (0xf2) for empty string
	if len(b) != 5 || string(b[:4]) != "skir" || b[4] != 0xf2 {
		t.Errorf("ToBytes(\"\") = %x, want skir+[f2]", b)
	}
}

func TestStringSerializer_ToBytes_noEscaping(t *testing.T) {
	// Binary encoding stores raw UTF-8 bytes – no JSON escaping applied.
	s := StringSerializer()
	b := s.ToBytes("\"\n")
	got := mustFromBytes(t, s, b)
	if got != "\"\n" {
		t.Errorf(`binary round-trip("\"\n") = %q, want "\"\n"`, got)
	}
	// Payload bytes must be the raw chars 0x22 0x0A, not their JSON escapes.
	// wire=243, encoded_len=2, 0x22, 0x0A
	if len(b) < 3 || b[len(b)-2] != 0x22 || b[len(b)-1] != 0x0a {
		t.Errorf("ToBytes unexpected payload: %x", b)
	}
}

func TestStringSerializer_ToBytes_invalidUtf8ReplacedWithRuneError(t *testing.T) {
	// Unlike ToJson, the binary encoder replaces invalid UTF-8 with the actual
	// U+FFFD character (strings.ToValidUTF8), not the \ufffd JSON escape.
	s := StringSerializer()
	b := s.ToBytes("\xc3z") // \xc3 is an incomplete 2-byte lead
	got := mustFromBytes(t, s, b)
	// must decode successfully and contain the replacement character followed by 'z'
	runeError := string('\uFFFD')
	if got != runeError+"z" {
		t.Errorf("binary round-trip(invalid UTF-8) = %q, want %q", got, runeError+"z")
	}
}

func TestStringSerializer_BinaryRoundTrip(t *testing.T) {
	s := StringSerializer()
	for _, v := range []string{"", "hello", "pokémon", "\n\t\"\\", "这是什么", "😊"} {
		b := s.ToBytes(v)
		got := mustFromBytes(t, s, b)
		if got != v {
			t.Errorf("binary round-trip(%q): got %q", v, got)
		}
	}
}

func TestStringSerializer_FromBytes_wireZeroIsEmptyString(t *testing.T) {
	// Wire byte 0x00 means default (empty string). Must include the "skir" prefix
	// so FromBytes routes to the binary decoder rather than falling back to JSON.
	got := mustFromBytes(t, StringSerializer(), []byte("skir\x00"))
	if got != "" {
		t.Errorf("FromBytes(skir+[00]) = %q, want empty string", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// StringSerializer – TypeDescriptor
// ─────────────────────────────────────────────────────────────────────────────

func TestStringSerializer_TypeDescriptor(t *testing.T) {
	d := StringSerializer().TypeDescriptor()
	pd, ok := d.(*PrimitiveDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor type = %T, want *PrimitiveDescriptor", d)
	}
	if pd.PrimitiveType() != PrimitiveTypeString {
		t.Errorf("PrimitiveType = %v, want PrimitiveTypeString", pd.PrimitiveType())
	}
}
