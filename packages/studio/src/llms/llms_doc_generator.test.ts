import { describe, it } from "mocha";
import assert from "node:assert/strict";
import { generateLlmsTxt, type MethodList } from "./llms_doc_generator.js";

const SERVICE_URL = "http://localhost:8787/test";

/** Extracts the single shared JSON schema block from the generated text. */
function extractSharedSchema(result: string): Record<string, unknown> {
  const match = /```json\n([\s\S]*?)\n```/.exec(result);
  assert.ok(match, "shared schema block not found");
  return JSON.parse(match![1]) as Record<string, unknown>;
}

/**
 * Minimal fixture covering all generator code paths:
 * - Two methods with doc strings
 * - Enum with const variants (with docs) + a float64 wrapper variant
 * - Shared record (t:Point) referenced by both methods → deduplication
 * - Timestamp field
 * - Keyed array (key_extractor: "shape_id")
 * - Optional string field
 */
const METHOD_LIST: MethodList = {
  methods: [
    {
      method: "Foo",
      number: "Foo",
      doc: "The Foo method",
      request: {
        type: { kind: "record", value: "t:FooRequest" },
        records: [
          {
            kind: "struct",
            id: "t:FooRequest",
            fields: [
              {
                name: "unit",
                number: 0,
                type: { kind: "record", value: "t:Unit" },
              },
            ],
          },
          {
            kind: "enum",
            id: "t:Unit",
            doc: "Unit of measurement",
            variants: [
              { name: "METERS", number: 1, doc: "Metric system" },
              { name: "FEET", number: 2, doc: "Imperial system" },
              {
                name: "custom",
                number: 3,
                doc: "Custom factor",
                type: { kind: "primitive", value: "float64" },
              },
            ],
          },
        ],
      },
      response: {
        type: { kind: "record", value: "t:FooResponse" },
        records: [
          {
            kind: "struct",
            id: "t:FooResponse",
            fields: [
              {
                name: "point",
                number: 0,
                type: { kind: "record", value: "t:Point" },
              },
              {
                name: "created_at",
                number: 1,
                type: { kind: "primitive", value: "timestamp" },
              },
            ],
          },
          {
            kind: "struct",
            id: "t:Point",
            doc: "A point in 2D space",
            fields: [
              {
                name: "x",
                number: 0,
                type: { kind: "primitive", value: "float64" },
              },
              {
                name: "y",
                number: 1,
                type: { kind: "primitive", value: "float64" },
              },
            ],
          },
        ],
      },
    },
    {
      method: "Bar",
      number: "Bar",
      doc: "The Bar method",
      request: {
        type: { kind: "record", value: "t:BarRequest" },
        records: [
          {
            kind: "struct",
            id: "t:BarRequest",
            fields: [
              {
                name: "point",
                number: 0,
                type: { kind: "record", value: "t:Point" },
              },
            ],
          },
          {
            kind: "struct",
            id: "t:Point",
            doc: "A point in 2D space",
            fields: [
              {
                name: "x",
                number: 0,
                type: { kind: "primitive", value: "float64" },
              },
              {
                name: "y",
                number: 1,
                type: { kind: "primitive", value: "float64" },
              },
            ],
          },
        ],
      },
      response: {
        type: { kind: "record", value: "t:BarResponse" },
        records: [
          {
            kind: "struct",
            id: "t:BarResponse",
            fields: [
              {
                name: "results",
                number: 0,
                type: {
                  kind: "array",
                  value: {
                    item: { kind: "record", value: "t:Result" },
                    key_extractor: "shape_id",
                  },
                },
              },
            ],
          },
          {
            kind: "struct",
            id: "t:Result",
            fields: [
              {
                name: "shape_id",
                number: 0,
                type: { kind: "primitive", value: "string" },
              },
              {
                name: "error",
                number: 1,
                type: {
                  kind: "optional",
                  value: { kind: "primitive", value: "string" },
                },
              },
            ],
          },
        ],
      },
    },
  ],
};

describe("generateLlmsTxt", () => {
  // ---------------------------------------------------------------------------
  // Snapshot test: overall structure.
  // ---------------------------------------------------------------------------

  it("produces the expected output", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);

    // Header
    assert.ok(result.startsWith("# "));
    assert.ok(result.includes(`Base URL: ${SERVICE_URL}`));

    // Both methods present with their doc strings
    assert.ok(result.includes("### Foo"));
    assert.ok(result.includes("### Bar"));
    assert.ok(result.includes("The Foo method"));
    assert.ok(result.includes("The Bar method"));

    // One curl block per method
    const curlMatches = result.match(/curl -X POST/g);
    assert.equal(curlMatches?.length, 2, "one curl block per method");

    // Exactly one JSON schema block
    const schemaBlocks = [...result.matchAll(/```json\n([\s\S]*?)\n```/g)];
    assert.equal(schemaBlocks.length, 1, "exactly one shared schema block");
    assert.doesNotThrow(
      () => JSON.parse(schemaBlocks[0]![1]!),
      "shared schema is valid JSON",
    );
  });

  it("handles an empty method list gracefully", () => {
    const result = generateLlmsTxt({ methods: [] }, SERVICE_URL);
    assert.ok(result.includes("# "));
    assert.ok(!result.includes("### "), "no method headings");
  });

  it("auth=auth adds Authorization header to every curl block", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL, "auth");
    const curlBlocks = [...result.matchAll(/```bash\n([\s\S]*?)\n```/g)].map(
      (m) => m[1]!,
    );
    assert.equal(curlBlocks.length, 2, "one curl block per method");
    for (const block of curlBlocks) {
      assert.ok(
        block.includes('-H "Authorization: Bearer ${MY_API_BEARER_TOKEN}"'),
        "each curl block has the Authorization header",
      );
    }
  });

  it("auth=auth adds a warning about MY_API_BEARER_TOKEN; no-auth does not", () => {
    const withAuth = generateLlmsTxt(METHOD_LIST, SERVICE_URL, "auth");
    const noAuth = generateLlmsTxt(METHOD_LIST, SERVICE_URL, "no-auth");
    assert.ok(
      withAuth.includes("MY_API_BEARER_TOKEN"),
      "warning present when auth",
    );
    assert.ok(
      !noAuth.includes("MY_API_BEARER_TOKEN"),
      "warning absent when no-auth",
    );
  });

  // ---------------------------------------------------------------------------
  // Unit: shared $defs contains all record types.
  // ---------------------------------------------------------------------------

  it("emits a single shared $defs containing all record types", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;

    assert.ok("t:FooRequest" in defs, "t:FooRequest present");
    assert.ok("t:FooResponse" in defs, "t:FooResponse present");
    assert.ok("t:Unit" in defs, "t:Unit enum present");
    assert.ok("t:Point" in defs, "t:Point present (shared across methods)");
    assert.ok("t:BarRequest" in defs, "t:BarRequest present");
    assert.ok("t:BarResponse" in defs, "t:BarResponse present");
    assert.ok("t:Result" in defs, "t:Result present");
  });

  it("adds complex primitive types to $defs only when used", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;

    // Used → must be present.
    assert.ok("$primitive:float64" in defs, "$primitive:float64 in $defs");
    assert.ok("$primitive:timestamp" in defs, "$primitive:timestamp in $defs");

    // Not used → must be absent.
    assert.ok(!("$primitive:float32" in defs), "$primitive:float32 absent");
    assert.ok(!("$primitive:int64" in defs), "$primitive:int64 absent");
    assert.ok(!("$primitive:hash64" in defs), "$primitive:hash64 absent");
    assert.ok(!("$primitive:bytes" in defs), "$primitive:bytes absent");
  });

  it("fields referencing float64 use $ref to $primitive:float64", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;
    const point = defs["t:Point"] as Record<string, unknown>;
    const props = point["properties"] as Record<string, unknown>;
    const x = props["x"] as Record<string, unknown>;
    assert.equal(
      x["$ref"],
      "#/$defs/$primitive:float64",
      "float64 field uses $ref",
    );
  });

  it("per-method request/response root schemas are in $defs", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;

    assert.ok("Foo:request" in defs);
    assert.ok("Foo:response" in defs);
    assert.ok("Bar:request" in defs);
    assert.ok("Bar:response" in defs);
  });

  // ---------------------------------------------------------------------------
  // Unit: enum with both constant and wrapper variants.
  // ---------------------------------------------------------------------------

  it("represents t:Unit enum correctly in JSON Schema", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;
    const unit = defs["t:Unit"] as Record<string, unknown>;

    assert.ok(Array.isArray(unit["oneOf"]), "t:Unit uses oneOf");
    const options = unit["oneOf"] as Array<Record<string, unknown>>;
    const constOpt = options[0]!;
    assert.equal(constOpt["type"], "string");
    assert.ok((constOpt["enum"] as string[]).includes("UNKNOWN"));
    assert.ok((constOpt["enum"] as string[]).includes("METERS"));
    const customOpt = options[1] as Record<string, unknown>;
    assert.equal(customOpt["type"], "object");
    const kindProp = (customOpt["properties"] as Record<string, unknown>)[
      "kind"
    ] as Record<string, unknown>;
    assert.deepEqual(kindProp["enum"], ["custom"]);
  });

  // ---------------------------------------------------------------------------
  // Unit: optional field → oneOf [null, T].
  // ---------------------------------------------------------------------------

  it("serializes optional fields as oneOf null + inner type", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;
    const resultStruct = defs["t:Result"] as Record<string, unknown>;
    const props = resultStruct["properties"] as Record<string, unknown>;
    const errorProp = props["error"] as Record<string, unknown>;
    assert.ok(
      Array.isArray(errorProp["oneOf"]),
      "optional 'error' field uses oneOf",
    );
    const oneOf = errorProp["oneOf"] as Array<Record<string, unknown>>;
    assert.ok(
      oneOf.some((o) => o["type"] === "null"),
      "oneOf includes null",
    );
    assert.ok(
      oneOf.some((o) => o["type"] === "string"),
      "oneOf includes string",
    );
  });

  // ---------------------------------------------------------------------------
  // Unit: keyed array surfaced in description.
  // ---------------------------------------------------------------------------

  it("documents the key_extractor of a keyed array", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    assert.ok(
      result.includes("shape_id"),
      "key_extractor 'shape_id' appears in output",
    );
  });

  // ---------------------------------------------------------------------------
  // Unit: timestamp primitive schema.
  // ---------------------------------------------------------------------------

  it("maps timestamp to an object schema with unix_millis min/max", () => {
    const result = generateLlmsTxt(METHOD_LIST, SERVICE_URL);
    const defs = extractSharedSchema(result)["$defs"] as Record<
      string,
      unknown
    >;
    const ts = defs["$primitive:timestamp"] as Record<string, unknown>;
    assert.equal(ts["type"], "object");
    const tsProps = ts["properties"] as Record<string, unknown>;
    assert.ok("unix_millis" in tsProps, "timestamp has unix_millis");
    assert.ok(!("formatted" in tsProps), "timestamp has no formatted field");
    const unixMillis = tsProps["unix_millis"] as Record<string, unknown>;
    assert.equal(unixMillis["minimum"], Number.MIN_SAFE_INTEGER);
    assert.equal(unixMillis["maximum"], Number.MAX_SAFE_INTEGER);
  });

  // ---------------------------------------------------------------------------
  // Unit: int64 pattern, hash64 pattern, bytes pattern.
  // ---------------------------------------------------------------------------

  it("int64 string branch has the correct sign-aware pattern", () => {
    const list: MethodList = {
      methods: [
        {
          method: "M",
          number: "M",
          request: {
            type: { kind: "record", value: "t:Req" },
            records: [
              {
                kind: "struct",
                id: "t:Req",
                fields: [
                  {
                    name: "v",
                    number: 0,
                    type: { kind: "primitive", value: "int64" },
                  },
                ],
              },
            ],
          },
          response: { type: { kind: "primitive", value: "bool" }, records: [] },
        },
      ],
    };
    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;
    const int64 = defs["$primitive:int64"] as Record<string, unknown>;
    const oneOf = int64["oneOf"] as Array<Record<string, unknown>>;
    const strBranch = oneOf.find((o) => o["type"] === "string")!;
    assert.equal(strBranch["pattern"], "^-?(?:0|[1-9][0-9]*)$");
  });

  it("hash64 string branch has an unsigned-only pattern", () => {
    const list: MethodList = {
      methods: [
        {
          method: "M",
          number: "M",
          request: {
            type: { kind: "record", value: "t:Req" },
            records: [
              {
                kind: "struct",
                id: "t:Req",
                fields: [
                  {
                    name: "v",
                    number: 0,
                    type: { kind: "primitive", value: "hash64" },
                  },
                ],
              },
            ],
          },
          response: { type: { kind: "primitive", value: "bool" }, records: [] },
        },
      ],
    };
    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;
    const hash64 = defs["$primitive:hash64"] as Record<string, unknown>;
    const oneOf = hash64["oneOf"] as Array<Record<string, unknown>>;
    const strBranch = oneOf.find((o) => o["type"] === "string")!;
    assert.equal(strBranch["pattern"], "^(?:0|[1-9][0-9]*)$");
  });

  it("bytes pattern requires even-length hex digits", () => {
    const list: MethodList = {
      methods: [
        {
          method: "M",
          number: "M",
          request: {
            type: { kind: "record", value: "t:Req" },
            records: [
              {
                kind: "struct",
                id: "t:Req",
                fields: [
                  {
                    name: "v",
                    number: 0,
                    type: { kind: "primitive", value: "bytes" },
                  },
                ],
              },
            ],
          },
          response: { type: { kind: "primitive", value: "bool" }, records: [] },
        },
      ],
    };
    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;
    const bytes = defs["$primitive:bytes"] as Record<string, unknown>;
    assert.equal(bytes["pattern"], "^hex:([0-9a-fA-F]{2})*$");
  });

  // ---------------------------------------------------------------------------
  // Unit: recursive types – the generator must not infinite-loop and must
  // produce valid $ref back-references.
  // ---------------------------------------------------------------------------

  /** Helper: build a one-method MethodList whose request is the given records. */
  function makeList(
    rootId: string,
    records: MethodList["methods"][number]["request"]["records"],
  ): MethodList {
    return {
      methods: [
        {
          method: "M",
          number: "M",
          request: {
            type: { kind: "record", value: rootId },
            records,
          },
          response: { type: { kind: "primitive", value: "bool" }, records: [] },
        },
      ],
    };
  }

  it("handles a directly self-recursive type without hanging", () => {
    // t:Node { value: int32, children: t:Node[] }
    const list = makeList("t:Node", [
      {
        kind: "struct",
        id: "t:Node",
        fields: [
          {
            name: "value",
            number: 0,
            type: { kind: "primitive", value: "int32" },
          },
          {
            name: "children",
            number: 1,
            type: {
              kind: "array",
              value: {
                item: { kind: "record", value: "t:Node" },
              },
            },
          },
        ],
      },
    ]);

    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;

    assert.ok("t:Node" in defs, "t:Node is in $defs");

    const node = defs["t:Node"] as Record<string, unknown>;
    const props = node["properties"] as Record<string, unknown>;
    const children = props["children"] as Record<string, unknown>;

    assert.equal(children["type"], "array", "children is an array");
    const items = children["items"] as Record<string, unknown>;
    assert.equal(
      items["$ref"],
      "#/$defs/t:Node",
      "children items $ref points back to t:Node",
    );
  });

  it("handles a directly self-recursive optional field without hanging", () => {
    // t:TreeNode { value: int32, parent: optional t:TreeNode }
    const list = makeList("t:TreeNode", [
      {
        kind: "struct",
        id: "t:TreeNode",
        fields: [
          {
            name: "value",
            number: 0,
            type: { kind: "primitive", value: "int32" },
          },
          {
            name: "parent",
            number: 1,
            type: {
              kind: "optional",
              value: { kind: "record", value: "t:TreeNode" },
            },
          },
        ],
      },
    ]);

    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;

    assert.ok("t:TreeNode" in defs, "t:TreeNode is in $defs");

    const node = defs["t:TreeNode"] as Record<string, unknown>;
    const props = node["properties"] as Record<string, unknown>;
    const parent = props["parent"] as Record<string, unknown>;

    const oneOf = parent["oneOf"] as Array<Record<string, unknown>>;
    assert.ok(
      oneOf.some((o) => o["type"] === "null"),
      "parent oneOf includes null",
    );
    assert.ok(
      oneOf.some((o) => o["$ref"] === "#/$defs/t:TreeNode"),
      "parent oneOf includes $ref to t:TreeNode",
    );
  });

  it("handles mutually recursive types without hanging", () => {
    // t:A { b: t:B }   t:B { a: optional t:A }
    const list = makeList("t:A", [
      {
        kind: "struct",
        id: "t:A",
        fields: [
          { name: "b", number: 0, type: { kind: "record", value: "t:B" } },
        ],
      },
      {
        kind: "struct",
        id: "t:B",
        fields: [
          {
            name: "a",
            number: 0,
            type: {
              kind: "optional",
              value: { kind: "record", value: "t:A" },
            },
          },
        ],
      },
    ]);

    const defs = extractSharedSchema(generateLlmsTxt(list, SERVICE_URL))[
      "$defs"
    ] as Record<string, unknown>;

    assert.ok("t:A" in defs, "t:A is in $defs");
    assert.ok("t:B" in defs, "t:B is in $defs");

    // t:A.b → $ref to t:B
    const aProps = (defs["t:A"] as Record<string, unknown>)[
      "properties"
    ] as Record<string, unknown>;
    assert.equal(
      (aProps["b"] as Record<string, unknown>)["$ref"],
      "#/$defs/t:B",
      "t:A.b $ref points to t:B",
    );

    // t:B.a → oneOf [null, $ref t:A]
    const bProps = (defs["t:B"] as Record<string, unknown>)[
      "properties"
    ] as Record<string, unknown>;
    const aField = bProps["a"] as Record<string, unknown>;
    const oneOf = aField["oneOf"] as Array<Record<string, unknown>>;
    assert.ok(
      oneOf.some((o) => o["$ref"] === "#/$defs/t:A"),
      "t:B.a oneOf includes $ref to t:A",
    );
  });
});
