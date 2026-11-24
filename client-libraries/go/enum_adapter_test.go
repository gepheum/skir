package skir_client

import (
	"testing"
)

// ─────────────────────────────────────────────────────────────────────────────
// Helpers: a minimal Color enum for case-compatibility tests
// ─────────────────────────────────────────────────────────────────────────────

type colorKind int

const (
	colorKindUnknown colorKind = 0
	colorKindRed     colorKind = 1
	colorKindGreen   colorKind = 2
	colorKindBlue    colorKind = 3
)

type testColor struct {
	kind         colorKind
	unrecognized *Internal__UnrecognizedVariant
}

var (
	testColorUnknown = testColor{kind: colorKindUnknown}
	testColorRed     = testColor{kind: colorKindRed}
	testColorGreen   = testColor{kind: colorKindGreen}
	testColorBlue    = testColor{kind: colorKindBlue}
)

func newTestColorEnumAdapter() *Internal__EnumAdapter[testColor] {
	a := NewEnumAdapter[testColor](
		"test", "Color", "",
		func(c testColor) int { return int(c.kind) },
		4,
		testColorUnknown,
		func(u *Internal__UnrecognizedVariant) testColor {
			return testColor{kind: colorKindUnknown, unrecognized: u}
		},
		func(c testColor) *Internal__UnrecognizedVariant { return c.unrecognized },
	)
	// Register with lower_case names (as the future generator will produce).
	a.AddConstantVariant(1, "red", int(colorKindRed), "", testColorRed)
	a.AddConstantVariant(2, "green", int(colorKindGreen), "", testColorGreen)
	a.AddConstantVariant(3, "blue", int(colorKindBlue), "", testColorBlue)
	a.Finalize()
	return a
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

// TestEnumNameCase_SerializeLowerCase verifies that a constant registered with
// a lower_case name is serialized to lower_case in readable JSON.
func TestEnumNameCase_SerializeLowerCase(t *testing.T) {
	a := newTestColorEnumAdapter()
	ser := a.Serializer()

	got := ser.ToJson(testColorRed, Readable{})
	if got != `"red"` {
		t.Errorf("ToJson(RED, readable) = %q, want %q", got, `"red"`)
	}
}

// TestEnumNameCase_ParseUpperCase verifies that UPPER_CASE constant names
// (produced by old serializers) are correctly parsed.
func TestEnumNameCase_ParseUpperCase(t *testing.T) {
	a := newTestColorEnumAdapter()
	ser := a.Serializer()

	result, err := ser.FromJson(`"RED"`)
	if err != nil {
		t.Fatalf("FromJson(%q): %v", `"RED"`, err)
	}
	if result.kind != colorKindRed {
		t.Errorf("FromJson(%q).kind = %v, want %v", `"RED"`, result.kind, colorKindRed)
	}
}

// TestEnumNameCase_ParseLowerCase verifies that lower_case constant names
// (produced by new serializers) are correctly parsed.
func TestEnumNameCase_ParseLowerCase(t *testing.T) {
	a := newTestColorEnumAdapter()
	ser := a.Serializer()

	result, err := ser.FromJson(`"green"`)
	if err != nil {
		t.Fatalf("FromJson(%q): %v", `"green"`, err)
	}
	if result.kind != colorKindGreen {
		t.Errorf("FromJson(%q).kind = %v, want %v", `"green"`, result.kind, colorKindGreen)
	}
}

// TestEnumNameCase_UpperAndLowerYieldSameResult verifies that parsing the same
// constant name in either casing yields identical results.
func TestEnumNameCase_UpperAndLowerYieldSameResult(t *testing.T) {
	a := newTestColorEnumAdapter()
	ser := a.Serializer()

	fromUpper, err := ser.FromJson(`"RED"`)
	if err != nil {
		t.Fatalf("FromJson(RED): %v", err)
	}
	fromLower, err := ser.FromJson(`"red"`)
	if err != nil {
		t.Fatalf("FromJson(red): %v", err)
	}
	if fromUpper.kind != fromLower.kind {
		t.Errorf("Parsing RED and red yield different kinds: %v vs %v", fromUpper.kind, fromLower.kind)
	}
	if fromUpper.kind != colorKindRed {
		t.Errorf("Expected colorKindRed, got %v", fromUpper.kind)
	}
}

// TestEnumNameCase_ParseUnknownLowerCase verifies that lower-case "unknown"
// is treated like upper-case "UNKNOWN".
func TestEnumNameCase_ParseUnknownLowerCase(t *testing.T) {
	a := newTestColorEnumAdapter()
	ser := a.Serializer()

	fromUpper, err := ser.FromJson(`"UNKNOWN"`)
	if err != nil {
		t.Fatalf("FromJson(UNKNOWN): %v", err)
	}
	fromLower, err := ser.FromJson(`"unknown"`)
	if err != nil {
		t.Fatalf("FromJson(unknown): %v", err)
	}
	if fromUpper.kind != fromLower.kind {
		t.Errorf("Parsing UNKNOWN and unknown yield different kinds: %v vs %v", fromUpper.kind, fromLower.kind)
	}
	if fromLower.kind != colorKindUnknown {
		t.Errorf("Expected colorKindUnknown, got %v", fromLower.kind)
	}
}
