# typed: strict
# frozen_string_literal: true

# Code snippets showing how to use Ruby-generated data classes.
#
# Run with:
#   bundle exec ruby snippets.rb

require "sorbet-runtime"
require "skir"
require_relative "skirout/user_skir"

module Snippets
  extend T::Sig

  User = Skirout::UserSkir::User
  UserHistory = Skirout::UserSkir::UserHistory
  UserRegistry = Skirout::UserSkir::UserRegistry
  SubscriptionStatus = Skirout::UserSkir::SubscriptionStatus
  TARZAN = Skirout::UserSkir::TARZAN

  # 'User::OrMutable' is a type alias for 'T.any(User, User::Mutable)'.
  sig { params(user: User::OrMutable).void }
  def self.greet(user)
    puts "Hello, #{user.name}"
  end

  sig { params(status: SubscriptionStatus).returns(String) }
  def self.get_subscription_info_text(status)
    # Pattern matching on enum variants with Sorbet exhaustiveness checking
    kind = status.kind
    case kind
    when SubscriptionStatus::Kind::UNKNOWN
      "Unknown subscription status"
    when SubscriptionStatus::Kind::FREE
      "Free user"
    when SubscriptionStatus::Kind::PREMIUM
      "Premium user"
    when SubscriptionStatus::Kind::TRIAL
      trial = status.as_trial
      "On trial since #{trial.start_time}"
    else
      # Sorbet will report a static type error if any case is missed.
      T.absurd(kind)
    end
  end

  sig { void }
  def self.run
    # FROZEN STRUCT CLASSES
    #
    # For every struct S in the .skir file, skir generates a frozen (deeply
    # immutable) class 'S' and a mutable class 'S::Mutable'.
    #
    # To construct a frozen User, either call User.new or User.partial.

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
      # ^ Does not typecheck: 'foo' is not a field of User
    )

    raise unless john.name == "John Doe"

    # Lists passed to User.new or User.partial are copied and frozen to ensure
    # deep immutability.
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

    # MUTABLE STRUCT CLASSES

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

    # The mutable_user getter first checks if 'user' is already a mutable
    # struct, and if so, returns it. Otherwise, it assigns to 'user' a mutable
    # shallow copy of itself and returns it.
    joly_history_mut.mutable_user.quote = "I am Joly."

    # Similarly, mutable_pets first checks if 'pets' is already a mutable array,
    # and if so, returns it. Otherwise, it assigns to 'pets' a mutable shallow copy
    # of itself and returns it.
    lyla_mut.mutable_pets << User::Pet.partial(name: "Cupcake")
    lyla_mut.mutable_pets << User::Pet::Mutable.new(name: "Simba")

    # CONVERTING BETWEEN FROZEN AND MUTABLE

    # to_mutable does a shallow copy of the frozen struct, so it's cheap. All the
    # properties of the copy hold a frozen value.
    evil_jane_mut = jane.to_mutable
    evil_jane_mut.name = "Evil Jane"

    # to_frozen recursively copies the mutable values held by properties of the
    # object. It's cheap if all the values are frozen, like in this example.
    evil_jane = T.let(evil_jane_mut.to_frozen, User)

    # You can also call replace on the frozen struct.
    evil_jane = evil_jane.replace(name: "Evil Jane")

    raise unless evil_jane.user_id == 43

    # WRITING LOGIC AGNOSTIC OF MUTABILITY

    greet(jane)
    # Hello, Jane Doe
    greet(lyla_mut)
    # Hello, Lyla Doe

    # MAKING ENUM VALUES

    john_status = SubscriptionStatus::FREE
    _jane_status = SubscriptionStatus::PREMIUM
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

    # CONDITIONS ON ENUMS

    # For constant variants, compare directly with '==':
    raise unless john_status == SubscriptionStatus::FREE
    raise unless joly_status == SubscriptionStatus::UNKNOWN

    # For wrapper variants, use 'is_<variant>?' and 'as_<variant>':
    raise unless roni_status.is_trial?
    raise unless roni_status.as_trial.start_time == Time.at(1_744_974_198).utc

    # Or inspect 'kind' (a Sorbet T::Enum):
    raise unless john_status.kind == SubscriptionStatus::Kind::FREE
    raise unless joly_status.kind == SubscriptionStatus::Kind::UNKNOWN
    raise unless roni_status.kind == SubscriptionStatus::Kind::TRIAL

    raise unless get_subscription_info_text(john_status) == "Free user"
    raise unless get_subscription_info_text(roni_status).start_with?("On trial since ")

    # SERIALIZATION

    serializer = User.serializer

    # Serialize 'john' to dense JSON.
    john_dense_json = serializer.to_json(john)

    # With dense JSON, structs are encoded as JSON arrays
    raise unless john_dense_json.is_a?(Array)

    # to_json_code returns a string containing the JSON code.
    john_dense_json_code = T.let(serializer.to_json_code(john), String)
    raise unless john_dense_json_code.start_with?("[")

    # Serialize 'john' to readable JSON.
    puts serializer.to_json_code(john, readable: true)

    # DESERIALIZATION

    # Use from_json, from_json_code, and from_bytes to deserialize.
    raise unless john == serializer.from_json(john_dense_json)
    raise unless john == serializer.from_json_code(john_dense_json_code)

    # Also works with readable JSON.
    raise unless john == serializer.from_json_code(
      serializer.to_json_code(john, readable: true)
    )

    # Also works with binary format.
    john_bytes = serializer.to_bytes(john)
    raise unless john == serializer.from_bytes(john_bytes)

    # PRIMITIVE SERIALIZERS

    raise unless Skir.primitive_serializer("bool").to_json(true) == 1
    raise unless Skir.primitive_serializer("int32").to_json(3) == 3
    raise unless Skir.primitive_serializer("int64").to_json(9_223_372_036_854_775_807) == "9223372036854775807"
    raise unless Skir.primitive_serializer("hash64").to_json((1 << 64) - 1) == "18446744073709551615"
    raise unless Skir.primitive_serializer("timestamp").to_json(Time.at(1_743_682_787).utc) == 1_743_682_787_000
    raise unless Skir.primitive_serializer("float32").to_json(3.14) == 3.14
    raise unless Skir.primitive_serializer("float64").to_json(3.14) == 3.14
    raise unless Skir.primitive_serializer("string").to_json("Foo") == "Foo"
    raise unless Skir.primitive_serializer("bytes").to_json([1, 2, 3].pack("C*")) == "AQID"

    # COMPOSITE SERIALIZERS

    raise unless Skir.optional_serializer(Skir.primitive_serializer("string")).to_json("foo") == "foo"
    raise unless Skir.optional_serializer(Skir.primitive_serializer("string")).to_json(nil).nil?
    raise unless Skir.array_serializer(Skir.primitive_serializer("bool")).to_json([true, false]) == [1, 0]

    # KEYED ARRAYS

    user_registry = UserRegistry.new(users: [john, jane, lyla_mut])

    # 'user_registry.users' is an instance of Skir::KeyedItems[User, Integer]
    # which has methods for finding items by key.
    raise unless user_registry.users.find(42) == john
    raise unless user_registry.users.find(100).nil?

    raise unless user_registry.users.find_or_default(42).name == "John Doe"
    raise unless user_registry.users.find_or_default(100).name == ""

    # CONSTANTS

    puts TARZAN

    # REFLECTION

    user_type_descriptor = User.serializer.type_descriptor
    puts user_type_descriptor.as_json_code

    # A TypeDescriptor can be serialized and deserialized.
    raise unless user_type_descriptor == Skir::Reflection::TypeDescriptor.from_json_code(
      user_type_descriptor.as_json_code
    )
  end
end

Snippets.run if __FILE__ == $PROGRAM_NAME
