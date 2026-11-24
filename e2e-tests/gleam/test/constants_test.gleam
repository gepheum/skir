import gleeunit/should
import skir_client/timestamp
import skirout/constants
import skirout/enums

// =============================================================================
// b_const
// =============================================================================

pub fn b_const_test() {
  constants.b_const
  |> should.equal(False)
}

// =============================================================================
// foo_method_const
// =============================================================================

pub fn foo_method_const_test() {
  constants.foo_method_const
  |> should.equal(True)
}

// =============================================================================
// large_int64_const
// =============================================================================

pub fn large_int64_const_test() {
  constants.large_int64_const
  |> should.equal(9_223_372_036_854_775_807)
}

// =============================================================================
// one_single_quoted_string_const
// =============================================================================

pub fn one_single_quoted_string_const_test() {
  constants.one_single_quoted_string_const
  |> should.equal("\"Foo\"")
}

// =============================================================================
// one_timestamp_const
// =============================================================================

pub fn one_timestamp_const_test() {
  let timestamp.Timestamp(unix_millis: ms) = constants.one_timestamp_const
  ms
  |> should.equal(1_703_984_028_000)
}

// =============================================================================
// pi_const
// =============================================================================

pub fn pi_const_test() {
  constants.pi_const
  |> should.equal(3.141592653589793)
}

// =============================================================================
// one_constant_const — complex enum with nested values
// =============================================================================

pub fn one_constant_const_is_array_variant_test() {
  case constants.one_constant_const {
    enums.JsonValueArray(_) -> Nil
    _ -> should.fail()
  }
}

pub fn one_constant_const_array_has_4_items_test() {
  let assert enums.JsonValueArray(items) = constants.one_constant_const
  let assert [b, n, s, obj] = items
  b |> should.equal(enums.JsonValueBoolean(True))
  n |> should.equal(enums.JsonValueNumber(2.5))
  s |> should.equal(enums.JsonValueString("\n        foo\n        bar"))
  let assert enums.JsonValueObject([pair]) = obj
  let enums.JsonValuePair(name: name, value: v, ..) = pair
  name |> should.equal("foo")
  v |> should.equal(enums.JsonValueNull)
}

// =============================================================================
// infinity_const, minus_infinity_const, nan_const — pub const fallbacks
// =============================================================================

pub fn infinity_const_is_float_test() {
  // Infinity maps to max float
  should.equal(constants.infinity_const >. 1.0e308, True)
}
