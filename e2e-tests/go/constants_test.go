package e2e_test

import (
	"math"
	"testing"
	"time"

	constants "e2e-test/skirout/constants"
)

func TestConstants_OneSingleQuotedString(t *testing.T) {
	if got := constants.OneSingleQuotedString_const; got != `"Foo"` {
		t.Errorf(`OneSingleQuotedString_const = %q, want "Foo"`, got)
	}
}

func TestConstants_OneFloat(t *testing.T) {
	if got := constants.OneFloat_const; got != 3.14 {
		t.Errorf("OneFloat_const = %v, want 3.14", got)
	}
}

func TestConstants_OneDouble(t *testing.T) {
	if got := constants.OneDouble_const; got != 3.141592653589793 {
		t.Errorf("OneDouble_const = %v, want 3.141592653589793", got)
	}
}

func TestConstants_OneBool(t *testing.T) {
	if got := constants.OneBool_const; !got {
		t.Errorf("OneBool_const = %v, want true", got)
	}
}

func TestConstants_LargeInt64(t *testing.T) {
	if got := constants.LargeInt64_const; got != math.MaxInt64 {
		t.Errorf("LargeInt64_const = %d, want %d", got, int64(math.MaxInt64))
	}
}

func TestConstants_LargeHash64(t *testing.T) {
	if got := constants.LargeHash64_const; got != math.MaxUint64 {
		t.Errorf("LargeHash64_const = %d, want %d", got, uint64(math.MaxUint64))
	}
}

func TestConstants_B(t *testing.T) {
	if got := constants.B_const; got {
		t.Errorf("B_const = %v, want false", got)
	}
}

func TestConstants_Pi(t *testing.T) {
	if got := constants.Pi_const; got != math.Pi {
		t.Errorf("Pi_const = %v, want %v", got, math.Pi)
	}
}

func TestConstants_OneTimestamp(t *testing.T) {
	got := constants.OneTimestamp_const()
	want := time.UnixMilli(1703984028000).UTC()
	if !got.Equal(want) {
		t.Errorf("OneTimestamp_const = %v, want %v", got, want)
	}
}

func TestConstants_Infinity(t *testing.T) {
	got := constants.Infinity_const()
	if !math.IsInf(float64(got), 1) {
		t.Errorf("Infinity_const = %v, want +Inf", got)
	}
}

func TestConstants_NegativeInfinity(t *testing.T) {
	got := constants.NegativeInfinity_const()
	if !math.IsInf(float64(got), -1) {
		t.Errorf("NegativeInfinity_const = %v, want -Inf", got)
	}
}

func TestConstants_Nan(t *testing.T) {
	got := constants.Nan_const()
	if !math.IsNaN(got) {
		t.Errorf("Nan_const = %v, want NaN", got)
	}
}
