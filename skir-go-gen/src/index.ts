import { capitalize, convertCase, unquoteAndUnescape } from "skir-internal";
import type {
  CodeGenerator,
  Constant,
  Field,
  Method,
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
  Value,
} from "skir-internal";
import { z } from "zod";
import {
  getGoPackageName,
  GoTypeSpeller,
  modulePathToGoFilePath,
  toGoEnumConstName,
  toGoFieldName,
} from "./type_speller.js";

const Config = z.strictObject({
  packagePrefix: z.string().optional(),
});

type Config = z.infer<typeof Config>;

class GoCodeGenerator implements CodeGenerator<Config> {
  readonly id = "skir-go-gen";
  readonly configType = Config;

  generateCode(input: CodeGenerator.Input<Config>): CodeGenerator.Output {
    const { recordMap, config } = input;
    const outputFiles: CodeGenerator.OutputFile[] = [];

    for (const module of input.modules) {
      const gen = new GoModuleCodeGenerator(module, recordMap, config);
      outputFiles.push({
        path: modulePathToGoFilePath(module.path),
        code: gen.generate(),
      });
    }

    return { files: outputFiles };
  }
}

export const GENERATOR = new GoCodeGenerator();

/**
 * Generates the code for one Go source file from a single Skir module.
 */
class GoModuleCodeGenerator {
  private code = "";
  private readonly typeSpeller: GoTypeSpeller;
  private readonly packageName: string;

  constructor(
    private readonly inModule: Module,
    recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly config: Config,
  ) {
    this.typeSpeller = new GoTypeSpeller(recordMap, inModule, config);
    this.packageName = getGoPackageName(inModule.path);
  }

  generate(): string {
    const bodyCode = this.generateBody();

    let header = "";
    header += GENERATED_HEADER;
    header += `package ${this.packageName}\n`;
    header += "\n";
    header += this.buildImports();
    header += bodyCode;
    return header;
  }

  private generateBody(): string {
    const topLevelRecords = this.inModule.records.filter(
      (r) => r.recordAncestors.length === 1,
    );

    for (const record of topLevelRecords) {
      this.writeRecord(record);
    }

    for (const method of this.inModule.methods) {
      this.writeMethod(method);
    }

    for (const constant of this.inModule.constants) {
      this.writeConstant(constant);
    }

    return this.code;
  }

  // ---------------------------------------------------------------------------
  // Records
  // ---------------------------------------------------------------------------

  private writeRecord(recordLocation: RecordLocation): void {
    const { record } = recordLocation;
    if (record.recordType === "struct") {
      this.writeStruct(recordLocation);
    } else {
      this.writeEnum(recordLocation);
    }

    for (const nested of record.nestedRecords) {
      const nestedLocation = this.typeSpeller.recordMap.get(nested.key)!;
      this.writeRecord(nestedLocation);
    }
  }

  // ---------------------------------------------------------------------------
  // Structs
  // ---------------------------------------------------------------------------

  private writeStruct(recordLocation: RecordLocation): void {
    const { typeSpeller } = this;
    const { record } = recordLocation;
    const typeName = typeSpeller.getRecordTypeName(recordLocation);
    const { fields } = record;

    this.writeDoc(record.doc, typeName);
    this.pushLine(`type ${typeName} struct {`);
    for (const field of fields) {
      const goFieldName = toGoFieldName(field.name.text);
      const goType = typeSpeller.getGoType(field.type!);
      const jsonTag = field.name.text;
      this.writeDoc(field.doc, goFieldName, "\t");
      this.pushLine(`\t${goFieldName} ${goType} \`json:"${jsonTag}"\``);
    }
    this.pushLine("}");
    this.pushLine("");

    this.writeStructDefaultFunc(typeName);
    this.writeStructEqualFunc(typeName, fields);
  }

  private writeStructDefaultFunc(typeName: string): void {
    this.pushLine(
      `// New${typeName} creates a new ${typeName} with default values.`,
    );
    this.pushLine(`func New${typeName}() ${typeName} {`);
    this.pushLine(`\treturn ${typeName}{}`);
    this.pushLine("}");
    this.pushLine("");
  }

  private writeStructEqualFunc(
    typeName: string,
    fields: ReadonlyArray<Field>,
  ): void {
    this.pushLine(
      `// Equal returns true if the two ${typeName} values are equal.`,
    );
    this.pushLine(`func (a ${typeName}) Equal(b ${typeName}) bool {`);
    if (fields.length === 0) {
      this.pushLine("\treturn true");
    } else {
      const conditions: string[] = [];
      for (const field of fields) {
        const goFieldName = toGoFieldName(field.name.text);
        conditions.push(
          this.equalExpr(`a.${goFieldName}`, `b.${goFieldName}`, field.type!),
        );
      }
      this.pushLine(`\treturn ${conditions.join(" &&\n\t\t")}`);
    }
    this.pushLine("}");
    this.pushLine("");
  }

  private equalExpr(a: string, b: string, type: ResolvedType): string {
    switch (type.kind) {
      case "primitive":
        if (type.primitive === "bytes") {
          this.typeSpeller.imports.add("bytes");
          return `bytes.Equal(${a}, ${b})`;
        }
        if (type.primitive === "timestamp") {
          return `${a}.Equal(${b})`;
        }
        return `${a} == ${b}`;
      case "record":
        return `${a}.Equal(${b})`;
      case "optional":
        return `reflect.DeepEqual(${a}, ${b})`;
      case "array":
        this.typeSpeller.imports.add("reflect");
        return `reflect.DeepEqual(${a}, ${b})`;
    }
  }

  // ---------------------------------------------------------------------------
  // Enums
  // ---------------------------------------------------------------------------

  private writeEnum(recordLocation: RecordLocation): void {
    const { typeSpeller } = this;
    const { record } = recordLocation;
    const typeName = typeSpeller.getRecordTypeName(recordLocation);
    const variants = record.fields;
    const constantVariants = variants.filter((v) => !v.type);
    const wrapperVariants = variants.filter((v) => v.type);

    this.writeDoc(record.doc, typeName);

    this.writeEnumKindType(typeName, variants);
    this.writeEnumStruct(typeName, wrapperVariants);
    this.writeEnumConstructors(typeName, constantVariants, wrapperVariants);
    this.writeEnumAccessors(typeName, wrapperVariants);
    this.writeEnumEqualFunc(typeName, wrapperVariants);
    this.writeEnumMarshalJSON(typeName, constantVariants, wrapperVariants);
    this.writeEnumUnmarshalJSON(typeName, constantVariants, wrapperVariants);
  }

  private writeEnumKindType(
    typeName: string,
    variants: ReadonlyArray<Field>,
  ): void {
    const kindType = `${typeName}Kind`;
    this.pushLine(
      `// ${kindType} represents the variant kind of a ${typeName}.`,
    );
    this.pushLine(`type ${kindType} string`);
    this.pushLine("");
    this.pushLine("const (");
    this.pushLine(
      `\t${toGoEnumConstName(typeName, "unknown")} ${kindType} = "UNKNOWN"`,
    );
    for (const variant of variants) {
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.pushLine(`\t${constName} ${kindType} = "${variant.name.text}"`);
    }
    this.pushLine(")");
    this.pushLine("");
  }

  private writeEnumStruct(
    typeName: string,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    const { typeSpeller } = this;
    this.pushLine(`type ${typeName} struct {`);
    this.pushLine(`\tkind ${typeName}Kind`);
    for (const variant of wrapperVariants) {
      const fieldName = variant.name.text + "Value";
      const goType = typeSpeller.getGoType(variant.type!);
      this.pushLine(`\t${fieldName} *${goType}`);
    }
    this.pushLine("}");
    this.pushLine("");

    this.pushLine(`// Kind returns the variant kind of this ${typeName}.`);
    this.pushLine(`func (e ${typeName}) Kind() ${typeName}Kind {`);
    this.pushLine("\treturn e.kind");
    this.pushLine("}");
    this.pushLine("");
  }

  private writeEnumConstructors(
    typeName: string,
    constantVariants: ReadonlyArray<Field>,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    const { typeSpeller } = this;

    this.pushLine(
      `// New${typeName}Unknown creates an unknown ${typeName} (default value).`,
    );
    this.pushLine(`func New${typeName}Unknown() ${typeName} {`);
    this.pushLine(
      `\treturn ${typeName}{kind: ${toGoEnumConstName(typeName, "unknown")}}`,
    );
    this.pushLine("}");
    this.pushLine("");

    for (const variant of constantVariants) {
      const variantUpper = capitalize(
        convertCase(variant.name.text, "UpperCamel"),
      );
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.writeDoc(variant.doc, `New${typeName}${variantUpper}`);
      this.pushLine(`func New${typeName}${variantUpper}() ${typeName} {`);
      this.pushLine(`\treturn ${typeName}{kind: ${constName}}`);
      this.pushLine("}");
      this.pushLine("");
    }

    for (const variant of wrapperVariants) {
      const variantUpper = capitalize(
        convertCase(variant.name.text, "UpperCamel"),
      );
      const goType = typeSpeller.getGoType(variant.type!);
      this.writeDoc(variant.doc, `New${typeName}${variantUpper}`);
      this.pushLine(
        `func New${typeName}${variantUpper}(value ${goType}) ${typeName} {`,
      );
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.pushLine(
        `\treturn ${typeName}{kind: ${constName}, ${variant.name.text}Value: &value}`,
      );
      this.pushLine("}");
      this.pushLine("");
    }
  }

  private writeEnumAccessors(
    typeName: string,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    const { typeSpeller } = this;

    for (const variant of wrapperVariants) {
      const variantUpper = capitalize(
        convertCase(variant.name.text, "UpperCamel"),
      );
      const goType = typeSpeller.getGoType(variant.type!);
      const constName = toGoEnumConstName(typeName, variant.name.text);
      const defaultValue = typeSpeller.getDefaultValue(variant.type!);

      this.pushLine(
        `// As${variantUpper} returns the ${variant.name.text} value if this ${typeName} holds a ${variant.name.text} variant.`,
      );
      this.pushLine(
        `func (e ${typeName}) As${variantUpper}() (${goType}, bool) {`,
      );
      this.pushLine(
        `\tif e.kind == ${constName} && e.${variant.name.text}Value != nil {`,
      );
      this.pushLine(`\t\treturn *e.${variant.name.text}Value, true`);
      this.pushLine("\t}");
      this.pushLine(`\treturn ${defaultValue}, false`);
      this.pushLine("}");
      this.pushLine("");
    }
  }

  private writeEnumEqualFunc(
    typeName: string,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    this.pushLine(
      `// Equal returns true if the two ${typeName} values are equal.`,
    );
    this.pushLine(`func (a ${typeName}) Equal(b ${typeName}) bool {`);
    this.pushLine("\tif a.kind != b.kind {");
    this.pushLine("\t\treturn false");
    this.pushLine("\t}");

    if (wrapperVariants.length > 0) {
      this.pushLine("\tswitch a.kind {");
      for (const variant of wrapperVariants) {
        const constName = toGoEnumConstName(typeName, variant.name.text);
        const fieldName = variant.name.text + "Value";
        this.pushLine(`\tcase ${constName}:`);
        this.pushLine(
          `\t\tif a.${fieldName} == nil || b.${fieldName} == nil {`,
        );
        this.pushLine(`\t\t\treturn a.${fieldName} == b.${fieldName}`);
        this.pushLine("\t\t}");

        const fType = variant.type!;
        if (fType.kind === "record") {
          this.pushLine(
            `\t\treturn a.${fieldName}.Equal(*b.${fieldName})`,
          );
        } else if (
          fType.kind === "primitive" &&
          fType.primitive === "bytes"
        ) {
          this.typeSpeller.imports.add("bytes");
          this.pushLine(
            `\t\treturn bytes.Equal(*a.${fieldName}, *b.${fieldName})`,
          );
        } else {
          this.pushLine(
            `\t\treturn *a.${fieldName} == *b.${fieldName}`,
          );
        }
      }
      this.pushLine("\t}");
    }

    this.pushLine("\treturn true");
    this.pushLine("}");
    this.pushLine("");
  }

  private writeEnumMarshalJSON(
    typeName: string,
    constantVariants: ReadonlyArray<Field>,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    this.typeSpeller.imports.add("encoding/json");

    this.pushLine(
      `// MarshalJSON implements the json.Marshaler interface for ${typeName}.`,
    );
    this.pushLine(`func (e ${typeName}) MarshalJSON() ([]byte, error) {`);
    this.pushLine("\tswitch e.kind {");

    for (const variant of constantVariants) {
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.pushLine(`\tcase ${constName}:`);
      this.pushLine(`\t\treturn json.Marshal("${variant.name.text}")`);
    }

    for (const variant of wrapperVariants) {
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.pushLine(`\tcase ${constName}:`);
      this.pushLine("\t\twrapper := struct {");
      this.pushLine(`\t\t\tKind  string      \`json:"kind"\``);
      this.pushLine(`\t\t\tValue interface{} \`json:"value"\``);
      this.pushLine(
        `\t\t}{Kind: "${variant.name.text}", Value: e.${variant.name.text}Value}`,
      );
      this.pushLine("\t\treturn json.Marshal(wrapper)");
    }

    this.pushLine("\tdefault:");
    this.pushLine(`\t\treturn json.Marshal("UNKNOWN")`);
    this.pushLine("\t}");
    this.pushLine("}");
    this.pushLine("");
  }

  private writeEnumUnmarshalJSON(
    typeName: string,
    constantVariants: ReadonlyArray<Field>,
    wrapperVariants: ReadonlyArray<Field>,
  ): void {
    const { typeSpeller } = this;
    this.typeSpeller.imports.add("encoding/json");

    this.pushLine(
      `// UnmarshalJSON implements the json.Unmarshaler interface for ${typeName}.`,
    );
    this.pushLine(
      `func (e *${typeName}) UnmarshalJSON(data []byte) error {`,
    );

    this.pushLine("\tvar str string");
    this.pushLine("\tif err := json.Unmarshal(data, &str); err == nil {");
    this.pushLine("\t\tswitch str {");
    for (const variant of constantVariants) {
      const constName = toGoEnumConstName(typeName, variant.name.text);
      this.pushLine(`\t\tcase "${variant.name.text}":`);
      this.pushLine(`\t\t\te.kind = ${constName}`);
    }
    this.pushLine("\t\tdefault:");
    this.pushLine(
      `\t\t\te.kind = ${toGoEnumConstName(typeName, "unknown")}`,
    );
    this.pushLine("\t\t}");
    this.pushLine("\t\treturn nil");
    this.pushLine("\t}");

    if (wrapperVariants.length > 0) {
      this.pushLine("\tvar wrapper struct {");
      this.pushLine(`\t\tKind  string          \`json:"kind"\``);
      this.pushLine(`\t\tValue json.RawMessage \`json:"value"\``);
      this.pushLine("\t}");
      this.pushLine(
        "\tif err := json.Unmarshal(data, &wrapper); err == nil {",
      );
      this.pushLine("\t\tswitch wrapper.Kind {");
      for (const variant of wrapperVariants) {
        const constName = toGoEnumConstName(typeName, variant.name.text);
        const goType = typeSpeller.getGoType(variant.type!);
        this.pushLine(`\t\tcase "${variant.name.text}":`);
        this.pushLine(`\t\t\tvar v ${goType}`);
        this.pushLine(
          "\t\t\tif err := json.Unmarshal(wrapper.Value, &v); err != nil {",
        );
        this.pushLine("\t\t\t\treturn err");
        this.pushLine("\t\t\t}");
        this.pushLine(`\t\t\te.kind = ${constName}`);
        this.pushLine(`\t\t\te.${variant.name.text}Value = &v`);
      }
      this.pushLine("\t\tdefault:");
      this.pushLine(
        `\t\t\te.kind = ${toGoEnumConstName(typeName, "unknown")}`,
      );
      this.pushLine("\t\t}");
      this.pushLine("\t\treturn nil");
      this.pushLine("\t}");
    }

    this.pushLine(
      `\te.kind = ${toGoEnumConstName(typeName, "unknown")}`,
    );
    this.pushLine("\treturn nil");
    this.pushLine("}");
    this.pushLine("");
  }

  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  private writeMethod(method: Method): void {
    const { typeSpeller } = this;
    const methodName = capitalize(convertCase(method.name.text, "UpperCamel"));
    const requestType = typeSpeller.getGoType(method.requestType!);
    const responseType = typeSpeller.getGoType(method.responseType!);

    this.writeDoc(method.doc, methodName);
    this.pushLine(`type ${methodName}Method struct{}`);
    this.pushLine("");
    this.pushLine(
      `func (${methodName}Method) Name() string { return "${method.name.text}" }`,
    );
    this.pushLine(
      `func (${methodName}Method) Number() uint32 { return ${method.number} }`,
    );
    this.pushLine("");
    this.pushLine(`type ${methodName}Request = ${requestType}`);
    this.pushLine(`type ${methodName}Response = ${responseType}`);
    this.pushLine("");
  }

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  private writeConstant(constant: Constant): void {
    const { typeSpeller } = this;
    const name = convertCase(constant.name.text, "UpperCamel");
    const goType = typeSpeller.getGoType(constant.type!);
    const goLiteral = this.valueToGoLiteral(constant.value, constant.type!);

    this.writeDoc(constant.doc, name);
    this.pushLine(`var ${name} = ${goLiteral}`);
    this.pushLine("");
  }

  private valueToGoLiteral(value: Value, type: ResolvedType): string {
    const { typeSpeller } = this;

    switch (value.kind) {
      case "literal": {
        const text = value.token.text;
        if (type.kind === "primitive") {
          switch (type.primitive) {
            case "bool":
              return text;
            case "string":
              return unquoteAndUnescape(text);
            case "int32":
            case "int64":
            case "hash64":
            case "float32":
            case "float64":
              return text;
            case "bytes":
              return `[]byte(${unquoteAndUnescape(text)})`;
            default:
              return text;
          }
        }
        if (type.kind === "record" && type.recordType === "enum") {
          const recordLocation = typeSpeller.recordMap.get(type.key)!;
          const typeName = typeSpeller.getRecordTypeName(recordLocation);
          const variantUpper = capitalize(convertCase(text, "UpperCamel"));
          return `New${typeName}${variantUpper}()`;
        }
        return text;
      }
      case "object": {
        if (type.kind !== "record") {
          return "nil";
        }
        const recordLocation = typeSpeller.recordMap.get(type.key)!;
        const typeName = typeSpeller.getRecordTypeName(recordLocation);
        const { record } = recordLocation;

        if (record.recordType === "struct") {
          const fieldAssignments: string[] = [];
          for (const field of record.fields) {
            const entry = value.entries[field.name.text];
            if (entry) {
              const goFieldName = toGoFieldName(field.name.text);
              const fieldLiteral = this.valueToGoLiteral(
                entry.value,
                field.type!,
              );
              fieldAssignments.push(`${goFieldName}: ${fieldLiteral}`);
            }
          }
          if (fieldAssignments.length === 0) {
            return `${typeName}{}`;
          }
          return `${typeName}{${fieldAssignments.join(", ")}}`;
        }

        if (record.recordType === "enum") {
          const entries = Object.entries(value.entries);
          if (entries.length === 0) {
            return `New${typeName}Unknown()`;
          }
          const [variantName, entry] = entries[0]!;
          const variantUpper = capitalize(
            convertCase(variantName, "UpperCamel"),
          );
          const variant = record.fields.find(
            (f) => f.name.text === variantName,
          );
          if (variant?.type) {
            const innerLiteral = this.valueToGoLiteral(
              entry.value,
              variant.type,
            );
            return `New${typeName}${variantUpper}(${innerLiteral})`;
          }
          return `New${typeName}${variantUpper}()`;
        }

        return "nil";
      }
      case "array": {
        if (type.kind === "array") {
          const itemType = typeSpeller.getGoType(type.item);
          if (value.items.length === 0) {
            return `[]${itemType}{}`;
          }
          const items = value.items.map((item) =>
            this.valueToGoLiteral(item, type.item),
          );
          return `[]${itemType}{${items.join(", ")}}`;
        }
        return "nil";
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private writeDoc(
    doc: { readonly text: string; readonly pieces: readonly unknown[] },
    name: string,
    indent = "",
  ): void {
    if (!doc.text) return;
    const lines = doc.text.split("\n");
    for (const line of lines) {
      this.pushLine(`${indent}// ${line}`);
    }
  }

  private buildImports(): string {
    const imports = this.typeSpeller.imports;
    if (imports.size === 0) {
      return "";
    }

    const stdLibImports: string[] = [];
    const externalImports: string[] = [];

    for (const imp of [...imports].sort()) {
      if (imp.includes('"')) {
        externalImports.push(imp);
      } else {
        stdLibImports.push(`"${imp}"`);
      }
    }

    let result = "import (\n";
    for (const imp of stdLibImports) {
      result += `\t${imp}\n`;
    }
    if (stdLibImports.length > 0 && externalImports.length > 0) {
      result += "\n";
    }
    for (const imp of externalImports) {
      result += `\t${imp}\n`;
    }
    result += ")\n\n";
    return result;
  }

  private pushLine(line = ""): void {
    this.code += line + "\n";
  }
}

const GENERATED_HEADER = `// Code generated by skir-go-gen. DO NOT EDIT.
// Home: https://github.com/gepheum/skir

`;
