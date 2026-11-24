///|
pub(all) enum KeepOrSet[T] {
  Keep
  Set(T)
} derive(Eq, Debug)
