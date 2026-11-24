import { NextPageLink } from '@/components/next-page-link'
import { CodeBlock, Note, Prose } from '@/components/prose'
import Image from 'next/image'

export const metadata = {
  title: 'Schema evolution & compatibility - Skir Documentation',
  description: 'Guidelines for evolving your Skir schema without breaking backward compatibility.',
}

export default function SchemaEvolutionPage() {
  return (
    <Prose>
      <h1>Schema evolution & compatibility</h1>
      <p>
        Skir includes built-in compatibility checks so you can evolve schemas safely and catch
        breaking changes before they hit production. It is designed for long-term data persistence
        and distributed systems, with support for both backward compatibility (new code can read old
        data) and forward compatibility (old code can read new data when services or clients run
        different versions).
      </p>

      <h2>Safe schema changes</h2>
      <p>The following changes are safe and preserve both backward and forward compatibility:</p>

      <h3>Adding a field to a struct</h3>
      <p>New code reading old data will use default values for missing fields:</p>
      <ul>
        <li>
          Numbers: <code>0</code>
        </li>
        <li>
          Booleans: <code>false</code>
        </li>
        <li>Strings, bytes, arrays: empty</li>
        <li>Structs: a struct with all fields at their default values</li>
        <li>
          Enums: the implicit <code>unknown</code> variant
        </li>
        <li>
          Optional: <code>null</code>
        </li>
      </ul>

      <h3>Adding a variant to an enum</h3>
      <p>
        Old code encountering a new variant will treat it as the implicit <code>unknown</code>{' '}
        variant.
      </p>

      <h3>Renaming a type, field, or variant</h3>
      <p>
        Skir uses numeric identifiers (field numbers) in its binary and compact JSON formats, not
        names. Therefore, renaming any element is safe. Renaming <code>.skir</code> files or moving
        symbols across files is also always safe.
      </p>
      <Note type="info">
        <p>
          Names <em>are</em> used in the human-readable JSON format. This format is for debugging
          only and should not be used for storage or inter-service communication.
        </p>
      </Note>

      <h3>Removing a field or variant</h3>
      <p>
        You must mark the field or variant number as <code>removed</code>. This is permanent: once a
        number is marked as removed, it cannot be reused. When removing a variant, new code
        encoutering the old variant will treat it as <code>unknown</code>.
      </p>

      <h3>Making a compatible type change</h3>
      <p>You can change a type if the new type is backward-compatible with the old one:</p>
      <ul>
        <li>
          <code>bool</code> → <code>int32</code>, <code>int64</code>, <code>hash64</code>
        </li>
        <li>
          <code>int32</code> → <code>int64</code>
        </li>
        <li>
          <code>float32</code> → <code>float64</code>
        </li>
        <li>
          <code>float64</code> → <code>float32</code> (precision loss possible)
        </li>
        <li>
          <code>[A]</code> → <code>[B]</code> (if <code>A</code> → <code>B</code> is valid)
        </li>
        <li>
          <code>A?</code> → <code>B?</code> (if <code>A</code> → <code>B</code> is valid)
        </li>
      </ul>

      <h3>Turning an array into a keyed array</h3>
      <p>
        You can freely add, remove, or change the key field of a keyed array (the part after{' '}
        <code>|</code>). For example, changing <code>[User]</code> to <code>[User|id]</code> or{' '}
        <code>[User|id]</code> to <code>[User]</code> is safe. The key annotation is purely a hint
        for code generation to provide efficient lookup methods—it doesn't affect the serialization
        format or data compatibility.
      </p>

      <h3>Converting a constant variant into a wrapper variant</h3>
      <p>
        You can safely convert a constant variant into a wrapper variant. New code reading old data
        with constant variants will treat them as wrapper variants around empty values.
      </p>
      <CodeBlock language="skir">{`// BEFORE
enum Status {
  error;
  ok;
}
`}</CodeBlock>
      <CodeBlock language="skir">{`// AFTER
enum Status {
  // When deserializing old data, the string will be empty.
  error: string;
  ok;
}
`}</CodeBlock>

      <h3>Giving a stable identifier to a record</h3>
      <p>
        Giving a stable identifier to a record, for example <code>struct Foo(123) {'{...}'}</code>,
        is safe. Stable identifiers are not used during serialization; they are only used by the
        snapshot tool to track records across time.
      </p>

      <h2>Unsafe changes</h2>
      <p>The following changes will break compatibility:</p>
      <ul>
        <li>
          Changing a field/variant number, or reordering fields/variants if using implicit
          numbering.
        </li>
        <li>
          Changing the type of a field, wrapper variant, method request or method response to an
          incompatible type.
        </li>
        <li>Changing a method's stable identifier.</li>
        <li>
          Reusing a <code>removed</code> field or variant number.
        </li>
        <li>
          Deleting a field or variant without marking it as <code>removed</code>.
        </li>
        <li>Converting a wrapper variant into a constant variant.</li>
      </ul>

      <h2>Automated compatibility checks</h2>
      <p>
        The Skir compiler includes a <code>snapshot</code> tool to prevent accidental breaking
        changes.
      </p>

      <h3>How it works</h3>
      <p>
        The <code>npx skir snapshot</code> command helps you manage schema evolution by maintaining
        a history of your schema state. When you run this command, two things happen:
      </p>
      <ol>
        <li>
          <strong>Verification</strong>: Skir checks for a <code>skir-snapshot.json</code> file. If
          it exists, it compares your current <code>.skir</code> files against it. If breaking
          changes are detected, the command reports them and exits.
        </li>
        <li>
          <strong>Update</strong>: If no breaking changes are found (or if no snapshot exists), Skir
          creates or updates the <code>skir-snapshot.json</code> file to reflect the current schema.
        </li>
      </ol>

      <h3>Tracked types and stable identifiers</h3>
      <p>
        To track compatibility across renames, Skir needs a way to identify your types. You can
        explicitly assign a random integer ID to your top-level types:
      </p>
      <CodeBlock language="skir">{`// Explicitly tracked by ID 500996846
struct User(500996846) {
  name: string;
  pets: [Pet];
}

// Implicitly tracked through User, no need to assign an ID
struct Pet {
  name: string;
}
`}</CodeBlock>
      <p>
        If you rename <code>User</code> to <code>Account</code> but keep the ID{' '}
        <code>500996846</code>, Skir knows it's the same type and will validate the change safely.
      </p>

      <h3>Which types to explicitly track</h3>
      <p>
        In most projects, only a handful of types need explicit stable identifiers: the top-level
        records that you store on disk. All records they contain, directly or indirectly, are
        implicitly tracked through their parents.
      </p>
      <p>
        In the example above, <code>Pet</code> is implicitly tracked through <code>User</code>. If
        you rename <code>Pet</code> to <code>Animal</code> without changing its structure, Skir will
        still recognize it as the same type because it is the type of the first field (number{' '}
        <code>0</code>) of <code>User</code>. But if you then make the following change:
      </p>
      <CodeBlock language="skir">{`struct Animal {
  name: bool;  // Was string
}
`}</CodeBlock>
      <p>
        The snapshot tool will report a breaking change in <code>Pet</code>/<code>Animal</code>{' '}
        because <code>string</code> → <code>bool</code> is an incompatible type change.
      </p>
      <p>
        Types used as service method requests and responses are also implicitly tracked through the
        method number, so you do not need to give them stable IDs.
      </p>
      <CodeBlock language="skir">{`method GetUser(GetUserRequest): GetUserResponse = 12345;

// Tracked through GetUser
struct GetUserRequest { }

// Tracked through GetUser
struct GetUserResponse { }
`}</CodeBlock>

      <h3>Handling intentional breaking changes</h3>
      <p>
        If you must make a breaking change (e.g., during early development), simply delete the{' '}
        <code>skir-snapshot.json</code> file and run <code>npx skir snapshot</code> again to
        establish a new baseline.
      </p>

      <h2>Recommended workflow</h2>

      <h3>1. During development</h3>
      <p>
        While drafting a new schema version, use the <code>--dry-run</code> flag to check for
        backward compatibility without updating the snapshot:
      </p>
      <CodeBlock language="bash">{`npx skir snapshot --dry-run`}</CodeBlock>
      <p>This confirms that your changes are safe relative to the last release (snapshot).</p>

      <p>
        If you are using the official{' '}
        <a
          href="https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language"
          target="_blank"
          rel="noopener noreferrer"
          className="underline decoration-muted-foreground/50 hover:text-foreground transition-colors"
        >
          VSCode extension
        </a>
        , breaking changes will be highlighted directly in your editor as you type.
      </p>
      <div className="not-prose mx-auto my-6 flex max-w-5xl items-center justify-center gap-2 pt-[2px] md:gap-3">
        <div className="soft-surface w-[45%] overflow-hidden rounded-xl p-2">
          <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Before
          </div>
          <Image
            src="/shapes-before.png"
            alt="Schema before evolution changes"
            width={0}
            height={0}
            sizes="(max-width: 768px) 45vw, 420px"
            className="h-auto w-full rounded-lg"
          />
        </div>
        <div className="soft-surface w-[45%] overflow-hidden rounded-xl p-2">
          <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
            After
          </div>
          <Image
            src="/shapes-after.png"
            alt="Schema after evolution changes"
            width={0}
            height={0}
            sizes="(max-width: 768px) 45vw, 420px"
            className="h-auto w-full rounded-lg"
          />
        </div>
      </div>

      <h3>2. Before release</h3>
      <p>
        Run <code>npx skir snapshot</code> without flags to verify compatibility and commit the new
        schema state to the snapshot file.
      </p>

      <h3>3. Continuous integration</h3>
      <p>
        Add the command to your CI pipeline or pre-commit hook to prevent accidental breaking
        changes. The <code>--ci</code> flag ensures the snapshot is up-to-date and compatible:
      </p>
      <CodeBlock language="yaml">{`- name: Ensure Skir snapshot up-to-date
  run: npx skir snapshot --ci`}</CodeBlock>

      <h2>Round-tripping unrecognized data</h2>
      <p>
        Consider a service in a distributed system that reads a Skir value, modifies it, and writes
        it back. If the schema has evolved (e.g., new fields were added) but the service is running
        older code, it may encounter data it doesn't recognize.
      </p>
      <p>
        When deserializing, you can choose to either <strong>drop</strong> or{' '}
        <strong>preserve</strong> this unrecognized data.
      </p>
      <ul>
        <li>
          <strong>Drop (default)</strong>: Unrecognized fields and variants are discarded. This is
          safer but results in data loss if the object is saved back to storage.
        </li>
        <li>
          <strong>Preserve</strong>: Unrecognized data is kept internally and written back during
          serialization. This enables "round-tripping".
        </li>
      </ul>

      <p>For example, consider a schema evolution where a field and an enum variant are added:</p>
      <CodeBlock language="skir" filename="Version 1">{`struct UserBefore(999) {
  id: int64;
  subscription_status: enum {
    free;
    premium;
  };
}`}</CodeBlock>
      <CodeBlock language="skir" filename="Version 2">{`struct UserAfter(999) {
  id: int64;
  subscription_status: enum {
    free;
    premium;
    trial;  // Added
  };
  name: string;  // Added
}`}</CodeBlock>

      <h3>Default behavior: drop</h3>
      <p>By default, unrecognized data is lost during the round-trip.</p>
      <CodeBlock language="typescript">{`// Old code reads and writes the data
const oldUser = UserBefore.serializer.fromJson(originalJson);
const roundTrippedJson = UserBefore.serializer.toJson(oldUser);

// New code reads the result
const result = UserAfter.serializer.fromJson(roundTrippedJson);

assert(result.id === 123);
assert(result.name === "");  // Lost: reset to default
assert(result.subscriptionStatus.union.kind === "unknown");  // Lost: became unknown`}</CodeBlock>

      <h3>Preserve behavior</h3>
      <p>You can configure the deserializer to keep unrecognized values.</p>
      <CodeBlock language="typescript">{`// Old code reads with "keep-unrecognized-values"
const oldUser = UserBefore.serializer.fromJson(
  originalJson,
  "keep-unrecognized-values"
);
const roundTrippedJson = UserBefore.serializer.toJson(oldUser);

// New code reads the result
const result = UserAfter.serializer.fromJson(roundTrippedJson);

assert(result.id === 123);
assert(result.name === "Jane");  // Preserved!
assert(result.subscriptionStatus.union.kind === "trial");  // Preserved!`}</CodeBlock>

      <Note type="warning">
        <p>
          <strong>Only preserve unrecognized data from trusted sources.</strong> Malicious actors
          could inject fields with IDs that you haven't defined yet. If you preserve this data and
          later define those IDs in a future version of your schema, the injected data could be
          deserialized as valid fields, potentially leading to security vulnerabilities or data
          corruption.
        </p>
      </Note>

      <NextPageLink title="SkirRPC" href="/docs/skirrpc" />
    </Prose>
  )
}
