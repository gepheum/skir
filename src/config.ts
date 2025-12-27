import { z } from "zod";

export const GeneratorConfig = z.strictObject({
  mod: z.string(),
  config: z.any(),
  outDir: z
    .union([
      z.string().endsWith("/skirout"),
      z.array(z.string().endsWith("/skirout")),
    ])
    .optional(),
});

export type GeneratorConfig = z.infer<typeof GeneratorConfig>;

export const SkirConfig = z
  .object({
    generators: z.array(GeneratorConfig),
    srcDir: z.string().optional(),
  })
  .strict();

export type SkirConfig = z.infer<typeof SkirConfig>;
