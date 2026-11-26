# Ruby

This guide explains how to use Skir in a Ruby project. Targets Ruby 3.1 and higher, with full static type-checking support via [Sorbet](https://sorbet.org) (`# typed: strict`).

## Set up

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
- mod: skir-ruby-gen
  outDir: ./lib/skirout
  config: {}
  # Or with a custom top-level module prefix:
  # outDir: ./lib/my_app/skirout
  # config:
  #   modulePrefix: "MyApp::"
```

The generated Ruby code has a runtime dependency on the `skir-client` gem (which depends on `sorbet-runtime`). Install it with:

```bash
gem install skir-client
```

Or add it to your `Gemfile`:

```ruby
gem "skir-client"
```

## Generated code guide

The examples below are for the code generated from `user.skir`.

### Referring to generated symbols

Require the generated file and reference the module or assign convenient aliases:

```ruby
require_relative "skirout/user_skir"

User = Skirout::UserSkir::User
UserHistory = Skirout::UserSkir::UserHistory
UserRegistry = Skirout::UserSkir::UserRegistry
SubscriptionStatus = Skirout::UserSkir::SubscriptionStatus
TARZAN = Skirout::UserSkir::TARZAN
```

### Structs

For every struct `S` in the `.skir` file, Skir generates a frozen (deeply immutable) class `S` and a mutable class `S::Mutable`.

#### Frozen structs

```ruby
# To construct a frozen User, either call User.new (all fields required as keyword arguments)
# or User.partial (omitted fields default to their type's default value).

john = User.new(
  user_id: 42,
  name: "John Doe",
  quote: "Coffee is just a socially acceptable form of rage.",
  pets: [
    User::Pet.new(
      name: "Dumbo",
      height_in_meters: 1.0,
      picture: "🐘"
    )
  ],
  subscription_status: SubscriptionStatus::FREE
  # foo: "bar"
  # ^ Static & runtime error: 'foo' is not a field of User
)

raise unless john.name == "John Doe"

# Lists passed to new or partial are copied and frozen to ensure deep immutability.
raise unless john.pets.frozen?

# With 'User.partial', you don't need to specify all the fields of the struct.
jane = User.partial(
  user_id: 43,
  name: "Jane Doe"
)

# Missing fields are initialized to their default values.
raise unless jane.quote == ""

# 'User::DEFAULT' is a constant holding the result of calling 'User.partial'
# with no arguments.
raise unless User::DEFAULT == User.partial
```

#### Mutable structs

```ruby
# User::Mutable is a mutable version of User.
lyla_mut = User::Mutable.new
lyla_mut.user_id = 44
lyla_mut.name = "Lyla Doe"

# You can also set fields in the constructor.
joly_mut = User::Mutable.new(user_id: 45)
joly_mut.name = "Joly Doe"

joly_history_mut = UserHistory::Mutable.new
joly_history_mut.user = joly_mut
# ^ The right-hand side of the assignment can be either frozen or mutable.

# The mutable_user getter first checks if 'user' is already a mutable struct,
# and if so, returns it. Otherwise, it assigns to 'user' a mutable shallow copy
# of itself and returns it.
joly_history_mut.mutable_user.quote = "I am Joly."

# Similarly, mutable_pets first checks if 'pets' is already a mutable Array,
# and if so, returns it. Otherwise, it assigns to 'pets' a mutable shallow copy
# of itself and returns it.
lyla_mut.mutable_pets << User::Pet.partial(name: "Cupcake")
lyla_mut.mutable_pets << User::Pet::Mutable.new(name: "Simba")
```

#### Converting between frozen and mutable

```ruby
# to_mutable does a shallow copy of the frozen struct, so it's cheap. All the
# properties of the copy hold a frozen value.
evil_jane_mut = jane.to_mutable
evil_jane_mut.name = "Evil Jane"

# to_frozen recursively copies the mutable values held by properties of the
# object. It's cheap if all the values are frozen, like in this example.
evil_jane = evil_jane_mut.to_frozen

# You can also call replace on the frozen struct.
evil_jane = evil_jane.replace(name: "Evil Jane")

raise unless evil_jane.user_id == 43
```

#### Writing logic agnostic of mutability

```ruby
extend T::Sig

# 'User::OrMutable' is a Sorbet type alias for 'T.any(User, User::Mutable)'.
sig { params(user: User::OrMutable).void }
def greet(user)
  puts "Hello, #{user.name}"
end

greet(jane)
# Hello, Jane Doe
greet(lyla_mut)
# Hello, Lyla Doe
```

### Enums

The definition of the `SubscriptionStatus` enum in the `.skir` file is:

```skir
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

#### Creating enum values

```ruby
john_status = SubscriptionStatus::FREE
jane_status = SubscriptionStatus::PREMIUM

joly_status = SubscriptionStatus::UNKNOWN

# Use wrap_*() for wrapper variants.
roni_status = SubscriptionStatus.wrap_trial(
  SubscriptionStatus::Trial.new(
    start_time: Time.at(1_744_974_198).utc
  )
)

# If the wrapped value is a struct, you can use create_*(...) instead of
# wrap_*(Struct.new(...))
raise unless roni_status == SubscriptionStatus.create_trial(
  start_time: Time.at(1_744_974_198).utc
)
```

#### Pattern matching and type-safe exhaustiveness with Sorbet

Every enum class is `sealed!` in Sorbet with final variant subclasses `V_UNKNOWN`, `V_<CONSTANT_VARIANT>`, and `V_<wrapper_variant>`, and exposes `status.union` (typed as `SubscriptionStatus::Union`):

```ruby
# Use 'union.kind' to check which variant the enum value holds.
raise unless john_status.union.kind == "FREE"
raise unless joly_status.union.kind == "UNKNOWN"
raise unless roni_status.union.kind == "trial"

# If the enum holds a wrapper variant, you can access the wrapped value through 'union.value'.
raise unless roni_status.union.value.is_a?(SubscriptionStatus::Trial)

# Exhaustive, statically type-checked branching with Sorbet:
sig { params(status: SubscriptionStatus).returns(String) }
def get_subscription_info_text(status)
  u = status.union
  case u
  when SubscriptionStatus::V_UNKNOWN
    "Unknown subscription status"
  when SubscriptionStatus::V_FREE
    "Free user"
  when SubscriptionStatus::V_PREMIUM
    "Premium user"
  when SubscriptionStatus::V_trial
    # Here Sorbet statically narrows u.value to SubscriptionStatus::Trial!
    trial = u.value
    "On trial since #{trial.start_time}"
  else
    # Sorbet will report a compile-time error if any variant is missing.
    T.absurd(u)
  end
end
```

### Serialization

Every frozen struct class and enum class has a `serializer` singleton method which returns a `Skir::Serializer` for serializing and deserializing instances of the class.

```ruby
serializer = User.serializer

# Serialize 'john' to dense JSON (a Ruby Array/Hash structure).
john_dense_json = serializer.to_json(john)
raise unless john_dense_json.is_a?(Array)

# to_json_code returns a JSON string.
john_dense_json_code = serializer.to_json_code(john)
raise unless john_dense_json_code.start_with?("[")

# Serialize 'john' to readable JSON.
puts serializer.to_json_code(john, readable: true)
# {
#   "user_id": 42,
#   "name": "John Doe",
#   "quote": "Coffee is just a socially acceptable form of rage.",
#   "pets": [
#     {
#       "name": "Dumbo",
#       "height_in_meters": 1.0,
#       "picture": "🐘"
#     }
#   ],
#   "subscription_status": "free"
# }

# Serialize 'john' to binary format.
john_bytes = serializer.to_bytes(john)
```

#### Deserialization

```ruby
# Use from_json, from_json_code, and from_bytes to deserialize.
raise unless john == serializer.from_json(john_dense_json)
raise unless john == serializer.from_json_code(john_dense_json_code)
raise unless john == serializer.from_json_code(serializer.to_json_code(john, readable: true))
raise unless john == serializer.from_bytes(john_bytes)
```

#### Primitive and composite serializers

```ruby
raise unless Skir.primitive_serializer("bool").to_json(true) == 1
raise unless Skir.primitive_serializer("int32").to_json(3) == 3
raise unless Skir.primitive_serializer("int64").to_json(9_223_372_036_854_775_807) == "9223372036854775807"
raise unless Skir.primitive_serializer("hash64").to_json(18_446_744_073_709_551_615) == "18446744073709551615"
raise unless Skir.primitive_serializer("timestamp").to_json(Time.at(1_743_682_787).utc) == 1_743_682_787_000
raise unless Skir.primitive_serializer("float32").to_json(3.14) == 3.14
raise unless Skir.primitive_serializer("float64").to_json(3.14) == 3.14
raise unless Skir.primitive_serializer("string").to_json("Foo") == "Foo"
raise unless Skir.primitive_serializer("bytes").to_json([1, 2, 3].pack("C*")) == "AQID"

raise unless Skir.optional_serializer(Skir.primitive_serializer("string")).to_json("foo") == "foo"
raise unless Skir.optional_serializer(Skir.primitive_serializer("string")).to_json(nil).nil?
raise unless Skir.array_serializer(Skir.primitive_serializer("bool")).to_json([true, false]) == [1, 0]
```

### Keyed arrays

```ruby
user_registry = UserRegistry.new(users: [john, jane, lyla_mut])

# 'user_registry.users' is an instance of Skir::KeyedItems[User, Integer]
# which has methods for finding items by key.

raise unless user_registry.users.find(42) == john
raise unless user_registry.users.find(100).nil?

raise unless user_registry.users.find_or_default(42).name == "John Doe"
raise unless user_registry.users.find_or_default(100).name == ""

# The first lookup runs in O(N) time, and following lookups run in O(1) time.
```

### SkirRPC services

#### Starting a SkirRPC service

`Skir::Service` integrates with any Ruby web framework (Rack, Sinatra, Rails, etc.):

```ruby
service = Skir::Service.new
service.add_method(GetUser) do |req, req_meta|
  # Return response
end

# In your HTTP handler:
raw_response = service.handle_request(request_body, request_headers)
# Return raw_response.data with status raw_response.status_code and Content-Type raw_response.content_type
```

#### Sending RPCs with `Skir::ServiceClient`

```ruby
client = Skir::ServiceClient.new("http://localhost:8080/api")
response = client.invoke_remote(
  GetUser,
  GetUserRequest.new(user_id: 42),
  { "Authorization" => "Bearer token" }
)
```

### Reflection

Reflection allows you to inspect a Skir type at runtime:

```ruby
user_type_descriptor = User.serializer.type_descriptor

puts user_type_descriptor.as_json_code

# A TypeDescriptor can be serialized and deserialized.
raise unless user_type_descriptor == Skir::Reflection::TypeDescriptor.from_json_code(
  user_type_descriptor.as_json_code
)
```
