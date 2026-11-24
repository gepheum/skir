///|
fn assert_string_eq(actual : String, expected : String) -> Unit {
  if actual != expected {
    panic()
  }
}

///|
test "get_percent_decoded_query_from_url: no query" {
  assert_string_eq(get_percent_decoded_query_from_url("/api/users"), "")
}

///|
test "get_percent_decoded_query_from_url: empty query" {
  assert_string_eq(get_percent_decoded_query_from_url("/api/users?"), "")
}

///|
test "get_percent_decoded_query_from_url: keeps plain query" {
  assert_string_eq(
    get_percent_decoded_query_from_url("/api/users?name=alice&age=30"),
    "name=alice&age=30",
  )
}

///|
test "get_percent_decoded_query_from_url: percent and plus decode" {
  assert_string_eq(
    get_percent_decoded_query_from_url("/api/search?q=hello%20moonbit+world"),
    "q=hello moonbit world",
  )
}

///|
test "get_percent_decoded_query_from_url: invalid percent is kept" {
  assert_string_eq(
    get_percent_decoded_query_from_url("/api/search?q=%ZZ"),
    "q=%ZZ",
  )
}
