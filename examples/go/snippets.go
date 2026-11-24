// Code snippets showing how to use Go-generated data types.
//
// Run with: go run .

package main

import (
	"fmt"
	"time"

	skir "github.com/gepheum/skir-go-client"
	svc "github.com/gepheum/skir-go-example/skirout/service"
	user "github.com/gepheum/skir-go-example/skirout/user"
)

func main() {
	// =========================================================================
	// STRUCT TYPES
	// =========================================================================

	// Skir generates a deeply immutable Go interface for every struct in the
	// .skir file. The generated code provides both ordered and partial builders.

	// Ordered builder: all fields must be set in alphabetical order.
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
	fmt.Println(user.User_default().UserId()) // 0

	// ToBuilder copies all fields into a new partial builder.
	// Useful for creating modified copies without mutating the original.
	evilJohn := john.ToBuilder().
		SetName("Evil John").
		SetQuote("I solemnly swear I am up to no good.").
		Build()

	fmt.Println(evilJohn.Name())   // Evil John
	fmt.Println(evilJohn.UserId()) // 42 (copied from john)
	fmt.Println(john.Name())       // John Doe (john is unchanged)

	// =========================================================================
	// ENUM TYPES
	// =========================================================================

	// Skir generates a Go struct type for every enum in the .skir file.
	// Unlike the standard Go 'iota' pattern, Skir enums can carry a value
	// in wrapper variants.
	//
	// Every Skir enum automatically has an UNKNOWN variant which is not declared
	// in the .skir file. UNKNOWN is the zero value for fields of that enum type.

	_ = []user.SubscriptionStatus{
		// UNKNOWN is the default and is present in all Skir enums.
		user.SubscriptionStatus_unknown(),
		user.SubscriptionStatus_freeConst(),
		user.SubscriptionStatus_premiumConst(),
		// Wrapper variants carry a value; use the *Wrapper constructor.
		user.SubscriptionStatus_trialWrapper(
			user.SubscriptionStatus_Trial_builder().
				SetStartTime(time.Now()).
				Build(),
		),
	}

	// =========================================================================
	// ENUM KIND CHECKS AND SWITCHING
	// =========================================================================

	fmt.Println(john.SubscriptionStatus().IsFreeConst()) // true
	fmt.Println(jane.SubscriptionStatus().IsUnknown())   // true (default)

	now := time.Now()
	trialStatus := user.SubscriptionStatus_trialWrapper(
		user.SubscriptionStatus_Trial_builder().SetStartTime(now).Build(),
	)
	fmt.Println(trialStatus.IsTrialWrapper())                     // true
	fmt.Println(trialStatus.UnwrapTrial().StartTime().Equal(now)) // true

	// First way to branch on enum variants: a switch on Kind().
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

	// Second way to branch on enum variants: the visitor pattern (preferre).
	// More verbose, but provides compile-time safety: the compiler will error
	// if you forget to handle a variant (no default case required).
	fmt.Println(
		user.SubscriptionStatus_accept(
			john.SubscriptionStatus(),
			subscriptionStatusInfoVisitor{},
		),
	) // Free user

	// =========================================================================
	// SERIALIZATION
	// =========================================================================

	serializer := user.User_serializer()

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
	//   ...
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
	_ = fromBytes

	// =========================================================================
	// PRIMITIVE SERIALIZERS
	// =========================================================================

	fmt.Println(skir.BoolSerializer().ToJson(true))
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
	// 1743682787000

	// =========================================================================
	// COMPOSITE SERIALIZERS
	// =========================================================================

	fmt.Println(
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
	// [1,0]

	// =========================================================================
	// CONSTANTS
	// =========================================================================

	// Constants declared with 'const' in the .skir file are available as
	// functions (or package-level variables for primitive types) in the
	// generated Go package.
	fmt.Println(user.Tarzan_const())
	// {
	//   "user_id": 123,
	//   "name": "Tarzan",
	//   ...
	// }

	// =========================================================================
	// KEYED LISTS
	// =========================================================================

	// In the .skir file:
	//   struct UserRegistry {
	//     users: [User|user_id];
	//   }
	// The '|user_id' part tells Skir to generate a search method keyed by
	// user_id.

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
	fmt.Println(notFound.IsPresent()) // false

	// =========================================================================
	// REFLECTION
	// =========================================================================

	// Reflection allows you to inspect a Skir type at runtime.

	td := user.User_serializer().TypeDescriptor()
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
	}

	// =========================================================================
	// RPC METHODS
	// =========================================================================

	// Skir generates a Method value for every 'method' declaration in the
	// .skir file. Methods carry their name, number, request/response
	// serializers, and documentation.
	getUser := svc.GetUser()
	fmt.Println(getUser.Name())   // GetUser
	fmt.Println(getUser.Number()) // 12345
	fmt.Println(getUser.Doc())    // Returns the user with the given user_id...
}

// subscriptionStatusInfoVisitor implements user.SubscriptionStatus_visitor[string].
// Used in the visitor pattern example above.
type subscriptionStatusInfoVisitor struct{}

func (subscriptionStatusInfoVisitor) OnUnknown() string      { return "Unknown subscription status" }
func (subscriptionStatusInfoVisitor) OnFreeConst() string    { return "Free user" }
func (subscriptionStatusInfoVisitor) OnPremiumConst() string { return "Premium user" }
func (subscriptionStatusInfoVisitor) OnTrialWrapper(t user.SubscriptionStatus_Trial) string {
	return fmt.Sprintf("On trial since %v", t.StartTime())
}
