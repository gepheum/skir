import { describe, it } from "mocha";
import assert from "node:assert/strict";
import * as skir from "../src/skir-client.js";

describe("generated class support", () => {
  class Node extends skir._FrozenBase {
    constructor(privateKey?: symbol) {
      super(privateKey!);
    }

    declare readonly value: number;
    declare readonly next: Node;
    declare static DEFAULT: Node;
    declare static create: (initializer: Partial<Node>) => Node;
    declare static Mutable: new (initializer?: Partial<Node>) => {
      value: number;
      next: Node;
      toFrozen(): Node;
    };
    declare static serializer: skir.Serializer<Node>;
    declare [skir._INITIALIZER]: { value?: number; next?: Node };
  }

  class Choice extends skir._EnumBase {
    constructor(privateKey: symbol, kind: string, value?: unknown) {
      super(privateKey, kind, value);
    }

    declare readonly union:
      | { kind: "UNKNOWN" | "EMPTY"; value: undefined }
      | { kind: "number"; value: number };
    declare static UNKNOWN: Choice;
    declare static EMPTY: Choice;
    declare static create: (
      initializer: "EMPTY" | { kind: "number"; value: number },
    ) => Choice;
    declare static serializer: skir.Serializer<Choice>;
  }

  skir._initModuleClasses("test.skir", [
    {
      kind: "struct",
      ctor: Node,
      name: "Node",
      initFn: (target: unknown, initializer: unknown): void => {
        const input = initializer as Partial<Node>;
        Object.assign(target as object, {
          value: input.value ?? 0,
          next: input.next ?? Node.DEFAULT,
        });
      },
      fields: [
        {
          name: "value",
          property: "value",
          number: 0,
          type: { kind: "primitive", primitive: "int32" },
        },
        {
          name: "next",
          property: "next",
          number: 1,
          type: { kind: "record", ctor: Node },
        },
      ],
    },
    {
      kind: "enum",
      ctor: Choice,
      name: "Choice",
      createValueFn: (initializer: unknown): unknown =>
        (initializer as { value?: unknown }).value,
      variants: [
        { name: "EMPTY", number: 1 },
        {
          name: "number",
          number: 2,
          type: { kind: "primitive", primitive: "int32" },
        },
      ],
    },
  ]);

  it("initializes recursive defaults without freezing them too early", () => {
    assert.equal(Node.DEFAULT.next, Node.DEFAULT);
    assert(Object.isFrozen(Node.DEFAULT));
    assert(Object.isFrozen(Node));
    assert.equal(Node.serializer.fromJson(0), Node.DEFAULT);
    assert.equal(Node.serializer.typeDescriptor.getField("value").number, 0);
  });

  it("reconstructs recursive descriptors and transforms nested values", () => {
    const descriptor = skir.parseTypeDescriptorFromJsonCode(
      Node.serializer.typeDescriptor.asJsonCode(),
    );
    assert.equal(descriptor.kind, "struct");
    assert(descriptor.kind === "struct");
    assert.equal(descriptor.getField("next")!.type, descriptor);
    assert(Object.isFrozen(descriptor));
    assert(Object.isFrozen(descriptor.fields));

    const dense = [1, [2]];
    const readable = { value: 1, next: { value: 2 } };
    assert.deepEqual(descriptor.transform(dense, "readable"), readable);
    const bytes = descriptor.transform(readable, "bytes");
    assert.deepEqual(descriptor.transform(bytes, "dense"), dense);
    assert.deepEqual(
      Node.serializer.toJson(Node.serializer.fromBytes(bytes)),
      dense,
    );
  });

  it("preserves generated struct identity across serialization and mutation", () => {
    const node = Node.create({ value: 42 });
    assert(node instanceof Node);
    assert(Object.isFrozen(node));
    assert.equal(node.next, Node.DEFAULT);
    const decoded = Node.serializer.fromBytes(
      Node.serializer.toBytes(node).toBuffer(),
    );
    assert(decoded instanceof Node);
    assert.equal(decoded.value, 42);
    const mutable = node.toMutable() as InstanceType<typeof Node.Mutable>;
    mutable.value = 7;
    assert.equal(mutable.toFrozen().value, 7);
    assert.equal(node.value, 42);
    assert.equal(node.toString(), Node.serializer.toJsonCode(node, "readable"));
  });

  it("preserves enum constants and wrapper variants", () => {
    assert.equal(Choice.create("EMPTY"), Choice.EMPTY);
    const choice = Choice.create({ kind: "number", value: 42 });
    const decoded = Choice.serializer.fromBytes(
      Choice.serializer.toBytes(choice).toBuffer(),
    );
    assert(decoded instanceof Choice);
    assert.deepEqual(decoded.union, choice.union);
    assert.equal(Choice.serializer.fromJson(0), Choice.UNKNOWN);
    const variant = Choice.serializer.typeDescriptor.getVariant("number");
    assert("wrap" in variant);
    assert.equal(variant.wrap(7).union.value, 7);
  });

  it("reuses frozen arrays and copies mutable arrays", () => {
    const input = [Node.create({ value: 42 })];
    const frozen = skir._toFrozenArray<Node, Node>(input);
    assert.notEqual(frozen, input);
    assert(Object.isFrozen(frozen));
    assert.equal(skir._toFrozenArray<Node, Node>(frozen), frozen);
    assert.equal(
      skir._toFrozenArray([]),
      skir.arraySerializer(skir.primitiveSerializer("int32")).fromJson(0),
    );
  });
});
