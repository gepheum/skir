import { Doc, Field, ResolvedType, convertCase } from "skir-internal";
import { TypeSpeller } from "./type_speller.js";

interface MutableEnumVariant {
  /** As specified in the .skir file. */
  readonly variantName: string;
  /** Examples: "bool", "Foo". Empty if the variant is a constant. */
  readonly valueType: string;
  /** Examples: "bool", "foo::Foo". Empty if the variant is a constant. */
  readonly valueTypeWithNamespace: string;
  /** As specified in the .skir file. */
  variantNumber: number;
  /** Whether the variant is the special UNKNOWN variant. */
  isUnknownVariant: boolean;
  /** Examples: "k_variant", "wrap_variant". */
  readonly structType: string;
  /** Example: "wrap_variant_type". Empty if the variant is a constant. */
  readonly typeAlias: string;
  /** kVariant or wrap_variant. */
  readonly identifier: string;
  /** kConstVariant or kValVariant */
  readonly kindEnumerator: string;
  /**
   * True if the variant is a wrapper and the value should be allocated on the heap.
   */
  readonly usePointer: boolean;
  readonly doc: Doc;
}

export type EnumVariant = Readonly<MutableEnumVariant>;

export function getEnumVariants(
  variants: readonly Field[],
  typeSpeller: TypeSpeller,
): readonly EnumVariant[] {
  const result: MutableEnumVariant[] = [];
  result.push(makeUnknownVariant());
  for (const inVariant of variants) {
    let outVariant: MutableEnumVariant;
    if (inVariant.type) {
      outVariant = makeWrapperVariant(inVariant, inVariant.doc, typeSpeller);
    } else {
      outVariant = makeConstantVariant(inVariant.name.text, inVariant.doc);
    }
    outVariant.variantNumber = inVariant.number;
    result.push(outVariant);
  }
  return result;
}

function makeUnknownVariant(): MutableEnumVariant {
  return {
    variantName: "unknown",
    valueType: "",
    valueTypeWithNamespace: "",
    variantNumber: 0,
    isUnknownVariant: true,
    structType: `k_unknown`,
    typeAlias: "",
    identifier: `kUnknown`,
    kindEnumerator: `kUnknown`,
    usePointer: false,
    doc: { text: "", pieces: [] },
  };
}

function makeConstantVariant(
  variantName: string,
  doc: Doc,
): MutableEnumVariant {
  const lowerUnderscore = convertCase(variantName, "lower_underscore");
  const upperCamel = convertCase(variantName, "UpperCamel");
  return {
    variantName: variantName,
    valueType: "",
    valueTypeWithNamespace: "",
    variantNumber: 0,
    isUnknownVariant: false,
    structType: `k_${lowerUnderscore}`,
    typeAlias: "",
    identifier: `k${upperCamel}`,
    kindEnumerator: `k${upperCamel}Const`,
    usePointer: false,
    doc: doc,
  };
}

function makeWrapperVariant(
  variant: Field,
  doc: Doc,
  typeSpeller: TypeSpeller,
): MutableEnumVariant {
  const variantName = variant.name.text;
  const upperCamel = convertCase(variantName, "UpperCamel");
  const type = variant.type!;
  return {
    variantName: variantName,
    valueType: typeSpeller.getCcType(type),
    valueTypeWithNamespace: typeSpeller.getCcType(type, {
      forceNamespace: true,
    }),
    variantNumber: 0,
    isUnknownVariant: false,
    structType: `wrap_${variantName}`,
    typeAlias: `wrap_${variantName}_type`,
    identifier: `wrap_${variantName}`,
    kindEnumerator: `k${upperCamel}Wrapper`,
    usePointer: usePointer(variant.type!),
    doc: doc,
  };
}

function usePointer(type: ResolvedType): boolean {
  if (type.kind !== "primitive") return true;
  switch (type.primitive) {
    case "bool":
    case "int32":
    case "int64":
    case "hash64":
    case "float32":
    case "float64":
    case "timestamp":
      return false;
  }
  return true;
}
