// Code snippets showing how to use C#-generated data types.
//
// Run with:
//   dotnet run

using System.Collections.Immutable;
using SkirClient;
using Skirout_Service;
using Skirout_User;

static class Snippets
{
    public static void Run()
    {
        // =============================================================================
        // STRUCT TYPES
        // =============================================================================

        // Skir generates a readonly record struct for every struct in the .skir file.
        // Every field is marked 'required' — the compiler enforces that all fields are
        // initialised when constructing a value.
        var john = new User
        {
            UserId = 42,
            Name = "John Doe",
            Quote = "Coffee is just a socially acceptable form of rage.",
            Pets =
            [
                new User_Pet { Name = "Dumbo", HeightInMeters = 1.0f, Picture = "🐘" },
            ],
            SubscriptionStatus = SubscriptionStatus.Free,
        };

        Console.WriteLine(john.Name); // John Doe

        // john.Name = "John Smith";
        // ^ Does not compile: init-only properties cannot be set after construction.

        // 'Default' gives a value with every field set to its zero value (0, "", [], …).
        Console.WriteLine(User.Default.Name);   // (empty string)
        Console.WriteLine(User.Default.UserId); // 0

        // The C# 'with' expression creates a copy with specific fields changed.
        // All other fields are carried over unchanged from the source value.
        var jane = User.Default with { UserId = 43, Name = "Jane Doe" };

        Console.WriteLine(jane.Quote);       // (empty string — defaulted)
        Console.WriteLine(jane.Pets.Length); // 0 — defaulted

        var evilJohn = john with
        {
            Name = "Evil John",
            Quote = "I solemnly swear I am up to no good.",
        };

        Console.WriteLine(evilJohn.Name);   // Evil John
        Console.WriteLine(evilJohn.UserId); // 42 (copied from john)
        Console.WriteLine(john.Name);       // John Doe (john is unchanged)

        // Record structs support structural equality out of the box.
        Console.WriteLine(User.Default == (User.Default with { })); // True

        // =============================================================================
        // ENUM TYPES
        // =============================================================================

        // Skir generates a sealed class for every enum in the .skir file.
        // Constant variants are exposed as static readonly singletons.
        // Wrapper variants are created with WrapX() factory methods.
        //
        // Every Skir enum has an implicit UNKNOWN variant that is the default value,
        // returned when deserializing an unrecognized variant number.

        SubscriptionStatus[] statuses =
        [
            SubscriptionStatus.Unknown,    // implicit default
            SubscriptionStatus.Free,       // constant variant
            SubscriptionStatus.Premium,    // constant variant
            SubscriptionStatus.WrapTrial(  // wrapper variant
                new SubscriptionStatus_Trial { StartTime = DateTimeOffset.UtcNow }),
        ];

        // =============================================================================
        // ENUM MATCHING
        // =============================================================================

        Console.WriteLine(john.SubscriptionStatus == SubscriptionStatus.Free);    // True
        Console.WriteLine(jane.SubscriptionStatus == SubscriptionStatus.Unknown); // True (default)

        var now = DateTimeOffset.UtcNow;
        var trialStatus = SubscriptionStatus.WrapTrial(
            new SubscriptionStatus_Trial { StartTime = now });

        // Option 1: switch on Kind — concise, covers all variants at runtime.
        string GetInfoText(SubscriptionStatus status) => status.Kind switch
        {
            SubscriptionStatus.KindType.Free         => "Free user",
            SubscriptionStatus.KindType.Premium      => "Premium user",
            SubscriptionStatus.KindType.TrialWrapper => $"On trial since {status.AsTrial().StartTime}",
            _                                        => "Unknown subscription status",
        };

        Console.WriteLine(GetInfoText(john.SubscriptionStatus)); // Free user
        Console.WriteLine(GetInfoText(trialStatus));             // On trial since …

        // Option 2: visitor — provides compile-time guarantee that all variants
        // are handled (the interface has one method per variant).
        string GetInfoTextVisitor(SubscriptionStatus status) =>
            status.Accept(new InfoTextVisitor());

        Console.WriteLine(GetInfoTextVisitor(john.SubscriptionStatus)); // Free user

        // =============================================================================
        // SERIALIZATION
        // =============================================================================

        var serializer = User.Serializer;

        // Serialize to dense JSON (field-number-based; the default).
        // Use this for persistence and transport. Field renames remain
        // backward-compatible because names are not part of the dense JSON.
        var johnDenseJson = serializer.ToJson(john);
        Console.WriteLine(johnDenseJson);
        // [42,"John Doe",...]

        // Serialize to readable (name-based, indented) JSON — for debugging only.
        Console.WriteLine(serializer.ToJson(john, readable: true));
        // {
        //   "user_id": 42,
        //   "name": "John Doe",
        //   ...
        // }

        // Deserialize from JSON. Both dense and readable formats are accepted.
        var johnReserializedFromJson = serializer.FromJson(johnDenseJson);
        Console.WriteLine(johnReserializedFromJson.Name); // John Doe

        // Serialize to compact binary format.
        var johnBytes = serializer.ToBytes(john);
        var johnReserializedFromBytes = serializer.FromBytes(johnBytes);
        Console.WriteLine(johnReserializedFromBytes.Name); // John Doe

        // =============================================================================
        // PRIMITIVE SERIALIZERS
        // =============================================================================

        Console.WriteLine(Serializers.Bool.ToJson(true));
        // 1

        Console.WriteLine(Serializers.Int32.ToJson(3));
        // 3

        Console.WriteLine(Serializers.Int64.ToJson(9_223_372_036_854_775_807L));
        // "9223372036854775807"
        // int64 values are JSON-encoded as quoted strings so that JavaScript parsers
        // (which use 64-bit floats) cannot silently lose precision.

        Console.WriteLine(Serializers.Hash64.ToJson(18_446_744_073_709_551_615UL));
        // "18446744073709551615"

        Console.WriteLine(Serializers.Float32.ToJson(1.5f));
        // 1.5

        Console.WriteLine(Serializers.Float64.ToJson(1.5));
        // 1.5

        Console.WriteLine(Serializers.String.ToJson("Foo"));
        // "Foo"

        // Skir timestamps are UTC milliseconds since the Unix epoch.
        // C# maps them to DateTimeOffset with a zero UTC offset.
        var ts = new DateTimeOffset(2023, 12, 31, 0, 53, 48, TimeSpan.Zero);
        Console.WriteLine(Serializers.Timestamp.ToJson(ts));
        // 1703984028000

        Console.WriteLine(Serializers.Timestamp.ToJson(ts, readable: true));
        // {"unix_millis":1703984028000,"formatted":"2023-12-31T00:53:48.000Z"}

        Console.WriteLine(Serializers.Bytes.ToJson(ImmutableBytes.CopyFrom([0xDE, 0xAD, 0xBE, 0xEF])));
        // "3q2+7w=="

        // =============================================================================
        // COMPOSITE SERIALIZERS
        // =============================================================================

        // Optional serializer for nullable reference types:
        Console.WriteLine(Serializers.Optional(Serializers.String).ToJson("foo"));
        // "foo"

        Console.WriteLine(Serializers.Optional(Serializers.String).ToJson(null as string));
        // null

        // Array serializer:
        Console.WriteLine(Serializers.Array(Serializers.Bool).ToJson(ImmutableArray.Create(true, false)));
        // [1,0]

        // =============================================================================
        // CONSTANTS
        // =============================================================================

        // Constants declared with 'const' in the .skir file are generated inside
        // the 'Consts' class of the same module.
        var tarzan = Consts.Tarzan;
        Console.WriteLine(tarzan.Name);  // Tarzan
        Console.WriteLine(tarzan.Quote); // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA
        Console.WriteLine(User.Serializer.ToJson(tarzan, readable: true));
        // {
        //   "user_id": 123,
        //   "name": "Tarzan",
        //   ...
        // }

        // =============================================================================
        // KEYED ARRAYS
        // =============================================================================

        // In the .skir file:
        //   struct UserRegistry {
        //     users: [User|user_id];
        //   }
        // The '|user_id' suffix tells Skir to generate keyed-array lookup methods
        // so individual users can be retrieved by user_id in O(1) after the first
        // call (the index is built lazily and cached per array instance).

        var registry = new UserRegistry { Users = [john, jane, evilJohn] };

        // Users_FindByUserId returns the matching element, or null if not found.
        var found = registry.Users_FindByUserId(43);
        Console.WriteLine(found != null);   // True
        Console.WriteLine(found == jane);   // True

        var notFound = registry.Users_FindByUserId(999);
        Console.WriteLine(notFound == null); // True

        // Users_FindByUserIdOrDefault returns User.Default instead of null.
        var notFoundOrDefault = registry.Users_FindByUserIdOrDefault(999);
        Console.WriteLine(notFoundOrDefault == User.Default); // True

        // =============================================================================
        // REFLECTION
        // =============================================================================

        // Every generated type exposes its schema via its serializer's TypeDescriptor.
        var typeDescriptor = User.Serializer.TypeDescriptor;

        if (typeDescriptor is StructDescriptor sd)
        {
            var fieldNames = string.Join(", ", sd.Fields.Select(f => f.Name));
            Console.WriteLine(fieldNames);
            // user_id, name, quote, pets, subscription_status
        }

        // TypeDescriptors can be serialized to JSON and deserialized back.
        var descriptorJson = typeDescriptor.AsJson();
        var descriptorFromJson = TypeDescriptor.ParseFromJson(descriptorJson);
        if (descriptorFromJson is StructDescriptor sd2)
        {
            Console.WriteLine(sd2.Fields.Count); // 5
        }

        // =============================================================================
        // RPC METHODS
        // =============================================================================

        // Skir generates a Method<TRequest, TResponse> descriptor for every 'method'
        // declaration in the .skir file. Use it to inspect metadata or wire up a
        // client/server.

        var getUser = Methods.GetUser;
        Console.WriteLine(getUser.Name);   // GetUser
        Console.WriteLine(getUser.Number); // 12345
        Console.WriteLine(getUser.Doc);    // Returns the user with the given user_id…

        var addUser = Methods.AddUser;
        Console.WriteLine(addUser.Name);   // AddUser
        Console.WriteLine(addUser.Number); // 23456

        // Suppress "unused variable" warnings for demo variables.
        _ = (statuses, johnBytes, johnReserializedFromBytes, descriptorFromJson, addUser);
    }

    private sealed class InfoTextVisitor : SubscriptionStatus.IVisitor<string>
    {
        public string OnUnknown() => "Unknown subscription status";
        public string OnFree() => "Free user";
        public string OnTrial(SubscriptionStatus_Trial trial) => $"On trial since {trial.StartTime}";
        public string OnPremium() => "Premium user";
    }
}
