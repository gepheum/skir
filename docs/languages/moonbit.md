[![npm](https://img.shields.io/npm/v/skir-moonbit-gen)](https://www.npmjs.com/package/skir-moonbit-gen)
[![build](https://github.com/gepheum/skir-moonbit-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-moonbit-gen/actions)

# Skir's MoonBit code generator

Official plugin for generating MoonBit code from [.skir](https://github.com/gepheum/skir) files.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
	- mod: skir-moonbit-gen
		outDir: ./skirout
		config: {}
```

The generated MoonBit code has a runtime dependency on `gepheum/skir-client`.
Add it with:

```bash
moon add gepheum/skir-client
```

For more information, see this MoonBit project [example](https://github.com/gepheum/skir-moonbit-example).

## MoonBit generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-moonbit-example/blob/main/skir-src/user.skir) .skir file.
Most code snippets are quoted from [moonbit-example/src/snippets.mbt](https://github.com/gepheum/skir-moonbit-example/blob/main/src/snippets.mbt).

### Struct types

Skir generates a plain MoonBit struct for each struct in the .skir schema.

```moonbit
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

let evil_john = john.copy(
	name=@client.KeepOrSet::Set("Evil John"),
	quote=@client.KeepOrSet::Set("I solemnly swear I am up to no good."),
)

println(evil_john.name)
// Evil John
println(evil_john.user_id.to_string())
// 42

let jane = @skirout_user.User::default().copy(
	user_id=@client.KeepOrSet::Set(43),
	name=@client.KeepOrSet::Set("Jane Doe"),
)

println(jane.name)
// Jane Doe
println(jane.quote)
// (empty string)
```

### Enum types

```moonbit
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
```

### Conditions on enums

```moonbit
let subscription_info_text = fn(
	status : @skirout_user.SubscriptionStatus,
) {
	match status {
		Unknown(_) => "Unknown subscription status"
		Free => "Free user"
		Trial(trial) => "On trial since " + trial.start_time.to_iso8601()
		Premium => "Premium user"
	}
}

println(subscription_info_text(john.subscription_status))
// Free user

println(
	subscription_info_text(@skirout_user.SubscriptionStatus::unknown()),
)
// Unknown subscription status
```

### Serialization

Every generated struct and enum has a static serializer.

```moonbit
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
```

### Deserialization

```moonbit
let from_dense = match user_serializer.from_json_code(john_dense_json) {
	Ok(value) => value
	Err(_) => panic()
}

let from_readable = match user_serializer.from_json_code(john_readable_json) {
	Ok(value) => value
	Err(_) => panic()
}

let from_binary = match
	user_serializer.from_bytes(
		john_binary,
		unrecognized_values=@client.UnrecognizedValues::Drop,
	) {
	Ok(value) => value
	Err(_) => panic()
}

if from_dense != john || from_readable != john || from_binary != john {
	panic()
}
```

### Primitive serializers

```moonbit
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
println(@client.float32_serializer().to_dense_json_code(3.14))
// 3.14
println(@client.float64_serializer().to_dense_json_code(3.14))
// 3.14
println(@client.string_serializer().to_dense_json_code("Foo"))
// "Foo"
println(@client.bytes_serializer().to_dense_json_code(@utf8.encode("ABC")))
// "QUJD"
```

### Composite serializers

```moonbit
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
```

### Constants

```moonbit
let tarzan = @skirout_user.tarzan_const
println(tarzan.name)
// Tarzan
println(user_serializer.to_readable_json(tarzan).stringify(indent=2))
// {
//   "user_id": 123,
//   ...
// }
```

### Keyed arrays

```moonbit
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
```

### Reflection

```moonbit
let user_td = user_serializer.type_descriptor()
println(user_td.records.length().to_string())

for record in user_td.records.iter() {
	match record {
		Struct(sd) =>
			if sd.record_id == "user.skir:User" {
				println(sd.record_id + " has " + sd.fields.length().to_string() + " fields")
			}
		Enum(_) => ()
	}
}

let user_td_json = user_td.as_json()
let parsed_td = match @client.parse_from_json(user_td_json) {
	Ok(v) => v
	Err(_) => panic()
}
println(parsed_td.records.length().to_string())
```

### SkirRPC services

#### Starting a SkirRPC service on an HTTP server

Full example [here](https://github.com/gepheum/skir-moonbit-example/blob/main/src/start_service.mbt).

#### Sending RPCs to a SkirRPC service

Full example [here](https://github.com/gepheum/skir-moonbit-example/blob/main/src/call_service.mbt).
