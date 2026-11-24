test "generated_full_name_struct_helpers_and_roundtrip" {
  let original = @full_name.FullName::new(first_name="Ada", last_name="Lovelace")
  assert_eq(original.first_name, "Ada")
  assert_eq(original.last_name, "Lovelace")

  let changed = original.copy(
    last_name=Set("Byron"),
  )
  assert_eq(changed.first_name, "Ada")
  assert_eq(changed.last_name, "Byron")

  let from_default_copy = @full_name.FullName::default().copy(
    first_name=Set("Grace"),
  )
  assert_eq(from_default_copy.first_name, "Grace")
  assert_eq(from_default_copy.last_name, "")

  let serializer = @full_name.FullName::serializer()
  let dense = serializer.to_dense_json_code(changed)
  match serializer.from_json_code(dense) {
    Ok(parsed) => if parsed != changed { panic() }
    Err(_) => panic()
  }

  let encoded = serializer.to_bytes(changed)
  match serializer.from_bytes(encoded) {
    Ok(parsed) => if parsed != changed { panic() }
    Err(_) => panic()
  }
}

test "generated_method_constants_are_stable" {
  assert_eq(@methods.my_procedure_method.name, "MyProcedure")
  assert_eq(@methods.with_explicit_number_method.number, 3)
  assert_eq(@methods.true_method.name, "True")

  // Access serializer fields from Method to catch API shape regressions.
  let dense = @methods.true_method.request_serializer.to_dense_json_code("hello")
  assert_eq(dense, "\"hello\"")
}

test "generated_goldens_constant_roundtrip" {
  let unit_test_vec_serializer = @client.vector_serializer(@goldens.UnitTest::serializer())
  let dense = unit_test_vec_serializer.to_dense_json_code(@goldens.unit_tests_const)
  match unit_test_vec_serializer.from_json_code(dense) {
    Ok(parsed) => if parsed != @goldens.unit_tests_const { panic() }
    Err(_) => panic()
  }
}

test "generated_keyed_vector_wrapper_lookup" {
  let monday_item = @goldens.KeyedArrays_Item::new(
    sub_item=@goldens.KeyedArrays_SubItem::new(
      weekday=@goldens.KeyedArrays_Weekday::monday(),
    ),
  )
  let keyed = @goldens.KeyedArrays_Item_bySubItem_Weekday_Kind::from_array([monday_item])
  match keyed.find_by_sub_item_weekday_kind(@goldens.KeyedArrays_Weekday_kind::Monday) {
    Some(found) => {
      if found.sub_item.weekday.kind() != @goldens.KeyedArrays_Weekday_kind::Monday {
        panic()
      }
    }
    None => panic()
  }
}

test "generated_enum_roundtrip_smoke" {
  let value = @goldens.EnumB::b("payload")
  let serializer = @goldens.EnumB::serializer()

  let dense = serializer.to_dense_json_code(value)
  match serializer.from_json_code(dense) {
    Ok(parsed) => if parsed != value { panic() }
    Err(_) => panic()
  }

  let encoded = serializer.to_bytes(value)
  match serializer.from_bytes(encoded) {
    Ok(parsed) => if parsed != value { panic() }
    Err(_) => panic()
  }
}
