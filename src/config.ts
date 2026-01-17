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

export const SkirConfig = z
  .object({
    generators: z.array(GeneratorConfig),
    dependencies: z
      .record(
        z.string().regex(/^@[A-Za-z0-9-]+\/[A-Za-z0-9\-_.]+$/),
        z.string().regex(/^[A-Za-z0-9\-_./+]+$/),
      )
      .optional(),
  })
  .strict();

export type SkirConfig = z.infer<typeof SkirConfig>;
