// Wraps a hard-recursive struct field value.
// Default should be treated the same as the default value of T.

///|
pub(all) enum Recursive[T] {
  Default
  Some(T)
} derive(Eq, Debug)
