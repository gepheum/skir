/// Wraps a hard-recursive struct field value.
///
/// `Default` should be treated the same as the default value of `a`.
pub type Recursive(a) {
  /// Treat this like the default value of `a`.
  Default
  Some(a)
}
