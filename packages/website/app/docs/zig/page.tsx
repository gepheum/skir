import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Zig - Skir Documentation',
  description: 'Learn how to use Skir-generated Zig code in your projects',
}

export default function ZigPage() {
  return (
    <Prose>
      <H1>Zig</H1>
      <P>This guide explains how to use Skir in a Zig project.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-zig-gen
  outDir: ./src/skirout
  config: {}`}</CodeBlock>

      <P>
        The generated Zig code has a runtime dependency on <InlineCode>skir_client</InlineCode>. Add
        it to your <InlineCode>build.zig.zon</InlineCode>:
      </P>
      <CodeBlock language="zig">{`.dependencies = .{
    .skir_client = .{
        .url = "https://github.com/gepheum/skir-zig-client/archive/refs/heads/main.tar.gz",
        .hash = "<hash printed by zig fetch>",
    },
},`}</CodeBlock>

      <P>Then fetch the archive once to get the hash:</P>
      <CodeBlock language="bash">{`zig fetch https://github.com/gepheum/skir-zig-client/archive/refs/heads/main.tar.gz`}</CodeBlock>

      <P>
        For more information, see this Zig project{' '}
        <a
          href="https://github.com/gepheum/skir-zig-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>Zig generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-zig-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <CodeBlock language="zig">{`// Import the Zig module generated from "user.skir".
const user_mod = @import("skirout/user.zig");
const skir = @import("skir_client.zig");

// Now you can use: user_mod.User, user_mod.UserRegistry,
// user_mod.SubscriptionStatus, user_mod.tarzan_const, etc.`}</CodeBlock>

      <H3>Struct types</H3>
      <P>
        Skir generates a plain Zig struct for every struct in the .skir file. All fields are value
        types; the struct is not heap-allocated by the generator.
      </P>
      <CodeBlock language="zig">{`// Skir generates a plain Zig struct for each struct in the .skir schema.
const john: user_mod.User = .{
    .user_id = 42,
    .name = "John Doe",
    .quote = "Coffee is just a socially acceptable form of rage.",
    .pets = &.{.{
        .name = "Dumbo",
        .height_in_meters = 1.0,
        .picture = "🐘",
        ._unrecognized = null,
    }},
    .subscription_status = .Free,
    ._unrecognized = null, // Present in every struct; always set to null
};

std.debug.print("{s}\\n", .{john.name});
// John Doe`}</CodeBlock>

      <H4>Default value</H4>
      <CodeBlock language="zig">{`// To create a value with only some fields set, start from the default
// and override what you need. All other fields keep their default values.
var jane = user_mod.User.default;
jane.name = "Jane";
jane.quote = "I came, I saw, I deleted the cache.";
std.debug.print("{s}\\n", .{jane.name});
// Jane
std.debug.print("{d}\\n", .{jane.user_id});
// 0`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="zig">{`// For a shallow copy, use a plain assignment.
var evil_jane = jane;
evil_jane.name = "Evil Jane";

// For a deep copy, use clone().
var evil_john = try john.clone(arena_allocator);
evil_john.name = "Evil John";
evil_john.quote = "I solemnly swear I am up to no good.";

std.debug.print("{s}\\n", .{evil_john.name});
// Evil John
std.debug.print("{d}\\n", .{evil_john.user_id});
// 42`}</CodeBlock>

      <H3>Enum types</H3>
      <P>The definition of the SubscriptionStatus enum in the .skir file is:</P>
      <CodeBlock language="rust" filename="Skir">{`enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}`}</CodeBlock>
      <P>Skir generates a tagged union for every enum in the .skir file.</P>

      <H4>Making enum values</H4>
      <CodeBlock language="zig">{`const trial_payload: user_mod.SubscriptionStatus.Trial_ = .{
    .start_time = .{ .unix_millis = 1_744_974_198_000 },
    ._unrecognized = null,
};

const some_statuses = [_]user_mod.SubscriptionStatus{
    user_mod.SubscriptionStatus.unknown,
    .Free,
    .Premium,
    .{ .Trial = &trial_payload },
};
_ = some_statuses;`}</CodeBlock>

      <H3>Enum matching</H3>
      <CodeBlock language="zig">{`fn subscriptionInfoText(status: user_mod.SubscriptionStatus) []const u8 {
    return switch (status) {
        .Unknown => "Unknown subscription status",
        .Free => "Free user",
        .Trial => |trial| blk: {
            _ = trial;
            break :blk "On trial since (some timestamp)";
        },
        .Premium => "Premium user",
    };
}

std.debug.print("{s}\\n", .{subscriptionInfoText(john.subscription_status)});
// Free user
std.debug.print("{s}\\n", .{subscriptionInfoText(user_mod.SubscriptionStatus.unknown)});
// Unknown subscription status
std.debug.print("{s}\\n", .{subscriptionInfoText(.{ .Trial = &trial_payload })});
// On trial since (some timestamp)`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        <InlineCode>User.serializer()</InlineCode> returns a serializer which can serialize and
        deserialize instances of <InlineCode>User</InlineCode>.
      </P>
      <CodeBlock language="zig">{`const user_serializer = user_mod.User.serializer();

const john_dense_json = try user_serializer.serialize(
    arena_allocator,
    john,
    .{ .format = .denseJson },
);
std.debug.print("{s}\\n", .{john_dense_json});
// [42,"John Doe","Coffee is just a socially acceptable form of rage.",[["Dumbo",1,"🐘"]],1]

const john_readable_json = try user_serializer.serialize(
    arena_allocator,
    john,
    .{ .format = .readableJson },
);
std.debug.print("{s}\\n", .{john_readable_json});
// {
//   "user_id": 42,
//   "name": "John Doe",
//   ...
// }

const john_binary = try user_serializer.serialize(
    arena_allocator,
    john,
    .{ .format = .binary },
);`}</CodeBlock>

      <H4>Deserialization</H4>
      <CodeBlock language="zig">{`// deserialize() auto-detects the format (dense JSON, readable JSON, or
// binary) from the input bytes — the same call works for all three.
// Pass an arena allocator; everything allocated through it is freed at
// once by calling arena.deinit().

// Deserialize from dense JSON.
const from_dense = try user_serializer.deserialize(
    arena_allocator,
    john_dense_json,
    .{},
);
std.debug.print("{s}\\n", .{from_dense.name});
// John Doe

// Deserialize from readable JSON — same call, different bytes.
const from_readable = try user_serializer.deserialize(
    arena_allocator,
    john_readable_json,
    .{},
);
std.debug.print("{s}\\n", .{from_readable.name});
// John Doe

// Deserialize from binary — same call again.
const from_binary = try user_serializer.deserialize(
    arena_allocator,
    john_binary,
    .{},
);
std.debug.print("{s}\\n", .{from_binary.name});
// John Doe`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock language="zig">{`// skir.boolSerializer(), skir.int32Serializer(), etc. return serializers
// for Zig primitive types.
_ = try skir.boolSerializer().serialize(
    arena_allocator,
    true,
    .{ .format = .denseJson },
);
_ = try skir.int32Serializer().serialize(
    arena_allocator,
    @as(i32, 3),
    .{ .format = .denseJson },
);
_ = try skir.int64Serializer().serialize(
    arena_allocator,
    @as(i64, 9_223_372_036_854_775_807),
    .{ .format = .denseJson },
);
_ = try skir.hash64Serializer().serialize(
    arena_allocator,
    @as(u64, 18_446_744_073_709_551_615),
    .{ .format = .denseJson },
);
_ = try skir.timestampSerializer().serialize(
    arena_allocator,
    skir.Timestamp{ .unix_millis = 1_743_682_787_000 },
    .{ .format = .denseJson },
);
_ = try skir.float32Serializer().serialize(
    arena_allocator,
    @as(f32, 3.14),
    .{ .format = .denseJson },
);
_ = try skir.float64Serializer().serialize(
    arena_allocator,
    @as(f64, 3.14),
    .{ .format = .denseJson },
);
_ = try skir.stringSerializer().serialize(
    arena_allocator,
    "Foo",
    .{ .format = .denseJson },
);
_ = try skir.bytesSerializer().serialize(
    arena_allocator,
    @as([]const u8, &.{ 1, 2, 3 }),
    .{ .format = .denseJson },
);`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="zig">{`const opt_string_ser = skir.optionalSerializer(skir.stringSerializer());
_ = try opt_string_ser.serialize(
    arena_allocator,
    @as(?[]const u8, null),
    .{ .format = .denseJson },
);

const bool_array_ser = skir.arraySerializer(skir.boolSerializer());
_ = try bool_array_ser.serialize(
    arena_allocator,
    @as([]const bool, &.{ true, false }),
    .{ .format = .denseJson },
);`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="zig">{`// Constants declared with 'const' in the .skir file are available as
// module-level values in the generated Zig file.
const tarzan = user_mod.tarzan_const;
std.debug.print("{s}\\n", .{tarzan.name});
// Tarzan

const tarzan_json = try user_serializer.serialize(
    arena_allocator,
    tarzan,
    .{ .format = .readableJson },
);
std.debug.print("{s}\\n", .{tarzan_json});
// {
//   "user_id": 123,
//   "name": "Tarzan",
//   ...
// }`}</CodeBlock>

      <H3>Keyed arrays</H3>
      <CodeBlock language="zig">{`// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }
// The '|user_id' part tells Skir to generate a search keyed by user_id.

var users = [_]user_mod.User{ john, jane, evil_john, tarzan };
var registry = user_mod.UserRegistry{
    .users = skir.KeyedArray(user_mod.User.By_UserId).init(
        arena_allocator,
        users[0..],
    ),
    ._unrecognized = null,
};

const found = try registry.users.findByKey(42);
if (found) |u| {
    std.debug.print("{s}\\n", .{u.name});
    // Evil John (last duplicate wins)
}

const not_found = try registry.users.findByKey(43);
std.debug.print("{}\\n", .{not_found == null});
// true

const found_or_default = try registry.users.findByKeyOrDefault(999);
std.debug.print("{d}\\n", .{found_or_default.pets.len});
// 0`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <P>
        <strong>Starting a SkirRPC service on an HTTP server</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-zig-example/blob/main/src/start_service.zig"
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
          href="https://github.com/gepheum/skir-zig-example/blob/main/src/call_service.zig"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <P>Reflection allows you to inspect a Skir type at runtime.</P>
      <CodeBlock language="zig">{`const type_descriptor = user_serializer.typeDescriptor();
switch (type_descriptor) {
    .struct_record => |sd| {
        std.debug.print("{s} has {d} fields\\n", .{ sd.name, sd.fields.len });
        // User has 5 fields
        if (sd.fieldByName("name")) |f| {
            std.debug.print("field 'name' number={d}\\n", .{f.number});
            // field 'name' number=1
        }
    },
    else => {},
}

const enum_type_descriptor =
    user_mod.SubscriptionStatus.serializer().typeDescriptor();
switch (enum_type_descriptor) {
    .enum_record => |ed| {
        std.debug.print("{s} has {d} variants\\n", .{ ed.name, ed.variants.len });
        // SubscriptionStatus has 3 variants
        if (ed.variantByName("trial")) |variant| {
            std.debug.print("variant trial number={d}\\n", .{variant.number()});
            // variant trial number=2
        }
    },
    else => {},
}`}</CodeBlock>
    </Prose>
  )
}
