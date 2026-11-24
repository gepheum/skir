export class PyType {
  /** Creates a non-union type. */
  static of(type: string): PyType {
    return new PyType([type]);
  }

  /** Creates a non-union type by adding quotes to the given string. */
  static quote(unquoted: string): PyType {
    return new PyType([`"${unquoted}"`]);
  }

  static union(types: readonly PyType[]): PyType {
    const typesInUnion = new Set<string>();
    for (const arg of types) {
      for (const part of arg.typesInUnion) {
        typesInUnion.add(part);
      }
    }
    return new PyType([...typesInUnion]);
  }

  static readonly NONE = this.of("None");
  static readonly BOOL = this.of("bool");
  static readonly INT = this.of("int");
  static readonly FLOAT = this.of("float");
  static readonly TIMESTAMP = this.of("skir.Timestamp");
  static readonly STR = this.of("str");
  static readonly BYTES = this.of("bytes");
  static readonly NEVER = this.union([]);

  private constructor(private readonly typesInUnion: readonly string[]) {}

  toString(): string {
    const { typesInUnion } = this;
    switch (typesInUnion.length) {
      case 0:
        // `typing.Never` was introduced in Python 3.11.
        return "typing.NoReturn";
      case 1:
        return typesInUnion[0]!;
      default: {
        // Must quote the union if one of the operands is quoted and unless one operand
        // is generic, in which case we prefer the typing.Union notation.
        const oneTypeIsGeneric = typesInUnion.some((t) => t.includes("["));

        if (oneTypeIsGeneric) {
          // Use the typing.Union notation.
          return `typing.Union[${typesInUnion.join(", ")}]`;
        }
        const oneTypeIsQuoted = typesInUnion.some((t) => t.startsWith('"'));
        const parts = oneTypeIsQuoted
          ? typesInUnion.map((t) =>
              t.startsWith('"') ? t.substring(1, t.length - 1) : t,
            )
          : typesInUnion;
        const joinResult = parts.join(" | ");
        return oneTypeIsQuoted ? `"${joinResult}"` : joinResult;
      }
    }
  }
}
