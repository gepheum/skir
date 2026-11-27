// Code snippets showing how to use F#-generated data types.
//
// Run with:
//   dotnet run

module Snippets

open System
open System.Collections.Immutable
open System.Linq
open SkirClient
open Skirout_Service
open Skirout_User

let run () =
    // =========================================================================
    // STRUCT TYPES
    // =========================================================================

    // Skir generates an immutable F# record with a static Create method
    // for every struct in the .skir file.
    let john =
        User.Create(
            userId = 42,
            name = "John Doe",
            quote = "Coffee is just a socially acceptable form of rage.",
            pets =
                ImmutableArray.Create(
                    User_Pet.Create(name = "Dumbo", heightInMeters = 1.0f, picture = "🐘")
                ),
            subscriptionStatus = SubscriptionStatus.Free
        )

    printfn "%s" john.Name // John Doe

    // 'Default' gives a value with every field set to its zero value (0, "", [], ...).
    printfn "%s" User.Default.Name // (empty string)
    printfn "%d" User.Default.UserId // 0

    // Any argument omitted from Create defaults to its zero value.
    let jane = User.Create(userId = 43, name = "Jane Doe")

    printfn "%s" jane.Quote // (empty string)
    printfn "%d" jane.Pets.Length // 0

    // F#'s native '{ record with ... }' expression creates a copy with specific fields changed.
    let evilJohn =
        { john with
            Name = "Evil John"
            Quote = "I solemnly swear I am up to no good." }

    printfn "%s" evilJohn.Name // Evil John
    printfn "%d" evilJohn.UserId // 42 (copied from john)
    printfn "%s" john.Name // John Doe (john is unchanged)

    // Generated records support structural equality out of the box (including array fields).
    printfn "%b" (User.Default = User.Create()) // true

    // =========================================================================
    // ENUM TYPES
    // =========================================================================

    // Skir generates an F# Discriminated Union for every enum in the .skir file.
    // Every Skir enum has an implicit Unknown variant that is the default value,
    // returned when deserializing an unrecognized variant number.
    let statuses =
        [
            SubscriptionStatus.UnknownDefault
            SubscriptionStatus.Free
            SubscriptionStatus.Premium
            SubscriptionStatus.Trial(SubscriptionStatus_Trial.Create(startTime = DateTimeOffset.UtcNow))
        ]

    ignore statuses

    // =========================================================================
    // ENUM PATTERN MATCHING
    // =========================================================================

    printfn "%b" (john.SubscriptionStatus = SubscriptionStatus.Free) // true
    printfn "%b" (jane.SubscriptionStatus = SubscriptionStatus.UnknownDefault) // true

    let now = DateTimeOffset.UtcNow
    let trialStatus =
        SubscriptionStatus.Trial(SubscriptionStatus_Trial.Create(startTime = now))

    // Native F# pattern matching over enum cases:
    let getInfoText (status: SubscriptionStatus) =
        match status with
        | SubscriptionStatus.Free -> "Free user"
        | SubscriptionStatus.Premium -> "Premium user"
        | SubscriptionStatus.Trial trial -> sprintf "On trial since %O" trial.StartTime
        | SubscriptionStatus.Unknown _ -> "Unknown subscription status"

    printfn "%s" (getInfoText john.SubscriptionStatus) // Free user
    printfn "%s" (getInfoText trialStatus) // On trial since ...

    // =========================================================================
    // SERIALIZATION
    // =========================================================================

    let serializer = User.Serializer

    // Serialize to dense JSON (field-number-based; the default).
    let johnDenseJson = serializer.ToJson(john)
    printfn "%s" johnDenseJson
    // [42,"John Doe",...]

    // Serialize to readable (name-based, indented) JSON — for debugging only.
    printfn "%s" (serializer.ToJson(john, readable = true))

    // Deserialize from JSON. Both dense and readable formats are accepted.
    let johnReserializedFromJson = serializer.FromJson(johnDenseJson)
    assert (johnReserializedFromJson = john)

    // Serialize to compact binary format.
    let johnBytes = serializer.ToBytes(john)
    let johnReserializedFromBytes = serializer.FromBytes(johnBytes)
    assert (johnReserializedFromBytes = john)

    // =========================================================================
    // PRIMITIVE & COMPOSITE SERIALIZERS
    // =========================================================================

    printfn "%s" (Serializers.Bool.ToJson(true)) // 1
    printfn "%s" (Serializers.Int32.ToJson(3)) // 3
    printfn "%s" (Serializers.Int64.ToJson(9_223_372_036_854_775_807L)) // "9223372036854775807"
    printfn "%s" (Serializers.Hash64.ToJson(18_446_744_073_709_551_615UL)) // "18446744073709551615"
    printfn "%s" (Serializers.Float32.ToJson(1.5f)) // 1.5
    printfn "%s" (Serializers.Float64.ToJson(1.5)) // 1.5
    printfn "%s" (Serializers.String.ToJson("Foo")) // "Foo"

    let ts = DateTimeOffset(2023, 12, 31, 0, 53, 48, TimeSpan.Zero)
    printfn "%s" (Serializers.Timestamp.ToJson(ts)) // 1703984028000
    printfn "%s" (Serializers.Bytes.ToJson(ImmutableBytes.CopyFrom([| 0xDEuy; 0xADuy; 0xBEuy; 0xEFuy |]))) // "3q2+7w=="

    // Array serializer:
    printfn "%s" (Serializers.Array(Serializers.Bool).ToJson(ImmutableArray.Create(true, false))) // [1,0]

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    let tarzan = Consts.Tarzan
    printfn "%s" tarzan.Name // Tarzan
    printfn "%s" tarzan.Quote // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA

    // =========================================================================
    // KEYED ARRAYS
    // =========================================================================

    let registry =
        UserRegistry.Create(users = ImmutableArray.Create(john, jane, evilJohn))

    // Users_FindByUserId returns option<User> (Some user or None).
    let found = registry.Users_FindByUserId(43)
    assert (found = Some jane)

    let notFound = registry.Users_FindByUserId(999)
    assert (notFound = None)

    // Users_FindByUserIdOrDefault returns User.Default instead of None.
    let notFoundOrDefault = registry.Users_FindByUserIdOrDefault(999)
    assert (notFoundOrDefault = User.Default)

    // =========================================================================
    // REFLECTION
    // =========================================================================

    let typeDescriptor = User.Serializer.TypeDescriptor
    match typeDescriptor with
    | :? StructDescriptor as sd ->
        let fieldNames = String.Join(", ", sd.Fields.Select(fun f -> f.Name))
        printfn "%s" fieldNames
        // user_id, name, quote, pets, subscription_status
    | _ -> ()

    let descriptorJson = typeDescriptor.AsJson()
    let descriptorFromJson = TypeDescriptor.ParseFromJson(descriptorJson)
    assert (descriptorFromJson.AsJson() = descriptorJson)

    // =========================================================================
    // RPC METHODS
    // =========================================================================

    let getUser = Methods.GetUser
    printfn "%s (%d): %s" getUser.Name getUser.Number getUser.Doc

    let addUser = Methods.AddUser
    printfn "%s (%d)" addUser.Name addUser.Number
