import gleeunit/should
import skirout/methods

// =============================================================================
// my_procedure_method
// =============================================================================

pub fn my_procedure_method_name_test() {
  methods.my_procedure_method().name
  |> should.equal("MyProcedure")
}

pub fn my_procedure_method_number_test() {
  methods.my_procedure_method().number
  |> should.equal(674_706_602)
}

pub fn my_procedure_method_doc_test() {
  methods.my_procedure_method().doc
  |> should.equal("My procedure")
}

// =============================================================================
// with_explicit_number_method
// =============================================================================

pub fn with_explicit_number_method_name_test() {
  methods.with_explicit_number_method().name
  |> should.equal("WithExplicitNumber")
}

pub fn with_explicit_number_method_number_test() {
  methods.with_explicit_number_method().number
  |> should.equal(3)
}

// =============================================================================
// true_method
// =============================================================================

pub fn true_method_name_test() {
  methods.true_method().name
  |> should.equal("True")
}

pub fn true_method_number_test() {
  methods.true_method().number
  |> should.equal(78_901)
}
