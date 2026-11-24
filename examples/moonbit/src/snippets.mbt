///|
/// Code snippets showing how to use MoonBit-generated data types.
///
/// Run with:
///   moon test src --target native --filter snippets
test "snippets" {
  // ==========================================================================
  // STRUCT TYPES
  // ==========================================================================

  // Skir generates a plain MoonBit struct for each struct in the .skir schema.
  let john = @skirout_user.User::new(
    user_id=42,
    name="John Doe",
    quote="Coffee is just a socially acceptable form of rage.",
    pets=@client.ImmutVector::from_array([
      @skirout_user.User_Pet::new(
        name="Dumbo",
        height_in_meters=1.0,
        picture="🐘",
      ),
    ]),
    subscription_status=@skirout_user.SubscriptionStatus::free(),
  )

  println(john.name)
  // John Doe

  // copy() returns a modified value while preserving non-overridden fields.
  let evil_john = john.copy(
    name=@client.KeepOrSet::Set("Evil John"),
    quote=@client.KeepOrSet::Set("I solemnly swear I am up to no good."),
  )

  println(evil_john.name)
  // Evil John
  println(evil_john.user_id.to_string())
  // 42

  // To create a value with only some fields set, start from defaults and copy
  // only what you need.
  let jane = @skirout_user.User::default().copy(
    user_id=@client.KeepOrSet::Set(43),
    name=@client.KeepOrSet::Set("Jane Doe"),
  )

  println(jane.name)
  // Jane Doe
  println(jane.quote)
  // (empty string)

  // ==========================================================================
  // ENUM TYPES
  // ==========================================================================

  let trial_payload = @skirout_user.SubscriptionStatus_Trial::new(
    start_time=@client.Timestamp::from_unix_millis(1744974198000L),
  )

  let some_statuses = [
    @skirout_user.SubscriptionStatus::unknown(),
    @skirout_user.SubscriptionStatus::free(),
    @skirout_user.SubscriptionStatus::premium(),
    @skirout_user.SubscriptionStatus::trial(trial_payload),
  ]
  println(some_statuses.length().to_string())
  // 4

  let subscription_info_text = fn(status : @skirout_user.SubscriptionStatus) {
    match status {
      Unknown(_) => "Unknown subscription status"
      Free => "Free user"
      Trial(trial) => "On trial since " + trial.start_time.to_iso8601()
      Premium => "Premium user"
    }
  }

  // ==========================================================================
  // ENUM MATCHING
  // ==========================================================================

  println(subscription_info_text(john.subscription_status))
  // Free user

  println(subscription_info_text(@skirout_user.SubscriptionStatus::unknown()))
  // Unknown subscription status

  println(
    subscription_info_text(
      @skirout_user.SubscriptionStatus::trial(trial_payload),
    ),
  )
  // On trial since ...

  // ==========================================================================
  // SERIALIZATION
  // ==========================================================================

  let user_serializer = @skirout_user.User::serializer()

  let john_dense_json = user_serializer.to_dense_json_code(john)
  println(john_dense_json)
  // [42,"John Doe",...]

  let john_readable_json = user_serializer
    .to_readable_json(john)
    .stringify(indent=2)
  println(john_readable_json)
  // {
  //   "user_id": 42,
  //   ...
  // }

  let john_binary = user_serializer.to_bytes(john)

  // from_json_code handles both dense and readable JSON.
  let from_dense = match user_serializer.from_json_code(john_dense_json) {
    Ok(value) => value
    Err(_) => panic()
  }
  println(from_dense.name)
  // John Doe

  let from_readable = match user_serializer.from_json_code(john_readable_json) {
    Ok(value) => value
    Err(_) => panic()
  }
  println(from_readable.name)
  // John Doe

  let from_binary = match
    user_serializer.from_bytes(
      john_binary,
      unrecognized_values=@client.UnrecognizedValues::Drop,
    ) {
    Ok(value) => value
    Err(_) => panic()
  }
  println(from_binary.name)
  // John Doe

  if from_dense != john || from_readable != john || from_binary != john {
    panic()
  }

  // ==========================================================================
  // PRIMITIVE SERIALIZERS
  // ==========================================================================

  println(@client.bool_serializer().to_dense_json_code(true))
  // 1
  println(@client.int32_serializer().to_dense_json_code(3))
  // 3
  println(@client.int64_serializer().to_dense_json_code(9223372036854775807L))
  // "9223372036854775807"
  println(
    @client.hash64_serializer().to_dense_json_code(18446744073709551615UL),
  )
  // "18446744073709551615"
  println(
    @client.timestamp_serializer()
    .to_readable_json(@client.Timestamp::from_unix_millis(1743682787000L))
    .stringify(),
  )
  // {"unix_millis":...,"formatted":"..."}
  println(@client.float32_serializer().to_dense_json_code(3.14))
  // 3.14
  println(@client.float64_serializer().to_dense_json_code(3.14))
  // 3.14
  println(@client.string_serializer().to_dense_json_code("Foo"))
  // "Foo"
  println(@client.bytes_serializer().to_dense_json_code(@utf8.encode("ABC")))
  // "QUJD"

  // ==========================================================================
  // COMPOSITE SERIALIZERS
  // ==========================================================================

  let opt_string_ser = @client.optional_serializer(@client.string_serializer())
  println(opt_string_ser.to_dense_json_code(None))
  // null
  println(opt_string_ser.to_dense_json_code(Some("foo")))
  // "foo"

  let bool_array_ser = @client.vector_serializer(@client.bool_serializer())
  println(
    bool_array_ser.to_dense_json_code(
      @client.ImmutVector::from_array([true, false]),
    ),
  )
  // [1,0]

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  let tarzan = @skirout_user.tarzan_const
  println(tarzan.name)
  // Tarzan
  println(user_serializer.to_readable_json(tarzan).stringify(indent=2))
  // {
  //   "user_id": 123,
  //   ...
  // }

  // ==========================================================================
  // KEYED ARRAYS
  // ==========================================================================

  let user_registry = @skirout_user.UserRegistry::new(
    users=@skirout_user.User_byUserId::from_array([john, jane, evil_john]),
  )

  let found = user_registry.users.find_by_user_id(43)
  match found {
    Some(user) => println(user.name)
    None => panic()
  }
  // Jane Doe

  let not_found = user_registry.users.find_by_user_id(999)
  println((not_found is None).to_string())
  // true

  let found_or_default = user_registry.users.find_by_user_id_or_default(999)
  println(found_or_default.pets.length().to_string())
  // 0

  // ==========================================================================
  // REFLECTION
  // ==========================================================================

  let user_td = user_serializer.type_descriptor()
  println(user_td.records.length().to_string())

  for record in user_td.records.iter() {
    match record {
      Struct(sd) =>
        if sd.record_id == "user.skir:User" {
          println(
            sd.record_id + " has " + sd.fields.length().to_string() + " fields",
          )
          for field in sd.fields.iter() {
            if field.name == "name" {
              println("field 'name' number=" + field.number.to_string())
            }
          }
        }
      Enum(_) => ()
    }
  }

  let enum_td = @skirout_user.SubscriptionStatus::serializer().type_descriptor()
  for record in enum_td.records.iter() {
    match record {
      Enum(ed) =>
        if ed.record_id == "user.skir:SubscriptionStatus" {
          println(
            ed.record_id +
            " has " +
            ed.variants.length().to_string() +
            " variants",
          )
          for variant in ed.variants.iter() {
            match variant {
              Constant(v) =>
                if v.name == "trial" {
                  println("variant trial number=" + v.number.to_string())
                }
              Wrapper(v) =>
                if v.name == "trial" {
                  println("variant trial number=" + v.number.to_string())
                }
            }
          }
        }
      Struct(_) => ()
    }
  }

  // You can serialize type descriptors and parse them back.
  let user_td_json = user_td.as_json()
  let parsed_td = match @client.parse_from_json(user_td_json) {
    Ok(v) => v
    Err(_) => panic()
  }
  println(parsed_td.records.length().to_string())
}
