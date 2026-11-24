import { HoverVideo } from '@/components/hover-video'
import { CodeBlock, Prose } from '@/components/prose'

export const metadata = {
  title: 'Skir vs Protobuf - Skir Documentation',
  description: 'A guide for Protocol Buffer users migrating to Skir.',
}

export default function ProtobufPage() {
  return (
    <Prose>
      <h1>Skir vs Protobuf</h1>
      <p>
        If you have used{' '}
        <a href="https://protobuf.dev/" target="_blank" rel="noopener noreferrer">
          Protocol Buffers
        </a>{' '}
        (protobuf) before, you will find Skir very familiar. Skir was heavily inspired by protobuf
        and shares many of its core design principles: efficient binary serialization, schema
        evolution, and language-agnostic types.
      </p>
      <p>
        However, Skir was built to address common pain points in the protobuf ecosystem and to
        provide a superior developer experience. This guide highlights the key differences.
      </p>

      <h2>Polymorphism</h2>
      <p>
        In Protocol Buffers, an <code>enum</code> represents one of multiple stateless options, and
        a <code>oneof</code> represents one of multiple stateful options. This often leads to
        awkward patterns when you want a mix of stateless and stateful options, for example:
      </p>
      <CodeBlock language="protobuf">{`// poker.proto

message PokerAction {
  enum Enum {
    UNKNOWN = 0;
    CHECK = 1;
    BET = 2;
    CALL = 3;
    FOLD = 4;
    RAISE = 5;
  }
  Enum action = 1;
  // Only if action is BET or RAISE
  int32 amount = 2;
}`}</CodeBlock>
      <p>
        Skir unifies these two concepts into a specific "Rust-like" enum. Variants can be stateless
        (like a standard enum) or stateful (holding data), and you can mix them freely.
      </p>
      <CodeBlock language="skir">{`enum PokerAction {
  check;           // Stateless variant
  bet: int32;      // Stateful variant (holds the amount)
  fold;
  call;
  raise: int32;
}`}</CodeBlock>

      <h2>Must all fields be specified at construction time?</h2>
      <p>
        This reflects a fundamental difference in code generation philosophy between Skir and
        Protobuf.
      </p>
      <p>
        With Protocol Buffers, adding a field to a message is guaranteed <strong>not</strong> to
        break existing code that constructs instances of that message. If the code isn&apos;t
        updated, the new field simply takes its default value (0, empty string, etc.).
      </p>
      <p>
        Skir takes the opposite approach: it aims to raise a compile-time error if you add a field
        to a struct but forget to update the code that constructs it. When you add a field, you
        usually <em>want</em> to update every instantiation site to populate that field correctly.
        Skir ensures you don&apos;t miss any spot by enforcing strict constructors.
      </p>
      <CodeBlock language="python" filename="Protobuf">{`# my_script_with_protobuf.py

# Adding 'email' to User message doesn't break this code.
user = User()
user.id = 123
user.name = "Alice"`}</CodeBlock>
      <CodeBlock language="python" filename="Skir">{`# my_script_with_skir.py

# Static type checkers will raise an error if 'email' is added to User in the
# schema file and this code is not updated.
user = User(
    id=123,
    name="Alice",
)`}</CodeBlock>
      <p>
        If you need to opt out explicitly, Skir also generates a <code>partial</code> constructor.
        This is useful for test fixtures, where updating every constructor call can become
        cumbersome when fields are added to a <code>struct</code>.
      </p>
      <CodeBlock language="python" filename="Skir (explicit opt-out)">{`user = User.partial(
    id=123,
    # no name
)`}</CodeBlock>
      <p>
        When deserializing old data that is missing the new field, both Protobuf and Skir behave
        similarly: the new field is assigned its default value.
      </p>

      <h2>Schema evolution: guidelines vs guarantees</h2>
      <p>
        Both Protocol Buffers and Skir are designed to support schema evolution, but they take
        fundamentally different approaches to ensuring compatibility.
      </p>
      <p>
        Protocol Buffers provides{' '}
        <a
          href="https://protobuf.dev/programming-guides/proto3/#updating"
          target="_blank"
          rel="noopener noreferrer"
        >
          guidelines and best practices
        </a>{' '}
        for evolving schemas safely. These guidelines tell you which changes are safe (e.g., adding
        fields, renaming) and which are dangerous (e.g., changing field numbers, incompatible type
        changes). However, <strong>nothing in the toolchain enforces these rules</strong>. It is
        entirely up to developers to remember the guidelines, understand the implications, and avoid
        making breaking changes.
      </p>
      <p>
        Skir takes a different approach: it provides <strong>automated enforcement</strong> through
        its built-in snapshot tool. When you run <code>npx skir snapshot</code>, Skir analyzes your
        current schema against a stored snapshot of the previous version and automatically detects
        breaking changes. If you accidentally change a field number or make an incompatible type
        change, Skir will catch it and refuse to proceed.
      </p>
      <p>
        This shift from <em>guidelines you must remember to follow</em> to{' '}
        <em>automated checks that prevent mistakes</em> provides a much stronger guarantee of
        compatibility. You can confidently evolve your schema knowing that the tooling will catch
        any dangerous changes before they reach production. Additionally, when integrated into your
        CI pipeline or Git pre-commit hooks, the snapshot check ensures that every schema change is
        validated automatically.
      </p>

      <h3>
        A note on <code>buf breaking</code>
      </h3>
      <p>
        Buf has addressed this gap in the Protobuf ecosystem with its{' '}
        <a href="https://buf.build/docs/breaking/" target="_blank" rel="noopener noreferrer">
          <code>buf breaking</code>
        </a>{' '}
        command, which detects backward-incompatible schema changes. However, it identifies types
        purely by their fully-qualified name. This means renaming a type — even a simple refactor —
        is treated as a breaking change: the old type is seen as deleted and a new one created,
        losing all compatibility history.
      </p>
      <p>
        Skir avoids this by letting you assign a{' '}
        <a
          href="https://skir.build/docs/schema-evolution#tracked-types-and-stable-identifiers"
          target="_blank"
          rel="noopener noreferrer"
        >
          stable numeric identifier
        </a>{' '}
        to your top-level types. This identifier is a meaningless number — purely internal to the
        compiler — so you can rename a type freely without breaking compatibility. It also lets Skir
        automatically track all the nested types a top-level type references, without requiring you
        to annotate each one manually.
      </p>

      <h2>External dependencies</h2>
      <p>
        Protocol Buffers does not come with a built-in package manager. To share types across
        multiple Git repositories, developers traditionally have to rely on{' '}
        <code>git submodule</code>, manual file copying, or external commercial services like{' '}
        <code>buf</code>.
      </p>
      <p>
        Skir supports GitHub imports, like Go and Swift. This allows you to easily share common data
        structures (like standard currency types or user definitions) across your backend
        microservices and your frontend applications.
      </p>
      <ol>
        <li>
          Define dependencies in <code>skir.yml</code>, pointing to any public or private GitHub
          repository and a tag.
        </li>
        <li>
          Import the types you need:{' '}
          <code>{'import { User } from "@my-org/common-types/user.skir";'}</code>
        </li>
        <li>
          Run <code>npx skir gen</code>.
        </li>
      </ol>
      <p>
        Skir handles downloading the repositories from GitHub, caching them, and resolving imports
        automatically. You get a full-featured schema registry experience using just your existing
        source control.
      </p>

      <h2>Serialization</h2>
      <p>Protobuf has two serialization formats: Binary and JSON (Proto3 JSON Mapping).</p>
      <p>
        The Protobuf JSON format is readable (uses field names), but is not safe for schema
        evolution (renaming fields breaks compatibility).
      </p>
      <p>Skir offers three serialization formats:</p>
      <ul>
        <li>
          <strong>JSON (Dense)</strong>: Structs are serialized as arrays (<code>[val1, val2]</code>
          ) rather than objects. It is the default choice offering the best balance between:
          <ul>
            <li>
              Space efficiency: although it is not as space efficient as binary, it comes close.
            </li>
            <li>Evolution safety: you can rename fields without breaking compatibility.</li>
            <li>
              Interoperability and debuggability: being valid JSON, it is easy to inspect and works
              out of the box with databases (e.g., PostgreSQL JSONB columns) and external tools,
              unlike binary formats.
            </li>
          </ul>
        </li>
        <li>
          <strong>JSON (Readable)</strong>: Similar to Protobuf&apos;s JSON mapping. Useful for
          debugging but unsafe for persistence as it relies on field names.
        </li>
        <li>
          <strong>Binary</strong>: Equivalent to Protobuf binary. A bit more compact and performant
          than dense JSON.
        </li>
      </ul>
      <p>
        Skir can also serialize schemas themselves, so you can store schema metadata alongside your
        data. This enables generic tooling that can inspect serialized payloads. For example, the{' '}
        <a href="https://skir.build/converter.html" target="_blank" rel="noopener noreferrer">
          Skir converter web app
        </a>{' '}
        can load a schema from a type descriptor JSON or from a GitHub URL, then convert a pasted
        value between dense JSON, readable JSON, and binary formats.
      </p>
      <div className="not-prose my-6 pt-[2px] max-w-full mx-auto">
        <HoverVideo src="/skir-converter-github.mp4" />
      </div>

      <h2>Constants</h2>
      <p>
        Skir lets you define constants directly in your schema files. You can define complex values
        (structs, lists, maps, primitives) in your <code>.skir</code> file and they will be compiled
        into native code constants in your target language.
      </p>
      <CodeBlock language="skir" filename="config.skir">{`struct Config {
  timeout_ms: int32;
  retries: int32;
  supported_locales: [string];
}

const DEFAULT_CONFIG: Config = {
  timeout_ms = 5000,
  retries = 3,
  supported_locales = ["en-US", "ja-JP", "fr-FR"],
};`}</CodeBlock>
      <p>
        The <code>DEFAULT_CONFIG</code> constant is compiled into native code, ensuring your
        frontend and backend share the exact same configuration values.
      </p>

      <h2>Keyed arrays vs maps</h2>
      <p>
        Protocol Buffer 3 introduced the <code>{'map<K, V>'}</code> type with the goal of preventing
        developers from having to manually iterate through lists to find items. Such manual
        iteration is cumbersome and inefficient if multiple lookups have to be performed.
      </p>
      <p>
        Unfortunately, <code>map</code> comes with a trade-off: in the majority of cases, the key
        used for indexing is already stored inside the value type.
      </p>
      <CodeBlock language="protobuf" filename="Protobuf">{`message User {
  string id = 1;
  string name = 2;
}

message UserRegistry {
  // Redundant: 'id' is stored in the map key AND the User
  map<string, User> users = 1;
}`}</CodeBlock>
      <p>
        This forces you to store the ID twice and creates an implicit contract: the code
        constructing the map must ensure the key matches the ID inside the value.
      </p>
      <p>
        Skir introduces <em>Keyed Arrays</em> to solve this problem. You define an array and tell
        the compiler which field of the value acts as the key.
      </p>
      <CodeBlock language="skir" filename="Skir">{`struct User {
  id: string;
  name: string;
}

struct UserRegistry {
  // Serialized as a list, but indexed by 'id' in generated code
  users: [User|id];
}`}</CodeBlock>
      <p>
        On the wire, <code>users</code> is serialized as a plain list of <code>User</code> objects.
        In the generated code, Skir automatically creates methods to perform O(1) lookups by{' '}
        <code>id</code>.
      </p>

      <h2>SkirRPC vs gRPC</h2>
      <p>
        Protobuf is typically paired with gRPC. While efficient, gRPC requires specific tooling for
        debugging (like <code>grpcui</code>) and often needs a proxy (gRPC-Web) to be called from a
        browser.
      </p>
      <p>
        SkirRPC services run over standard HTTP and are designed to be embedded into your existing
        application (Express, Flask, Spring Boot, etc.). This makes them naturally compatible with
        web clients and easy to inspect with standard tools like cURL.
      </p>
      <p>
        Additionally, every SkirRPC service comes with <strong>Skir Studio</strong> out of the box.
        This built-in interactive debugging interface allows you to explore your API and test
        methods directly in your browser, without needing to install or configure any external
        tools.
      </p>
      <div className="not-prose pt-[2px] max-w-full mx-auto mb-8">
        <HoverVideo src="/rpc-studio.mp4" />
      </div>

      <h2>Other differences</h2>

      <h3>Implicit unknown variant</h3>
      <p>
        The{' '}
        <a
          href="https://protobuf.dev/programming-guides/style/"
          target="_blank"
          rel="noopener noreferrer"
        >
          Protobuf Style Guide
        </a>{' '}
        requires you to manually add an <code>UNSPECIFIED</code> value as the first entry of every
        enum to handle default values safely:
      </p>

      <blockquote className="border-l-4 pl-4 text-muted-foreground italic my-4">
        <p>
          The first listed value should be a zero value enum and have the suffix of either{' '}
          <code>_UNSPECIFIED</code> or <code>_UNKNOWN</code>. This value may be used as an
          unknown/default value and should be distinct from any of the semantic values you expect to
          be explicitly set. For more information on the unspecified enum value, see the Proto Best
          Practices page.
        </p>
      </blockquote>

      <p>
        Skir does this automatically. Every enum in Skir has an implicit <code>unknown</code>{' '}
        variant (with index 0). This serves as the default value and captures unrecognized variants
        deserialized from newer schema versions.
      </p>

      <h3>Field numbering</h3>
      <p>
        In Skir, fields in a <code>struct</code> are numbered starting from 0, and they must use
        sequential integers (no gaps allowed). With Protobuf, field numbers must be greater than 0,
        and can be sparse (you can skip numbers).
      </p>

      <h3>Imports</h3>
      <p>
        Protobuf imports work like C includes: importing a <code>.proto</code> file brings all of
        its symbols into scope without any explicit listing. If you encounter a type like{' '}
        <code>Foo</code> that is not defined in the current file, you cannot tell which imported
        file it comes from without opening each one. Skir uses named imports, similar to TypeScript
        and Python: you explicitly list which names you are importing and from which module, making
        every dependency immediately traceable.
      </p>

      <h3>API definitions</h3>
      <p>
        In Protocol Buffers, service methods are grouped into <code>service</code> blocks. In Skir,
        methods are defined globally in the schema, and grouping is decided in the application code.
      </p>
      <p>
        In Protocol Buffers, service methods are identified by their name. In Skir, methods are
        identified by a numeric ID. This makes it safe to rename methods without breaking
        compatibility.
      </p>

      <h3>Immutability</h3>
      <p>
        Skir leans toward immutable generated data types, even in languages where that pattern is
        less common. In Python and TypeScript, for example, it generates two versions of each type:
        a deeply immutable one and a mutable one, with conversion methods between them. Protobuf
        generates only mutable data classes in these languages.
      </p>

      <h2>Final note on Buf</h2>
      <p>
        Both Skir and{' '}
        <a href="https://buf.build/" target="_blank" rel="noopener noreferrer">
          Buf
        </a>{' '}
        were created to solve the same fundamental gaps in the Protobuf ecosystem: providing a
        seamless workflow with integrated dependency management, linting, formatting, and
        breaking-change detection.
      </p>
      <p>
        The difference lies in philosophy. Buf builds the best possible ecosystem around the
        Protobuf language as it exists today. Skir, however, operates on the belief that
        Protobuf&apos;s core design flaws are significant enough to justify a new language. This
        mirrors recurring industry "evolution vs. revolution" debates, much like TypeScript vs. Dart
        or Carbon vs. Rust. While introducing a new language adds adoption cost, one can argue that
        without moving beyond legacy constraints, meaningful progress in developer experience
        remains limited.
      </p>
    </Prose>
  )
}
