import { CodeBlock, Note, Prose } from '@/components/prose'

export const metadata = {
  title: 'Schema design: best practices - Skir Documentation',
  description:
    'Practical rules for writing Skir schemas that stay readable, maintainable, and easy to evolve.',
}

export default function BestPracticesPage() {
  return (
    <Prose>
      <h1>Schema design: best practices</h1>
      <p>This section contains an opinionated list of rules for writing good Skir schemas.</p>
      <p>
        When followed, these practices will help you design APIs that are robust, consistent, easy
        to evolve, and safe to use across different languages.
      </p>

      <h2>When in doubt, wrap it in a struct</h2>
      <p>
        The most common evolution pitfall is starting with primitives <em>because it's simpler</em>{' '}
        and getting stuck the first time you need to add one more attribute.
      </p>
      <p>
        A tiny wrapper struct costs almost nothing upfront, but it buys you an easy extension point
        later. This is especially valuable for list elements and method request/response types.
      </p>

      <h3>Wrap elements of arrays</h3>
      <p>
        If you store an array of primitives (<code>string</code>, <code>int32</code>, …), remember
        that in the future you may want to attach metadata to each element (for example, when it was
        added or where it came from).
      </p>

      <CodeBlock language="skir" filename="Don't (hard to extend)">{`struct Product {
  // ...
  tags: [string];
}`}</CodeBlock>

      <CodeBlock language="skir" filename="Do (easy to extend)">{`struct Product {
  // ...
  struct Tag {
    value: string;
    // added_at: timestamp;   // easy future evolution
  }

  tags: [Tag];
}`}</CodeBlock>

      <p>
        With the wrapper approach, adding a field to <code>Tag</code> is a safe, compatible schema
        evolution. You don't need awkward parallel arrays or other ad-hoc workarounds.
      </p>

      <h3>Wrap method inputs and outputs</h3>
      <p>
        The same idea applies to APIs. A method signature like{' '}
        <em>
          <code>string</code> → <code>bool</code>
        </em>{' '}
        looks clean, but it gives you very little room to grow.
      </p>

      <CodeBlock
        language="skir"
        filename="Don't (no room to grow)"
      >{`method IsPalindrome(string): bool = 2000;`}</CodeBlock>

      <CodeBlock language="skir" filename="Do (extensible)">{`method IsPalindrome(
  struct {
    word: string;
  }
): struct {
  result: bool;
} = 2000;`}</CodeBlock>

      <p>
        Later, you can evolve it without breaking callers (and without inventing new methods for
        every little feature):
      </p>

      <CodeBlock language="skir" filename="Later evolution">{`method AnalyzeWord(
  struct {
    word: string;
    case_sensitive: bool;  // New field
  }
): struct {
  is_palindrome: bool;
  is_semordnilap: bool;  // New field
} = 2000;`}</CodeBlock>

      <Note type="tip">
        <p>
          This habit pairs perfectly with the rules in{' '}
          <a href="/docs/schema-evolution">Schema evolution</a>. Wrapper structs make{' '}
          <em>adding fields later</em> the default path.
        </p>
      </Note>

      <h2>Prefer wrapper structs for enriched views</h2>
      <p>
        If a type <code>A</code> exists in multiple stages of a flow, you will often end up with an
        <em>enriched</em> version of it: you start with <code>A</code>, then later attach some extra
        data <code>B</code> (permissions, computed pricing, resolved references, cache metadata,
        etc.).
      </p>
      <p>
        It can look tempting to add a <code>B?</code> field directly on <code>A</code> and explain
        in a comment that it is only populated in some parts of the flow. Avoid that.
      </p>

      <CodeBlock
        language="skir"
        filename="Don't (partial A with a conditional field)"
      >{`struct Permissions {
  can_edit: bool;
  can_delete: bool;
}

struct User {
  id: hash64;
  name: string;

  // Only populated after an authorization step.
  permissions: Permissions?;
}`}</CodeBlock>

      <p>
        The problem is that this rule lives in prose, not in the type system. In practice, the
        optional field becomes a footgun: it is easy to forget when it is present, and nothing
        forces callers to handle the "unenriched" state.
      </p>
      <p>Prefer defining a new wrapper type that makes the enrichment explicit:</p>

      <CodeBlock
        language="skir"
        filename="Do (make enrichment a different type)"
      >{`struct Permissions {
  can_edit: bool;
  can_delete: bool;
}

struct User {
  id: hash64;
  name: string;
}

struct UserBundle {
  user: User;
  permissions: Permissions;
}`}</CodeBlock>

      <p>
        This is more type-safe, reads better at call sites, and scales well over time (you can add
        other enriched views without turning the base type into a grab-bag of conditional fields).
      </p>

      <h2>Don't overuse optional types</h2>
      <p>
        Optional types (<code>T?</code>) are great when <em>missing</em> is a distinct state. But
        they also propagate into generated APIs and typically add extra branching in client code.
      </p>
      <p>
        If the default value of <code>T</code> is an acceptable representation of <em>not set</em>{' '}
        (e.g. <code>""</code> for strings, <code>0</code> for numbers, <code>[]</code> for arrays),
        prefer a non-optional field and document the convention.
      </p>

      <CodeBlock language="skir">{`struct Product {
  /// Can be empty.
  description: string;
}`}</CodeBlock>

      <p>
        Use <code>T?</code> when you truly need to distinguish <em>not provided</em> from{' '}
        <em>provided with a default value</em>.
      </p>

      <h2>
        Use the <code>timestamp</code> type for instants
      </h2>
      <p>
        If a field represents an instant in time, use the <code>timestamp</code> primitive instead
        of a numeric type.
      </p>

      <CodeBlock language="skir" filename="Don't">{`struct User {
  // Is this seconds? milliseconds? microseconds?
  last_visit: int64;
}`}</CodeBlock>

      <CodeBlock language="skir" filename="Do">{`struct User {
  last_visit: timestamp;
}`}</CodeBlock>

      <p>
        This makes it much harder to mix up units (seconds vs milliseconds) — a surprisingly common
        pitfall that often slips past compile-time checks — and it tends to produce more readable
        debug output across languages.
      </p>

      <h2>Prefer good names over doc comments</h2>
      <p>Good documentation starts with good names.</p>
      <p>
        If a symbol name can carry the key information (units, meaning, constraints) without being
        absurdly long, put it in the name.
      </p>
      <p>
        Doc comments should be added when they provide extra value (examples, rationale, edge cases,
        invariants) - not just to restate what a better name could have said.
      </p>

      <CodeBlock
        language="skir"
        filename="Don't (comments compensate for vague names)"
      >{`struct Telemetry {
  /// Duration in milliseconds.
  request_timeout: int64;

  /// Speed in kilometers per hour.
  max_speed: int32;
}`}</CodeBlock>

      <CodeBlock
        language="skir"
        filename="Do (encode the crucial info in the name)"
      >{`struct Telemetry {
  request_timeout_millis: int64;
  max_speed_kmph: int32;
}`}</CodeBlock>

      <p>
        Adding the unit to the name usually only makes it slightly longer, but it carries crucial
        information and significantly reduces the risk of accidentally mixing up units (which the
        compiler typically cannot catch).
      </p>
      <p>
        Once the name is explicit, the doc comment often stops adding value - so it can be removed.
      </p>

      <h2>Keep nested type names short</h2>
      <p>
        Nested types are a great way to keep a schema readable: they group related definitions
        together and reduce global namespace clutter.
      </p>
      <p>
        When a type <code>B</code> is nested inside <code>A</code>, users will reference it as{' '}
        <code>A.B</code>. Because the parent name is already present, the nested name should avoid
        repeating it.
      </p>

      <CodeBlock language="skir" filename="Don't">{`struct UserHistory {
  struct HistoricalUserAction {
    // ...
  }

  actions: [HistoricalUserAction];
}`}</CodeBlock>

      <CodeBlock language="skir" filename="Do">{`struct UserHistory {
  struct Action {
    // ...
  }

  actions: [Action];
}`}</CodeBlock>

      <h2>Model expected outcomes in the response type</h2>
      <p>
        Transport errors (HTTP errors, exceptions, etc.) are for <em>unexpected</em> failures: the
        user is unauthorized, the server is unhealthy, a dependency timed out.
      </p>
      <p>
        If an outcome is part of normal operation (not found, already exists, invalid input you want
        to report precisely…), model it in the response type so clients can handle it in a typed,
        exhaustive way.
      </p>

      <CodeBlock language="skir" filename="Don't (ambiguous)">{`method GetProduct(
  struct {
    product_id: hash64;
  }
): Product = 1000;
// "Not found" would have to be communicated via HTTP errors.`}</CodeBlock>

      <CodeBlock language="skir" filename="Do (explicit)">{`method GetProduct(
  struct {
    product_id: string;
  }
): enum {
  ok: Product;
  not_found;
  retired;
  invalid_product_id: string;
} = 1000;`}</CodeBlock>

      <Note type="info">
        <p>
          It's still fine to use HTTP errors for <em>you can't do that</em> situations
          (unauthorized, forbidden) or infrastructure failures. The rule is: don't use transport
          errors as a second return type.
        </p>
      </Note>
    </Prose>
  )
}
