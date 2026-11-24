import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Go - Skir Documentation',
  description: 'Learn how to use Skir-generated Go code in your projects',
}

export default function GoPage() {
  return (
    <Prose>
      <H1>Go</H1>
      <P>This guide explains how to use Skir in a Go project.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-go-gen
  outDir: ./skirout
  config:
    goModuleName: "github.com/my-org/my-project"`}</CodeBlock>
      <P>
        The <InlineCode>goModuleName</InlineCode> config option must match the module name declared
        in your <InlineCode>go.mod</InlineCode> file.
      </P>
      <P>
        The generated Go code has a runtime dependency on the{' '}
        <InlineCode>skir-go-client</InlineCode> module. Add it to your project with:
      </P>
      <CodeBlock language="bash">{`go get github.com/gepheum/skir-go-client`}</CodeBlock>
      <P>
        For more information, see this Go project{' '}
        <a
          href="https://github.com/gepheum/skir-go-example"
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
          href="https://github.com/gepheum/skir-go-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <CodeBlock language="go">{`// Import the Go package generated from "user.skir".
// Replace "github.com/my-org/my-project" with your own module name.
import user "github.com/my-org/my-project/skirout/user"

// Now you can use: user.User_builder(), user.Tarzan_const(),
// user.SubscriptionStatus_freeConst(), user.User_serializer(), etc.`}</CodeBlock>

      <H3>Struct types</H3>
      <P>
        Skir generates a deeply immutable Go interface for every struct in the .skir file. The
        generated code provides both ordered and partial builders.
      </P>
      <CodeBlock language="go">{`// Ordered builder: all fields must be set in alphabetical order.
// The compiler errors if you skip a field or set them out of order.
john := user.User_builder().
    SetName("John Doe").
    SetPets([]user.User_Pet{
        user.User_Pet_builder().
            SetHeightInMeters(1.0).
            SetName("Dumbo").
            SetPicture("🐘").
            Build(),
    }).
    SetQuote("Coffee is just a socially acceptable form of rage.").
    SetSubscriptionStatus(user.SubscriptionStatus_freeConst()).
    SetUserId(42).
    Build()

fmt.Println(john.Name()) // John Doe

// Partial builder: fields can be set in any order.
// Fields not explicitly set are initialized to their zero values.
jane := user.User_partialBuilder().SetUserId(43).SetName("Jane Doe").Build()

fmt.Println(jane.Quote())      // (empty string)
fmt.Println(jane.Pets().Len()) // 0

// User_default returns an instance with all fields set to their zero values.
fmt.Println(user.User_default().Name())   // (empty string)
fmt.Println(user.User_default().UserId()) // 0`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="go">{`// ToBuilder copies all fields into a new partial builder.
// Useful for creating modified copies without mutating the original.
evilJohn := john.ToBuilder().
    SetName("Evil John").
    SetQuote("I solemnly swear I am up to no good.").
    Build()

fmt.Println(evilJohn.Name())   // Evil John
fmt.Println(evilJohn.UserId()) // 42 (copied from john)
fmt.Println(john.Name())       // John Doe (john is unchanged)`}</CodeBlock>

      <H3>Enum types</H3>
      <P>
        Skir generates a Go struct type for every enum in the .skir file. Unlike the standard Go{' '}
        <InlineCode>iota</InlineCode> pattern, Skir enums can carry a value in wrapper variants.
      </P>
      <P>
        The definition of the <InlineCode>SubscriptionStatus</InlineCode> enum in the .skir file is:
      </P>
      <CodeBlock language="skir">{`enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}`}</CodeBlock>

      <H4>Making enum values</H4>
      <CodeBlock language="go">{`_ = []user.SubscriptionStatus{
    // The unknown constant is present in all Skir enums even if it is not
    // declared in the .skir file.
    user.SubscriptionStatus_unknown(),
    user.SubscriptionStatus_freeConst(),
    user.SubscriptionStatus_premiumConst(),
    // Wrapper variants carry a value; use the *Wrapper constructor.
    user.SubscriptionStatus_trialWrapper(
        user.SubscriptionStatus_Trial_builder().
            SetStartTime(time.Now()).
            Build(),
    ),
}`}</CodeBlock>

      <H4>Conditions on enums</H4>
      <CodeBlock language="go">{`fmt.Println(john.SubscriptionStatus().IsFreeConst()) // true
fmt.Println(jane.SubscriptionStatus().IsUnknown())   // true (default)

now := time.Now()
trialStatus := user.SubscriptionStatus_trialWrapper(
    user.SubscriptionStatus_Trial_builder().SetStartTime(now).Build(),
)
fmt.Println(trialStatus.IsTrialWrapper())                     // true
fmt.Println(trialStatus.UnwrapTrial().StartTime().Equal(now)) // true

// UnwrapTrial() panics if called on a value that is not a trial wrapper.`}</CodeBlock>

      <H4>Branching on enum variants</H4>
      <CodeBlock language="go">{`// First way to branch on enum variants: a switch on Kind().
getInfoText := func(status user.SubscriptionStatus) string {
    switch status.Kind() {
    case user.SubscriptionStatus_kind_freeConst:
        return "Free user"
    case user.SubscriptionStatus_kind_premiumConst:
        return "Premium user"
    case user.SubscriptionStatus_kind_trialWrapper:
        return fmt.Sprintf("On trial since %v", status.UnwrapTrial().StartTime())
    default:
        return "Unknown subscription status"
    }
}
fmt.Println(getInfoText(john.SubscriptionStatus())) // Free user

// Second way to branch on enum variants: the visitor pattern (preferred).
// More verbose, but provides compile-time safety: the compiler will error
// if you forget to handle a variant (no default case required).
fmt.Println(
    user.SubscriptionStatus_accept(
        john.SubscriptionStatus(),
        subscriptionStatusInfoVisitor{},
    ),
) // Free user`}</CodeBlock>
      <P>
        The visitor type must implement the <InlineCode>SubscriptionStatus_visitor[T]</InlineCode>{' '}
        interface:
      </P>
      <CodeBlock language="go">{`type subscriptionStatusInfoVisitor struct{}

func (subscriptionStatusInfoVisitor) OnUnknown() string      { return "Unknown subscription status" }
func (subscriptionStatusInfoVisitor) OnFreeConst() string    { return "Free user" }
func (subscriptionStatusInfoVisitor) OnPremiumConst() string { return "Premium user" }
func (subscriptionStatusInfoVisitor) OnTrialWrapper(t user.SubscriptionStatus_Trial) string {
    return fmt.Sprintf("On trial since %v", t.StartTime())
}`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        <InlineCode>User_serializer()</InlineCode> returns a{' '}
        <InlineCode>skir.Serializer[User]</InlineCode> which can serialise and deserialise instances
        of <InlineCode>User</InlineCode>.
      </P>
      <CodeBlock language="go">{`serializer := user.User_serializer()

// Serialize to dense JSON (field-number-based; the default mode).
// Use this when you plan to deserialize the value later. Because field
// names are not included, renaming a field remains backward-compatible.
johnDenseJson := serializer.ToJson(john)
fmt.Println(johnDenseJson)
// [42,"John Doe",...]

// Serialize to readable (name-based, indented) JSON.
// Use this mainly for debugging.
fmt.Println(serializer.ToJson(john, skir.Readable{}))
// {
//   "user_id": 42,
//   "name": "John Doe",
//   "quote": "Coffee is just a socially acceptable form of rage.",
//   "pets": [
//     {
//       "name": "Dumbo",
//       "height_in_meters": 1,
//       "picture": "🐘"
//     }
//   ],
//   "subscription_status": "free"
// }

// Deserialize from JSON (both dense and readable formats are accepted).
reserializedJohn, err := serializer.FromJson(johnDenseJson)
if err != nil {
    panic(err)
}
_ = reserializedJohn

// Serialize to binary format (more compact than JSON; useful when
// performance matters, though the difference is rarely significant).
johnBytes := serializer.ToBytes(john)
fromBytes, err := serializer.FromBytes(johnBytes)
if err != nil {
    panic(err)
}
_ = fromBytes`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock language="go">{`fmt.Println(skir.BoolSerializer().ToJson(true))
// 1
fmt.Println(skir.Int32Serializer().ToJson(int32(3)))
// 3
fmt.Println(skir.Int64Serializer().ToJson(int64(9223372036854775807)))
// "9223372036854775807"
fmt.Println(skir.Float32Serializer().ToJson(float32(3.14)))
// 3.14
fmt.Println(skir.Float64Serializer().ToJson(3.14))
// 3.14
fmt.Println(skir.StringSerializer().ToJson("Foo"))
// "Foo"
fmt.Println(
    skir.TimestampSerializer().ToJson(
        time.UnixMilli(1_743_682_787_000).UTC()))
// 1743682787000`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="go">{`fmt.Println(
    skir.OptionalSerializer(skir.StringSerializer()).
        ToJson(skir.OptionalOf("foo")),
)
// "foo"

fmt.Println(
    skir.OptionalSerializer(skir.StringSerializer()).
        ToJson(skir.Optional[string]{}),
)
// null

fmt.Println(
    skir.ArraySerializer(skir.BoolSerializer()).
        ToJson(skir.ArrayFromSlice([]bool{true, false})),
)
// [1,0]`}</CodeBlock>

      <H3>Constants</H3>
      <P>
        Constants declared with <InlineCode>const</InlineCode> in the .skir file are available as
        functions in the generated Go package.
      </P>
      <CodeBlock language="go">{`fmt.Println(user.Tarzan_const())
// {
//   "user_id": 123,
//   "name": "Tarzan",
//   "quote": "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
//   "pets": [
//     {
//       "name": "Cheeta",
//       "height_in_meters": 1.67,
//       "picture": "🐒"
//     }
//   ],
//   "subscription_status": {
//     "kind": "trial",
//     "value": {
//       "start_time": {
//         "unix_millis": 1743592409000,
//         "formatted": "2025-04-02T11:13:29.000Z"
//       }
//     }
//   }
// }`}</CodeBlock>

      <H3>Keyed lists</H3>
      <CodeBlock language="go">{`// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }
// The '|user_id' part tells Skir to generate a search method keyed by user_id.

userRegistry := user.UserRegistry_builder().
    SetUsers([]user.User{john, jane, evilJohn}).
    Build()

// Users_SearchByUserId returns the last element whose user_id matches.
// The first search runs in O(n); subsequent searches run in O(1).
found := userRegistry.Users_SearchByUserId(43)
fmt.Println(found.IsPresent())   // true
fmt.Println(found.Get() == jane) // true

// If multiple elements share the same key, the last one wins.
found2 := userRegistry.Users_SearchByUserId(42)
fmt.Println(found2.Get() == evilJohn) // true

notFound := userRegistry.Users_SearchByUserId(999)
fmt.Println(notFound.IsPresent()) // false`}</CodeBlock>

      <H3>SkirRPC services</H3>

      <H4>Starting a SkirRPC service on an HTTP server</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-go-example/blob/main/cmd/start-service/main.go"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H4>Sending RPCs to a SkirRPC service</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-go-example/blob/main/cmd/call-service/main.go"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <P>Reflection allows you to inspect a Skir type at runtime.</P>
      <CodeBlock language="go">{`td := user.User_serializer().TypeDescriptor()
if sd, ok := td.(*skir.StructDescriptor); ok {
    names := make([]string, len(sd.Fields()))
    for i, f := range sd.Fields() {
        names[i] = f.Name()
    }
    fmt.Println(names)
    // [user_id name quote pets subscription_status]
}

// A TypeDescriptor can be serialized to JSON and deserialized later.
td2, err := skir.ParseTypeDescriptorFromJson(td.AsJson())
if err != nil {
    panic(err)
}
if sd2, ok := td2.(*skir.StructDescriptor); ok {
    fmt.Println(len(sd2.Fields())) // 5
}`}</CodeBlock>
    </Prose>
  )
}
