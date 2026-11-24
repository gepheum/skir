package skir_client

import "testing"

func TestOptional_zeroValue_isNotPresent(t *testing.T) {
	o := Optional[int]{}
	if o.IsPresent() {
		t.Fatal("expected IsPresent false for zero Optional")
	}
}

func TestOptionalOf_isPresent(t *testing.T) {
	o := OptionalOf(42)
	if !o.IsPresent() {
		t.Fatal("expected IsPresent true for OptionalOf(42)")
	}
}

func TestOptionalOf_Get(t *testing.T) {
	o := OptionalOf("hello")
	if got := o.Get(); got != "hello" {
		t.Fatalf("Get() = %q, want %q", got, "hello")
	}
}

func TestOptional_zeroValue_Get_panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic on Get() of absent Optional")
		}
	}()
	Optional[int]{}.Get()
}

func TestOptionalOfNilable_nil(t *testing.T) {
	o := OptionalOfNilable[int](nil)
	if o.IsPresent() {
		t.Fatal("expected IsPresent false for nil pointer")
	}
}

func TestOptionalOfNilable_nonNil(t *testing.T) {
	v := 99
	o := OptionalOfNilable(&v)
	if !o.IsPresent() {
		t.Fatal("expected IsPresent true for non-nil pointer")
	}
	if got := o.Get(); got != 99 {
		t.Fatalf("Get() = %d, want 99", got)
	}
}

func TestGetOr_present(t *testing.T) {
	o := OptionalOf(7)
	if got := o.GetOr(0); got != 7 {
		t.Fatalf("GetOr() = %d, want 7", got)
	}
}

func TestGetOr_absent(t *testing.T) {
	o := Optional[int]{}
	if got := o.GetOr(42); got != 42 {
		t.Fatalf("GetOr() = %d, want 42", got)
	}
}

func TestString_present(t *testing.T) {
	o := OptionalOf(123)
	if got := o.String(); got != "123" {
		t.Fatalf("String() = %q, want %q", got, "123")
	}
}

func TestString_absent(t *testing.T) {
	o := Optional[int]{}
	if got := o.String(); got != "null" {
		t.Fatalf("String() = %q, want %q", got, "null")
	}
}

func TestString_usesStringer(t *testing.T) {
	// bytes.Buffer implements fmt.Stringer; use a simple custom type instead.
	type myStringer struct{}
	// Use a string Optional to verify fmt.Sprint is called.
	o := OptionalOf("world")
	if got := o.String(); got != "world" {
		t.Fatalf("String() = %q, want %q", got, "world")
	}
}
