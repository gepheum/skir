import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'C# - Skir Documentation',
  description: 'Learn how to use Skir-generated C# code in your projects',
}

export default function CSharpPage() {
  return (
    <Prose>
      <H1>C#</H1>
      <P>Official plugin for generating C# code from .skir files.</P>
      <P>Targets C# 12 on .NET 10 and higher.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-csharp-gen
  outDir: ./skirout
  config: {}`}</CodeBlock>
      <P>
        The generated C# code has a runtime dependency on the <InlineCode>skir_client</InlineCode>{' '}
        NuGet package. Add it to your <InlineCode>.csproj</InlineCode> file with:
      </P>
      <CodeBlock language="xml">{`<ItemGroup>
  <PackageReference Include="skir_client" Version="*" />
</ItemGroup>`}</CodeBlock>
      <P>
        For more information, see this C# project{' '}
        <a
          href="https://github.com/gepheum/skir-csharp-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>C# generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-csharp-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <CodeBlock language="csharp">{`using SkirClient;
using Skirout_Service;
using Skirout_User;

// Now you can use: User, UserRegistry, SubscriptionStatus, Consts.Tarzan, Methods, etc.`}</CodeBlock>

      <H3>Struct types</H3>
      <P>Skir generates a readonly record struct for every struct in the .skir file.</P>
      <P>
        Every generated field is <InlineCode>required</InlineCode> and <InlineCode>init</InlineCode>
        -only.
      </P>
      <CodeBlock language="csharp">{`var john = new User
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
Console.WriteLine(jane.Pets.Length); // 0`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="csharp">{`var evilJohn = john with
{
    Name = "Evil John",
    Quote = "I solemnly swear I am up to no good.",
};

Console.WriteLine(evilJohn.Name);   // Evil John
Console.WriteLine(evilJohn.UserId); // 42 (copied from john)
Console.WriteLine(john.Name);       // John Doe (john is unchanged)

Console.WriteLine(User.Default == (User.Default with { })); // True`}</CodeBlock>

      <H3>Enum types</H3>
      <P>Skir generates a sealed C# class for every enum in the .skir file.</P>
      <P>
        The <InlineCode>Unknown</InlineCode> variant is added automatically and is the default
        value.
      </P>
      <CodeBlock language="csharp">{`var statuses = new SubscriptionStatus[]
{
    SubscriptionStatus.Unknown,
    SubscriptionStatus.Free,
    SubscriptionStatus.Premium,
    SubscriptionStatus.WrapTrial(
        new SubscriptionStatus_Trial { StartTime = DateTimeOffset.UtcNow }),
};`}</CodeBlock>

      <H4>Conditions on enums</H4>
      <CodeBlock language="csharp">{`Console.WriteLine(john.SubscriptionStatus == SubscriptionStatus.Free);    // True
Console.WriteLine(jane.SubscriptionStatus == SubscriptionStatus.Unknown); // True

var now = DateTimeOffset.UtcNow;
var trialStatus = SubscriptionStatus.WrapTrial(
    new SubscriptionStatus_Trial { StartTime = now });`}</CodeBlock>

      <H4>Branching on enum variants</H4>
      <CodeBlock language="csharp">{`string GetInfoText(SubscriptionStatus status) => status.Kind switch
{
    SubscriptionStatus.KindType.Free         => "Free user",
    SubscriptionStatus.KindType.Premium      => "Premium user",
    SubscriptionStatus.KindType.TrialWrapper => $"On trial since {status.AsTrial().StartTime}",
    _                                        => "Unknown subscription status",
};

Console.WriteLine(GetInfoText(john.SubscriptionStatus)); // Free user`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        <InlineCode>User.Serializer</InlineCode> returns a{' '}
        <InlineCode>Serializer&lt;User&gt;</InlineCode> which can serialize and deserialize
        instances of <InlineCode>User</InlineCode>.
      </P>
      <CodeBlock language="csharp">{`var serializer = User.Serializer;

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
Console.WriteLine(johnReserializedFromBytes.Name); // John Doe`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock language="csharp">{`Console.WriteLine(Serializers.Bool.ToJson(true));
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
// "3q2+7w=="`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="csharp">{`Console.WriteLine(Serializers.Optional(Serializers.String).ToJson("foo"));
// "foo"

Console.WriteLine(Serializers.Optional(Serializers.String).ToJson(null as string));
// null

Console.WriteLine(Serializers.Array(Serializers.Bool).ToJson(ImmutableArray.Create(true, false)));
// [1,0]`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="csharp">{`var tarzan = Consts.Tarzan;
Console.WriteLine(tarzan.Name);  // Tarzan
Console.WriteLine(tarzan.Quote); // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA
Console.WriteLine(User.Serializer.ToJson(tarzan, readable: true));`}</CodeBlock>

      <H3>Keyed arrays</H3>
      <CodeBlock language="csharp">{`var registry = new UserRegistry { Users = [john, jane, evilJohn] };

var found = registry.Users_FindByUserId(43);
Console.WriteLine(found != null); // True
Console.WriteLine(found == jane); // True

var notFound = registry.Users_FindByUserId(999);
Console.WriteLine(notFound == null); // True

var notFoundOrDefault = registry.Users_FindByUserIdOrDefault(999);
Console.WriteLine(notFoundOrDefault == User.Default); // True`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <H4>Starting a SkirRPC service on an HTTP server</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-csharp-example/blob/main/StartService.cs"
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
          href="https://github.com/gepheum/skir-csharp-example/blob/main/CallService.cs"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <P>Reflection allows you to inspect a Skir type at runtime.</P>
      <CodeBlock language="csharp">{`var typeDescriptor = User.Serializer.TypeDescriptor;
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
}`}</CodeBlock>

      <H3>RPC methods</H3>
      <P>
        Skir generates a <InlineCode>Method&lt;TRequest, TResponse&gt;</InlineCode> descriptor for
        every <InlineCode>method</InlineCode> declaration in the .skir file.
      </P>
      <CodeBlock language="csharp">{`var getUser = Methods.GetUser;
Console.WriteLine(getUser.Name);   // GetUser
Console.WriteLine(getUser.Number); // 12345
Console.WriteLine(getUser.Doc);    // Returns the user with the given user_id…

var addUser = Methods.AddUser;
Console.WriteLine(addUser.Name);   // AddUser
Console.WriteLine(addUser.Number); // 23456`}</CodeBlock>
    </Prose>
  )
}
