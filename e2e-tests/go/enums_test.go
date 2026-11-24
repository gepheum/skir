package e2e_test

import (
	"strings"
	"testing"

	enums "e2e-test/skirout/enums"

	skir_client "github.com/gepheum/skir-go-client"
)

// =============================================================================
// Weekday (constants-only enum)
// =============================================================================

func TestWeekday_Default_IsUnknown(t *testing.T) {
	w := enums.Weekday_unknown()
	if w.Kind() != enums.Weekday_kind_unknown {
		t.Errorf("Kind: got %v, want Weekday_kind_unknown", w.Kind())
	}
	if !w.IsUnknown() {
		t.Error("IsUnknown() should be true for unknown")
	}
}

func TestWeekday_Constants_Kind(t *testing.T) {
	cases := []struct {
		w    enums.Weekday
		kind enums.Weekday_kind
		name string
	}{
		{enums.Weekday_fridayConst(), enums.Weekday_kind_fridayConst, "friday"},
		{enums.Weekday_mondayConst(), enums.Weekday_kind_mondayConst, "monday"},
		{enums.Weekday_saturdayConst(), enums.Weekday_kind_saturdayConst, "saturday"},
		{enums.Weekday_sundayConst(), enums.Weekday_kind_sundayConst, "sunday"},
		{enums.Weekday_thursdayConst(), enums.Weekday_kind_thursdayConst, "thursday"},
		{enums.Weekday_tuesdayConst(), enums.Weekday_kind_tuesdayConst, "tuesday"},
		{enums.Weekday_wednesdayConst(), enums.Weekday_kind_wednesdayConst, "wednesday"},
	}
	for _, c := range cases {
		if c.w.Kind() != c.kind {
			t.Errorf("%s: Kind()=%v, want %v", c.name, c.w.Kind(), c.kind)
		}
		if c.w.IsUnknown() {
			t.Errorf("%s: IsUnknown() should be false", c.name)
		}
	}
}

func TestWeekday_Predicates_OnlyMatchSelf(t *testing.T) {
	monday := enums.Weekday_mondayConst()
	if !monday.IsMondayConst() {
		t.Error("IsMondayConst() should be true")
	}
	if monday.IsFridayConst() || monday.IsSaturdayConst() || monday.IsSundayConst() ||
		monday.IsThursdayConst() || monday.IsTuesdayConst() || monday.IsWednesdayConst() {
		t.Error("only IsMondayConst() should be true for mondayConst")
	}

	friday := enums.Weekday_fridayConst()
	if !friday.IsFridayConst() {
		t.Error("IsFridayConst() should be true")
	}
	if friday.IsMondayConst() {
		t.Error("IsMondayConst() should be false for fridayConst")
	}
}

func TestWeekday_String(t *testing.T) {
	if got := enums.Weekday_mondayConst().String(); got != `"monday"` {
		t.Errorf("String(): got %q, want %q", got, `"monday"`)
	}
	if got := enums.Weekday_unknown().String(); got != `"unknown"` {
		t.Errorf("String() for unknown: got %q, want %q", got, `"unknown"`)
	}
}

func TestWeekday_Serializer_ToJson_Dense(t *testing.T) {
	s := enums.Weekday_serializer()

	// MONDAY has binary field number 1
	if got := s.ToJson(enums.Weekday_mondayConst()); got != "1" {
		t.Errorf("MONDAY dense: got %q, want %q", got, "1")
	}
	// TUESDAY has binary field number 2
	if got := s.ToJson(enums.Weekday_tuesdayConst()); got != "2" {
		t.Errorf("TUESDAY dense: got %q, want %q", got, "2")
	}
	// unknown = 0
	if got := s.ToJson(enums.Weekday_unknown()); got != "0" {
		t.Errorf("unknown dense: got %q, want %q", got, "0")
	}
}

func TestWeekday_Serializer_ToJson_Readable(t *testing.T) {
	s := enums.Weekday_serializer()
	if got := s.ToJson(enums.Weekday_mondayConst(), skir_client.Readable{}); got != `"monday"` {
		t.Errorf("MONDAY readable: got %q, want %q", got, `"monday"`)
	}
	if got := s.ToJson(enums.Weekday_fridayConst(), skir_client.Readable{}); got != `"friday"` {
		t.Errorf("FRIDAY readable: got %q, want %q", got, `"friday"`)
	}
}

func TestWeekday_Serializer_FromJson_Dense(t *testing.T) {
	s := enums.Weekday_serializer()
	w, err := s.FromJson("1")
	if err != nil {
		t.Fatalf("FromJson(1) error: %v", err)
	}
	if !w.IsMondayConst() {
		t.Errorf("FromJson(1) should be MONDAY, got kind=%v", w.Kind())
	}
}

func TestWeekday_Serializer_FromJson_Readable(t *testing.T) {
	s := enums.Weekday_serializer()
	w, err := s.FromJson(`"wednesday"`)
	if err != nil {
		t.Fatalf("FromJson(wednesday) error: %v", err)
	}
	if !w.IsWednesdayConst() {
		t.Errorf("FromJson(wednesday): got kind=%v, want wednesdayConst", w.Kind())
	}
}

func TestWeekday_Serializer_RoundTrip(t *testing.T) {
	s := enums.Weekday_serializer()
	for _, w := range []enums.Weekday{
		enums.Weekday_mondayConst(),
		enums.Weekday_fridayConst(),
		enums.Weekday_saturdayConst(),
	} {
		decoded, err := s.FromJson(s.ToJson(w))
		if err != nil {
			t.Fatalf("dense round-trip error for %v: %v", w, err)
		}
		if decoded.Kind() != w.Kind() {
			t.Errorf("dense round-trip: got kind=%v, want %v", decoded.Kind(), w.Kind())
		}
	}
}

func TestWeekday_Serializer_ToBytes_FromBytes(t *testing.T) {
	s := enums.Weekday_serializer()
	original := enums.Weekday_mondayConst()
	b := s.ToBytes(original)
	decoded, err := s.FromBytes(b)
	if err != nil {
		t.Fatalf("FromBytes error: %v", err)
	}
	if !decoded.IsMondayConst() {
		t.Errorf("bytes round-trip: got kind=%v, want mondayConst", decoded.Kind())
	}
}

func TestWeekday_Accept_DispatchesToCorrectMethod(t *testing.T) {
	called := ""

	visitor := &weekdayTestVisitor{
		onMonday:    func() { called = "monday" },
		onFriday:    func() { called = "friday" },
		onUnknown:   func() { called = "unknown" },
		onSaturday:  func() { called = "saturday" },
		onSunday:    func() { called = "sunday" },
		onThursday:  func() { called = "thursday" },
		onTuesday:   func() { called = "tuesday" },
		onWednesday: func() { called = "wednesday" },
	}

	enums.Weekday_accept(enums.Weekday_mondayConst(), visitor)
	if called != "monday" {
		t.Errorf("accept monday: called %q, want monday", called)
	}

	enums.Weekday_accept(enums.Weekday_fridayConst(), visitor)
	if called != "friday" {
		t.Errorf("accept friday: called %q, want friday", called)
	}

	enums.Weekday_accept(enums.Weekday_unknown(), visitor)
	if called != "unknown" {
		t.Errorf("accept unknown: called %q, want unknown", called)
	}

	enums.Weekday_accept(enums.Weekday_wednesdayConst(), visitor)
	if called != "wednesday" {
		t.Errorf("accept wednesday: called %q, want wednesday", called)
	}
}

func TestWeekday_Accept_ReturnsValue(t *testing.T) {
	got := enums.Weekday_accept(enums.Weekday_tuesdayConst(), &weekdayNameVisitor{})
	if got != "tuesday" {
		t.Errorf("accept return: got %q, want tuesday", got)
	}
	got = enums.Weekday_accept(enums.Weekday_unknown(), &weekdayNameVisitor{})
	if got != "unknown" {
		t.Errorf("accept unknown return: got %q, want unknown", got)
	}
}

// helpers for Weekday visitor tests

type weekdayTestVisitor struct {
	onUnknown   func()
	onFriday    func()
	onMonday    func()
	onSaturday  func()
	onSunday    func()
	onThursday  func()
	onTuesday   func()
	onWednesday func()
}

func (v *weekdayTestVisitor) OnUnknown() struct{}        { v.onUnknown(); return struct{}{} }
func (v *weekdayTestVisitor) OnFridayConst() struct{}    { v.onFriday(); return struct{}{} }
func (v *weekdayTestVisitor) OnMondayConst() struct{}    { v.onMonday(); return struct{}{} }
func (v *weekdayTestVisitor) OnSaturdayConst() struct{}  { v.onSaturday(); return struct{}{} }
func (v *weekdayTestVisitor) OnSundayConst() struct{}    { v.onSunday(); return struct{}{} }
func (v *weekdayTestVisitor) OnThursdayConst() struct{}  { v.onThursday(); return struct{}{} }
func (v *weekdayTestVisitor) OnTuesdayConst() struct{}   { v.onTuesday(); return struct{}{} }
func (v *weekdayTestVisitor) OnWednesdayConst() struct{} { v.onWednesday(); return struct{}{} }

type weekdayNameVisitor struct{}

func (v *weekdayNameVisitor) OnUnknown() string        { return "unknown" }
func (v *weekdayNameVisitor) OnFridayConst() string    { return "friday" }
func (v *weekdayNameVisitor) OnMondayConst() string    { return "monday" }
func (v *weekdayNameVisitor) OnSaturdayConst() string  { return "saturday" }
func (v *weekdayNameVisitor) OnSundayConst() string    { return "sunday" }
func (v *weekdayNameVisitor) OnThursdayConst() string  { return "thursday" }
func (v *weekdayNameVisitor) OnTuesdayConst() string   { return "tuesday" }
func (v *weekdayNameVisitor) OnWednesdayConst() string { return "wednesday" }

// =============================================================================
// JsonValue (enum with nullConst + 5 wrappers)
// =============================================================================

func TestJsonValue_Default_IsUnknown(t *testing.T) {
	jv := enums.JsonValue_unknown()
	if jv.Kind() != enums.JsonValue_kind_unknown {
		t.Errorf("Kind: got %v, want unknown", jv.Kind())
	}
	if !jv.IsUnknown() {
		t.Error("IsUnknown() should be true")
	}
}

func TestJsonValue_NullConst(t *testing.T) {
	jv := enums.JsonValue_nullConst()
	if jv.Kind() != enums.JsonValue_kind_nullConst {
		t.Errorf("Kind: got %v, want nullConst", jv.Kind())
	}
	if !jv.IsNullConst() {
		t.Error("IsNullConst() should be true")
	}
	if jv.IsUnknown() || jv.IsStringWrapper() || jv.IsBooleanWrapper() {
		t.Error("only IsNullConst() should be true")
	}
}

func TestJsonValue_StringWrapper(t *testing.T) {
	jv := enums.JsonValue_stringWrapper("hello")
	if jv.Kind() != enums.JsonValue_kind_stringWrapper {
		t.Errorf("Kind: got %v, want stringWrapper", jv.Kind())
	}
	if !jv.IsStringWrapper() {
		t.Error("IsStringWrapper() should be true")
	}
	if jv.UnwrapString() != "hello" {
		t.Errorf("UnwrapString(): got %q, want %q", jv.UnwrapString(), "hello")
	}
	if jv.IsNullConst() || jv.IsBooleanWrapper() || jv.IsArrayWrapper() {
		t.Error("only IsStringWrapper() should be true")
	}
}

func TestJsonValue_BooleanWrapper(t *testing.T) {
	jvTrue := enums.JsonValue_booleanWrapper(true)
	if !jvTrue.IsBooleanWrapper() {
		t.Error("IsBooleanWrapper() should be true")
	}
	if jvTrue.UnwrapBoolean() != true {
		t.Errorf("UnwrapBoolean(): got %v, want true", jvTrue.UnwrapBoolean())
	}

	jvFalse := enums.JsonValue_booleanWrapper(false)
	if jvFalse.UnwrapBoolean() != false {
		t.Errorf("UnwrapBoolean(): got %v, want false", jvFalse.UnwrapBoolean())
	}
}

func TestJsonValue_NumberWrapper(t *testing.T) {
	jv := enums.JsonValue_numberWrapper(3.14)
	if !jv.IsNumberWrapper() {
		t.Error("IsNumberWrapper() should be true")
	}
	if jv.UnwrapNumber() != 3.14 {
		t.Errorf("UnwrapNumber(): got %v, want 3.14", jv.UnwrapNumber())
	}
}

func TestJsonValue_ArrayWrapper(t *testing.T) {
	arr := skir_client.ArrayFromSlice([]enums.JsonValue{
		enums.JsonValue_stringWrapper("a"),
		enums.JsonValue_booleanWrapper(true),
	})
	jv := enums.JsonValue_arrayWrapper(arr)
	if !jv.IsArrayWrapper() {
		t.Error("IsArrayWrapper() should be true")
	}
	got := jv.UnwrapArray()
	if got.Len() != 2 {
		t.Errorf("UnwrapArray length: got %d, want 2", got.Len())
	}
	if !got.At(0).IsStringWrapper() || got.At(0).UnwrapString() != "a" {
		t.Errorf("array[0]: expected stringWrapper(a)")
	}
	if !got.At(1).IsBooleanWrapper() || got.At(1).UnwrapBoolean() != true {
		t.Errorf("array[1]: expected booleanWrapper(true)")
	}
}

func TestJsonValue_ObjectWrapper(t *testing.T) {
	pair := enums.JsonValue_Pair_builder().
		SetName("key").
		SetValue(enums.JsonValue_stringWrapper("val")).
		Build()
	obj := skir_client.ArrayFromSlice([]enums.JsonValue_Pair{pair})
	jv := enums.JsonValue_objectWrapper(obj)
	if !jv.IsObjectWrapper() {
		t.Error("IsObjectWrapper() should be true")
	}
	pairs := jv.UnwrapObject()
	if pairs.Len() != 1 {
		t.Errorf("UnwrapObject length: got %d, want 1", pairs.Len())
	}
	if pairs.At(0).Name() != "key" {
		t.Errorf("pair Name: got %q, want %q", pairs.At(0).Name(), "key")
	}
	if !pairs.At(0).Value().IsStringWrapper() {
		t.Error("pair Value should be stringWrapper")
	}
}

func TestJsonValue_UnwrapPanicsOnWrongKind(t *testing.T) {
	jv := enums.JsonValue_stringWrapper("x")

	assertPanics(t, "UnwrapArray on stringWrapper", func() { jv.UnwrapArray() })
	assertPanics(t, "UnwrapBoolean on stringWrapper", func() { jv.UnwrapBoolean() })
	assertPanics(t, "UnwrapNumber on stringWrapper", func() { jv.UnwrapNumber() })
	assertPanics(t, "UnwrapObject on stringWrapper", func() { jv.UnwrapObject() })

	jv2 := enums.JsonValue_booleanWrapper(true)
	assertPanics(t, "UnwrapString on booleanWrapper", func() { jv2.UnwrapString() })
}

func TestJsonValue_Serializer_Dense(t *testing.T) {
	s := enums.JsonValue_serializer()

	// NULL constant has binary field 1
	if got := s.ToJson(enums.JsonValue_nullConst()); got != "1" {
		t.Errorf("nullConst dense: got %q, want %q", got, "1")
	}
	// string wrapper has binary field 3
	if got := s.ToJson(enums.JsonValue_stringWrapper("hello")); got != `[3,"hello"]` {
		t.Errorf("stringWrapper dense: got %q, want %q", got, `[3,"hello"]`)
	}
	// boolean wrapper has binary field 100; true encodes as 1
	if got := s.ToJson(enums.JsonValue_booleanWrapper(true)); got != "[100,1]" {
		t.Errorf("booleanWrapper(true) dense: got %q, want %q", got, "[100,1]")
	}
}

func TestJsonValue_Serializer_Readable(t *testing.T) {
	s := enums.JsonValue_serializer()

	// NULL constant
	if got := s.ToJson(enums.JsonValue_nullConst(), skir_client.Readable{}); got != `"null"` {
		t.Errorf("nullConst readable: got %q, want %q", got, `"null"`)
	}
	// unknown
	if got := s.ToJson(enums.JsonValue_unknown(), skir_client.Readable{}); got != `"unknown"` {
		t.Errorf("unknown readable: got %q, want %q", got, `"unknown"`)
	}
	// string wrapper
	readable := s.ToJson(enums.JsonValue_stringWrapper("hello"), skir_client.Readable{})
	if !strings.Contains(readable, `"string"`) || !strings.Contains(readable, `"hello"`) {
		t.Errorf("stringWrapper readable: %q missing expected content", readable)
	}
}

func TestJsonValue_Serializer_RoundTrip(t *testing.T) {
	s := enums.JsonValue_serializer()

	cases := []enums.JsonValue{
		enums.JsonValue_unknown(),
		enums.JsonValue_nullConst(),
		enums.JsonValue_stringWrapper("hello"),
		enums.JsonValue_booleanWrapper(false),
		enums.JsonValue_numberWrapper(42.5),
	}
	for _, jv := range cases {
		decoded, err := s.FromJson(s.ToJson(jv))
		if err != nil {
			t.Fatalf("dense round-trip error: %v", err)
		}
		if decoded.Kind() != jv.Kind() {
			t.Errorf("dense round-trip kind: got %v, want %v", decoded.Kind(), jv.Kind())
		}
	}
}

func TestJsonValue_Serializer_Bytes_RoundTrip(t *testing.T) {
	s := enums.JsonValue_serializer()
	jv := enums.JsonValue_stringWrapper("world")
	b := s.ToBytes(jv)
	decoded, err := s.FromBytes(b)
	if err != nil {
		t.Fatalf("FromBytes error: %v", err)
	}
	if !decoded.IsStringWrapper() || decoded.UnwrapString() != "world" {
		t.Errorf("bytes round-trip: got %v", decoded)
	}
}

func TestJsonValue_Accept(t *testing.T) {
	v := &jsonValueNameVisitor{}

	if got := enums.JsonValue_accept(enums.JsonValue_unknown(), v); got != "unknown" {
		t.Errorf("accept unknown: got %q, want unknown", got)
	}
	if got := enums.JsonValue_accept(enums.JsonValue_nullConst(), v); got != "null" {
		t.Errorf("accept null: got %q, want null", got)
	}
	if got := enums.JsonValue_accept(enums.JsonValue_stringWrapper("x"), v); got != "string" {
		t.Errorf("accept string: got %q, want string", got)
	}
	if got := enums.JsonValue_accept(enums.JsonValue_booleanWrapper(true), v); got != "boolean" {
		t.Errorf("accept boolean: got %q, want boolean", got)
	}
	if got := enums.JsonValue_accept(enums.JsonValue_numberWrapper(1), v); got != "number" {
		t.Errorf("accept number: got %q, want number", got)
	}
}

type jsonValueNameVisitor struct{}

func (v *jsonValueNameVisitor) OnUnknown() string   { return "unknown" }
func (v *jsonValueNameVisitor) OnNullConst() string { return "null" }
func (v *jsonValueNameVisitor) OnArrayWrapper(a skir_client.Array[enums.JsonValue]) string {
	return "array"
}
func (v *jsonValueNameVisitor) OnBooleanWrapper(b bool) string   { return "boolean" }
func (v *jsonValueNameVisitor) OnNumberWrapper(n float64) string { return "number" }
func (v *jsonValueNameVisitor) OnObjectWrapper(o skir_client.Array[enums.JsonValue_Pair]) string {
	return "object"
}
func (v *jsonValueNameVisitor) OnStringWrapper(s string) string { return "string" }

// =============================================================================
// JsonValue_Pair (struct nested inside JsonValue)
// =============================================================================

func TestJsonValuePair_Builder(t *testing.T) {
	pair := enums.JsonValue_Pair_builder().
		SetName("foo").
		SetValue(enums.JsonValue_booleanWrapper(true)).
		Build()
	if pair.Name() != "foo" {
		t.Errorf("Name: got %q, want foo", pair.Name())
	}
	if !pair.Value().IsBooleanWrapper() {
		t.Error("Value should be booleanWrapper")
	}
}

func TestJsonValuePair_PartialBuilder(t *testing.T) {
	pair := enums.JsonValue_Pair_partialBuilder().
		SetName("bar").
		Build()
	if pair.Name() != "bar" {
		t.Errorf("Name: got %q, want bar", pair.Name())
	}
	if !pair.Value().IsUnknown() {
		t.Error("default Value should be unknown")
	}
}

func TestJsonValuePair_Default(t *testing.T) {
	d := enums.JsonValue_Pair_default()
	if d.Name() != "" {
		t.Errorf("default Name: got %q, want empty", d.Name())
	}
	if !d.Value().IsUnknown() {
		t.Error("default Value should be unknown")
	}
}

// =============================================================================
// Status (ok constant + error wrapper with struct)
// =============================================================================

func TestStatus_Default_IsUnknown(t *testing.T) {
	s := enums.Status_unknown()
	if !s.IsUnknown() {
		t.Error("Status_unknown() should be unknown")
	}
}

func TestStatus_OkConst(t *testing.T) {
	s := enums.Status_okConst()
	if !s.IsOkConst() {
		t.Error("IsOkConst() should be true")
	}
	if s.IsUnknown() || s.IsErrorWrapper() {
		t.Error("only IsOkConst() should be true")
	}
}

func TestStatus_ErrorWrapper(t *testing.T) {
	err := enums.Status_Error_builder().SetCode(500).SetMessage("internal error").Build()
	s := enums.Status_errorWrapper(err)

	if !s.IsErrorWrapper() {
		t.Error("IsErrorWrapper() should be true")
	}
	if s.IsOkConst() || s.IsUnknown() {
		t.Error("only IsErrorWrapper() should be true")
	}

	e := s.UnwrapError()
	if e.Code() != 500 {
		t.Errorf("Code: got %d, want 500", e.Code())
	}
	if e.Message() != "internal error" {
		t.Errorf("Message: got %q, want %q", e.Message(), "internal error")
	}
}

func TestStatus_UnwrapError_PanicsOnWrongKind(t *testing.T) {
	assertPanics(t, "UnwrapError on ok", func() { enums.Status_okConst().UnwrapError() })
	assertPanics(t, "UnwrapError on unknown", func() { enums.Status_unknown().UnwrapError() })
}

func TestStatus_String(t *testing.T) {
	if got := enums.Status_okConst().String(); got != `"ok"` {
		t.Errorf("String() for ok: got %q, want %q", got, `"ok"`)
	}
	s := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(1).SetMessage("err").Build(),
	)
	str := s.String()
	if !strings.Contains(str, "error") {
		t.Errorf("String() for error: %q missing 'error'", str)
	}
}

func TestStatus_Serializer_Dense(t *testing.T) {
	s := enums.Status_serializer()

	// ok has binary field 1
	if got := s.ToJson(enums.Status_okConst()); got != "1" {
		t.Errorf("ok dense: got %q, want %q", got, "1")
	}
	// error wrapper has binary field 4; Status_Error is a struct encoded as positional array
	errStatus := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(404).SetMessage("not found").Build(),
	)
	if got := s.ToJson(errStatus); got != `[4,[404,"not found"]]` {
		t.Errorf("error dense: got %q, want %q", got, `[4,[404,"not found"]]`)
	}
}

func TestStatus_Serializer_Readable(t *testing.T) {
	s := enums.Status_serializer()

	if got := s.ToJson(enums.Status_okConst(), skir_client.Readable{}); got != `"ok"` {
		t.Errorf("ok readable: got %q, want %q", got, `"ok"`)
	}
	errStatus := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(404).SetMessage("not found").Build(),
	)
	readable := s.ToJson(errStatus, skir_client.Readable{})
	if !strings.Contains(readable, "error") {
		t.Errorf("error readable: %q missing 'error'", readable)
	}
	if !strings.Contains(readable, "404") {
		t.Errorf("error readable: %q missing '404'", readable)
	}
}

func TestStatus_Serializer_RoundTrip(t *testing.T) {
	s := enums.Status_serializer()

	errStatus := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(403).SetMessage("forbidden").Build(),
	)
	decoded, err := s.FromJson(s.ToJson(errStatus))
	if err != nil {
		t.Fatalf("round-trip error: %v", err)
	}
	if !decoded.IsErrorWrapper() {
		t.Fatalf("round-trip: expected errorWrapper, got kind=%v", decoded.Kind())
	}
	if decoded.UnwrapError().Code() != 403 {
		t.Errorf("Code: got %d, want 403", decoded.UnwrapError().Code())
	}
	if decoded.UnwrapError().Message() != "forbidden" {
		t.Errorf("Message: got %q, want forbidden", decoded.UnwrapError().Message())
	}
}

func TestStatus_Serializer_Bytes_RoundTrip(t *testing.T) {
	s := enums.Status_serializer()
	errStatus := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(404).SetMessage("not found").Build(),
	)
	b := s.ToBytes(errStatus)
	decoded, err := s.FromBytes(b)
	if err != nil {
		t.Fatalf("FromBytes error: %v", err)
	}
	if !decoded.IsErrorWrapper() {
		t.Fatalf("bytes round-trip: expected errorWrapper")
	}
	if decoded.UnwrapError().Code() != 404 || decoded.UnwrapError().Message() != "not found" {
		t.Errorf("bytes round-trip mismatch: code=%d msg=%q", decoded.UnwrapError().Code(), decoded.UnwrapError().Message())
	}
}

func TestStatus_Accept(t *testing.T) {
	v := &statusNameVisitor{}

	if got := enums.Status_accept(enums.Status_unknown(), v); got != "unknown" {
		t.Errorf("accept unknown: got %q", got)
	}
	if got := enums.Status_accept(enums.Status_okConst(), v); got != "ok" {
		t.Errorf("accept ok: got %q", got)
	}
	errStatus := enums.Status_errorWrapper(
		enums.Status_Error_builder().SetCode(0).SetMessage("").Build(),
	)
	if got := enums.Status_accept(errStatus, v); got != "error" {
		t.Errorf("accept error: got %q", got)
	}
}

type statusNameVisitor struct{}

func (v *statusNameVisitor) OnUnknown() string                          { return "unknown" }
func (v *statusNameVisitor) OnOkConst() string                          { return "ok" }
func (v *statusNameVisitor) OnErrorWrapper(e enums.Status_Error) string { return "error" }

// =============================================================================
// Status_Error (struct nested inside Status)
// =============================================================================

func TestStatusError_Builder(t *testing.T) {
	e := enums.Status_Error_builder().SetCode(200).SetMessage("ok").Build()
	if e.Code() != 200 {
		t.Errorf("Code: got %d, want 200", e.Code())
	}
	if e.Message() != "ok" {
		t.Errorf("Message: got %q, want ok", e.Message())
	}
}

func TestStatusError_PartialBuilder(t *testing.T) {
	e := enums.Status_Error_partialBuilder().SetCode(42).Build()
	if e.Code() != 42 {
		t.Errorf("Code: got %d, want 42", e.Code())
	}
	if e.Message() != "" {
		t.Errorf("Message: got %q, want empty", e.Message())
	}
}

func TestStatusError_Default(t *testing.T) {
	d := enums.Status_Error_default()
	if d.Code() != 0 || d.Message() != "" {
		t.Errorf("default: Code=%d Message=%q", d.Code(), d.Message())
	}
}

func TestStatusError_ToBuilder(t *testing.T) {
	original := enums.Status_Error_builder().SetCode(100).SetMessage("continue").Build()
	modified := original.ToBuilder().SetCode(200).Build()
	if modified.Code() != 200 {
		t.Errorf("ToBuilder Code: got %d, want 200", modified.Code())
	}
	if modified.Message() != "continue" {
		t.Errorf("ToBuilder Message: got %q, want continue", modified.Message())
	}
}

// =============================================================================
// EmptyEnum
// =============================================================================

func TestEmptyEnum_Default_IsUnknown(t *testing.T) {
	e := enums.EmptyEnum_unknown()
	if !e.IsUnknown() {
		t.Error("IsUnknown() should be true")
	}
	if e.Kind() != enums.EmptyEnum_kind_unknown {
		t.Errorf("Kind: got %v, want unknown", e.Kind())
	}
}

func TestEmptyEnum_Accept(t *testing.T) {
	called := false
	enums.EmptyEnum_accept(enums.EmptyEnum_unknown(), &emptyEnumVisitor{
		onUnknown: func() { called = true },
	})
	if !called {
		t.Error("OnUnknown should be called for unknown EmptyEnum")
	}
}

func TestEmptyEnum_Serializer(t *testing.T) {
	s := enums.EmptyEnum_serializer()
	e := enums.EmptyEnum_unknown()
	decoded, err := s.FromJson(s.ToJson(e))
	if err != nil {
		t.Fatalf("round-trip error: %v", err)
	}
	if !decoded.IsUnknown() {
		t.Errorf("round-trip: expected unknown")
	}
}

type emptyEnumVisitor struct {
	onUnknown func()
}

func (v *emptyEnumVisitor) OnUnknown() struct{} { v.onUnknown(); return struct{}{} }

// =============================================================================
// EnumWithNameConflict (serializerConst + ifWrapper)
// =============================================================================

func TestEnumWithNameConflict_SerializerConst(t *testing.T) {
	e := enums.EnumWithNameConflict_serializerConst()
	if !e.IsSerializerConst() {
		t.Error("IsSerializerConst() should be true")
	}
	if e.IsUnknown() || e.IsIfWrapper() {
		t.Error("only IsSerializerConst() should be true")
	}
	// serializer has binary field 1
	if got := enums.EnumWithNameConflict_serializer().ToJson(e); got != "1" {
		t.Errorf("serializerConst dense: got %q, want %q", got, "1")
	}
	if got := enums.EnumWithNameConflict_serializer().ToJson(e, skir_client.Readable{}); got != `"serializer"` {
		t.Errorf("serializerConst readable: got %q, want %q", got, `"serializer"`)
	}
}

func TestEnumWithNameConflict_IfWrapper(t *testing.T) {
	e := enums.EnumWithNameConflict_ifWrapper(true)
	if !e.IsIfWrapper() {
		t.Error("IsIfWrapper() should be true")
	}
	if e.UnwrapIf() != true {
		t.Error("UnwrapIf() should return true")
	}

	eFalse := enums.EnumWithNameConflict_ifWrapper(false)
	if eFalse.UnwrapIf() != false {
		t.Error("UnwrapIf() should return false")
	}
}

func TestEnumWithNameConflict_UnwrapIf_PanicsOnWrongKind(t *testing.T) {
	assertPanics(t, "UnwrapIf on serializerConst", func() {
		enums.EnumWithNameConflict_serializerConst().UnwrapIf()
	})
}

func TestEnumWithNameConflict_Accept(t *testing.T) {
	v := &enumWithNameConflictVisitor{}

	if got := enums.EnumWithNameConflict_accept(enums.EnumWithNameConflict_unknown(), v); got != "unknown" {
		t.Errorf("accept unknown: got %q", got)
	}
	if got := enums.EnumWithNameConflict_accept(enums.EnumWithNameConflict_serializerConst(), v); got != "serializer" {
		t.Errorf("accept serializer: got %q", got)
	}
	if got := enums.EnumWithNameConflict_accept(enums.EnumWithNameConflict_ifWrapper(true), v); got != "if:true" {
		t.Errorf("accept if(true): got %q", got)
	}
}

type enumWithNameConflictVisitor struct{}

func (v *enumWithNameConflictVisitor) OnUnknown() string         { return "unknown" }
func (v *enumWithNameConflictVisitor) OnSerializerConst() string { return "serializer" }
func (v *enumWithNameConflictVisitor) OnIfWrapper(b bool) string {
	if b {
		return "if:true"
	}
	return "if:false"
}

// =============================================================================
// EnumWithStructField (sWrapper with S{x,y} struct)
// =============================================================================

func TestEnumWithStructField_SWrapper(t *testing.T) {
	s := enums.EnumWithStructField_S_builder().SetX(1.5).SetY(2.5).Build()
	e := enums.EnumWithStructField_sWrapper(s)

	if !e.IsSWrapper() {
		t.Error("IsSWrapper() should be true")
	}
	if e.IsUnknown() {
		t.Error("IsUnknown() should be false")
	}
	got := e.UnwrapS()
	if got.X() != 1.5 {
		t.Errorf("X: got %v, want 1.5", got.X())
	}
	if got.Y() != 2.5 {
		t.Errorf("Y: got %v, want 2.5", got.Y())
	}
}

func TestEnumWithStructField_UnwrapS_PanicsOnWrongKind(t *testing.T) {
	assertPanics(t, "UnwrapS on unknown", func() {
		enums.EnumWithStructField_unknown().UnwrapS()
	})
}

func TestEnumWithStructField_Serializer_RoundTrip(t *testing.T) {
	s := enums.EnumWithStructField_S_builder().SetX(3.0).SetY(4.0).Build()
	e := enums.EnumWithStructField_sWrapper(s)
	ser := enums.EnumWithStructField_serializer()

	decoded, err := ser.FromJson(ser.ToJson(e))
	if err != nil {
		t.Fatalf("round-trip error: %v", err)
	}
	if !decoded.IsSWrapper() {
		t.Fatalf("round-trip: expected sWrapper")
	}
	if decoded.UnwrapS().X() != 3.0 || decoded.UnwrapS().Y() != 4.0 {
		t.Errorf("round-trip S: X=%v Y=%v", decoded.UnwrapS().X(), decoded.UnwrapS().Y())
	}
}

func TestEnumWithStructField_Accept(t *testing.T) {
	v := &enumWithStructFieldVisitor{}

	if got := enums.EnumWithStructField_accept(enums.EnumWithStructField_unknown(), v); got != "unknown" {
		t.Errorf("accept unknown: got %q", got)
	}
	s := enums.EnumWithStructField_S_builder().SetX(0).SetY(0).Build()
	if got := enums.EnumWithStructField_accept(enums.EnumWithStructField_sWrapper(s), v); got != "s" {
		t.Errorf("accept s: got %q", got)
	}
}

type enumWithStructFieldVisitor struct{}

func (v *enumWithStructFieldVisitor) OnUnknown() string                               { return "unknown" }
func (v *enumWithStructFieldVisitor) OnSWrapper(s enums.EnumWithStructField_S) string { return "s" }

// =============================================================================
// Kind (constants: BAR, FOO + wrappers: createOption, kind, wrapOption)
// =============================================================================

func TestKind_Constants(t *testing.T) {
	foo := enums.Kind_fooConst()
	if !foo.IsFooConst() {
		t.Error("IsFooConst() should be true")
	}
	if foo.IsBarConst() || foo.IsUnknown() {
		t.Error("only IsFooConst() should be true")
	}

	bar := enums.Kind_barConst()
	if !bar.IsBarConst() {
		t.Error("IsBarConst() should be true")
	}
}

func TestKind_Constants_Dense(t *testing.T) {
	s := enums.Kind_serializer()
	// FOO has binary field 1
	if got := s.ToJson(enums.Kind_fooConst()); got != "1" {
		t.Errorf("FOO dense: got %q, want %q", got, "1")
	}
	// BAR has binary field 2
	if got := s.ToJson(enums.Kind_barConst()); got != "2" {
		t.Errorf("BAR dense: got %q, want %q", got, "2")
	}
}

func TestKind_KindWrapper(t *testing.T) {
	inner := enums.Kind_Kind_kindWrapper(true)
	k := enums.Kind_kindWrapper(inner)

	if !k.IsKindWrapper() {
		t.Error("IsKindWrapper() should be true")
	}
	if k.UnwrapKind().IsUnknown() {
		t.Error("inner Kind_Kind should not be unknown")
	}
	if !k.UnwrapKind().IsKindWrapper() {
		t.Error("inner Kind_Kind should be kindWrapper")
	}
	if k.UnwrapKind().UnwrapKind() != true {
		t.Error("inner Kind_Kind value should be true")
	}
}

func TestKind_WrapOptionWrapper(t *testing.T) {
	opt := enums.Kind_WrapOption_builder().Build()
	k := enums.Kind_wrapOptionWrapper(opt)

	if !k.IsWrapOptionWrapper() {
		t.Error("IsWrapOptionWrapper() should be true")
	}
	if k.IsKindWrapper() || k.IsFooConst() {
		t.Error("only IsWrapOptionWrapper() should be true")
	}
	_ = k.UnwrapWrapOption()
}

func TestKind_CreateOptionWrapper(t *testing.T) {
	opt := enums.Kind_WrapOption_builder().Build()
	k := enums.Kind_createOptionWrapper(opt)

	if !k.IsCreateOptionWrapper() {
		t.Error("IsCreateOptionWrapper() should be true")
	}
	_ = k.UnwrapCreateOption()
}

func TestKind_UnwrapPanicsOnWrongKind(t *testing.T) {
	foo := enums.Kind_fooConst()
	assertPanics(t, "UnwrapKind on fooConst", func() { foo.UnwrapKind() })
	assertPanics(t, "UnwrapWrapOption on fooConst", func() { foo.UnwrapWrapOption() })
	assertPanics(t, "UnwrapCreateOption on fooConst", func() { foo.UnwrapCreateOption() })
}

func TestKind_Accept(t *testing.T) {
	v := &kindNameVisitor{}

	if got := enums.Kind_accept(enums.Kind_unknown(), v); got != "unknown" {
		t.Errorf("accept unknown: got %q", got)
	}
	if got := enums.Kind_accept(enums.Kind_fooConst(), v); got != "foo" {
		t.Errorf("accept foo: got %q", got)
	}
	if got := enums.Kind_accept(enums.Kind_barConst(), v); got != "bar" {
		t.Errorf("accept bar: got %q", got)
	}
	inner := enums.Kind_Kind_kindWrapper(false)
	if got := enums.Kind_accept(enums.Kind_kindWrapper(inner), v); got != "kind" {
		t.Errorf("accept kind: got %q", got)
	}
}

type kindNameVisitor struct{}

func (v *kindNameVisitor) OnUnknown() string  { return "unknown" }
func (v *kindNameVisitor) OnBarConst() string { return "bar" }
func (v *kindNameVisitor) OnFooConst() string { return "foo" }
func (v *kindNameVisitor) OnCreateOptionWrapper(o enums.Kind_WrapOption) string {
	return "createOption"
}
func (v *kindNameVisitor) OnKindWrapper(k enums.Kind_Kind) string             { return "kind" }
func (v *kindNameVisitor) OnWrapOptionWrapper(o enums.Kind_WrapOption) string { return "wrapOption" }

// =============================================================================
// Kind_Kind (enum wrapping a bool under "kind")
// =============================================================================

func TestKind_Kind_Default_IsUnknown(t *testing.T) {
	k := enums.Kind_Kind_unknown()
	if !k.IsUnknown() {
		t.Error("IsUnknown() should be true")
	}
}

func TestKind_Kind_KindWrapper(t *testing.T) {
	k := enums.Kind_Kind_kindWrapper(true)
	if !k.IsKindWrapper() {
		t.Error("IsKindWrapper() should be true")
	}
	if k.UnwrapKind() != true {
		t.Error("UnwrapKind() should return true")
	}
}

func TestKind_Kind_UnwrapPanicsOnWrongKind(t *testing.T) {
	assertPanics(t, "UnwrapKind on unknown", func() {
		enums.Kind_Kind_unknown().UnwrapKind()
	})
}

// =============================================================================
// Type descriptor
// =============================================================================

func TestWeekday_TypeDescriptor_IsEnumDescriptor(t *testing.T) {
	td := enums.Weekday_serializer().TypeDescriptor()
	ed, ok := td.(*skir_client.EnumDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor is %T, want *skir_client.EnumDescriptor", td)
	}
	if ed.Name() != "Weekday" {
		t.Errorf("Name: got %q, want Weekday", ed.Name())
	}
	// 7 named constants + unknown variant = 7 variants listed
	if len(ed.Variants()) != 7 {
		t.Errorf("Variants: got %d, want 7", len(ed.Variants()))
	}
}

func TestJsonValue_TypeDescriptor_IsEnumDescriptor(t *testing.T) {
	td := enums.JsonValue_serializer().TypeDescriptor()
	ed, ok := td.(*skir_client.EnumDescriptor)
	if !ok {
		t.Fatalf("TypeDescriptor is %T, want *skir_client.EnumDescriptor", td)
	}
	if ed.Name() != "JsonValue" {
		t.Errorf("Name: got %q, want JsonValue", ed.Name())
	}
	// null (constant) + array, boolean, number, object, string (wrappers) = 6 variants
	if len(ed.Variants()) != 6 {
		t.Errorf("Variants: got %d, want 6", len(ed.Variants()))
	}
}

// =============================================================================
// helpers
// =============================================================================

func assertPanics(t *testing.T, label string, fn func()) {
	t.Helper()
	defer func() {
		if recover() == nil {
			t.Errorf("%s: expected a panic but did not panic", label)
		}
	}()
	fn()
}
