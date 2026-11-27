# F#

This guide explains how to use Skir in an F# project. Targets F# on .NET 10 and higher.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
- mod: skir-fsharp-gen
  outDir: ./skirout
  config: {}
```

The generated F# code has a runtime dependency on the `skir_client` NuGet package and is emitted into a single topologically ordered `skirout/Skirout.fs` file so your `.fsproj` file never needs to be updated when `.skir` files are added or reorganized. Add both to your `.fsproj` file:

```xml
<ItemGroup>
  <PackageReference Include="skir_client" Version="*" />
</ItemGroup>

<ItemGroup>
  <Compile Include="skirout/Skirout.fs" />
  <!-- Your F# source files follow here -->
</ItemGroup>
```

For more information, see this F# project [example](https://github.com/gepheum/skir-fsharp-example).

## Generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-fsharp-example/blob/main/skir-src/user.skir) `.skir` file.

### Referring to generated symbols

Each `.skir` file `path/to/my_module.skir` generates a recursive module `Skirout_Path_To_MyModule` inside `skirout/Skirout.fs`:

```fsharp
open SkirClient
open Skirout_Service
open Skirout_User

// Now you can use: User, UserRegistry, SubscriptionStatus, Consts.Tarzan, Methods, etc.
```

### Structs

Skir generates an immutable F# record with custom structural equality (including element-wise equality for `ImmutableArray<'T>` fields) and a static `Create` method with optional parameters for every struct in the `.skir` file.

```fsharp
open System.Collections.Immutable

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
printfn "%s" User.Default.Name   // (empty string)
printfn "%d" User.Default.UserId // 0

// Any argument omitted from Create defaults to its zero value.
let jane = User.Create(userId = 43, name = "Jane Doe")
printfn "%s" jane.Quote       // (empty string)
printfn "%d" jane.Pets.Length // 0
```

#### Creating modified copies

Use F#'s native `{ record with ... }` record update syntax to create modified copies:

```fsharp
let evilJohn =
    { john with
        Name = "Evil John"
        Quote = "I solemnly swear I am up to no good." }

printfn "%s" evilJohn.Name   // Evil John
printfn "%d" evilJohn.UserId // 42 (copied from john)
printfn "%s" john.Name       // John Doe (john is unchanged)

printfn "%b" (User.Default = User.Create()) // true
```

### Enums

Skir generates a native F# Discriminated Union for every enum in the `.skir` file. The `Unknown` case is added automatically (`SubscriptionStatus.UnknownDefault` is the default value).

The definition of the `SubscriptionStatus` enum in the `.skir` file is:

```skir
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

#### Making enum values

```fsharp
open System

let statuses =
    [
        SubscriptionStatus.UnknownDefault
        SubscriptionStatus.Free
        SubscriptionStatus.Premium
        SubscriptionStatus.Trial(
            SubscriptionStatus_Trial.Create(startTime = DateTimeOffset.UtcNow)
        )
    ]
```

#### Pattern matching on enums

Because enums are native F# Discriminated Unions, you can use idiomatic F# `match` expressions:

```fsharp
let getInfoText (status: SubscriptionStatus) : string =
    match status with
    | SubscriptionStatus.Free -> "Free user"
    | SubscriptionStatus.Premium -> "Premium user"
    | SubscriptionStatus.Trial trial -> sprintf "On trial since %O" trial.StartTime
    | SubscriptionStatus.Unknown _ -> "Unknown subscription status"

printfn "%s" (getInfoText john.SubscriptionStatus) // Free user
```

### Serialization

`User.Serializer` returns a `Serializer<User>` which can serialize and deserialize instances of `User`.

```fsharp
let serializer = User.Serializer

// Serialize to dense JSON (field-number-based; the default).
let johnDenseJson = serializer.ToJson(john)
printfn "%s" johnDenseJson
// [42,"John Doe",...]

// Serialize to readable (name-based, indented) JSON — for debugging only.
printfn "%s" (serializer.ToJson(john, readable = true))
// {
//   "user_id": 42,
//   "name": "John Doe",
//   ...
// }

// Deserialize from JSON. Both dense and readable formats are accepted.
let johnReserializedFromJson = serializer.FromJson(johnDenseJson)
assert (johnReserializedFromJson = john)

// Serialize to compact binary format.
let johnBytes = serializer.ToBytes(john)
let johnReserializedFromBytes = serializer.FromBytes(johnBytes)
assert (johnReserializedFromBytes = john)
```

#### Primitive and composite serializers

```fsharp
printfn "%s" (Serializers.Bool.ToJson(true))
// 1

printfn "%s" (Serializers.Int32.ToJson(3))
// 3

printfn "%s" (Serializers.Int64.ToJson(9_223_372_036_854_775_807L))
// "9223372036854775807"

printfn "%s" (Serializers.Hash64.ToJson(18_446_744_073_709_551_615UL))
// "18446744073709551615"

printfn "%s" (Serializers.Float32.ToJson(1.5f))
// 1.5

printfn "%s" (Serializers.Float64.ToJson(1.5))
// 1.5

printfn "%s" (Serializers.String.ToJson("Foo"))
// "Foo"

let ts = DateTimeOffset(2023, 12, 31, 0, 53, 48, TimeSpan.Zero)
printfn "%s" (Serializers.Timestamp.ToJson(ts))
// 1703984028000

printfn "%s" (Serializers.Timestamp.ToJson(ts, readable = true))
// {"unix_millis": 1703984028000, "formatted": "2023-12-31T00:53:48.000Z"}

printfn "%s" (Serializers.Bytes.ToJson(ImmutableBytes.CopyFrom([| 0xDEuy; 0xADuy; 0xBEuy; 0xEFuy |])))
// "3q2+7w=="

printfn "%s" (Serializers.Array(Serializers.Bool).ToJson(ImmutableArray.Create(true, false)))
// [1,0]
```

### Constants

Constants declared with `const` in the `.skir` file are generated inside the `Consts` submodule of the same module:

```fsharp
let tarzan = Consts.Tarzan
printfn "%s" tarzan.Name  // Tarzan
printfn "%s" tarzan.Quote // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA
printfn "%s" (User.Serializer.ToJson(tarzan, readable = true))
```

### Keyed arrays

Keyed array lookup methods return `'T option` (`Some item` or `None`) or `'T` (`*OrDefault`):

```fsharp
let registry =
    UserRegistry.Create(users = ImmutableArray.Create(john, jane, evilJohn))

let found = registry.Users_FindByUserId(43)
assert (found = Some jane)

let notFound = registry.Users_FindByUserId(999)
assert (notFound = None)

let notFoundOrDefault = registry.Users_FindByUserIdOrDefault(999)
assert (notFoundOrDefault = User.Default)
```

### SkirRPC services

**Starting a SkirRPC service on an HTTP server** - full example [here](https://github.com/gepheum/skir-fsharp-example/blob/main/StartService.fs).

**Sending RPCs to a SkirRPC service** - full example [here](https://github.com/gepheum/skir-fsharp-example/blob/main/CallService.fs).

### Reflection

Reflection allows you to inspect a Skir type at runtime.

```fsharp
open System.Linq

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
```

### RPC methods

Skir generates a `Method<'TRequest, 'TResponse>` descriptor in the `Methods` submodule for every `method` declaration in the `.skir` file.

```fsharp
let getUser = Methods.GetUser
printfn "%s" getUser.Name   // GetUser
printfn "%d" getUser.Number // 12345
printfn "%s" getUser.Doc    // Returns the user with the given user_id...

let addUser = Methods.AddUser
printfn "%s" addUser.Name   // AddUser
printfn "%d" addUser.Number // 23456
```
