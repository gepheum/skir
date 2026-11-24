package skir_client

import (
	"iter"
)

// Array is an immutable, ordered sequence of elements of type T.
//
// Unlike []T, an Array value cannot be modified after creation: callers cannot
// append to it, remove from it, or overwrite individual elements.
//
// Elements must not be nil; [ArrayFromSlice] panics if any element is nil.
type Array[T any] struct {
	// A copy of the original slice is stored, so the caller cannot mutate the
	// contents by keeping a reference to the original slice.
	s []T
}

// ArrayFromSlice returns an Array whose content is a copy of s.
// Panics if any element of s is nil.
func ArrayFromSlice[T any](s []T) Array[T] {
	c := make([]T, len(s))
	for i, v := range s {
		if any(v) == nil {
			panic("ArrayFromSlice: element must not be nil")
		}
		c[i] = v
	}
	return Array[T]{s: c}
}

// Len returns the number of elements in the array.
func (a Array[T]) Len() int {
	return len(a.s)
}

// IsEmpty reports whether the array contains no elements.
func (a Array[T]) IsEmpty() bool {
	return len(a.s) == 0
}

// At returns the element at index i. Panics if i is out of range.
func (a Array[T]) At(i int) T {
	return a.s[i]
}

// ToSlice returns a copy of the underlying elements as a []T.
func (a Array[T]) ToSlice() []T {
	c := make([]T, len(a.s))
	copy(c, a.s)
	return c
}

// All returns an iterator over index-value pairs in forward order,
// compatible with range loops in Go 1.23+.
func (a Array[T]) All() iter.Seq2[int, T] {
	return func(yield func(int, T) bool) {
		for i, v := range a.s {
			if !yield(i, v) {
				return
			}
		}
	}
}

// Backward returns an iterator over index-value pairs in reverse order,
// compatible with range loops in Go 1.23+.
func (a Array[T]) Backward() iter.Seq2[int, T] {
	return func(yield func(int, T) bool) {
		for i := len(a.s) - 1; i >= 0; i-- {
			if !yield(i, a.s[i]) {
				return
			}
		}
	}
}
