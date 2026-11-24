/**
 * @fileoverview Returns a TypeScript expression transforming a value from a
 * `initializer` type into a `frozen` type.
 */
import type { ResolvedType } from "skir-internal";
import { TypeSpeller } from "./type_speller.js";

export interface ToFrozenExpressionArg {
  type: ResolvedType;
  // Input TypeScript expression, e.g. "foo.bar".
  inExpr: string;
  // True if the input expression may be "undefined".
  maybeUndefined: boolean;
  typeSpeller: TypeSpeller;
}

export function toFrozenExpression(arg: ToFrozenExpressionArg): string {
  const { type, inExpr, maybeUndefined, typeSpeller } = arg;
  if (type.kind === "record") {
    const frozenClass = typeSpeller.getClassName(type.key);
    const defaultExpr =
      type.recordType === "struct"
        ? `${frozenClass.value}.DEFAULT`
        : `${frozenClass.value}.UNKNOWN`;
    const inExprOrDefault = maybeUndefined
      ? `${inExpr} ?? ${defaultExpr}`
      : inExpr;
    return `${frozenClass.value}.create(${inExprOrDefault})`;
  } else if (type.kind === "array") {
    const transformItemExpr = toFrozenExpression({
      type: type.item,
      inExpr: "e",
      maybeUndefined: false,
      typeSpeller: typeSpeller,
    });
    const inExprOrEmpty = maybeUndefined ? `${inExpr} || []` : inExpr;
    if (transformItemExpr === "e") {
      return `$._toFrozenArray(\n${inExprOrEmpty})`;
    } else {
      let mapFnExpr: string;
      if (type.item.kind === "record") {
        // Instead of creating a lambda, we can just get the `create` static
        // function.
        const frozenClass = typeSpeller.getClassName(type.item.key);
        mapFnExpr = `${frozenClass.value}.create`;
      } else {
        mapFnExpr = `(e) => ${transformItemExpr}`;
      }
      const funName = "$._toFrozenArray";
      return `${funName}(\n${inExprOrEmpty},\n${mapFnExpr},\n)`;
    }
  } else if (type.kind === "optional") {
    const otherType = type.other;
    const otherExpr = toFrozenExpression({
      type: otherType,
      inExpr: inExpr,
      maybeUndefined: false,
      typeSpeller: typeSpeller,
    });
    if (otherExpr === inExpr) {
      return maybeUndefined ? `${inExpr} ?? null` : inExpr;
    }
    // The condition for returning otherExpr.
    let condition: string;
    if (canBeFalsy(otherType)) {
      if (maybeUndefined) {
        // This is one way to test that inExpr is not null or undefined.
        // Works because if inExpr was === 0, then we would have already
        // returned.
        condition = `((${inExpr} ?? 0) !== 0)`;
      } else {
        condition = `${inExpr} !== null`;
      }
    } else {
      // Just rely on implicit boolean conversion.
      // Also works if maybeUndefined is true.
      condition = inExpr;
    }
    return `${condition} ? ${otherExpr} : null`;
  }
  // A primitive type.
  if (!maybeUndefined) {
    return inExpr;
  }
  const { primitive } = type;
  let defaultValue: string;
  if (primitive === "bool") {
    defaultValue = "false";
  } else if (
    primitive === "int32" ||
    primitive === "float32" ||
    primitive === "float64"
  ) {
    defaultValue = "0";
  } else if (primitive === "int64" || primitive === "hash64") {
    defaultValue = "BigInt(0)";
  } else if (primitive === "timestamp") {
    defaultValue = "$.Timestamp.UNIX_EPOCH";
  } else if (primitive === "string") {
    defaultValue = '""';
  } else if (primitive === "bytes") {
    defaultValue = "$.ByteString.EMPTY";
  } else {
    const _: never = primitive;
    throw TypeError();
  }
  return `${inExpr} ?? ${defaultValue}`;
}

// Returns true if values of the given type can ever be falsy.
// See https://developer.mozilla.org/en-US/docs/Glossary/Falsy
function canBeFalsy(type: ResolvedType): boolean {
  if (type.kind === "optional") {
    return true;
  }
  if (type.kind !== "primitive") {
    return false;
  }
  const { primitive } = type;
  return (
    primitive === "bool" ||
    primitive === "int32" ||
    primitive === "int64" ||
    primitive === "hash64" ||
    primitive === "float32" ||
    primitive === "float64" ||
    primitive === "string"
  );
}
