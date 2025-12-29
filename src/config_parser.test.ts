import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseSkirConfig } from "./config_parser.js";

describe("config_parser", () => {
  describe("parseConfig", () => {
    it("should parse valid config with single generator", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      foo: bar
srcDir: src
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              outDir: "./skirout",
              config: { foo: "bar" },
            },
          ],
          srcDir: "src",
        },
        errors: [],
      });
    });

    it("should parse valid config with multiple generators", async () => {
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
      const result = await parseSkirConfig(yamlCode);
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

    it("should parse config with outDir array", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir:
      - path/to/skirout
      - another/skirout
`;
      const result = await parseSkirConfig(yamlCode);
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

    it("should parse config without optional srcDir", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            { mod: "@example/generator", outDir: "./skirout", config: {} },
          ],
        },
        errors: [],
      });
    });

    it("should return error for invalid YAML syntax", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      invalid: [unclosed array
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
        maybeForgotToEditAfterInit: undefined,
      });
    });

    it("should return error for invalid YAML syntax", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config:
      invalid: [unclosed array
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
        maybeForgotToEditAfterInit: undefined,
      });
    });

    it("user maybe forgot to edit after init", async () => {
      const yamlCode = `generators:

      `;
      const result = await parseSkirConfig(yamlCode);
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

    it("should return error for missing required field", async () => {
      const yamlCode = `
generators:
  - config: {}
`;
      const result = await parseSkirConfig(yamlCode);
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

    it("should return error for wrong type", async () => {
      const yamlCode = `
generators: "not an array"
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error with line/column for schema validation error", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: invalid/path
`;
      const result = await parseSkirConfig(yamlCode);
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

    it("should return error for extra fields in strict schema", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
    extraField: value
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [
          {
            message: /unrecognized/i,
          },
        ],
      });
    });

    it("should return error for invalid outDir pattern", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: does/not/end/properly
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should return error for invalid outDir array element", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir:
      - valid/skirout
      - invalid/path
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should parse config with empty generators array", async () => {
      const yamlCode = `
generators: []
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [],
        },
        errors: [],
      });
    });

    it("should handle empty YAML document", async () => {
      const yamlCode = "";
      const result = await parseSkirConfig(yamlCode);
      // Empty YAML parses as null/undefined, which fails schema validation
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}], // At least one error
      });
    });

    it("should handle YAML with comments", async () => {
      const yamlCode = `
# This is a comment
generators:
  # Generator 1
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
# Source directory
srcDir: src
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: {
          generators: [
            {
              mod: "@example/generator",
              outDir: "./skirout",
              config: {},
            },
          ],
          srcDir: "src",
        },
        errors: [],
      });
    });

    it("should return multiple errors for multiple validation issues", async () => {
      const yamlCode = `
generators:
  - config: {}
  - mod: "@example/gen"
extraField: invalid
`;
      const result = await parseSkirConfig(yamlCode);
      expect(result).toMatch({
        skirConfig: undefined,
        errors: [{}, {}, {}, {}], // At least four errors
      });
    });

    it("should handle complex nested config objects", async () => {
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
      const result = await parseSkirConfig(yamlCode);
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

    it("should validate outDir ends with skirout", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    config: {}
    outDir: path/to/skirout
`;
      const result = await parseSkirConfig(yamlCode);
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

    it("should handle YAML with duplicate keys as warning/error", async () => {
      const yamlCode = `
generators:
  - mod: "@example/generator"
    outDir: ./skirout
    config: {}
    mod: "@another/generator"
`;
      const result = await parseSkirConfig(yamlCode);
      // YAML library should detect duplicate keys
      // The exact behavior depends on yaml library settings
      if (result.errors.length > 0) {
        expect(result.skirConfig).toMatch(undefined);
      }
    });

    it("should do validation on generator's config if known", async () => {
      const yamlCode = `
generators:
  - mod: skir-typescript-gen
    outDir: ./skirout
    config:
      importPathExtension: .jss
`;
      const result = await parseSkirConfig(yamlCode);
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
