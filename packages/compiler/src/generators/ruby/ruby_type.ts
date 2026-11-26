export class RubyType {
  static of(type: string): RubyType {
    return new RubyType([type], false);
  }

  static nilable(other: RubyType): RubyType {
    return new RubyType([...other.typesInUnion], true);
  }

  static union(types: readonly RubyType[]): RubyType {
    const typesInUnion = new Set<string>();
    let isNilable = false;
    for (const arg of types) {
      if (arg.isNilable) {
        isNilable = true;
      }
      for (const part of arg.typesInUnion) {
        if (part === "NilClass") {
          isNilable = true;
        } else {
          typesInUnion.add(part);
        }
      }
    }
    return new RubyType([...typesInUnion], isNilable);
  }

  static readonly NIL = new RubyType([], true);
  static readonly BOOL = this.of("T::Boolean");
  static readonly INT = this.of("Integer");
  static readonly FLOAT = this.of("Float");
  static readonly NUMERIC = this.of("Numeric");
  static readonly TIMESTAMP = this.of("Time");
  static readonly STR = this.of("String");
  static readonly BYTES = this.of("String");
  static readonly KEEP = this.of("Skir::Keep");
  static readonly NORETURN = new RubyType([], false);

  private constructor(
    private readonly typesInUnion: readonly string[],
    private readonly isNilable: boolean,
  ) {}

  toString(): string {
    const { typesInUnion, isNilable } = this;
    if (typesInUnion.length === 0) {
      return isNilable ? "NilClass" : "T.noreturn";
    }
    let core: string;
    if (typesInUnion.length === 1) {
      core = typesInUnion[0]!;
    } else {
      core = `T.any(${typesInUnion.join(", ")})`;
    }
    return isNilable ? `T.nilable(${core})` : core;
  }
}
