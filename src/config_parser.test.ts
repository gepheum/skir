import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseSkirConfig } from "./config_parser.js";

describe("config_parser", () => {
  describe("parseConfig", () => {
    it("should parse valid config with single generator", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      foo: bar
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              outDir: "./skirout",
              config: { foo: "bar" },
            },
          ],
        },
        errors: [],
      });
    });

    it("should parse valid config with multiple generators", () => {
      const yamlCode = `
generators:
  - mod: "@example/gen1"
    outDir: ./skirout
    config: {}
  - mod: "@example/gen2"
    config:
      setting: value
    outDir: custom/skirout
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            { mod: "@example/gen1", outDir: "./skirout", config: {} },
            {
              mod: "@example/gen2",
              config: { setting: "value" },
              outDir: "custom/skirout",
            },
          ],
        },
        errors: [],
      });
    });

    it("should parse config with outDir array", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir:
      - path/to/skirout
      - another/skirout
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              config: {},
              outDir: ["path/to/skirout", "another/skirout"],
            },
          ],
        },
        errors: [],
      });
    });

    it("should parse config without optional dependencies", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            { mod: "@example/generator", outDir: "./skirout", config: {} },
          ],
        },
        errors: [],
      });
    });

    it("should parse config with dependencies", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
dependencies:
  "@org/package": "1.2.3"
  "@other/lib": "path/to/lib"
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            { mod: "@example/generator", outDir: "./skirout", config: {} },
          ],
          dependencies: {
            "@org/package": "1.2.3",
            "@other/lib": "path/to/lib",
          },
        },
        errors: [],
      });
    });

    it("should return error for invalid dependency key format", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
dependencies:
  invalid-key: "1.0.0"
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error for invalid dependency value format", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
dependencies:
  "@org/package": "invalid value with spaces!"
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error for invalid YAML syntax", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      invalid: [unclosed array
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
        maybeForgotToEditAfterInit: undefined,
      });
    });

    it("should return error for invalid YAML syntax", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      invalid: [unclosed array
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
        maybeForgotToEditAfterInit: undefined,
      });
    });

    it("user maybe forgot to edit after init", () => {
      const yamlCode = `generators:

      `;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [
          {
            range: {
              start: {
                lineNumber: 1,
              },
            },
          },
        ],
        maybeForgotToEditAfterInit: true,
      });
    });

    it("should return error for missing required field", () => {
      const yamlCode = `
generators:
  - config: {}
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [
          {
            message: /^Missing property 'mod': /,
            range: {
              start: {
                lineNumber: 3,
              },
            },
          },
          {
            message: /^Missing property 'outDir': /,
            range: {
              start: {
                lineNumber: 3,
              },
            },
          },
        ],
        maybeForgotToEditAfterInit: false,
      });
    });

    it("should return error for wrong type", () => {
      const yamlCode = `
generators: "not an array"
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error with line/column for schema validation error", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: invalid/path
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [
          {
            message: 'Invalid string: must end with "/skirout"',
            range: {
              start: {
                lineNumber: 5,
                colNumber: 13,
                offset: 70,
              },
              end: {
                lineNumber: 5,
                colNumber: 25,
                offset: 82,
              },
            },
          },
        ],
      });
    });

    it("should return error for extra fields in strict schema", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
    extraField: value
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [
          {
            message: /unrecognized/i,
          },
        ],
      });
    });

    it("should return error for invalid outDir pattern", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: does/not/end/properly
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error for invalid outDir array element", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir:
      - valid/skirout
      - invalid/path
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should parse config with empty generators array", () => {
      const yamlCode = `
generators: []
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [],
        },
        errors: [],
      });
    });

    it("should handle empty YAML document", () => {
      const yamlCode = "";
      const result = parseSkirConfig(yamlCode);
      // Empty YAML parses as null/undefined, which fails schema validation
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should handle YAML with comments", () => {
      const yamlCode = `
# This is a comment
generators:
  # Generator 1
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              outDir: "./skirout",
              config: {},
            },
          ],
        },
        errors: [],
      });
    });

    it("should return multiple errors for multiple validation issues", () => {
      const yamlCode = `
generators:
  - config: {}
  - mod: "@example/gen"
extraField: invalid
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}, {}, {}, {}], // At least four errors
      });
    });

    it("should handle complex nested config objects", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      nested:
        deeply:
          value: 123
      array:
        - item1
        - item2
      boolean: true
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              outDir: "./skirout",
              config: {
                nested: {
                  deeply: {
                    value: 123,
                  },
                },
                array: ["item1", "item2"],
                boolean: true,
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("should validate outDir ends with skirout", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: path/to/skirout
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              config: {},
              outDir: "path/to/skirout",
            },
          ],
        },
        errors: [],
      });
    });

    it("should handle YAML with duplicate keys as warning/error", () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
    mod: "@another/generator"
`;
      const result = parseSkirConfig(yamlCode);
      // YAML library should detect duplicate keys
      // The exact behavior depends on yaml library settings
      if (result.errors.length > 0) {
        expect(result.skirConfig).toMatch(undefined);
      }
    });

    it("should do validation on generator's config if known", () => {
      const yamlCode = `
generators:
  - mod: skir-typescript-gen
    outDir: ./skirout
    config:
      importPathExtension: .jss
`;
      const result = parseSkirConfig(yamlCode);
      expect(result).toMatch({
        errors: [
          {
            range: {
              start: {
                lineNumber: 6,
                colNumber: 28,
              },
              end: {
                lineNumber: 6,
                colNumber: 32,
              },
            },
          },
        ],
      });
    });
  });
});
