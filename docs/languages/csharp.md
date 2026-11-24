[![npm](https://img.shields.io/npm/v/skir-csharp-gen)](https://www.npmjs.com/package/skir-csharp-gen)
[![build](https://github.com/gepheum/skir-csharp-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-csharp-gen/actions)

# Skir's C# code generator

Official plugin for generating C# code from [.skir](https://github.com/gepheum/skir) files.

Targets C# 12 on .NET 10 and higher.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:
```yaml
  - mod: skir-csharp-gen
    outDir: ./skirout
    config: {}
```

The generated C# code has a runtime dependency on the `skir_client` NuGet package. Add it to your `.csproj` file with:

```xml
<ItemGroup>
  <PackageReference Include="skir_client" Version="*" />
</ItemGroup>
```

For more information, see this C# project [example](https://github.com/gepheum/skir-csharp-example).

## C# generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-csharp-example/blob/main/skir-src/user.skir) .skir file.

### Referring to generated symbols

```csharp
using SkirClient;
using Skirout_Service;
using Skirout_User;

// Now you can use: User, UserRegistry, SubscriptionStatus, Consts.Tarzan, Methods, etc.
```

### Struct types

Skir generates a readonly record struct for every struct in the .skir file.
Every generated field is `required` and `init`-only.

```csharp
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

Console.WriteLine(User.Default.Name);   // (empty string)
Console.WriteLine(User.Default.UserId); // 0

var jane = User.Default with { UserId = 43, Name = "Jane Doe" };
Console.WriteLine(jane.Quote);       // (empty string)
Console.WriteLine(jane.Pets.Length); // 0
```

#### Creating modified copies

```csharp
var evilJohn = john with
{
    Name = "Evil John",
    Quote = "I solemnly swear I am up to no good.",
};

Console.WriteLine(evilJohn.Name);   // Evil John
Console.WriteLine(evilJohn.UserId); // 42 (copied from john)
Console.WriteLine(john.Name);       // John Doe (john is unchanged)

Console.WriteLine(User.Default == (User.Default with { })); // True
```

### Enum types

Skir generates a sealed C# class for every enum in the .skir file.
The `Unknown` variant is added automatically and is the default value.

```csharp
var statuses = new SubscriptionStatus[]
{
    SubscriptionStatus.Unknown,
    SubscriptionStatus.Free,
    SubscriptionStatus.Premium,
    SubscriptionStatus.WrapTrial(
        new SubscriptionStatus_Trial { StartTime = DateTimeOffset.UtcNow }),
};
```

#### Conditions on enums

```csharp
Console.WriteLine(john.SubscriptionStatus == SubscriptionStatus.Free);    // True
Console.WriteLine(jane.SubscriptionStatus == SubscriptionStatus.Unknown); // True

var now = DateTimeOffset.UtcNow;
var trialStatus = SubscriptionStatus.WrapTrial(
    new SubscriptionStatus_Trial { StartTime = now });
```

#### Branching on enum variants

```csharp
string GetInfoText(SubscriptionStatus status) => status.Kind switch
{
    SubscriptionStatus.KindType.Free         => "Free user",
    SubscriptionStatus.KindType.Premium      => "Premium user",
    SubscriptionStatus.KindType.TrialWrapper => $"On trial since {status.AsTrial().StartTime}",
    _                                        => "Unknown subscription status",
};

Console.WriteLine(GetInfoText(john.SubscriptionStatus)); // Free user
```

### Serialization

`User.Serializer` returns a `Serializer<User>` which can serialize and
deserialize instances of `User`.

```csharp
var serializer = User.Serializer;

var johnDenseJson = serializer.ToJson(john);
Console.WriteLine(johnDenseJson);
// [42,"John Doe",...]

Console.WriteLine(serializer.ToJson(john, readable: true));
// {
//   "user_id": 42,
//   "name": "John Doe",
//   ...
// }

var johnReserializedFromJson = serializer.FromJson(johnDenseJson);
Console.WriteLine(johnReserializedFromJson.Name); // John Doe

var johnBytes = serializer.ToBytes(john);
var johnReserializedFromBytes = serializer.FromBytes(johnBytes);
Console.WriteLine(johnReserializedFromBytes.Name); // John Doe
```

### Primitive serializers

```csharp
Console.WriteLine(Serializers.Bool.ToJson(true));
// 1

Console.WriteLine(Serializers.Int32.ToJson(3));
// 3

Console.WriteLine(Serializers.Int64.ToJson(9_223_372_036_854_775_807L));
// "9223372036854775807"

Console.WriteLine(Serializers.Hash64.ToJson(18_446_744_073_709_551_615UL));
// "18446744073709551615"

Console.WriteLine(Serializers.Float32.ToJson(1.5f));
// 1.5

Console.WriteLine(Serializers.Float64.ToJson(1.5));
// 1.5

Console.WriteLine(Serializers.String.ToJson("Foo"));
// "Foo"

var ts = new DateTimeOffset(2023, 12, 31, 0, 53, 48, TimeSpan.Zero);
Console.WriteLine(Serializers.Timestamp.ToJson(ts));
// 1703984028000

Console.WriteLine(Serializers.Timestamp.ToJson(ts, readable: true));
// {"unix_millis":1703984028000,"formatted":"2023-12-31T00:53:48.000Z"}

Console.WriteLine(Serializers.Bytes.ToJson(ImmutableBytes.CopyFrom([0xDE, 0xAD, 0xBE, 0xEF])));
// "3q2+7w=="
```

### Composite serializers

```csharp
Console.WriteLine(Serializers.Optional(Serializers.String).ToJson("foo"));
// "foo"

Console.WriteLine(Serializers.Optional(Serializers.String).ToJson(null as string));
// null

Console.WriteLine(Serializers.Array(Serializers.Bool).ToJson(ImmutableArray.Create(true, false)));
// [1,0]
```

### Constants

```csharp
var tarzan = Consts.Tarzan;
Console.WriteLine(tarzan.Name);  // Tarzan
Console.WriteLine(tarzan.Quote); // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA
Console.WriteLine(User.Serializer.ToJson(tarzan, readable: true));
```

### Keyed arrays

```csharp
var registry = new UserRegistry { Users = [john, jane, evilJohn] };

var found = registry.Users_FindByUserId(43);
Console.WriteLine(found != null); // True
Console.WriteLine(found == jane); // True

var notFound = registry.Users_FindByUserId(999);
Console.WriteLine(notFound == null); // True

var notFoundOrDefault = registry.Users_FindByUserIdOrDefault(999);
Console.WriteLine(notFoundOrDefault == User.Default); // True
```

### SkirRPC services

#### Starting a SkirRPC service on an HTTP server

Full example [here](https://github.com/gepheum/skir-csharp-example/blob/main/StartService.cs).

#### Sending RPCs to a SkirRPC service

Full example [here](https://github.com/gepheum/skir-csharp-example/blob/main/CallService.cs).

### Reflection

Reflection allows you to inspect a Skir type at runtime.

```csharp
var typeDescriptor = User.Serializer.TypeDescriptor;
if (typeDescriptor is StructDescriptor sd)
{
    var fieldNames = string.Join(", ", sd.Fields.Select(f => f.Name));
    Console.WriteLine(fieldNames);
    // user_id, name, quote, pets, subscription_status
}

var descriptorJson = typeDescriptor.AsJson();
var descriptorFromJson = TypeDescriptor.ParseFromJson(descriptorJson);
if (descriptorFromJson is StructDescriptor sd2)
{
    Console.WriteLine(sd2.Fields.Count); // 5
}
```

### RPC methods

Skir generates a `Method<TRequest, TResponse>` descriptor for every `method`
declaration in the .skir file.

```csharp
var getUser = Methods.GetUser;
Console.WriteLine(getUser.Name);   // GetUser
Console.WriteLine(getUser.Number); // 12345
Console.WriteLine(getUser.Doc);    // Returns the user with the given user_id…

var addUser = Methods.AddUser;
Console.WriteLine(addUser.Name);   // AddUser
Console.WriteLine(addUser.Number); // 23456
```

