/**
 * Utility class for spelling out types in TypeScript code.
 * Every instance represents a TypeScript type.
 */
export class TsType {
  /** Creates a single-lined non-union type. */
  static simple(type: string): TsType {
    const multiline = type.includes("\n");
    return new TsType([type], multiline);
  }

  /**
   * Returns the generic type:
   *   'name' + '<' + args[0] + ', ' + args[1] + ... + args[N] + '>'
   */
  static generic(name: string, ...args: readonly TsType[]): TsType {
    const multiline = args.some((u) => u.multiline);
    let type: string;
    if (multiline) {
      const mapFn = (a: TsType): string => `\n${a.toString().trimStart()},`;
      type = `${name}<${args.map(mapFn).join("")}\n>`;
    } else {
      type = `${name}<${args.join(", ")}>`;
    }
    return new TsType([type], multiline);
  }

  /** A literal value, e.g. `"foobar"` or `3`. */
  static literal(value: string | number): TsType {
    return this.simple(JSON.stringify(value));
  }

  /**
   * An inline interface as it appears for example in the following declaration:
   * ```
   *   const foo: {a: number; b: number} = {a: 10, b: 20};
   * ```
   */
  static inlineInterface(nameToType: Readonly<Record<string, TsType>>): TsType {
    const entries = Object.entries(nameToType);
    const multiline =
      entries.length >= 3 || [...entries].some((e) => e[1].multiline);
    if (multiline) {
      const mapFn = (e: [string, TsType]): string => `${e[0]}: ${e[1]};\n`;
      return new TsType([`{\n${entries.map(mapFn).join("")}}`], multiline);
    }
    const mapFn = (e: [string, TsType]): string => `${e[0]}: ${e[1]}`;
    return new TsType([`{ ${entries.map(mapFn).join("; ")} }`], multiline);
  }

  static union(types: readonly TsType[]): TsType {
    const typesInUnion = new Set<string>();
    for (const arg of types) {
      for (const part of arg.typesInUnion) {
        typesInUnion.add(part);
      }
    }
    // The result is multiline if any argument is multiline or if there are at
    // least two arguements which are not "null" or "undefined".
    const multiline =
      [...types].some((u) => u.multiline) ||
      typesInUnion.size -
        +typesInUnion.has("null") -
        +typesInUnion.has("undefined") >=
        2;
    return new TsType([...typesInUnion], multiline);
  }

  static readonly NULL = this.simple("null");
  static readonly UNDEFINED = this.simple("undefined");
  static readonly BOOLEAN = this.simple("boolean");
  static readonly NUMBER = this.simple("number");
  static readonly BIGINT = this.simple("bigint");
  static readonly TIMESTAMP = this.simple("$.Timestamp");
  static readonly STRING = this.simple("string");
  static readonly BYTE_STRING = this.simple("$.ByteString");
  static readonly NEVER = new TsType([], false);

  private constructor(
    private readonly typesInUnion: string[],
    private readonly multiline: boolean,
  ) {}

  get isNever(): boolean {
    return this.typesInUnion.length <= 0;
  }

  /**
   * Returns a representation of this type union as valid TypeScript code.
   * If multiple lines are required, the string starts with EOL and does not end
   * with EOL.
   */
  toString(): string {
    if (this.isNever) {
      return "never";
    }
    if (this.multiline) {
      if (this.typesInUnion.length === 1) {
        return `\n${this.typesInUnion[0]}`;
      }
      return [...this.typesInUnion].map((p) => `\n| ${p}`).join("");
    }
    return [...this.typesInUnion].join(" | ");
  }
}
