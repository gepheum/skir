import type { CodeGenerator } from "skir-internal";
import { z } from "zod";
import { type ElixirConfig, generateCode } from "./generator.js";

export const GENERATOR: CodeGenerator<ElixirConfig> = Object.freeze({
  id: "skir-elixir-gen",
  configType: z.strictObject({
    namespace: z
      .string()
      .regex(/^[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/)
      .optional(),
  }),
  generateCode,
});
