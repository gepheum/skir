package e2e_test

import (
	"strings"
	"testing"

	full_name "e2e-test/skirout/full_name"

	skir_client "github.com/gepheum/skir-go-client"
)

// Default value tests

func TestFullName_DefaultValue(t *testing.T) {
	d := full_name.FullName_default()
	if d.FirstName() != "" {
		t.Errorf("default FirstName: got %q, want %q", d.FirstName(), "")
	}
	if d.LastName() != "" {
		t.Errorf("default LastName: got %q, want %q", d.LastName(), "")
	}
}

func TestFullName_DefaultValue_IsSingleton(t *testing.T) {
	def := full_name.FullName_default()
	if full_name.FullName_default() != def {
		t.Error("FullName_default() should return the same pointer every time")
	}
}

// Ordered builder tests

func TestFullName_Builder(t *testing.T) {
	fn := full_name.FullName_builder().
		SetFirstName("John").
		SetLastName("Doe").
		Build()
	if fn.FirstName() != "John" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "John")
	}
	if fn.LastName() != "Doe" {
		t.Errorf("LastName: got %q, want %q", fn.LastName(), "Doe")
	}
}

func TestFullName_Builder_EmptyStrings(t *testing.T) {
	fn := full_name.FullName_builder().
		SetFirstName("").
		SetLastName("").
		Build()
	if fn.FirstName() != "" || fn.LastName() != "" {
		t.Errorf("expected empty fields, got FirstName=%q LastName=%q", fn.FirstName(), fn.LastName())
	}
}

// Partial builder tests

func TestFullName_PartialBuilder_OnlyLastName(t *testing.T) {
	fn := full_name.FullName_partialBuilder().
		SetLastName("Smith").
		Build()
	if fn.FirstName() != "" {
		t.Errorf("FirstName: got %q, want empty", fn.FirstName())
	}
	if fn.LastName() != "Smith" {
		t.Errorf("LastName: got %q, want %q", fn.LastName(), "Smith")
	}
}

func TestFullName_PartialBuilder_OnlyFirstName(t *testing.T) {
	fn := full_name.FullName_partialBuilder().
		SetFirstName("Alice").
		Build()
	if fn.FirstName() != "Alice" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "Alice")
	}
	if fn.LastName() != "" {
		t.Errorf("LastName: got %q, want empty", fn.LastName())
	}
}

func TestFullName_PartialBuilder_BothFields_AnyOrder(t *testing.T) {
	fn := full_name.FullName_partialBuilder().
		SetLastName("Doe").
		SetFirstName("Jane").
		Build()
	if fn.FirstName() != "Jane" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "Jane")
	}
	if fn.LastName() != "Doe" {
		t.Errorf("LastName: got %q, want %q", fn.LastName(), "Doe")
	}
}

// ToBuilder (copy-and-modify) tests

func TestFullName_ToBuilder_ModifyFirstName(t *testing.T) {
	original := full_name.FullName_builder().
		SetFirstName("Jane").
		SetLastName("Doe").
		Build()
	modified := original.ToBuilder().SetFirstName("Alice").Build()

	if modified.FirstName() != "Alice" {
		t.Errorf("modified FirstName: got %q, want %q", modified.FirstName(), "Alice")
	}
	if modified.LastName() != "Doe" {
		t.Errorf("modified LastName should be unchanged: got %q, want %q", modified.LastName(), "Doe")
	}
	if original.FirstName() != "Jane" {
		t.Errorf("original FirstName should be unchanged: got %q, want %q", original.FirstName(), "Jane")
	}
}

func TestFullName_ToBuilder_ModifyLastName(t *testing.T) {
	original := full_name.FullName_builder().
		SetFirstName("Bob").
		SetLastName("Old").
		Build()
	modified := original.ToBuilder().SetLastName("New").Build()

	if modified.FirstName() != "Bob" {
		t.Errorf("modified FirstName should be unchanged: got %q, want %q", modified.FirstName(), "Bob")
	}
	if modified.LastName() != "New" {
		t.Errorf("modified LastName: got %q, want %q", modified.LastName(), "New")
	}
	if original.LastName() != "Old" {
		t.Errorf("original LastName should be unchanged: got %q, want %q", original.LastName(), "Old")
	}
}

// String() tests

func TestFullName_String(t *testing.T) {
	fn := full_name.FullName_builder().
		SetFirstName("John").
		SetLastName("Doe").
		Build()
	s := fn.String()
	if !strings.Contains(s, "John") {
		t.Errorf("String() %q does not contain %q", s, "John")
	}
	if !strings.Contains(s, "Doe") {
		t.Errorf("String() %q does not contain %q", s, "Doe")
	}
	// String() uses readable JSON which is multi-line.
	if !strings.Contains(s, "\n") {
		t.Errorf("String() is not multi-line (expected readable JSON): %q", s)
	}
}

func TestFullName_String_Default(t *testing.T) {
	d := full_name.FullName_default()
	if got := d.String(); got != "{}" {
		t.Errorf("String() on default: got %q, want %q", got, "{}")
	}
}

// Serializer dense JSON tests

func TestFullName_Serializer_ToJson_Dense(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	got := s.ToJson(fn)
	// Dense (compact) JSON uses a positional array format.
	want := `["John","Doe"]`
	if got != want {
		t.Errorf("dense json: got %q, want %q", got, want)
	}
}

func TestFullName_Serializer_ToJson_Default(t *testing.T) {
	s := full_name.FullName_serializer()
	got := s.ToJson(full_name.FullName_default())
	// Dense format for an all-default struct is an empty array.
	if got != "[]" {
		t.Errorf("default dense json: got %q, want %q", got, "[]")
	}
}

func TestFullName_Serializer_ToJson_OnlyFirstName(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_partialBuilder().SetFirstName("Only").Build()
	got := s.ToJson(fn)
	// Dense positional array: only non-default trailing fields are omitted.
	want := `["Only"]`
	if got != want {
		t.Errorf("partial json: got %q, want %q", got, want)
	}
}

func TestFullName_Serializer_ToJson_SpecialChars(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_partialBuilder().SetFirstName(`a"b\c`).Build()
	decoded, err := s.FromJson(s.ToJson(fn))
	if err != nil {
		t.Fatalf("FromJson error for special chars: %v", err)
	}
	if decoded.FirstName() != `a"b\c` {
		t.Errorf("special chars round-trip: got %q, want %q", decoded.FirstName(), `a"b\c`)
	}
}

// Serializer readable JSON tests

func TestFullName_Serializer_ToJson_Readable(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	readable := s.ToJson(fn, skir_client.Readable{})
	if !strings.Contains(readable, "first_name") || !strings.Contains(readable, "John") {
		t.Errorf("readable json missing first_name/John: %q", readable)
	}
	if !strings.Contains(readable, "last_name") || !strings.Contains(readable, "Doe") {
		t.Errorf("readable json missing last_name/Doe: %q", readable)
	}
	if !strings.Contains(readable, "\n") {
		t.Errorf("readable json is not multi-line: %q", readable)
	}
}

func TestFullName_Serializer_ToJson_ReadableRoundTrip(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	decoded, err := s.FromJson(s.ToJson(fn, skir_client.Readable{}))
	if err != nil {
		t.Fatalf("FromJson(readable) error: %v", err)
	}
	if decoded.FirstName() != fn.FirstName() || decoded.LastName() != fn.LastName() {
		t.Errorf("readable round-trip: got {%q,%q}, want {%q,%q}",
			decoded.FirstName(), decoded.LastName(), fn.FirstName(), fn.LastName())
	}
}

// Serializer FromJson tests

func TestFullName_Serializer_FromJson(t *testing.T) {
	s := full_name.FullName_serializer()
	fn, err := s.FromJson(`{"first_name":"Jane","last_name":"Smith"}`)
	if err != nil {
		t.Fatalf("FromJson error: %v", err)
	}
	if fn.FirstName() != "Jane" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "Jane")
	}
	if fn.LastName() != "Smith" {
		t.Errorf("LastName: got %q, want %q", fn.LastName(), "Smith")
	}
}

func TestFullName_Serializer_FromJson_EmptyObject(t *testing.T) {
	s := full_name.FullName_serializer()
	fn, err := s.FromJson(`{}`)
	if err != nil {
		t.Fatalf("FromJson({}) error: %v", err)
	}
	if fn.FirstName() != "" || fn.LastName() != "" {
		t.Errorf("expected empty fields, got FirstName=%q LastName=%q", fn.FirstName(), fn.LastName())
	}
}

func TestFullName_Serializer_FromJson_UnrecognizedDropped(t *testing.T) {
	s := full_name.FullName_serializer()
	fn, err := s.FromJson(`{"first_name":"Joan","unknown_field":"ignored"}`)
	if err != nil {
		t.Fatalf("FromJson error: %v", err)
	}
	if fn.FirstName() != "Joan" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "Joan")
	}
	got := s.ToJson(fn)
	if strings.Contains(got, "unknown_field") {
		t.Errorf("re-serialized JSON contains unexpected unknown_field: %q", got)
	}
}

func TestFullName_Serializer_FromJson_KeepUnrecognized(t *testing.T) {
	s := full_name.FullName_serializer()
	// KeepUnrecognizedValues preserves extra positional slots in the dense array
	// format that come from a newer schema version (slot index >= current field count).
	fn, err := s.FromJson(
		`["Joan","Smith","future_value"]`,
		skir_client.KeepUnrecognizedValues{},
	)
	if err != nil {
		t.Fatalf("FromJson(KeepUnrecognized) error: %v", err)
	}
	if fn.FirstName() != "Joan" {
		t.Errorf("FirstName: got %q, want %q", fn.FirstName(), "Joan")
	}
	if fn.LastName() != "Smith" {
		t.Errorf("LastName: got %q, want %q", fn.LastName(), "Smith")
	}
	// Re-serializing in dense mode should include the preserved extra slot.
	got := s.ToJson(fn)
	if !strings.Contains(got, "future_value") {
		t.Errorf("re-serialized dense JSON should contain preserved slot: %q", got)
	}
}

func TestFullName_Serializer_FromJson_InvalidJson(t *testing.T) {
	s := full_name.FullName_serializer()
	_, err := s.FromJson(`not valid json`)
	if err == nil {
		t.Error("expected error for invalid JSON, got nil")
	}
}

func TestFullName_Serializer_FromJson_DenseRoundTrip(t *testing.T) {
	s := full_name.FullName_serializer()
	original := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	j := s.ToJson(original)
	decoded, err := s.FromJson(j)
	if err != nil {
		t.Fatalf("FromJson error: %v", err)
	}
	if s.ToJson(decoded) != j {
		t.Errorf("round-trip JSON not stable: got %q, want %q", s.ToJson(decoded), j)
	}
}

// Serializer binary (bytes) tests

func TestFullName_Serializer_Bytes_MagicPrefix(t *testing.T) {
	s := full_name.FullName_serializer()
	fn := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	b := s.ToBytes(fn)
	if len(b) < 4 || string(b[:4]) != "skir" {
		t.Errorf("bytes should start with \"skir\" magic prefix")
	}
}

func TestFullName_Serializer_Bytes_RoundTrip(t *testing.T) {
	s := full_name.FullName_serializer()
	original := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	decoded, err := s.FromBytes(s.ToBytes(original))
	if err != nil {
		t.Fatalf("FromBytes error: %v", err)
	}
	if decoded.FirstName() != original.FirstName() {
		t.Errorf("round-trip FirstName: got %q, want %q", decoded.FirstName(), original.FirstName())
	}
	if decoded.LastName() != original.LastName() {
		t.Errorf("round-trip LastName: got %q, want %q", decoded.LastName(), original.LastName())
	}
}

func TestFullName_Serializer_Bytes_RoundTrip_Default(t *testing.T) {
	s := full_name.FullName_serializer()
	decoded, err := s.FromBytes(s.ToBytes(full_name.FullName_default()))
	if err != nil {
		t.Fatalf("FromBytes(default) error: %v", err)
	}
	if decoded.FirstName() != "" || decoded.LastName() != "" {
		t.Errorf("expected empty fields after default round-trip, got FirstName=%q LastName=%q",
			decoded.FirstName(), decoded.LastName())
	}
}

func TestFullName_Serializer_Bytes_StableAfterRoundTrip(t *testing.T) {
	s := full_name.FullName_serializer()
	original := full_name.FullName_builder().SetFirstName("John").SetLastName("Doe").Build()
	b1 := s.ToBytes(original)
	decoded, _ := s.FromBytes(b1)
	b2 := s.ToBytes(decoded)
	if string(b1) != string(b2) {
		t.Error("bytes encoding not stable after round-trip")
	}
}

func TestFullName_Serializer_Bytes_KeepUnrecognized(t *testing.T) {
	// Parse a dense JSON with an extra future slot, keep it, then verify the
	// unrecognized data survives a full bytes round-trip by checking that
	// encoding to bytes is stable after decode → re-encode.
	s := full_name.FullName_serializer()
	fn, err := s.FromJson(
		`["Joan","Smith","future_value"]`,
		skir_client.KeepUnrecognizedValues{},
	)
	if err != nil {
		t.Fatalf("FromJson error: %v", err)
	}
	b1 := s.ToBytes(fn)
	decoded, err := s.FromBytes(b1, skir_client.KeepUnrecognizedValues{})
	if err != nil {
		t.Fatalf("FromBytes error: %v", err)
	}
	b2 := s.ToBytes(decoded)
	if string(b1) != string(b2) {
		t.Errorf("bytes not stable after KeepUnrecognized round-trip")
	}
	// The recognized fields must be intact.
	if decoded.FirstName() != "Joan" || decoded.LastName() != "Smith" {
		t.Errorf("recognized fields wrong after round-trip: FirstName=%q LastName=%q",
			decoded.FirstName(), decoded.LastName())
	}
}

// Type descriptor tests

func TestFullName_TypeDescriptor_IsStructDescriptor(t *testing.T) {
	td := full_name.FullName_serializer().TypeDescriptor()
	if _, ok := td.(*skir_client.StructDescriptor); !ok {
		t.Fatalf("TypeDescriptor is %T, want *skir_client.StructDescriptor", td)
	}
}

func TestFullName_TypeDescriptor_Metadata(t *testing.T) {
	sd := full_name.FullName_serializer().TypeDescriptor().(*skir_client.StructDescriptor)

	if got := sd.Name(); got != "FullName" {
		t.Errorf("Name: got %q, want %q", got, "FullName")
	}
	if got := sd.QualifiedName(); got != "FullName" {
		t.Errorf("QualifiedName: got %q, want %q", got, "FullName")
	}
	if got := sd.ModulePath(); got != "full_name.skir" {
		t.Errorf("ModulePath: got %q, want %q", got, "full_name.skir")
	}
	if got := sd.Doc(); got != "A person's full name." {
		t.Errorf("Doc: got %q, want %q", got, "A person's full name.")
	}
}

func TestFullName_TypeDescriptor_Fields(t *testing.T) {
	sd := full_name.FullName_serializer().TypeDescriptor().(*skir_client.StructDescriptor)
	fields := sd.Fields()
	if len(fields) != 2 {
		t.Fatalf("Fields: got %d fields, want 2", len(fields))
	}

	f0 := fields[0]
	if f0.Name() != "first_name" {
		t.Errorf("fields[0].Name: got %q, want %q", f0.Name(), "first_name")
	}
	if f0.Number() != 0 {
		t.Errorf("fields[0].Number: got %d, want 0", f0.Number())
	}
	if f0.Doc() != "The first name." {
		t.Errorf("fields[0].Doc: got %q, want %q", f0.Doc(), "The first name.")
	}
	pd0, ok := f0.Type().(*skir_client.PrimitiveDescriptor)
	if !ok {
		t.Errorf("fields[0].Type() is %T, want *PrimitiveDescriptor", f0.Type())
	} else if pd0.PrimitiveType() != skir_client.PrimitiveTypeString {
		t.Errorf("fields[0] PrimitiveType: got %v, want string", pd0.PrimitiveType())
	}

	f1 := fields[1]
	if f1.Name() != "last_name" {
		t.Errorf("fields[1].Name: got %q, want %q", f1.Name(), "last_name")
	}
	if f1.Number() != 1 {
		t.Errorf("fields[1].Number: got %d, want 1", f1.Number())
	}
	if f1.Doc() != "The last\nname." {
		t.Errorf("fields[1].Doc: got %q, want %q", f1.Doc(), "The last\nname.")
	}
	pd1, ok := f1.Type().(*skir_client.PrimitiveDescriptor)
	if !ok {
		t.Errorf("fields[1].Type() is %T, want *PrimitiveDescriptor", f1.Type())
	} else if pd1.PrimitiveType() != skir_client.PrimitiveTypeString {
		t.Errorf("fields[1] PrimitiveType: got %v, want string", pd1.PrimitiveType())
	}
}

func TestFullName_TypeDescriptor_GetFieldByName(t *testing.T) {
	sd := full_name.FullName_serializer().TypeDescriptor().(*skir_client.StructDescriptor)

	f := sd.FieldByName("first_name")
	if f == nil {
		t.Fatal("FieldByName(\"first_name\"): got nil")
	}
	if f.Number() != 0 {
		t.Errorf("FieldByName(\"first_name\").Number: got %d, want 0", f.Number())
	}
	if sd.FieldByName("nonexistent") != nil {
		t.Error("FieldByName(\"nonexistent\"): expected nil, got non-nil")
	}
}

func TestFullName_TypeDescriptor_GetFieldByNumber(t *testing.T) {
	sd := full_name.FullName_serializer().TypeDescriptor().(*skir_client.StructDescriptor)

	f := sd.FieldByNumber(1)
	if f == nil {
		t.Fatal("FieldByNumber(1): got nil")
	}
	if f.Name() != "last_name" {
		t.Errorf("FieldByNumber(1).Name: got %q, want %q", f.Name(), "last_name")
	}
	if sd.FieldByNumber(99) != nil {
		t.Error("FieldByNumber(99): expected nil, got non-nil")
	}
}

func TestFullName_TypeDescriptor_AsJson(t *testing.T) {
	j := full_name.FullName_serializer().TypeDescriptor().AsJson()
	if !strings.Contains(j, "FullName") {
		t.Errorf("AsJson() missing struct name: %q", j)
	}
	if !strings.Contains(j, "first_name") {
		t.Errorf("AsJson() missing field name first_name: %q", j)
	}
	if !strings.Contains(j, "last_name") {
		t.Errorf("AsJson() missing field name last_name: %q", j)
	}
}
