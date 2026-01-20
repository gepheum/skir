import { z } from "zod";

export const GeneratorConfig = z.strictObject({
  mod: z.string(),
  outDir: z.union([
    z.string().endsWith("/skirout"),
    z.array(z.string().endsWith("/skirout")),
  ]),
  config: z.any(),
});

export type GeneratorConfig = z.infer<typeof GeneratorConfig>;

const PackageId = z.string().regex(/^@[A-Za-z0-9-]+\/[A-Za-z0-9\-_.]+$/);
const Version = z.string().regex(/^[A-Za-z0-9\-_./+]+$/);

export const SkirConfig = z
  .object({
    version: Version.default(""),
    generators: z.array(GeneratorConfig).default([]),
    dependencies: z.record(PackageId, Version).default({}),
  })
  .strict();

export type SkirConfig = z.infer<typeof SkirConfig>;
