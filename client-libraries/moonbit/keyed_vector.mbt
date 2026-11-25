///|
pub(all) struct Internal_KeyedVectorSpec[T, K] {
  get_key : (T) -> K
  key_extractor : String
  default_item : T
}

///|
pub struct Internal_KeyedVector[T, K] {
  vector : @immut_vector.Vector[T]
  priv spec : Internal_KeyedVectorSpec[T, K]
  priv mut index : @hashmap.HashMap[K, T]?
}

///|
pub fn[T, K] Internal_KeyedVector::new(
  vector : @immut_vector.Vector[T],
  spec : Internal_KeyedVectorSpec[T, K],
) -> Internal_KeyedVector[T, K] {
  { vector, spec, index: None, }
}

///|
pub fn[T, K] Internal_KeyedVector::from_array(
  items : Array[T],
  spec : Internal_KeyedVectorSpec[T, K],
) -> Internal_KeyedVector[T, K] {
  Internal_KeyedVector::new(@immut_vector.Vector::from_array(items), spec)
}

///|
pub fn[T, K] Internal_KeyedVector::empty(
  spec : Internal_KeyedVectorSpec[T, K],
) -> Internal_KeyedVector[T, K] {
  Internal_KeyedVector::new(@immut_vector.Vector::new(), spec)
}

///|
fn[T, K] Internal_KeyedVector::has_index(
  self : Internal_KeyedVector[T, K],
) -> Bool {
  match self.index {
    Some(_) => true
    None => false
  }
}

///|
fn[T, K : Hash + Eq] Internal_KeyedVector::build_index(
  self : Internal_KeyedVector[T, K],
) -> @hashmap.HashMap[K, T] {
  let index : @hashmap.HashMap[K, T] = @hashmap.HashMap(
    [],
    capacity=self.vector.length(),
  )
  for item in self.vector.iter() {
    let key = (self.spec.get_key)(item)
    // Keep last occurrence for duplicate keys.
    index.set(key, item)
  }
  index
}

///|
fn[T, K : Hash + Eq] Internal_KeyedVector::ensure_index(
  self : Internal_KeyedVector[T, K],
) -> @hashmap.HashMap[K, T] {
  match self.index {
    Some(index) => index
    None => {
      // Benign race: concurrent calls may build twice, but memory stays safe.
      let built = self.build_index()
      self.index = Some(built)
      built
    }
  }
}

///|
pub fn[T, K : Hash + Eq] Internal_KeyedVector::find_by_key(
  self : Internal_KeyedVector[T, K],
  key : K,
) -> T? {
  self.ensure_index().get(key)
}

///|
pub fn[T, K : Hash + Eq] Internal_KeyedVector::find_by_key_or_default(
  self : Internal_KeyedVector[T, K],
  key : K,
) -> T {
  match self.find_by_key(key) {
    Some(v) => v
    None => self.spec.default_item
  }
}

///|
priv struct MockItem {
  key : String
  value : Int32
}

///|
fn mock_spec() -> Internal_KeyedVectorSpec[MockItem, String] {
  Internal_KeyedVectorSpec::{
    get_key: fn(item : MockItem) { item.key },
    key_extractor: "key",
    default_item: { key: "", value: 0, },
  }
}

///|
fn[T : Eq] assert_eq_kv(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

///|
test "keyed_vector_starts_without_index" {
  let kv = Internal_KeyedVector::from_array(
    [{ key: "a", value: 1, }],
    mock_spec(),
  )
  assert_eq_kv(kv.has_index(), false)
}

///|
test "find_by_key_builds_index_and_returns_value" {
  let kv = Internal_KeyedVector::from_array(
    [{ key: "a", value: 1, }, { key: "b", value: 2, }],
    mock_spec(),
  )
  match kv.find_by_key("b") {
    Some(v) => assert_eq_kv(v.value, 2)
    None => panic()
  }
  assert_eq_kv(kv.has_index(), true)
}

///|
test "find_by_key_returns_none_when_missing" {
  let kv = Internal_KeyedVector::from_array(
    [{ key: "a", value: 1, }],
    mock_spec(),
  )
  assert_eq_kv(kv.find_by_key("missing") is None, true)
}

///|
test "find_by_key_keeps_last_duplicate" {
  let kv = Internal_KeyedVector::from_array(
    [{ key: "dup", value: 1, }, { key: "dup", value: 2, }],
    mock_spec(),
  )
  match kv.find_by_key("dup") {
    Some(v) => assert_eq_kv(v.value, 2)
    None => panic()
  }
}

///|
test "find_by_key_or_default_uses_spec_default_item" {
  let kv = Internal_KeyedVector::from_array(
    [{ key: "a", value: 1, }],
    mock_spec(),
  )
  let v = kv.find_by_key_or_default("missing")
  assert_eq_kv(v.key, "")
  assert_eq_kv(v.value, 0)
}

///|
pub impl[T : Eq, K] Eq for Internal_KeyedVector[T, K] with fn equal(self, other) {
  self.vector == other.vector
}

///|
pub impl[T : Debug, K] Debug for Internal_KeyedVector[T, K] with fn to_repr(
  self,
) {
  Debug::to_repr(self.vector)
}
