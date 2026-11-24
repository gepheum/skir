import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { ONE_CONSTANT } from "../skirout/constants.js";

describe("module-level constants", () => {
  it("work", () => {
    expect(ONE_CONSTANT).toMatch({
      union: {
        kind: "array",
        value: [
          {
            union: {
              kind: "boolean",
              value: true,
            },
          },
          {
            union: {
              kind: "number",
              value: 2.5,
            },
          },
          {
            union: {
              kind: "string",
              value: ["", "        foo", "        bar"].join("\n"),
            },
          },
          {
            union: {
              kind: "object",
              value: [
                {
                  name: "foo",
                  value: {
                    union: {
                      kind: "NULL",
                      value: undefined,
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    });
  });
});
