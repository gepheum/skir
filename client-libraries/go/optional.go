package skir_client

import "fmt"

// Optional[T] holds a value of type T that may or may not be present.
// It is deeply immutable when T is deeply immutable.
//
// To obtain a present value, use [OptionalOf] or [OptionalOfNilable].
// To obtain an absent value, use the zero value: Optional[T]{}.
//
// The wrapped value must not be nil; [OptionalOf] panics if it is.
type Optional[T any] struct {
	value   T
	present bool
}

// OptionalOf returns an Optional containing v. Panics if v is nil.
func OptionalOf[T any](v T) Optional[T] {
	if any(v) == nil {
		panic("OptionalOf: value must not be nil")
	}
	return Optional[T]{value: v, present: true}
}

// OptionalOfNilable converts a possibly-nil pointer to an Optional:
// nil pointer → absent, non-nil pointer → present with *p.
// If T is an interface type, *p must not be a nil interface; panics if it is.
func OptionalOfNilable[T any](p *T) Optional[T] {
	if p == nil {
		return Optional[T]{}
	} else {
		return OptionalOf(*p)
	}
}

// IsPresent reports whether a value is present.
func (o Optional[T]) IsPresent() bool { return o.present }

// Get returns the value. Panics if not present.
func (o Optional[T]) Get() T {
	if !o.present {
		panic("Optional.Get(): value is not present")
	}
	return o.value
}

// GetOr returns the value if present, or the provided default value otherwise.
func (o Optional[T]) GetOr(def T) T {
	if o.present {
		return o.value
	}
	return def
}

func (o Optional[T]) String() string {
	if !o.present {
		return "null"
	}
	return fmt.Sprint(o.value)
}
