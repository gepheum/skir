package skir_client

import (
	"slices"
	"testing"
)

func TestArrayFromSlice_nil(t *testing.T) {
	a := ArrayFromSlice[int](nil)
	if a.Len() != 0 {
		t.Fatalf("expected Len 0, got %d", a.Len())
	}
	if !a.IsEmpty() {
		t.Fatal("expected IsEmpty true for nil input")
	}
}

func TestArrayFromSlice_empty(t *testing.T) {
	a := ArrayFromSlice([]int{})
	if a.Len() != 0 {
		t.Fatalf("expected Len 0, got %d", a.Len())
	}
	if !a.IsEmpty() {
		t.Fatal("expected IsEmpty true for empty input")
	}
}

func TestArrayFromSlice_copiesSlice(t *testing.T) {
	s := []int{1, 2, 3}
	a := ArrayFromSlice(s)
	// Mutate the original slice – the array must be unaffected.
	s[0] = 99
	if a.At(0) != 1 {
		t.Fatalf("ArrayFromSlice did not copy: At(0) = %d, want 1", a.At(0))
	}
}

func TestLen(t *testing.T) {
	cases := []struct {
		input []string
		want  int
	}{
		{nil, 0},
		{[]string{}, 0},
		{[]string{"a"}, 1},
		{[]string{"a", "b", "c"}, 3},
	}
	for _, tc := range cases {
		a := ArrayFromSlice(tc.input)
		if got := a.Len(); got != tc.want {
			t.Errorf("Len(%v) = %d, want %d", tc.input, got, tc.want)
		}
	}
}

func TestIsEmpty(t *testing.T) {
	if !ArrayFromSlice[int](nil).IsEmpty() {
		t.Error("nil slice: expected IsEmpty true")
	}
	if !ArrayFromSlice([]int{}).IsEmpty() {
		t.Error("empty slice: expected IsEmpty true")
	}
	if ArrayFromSlice([]int{0}).IsEmpty() {
		t.Error("single-element slice: expected IsEmpty false")
	}
}

func TestZeroValue(t *testing.T) {
	var a Array[string]
	if !a.IsEmpty() {
		t.Error("zero-value Array should be empty")
	}
	if a.Len() != 0 {
		t.Errorf("zero-value Array Len should be 0, got %d", a.Len())
	}
}

func TestAt(t *testing.T) {
	a := ArrayFromSlice([]string{"x", "y", "z"})
	for i, want := range []string{"x", "y", "z"} {
		if got := a.At(i); got != want {
			t.Errorf("At(%d) = %q, want %q", i, got, want)
		}
	}
}

func TestAt_elementIsIsolated(t *testing.T) {
	a := ArrayFromSlice([]int{10, 20})
	v0a := a.At(0)
	v0b := a.At(0)
	if v0a != v0b {
		t.Error("At(0) returned different values on consecutive calls")
	}
}

func TestAt_panicOnOutOfRange(t *testing.T) {
	a := ArrayFromSlice([]int{1, 2, 3})
	assertPanics(t, "At(3) on length-3 array", func() { a.At(3) })
	assertPanics(t, "At(-1)", func() { a.At(-1) })
}

func TestAt_panicOnEmpty(t *testing.T) {
	a := ArrayFromSlice[int](nil)
	assertPanics(t, "At(0) on empty array", func() { a.At(0) })
}

func TestToSlice_returnsCorrectElements(t *testing.T) {
	want := []int{3, 1, 4, 1, 5}
	a := ArrayFromSlice(want)
	got := a.ToSlice()
	if !slices.Equal(got, want) {
		t.Errorf("ToSlice() = %v, want %v", got, want)
	}
}

func TestToSlice_returnsCopy(t *testing.T) {
	a := ArrayFromSlice([]int{1, 2, 3})
	s := a.ToSlice()
	s[0] = 99
	// The array itself must be unaffected.
	if a.At(0) != 1 {
		t.Fatal("ToSlice returned a reference to internal storage, not a copy")
	}
}

func TestToSlice_empty(t *testing.T) {
	a := ArrayFromSlice[int](nil)
	s := a.ToSlice()
	if len(s) != 0 {
		t.Errorf("ToSlice on empty array: want len 0, got %d", len(s))
	}
}

func TestAll_order(t *testing.T) {
	a := ArrayFromSlice([]int{10, 20, 30})
	var gotIndices []int
	var gotValues []int
	for i, v := range a.All() {
		gotIndices = append(gotIndices, i)
		gotValues = append(gotValues, v)
	}
	if !slices.Equal(gotIndices, []int{0, 1, 2}) {
		t.Errorf("All indices = %v, want [0 1 2]", gotIndices)
	}
	if !slices.Equal(gotValues, []int{10, 20, 30}) {
		t.Errorf("All values = %v, want [10 20 30]", gotValues)
	}
}

func TestAll_empty(t *testing.T) {
	a := ArrayFromSlice[int](nil)
	count := 0
	for range a.All() {
		count++
	}
	if count != 0 {
		t.Errorf("All on empty array iterated %d times, want 0", count)
	}
}

func TestAll_earlyStop(t *testing.T) {
	a := ArrayFromSlice([]int{1, 2, 3, 4, 5})
	var got []int
	for _, v := range a.All() {
		got = append(got, v)
		if len(got) == 3 {
			break
		}
	}
	if !slices.Equal(got, []int{1, 2, 3}) {
		t.Errorf("All early-stop = %v, want [1 2 3]", got)
	}
}

func TestBackward_order(t *testing.T) {
	a := ArrayFromSlice([]int{10, 20, 30})
	var gotIndices []int
	var gotValues []int
	for i, v := range a.Backward() {
		gotIndices = append(gotIndices, i)
		gotValues = append(gotValues, v)
	}
	if !slices.Equal(gotIndices, []int{2, 1, 0}) {
		t.Errorf("Backward indices = %v, want [2 1 0]", gotIndices)
	}
	if !slices.Equal(gotValues, []int{30, 20, 10}) {
		t.Errorf("Backward values = %v, want [30 20 10]", gotValues)
	}
}

func TestBackward_empty(t *testing.T) {
	a := ArrayFromSlice[int](nil)
	count := 0
	for range a.Backward() {
		count++
	}
	if count != 0 {
		t.Errorf("Backward on empty array iterated %d times, want 0", count)
	}
}

func TestBackward_earlyStop(t *testing.T) {
	a := ArrayFromSlice([]int{1, 2, 3, 4, 5})
	var got []int
	for _, v := range a.Backward() {
		got = append(got, v)
		if len(got) == 2 {
			break
		}
	}
	if !slices.Equal(got, []int{5, 4}) {
		t.Errorf("Backward early-stop = %v, want [5 4]", got)
	}
}

func TestBackward_singleElement(t *testing.T) {
	a := ArrayFromSlice([]int{42})
	var gotIndices []int
	var gotValues []int
	for i, v := range a.Backward() {
		gotIndices = append(gotIndices, i)
		gotValues = append(gotValues, v)
	}
	if !slices.Equal(gotIndices, []int{0}) {
		t.Errorf("Backward single-element indices = %v, want [0]", gotIndices)
	}
	if !slices.Equal(gotValues, []int{42}) {
		t.Errorf("Backward single-element values = %v, want [42]", gotValues)
	}
}

func assertPanics(t *testing.T, label string, fn func()) {
	t.Helper()
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("%s: expected a panic but none occurred", label)
		}
	}()
	fn()
}
