///|
#derive(Eq, Debug)
pub(all) enum KeepOrSet[T] {
  Keep
  Set(T)
}
