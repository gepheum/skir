import {
  type CodeGenerator,
  type Constant,
  convertCase,
  type Declaration,
  type Doc,
  type Field,
  type Method,
  type Module,
  type Record,
  type ResolvedType,
} from "skir-internal";
import { z } from "zod";
import { KeyedArrayContext } from "./keyed_array_context.js";
import {
  getQualifiedTypeName,
  getSwiftConstantName,
  getSwiftFieldName,
  getSwiftMethodName,
  getTypeName,
  getTypeRef,
  isValidVariantName,
  ModuleContext,
  modulePathToCaselessEnumName,
} from "./naming.js";
import { TypeSpeller } from "./type_speller.js";

const Config = z.strictObject({
  public: z
    .boolean()
    .default(false)
    .describe(
      "Whether to generate public declarations. Default to false: declarations are internal.",
    ),
});

type Config = z.infer<typeof Config>;

class SwiftCodeGenerator implements CodeGenerator<Config> {
  readonly id = "skir-swift-gen";
  readonly configType = Config;

  generateCode(input: CodeGenerator.Input<Config>): CodeGenerator.Output {
    const { recordMap, config } = input;
    const typeSpeller = new TypeSpeller(recordMap);
    const keyedArrayContext = new KeyedArrayContext(input.modules, typeSpeller);
    const outputFiles: CodeGenerator.OutputFile[] = [];
    for (const skirModule of input.modules) {
      outputFiles.push({
        path: skirModule.path.replace(/\.skir$/, ".swift"),
        code: new SwiftModuleCodeGenerator(
          skirModule,
          typeSpeller,
          keyedArrayContext,
          config,
        ).generate(),
      });
    }
    outputFiles.push({
      path: "Skir.swift",
      code: generateSkirEnumCode(input.modules, config),
    });
    return { files: outputFiles };
  }
}

/** Generates the code for one .swift file, corresponding to one .skir module. */
class SwiftModuleCodeGenerator {
  constructor(
    private readonly inModule: Module,
    private readonly typeSpeller: TypeSpeller,
    private readonly keyedArrayContext: KeyedArrayContext,
    private readonly config: Config,
  ) {
    this.currentModuleContext = { kind: "module", modulePath: inModule.path };
  }

  generate(): string {
    this.push(GENERATED_FILE_HEADER);

    const caselessEnumName = modulePathToCaselessEnumName(this.inModule.path);
    this.push(
      commentify(`Caseless enum for Skir module '${this.inModule.path}'`),
    );
    this.push(`${this.pub}enum ${caselessEnumName} {\n`);
    const records = this.inModule.declarations.filter(
      (r) => r.kind === "record",
    );
    this.writeCodeForRecords(records);
    for (const constant of this.inModule.constants) {
      this.writeConstant(constant);
    }
    for (const method of this.inModule.methods) {
      this.writeMethod(method);
    }
    this.writeCodeForModuleSerializers(records);
    this.push("}\n\n");

    return this.joinLinesAndFixFormatting();
  }

  private writeCodeForRecords(records: readonly Record[]): void {
    for (const record of records) {
      if (record.recordType === "struct") {
        this.writeCodeForStruct(record);
      } else {
        this.writeCodeForEnum(record);
      }
    }
  }

  private writeCodeForStruct(struct: Record): void {
    const { typeSpeller } = this;
    const structLocation = typeSpeller.recordMap.get(struct.key)!;
    const typeName = getTypeName(struct);
    // How to refer to this type from this type.
    const selfTypeRef = getTypeRef(structLocation, structLocation);
    const qualifiedSelfType = getQualifiedTypeName(structLocation);
    this.push(
      `${this.pub}struct ${typeName}: Swift.CustomStringConvertible, Swift.Equatable {\n`,
    );
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const fieldType = typeSpeller.getSwiftType(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      this.push(
        commentify([
          docToCommentText(field.doc),
          ...(field.isRecursive === "hard"
            ? [
                "Recursive field. Stored as IndirectOptional to avoid infinite size.",
                "None should be treated the same as the default struct value.",
                `Use \`${fieldName}\` to read this field without having to handle the Option,`,
                "but be careful not to call it from a recursive function as it may cause",
                "infinite recursion.",
              ]
            : []),
        ]),
      );
      this.push(`${this.pub}let ${fieldName}: ${fieldType}\n`);
    }
    this.push(
      "private let _unrecognized: SkirClient.UnrecognizedFields<",
      selfTypeRef,
      ">\n",
    );
    this.push("\n");

    if (this.config.public) {
      this.push(`${this.pub}init(\n`);
      for (const field of struct.fields) {
        const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
        const fieldType = typeSpeller.getSwiftType(
          field.type!,
          structLocation,
          field.isRecursive,
        );
        this.push(`${fieldName}: ${fieldType},\n`);
      }
      this.push(
        "_unrecognized: SkirClient.UnrecognizedFields<",
        selfTypeRef,
        "> = nil,\n",
      );
      this.push(") {\n");
      for (const field of struct.fields) {
        const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
        this.push(`self.${fieldName} = ${fieldName}\n`);
      }
      this.push("self._unrecognized = _unrecognized\n");
      this.push("}\n\n");
    }

    this.push(`${this.pub}static let defaultValue = `, selfTypeRef, "(\n");
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const defaultExpression = typeSpeller.getDefaultExpression(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      this.push(`${fieldName}: ${defaultExpression},\n`);
    }
    this.push("_unrecognized: nil,\n");
    this.push(");\n\n");

    // Add computed properties for recursive fields.
    for (const field of struct.fields) {
      if (field.isRecursive !== "hard") continue;
      const getterName = getSwiftFieldName(field.name.text);
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const skirType = field.type!;
      const returnType = typeSpeller.getSwiftType(skirType, structLocation);
      const defaultExpression = typeSpeller.getDefaultExpression(
        skirType,
        structLocation,
      );
      this.push(`${this.pub}var ${getterName}: ${returnType} {\n`);
      this.push(`switch self.${fieldName} {\n`);
      this.push(`case .some(let rec): rec\n`);
      this.push(`case .none: ${defaultExpression}\n`);
      this.push("}\n");
      this.push("}\n\n");
    }

    // The partial() static factory method.
    this.push(`${this.pub}static func partial(\n`);
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const fieldType = typeSpeller.getSwiftType(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      const defaultExpression = this.typeSpeller.getDefaultExpression(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      this.push(`${fieldName}: ${fieldType} = ${defaultExpression},\n`);
    }
    this.push(") -> ", selfTypeRef, " {\n");
    this.push("return ", selfTypeRef, "(\n");
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      this.push(`${fieldName}: ${fieldName},\n`);
    }
    this.push("_unrecognized: nil,\n");
    this.push(");\n");
    this.push("}\n\n");

    this.push(`${this.pub}func copy(\n`);
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const fieldType = typeSpeller.getSwiftType(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      this.push(`${fieldName}: SkirClient.KeepOrSet<${fieldType}> = .keep,\n`);
    }
    this.push(") -> ", selfTypeRef, " {\n");
    this.push("return ", selfTypeRef, "(\n");
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      this.push(`${fieldName}: {\n`);
      this.push(`switch ${fieldName} {\n`);
      this.push("case .keep:\n");
      this.push(`return self.${fieldName};\n`);
      this.push("case let .set(value):\n");
      this.push("return value;\n");
      this.push("}\n");
      this.push("}(),\n");
    }
    this.push("_unrecognized: _unrecognized,\n");
    this.push(");\n");
    this.push("}\n\n");

    this.push(
      `${this.pub}static func == (lhs: ${selfTypeRef}, rhs: ${selfTypeRef}) -> Bool {\n`,
    );
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      if (field.isRecursive === "hard") {
        const getterName = getSwiftFieldName(field.name.text);
        this.push(
          `guard (lhs.${fieldName} == nil && rhs.${fieldName} == nil) || (lhs.${getterName} == rhs.${getterName}) else { return false }\n`,
        );
      } else {
        this.push(
          `guard lhs.${fieldName} == rhs.${fieldName} else { return false }\n`,
        );
      }
    }
    this.push("return true\n");
    this.push("}\n\n");

    this.push(`${this.pub}var description: String {\n`);
    this.push("Self.serializer.toJson(self, readable: true)\n");
    this.push("}\n\n");

    this.push(
      `${this.pub}static var serializer: SkirClient.Serializer<`,
      selfTypeRef,
      "> {\n",
      "_ = ",
      modulePathToCaselessEnumName(structLocation.modulePath),
      "._initializeModuleSerializers\n",
      "return SkirClient.Serializer(adapter: _typeAdapter)\n",
      "}\n\n",
      "final class _Builder {\n",
    );
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      const fieldType = typeSpeller.getSwiftType(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      const defaultExpression = typeSpeller.getDefaultExpression(
        field.type!,
        structLocation,
        field.isRecursive,
      );
      this.push(`var ${fieldName}: ${fieldType} = ${defaultExpression}\n`);
    }
    this.push(
      "var _unrecognized: SkirClient.UnrecognizedFields<",
      selfTypeRef,
      "> = nil\n",
    );
    this.push("\n");
    this.push("func build() -> ", selfTypeRef, " {\n");
    this.push("return ", selfTypeRef, "(\n");
    for (const field of struct.fields) {
      const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
      this.push(`${fieldName}: ${fieldName},\n`);
    }
    this.push("_unrecognized: _unrecognized,\n");
    this.push(");\n");
    this.push("}\n");
    this.push("}\n\n");

    this.push(
      commentify([
        "Type adapter for this struct.",
        "For use only by code generated by the Skir code generator.",
      ]),
      "static let _typeAdapter = SkirClient.Internal.StructAdapter<",
      selfTypeRef,
      ", _Builder",
      ">(\n",
      "modulePath: ",
      JSON.stringify(structLocation.modulePath),
      ",\n",
      'qualifiedName: "',
      structLocation.recordAncestors.map((r) => r.name.text).join("."),
      '",\n',
      "doc: ",
      JSON.stringify(docToCommentText(struct.doc)),
      ",\n",
      "newInstance: { _Builder() },\n",
      "toFrozen: { mutable in mutable.build() },\n",
      "getUnrecognized: { input in input._unrecognized },\n",
      "setUnrecognized: { input, unrecognized in input._unrecognized = unrecognized }\n",
      ");\n\n",
    );

    const keySpecs =
      this.keyedArrayContext.getKeySpecsForItemStruct(structLocation);
    for (const keySpec of keySpecs) {
      this.push(
        commentify([
          `Spec for arrays of \`${typeName}\` items keyed by \`${keySpec.swiftKeyExpr}\`.`,
          `Example: SkirClient.KeyedArray<${selfTypeRef}.${keySpec.specName}>`,
        ]),
        `${this.pub}enum ${keySpec.specName}: SkirClient.KeyedArraySpec {\n`,
        `${this.pub}typealias Item = ${qualifiedSelfType}\n`,
        `${this.pub}typealias Key = ${keySpec.swiftKeyType}\n`,
        "\n",
        `${this.pub}static func getKey(from item: Item) -> Key {\n`,
        `return item.${keySpec.swiftKeyExpr}\n`,
        "}\n",
        "\n",
        `${this.pub}static func keyExtractor() -> String {\n`,
        `return ${JSON.stringify(keySpec.keyExtractor)}\n`,
        "}\n",
        "\n",
        `${this.pub}static var defaultItem: Item {\n`,
        `return ${qualifiedSelfType}.defaultValue\n`,
        "}\n",
        "}\n\n",
      );
    }

    this.writeCodeForRecords(struct.nestedRecords);
    this.push("}\n\n");
  }

  private writeCodeForEnum(record: Record): void {
    const { typeSpeller } = this;
    const recordLocation = typeSpeller.recordMap.get(record.key)!;
    const typeName = getTypeName(record);
    // How to refer to this type from this type.
    const selfTypeRef = getTypeRef(recordLocation, recordLocation);
    this.push(
      `${this.pub}enum ${typeName}: Swift.CustomStringConvertible, Swift.Equatable {\n`,
    );
    this.push(
      commentify([
        "Use this case if you need to check if a value is unknown.",
        "Use `unknownValue` if you just need an unknown value.",
      ]),
    );
    this.push(
      `case unknown(unrecognized: SkirClient.UnrecognizedVariant<${selfTypeRef}>);\n`,
    );
    const variants = record.fields;
    for (const variant of variants) {
      const variantName = this.getVariantName(variant);
      this.push(commentify(docToCommentText(variant.doc)));
      const variantType = variant.type;
      if (variantType) {
        const valueSwiftType = typeSpeller.getSwiftType(
          variantType,
          recordLocation,
          variant.isRecursive || false,
        );
        const maybeIndirect = resolveMaybeIndirect(variantType);
        this.push(`${maybeIndirect}case ${variantName}(${valueSwiftType});\n`);
      } else {
        this.push(`case ${variantName};\n`);
      }
    }
    this.push("\n");
    if (this.keyedArrayContext.isEnumUsedAsKey(record)) {
      this.push(`${this.pub}enum _Kind: Hashable {\n`);
      this.push("case unknown;\n");
      for (const variant of variants) {
        const variantName = this.getVariantName(variant);
        this.push(`case ${variantName};\n`);
      }
      this.push("}\n\n");

      this.push(`${this.pub}var kind: _Kind {\n`);
      this.push("switch self {\n");
      this.push("case .unknown:\n");
      this.push("return .unknown\n");
      for (const variant of variants) {
        const variantName = this.getVariantName(variant);
        if (variant.type) {
          this.push(`case .${variantName}(_):\n`);
        } else {
          this.push(`case .${variantName}:\n`);
        }
        this.push(`return .${variantName}\n`);
      }
      this.push("}\n");
      this.push("}\n\n");
    }
    this.push(
      `${this.pub}static let unknownValue = unknown(unrecognized: nil);\n\n`,
    );

    this.push(`${this.pub}var description: String {\n`);
    this.push("Self.serializer.toJson(self, readable: true)\n");
    this.push("}\n\n");

    this.push(
      `${this.pub}static func == (lhs: ${selfTypeRef}, rhs: ${selfTypeRef}) -> Bool {\n`,
      "switch (lhs, rhs) {\n",
      "case (.unknown, .unknown): return true\n",
    );
    for (const variant of variants) {
      const variantName = this.getVariantName(variant);
      if (variant.type) {
        this.push(
          `case (.${variantName}(let l), .${variantName}(let r)): return l == r\n`,
        );
      } else {
        this.push(`case (.${variantName}, .${variantName}): return true\n`);
      }
    }
    if (variants.length > 0) {
      this.push("default: return false\n");
    }
    this.push("}\n", "}\n\n");

    this.push(
      `${this.pub}static var serializer: SkirClient.Serializer<`,
      selfTypeRef,
      "> {\n",
      "_ = ",
      modulePathToCaselessEnumName(recordLocation.modulePath),
      "._initializeModuleSerializers\n",
      "return SkirClient.Serializer(adapter: _typeAdapter)\n",
      "}\n\n",
    );

    this.push(
      commentify([
        "Type adapter for this enum.",
        "For use only by code generated by the Skir code generator.",
      ]),
      "static let _typeAdapter = SkirClient.Internal.EnumAdapter<",
      selfTypeRef,
      ">(\n",
      "modulePath: ",
      JSON.stringify(recordLocation.modulePath),
      ",\n",
      'qualifiedName: "',
      recordLocation.recordAncestors.map((r) => r.name.text).join("."),
      '",\n',
      "doc: ",
      JSON.stringify(docToCommentText(record.doc)),
      ",\n",
      "defaultValue: unknownValue,\n",
      "getKindOrdinal: {\n",
      "input in\n",
      "switch input {\n",
      "case .unknown: return 0\n",
    );
    for (let i = 0; i < variants.length; i++) {
      const variant = variants[i]!;
      const variantName = this.getVariantName(variant);
      if (variant.type) {
        this.push(`case .${variantName}(_): `);
      } else {
        this.push(`case .${variantName}: `);
      }
      this.push(`return ${i + 1}\n`);
    }
    this.push(
      "}\n",
      "},\n",
      "wrapUnrecognized: { unrecognized in .unknown(unrecognized: .some(unrecognized)) },\n",
      "getUnrecognized: {\n",
      "input in\n",
      "switch input {\n",
      "case .unknown(let unrecognized):\n",
      "return unrecognized\n",
    );
    if (variants.length > 0) {
      this.push("default:\n", "return nil\n");
    }
    this.push("}\n", "}\n", ");\n\n");
    this.writeCodeForRecords(record.nestedRecords);
    this.push("}\n\n");
  }

  private writeCodeForModuleSerializers(records: readonly Record[]): void {
    this.push("private static let _initializeModuleSerializers: Void = {\n");
    for (const record of flattenRecords(records)) {
      this.writeCodeForRecordSerializerInitialization(record);
    }
    this.push("}();\n\n");
  }

  private writeCodeForRecordSerializerInitialization(record: Record): void {
    const recordLocation = this.typeSpeller.recordMap.get(record.key)!;
    const typeRef = getTypeRef(recordLocation, this.currentModuleContext);
    if (record.recordType === "struct") {
      for (const field of record.fields) {
        const fieldName = getSwiftFieldName(field.name.text, field.isRecursive);
        const serializerExpr = this.typeSpeller.getSerializerExpression(
          field.type!,
          this.currentModuleContext,
          "init",
          field.isRecursive,
        );
        this.push(`${typeRef}._typeAdapter.addField(\n`);
        this.push(`${JSON.stringify(field.name.text)},\n`);
        this.push(`number: ${field.number},\n`);
        this.push(`serializer: ${serializerExpr},\n`);
        this.push(`getter: { input in input.${fieldName} },\n`);
        this.push(`setter: { input, value in input.${fieldName} = value },\n`);
        this.push(`doc: ${JSON.stringify(docToCommentText(field.doc))}\n`);
        this.push(");\n");
      }
      for (const number of record.removedNumbers) {
        this.push(`${typeRef}._typeAdapter.addRemovedNumber(${number});\n`);
      }
      this.push(`${typeRef}._typeAdapter.finalize();\n\n`);
      return;
    }

    const variants = record.fields;
    for (let i = 0; i < variants.length; i++) {
      const variant = variants[i]!;
      const variantName = this.getVariantName(variant);
      const kindOrdinal = i + 1;
      if (variant.type) {
        const serializerExpr = this.typeSpeller.getSerializerExpression(
          variant.type,
          this.currentModuleContext,
          "init",
          variant.isRecursive,
        );
        const defaultExpr = this.typeSpeller.getDefaultExpression(
          variant.type,
          this.currentModuleContext!,
          variant.isRecursive,
        );
        this.push(`${typeRef}._typeAdapter.addWrapperVariant(\n`);
        this.push(`name: ${JSON.stringify(variant.name.text)},\n`);
        this.push(`number: ${variant.number},\n`);
        this.push(`kindOrdinal: ${kindOrdinal},\n`);
        this.push(`serializer: ${serializerExpr},\n`);
        this.push(`doc: ${JSON.stringify(docToCommentText(variant.doc))},\n`);
        this.push(`wrap: { value in .${variantName}(value) },\n`);
        this.push("getValue: {\n");
        this.push("input in\n");
        this.push("switch input {\n");
        this.push(`case .${variantName}(let value): return value;\n`);
        this.push(`default: return ${defaultExpr}\n`);
        this.push("}\n");
        this.push("}\n");
        this.push(");\n");
      } else {
        const nameLiteral = JSON.stringify(variant.name.text);
        this.push(`${typeRef}._typeAdapter.addConstantVariant(\n`);
        this.push(`name: ${nameLiteral},\n`);
        this.push(`number: ${variant.number},\n`);
        this.push(`kindOrdinal: ${kindOrdinal},\n`);
        this.push(`doc: ${JSON.stringify(docToCommentText(variant.doc))},\n`);
        this.push(`instance: .${variantName}\n`);
        this.push(");\n");
      }
    }
    for (const number of record.removedNumbers) {
      this.push(`${typeRef}._typeAdapter.addRemovedNumber(${number});\n`);
    }
    this.push(`${typeRef}._typeAdapter.finalize();\n\n`);
  }

  private writeMethod(method: Method): void {
    const { typeSpeller } = this;
    const methodName = getSwiftMethodName(method);
    const requestType = method.requestType!;
    const responseType = method.responseType!;
    const requestSwiftType = typeSpeller.getSwiftType(
      requestType,
      this.currentModuleContext,
    );
    const responseSwiftType = typeSpeller.getSwiftType(
      responseType,
      this.currentModuleContext,
    );
    const requestSerializerExpr = typeSpeller.getSerializerExpression(
      requestType,
      this.currentModuleContext,
    );
    const responseSerializerExpr = typeSpeller.getSerializerExpression(
      responseType,
      this.currentModuleContext,
    );
    this.push(commentify(docToCommentText(method.doc)));
    this.push(
      `${this.pub}static let ${methodName} = SkirClient.Method<${requestSwiftType}, ${responseSwiftType}>(
`,
      `name: ${JSON.stringify(method.name.text)},\n`,
      `number: ${method.number},\n`,
      `requestSerializer: ${requestSerializerExpr},\n`,
      `responseSerializer: ${responseSerializerExpr},\n`,
      `doc: ${JSON.stringify(docToCommentText(method.doc))}\n`,
      ")\n\n",
    );
  }

  private writeConstant(constant: Constant): void {
    const { typeSpeller } = this;
    const constantName = getSwiftConstantName(constant);
    const type = constant.type!;
    this.push(commentify(docToCommentText(constant.doc)));

    // Use LazyLock for lazy initialization from JSON.
    const serializerExpr = typeSpeller.getSerializerExpression(type, null);
    const jsonLiteral = toSwiftStringLiteral(
      JSON.stringify(constant.valueAsDenseJson),
    );
    this.push(
      `${this.pub}static let ${constantName} = try! `,
      `${serializerExpr}.fromJson(${jsonLiteral});\n\n`,
    );
  }

  private getVariantName(variant: Field): string {
    const lowerCamelName = convertCase(variant.name.text, "lowerCamel");
    return isValidVariantName(lowerCamelName)
      ? lowerCamelName
      : `${lowerCamelName}_`;
  }

  private pushSeparator(header: string): void {
    this.push(`// ${"=".repeat(78)}\n`);
    this.push(`// ${header}\n`);
    this.push(`// ${"=".repeat(78)}\n\n`);
  }

  private push(...code: string[]): void {
    this.code += code.join("");
  }

  private joinLinesAndFixFormatting(): string {
    return joinLinesAndFixFormatting(this.code);
  }

  private get pub(): string {
    return this.config.public ? "public " : "";
  }

  private readonly currentModuleContext: ModuleContext;
  private code = "";
}

function joinLinesAndFixFormatting(code: string): string {
  const indentUnit = "  ";
  let result = "";
  // The indent at every line is obtained by repeating indentUnit N times,
  // where N is the length of this array.
  const contextStack: Array<"{" | "(" | "[" | "<" | ":" | "."> = [];
  // Returns the last element in `contextStack`.
  const peakTop = (): string => contextStack.at(-1)!;
  const getMatchingLeftBracket = (r: "}" | ")" | "]" | ">"): string => {
    switch (r) {
      case "}":
        return "{";
      case ")":
        return "(";
      case "]":
        return "[";
      case ">":
        return "<";
    }
  };
  for (let line of code.split("\n")) {
    line = line.trim();
    if (line.length <= 0) {
      // Don't indent empty lines.
      result += "\n";
      continue;
    }

    const firstChar = line[0];
    switch (firstChar) {
      case "}":
      case ")":
      case "]":
      case ">": {
        const left = getMatchingLeftBracket(firstChar);
        while (contextStack.length > 0 && contextStack.pop() !== left) {
          // Keep popping until we find a matching opener.
        }
        break;
      }
      case ".": {
        if (peakTop() !== ".") {
          contextStack.push(".");
        }
        break;
      }
    }
    const indent =
      indentUnit.repeat(contextStack.length) +
      (line.startsWith("*") ? " " : "");
    result += `${indent}${line.trimEnd()}\n`;
    if (line.startsWith("/") || line.startsWith("*")) {
      // A comment.
      continue;
    }
    const lastChar = line.slice(-1);
    switch (lastChar) {
      case "{":
      case "(":
      case "[":
      case "<": {
        // The next line will be indented
        contextStack.push(lastChar);
        break;
      }
      case ":":
      case "=": {
        if (peakTop() !== ":") {
          contextStack.push(":");
        }
        break;
      }
      case ";":
      case ",": {
        if (peakTop() === "." || peakTop() === ":") {
          contextStack.pop();
        }
      }
    }
  }

  return (
    result
      // Swift does not require trailing semicolons in these generated lines.
      .replace(/;(?=\n)/g, "")
      // Remove spaces enclosed within curly brackets if that's all there is.
      .replace(/\{\s+\}/g, "{}")
      // Remove spaces enclosed within round brackets if that's all there is.
      .replace(/\(\s+\)/g, "()")
      // Remove spaces enclosed within square brackets if that's all there is.
      .replace(/\[\s+\]/g, "[]")
      // Remove empty line following an open curly bracket.
      .replace(/(\{\n *)\n/g, "$1")
      // Remove empty line preceding a closed curly bracket.
      .replace(/\n(\n *\})/g, "$1")
      // Coalesce consecutive empty lines.
      .replace(/\n\n\n+/g, "\n\n")
      .replace(/\n\n$/g, "\n")
  );
}

// http://patorjk.com/software/taag/#f=Doom&t=Do%20not%20edit
const GENERATED_FILE_HEADER =
  "//  ______                        _               _  _  _\n" +
  "//  |  _  \\                      | |             | |(_)| |\n" +
  "//  | | | |  ___    _ __    ___  | |_    ___   __| | _ | |_\n" +
  "//  | | | | / _ \\  | '_ \\  / _ \\ | __|  / _ \\ / _` || || __|\n" +
  "//  | |/ / | (_) | | | | || (_) || |_  |  __/| (_| || || |_ \n" +
  "//  |___/   \\___/  |_| |_| \\___/  \\__|  \\___| \\__,_||_| \\__|\n" +
  "//\n" +
  "// Generated by skir-swift-gen\n" +
  "// Home: https://github.com/gepheum/skir-swift-gen\n" +
  "//\n" +
  "// To install the Skir client library, run:\n" +
  "//   swift package add-dependency https://github.com/gepheum/skir-swift-client --branch main\n" +
  "\n" +
  "import Foundation\n" +
  "import SkirClient\n" +
  "\n";

type UnambiguousDecl = { decl: Record | Constant | Method; modulePath: string };

function getDeclSwiftName(decl: Declaration): string {
  switch (decl.kind) {
    case "record":
      return getTypeName(decl as Record);
    case "constant":
      return getSwiftConstantName(decl as Constant);
    case "method":
      return getSwiftMethodName(decl as Method);
    default:
      throw new Error(
        `Unexpected declaration kind: ${(decl as Declaration).kind}`,
      );
  }
}

function generateSkirEnumCode(
  modules: readonly Module[],
  config: Config,
): string {
  const allUnambiguous = findUnambiguousNamesAcrossModules(modules);

  // Group by module path, preserving module order.
  const byModule = new Map<string, UnambiguousDecl[]>();
  for (const module of modules) {
    byModule.set(module.path, []);
  }
  for (const entry of allUnambiguous) {
    byModule.get(entry.modulePath)!.push(entry);
  }

  const pub = config.public ? "public " : "";
  let code =
    "/// Convenience aliases for all names that are unambiguous across all modules.\n";
  code += `${pub}enum Skir {\n`;
  for (const [modulePath, entries] of byModule) {
    if (entries.length === 0) continue;
    code += `// ${"=".repeat(78)}\n`;
    code += `// ${modulePath}\n`;
    code += `// ${"=".repeat(78)}\n\n`;
    for (const { decl } of entries) {
      code += commentify(docToCommentText(decl.doc));
      const enumName = modulePathToCaselessEnumName(modulePath);
      const swiftName = getDeclSwiftName(decl);
      if (decl.kind === "record") {
        code += `${pub}typealias ${swiftName} = ${enumName}.${swiftName}\n`;
      } else {
        code += `${pub}static let ${swiftName} = ${enumName}.${swiftName}\n`;
      }
    }
    code += "\n";
  }
  code += "}\n";
  return joinLinesAndFixFormatting(GENERATED_FILE_HEADER + code);
}
function findUnambiguousNamesAcrossModules(
  modules: readonly Module[],
): readonly UnambiguousDecl[] {
  const nameToDecls = new Map<string, UnambiguousDecl[]>();
  for (const module of modules) {
    for (const decl of module.declarations) {
      if (decl.kind === "import" || decl.kind === "import-alias") continue;
      const name = decl.name.text;
      const entry: UnambiguousDecl = { decl, modulePath: module.path };
      const declsWithSameName = nameToDecls.get(name);
      if (declsWithSameName) {
        declsWithSameName.push(entry);
      } else {
        nameToDecls.set(name, [entry]);
      }
    }
  }
  const result: UnambiguousDecl[] = [];
  for (const declsWithSameName of nameToDecls.values()) {
    if (declsWithSameName.length === 1) {
      result.push(declsWithSameName[0]!);
    }
  }
  return result;
}

function flattenRecords(records: readonly Record[]): Record[] {
  const result: Record[] = [];
  for (const record of records) {
    result.push(record);
    result.push(...flattenRecords(record.nestedRecords));
  }
  return result;
}

function resolveMaybeIndirect(type: ResolvedType): "indirect " | "" {
  switch (type.kind) {
    case "array":
      return "";
    case "optional":
      return resolveMaybeIndirect(type.other);
    case "primitive":
      return "";
    case "record":
      return "indirect ";
  }
}

function toSwiftStringLiteral(input: string): string {
  const escaped = input
    .replace(/\\/g, "\\\\") // Escape backslashes
    .replace(/"/g, '\\"') // Escape double quotes
    .replace(/\n/g, "\\n") // Escape newlines
    .replace(/\r/g, "\\r") // Escape carriage returns
    .replace(/\t/g, "\\t"); // Escape tabs
  return `"${escaped}"`;
}

function commentify(textOrLines: string | readonly string[]): string {
  const text = (
    typeof textOrLines === "string" ? textOrLines : textOrLines.join("\n")
  )
    .trim()
    .replace(/\n{3,}/g, "\n\n");
  if (text.length <= 0) {
    return "";
  }
  return text
    .split("\n")
    .map((line) => (line.length > 0 ? `/// ${line}\n` : "///\n"))
    .join("");
}

function docToCommentText(doc: Doc): string {
  return doc.pieces
    .map((p) => {
      switch (p.kind) {
        case "text":
          return p.text;
        case "reference":
          return "`" + p.referenceRange.text.slice(1, -1) + "`";
      }
    })
    .join("");
}

export const GENERATOR = new SwiftCodeGenerator();
