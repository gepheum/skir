# Schema design: best practices

This section contains an opinionated list of rules for writing good Skir schemas.

When followed, these practices will help you design APIs that are robust, consistent, easy to evolve, and safe to use across different languages.

## When in doubt, wrap it in a struct

The most common evolution pitfall is starting with primitives _because it's simpler_ and getting stuck the first time you need to add one more attribute.

A tiny wrapper struct costs almost nothing upfront, but it buys you an easy extension point later. This is especially valuable for list elements and method request/response types.

### Wrap elements of arrays

If you store an array of primitives (`string`, `int32`, …), remember that in the future you may want to attach metadata to each element (for example, when it was added or where it came from).

```skir [Don]
struct Product {
  // ...
  tags: [string];
}
```

```skir [Do (easy to extend)]
struct Product {
  // ...
  struct Tag {
    value: string;
    // added_at: timestamp;   // easy future evolution
  }

  tags: [Tag];
}
```

With the wrapper approach, adding a field to `Tag` is a safe, compatible schema evolution. You don't need awkward parallel arrays or other ad-hoc workarounds.

### Wrap method inputs and outputs

The same idea applies to APIs. A method signature like * `string` → `bool` * looks clean, but it gives you very little room to grow.

```skir [Don]
method IsPalindrome(string): bool = 2000;
```

```skir [Do (extensible)]
method IsPalindrome(
  struct {
    word: string;
  }
): struct {
  result: bool;
} = 2000;
```

Later, you can evolve it without breaking callers (and without inventing new methods for every little feature):

```skir [Later evolution]
method AnalyzeWord(
  struct {
    word: string;
    case_sensitive: bool;  // New field
  }
): struct {
  is_palindrome: bool;
  is_semordnilap: bool;  // New field
} = 2000;
```

::: tip
This habit pairs perfectly with the rules in [Schema evolution](/docs/schema-evolution). Wrapper structs make _adding fields later_ the default path.
:::

## Prefer wrapper structs for enriched views

If a type `A` exists in multiple stages of a flow, you will often end up with an _enriched_ version of it: you start with `A`, then later attach some extra data `B` (permissions, computed pricing, resolved references, cache metadata, etc.).

It can look tempting to add a `B?` field directly on `A` and explain in a comment that it is only populated in some parts of the flow. Avoid that.

```skir [Don]
struct Permissions {
  can_edit: bool;
  can_delete: bool;
}

struct User {
  id: hash64;
  name: string;

  // Only populated after an authorization step.
  permissions: Permissions?;
}
```

The problem is that this rule lives in prose, not in the type system. In practice, the optional field becomes a footgun: it is easy to forget when it is present, and nothing forces callers to handle the "unenriched" state.

Prefer defining a new wrapper type that makes the enrichment explicit:

```skir [Do (make enrichment a different type)]
struct Permissions {
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
}
```

This is more type-safe, reads better at call sites, and scales well over time (you can add other enriched views without turning the base type into a grab-bag of conditional fields).

## Don't overuse optional types

Optional types (`T?`) are great when _missing_ is a distinct state. But they also propagate into generated APIs and typically add extra branching in client code.

If the default value of `T` is an acceptable representation of _not set_ (e.g. `""` for strings, `0` for numbers, `[]` for arrays), prefer a non-optional field and document the convention.

```skir
struct Product {
  /// Can be empty.
  description: string;
}
```

Use `T?` when you truly need to distinguish _not provided_ from _provided with a default value_.

## Use the `timestamp` type for instants

If a field represents an instant in time, use the `timestamp` primitive instead of a numeric type.

```skir [Don]
struct User {
  // Is this seconds? milliseconds? microseconds?
  last_visit: int64;
}
```

```skir [Do]
struct User {
  last_visit: timestamp;
}
```

This makes it much harder to mix up units (seconds vs milliseconds) — a surprisingly common pitfall that often slips past compile-time checks — and it tends to produce more readable debug output across languages.

## Prefer good names over doc comments

Good documentation starts with good names.

If a symbol name can carry the key information (units, meaning, constraints) without being absurdly long, put it in the name.

Doc comments should be added when they provide extra value (examples, rationale, edge cases, invariants) - not just to restate what a better name could have said.

```skir [Don]
struct Telemetry {
  /// Duration in milliseconds.
  request_timeout: int64;

  /// Speed in kilometers per hour.
  max_speed: int32;
}
```

```skir [Do (encode the crucial info in the name)]
struct Telemetry {
  request_timeout_millis: int64;
  max_speed_kmph: int32;
}
```

Adding the unit to the name usually only makes it slightly longer, but it carries crucial information and significantly reduces the risk of accidentally mixing up units (which the compiler typically cannot catch).

Once the name is explicit, the doc comment often stops adding value - so it can be removed.

## Keep nested type names short

Nested types are a great way to keep a schema readable: they group related definitions together and reduce global namespace clutter.

When a type `B` is nested inside `A`, users will reference it as `A.B`. Because the parent name is already present, the nested name should avoid repeating it.

```skir [Don]
struct UserHistory {
  struct HistoricalUserAction {
    // ...
  }

  actions: [HistoricalUserAction];
}
```

```skir [Do]
struct UserHistory {
  struct Action {
    // ...
  }

  actions: [Action];
}
```

## Model expected outcomes in the response type

Transport errors (HTTP errors, exceptions, etc.) are for _unexpected_ failures: the user is unauthorized, the server is unhealthy, a dependency timed out.

If an outcome is part of normal operation (not found, already exists, invalid input you want to report precisely…), model it in the response type so clients can handle it in a typed, exhaustive way.

```skir [Don]
method GetProduct(
  struct {
    product_id: hash64;
  }
): Product = 1000;
// "Not found" would have to be communicated via HTTP errors.
```

```skir [Do (explicit)]
method GetProduct(
  struct {
    product_id: string;
  }
): enum {
  ok: Product;
  not_found;
  retired;
  invalid_product_id: string;
} = 1000;
```

::: info
It's still fine to use HTTP errors for _you can't do that_ situations (unauthorized, forbidden) or infrastructure failures. The rule is: don't use transport errors as a second return type.
:::
