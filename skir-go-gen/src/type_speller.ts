import { capitalize, convertCase } from "skir-internal";
import type {
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { GO_KEYWORDS } from "./keywords.js";

export interface GoConfig {
  readonly packagePrefix?: string;
}

/**
 * Transforms a type found in a `.skir` file into a Go type.
 */
export class GoTypeSpeller {
  readonly imports = new Set<string>();

  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly origin: Module,
    readonly config: GoConfig,
  ) {}

  getGoType(type: ResolvedType): string {
    switch (type.kind) {
      case "primitive":
        return this.getPrimitiveType(type.primitive);
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        return this.getRecordTypeName(recordLocation);
      }
      case "array":
        return `[]${this.getGoType(type.item)}`;
      case "optional":
        return this.getOptionalType(type.other);
    }
  }

  private getOptionalType(inner: ResolvedType): string {
    if (inner.kind === "primitive" && inner.primitive === "bytes") {
      return "[]byte";
    }
    if (inner.kind === "array") {
      return this.getGoType(inner);
    }
    return `*${this.getGoType(inner)}`;
  }

  private getPrimitiveType(primitive: string): string {
    switch (primitive) {
      case "bool":
        return "bool";
      case "int32":
        return "int32";
      case "int64":
        return "int64";
      case "hash64":
        return "uint64";
      case "float32":
        return "float32";
      case "float64":
        return "float64";
      case "timestamp":
        this.imports.add("time");
        return "time.Time";
      case "string":
        return "string";
      case "bytes":
        return "[]byte";
      default:
        return "interface{}";
    }
  }

  getRecordTypeName(recordLocation: RecordLocation): string {
    const { recordAncestors, modulePath } = recordLocation;
    const typeName = recordAncestors
      .map((r) => capitalize(convertCase(r.name.text, "UpperCamel")))
      .join("_");

    if (modulePath !== this.origin.path) {
      const alias = modulePathToImportAlias(modulePath);
      const importPath = modulePathToGoImportPath(
        modulePath,
        this.config.packagePrefix,
      );
      this.imports.add(`${alias} "${importPath}"`);
      return `${alias}.${typeName}`;
    }

    return typeName;
  }

  getDefaultValue(type: ResolvedType): string {
    switch (type.kind) {
      case "array":
        return "nil";
      case "optional":
        return "nil";
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "false";
          case "int32":
          case "int64":
          case "hash64":
            return "0";
          case "float32":
          case "float64":
            return "0";
          case "string":
            return `""`;
          case "bytes":
            return "nil";
          case "timestamp":
            return "time.Time{}";
          default:
            return `""`;
        }
      }
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = this.getRecordTypeName(recordLocation);
        if (recordLocation.record.recordType === "enum") {
          return `New${typeName}Unknown()`;
        }
        return `${typeName}{}`;
      }
    }
  }
}

export function modulePathToGoFilePath(path: string): string {
  return path
    .replace(/-/g, "_")
    .replace(/^@/, "external/")
    .replace(/\.skir$/, ".go");
}

export function modulePathToGoImportPath(
  path: string,
  packagePrefix?: string,
): string {
  const normalized = path
    .replace(/-/g, "_")
    .replace(/^@/, "external/")
    .replace(/\.skir$/, "");
  const dir = normalized.includes("/")
    ? normalized.substring(0, normalized.lastIndexOf("/"))
    : "";
  const prefix = packagePrefix ?? "skirout";
  return dir ? `${prefix}/${dir}` : prefix;
}

export function modulePathToImportAlias(path: string): string {
  return path
    .replace(/-/g, "_")
    .replace(/^@/, "external_")
    .replace(/\.skir$/, "")
    .replace(/\//g, "_");
}

export function getGoPackageName(modulePath: string): string {
  const normalized = modulePath
    .replace(/-/g, "_")
    .replace(/^@/, "external/")
    .replace(/\.skir$/, "");
  const parts = normalized.split("/");
  if (parts.length <= 1) {
    return "skirout";
  }
  return parts[parts.length - 2]!.replace(/-/g, "_");
}

export function toGoFieldName(name: string): string {
  const result = convertCase(name, "UpperCamel");
  if (GO_KEYWORDS.has(result.toLowerCase())) {
    return result + "_";
  }
  return result;
}

export function toGoEnumConstName(
  typeName: string,
  variantName: string,
): string {
  return `${typeName}Kind${capitalize(convertCase(variantName, "UpperCamel"))}`;
}
