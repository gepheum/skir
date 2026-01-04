import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { ResolvedType, Token } from "skir-internal";
import { BreakingChange } from "./compatibility_checker.js";
import { getShortMessageForBreakingChange } from "./error_renderer.js";
import { ModuleSet } from "./module_set.js";

describe("getShortMessageForBreakingChange", () => {
  const mockModuleSet = {} as ModuleSet;

  it("illegal-type-change", () => {
    const breakingChange: BreakingChange = {
      kind: "illegal-type-change",
      expression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      type: {
        before: { kind: "primitive", primitive: "int32" } as ResolvedType,
        after: { kind: "primitive", primitive: "string" } as ResolvedType,
      },
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Illegal type change; was: int32");
  });

  it("missing-slots", () => {
    const breakingChange: BreakingChange = {
      kind: "missing-slots",
      recordExpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: { record: { name: { text: "Foo" } } } as any,
        after: { record: { name: { text: "Foo" } } } as any,
      },
      missingRangeStart: 1,
      missingRangeEnd: 2,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Missing slots; had 2");
  });

  it("variant-kind-change (constant to wrapper)", () => {
    const breakingChange: BreakingChange = {
      kind: "variant-kind-change",
      enumEpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
        after: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
      },
      variantName: {
        before: { text: "BAR" } as Token,
        after: { text: "bar" } as Token,
      },
      number: 1,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Was a constant variant");
  });

  it("variant-kind-change (wrapper to constant)", () => {
    const breakingChange: BreakingChange = {
      kind: "variant-kind-change",
      enumEpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
        after: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
      },
      variantName: {
        before: { text: "bar" } as Token,
        after: { text: "BAR" } as Token,
      },
      number: 1,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Was a wrapper variant");
  });

  it("missing-variant", () => {
    const breakingChange: BreakingChange = {
      kind: "missing-variant",
      enumEpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
        after: {
          recordAncestors: [{ name: { text: "Foo" } }],
        } as any,
      },
      variantName: { text: "BAR" } as Token,
      number: 1,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Missing variant: 1");
  });

  it("record-kind-change (struct to enum)", () => {
    const breakingChange: BreakingChange = {
      kind: "record-kind-change",
      recordExpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: { record: { name: { text: "Foo" } } } as any,
        after: { record: { name: { text: "Foo" } } } as any,
      },
      recordType: {
        before: "struct",
        after: "enum",
      },
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Was a struct");
  });

  it("record-kind-change (enum to struct)", () => {
    const breakingChange: BreakingChange = {
      kind: "record-kind-change",
      recordExpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: { record: { name: { text: "Foo" } } } as any,
        after: { record: { name: { text: "Foo" } } } as any,
      },
      recordType: {
        before: "enum",
        after: "struct",
      },
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Was an enum");
  });

  it("removed-number-reintroduced", () => {
    const breakingChange: BreakingChange = {
      kind: "removed-number-reintroduced",
      recordExpression: {
        before: { kind: "record", recordName: { text: "Foo" } as Token },
        after: { kind: "record", recordName: { text: "Foo" } as Token },
      },
      record: {
        before: { record: { name: { text: "Foo" } } } as any,
        after: { record: { name: { text: "Foo" } } } as any,
      },
      reintroducedAs: { text: "bar" } as Token,
      removedNumber: 1,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("Number was marked as removed");
  });

  it("missing-record", () => {
    const breakingChange: BreakingChange = {
      kind: "missing-record",
      record: {
        record: {
          recordType: "struct",
          name: { text: "Foo" },
        },
        recordAncestors: [],
      } as any,
      recordNumber: 123,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("");
  });

  it("missing-method", () => {
    const breakingChange: BreakingChange = {
      kind: "missing-method",
      method: {
        name: { text: "Foo" },
        number: 123,
        requestType: { kind: "primitive", primitive: "int32" },
        responseType: { kind: "primitive", primitive: "int32" },
      } as any,
    };
    expect(
      getShortMessageForBreakingChange(breakingChange, mockModuleSet),
    ).toBe("");
  });
});
