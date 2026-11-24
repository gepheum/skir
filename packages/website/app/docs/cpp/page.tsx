import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'C++ - Skir Documentation',
  description: 'Learn how to use Skir-generated C++ code in your projects',
}

export default function CppPage() {
  return (
    <Prose>
      <H1>C++</H1>
      <P>This guide explains how to use Skir in a C++ project. Targets C++17 and higher.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-cc-gen
  outDir: ./src/skirout
  config:
    writeGoogleTestHeaders: true  # If you use GoogleTest`}</CodeBlock>

      <H2>Runtime dependencies</H2>
      <P>
        The generated C++ code depends on the{' '}
        <a
          href="https://github.com/gepheum/skir-cc-gen/tree/main/client"
          target="_blank"
          rel="noopener noreferrer"
        >
          skir client library
        </a>
        ,{' '}
        <a href="https://abseil.io/" target="_blank" rel="noopener noreferrer">
          absl
        </a>{' '}
        and optionally{' '}
        <a href="https://github.com/google/googletest" target="_blank" rel="noopener noreferrer">
          GoogleTest
        </a>
        .
      </P>
      <P>
        Add this to your <InlineCode>CMakeLists.txt</InlineCode>:
      </P>
      <CodeBlock language="cmake">{`include(FetchContent)

FetchContent_Declare(
  skir-client
  GIT_REPOSITORY https://github.com/gepheum/skir-cc-gen.git
  GIT_TAG        main  # Or pick a specific commit/tag
  SOURCE_SUBDIR  client
)
FetchContent_MakeAvailable(skir-client)`}</CodeBlock>
      <P>
        See this{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/CMakeLists.txt"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>Generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/skir_src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <P>
        Every generated symbol lives in a namespace called{' '}
        <InlineCode>skirout_$&#123;path&#125;</InlineCode>, where{' '}
        <InlineCode>$&#123;path&#125;</InlineCode> is the path to the .skir file relative from the
        root of the skir source directory, with the ".skir" extension removed, and slashes replaced
        with underscores.
      </P>
      <CodeBlock language="cpp">{`#include "skirout/user.h"

using ::skirout_user::SubscriptionStatus;
using ::skirout_user::User;
using ::skirout_user::UserRegistry;`}</CodeBlock>

      <H3>Structs</H3>
      <CodeBlock language="cpp">{`// You can construct a struct like this:
User john;
john.user_id = 42;
john.name = "John Doe";

// Or you can use the designated initialized syntax:
User jane = {
    // Keep fields in alphabetical order
    .name = "Jane Doe",
    .pets = {{
                  .name = "Fluffy",
                  .picture = "cat",
              },
              {
                  .name = "Rex",
                  .picture = "dog",
              }},
    .subscription_status = skirout::kPremium,
    .user_id = 43,
};

// \${Struct}::whole forces you to initialize all the fields of the struct.
// You will get a compile-time error if you miss one.
User lyla = User::whole{
    .name = "Lyla Doe",
    .pets =
        {
            User::Pet::whole{
                .height_in_meters = 0.05f,
                .name = "Tiny",
                .picture = "🐁",
            },
        },
    .quote = "This is Lyla's world, you just live in it",
    .subscription_status = skirout::kFree,
    .user_id = 44,
};`}</CodeBlock>

      <H3>Constructing enums</H3>
      <CodeBlock language="cpp">{`// Use skirout::\${kFieldName} or \${Enum}::\${kFieldName} for constant variants.
SubscriptionStatus john_status = skirout::kFree;
SubscriptionStatus jane_status = skirout::kPremium;
SubscriptionStatus lara_status = SubscriptionStatus::kFree;

// Compilation error: MONDAY is not a field of the SubscriptionStatus enum.
// SubscriptionStatus sara_status = skirout::kMonday;

// Use wrap_\${field_name} for wrapper variants.
SubscriptionStatus jade_status =
    skirout::wrap_trial(SubscriptionStatus::Trial({
        .start_time = absl::FromUnixMillis(1743682787000),
    }));
SubscriptionStatus roni_status = SubscriptionStatus::wrap_trial({
    .start_time = absl::FromUnixMillis(1743682787000),
});`}</CodeBlock>

      <H4>Conditions on enums</H4>
      <CodeBlock language="cpp">{`if (john_status == skirout::kFree) {
  std::cout << "John, would you like to upgrade to premium?\\n";
}

// Call is_\${field_name}() to check if the enum holds a wrapper variant.
if (jade_status.is_trial()) {
  // as_\${field_name}() returns the wrapped value
  const SubscriptionStatus::Trial& trial = jade_status.as_trial();
  std::cout << "Jade's trial started on " << trial.start_time << "\\n";
}

// One way to do an exhaustive switch on an enum.
switch (lara_status.kind()) {
  case SubscriptionStatus::kind_type::kUnknown:
    // unknown is the default value for an uninitialized SubscriptionStatus.
    // ...
    break;
  case SubscriptionStatus::kind_type::kFreeConst:
    // ...
    break;
  case SubscriptionStatus::kind_type::kPremiumConst:
    // ...
    break;
  case SubscriptionStatus::kind_type::kTrialWrapper: {
    const SubscriptionStatus::Trial& trial = lara_status.as_trial();
    std::cout << "Lara's trial started on " << trial.start_time << "\\n";
  }
}

// Another way to do an exhaustive switch using the visitor pattern.
struct Visitor {
  void operator()(skirout::k_unknown) const {
    std::cout << "Lara's subscription status is UNKNOWN\\n";
  }
  void operator()(skirout::k_free) const {
    std::cout << "Lara's subscription status is FREE\\n";
  }
  void operator()(skirout::k_premium) const {
    std::cout << "Lara's subscription status is PREMIUM\\n";
  }
  void operator()(SubscriptionStatus::wrap_trial_type& w) const {
    const SubscriptionStatus::Trial& trial = w.value;
    std::cout << "Lara's trial started on " << trial.start_time << "\\n";
  }
};
lara_status.visit(Visitor());`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        Use <InlineCode>ToDenseJson</InlineCode>, <InlineCode>ToReadableJson</InlineCode> or{' '}
        <InlineCode>ToBytes</InlineCode> to serialize a skir value.
      </P>
      <CodeBlock language="cpp">{`// Serialize a skir value to JSON with ToDenseJson or ToReadableJson.
std::string john_dense_json = skir::ToDenseJson(john);
std::cout << john_dense_json << "\\n";
// [42,"John Doe"]

std::cout << skir::ToReadableJson(john) << "\\n";
// {
//   "user_id": 42,
//   "name": "John Doe"
// }

// The dense flavor is the flavor you should pick if you intend to
// deserialize the value in the future. Skir allows fields to be renamed, and
// because fields names are not part of the dense JSON, renaming a field does
// not prevent you from deserializing the value.
// You should pick the readable flavor mostly for debugging purposes.

// The binary format is not human readable, but it is a bit more compact than
// JSON, and serialization/deserialization can be a bit faster.
// Only use it when this small performance gain is likely to matter, which
// should be rare.
skir::ByteString john_bytes = skir::ToBytes(john);`}</CodeBlock>

      <H4>Deserialization</H4>
      <P>
        Use <InlineCode>Parse</InlineCode> to deserialize a skir value from JSON or binary format.
      </P>
      <CodeBlock language="cpp">{`// Use Parse to deserialize a skir value from JSON or binary format.
absl::StatusOr<User> reserialized_john = skir::Parse<User>(john_dense_json);
assert(reserialized_john.ok() && *reserialized_john == john);

reserialized_john = skir::Parse<User>(john_bytes.as_string());
assert(reserialized_john.ok() && *reserialized_john == john);`}</CodeBlock>

      <H4>Primitive serializers</H4>
      <CodeBlock language="cpp">{`// Skir type: bool
assert(skir::ToDenseJson(true) == "1");
// Skir type: int32
assert(skir::ToDenseJson(int32_t{3}) == "3");
// Skir type: int64
assert(skir::ToDenseJson(int64_t{9223372036854775807}) ==
       "\\"9223372036854775807\\"");
// Skir type: hash64
assert(skir::ToDenseJson(uint64_t{18446744073709551615ULL}) ==
       "\\"18446744073709551615\\"");
// Skir type: timestamp
assert(skir::ToDenseJson(absl::FromUnixMillis(1743682787000)) ==
       "1743682787000");
// Skir type: float32
assert(skir::ToDenseJson(3.14f) == "3.14");
// Skir type: float64
assert(skir::ToDenseJson(3.14) == "3.14");
// Skir type: string
assert(skir::ToDenseJson(std::string("Foo")) == "\\"Foo\\"");
// Skir type: bytes
assert(skir::ToDenseJson(skir::ByteString("\\x01\\x02\\x03")) == "\\"AQID\\"");`}</CodeBlock>

      <H4>Composite serializers</H4>
      <CodeBlock language="cpp">{`// Skir type: string?
assert(skir::ToDenseJson(std::optional<std::string>("foo")) == "\\"foo\\"");
assert(skir::ToDenseJson(std::optional<std::string>()) == "null");

// Skir type: [bool]
assert(skir::ToDenseJson(std::vector<bool>{true, false}) == "[1,0]");`}</CodeBlock>

      <H3>Keyed arrays</H3>
      <P>
        A <InlineCode>keyed_items&lt;T, get_key&gt;</InlineCode> is a container that stores items of
        type T and allows for fast lookups by key using a hash table.
      </P>
      <CodeBlock language="cpp">{`UserRegistry user_registry;
skir::keyed_items<User, skirout::get_user_id<>>&
    users = user_registry.users;
users.push_back(john);
users.push_back(jane);
users.push_back(lyla);

assert(users.size() == 3);
assert(users[0] == john);

const User* maybe_jane = users.find_or_null(43);
assert(maybe_jane != nullptr && *maybe_jane == jane);

assert(users.find_or_default(44).name == "Lyla Doe");
assert(users.find_or_default(45).name == "");

// If multiple items have the same key, find_or_null and find_or_default
// return the last one. Duplicates are allowed but generally discouraged.
User evil_lyla = lyla;
evil_lyla.name = "Evil Lyla";
users.push_back(evil_lyla);
assert(users.find_or_default(44).name == "Evil Lyla");`}</CodeBlock>

      <H4>Equality and hashing</H4>
      <P>Skir structs and enums are equality comparable and hashable.</P>
      <CodeBlock language="cpp">{`absl::flat_hash_set<User> user_set;
user_set.insert(john);
user_set.insert(jane);
user_set.insert(jane);
user_set.insert(lyla);

assert(user_set.size() == 3);`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="cpp">{`const User& tarzan = skirout_user::k_tarzan();
assert(tarzan.name == "Tarzan");`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <P>
        <strong>Starting a SkirRPC service on an HTTP server</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/service_start.cc"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>
      <P>
        <strong>Sending RPCs to a SkirRPC service</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/service_client.cc"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Dynamic reflection</H3>
      <CodeBlock language="cpp">{`using ::skir::reflection::GetTypeDescriptor;
using ::skir::reflection::TypeDescriptor;

// A TypeDescriptor describes a skir type. It contains the definition of all
// the structs and enums referenced from the type.
const TypeDescriptor& user_descriptor = GetTypeDescriptor<User>();

// TypeDescriptor can be serialized/deserialized to/from JSON.
absl::StatusOr<TypeDescriptor> reserialized_type_descriptor =
    TypeDescriptor::FromJson(user_descriptor.AsJson());
assert(reserialized_type_descriptor.ok());`}</CodeBlock>

      <H3>Static reflection</H3>
      <P>
        Static reflection allows you to inspect and modify values of generated skir types in a
        typesafe manner.
      </P>
      <P>
        See{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/string_capitalizer.h"
          target="_blank"
          rel="noopener noreferrer"
        >
          string_capitalizer.h
        </a>
        .
      </P>
      <CodeBlock language="cpp">{`User tarzan_copy = skirout_user::k_tarzan();
// CapitalizeStrings recursively capitalizes all the strings found within a
// skir value.
CapitalizeStrings(tarzan_copy);

std::cout << tarzan_copy << "\\n";
// {
//   .user_id: 123,
//   .name: "TARZAN",
//   .quote: "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
//   .pets: {
//     {
//       .name: "CHEETA",
//       .height_in_meters: 1.67,
//       .picture: "🐒",
//     },
//   },
//   .subscription_status:
//   ::skirout::wrap_trial_start_time(absl::FromUnixMillis(1743592409000 /*
//   2025-04-02T11:13:29+00:00 */)),
// }`}</CodeBlock>

      <H3>Writing unit tests with GoogleTest</H3>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-cc-example/blob/main/example.test.cc"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H4>Struct matchers</H4>
      <CodeBlock language="cpp">{`const User john = {
    .name = "John Doe",
    .pets =
        {
            {.height_in_meters = 1.67, .name = "Cheeta", .picture = "🐒"},
        },
    .quote = "Life is like a box of chocolates.",
    .user_id = 42,
};

EXPECT_THAT(john, (StructIs<User>{
                      // Only the specified fields are tested
                      .pets = testing::ElementsAre(StructIs<User::Pet>{
                          .height_in_meters = testing::FloatNear(1.7, 0.1),
                      }),
                      .quote = testing::StartsWith("Life is"),
                      .user_id = 42,
                  }));`}</CodeBlock>

      <H4>Enum matchers</H4>
      <CodeBlock language="cpp">{`SubscriptionStatus john_status = skirout::kFree;

EXPECT_THAT(john_status, testing::Eq(skirout::kFree));

SubscriptionStatus jade_status = SubscriptionStatus::wrap_trial(
    {.start_time = absl::FromUnixMillis(1743682787000)});

EXPECT_THAT(jade_status, IsTrial());
EXPECT_THAT(jade_status, IsTrial(StructIs<SubscriptionStatus::Trial>{
                             .start_time = testing::Gt(absl::UnixEpoch())}));`}</CodeBlock>
    </Prose>
  )
}
