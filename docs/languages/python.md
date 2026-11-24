[![npm](https://img.shields.io/npm/v/skir-python-gen)](https://www.npmjs.com/package/skir-python-gen)
[![build](https://github.com/gepheum/skir-python-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-python-gen/actions)

# Skir's Python code generator

Official plugin for generating Python code from [.skir](https://github.com/gepheum/skir) files.

Targets Python 3.10 and higher.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:
```yaml
  - mod: skir-python-gen
    outDir: ./src/skirout
    config: {}
```

The generated Python code has a runtime dependency on the `skir-client` library. Install it with:

```shell
pip install skir-client
```

For more information, see this Python project [example](https://github.com/gepheum/skir-python-example).

## Python generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-python-example/blob/main/skir_src/user.skir) .skir file.

### Referring to generated symbols

```python
# Import the given symbols from the Python module generated from "user.skir"
from skirout.user_skir import TARZAN, SubscriptionStatus, User, UserHistory, UserRegistry
```

### Struct classes

For every struct `S` in the .skir file, skir generates a frozen (deeply immutable) class `S` and a mutable class `S.Mutable`.

#### Frozen struct classes

```python
# To construct a frozen User, either call the User constructor or the
# User.partial() static factory method.

john = User(
    user_id=42,
    name="John Doe",
    quote="Coffee is just a socially acceptable form of rage.",
    pets=[
        User.Pet(
            name="Dumbo",
            height_in_meters=1.0,
            picture="🐘",
        ),
    ],
    subscription_status=SubscriptionStatus.FREE,
    # foo="bar",
    # Does not compile: 'foo' is not a field of User
)

assert john.name == "John Doe"

# Lists passed to the constructor or partial() are copied into tuples to ensure
# deep immutability.
assert isinstance(john.pets, tuple)

# Static type checkers will raise an error if you try to modify a frozen struct:
# john.name = "John Smith"

# With 'User.partial()', you don't need to specify all the fields of the struct.
jane = User.partial(
    user_id=43,
    name="Jane Doe",
)

# Missing fields are initialized to their default values.
assert jane.quote == ""

# 'User.DEFAULT' is a constant holding the result of calling 'User.partial()'
# with no arguments.
assert User.DEFAULT == User.partial()
```

#### Mutable struct classes

```python
# User.Mutable is a mutable version of User.
lyla_mut = User.Mutable()
lyla_mut.user_id = 44
lyla_mut.name = "Lyla Doe"

# You can also set fields in the constructor.
joly_mut = User.Mutable(user_id=45)
joly_mut.name = "Joly Doe"

joly_history_mut = UserHistory.Mutable()
joly_history_mut.user = joly_mut
# ^ The right-hand side of the assignment can be either frozen or mutable.

# joly_history_mut.user.quote = "I am Joly."
# ^ Static error: quote is readonly because joly_history_mut.user may be frozen

# The mutable_user() property first checks if 'user' is already a mutable
# struct, and if so, returns it. Otherwise, it assigns to 'user' a mutable
# shallow copy of itself and returns it.
joly_history_mut.mutable_user.quote = "I am Joly."

# Similarly, mutable_pets() first checks if 'pets' is already a mutable array,
# and if so, returns it. Otherwise, it assigns to 'pets' a mutable shallow copy
# of itself and returns it.
lyla_mut.mutable_pets.append(User.Pet.partial(name="Cupcake"))
lyla_mut.mutable_pets.append(User.Pet.Mutable(name="Simba"))
```

#### Converting between frozen and mutable

```python
# to_mutable() does a shallow copy of the frozen struct, so it's cheap. All the
# properties of the copy hold a frozen value.
evil_jane_mut = jane.to_mutable()
evil_jane_mut.name = "Evil Jane"

# to_frozen() recursively copies the mutable values held by properties of the
# object. It's cheap if all the values are frozen, like in this example.
evil_jane: User = evil_jane_mut.to_frozen()

# You can also call replace() on the frozen struct.
evil_jane = evil_jane.replace(name="Evil Jane")
# Same as:
#   evil_jane_mut = evil_jane.to_mutable()
#   evil_jane_mut.name = "Evil Jane"
#   evil_jane = evil_jane_mut.to_frozen()

assert evil_jane.user_id == 43
```

#### Writing logic agnostic of mutability

```python
# 'User.OrMutable' is a type alias for 'User | User.Mutable'.
def greet(user: User.OrMutable):
    print(f"Hello, {user.name}")


greet(jane)
# Hello, Jane Doe
greet(lyla_mut)
# Hello, Lyla Doe
```

### Enum classes

The definition of the `SubscriptionStatus` enum in the .skir file is:
```rust
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

#### Making enum values

```python
john_status = SubscriptionStatus.FREE
jane_status = SubscriptionStatus.PREMIUM

joly_status = SubscriptionStatus.UNKNOWN

# Use wrap_*() for wrapper variants.
roni_status = SubscriptionStatus.wrap_trial(
    SubscriptionStatus.Trial(
        start_time=skir.Timestamp.from_unix_millis(1744974198000),
    )
)

# If the wrapped value is a field, you can use create_*(...) instead of
# wrap_*(Struct(...))
assert roni_status == SubscriptionStatus.create_trial(
    start_time=skir.Timestamp.from_unix_millis(1744974198000)
)
```

#### Conditions on enums

```python
# Use 'union.kind' to check which variant the enum value holds.
assert john_status.union.kind == "FREE"

# Static type checkers will complain: "RED" not in the enum definition.
# assert jane_status.union.kind == "RED"

assert joly_status.union.kind == "UNKNOWN"

assert roni_status.union.kind == "trial"
# If the enum holds a wrapper variant, you can access the wrapped value through
# 'union.value'.
assert isinstance(roni_status.union.value, SubscriptionStatus.Trial)


def get_subscription_info_text(status: SubscriptionStatus) -> str:
    # Pattern matching on enum variants
    if status.union.kind == "UNKNOWN":
        return "Unknown subscription status"
    elif status.union.kind == "FREE":
        return "Free user"
    elif status.union.kind == "trial":
        # Here the compiler knows that the type of 'union.value' is
        # 'SubscriptionStatus.Trial'
        trial = status.union.value
        return f"On trial since {trial.start_time}"
    elif status.union.kind == "PREMIUM":
        return "Premium user"

    # Static type checkers will error if any case is missed.
    _: Never = status.union.kind
    raise AssertionError("Unreachable code")
```

### Serialization

Every frozen struct class and enum class has a static readonly `serializer` property which can be used for serializing and deserializing instances of the class.

```python
serializer = User.serializer

# Serialize 'john' to dense JSON.

john_dense_json = serializer.to_json(john)

# With dense JSON, structs are encoded as JSON arrays
assert isinstance(john_dense_json, list)

# to_json_code() returns a string containing the JSON code.
# Equivalent to calling json.dumps() on to_json()'s result.
john_dense_json_code: str = serializer.to_json_code(john)
assert john_dense_json_code.startswith("[")

# Serialize 'john' to readable JSON.
print(serializer.to_json_code(john, readable=True))
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
#   "subscription_status": "FREE"
# }

# The dense JSON flavor is the flavor you should pick if you intend to
# deserialize the value in the future. Skir allows fields to be renamed, and
# because fields names are not part of the dense JSON, renaming a field does
# not prevent you from deserializing the value.
# You should pick the readable flavor mostly for debugging purposes.
```

### Deserialization

```python
# Use from_json() and from_json_code() to deserialize.

assert john == serializer.from_json(serializer.to_json(john))

assert john == serializer.from_json_code(serializer.to_json_code(john))

# Also works with readable JSON.
assert john == serializer.from_json_code(  #
    serializer.to_json_code(john, readable=True)
)
```

### Primitive serializers

```python
assert skir.primitive_serializer("bool").to_json(True) == 1
assert skir.primitive_serializer("int32").to_json(3) == 3
assert (
    skir.primitive_serializer("int64").to_json(9223372036854775807)
    == "9223372036854775807"
)
assert (
    skir.primitive_serializer("hash64").to_json(18446744073709551615)
    == "18446744073709551615"
)
assert (
    skir.primitive_serializer("timestamp").to_json(
        skir.Timestamp.from_unix_millis(1743682787000)
    )
    == 1743682787000
)
assert skir.primitive_serializer("float32").to_json(3.14) == 3.14
assert skir.primitive_serializer("float64").to_json(3.14) == 3.14
assert skir.primitive_serializer("string").to_json("Foo") == "Foo"
assert skir.primitive_serializer("bytes").to_json(bytes([1, 2, 3])) == "AQID"
```

### Composite serializers

```python
assert (
    skir.optional_serializer(skir.primitive_serializer("string")).to_json("foo")
    == "foo"
)
assert (
    skir.optional_serializer(skir.primitive_serializer("string")).to_json(None) is None
)

assert skir.array_serializer(skir.primitive_serializer("bool")).to_json(
    (True, False)
) == [1, 0]
```

### Keyed arrays

```python
user_registry = UserRegistry(users=[john, jane, lyla_mut])

# 'user_registry.users' is an instance of a subclass of tuple[User, ...] which
# has methods for finding items by key.

assert user_registry.users.find(42) == john
assert user_registry.users.find(100) is None

assert user_registry.users.find_or_default(42).name == "John Doe"
assert user_registry.users.find_or_default(100).name == ""

# The first lookup runs in O(N) time, and the following lookups run in O(1)
# time.
```

### Constants

```python
print(TARZAN)
# User(
#   user_id=123,
#   name='Tarzan',
#   quote='AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA',
#   pets=[
#     User.Pet(
#       name='Cheeta',
#       height_in_meters=1.67,
#       picture='🐒',
#     ),
#   ],
#   subscription_status=SubscriptionStatus.wrap_trial(
#     SubscriptionStatus.Trial(
#       start_time=Timestamp(
#         unix_millis=1743592409000,
#         _formatted='2025-04-02T11:13:29Z',
#       ),
#     )
#   ),
# )
```

### SkirRPC services

#### Starting a SkirRPC service on an HTTP server

Examples:
- [Flask](https://github.com/gepheum/skir-python-example/blob/main/start_service_flask.py)
- [FastAPI](https://github.com/gepheum/skir-python-example/blob/main/start_service_fastapi.py)
- [Litestar](https://github.com/gepheum/skir-python-example/blob/main/start_service_starlite.py)

#### Sending RPCs to a SkirRPC service

Full example [here](https://github.com/gepheum/skir-python-example/blob/main/call_service.py).

### Reflection

Reflection allows you to inspect a skir type at runtime.

```python
field_names: list[str] = []

user_type_descriptor = User.serializer.type_descriptor

# 'user_type_descriptor' has information about User and all the types it
# depends on.

print(user_type_descriptor.as_json_code())
# {
#   "type": {
#     "kind": "record",
#     "value": "user.skir:User"
#   },
#   "records": [
#     {
#       "kind": "struct",
#       "id": "user.skir:User",
#       "fields": [
#         {
#           "name": "user_id",
#           "type": {
#             "kind": "primitive",
#             "value": "int64"
#           },
#           "number": 0
#         },
#          ...
#         {
#           "name": "pets",
#           "type": {
#             "kind": "array",
#             "value": {
#               "item": {
#                 "kind": "record",
#                 "value": "user.skir:User.Pet"
#               }
#             }
#           },
#           "number": 3
#         },
#         ...
#       ]
#     },
#     {
#       "kind": "struct",
#       "id": "user.skir:User.Pet",
#       ...
#     },
#     ...
#   ]
# }

# A TypeDescriptor can be serialized and deserialized.
assert user_type_descriptor == skir.reflection.TypeDescriptor.from_json_code(
    user_type_descriptor.as_json_code()
)
```

