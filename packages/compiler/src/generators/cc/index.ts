import {
  type CodeGenerator,
  type Constant,
  type Doc,
  type Field,
  type Method,
  type Module,
  type RecordKey,
  type RecordLocation,
  convertCase,
  encodeInt32,
  simpleHash,
} from "skir-internal";
import { z } from "zod";
import { EnumVariant, getEnumVariants } from "./enum_variant.js";
import { CC_KEYWORDS } from "./keywords.js";
import { reorderRecords } from "./recursivity_resolver.js";
import {
  TypeSpeller,
  getClassName,
  modulePathToNamespace,
} from "./type_speller.js";

const Config = z.strictObject({
  writeGoogleTestHeaders: z.optional(z.boolean()),
});

type Config = z.infer<typeof Config>;

class CcCodeGenerator implements CodeGenerator<Config> {
  readonly id = "skir-cc-gen";
  readonly configType = Config;

  generateCode(input: CodeGenerator.Input<Config>): CodeGenerator.Output {
    const { recordMap, config } = input;
    const outputFiles: CodeGenerator.OutputFile[] = [];

    for (const module of input.modules) {
      const generator = new CcLibFilesGenerator(module, recordMap);
      outputFiles.push({
        path: module.path.replace(/\.skir$/, ".h"),
        code: generator.getCode(".h"),
      });
      outputFiles.push({
        path: module.path.replace(/\.skir$/, ".cc"),
        code: generator.getCode(".cc"),
      });
      if (config.writeGoogleTestHeaders) {
        outputFiles.push({
          path: module.path.replace(/\.skir$/, ".testing.h"),
          code: generator.getCode(".testing.h"),
        });
      }
    }

    return { files: outputFiles };
  }
}

/**
 * Generates the code for one C++ library, made of one .h file and one .cc
 * file.
 */
class CcLibFilesGenerator {
  constructor(
    private readonly inModule: Module,
    private readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
  ) {
    this.typeSpeller = new TypeSpeller(recordMap, inModule, this.includes);
    this.reorderedRecords = reorderRecords(inModule, recordMap);
    this.includes.add('"skir.h"');
    this.namespace = modulePathToNamespace(inModule.path);
    this.generate();
  }

  getCode(extension: ".h" | ".cc" | ".testing.h"): string {
    switch (extension) {
      case ".h":
        return fileContentsToCode(this.header);
      case ".cc":
        return fileContentsToCode(this.source);
      case ".testing.h":
        return fileContentsToCode(this.testingHeader);
    }
  }

  private generate(): void {
    this.header.namespace = this.namespace;
    this.source.namespace = this.namespace;
    this.testingHeader.namespace = this.namespace;
    for (const record of this.reorderedRecords) {
      this.writeCodeForRecord(record);
    }
    for (const method of this.inModule.methods) {
      this.writeCodeForMethod(method);
    }
    for (const constant of this.inModule.constants) {
      this.writeCodeForConstant(constant);
    }
    this.writeIncludes();
  }

  private writeCodeForRecord(record: RecordLocation): void {
    const { recordType } = record.record;
    if (recordType === "struct") {
      this.writeCodeForStruct(record);
    } else {
      this.writeCodeForEnum(record);
    }
    this.writeCodeInHeaderForAdapter(record);
  }

  private writeCodeForStruct(struct: RecordLocation): void {
    const { header, recordMap, source, testingHeader, typeSpeller } = this;

    const { fields, numSlots, numSlotsInclRemovedNumbers, nestedRecords } =
      struct.record;
    const fieldsByName = [...struct.record.fields].sort((a, b) =>
      a.name.text.localeCompare(b.name.text, "en-US"),
    );
    const fieldsByNumber = [...struct.record.fields].sort(
      (a, b) => a.number - b.number,
    );

    const className = getClassName(struct);
    const adapterName = `${className}Adapter`;
    const qualifiedName = `::${this.namespace}::${className}`;
    const constRefType = `const ${qualifiedName}&`;

    // ------------------------------
    // - APPEND CODE IN THE .h FILE -
    // ------------------------------

    header.mainTop.push(`struct ${className};`);

    for (const field of fields) {
      const fieldName = field.name.text;
      const escapedFieldName = maybeEscapeLowerCaseName(fieldName);
      const structName = `get_${fieldName}`;
      if (!this.addskiroutSymbol(structName)) continue;
      header.skirout.push(`#ifndef skirout_${structName}`);
      header.skirout.push(`#define skirout_${structName}`);
      header.skirout.push("template <typename other = ::skir::identity>");
      header.skirout.push(`struct ${structName} {`);
      header.skirout.push("  using other_type = other;");
      header.skirout.push("");
      header.skirout.push(
        `  static constexpr absl::string_view kFieldName = "${fieldName}";`,
      );
      header.skirout.push("");
      header.skirout.push("  template <typename T>");
      header.skirout.push(`  auto& operator()(T& input) const {`);
      header.skirout.push(
        `    return skir_internal::get(other()(input).${escapedFieldName});`,
      );
      header.skirout.push("  }");
      header.skirout.push("};");
      header.skirout.push("#endif");
      header.skirout.push("");
    }

    header.mainMiddle.push(...commentify(docToCommentText(struct.record.doc)));
    header.mainMiddle.push(`struct ${className} {`);
    // Declare fields in alphabetical order. It helps users who want to
    // initialize a struct using the designated initializer syntax. See:
    // https://abseil.io/tips/172
    for (const field of fieldsByName) {
      const type = field.type!;
      const fieldIsRecursive =
        field.isRecursive === "hard" || field.isRecursive === "via-optional";
      const ccType = typeSpeller.getCcType(type, {
        fieldIsRecursive: fieldIsRecursive,
      });
      const fieldName = maybeEscapeLowerCaseName(field.name.text);
      // Numeric types must be initialized.
      let assignment = "";
      if (type.kind === "primitive") {
        if (type.primitive === "bool") {
          assignment = " = false";
        } else if (type.primitive.includes("int")) {
          assignment = " = 0";
        } else if (type.primitive.includes("float")) {
          assignment = " = 0.0";
        }
      }
      header.mainMiddle.push(...commentify(docToCommentText(field.doc), "  "));
      header.mainMiddle.push(`  ${ccType} ${fieldName}${assignment};`);
    }
    header.mainMiddle.push("");
    header.mainMiddle.push("  ::skir_internal::UnrecognizedFields<");
    header.mainMiddle.push(
      `      ::skir_internal::${this.namespace}::${adapterName}>`,
    );
    header.mainMiddle.push("      _unrecognized;");
    header.mainMiddle.push("");
    header.mainMiddle.push(
      `  bool operator==(const ${className}& other) const;`,
    );
    header.mainMiddle.push("");
    header.mainMiddle.push(
      `  inline bool operator!=(const ${className}& other) const {`,
    );
    header.mainMiddle.push("    return !(*this == other);");
    header.mainMiddle.push("  }");
    header.mainMiddle.push("");
    {
      const commentLines = [
        "Use this when you want to make sure you are specifying all the fields of",
        "the struct. The compiler will error if one field is missing.",
      ];
      if (fields.length !== 0) {
        commentLines.push(
          ...[
            "",
            "Example:",
            "",
            `  ${className} value = ${className}::whole{`,
          ],
        );
        for (const field of fieldsByName) {
          const fieldName = maybeEscapeLowerCaseName(field.name.text);
          commentLines.push(`    .${fieldName} = ...,`);
        }
        commentLines.push("  };");
      }
      header.mainMiddle.push(...commentify(commentLines, "  "));
    }
    header.mainMiddle.push("  struct whole {");
    for (const field of fieldsByName) {
      const type = field.type!;
      const fieldIsRecursive =
        field.isRecursive === "hard" || field.isRecursive === "via-optional";
      const ccType = typeSpeller.getCcType(type, {
        fieldIsRecursive: fieldIsRecursive,
      });
      const fieldName = maybeEscapeLowerCaseName(field.name.text);
      header.mainMiddle.push(
        ...commentify(docToCommentText(field.doc), "    "),
      );
      header.mainMiddle.push(`    ::skir::must_init<${ccType}> ${fieldName};`);
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(`    operator ${className}() &&;`);
    header.mainMiddle.push(`    operator ${className}() & = delete;`);
    header.mainMiddle.push(
      `    // Usage: auto val = *${className}::whole{...};`,
    );
    header.mainMiddle.push(
      `    // Use this to avoid repeating '${className}' on both sides of =`,
    );
    header.mainMiddle.push(`    ${className} operator*() &&;`);
    header.mainMiddle.push(`    ${className} operator*() & = delete;`);
    header.mainMiddle.push("  };");
    header.mainMiddle.push("");
    for (const nestedRecord of nestedRecords) {
      let typeAlias = nestedRecord.name.text;
      if (typeAlias === className) {
        typeAlias = `${typeAlias}_`;
      }
      const recordLocation = recordMap.get(nestedRecord.key)!;
      const nestedClassName = getClassName(recordLocation);
      header.mainMiddle.push(`  using ${typeAlias} = ${nestedClassName};`);
    }
    header.mainMiddle.push("};");
    header.mainMiddle.push("");
    header.mainBottom.push("inline std::ostream& operator<<(");
    header.mainBottom.push("    std::ostream& os,");
    header.mainBottom.push(`    ${constRefType} input) {`);
    header.mainBottom.push(
      "  return os << ::skir_internal::ToDebugString(input);",
    );
    header.mainBottom.push("}");
    header.mainBottom.push("");
    {
      header.mainBottom.push("template <typename H>");
      header.mainBottom.push(`H AbslHashValue(H h, ${constRefType} input) {`);
      const args = fields
        .map((f) => `,\n      input.${maybeEscapeLowerCaseName(f.name.text)}`)
        .join("");
      header.mainBottom.push("  return H::combine(");
      header.mainBottom.push(`      std::move(h)${args});`);
      header.mainBottom.push("}");
      header.mainBottom.push("");
    }

    // --------------------------------------
    // - APPEND CODE IN THE .testing.h FILE -
    // --------------------------------------

    testingHeader.skirout.push("template <>");
    testingHeader.skirout.push(`struct StructIs<${qualifiedName}> {`);
    // Declare fields in alphabetical order. It helps users who want to
    // initialize a struct using the designated initializer syntax. See:
    // https://abseil.io/tips/172
    for (const field of fieldsByName) {
      const type = field.type!;
      const fieldIsRecursive =
        field.isRecursive === "hard" || field.isRecursive === "via-optional";
      const fieldName = maybeEscapeLowerCaseName(field.name.text);
      if (type.kind === "record") {
        // Do not pass fieldIsRecursive.
        const ccType = typeSpeller.getCcType(type, { forceNamespace: true });
        const recordType = recordMap.get(type.key)!.record.recordType;
        if (!fieldIsRecursive && recordType === "struct") {
          testingHeader.skirout.push(`  StructIs<${ccType}> ${fieldName};`);
        } else {
          testingHeader.skirout.push(`  Matcher<${ccType}> ${fieldName} = _;`);
        }
      } else {
        const ccType = typeSpeller.getCcType(type, {
          fieldIsRecursive: fieldIsRecursive,
          forceNamespace: true,
        });
        testingHeader.skirout.push(`  Matcher<${ccType}> ${fieldName} = _;`);
      }
    }
    testingHeader.skirout.push("");
    testingHeader.skirout.push(
      `  Matcher<${qualifiedName}> ToMatcher() const {`,
    );
    if (fields.length <= 0) {
      testingHeader.skirout.push("    return _;");
    } else {
      testingHeader.skirout.push(
        `    return ::testing::skir_internal::StructIs<${qualifiedName}>(`,
      );
      for (const field of fieldsByName) {
        const type = field.type!;
        const fieldIsRecursive =
          field.isRecursive === "hard" || field.isRecursive === "via-optional";
        const fieldName = field.name.text;
        let matcherExpr = maybeEscapeLowerCaseName(fieldName);
        if (type.kind === "record") {
          const recordType = recordMap.get(type.key)!.record.recordType;
          if (!fieldIsRecursive && recordType === "struct") {
            matcherExpr += ".ToMatcher()";
          }
        }
        const end = field === fieldsByName.at(-1) ? ");" : ",";
        const getterExpr = `::skirout::get_${fieldName}()`;
        testingHeader.skirout.push(
          `        std::make_pair(${getterExpr}, ${matcherExpr})${end}`,
        );
      }
    }
    testingHeader.skirout.push("  }");
    testingHeader.skirout.push("");
    testingHeader.skirout.push("  template <typename T>");
    testingHeader.skirout.push("  operator Matcher<T>() const {");
    testingHeader.skirout.push(
      "    return ::testing::SafeMatcherCast<T>(ToMatcher());",
    );
    testingHeader.skirout.push("  }");
    testingHeader.skirout.push("");
    testingHeader.skirout.push("};");
    testingHeader.skirout.push("");

    // -------------------------------
    // - APPEND CODE IN THE .cc FILE -
    // -------------------------------

    {
      // _GetArrayLength(const T&)
      source.anonymous.push("inline ::int32_t _GetArrayLength(");
      source.anonymous.push(`    ${constRefType} input,`);
      source.anonymous.push(
        "    const std::shared_ptr<skir_internal::UnrecognizedFieldsData>& u,",
      );
      source.anonymous.push("    skir_internal::UnrecognizedFormat format) {");
      source.anonymous.push("  if (u != nullptr && u->format == format)");
      source.anonymous.push("    return u->array_len;");
      for (const field of [...fieldsByNumber].reverse()) {
        const { number, name } = field;
        const fieldExpr = `input.${maybeEscapeLowerCaseName(name.text)}`;
        source.anonymous.push(
          `  if (!::skir_internal::IsDefault(${fieldExpr}))`,
        );
        source.anonymous.push(`    return ${number + 1};`);
      }
      source.anonymous.push("  return 0;");
      source.anonymous.push("}");
      source.anonymous.push("");
    }

    {
      // IsDefault(const T&)
      source.internalMain.push(
        `bool ${adapterName}::IsDefault(const type& input) {`,
      );
      const expression = fields.length
        ? fields
            .map((f) => {
              const fieldName = maybeEscapeLowerCaseName(f.name.text);
              return `::skir_internal::IsDefault(input.${fieldName})`;
            })
            .join("\n      && ")
        : "true";
      source.internalMain.push(`  return ${expression};`);
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, DenseJson&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, DenseJson& out) {`,
      );
      source.internalMain.push(
        "  const auto& unrecognized = input._unrecognized.data;",
      );
      source.internalMain.push(
        "  const auto array_len = _GetArrayLength(input, unrecognized, skir_internal::UnrecognizedFormat::kDenseJson);",
      );
      source.internalMain.push("  if (array_len == 0) {");
      source.internalMain.push("    out.out += {'[', ']'};");
      source.internalMain.push("    return;");
      source.internalMain.push("  }");
      source.internalMain.push("  JsonArrayCloser closer(&out);");
      let charLiterals = ["'['"];
      let lastFieldNumber = -1;
      for (const field of fieldsByNumber) {
        const { number, name } = field;
        // Append one 0 for every removed number.
        for (let i = lastFieldNumber + 1; i < number; ++i) {
          charLiterals.push("'0'");
          charLiterals.push("','");
        }
        source.internalMain.push(`  out.out += {${charLiterals.join(", ")}};`);
        charLiterals = [];
        const fieldExpr = `input.${maybeEscapeLowerCaseName(name.text)}`;
        source.internalMain.push(
          `  ::skir_internal::Append(${fieldExpr}, out);`,
        );
        source.internalMain.push(`  if (array_len == ${number + 1}) return;`);
        lastFieldNumber = number;
        charLiterals.push("','");
      }
      for (let i = numSlots; i < numSlotsInclRemovedNumbers; ++i) {
        charLiterals.push("'0'");
        charLiterals.push("','");
      }
      source.internalMain.push(`  out.out += {${charLiterals.join(", ")}};`);
      source.internalMain.push("  unrecognized->values.AppendTo(out);");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, ReadableJson&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, ReadableJson& out) {`,
      );
      if (fields.length) {
        source.internalMain.push("  JsonObjectWriter(&out)");
        for (const field of fields) {
          const isLastField = field === fields.at(-1);
          const maybeSemicolon = isLastField ? ";" : "";
          const name = field.name.text;
          const fieldExpr = `input.${maybeEscapeLowerCaseName(name)}`;
          source.internalMain.push(
            `      .Write("${name}", ${fieldExpr})${maybeSemicolon}`,
          );
        }
      } else {
        source.internalMain.push("  out.out += {'{', '}'};");
      }
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, DebugString&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, DebugString& out) {`,
      );
      if (fields.length) {
        source.internalMain.push("  DebugObjectWriter(&out)");
        for (const field of fields) {
          const isLastField = field === fields.at(-1);
          const maybeSemicolon = isLastField ? ";" : "";
          const name = maybeEscapeLowerCaseName(field.name.text);
          const fieldExpr = `input.${name}`;
          source.internalMain.push(
            `      .Write("${name}", ${fieldExpr})${maybeSemicolon}`,
          );
        }
      } else {
        source.internalMain.push("  out.out += {'{', '}'};");
      }
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, ByteSink&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, ByteSink& out) {`,
      );
      source.internalMain.push(
        "  const auto& unrecognized = input._unrecognized.data;",
      );
      source.internalMain.push(
        "  const auto array_len = _GetArrayLength(input, unrecognized, skir_internal::UnrecognizedFormat::kBytes);",
      );
      source.internalMain.push("  if (array_len == 0) {");
      source.internalMain.push("    out.Push(246);");
      source.internalMain.push("    return;");
      source.internalMain.push("  }");
      source.internalMain.push("  AppendArrayPrefix(array_len, out);");
      let lastFieldNumber = -1;
      for (const field of fieldsByNumber) {
        const { number, name } = field;
        const isLastField = field === fieldsByNumber.at(-1);
        if (lastFieldNumber < number - 1) {
          // Append one 0 for every removed number.
          const zeros = "0, ".repeat(number - lastFieldNumber - 1).slice(0, -2);
          source.internalMain.push(`  out.Push(${zeros});`);
        }
        const fieldExpr = `input.${maybeEscapeLowerCaseName(name.text)}`;
        source.internalMain.push(
          `  ::skir_internal::Append(${fieldExpr}, out);`,
        );
        if (!isLastField) {
          source.internalMain.push(`  if (array_len == ${number + 1}) return;`);
        }
        lastFieldNumber = number;
      }
      source.internalMain.push(
        `  if (array_len == ${lastFieldNumber + 1}) return;`,
      );
      if (numSlots < numSlotsInclRemovedNumbers) {
        // Append one 0 for every removed number at the end of the struct.
        const zeros = "0, "
          .repeat(numSlotsInclRemovedNumbers - numSlots)
          .slice(0, -2);
        source.internalMain.push(`  out.Push(${zeros});`);
      }
      source.internalMain.push("  unrecognized->values.AppendTo(out);");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Parse(JsonTokenizer&, T&)
      source.internalMain.push(`void ${adapterName}::Parse(`);
      source.internalMain.push("    JsonTokenizer& tokenizer,");
      source.internalMain.push("    type& out) {");
      source.internalMain.push("  switch (tokenizer.state().token_type) {");
      source.internalMain.push("    case JsonTokenType::kLeftSquareBracket: {");
      source.internalMain.push(
        "      JsonArrayReader array_reader(&tokenizer);",
      );
      let lastNumber = -1;
      for (const field of fieldsByNumber) {
        const ccFieldName = maybeEscapeLowerCaseName(field.name.text);
        source.internalMain.push(
          "      if (!array_reader.NextElement()) break;",
        );
        for (let i = lastNumber + 1; i < field.number; ++i) {
          source.internalMain.push("      SkipValue(tokenizer);");
          source.internalMain.push(
            "      if (!array_reader.NextElement()) break;",
          );
        }
        source.internalMain.push(
          `      ::skir_internal::Parse(tokenizer, out.${ccFieldName});`,
        );
        lastNumber = field.number;
      }
      source.internalMain.push("      if (!array_reader.NextElement()) break;");
      source.internalMain.push(
        "      auto& unrecognized = out._unrecognized.data;",
      );
      const args = [
        "array_reader",
        numSlots,
        numSlotsInclRemovedNumbers,
        "unrecognized",
      ].join(", ");
      source.internalMain.push(
        `      ::skir_internal::ParseUnrecognizedFields(${args});`,
      );
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kLeftCurlyBracket: {");
      const parserExpr =
        "(new StructJsonObjectParser<type>())" +
        fields
          .map((field) => {
            const name = field.name.text;
            const ccFieldName = maybeEscapeLowerCaseName(name);
            const indent = "              ";
            return `\n${indent}->AddField("${name}", &type::${ccFieldName})`;
          })
          .join("");
      source.internalMain.push("      static const auto* kParser =");
      source.internalMain.push(`          ${parserExpr};`);
      source.internalMain.push("      kParser->Parse(tokenizer, out);");
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kZero:");
      source.internalMain.push("      tokenizer.Next();");
      source.internalMain.push("      break;");
      source.internalMain.push("    default: {");
      source.internalMain.push(
        "      tokenizer.mutable_state().PushUnexpectedTokenError(\"'['\");",
      );
      source.internalMain.push("    }");
      source.internalMain.push("  }");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Parse(ByteSource&, T&)
      source.internalMain.push(
        `void ${adapterName}::Parse(ByteSource& source, type& out) {`,
      );
      source.internalMain.push("  ::uint32_t array_len = 0;");
      source.internalMain.push("  ParseArrayPrefix(source, array_len);");
      let lastNumber = -1;
      for (const field of fieldsByNumber) {
        const ccFieldName = maybeEscapeLowerCaseName(field.name.text);
        for (let i = lastNumber + 1; i < field.number; ++i) {
          source.internalMain.push(`  if (array_len == ${i}) return;`);
          source.internalMain.push("  SkipValue(source);");
        }
        source.internalMain.push(`  if (array_len == ${field.number}) return;`);
        source.internalMain.push(
          `  ::skir_internal::Parse(source, out.${ccFieldName});`,
        );
        lastNumber = field.number;
      }
      source.internalMain.push(`  if (array_len == ${numSlots}) return;`);
      source.internalMain.push(
        "  auto& unrecognized = out._unrecognized.data;",
      );
      const args = [
        "source",
        "array_len",
        numSlots,
        numSlotsInclRemovedNumbers,
        "unrecognized",
      ].join(", ");
      source.internalMain.push(
        `  ::skir_internal::ParseUnrecognizedFields(${args});`,
      );
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // GetType(skir_type<T>)
      source.internalMain.push(
        `skir::reflection::Type ${adapterName}::GetType(skir_type<type>) {`,
      );
      const recordId = getRecordId(struct);
      source.internalMain.push(
        `  return skir::reflection::RecordType({"${recordId}"});`,
      );
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // RegisterRecords(skir_type<T>, RecordRegistry&)
      const recordId = getRecordId(struct);
      source.internalMain.push(`void ${adapterName}::RegisterRecords(`);
      source.internalMain.push("    skir_type<type>,");
      source.internalMain.push(
        "    skir::reflection::RecordRegistry& registry) {",
      );
      source.internalMain.push("  const bool already_present =");
      source.internalMain.push(
        `      registry.find_or_null("${recordId}") != nullptr;`,
      );
      source.internalMain.push("  if (already_present) return;");
      source.internalMain.push("  skir::reflection::Struct record = {");
      source.internalMain.push(`      "${recordId}",`);
      source.internalMain.push(
        `      ${toCStringLiteral(struct.record.doc.text)},`,
      );
      source.internalMain.push("      {");
      for (const field of fields) {
        const ccType = typeSpeller.getCcType(field.type!, {
          forceNamespace: true,
        });
        source.internalMain.push("          {");
        source.internalMain.push(`              "${field.name.text}",`);
        source.internalMain.push(`              ${field.number},`);
        source.internalMain.push(
          `              skir_internal::GetType<${ccType}>(),`,
        );
        source.internalMain.push(
          `              ${toCStringLiteral(field.doc.text)},`,
        );
        source.internalMain.push("          },");
      }
      source.internalMain.push("      },");
      const removedNumbers = struct.record.removedNumbers.join(", ");
      source.internalMain.push(`      {${removedNumbers}},`);
      source.internalMain.push("  };");
      source.internalMain.push("  registry.push_back(std::move(record));");
      for (const field of fields) {
        const ccType = typeSpeller.getCcType(field.type!, {
          forceNamespace: true,
        });
        source.internalMain.push(
          `  skir_internal::RegisterRecords<${ccType}>(registry);`,
        );
      }
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Struct::operator==(const T&)
      source.mainBottom.push(
        `bool ${className}::operator==(${constRefType} other) const {`,
      );
      const expression = fields.length
        ? fields
            .map((f) => {
              const fieldName = maybeEscapeLowerCaseName(f.name.text);
              return `this->${fieldName} == other.${fieldName}`;
            })
            .join("\n      && ")
        : "true";
      source.mainBottom.push(`  return ${expression};`);
      source.mainBottom.push("}");
      source.mainBottom.push("");
    }

    {
      // Whole -> Struct
      source.mainBottom.push(
        `${className}::whole::operator ${className}() && {`,
      );
      source.mainBottom.push(`  return ${className}{`);
      for (const field of fieldsByName) {
        const fieldName = maybeEscapeLowerCaseName(field.name.text);
        source.mainBottom.push(`      *std::move(${fieldName}),`);
      }
      source.mainBottom.push("  };");
      source.mainBottom.push("}");
      source.mainBottom.push("");
      source.mainBottom.push(
        `${className} ${className}::whole::operator*() && {`,
      );
      source.mainBottom.push("  return std::move(*this);");
      source.mainBottom.push("}");
      source.mainBottom.push("");
    }
  }

  private writeCodeForEnum(record: RecordLocation): void {
    const { header, recordMap, source, typeSpeller } = this;

    const { nestedRecords } = record.record;
    const variants = getEnumVariants(record.record.fields, typeSpeller);
    const constVariants = variants.filter((f) => !f.valueType);
    const wrapperVariants = variants.filter((f) => f.valueType);

    for (const variant of constVariants) {
      this.writeCodeForConstantVariant(variant);
    }
    for (const variant of wrapperVariants) {
      this.writeCodeForWrapperVariant(variant);
    }

    const className = getClassName(record);
    const adapterName = `${className}Adapter`;
    const qualifiedName = `::${this.namespace}::${className}`;
    const constRefType = `const ${qualifiedName}&`;

    header.mainTop.push(`class ${className};`);

    header.mainMiddle.push(...commentify(docToCommentText(record.record.doc)));
    header.mainMiddle.push(`class ${className} {`);
    header.mainMiddle.push(" public:");
    for (const variant of wrapperVariants) {
      const type = `::skirout::${variant.structType}<${variant.valueType}>`;
      header.mainMiddle.push(`  using ${variant.typeAlias} = ${type};`);
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(`  // The kind of variant held by a ${className}.`);
    header.mainMiddle.push("  enum class kind_type {");
    for (const variant of variants) {
      header.mainMiddle.push(
        ...commentify(
          variant.isUnknownVariant
            ? `Constant indicating an unknown ${className}.\n`
            : docToCommentText(variant.doc),
          "    ",
        ),
      );
      header.mainMiddle.push(`    ${variant.kindEnumerator},`);
    }
    header.mainMiddle.push("  };");
    header.mainMiddle.push("");
    for (const variant of constVariants) {
      const { identifier, isUnknownVariant, kindEnumerator, structType } =
        variant;
      const assignment = isUnknownVariant ? " = ::skirout::kUnknown" : "";
      header.mainMiddle.push(
        `  // For example: FunctionExpecting${className}(skirout::${identifier})`,
      );
      header.mainMiddle.push(
        `  ${className}(::skirout::${structType}${assignment});`,
      );
      source.mainMiddle.push(
        `${className}::${className}(::skirout::${
          structType
        }) : kind_(kind_type::${kindEnumerator}) {\n  value_._unrecognized = nullptr;\n}`,
      );
    }
    source.mainMiddle.push("");
    for (const variant of wrapperVariants) {
      const { identifier, kindEnumerator, typeAlias, usePointer, variantName } =
        variant;
      header.mainMiddle.push(
        `  // For example: FunctionExpecting${className}(skirout::${identifier}(...))`,
      );
      header.mainMiddle.push(`  ${className}(${typeAlias});`);
      source.mainMiddle.push(`${className}::${className}(${typeAlias} w)`);
      source.mainMiddle.push(`    : kind_(kind_type::${kindEnumerator}) {`);
      if (usePointer) {
        source.mainMiddle.push(
          `  value_.${variantName}_ = new ${typeAlias}(std::move(w));`,
        );
      } else {
        source.mainMiddle.push(`  value_.${variantName}_ = w;`);
      }
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(`  ${className}(const ${className}&);`);
    source.mainMiddle.push(
      `${className}::${className}(const ${className}& other) {`,
    );
    source.mainMiddle.push("  copy(other);");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");

    header.mainMiddle.push(`  ${className}(${className}&&);`);
    header.mainMiddle.push("");
    source.mainMiddle.push(`${className}::${className}(${className}&& other)`);
    source.mainMiddle.push(`    : kind_(other.kind_),`);
    source.mainMiddle.push(`      value_(other.value_) {`);
    source.mainMiddle.push("  other.kind_ = kind_type::kUnknown;");
    source.mainMiddle.push("  other.value_._unrecognized = nullptr;");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    {
      source.mainMiddle.push(
        `${className}::${
          className
        }(unrecognized_variant u) : kind_(kind_type::kUnknown) {`,
      );
      source.mainMiddle.push(
        "  value_._unrecognized = new unrecognized_variant(std::move(u));",
      );
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(`  ~${className}();`);
    header.mainMiddle.push("");
    source.mainMiddle.push(`${className}::~${className}() {`);
    source.mainMiddle.push("  free_value();");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    for (const variant of constVariants) {
      const { identifier } = variant;
      header.mainMiddle.push(
        `  static constexpr auto ${identifier} = ::skirout::${identifier};`,
      );
    }
    header.mainMiddle.push("");
    for (const variant of wrapperVariants) {
      const { identifier, usePointer, valueType } = variant;
      header.mainMiddle.push(
        `  static ${className} ${identifier}(${valueType} value);`,
      );
      source.mainMiddle.push(
        `${className} ${className}::${identifier}(${valueType} value) {`,
      );
      const maybeMoveValue = usePointer ? "std::move(value)" : "value";
      const returnValue = `${className}(::skirout::${identifier}(${maybeMoveValue}))`;
      source.mainMiddle.push(`  return ${returnValue};`);
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(
      `  // Returns the kind of variant held by this ${className}.`,
    );
    header.mainMiddle.push("  kind_type kind() const { return kind_; }");
    header.mainMiddle.push("");
    for (const variant of wrapperVariants) {
      const { variantName, kindEnumerator, usePointer, valueType } = variant;
      header.mainMiddle.push(
        `  // Returns true if this ${className} holds a ${variantName} variant.`,
      );
      header.mainMiddle.push(`  inline bool is_${variantName}() const;`);
      header.mainMiddle.push(
        `  // Assuming this ${className} holds a ${variantName} variant, returns its value.`,
      );
      header.mainMiddle.push(
        `  inline const ${valueType}& as_${variantName}() const;`,
      );
      header.mainMiddle.push(`  inline ${valueType}& as_${variantName}();`);
      header.mainMiddle.push("");
      header.mainBottom.push(
        `inline bool ${className}::is_${variantName}() const {`,
      );
      header.mainBottom.push(`  return kind_ == kind_type::${kindEnumerator};`);
      header.mainBottom.push("}");
      header.mainBottom.push("");
      header.mainBottom.push(
        `inline const ${valueType}& ${className}::as_${variantName}() const {`,
      );
      header.mainBottom.push(
        `  return const_cast<${className}*>(this)->as_${variantName}();`,
      );
      header.mainBottom.push("}");
      header.mainBottom.push("");
      header.mainBottom.push(
        `inline ${valueType}& ${className}::as_${variantName}() {`,
      );
      header.mainBottom.push(
        `  ABSL_CHECK(is_${variantName}()) << "actual: " << *this;`,
      );
      const returnValue = usePointer
        ? `value_.${variantName}_->value`
        : `value_.${variantName}_.value`;
      header.mainBottom.push(`  return ${returnValue};`);
      header.mainBottom.push("}");
      header.mainBottom.push("");
    }

    {
      const commentLines = ["Example:", "", "  struct visitor {"];
      for (const variant of constVariants) {
        const { structType } = variant;
        commentLines.push(
          `    void operator()(skirout::${structType}) { ... }`,
        );
      }
      for (const variant of wrapperVariants) {
        const { structType } = variant;
        commentLines.push(
          `    void operator()(const ${className}::${structType}& w) {`,
        );
        commentLines.push("      const auto& value = w.value;");
        commentLines.push("      ...");
        commentLines.push("    }");
      }
      commentLines.push("  };");
      commentLines.push("  e.visit(visitor());");
      header.mainMiddle.push(...commentify(commentLines, "  "));
    }
    header.mainMiddle.push("  template <typename Visitor>");
    header.mainMiddle.push("  decltype(auto) visit(Visitor&& visitor) const {");
    header.mainMiddle.push(
      `    return visit_impl(*this, std::forward<Visitor>(visitor));`,
    );
    header.mainMiddle.push("  }");
    header.mainMiddle.push("  template <typename Visitor>");
    header.mainMiddle.push("  decltype(auto) visit(Visitor&& visitor) {");
    header.mainMiddle.push(
      `    return visit_impl(*this, std::forward<Visitor>(visitor));`,
    );
    header.mainMiddle.push("  }");
    header.mainMiddle.push("");

    header.mainMiddle.push(
      `  ${className}& operator=(const ${className}& other);`,
    );
    source.mainMiddle.push(
      `${className}& ${className}::operator=(const ${className}& other) {`,
    );
    source.mainMiddle.push("  free_value();");
    source.mainMiddle.push("  copy(other);");
    source.mainMiddle.push("  return *this;");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    header.mainMiddle.push(`  ${className}& operator=(${className}&& other);`);
    source.mainMiddle.push(
      `${className}& ${className}::operator=(${className}&& other) {`,
    );
    source.mainMiddle.push("  free_value();");
    source.mainMiddle.push("  kind_ = other.kind_;");
    source.mainMiddle.push("  value_ = other.value_;");
    source.mainMiddle.push("  other.kind_ = kind_type::kUnknown;");
    source.mainMiddle.push("  other.value_._unrecognized = nullptr;");
    source.mainMiddle.push("  return *this;");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    header.mainMiddle.push("");
    for (const variant of constVariants) {
      const { kindEnumerator, structType } = variant;
      header.mainMiddle.push(
        `  ${className}& operator=(::skirout::${structType});`,
      );
      source.mainMiddle.push(
        `${className}& ${className}::operator=(::skirout::${structType}) {`,
      );
      source.mainMiddle.push("  free_value();");
      source.mainMiddle.push(`  kind_ = kind_type::${kindEnumerator};`);
      source.mainMiddle.push("  value_._unrecognized = nullptr;");
      source.mainMiddle.push("  return *this;");
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    }
    for (const variant of wrapperVariants) {
      const { variantName, kindEnumerator, typeAlias, usePointer } = variant;
      header.mainMiddle.push(`  ${className}& operator=(${typeAlias});`);
      source.mainMiddle.push(
        `${className}& ${className}::operator=(${typeAlias} w) {`,
      );
      source.mainMiddle.push("  free_value();");
      source.mainMiddle.push(`  kind_ = kind_type::${kindEnumerator};`);
      if (usePointer) {
        source.mainMiddle.push(
          `  value_.${variantName}_ = new ${typeAlias}(std::move(w));`,
        );
      } else {
        source.mainMiddle.push(`  value_.${variantName}_ = w;`);
      }
      source.mainMiddle.push("  return *this;");
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    }
    header.mainMiddle.push("");

    if (wrapperVariants.length) {
      header.mainMiddle.push(`  bool operator==(const ${className}&) const;`);

      source.mainMiddle.push(
        `bool ${className}::operator==(const ${className}& other) const {`,
      );
      source.mainMiddle.push("  if (other.kind_ != kind_) return false;");
      source.mainMiddle.push("  switch (kind_) {");
      for (const variant of wrapperVariants) {
        const { variantName, kindEnumerator, usePointer } = variant;
        const dotOrStar = usePointer ? "->" : ".";
        const a = `value_.${variantName}_${dotOrStar}value`;
        const b = `other.value_.${variantName}_${dotOrStar}value`;
        source.mainMiddle.push(`    case kind_type::${kindEnumerator}:`);
        source.mainMiddle.push(`      return ${a} == ${b};`);
      }
      source.mainMiddle.push(`    default:`);
      source.mainMiddle.push("      return true;");
      source.mainMiddle.push("  }");
      source.mainMiddle.push("}");
      source.mainMiddle.push("");
    } else {
      header.mainMiddle.push(
        `  inline bool operator==(const ${className}& other) const {`,
      );
      header.mainMiddle.push("    return other.kind_ == kind_;");
      header.mainMiddle.push("  }");
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(
      `  inline bool operator!=(const ${className}& other) const {`,
    );
    header.mainMiddle.push("    return !(*this == other);");
    header.mainMiddle.push("  }");
    header.mainMiddle.push("");
    for (const nestedRecord of nestedRecords) {
      let typeAlias = nestedRecord.name.text;
      if (typeAlias === className) {
        typeAlias = `${typeAlias}_`;
      }
      const recordLocation = recordMap.get(nestedRecord.key)!;
      const nestedClassName = getClassName(recordLocation);
      header.mainMiddle.push(`  using ${typeAlias} = ${nestedClassName};`);
    }
    header.mainMiddle.push("");
    header.mainMiddle.push(" private:");
    header.mainMiddle.push(
      "  using unrecognized_variant = ::skir_internal::UnrecognizedVariant;",
    );
    header.mainMiddle.push("");
    header.mainMiddle.push(`  ${className}(unrecognized_variant);`);
    header.mainMiddle.push("");
    header.mainMiddle.push("  kind_type kind_;");
    header.mainMiddle.push("");
    header.mainMiddle.push("  union value_wrapper {");
    header.mainMiddle.push("    value_wrapper() {}");
    header.mainMiddle.push("    unrecognized_variant* _unrecognized;");
    for (const variant of wrapperVariants) {
      const { variantName, typeAlias } = variant;
      const maybeStar = variant.usePointer ? "*" : "";
      header.mainMiddle.push(`    ${typeAlias}${maybeStar} ${variantName}_;`);
    }
    header.mainMiddle.push("  };");
    header.mainMiddle.push("  value_wrapper value_;");
    header.mainMiddle.push("");
    header.mainMiddle.push(`  void copy(const ${className}&);`);

    source.mainMiddle.push(
      `void ${className}::copy(const ${className}& other) {`,
    );
    source.mainMiddle.push("  kind_ = other.kind_;");
    source.mainMiddle.push("  switch (other.kind_) {");
    for (const variant of wrapperVariants) {
      const { variantName, kindEnumerator, typeAlias, usePointer } = variant;
      source.mainMiddle.push(`    case kind_type::${kindEnumerator}:`);
      if (usePointer) {
        const expr = `new ${typeAlias}(*other.value_.${variantName}_)`;
        source.mainMiddle.push(`      value_.${variantName}_ = ${expr};`);
      } else {
        source.mainMiddle.push(
          `      value_.${variantName}_ = other.value_.${variantName}_;`,
        );
      }
      source.mainMiddle.push("      break;");
    }
    source.mainMiddle.push("    default: {");
    source.mainMiddle.push(
      "      const unrecognized_variant* u = other.value_._unrecognized;",
    );
    source.mainMiddle.push(
      "      value_._unrecognized = u != nullptr ? new unrecognized_variant(*u) : nullptr;",
    );
    source.mainMiddle.push("      break;");
    source.mainMiddle.push("    }");
    source.mainMiddle.push("  }");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    header.mainMiddle.push("  void free_value() const;");

    source.mainMiddle.push(`void ${className}::free_value() const {`);
    source.mainMiddle.push("  switch (kind_) {");
    for (const variant of wrapperVariants) {
      const { variantName, kindEnumerator, typeAlias, usePointer } = variant;
      source.mainMiddle.push(`    case kind_type::${kindEnumerator}:`);
      if (usePointer) {
        source.mainMiddle.push(
          `      ::std::unique_ptr<${typeAlias}>(value_.${variantName}_);`,
        );
      }
      source.mainMiddle.push("      break;");
    }
    source.mainMiddle.push("    default:");
    source.mainMiddle.push(
      "      ::std::unique_ptr<unrecognized_variant>(value_._unrecognized);",
    );
    source.mainMiddle.push("      break;");
    source.mainMiddle.push("  }");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
    header.mainMiddle.push("");
    header.mainMiddle.push("  template <typename E, typename Visitor>");
    header.mainMiddle.push(
      "  static decltype(auto) visit_impl(E& e, Visitor&& visitor) {",
    );
    header.mainMiddle.push("    switch (e.kind_) {");
    for (const variant of constVariants) {
      const { kindEnumerator, structType } = variant;
      header.mainMiddle.push(`      case kind_type::${kindEnumerator}:`);
      header.mainMiddle.push(
        `        return std::forward<Visitor>(visitor)(::skirout::${
          structType
        }());`,
      );
    }
    for (const variant of wrapperVariants) {
      const { variantName, kindEnumerator, usePointer } = variant;
      const maybeStar = usePointer ? "*" : "";
      header.mainMiddle.push(`      case kind_type::${kindEnumerator}:`);
      header.mainMiddle.push(
        `        return std::forward<Visitor>(visitor)(${maybeStar}e.value_.${
          variantName
        }_);`,
      );
    }
    header.mainMiddle.push("    }");
    header.mainMiddle.push("    ABSL_CHECK(false);");
    header.mainMiddle.push("  }");
    header.mainMiddle.push("");
    header.mainMiddle.push(
      `  friend class ::skir_internal::${this.namespace}::${adapterName};`,
    );
    header.mainMiddle.push("};");
    header.mainMiddle.push("");

    for (const variant of constVariants) {
      const { kindEnumerator, structType } = variant;
      header.mainBottom.push("inline bool operator==(");
      header.mainBottom.push(`    ${constRefType} a,`);
      header.mainBottom.push(`    ::skirout::${structType}) {`);
      header.mainBottom.push(
        `  return a.kind() == ${qualifiedName}::kind_type::${kindEnumerator};`,
      );
      header.mainBottom.push("}");
      header.mainBottom.push("");
      header.mainBottom.push("inline bool operator!=(");
      header.mainBottom.push(`    ${constRefType} a,`);
      header.mainBottom.push(`    ::skirout::${structType} b) {`);
      header.mainBottom.push("  return !(a == b);");
      header.mainBottom.push("}");
      header.mainBottom.push("");
      header.mainBottom.push("inline bool operator==(");
      header.mainBottom.push(`    ::skirout::${variant.structType},`);
      header.mainBottom.push(`    ${constRefType} b) {`);
      header.mainBottom.push(
        `  return ${qualifiedName}::kind_type::${kindEnumerator} == b.kind();`,
      );
      header.mainBottom.push("}");
      header.mainBottom.push("");
      header.mainBottom.push("inline bool operator!=(");
      header.mainBottom.push(`    ::skirout::${variant.structType} a,`);
      header.mainBottom.push(`    ${constRefType} b) {`);
      header.mainBottom.push("  return !(a == b);");
      header.mainBottom.push("}");
      header.mainBottom.push("");
    }
    header.mainBottom.push("template <typename H>");
    header.mainBottom.push(`H AbslHashValue(H h, ${constRefType} input) {`);
    header.mainBottom.push("  struct visitor {");
    header.mainBottom.push("    H h;");
    for (const variant of constVariants) {
      const { variantName, structType } = variant;
      header.mainBottom.push(`    H operator()(::skirout::${structType}) {`);
      const hash = simpleHash(variantName);
      header.mainBottom.push(`      return H::combine(std::move(h), ${hash});`);
      header.mainBottom.push("    }");
    }
    for (const variant of wrapperVariants) {
      const { variantName, typeAlias } = variant;
      header.mainBottom.push(
        `    H operator()(const ${className}::${typeAlias}& w) {`,
      );
      const hash = simpleHash(variantName);
      header.mainBottom.push(
        `      return H::combine(std::move(h), ${hash}, w.value);`,
      );
      header.mainBottom.push("    }");
    }
    header.mainBottom.push("  };");
    header.mainBottom.push("  return input.visit(visitor{std::move(h)});");
    header.mainBottom.push("}");
    header.mainBottom.push("");
    header.mainMiddle.push("inline std::ostream& operator<<(");
    header.mainMiddle.push("    std::ostream& os,");
    header.mainMiddle.push(`    ${constRefType} input) {`);
    header.mainMiddle.push(
      "  return os << ::skir_internal::ToDebugString(input);",
    );
    header.mainMiddle.push("}");
    header.mainMiddle.push("");

    {
      // IsDefault(const T&)
      source.internalMain.push(
        `bool ${adapterName}::IsDefault(const type& input) {`,
      );
      source.internalMain.push("  return input == ::skirout::kUnknown;");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, DenseJson&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, DenseJson& out) {`,
      );
      source.internalMain.push("  switch (input.kind_) {");
      for (const variant of constVariants) {
        const { variantNumber, kindEnumerator, isUnknownVariant } = variant;
        source.internalMain.push(
          `    case type::kind_type::${kindEnumerator}: {`,
        );
        if (isUnknownVariant) {
          source.internalMain.push(
            "      AppendUnrecognizedVariant(input.value_._unrecognized, out);",
          );
        } else {
          source.internalMain.push(
            `      out.out += {${numberToCharLiterals(variantNumber)}};`,
          );
        }
        source.internalMain.push("      break;");
        source.internalMain.push("    }");
      }
      for (const variant of wrapperVariants) {
        const { variantName, variantNumber, kindEnumerator, usePointer } =
          variant;
        const dotOrArrow = usePointer ? "->" : ".";
        source.internalMain.push(
          `    case type::kind_type::${kindEnumerator}: {`,
        );
        source.internalMain.push(
          `      out.out += {'[', ${numberToCharLiterals(variantNumber)}, ','};`,
        );
        source.internalMain.push(
          `      ::skir_internal::Append(input.value_.${variantName}_${
            dotOrArrow
          }value, out);`,
        );
        source.internalMain.push("      out.out += ']';");
        source.internalMain.push("      break;");
        source.internalMain.push("    }");
      }
      source.internalMain.push("  }");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, ReadableJson&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, ReadableJson& out) {`,
      );
      source.internalMain.push("  struct visitor {");
      source.internalMain.push("    ReadableJson& out;");
      for (const variant of constVariants) {
        const { variantName, structType } = variant;
        source.internalMain.push(
          `    void operator()(::skirout::${structType}) {`,
        );
        source.internalMain.push(`      out.out += "\\"${variantName}\\"";`);
        source.internalMain.push("    }");
      }
      for (const variant of wrapperVariants) {
        const { variantName, typeAlias } = variant;
        source.internalMain.push(
          `    void operator()(const type::${typeAlias}& w) {`,
        );
        source.internalMain.push("      out.new_line.Indent();");
        source.internalMain.push(
          `      absl::StrAppend(&out.out, "{", *out.new_line, "\\"kind\\": \\"${variantName}\\",",`,
        );
        source.internalMain.push(
          '                      *out.new_line, "\\"value\\": ");',
        );
        source.internalMain.push(
          "      ::skir_internal::Append(w.value, out);",
        );
        source.internalMain.push(
          '      absl::StrAppend(&out.out, out.new_line.Dedent(), "}");',
        );
        source.internalMain.push("    }");
      }
      source.internalMain.push("  };");
      source.internalMain.push("  input.visit(visitor{out});");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, DebugString&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, DebugString& out) {`,
      );
      source.internalMain.push("  struct visitor {");
      source.internalMain.push("    DebugString& out;");
      for (const variant of constVariants) {
        const { identifier, structType } = variant;
        source.internalMain.push(
          `    void operator()(::skirout::${structType}) {`,
        );
        source.internalMain.push(`      out.out += "skirout::${identifier}";`);
        source.internalMain.push("    }");
      }
      for (const variant of wrapperVariants) {
        const { identifier, typeAlias } = variant;
        source.internalMain.push(
          `    void operator()(const ${qualifiedName}::${typeAlias}& w) {`,
        );
        source.internalMain.push(
          `      out.out += "::skirout::${identifier}(";`,
        );
        source.internalMain.push(
          "      ::skir_internal::Append(w.value, out);",
        );
        source.internalMain.push("      out.out += ')';");
        source.internalMain.push("    }");
      }
      source.internalMain.push("  };");
      source.internalMain.push("  input.visit(visitor{out});");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Append(const T&, ByteSink&)
      source.internalMain.push(
        `void ${adapterName}::Append(const type& input, ByteSink& out) {`,
      );
      source.internalMain.push("  switch (input.kind_) {");
      for (const variant of constVariants) {
        const { variantNumber, isUnknownVariant, kindEnumerator } = variant;
        source.internalMain.push(
          `    case type::kind_type::${kindEnumerator}: {`,
        );
        if (isUnknownVariant) {
          source.internalMain.push(
            "      AppendUnrecognizedVariant(input.value_._unrecognized, out);",
          );
        } else {
          const intLiterals = bytesToIntLiterals([
            ...encodeInt32(variantNumber),
          ]);
          source.internalMain.push(`      out.Push(${intLiterals});`);
        }
        source.internalMain.push("      break;");
        source.internalMain.push("    }");
      }
      for (const variant of wrapperVariants) {
        const { variantName, variantNumber, kindEnumerator, usePointer } =
          variant;
        const intLiterals = bytesToIntLiterals(
          1 <= variantNumber && variantNumber <= 4
            ? [variantNumber + 250]
            : [248, ...encodeInt32(variantNumber)],
        );
        const dotOrArrow = usePointer ? "->" : ".";
        source.internalMain.push(
          `    case type::kind_type::${kindEnumerator}: {`,
        );
        source.internalMain.push(`      out.Push(${intLiterals});`);
        source.internalMain.push(
          `      ::skir_internal::Append(input.value_.${variantName}_${
            dotOrArrow
          }value, out);`,
        );
        source.internalMain.push("      break;");
        source.internalMain.push("    }");
      }
      source.internalMain.push("  }");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Parse(JsonTokenizer&, T&)
      source.internalMain.push(
        `void ${adapterName}::Parse(JsonTokenizer& tokenizer, type& out) {`,
      );
      if (wrapperVariants.length > 0) {
        source.internalMain.push(
          "  const auto set_wrapper_default = [&](auto* wrapper) -> bool {",
        );
        source.internalMain.push(
          "    using Value = std::remove_reference_t<decltype(wrapper->value)>;",
        );
        source.internalMain.push(
          '    const absl::StatusOr<Value> parsed = ::skir::Parse<Value>("0");',
        );
        source.internalMain.push("    if (!parsed.ok()) return false;");
        source.internalMain.push("    wrapper->value = *parsed;");
        source.internalMain.push("    out = std::move(*wrapper);");
        source.internalMain.push("    return true;");
        source.internalMain.push("  };");
      }
      source.internalMain.push("  switch (tokenizer.state().token_type) {");
      source.internalMain.push("    case JsonTokenType::kZero:");
      source.internalMain.push("      tokenizer.Next();");
      source.internalMain.push("      break;");
      source.internalMain.push("    case JsonTokenType::kUnsignedInteger: {");
      source.internalMain.push(
        "      const int i = tokenizer.state().uint_value;",
      );
      source.internalMain.push("      switch (i) {");
      for (const variant of constVariants) {
        const { variantNumber, identifier } = variant;
        if (variant.variantNumber === 0) continue;
        source.internalMain.push(`        case ${variantNumber}:`);
        source.internalMain.push(`          out = ::skirout::${identifier};`);
        source.internalMain.push("          break;");
      }
      for (const variant of wrapperVariants) {
        const { variantNumber, typeAlias } = variant;
        source.internalMain.push(`        case ${variantNumber}: {`);
        source.internalMain.push(`          type::${typeAlias} wrapper;`);
        source.internalMain.push(
          "          (void)set_wrapper_default(&wrapper);",
        );
        source.internalMain.push("          break;");
        source.internalMain.push("        }");
      }
      source.internalMain.push("        default:");
      source.internalMain.push(
        "          if (tokenizer.keep_unrecognized_values()) {",
      );
      source.internalMain.push(
        "            out = type(UnrecognizedVariant{::skir_internal::UnrecognizedFormat::kDenseJson, i});",
      );
      source.internalMain.push("          }");
      source.internalMain.push("      }");
      source.internalMain.push("      tokenizer.Next();");
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kSignedInteger: {");
      source.internalMain.push("      tokenizer.Next();");
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kString: {");
      source.internalMain.push(
        "      static const auto* kMap = new absl::flat_hash_map<std::string, type>({",
      );
      for (const variant of constVariants) {
        const { variantName, identifier } = variant;
        source.internalMain.push(
          `          {"${variantName}", type::${identifier}},`,
        );
        {
          const variantNameUpper = variantName.toUpperCase();
          if (variantNameUpper !== variantName) {
            source.internalMain.push(
              `          {"${variantNameUpper}", type::${identifier}},`,
            );
          }
        }
        {
          const variantNameLower = variantName.toLowerCase();
          if (variantNameLower !== variantName) {
            source.internalMain.push(
              `          {"${variantNameLower}", type::${identifier}},`,
            );
          }
        }
      }
      source.internalMain.push("      });");
      source.internalMain.push(
        "      const auto it = kMap->find(tokenizer.state().string_value);",
      );
      source.internalMain.push("      if (it != kMap->cend()) {");
      source.internalMain.push("        out = it->second;");
      source.internalMain.push("        tokenizer.Next();");
      source.internalMain.push("        break;");
      source.internalMain.push("      }");
      for (const variant of wrapperVariants) {
        const { variantName, typeAlias } = variant;
        source.internalMain.push(
          `      if (tokenizer.state().string_value == ${toCStringLiteral(
            variantName,
          )}) {`,
        );
        source.internalMain.push(`        type::${typeAlias} wrapper;`);
        source.internalMain.push("        out = std::move(wrapper);");
        source.internalMain.push("        tokenizer.Next();");
        source.internalMain.push("        break;");
        source.internalMain.push("      }");
      }
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kLeftSquareBracket: {");
      source.internalMain.push("      EnumJsonArrayParser parser(&tokenizer);");
      source.internalMain.push("      const int number = parser.ReadNumber();");
      source.internalMain.push("      switch (number) {");
      for (const variant of constVariants) {
        const { variantNumber, identifier } = variant;
        if (variant.variantNumber === 0) continue;
        source.internalMain.push(`        case ${variantNumber}: {`);
        source.internalMain.push("          SkipValue(tokenizer);");
        source.internalMain.push(`          out = ::skirout::${identifier};`);
        source.internalMain.push("          break;");
        source.internalMain.push("        }");
      }
      for (const variant of wrapperVariants) {
        const { variantNumber, typeAlias } = variant;
        source.internalMain.push(`        case ${variantNumber}: {`);
        source.internalMain.push(`          type::${typeAlias} wrapper;`);
        source.internalMain.push(
          "          ::skir_internal::Parse(tokenizer, wrapper.value);",
        );
        source.internalMain.push("          out = std::move(wrapper);");
        source.internalMain.push("          break;");
        source.internalMain.push("        }");
      }
      source.internalMain.push("        default: {");
      source.internalMain.push(
        "          if (tokenizer.keep_unrecognized_values()) {",
      );
      source.internalMain.push(
        "            UnrecognizedVariant unrecognized{::skir_internal::UnrecognizedFormat::kDenseJson, number};",
      );
      source.internalMain.push(
        "            unrecognized.emplace_value().ParseFrom(tokenizer);",
      );
      source.internalMain.push(
        "            out = type(std::move(unrecognized));",
      );
      source.internalMain.push("          } else {");
      source.internalMain.push("            SkipValue(tokenizer);");
      source.internalMain.push("          }");
      source.internalMain.push("        }");
      source.internalMain.push("      }");
      source.internalMain.push("      parser.Finish();");
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    case JsonTokenType::kLeftCurlyBracket: {");
      const parserExpr =
        "(new EnumJsonObjectParser<type>())" +
        wrapperVariants
          .map((variant) => {
            const { variantName, typeAlias } = variant;
            const indent = "              ";
            return `\n${indent}->AddVariant<type::${typeAlias}>("${variantName}")`;
          })
          .join("");
      source.internalMain.push("      static const auto* kParser =");
      source.internalMain.push(`          ${parserExpr};`);
      source.internalMain.push("      kParser->Parse(tokenizer, out);");
      source.internalMain.push("      break;");
      source.internalMain.push("    }");
      source.internalMain.push("    default: {");
      source.internalMain.push(
        "      tokenizer.mutable_state().PushUnexpectedTokenError(\"number or '['\");",
      );
      source.internalMain.push("    }");
      source.internalMain.push("  }");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // Parse(ByteSource&, T&)
      source.internalMain.push(
        `void ${adapterName}::Parse(ByteSource& source, type& out) {`,
      );
      if (wrapperVariants.length > 0) {
        source.internalMain.push(
          "  const auto set_wrapper_default = [&](auto* wrapper) -> void {",
        );
        source.internalMain.push(
          "    using Value = std::remove_reference_t<decltype(wrapper->value)>;",
        );
        source.internalMain.push(
          '    const absl::StatusOr<Value> parsed = ::skir::Parse<Value>("0");',
        );
        source.internalMain.push("    if (!parsed.ok()) return;");
        source.internalMain.push("    wrapper->value = *parsed;");
        source.internalMain.push("    out = std::move(*wrapper);");
        source.internalMain.push("  };");
      }
      source.internalMain.push(
        "  const auto [has_value, number] = ParseEnumPrefix(source);",
      );
      source.internalMain.push("  if (has_value) {");
      source.internalMain.push("    switch (number) {");
      for (const variant of constVariants) {
        const { variantNumber, identifier } = variant;
        if (variant.variantNumber === 0) continue;
        source.internalMain.push(`      case ${variantNumber}: {`);
        source.internalMain.push("        SkipValue(source);");
        source.internalMain.push(`        out = ::skirout::${identifier};`);
        source.internalMain.push("        break;");
        source.internalMain.push("      }");
      }
      for (const variant of wrapperVariants) {
        const { variantNumber, typeAlias } = variant;
        source.internalMain.push(`      case ${variantNumber}: {`);
        source.internalMain.push(`        type::${typeAlias} wrapper;`);
        source.internalMain.push(
          "        ::skir_internal::Parse(source, wrapper.value);",
        );
        source.internalMain.push("        out = std::move(wrapper);");
        source.internalMain.push("        break;");
        source.internalMain.push("      }");
      }
      source.internalMain.push("      default: {");
      source.internalMain.push(
        "        if (source.keep_unrecognized_values) {",
      );
      source.internalMain.push(
        "          UnrecognizedVariant unrecognized{::skir_internal::UnrecognizedFormat::kBytes, number};",
      );
      source.internalMain.push(
        "          unrecognized.emplace_value().ParseFrom(source);",
      );
      source.internalMain.push(
        "          out = type(std::move(unrecognized));",
      );
      source.internalMain.push("        } else {");
      source.internalMain.push("          SkipValue(source);");
      source.internalMain.push("        }");
      source.internalMain.push("      }");
      source.internalMain.push("    }");
      source.internalMain.push("  } else {");
      source.internalMain.push("    switch (number) {");
      source.internalMain.push("      case 0:");
      source.internalMain.push("        break;");
      for (const variant of constVariants) {
        const { variantNumber, identifier } = variant;
        if (variant.variantNumber === 0) continue;
        source.internalMain.push(`      case ${variantNumber}:`);
        source.internalMain.push(`        out = ::skirout::${identifier};`);
        source.internalMain.push("        break;");
      }
      for (const variant of wrapperVariants) {
        const { variantNumber, typeAlias } = variant;
        source.internalMain.push(`      case ${variantNumber}: {`);
        source.internalMain.push(`        type::${typeAlias} wrapper;`);
        source.internalMain.push("        set_wrapper_default(&wrapper);");
        source.internalMain.push("        break;");
        source.internalMain.push("      }");
      }
      source.internalMain.push("      default: {");
      source.internalMain.push(
        "        if (source.keep_unrecognized_values) {",
      );
      source.internalMain.push(
        "          out = type(UnrecognizedVariant{::skir_internal::UnrecognizedFormat::kBytes, number});",
      );
      source.internalMain.push("        }");
      source.internalMain.push("      }");
      source.internalMain.push("    }");
      source.internalMain.push("  }");
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // GetType(skir_type<T>)
      source.internalMain.push(
        `skir::reflection::Type ${adapterName}::GetType(skir_type<type>) {`,
      );
      const recordId = getRecordId(record);
      source.internalMain.push(
        `  return skir::reflection::RecordType({"${recordId}"});`,
      );
      source.internalMain.push("}");
      source.internalMain.push("");
    }

    {
      // RegisterRecords(skir_type<T>, RecordRegistry&)
      const recordId = getRecordId(record);
      source.internalMain.push(`void ${adapterName}::RegisterRecords(`);
      source.internalMain.push("    skir_type<type>,");
      source.internalMain.push(
        "    skir::reflection::RecordRegistry& registry) {",
      );
      source.internalMain.push("  const bool already_present =");
      source.internalMain.push(
        `      registry.find_or_null("${recordId}") != nullptr;`,
      );
      source.internalMain.push("  if (already_present) return;");
      source.internalMain.push("  skir::reflection::Enum record = {");
      source.internalMain.push(`      "${recordId}",`);
      source.internalMain.push(
        `      ${toCStringLiteral(record.record.doc.text)},`,
      );
      source.internalMain.push("      {");
      for (const variant of constVariants) {
        if (variant.isUnknownVariant) {
          continue;
        }
        source.internalMain.push("          {");
        source.internalMain.push(`              "${variant.variantName}",`);
        source.internalMain.push(`              ${variant.variantNumber},`);
        source.internalMain.push(`              absl::nullopt,`);
        source.internalMain.push(
          `              ${toCStringLiteral(variant.doc.text)},`,
        );
        source.internalMain.push("          },");
      }
      for (const variant of wrapperVariants) {
        const { variantName, variantNumber, valueTypeWithNamespace } = variant;
        source.internalMain.push("          {");
        source.internalMain.push(`              "${variantName}",`);
        source.internalMain.push(`              ${variantNumber},`);
        source.internalMain.push(
          `              skir_internal::GetType<${valueTypeWithNamespace}>(),`,
        );
        source.internalMain.push("          },");
      }
      source.internalMain.push("      },");
      const removedNumbers = record.record.removedNumbers.join(", ");
      source.internalMain.push(`      {${removedNumbers}},`);
      source.internalMain.push("  };");
      source.internalMain.push("  registry.push_back(std::move(record));");
      for (const variant of wrapperVariants) {
        const { valueTypeWithNamespace } = variant;
        source.internalMain.push(
          `  skir_internal::RegisterRecords<${
            valueTypeWithNamespace
          }>(registry);`,
        );
      }
      source.internalMain.push("}");
      source.internalMain.push("");
    }
  }

  private writeCodeInHeaderForAdapter(record: RecordLocation): void {
    const { header } = this;

    const { fields, recordType } = record.record;
    const className = getClassName(record);
    const adapterName = `${className}Adapter`;
    const qualifiedName = `::${this.namespace}::${className}`;

    header.internalMainTop.push(`class ${adapterName};`);
    header.internalMain.push(`class ${adapterName} {`);
    header.internalMain.push(" public:");
    header.internalMain.push(`  using type = ${qualifiedName};`);
    const tupleName =
      recordType === "struct" ? "fields_tuple" : "variants_tuple";
    if (fields.length || recordType === "enum") {
      const fieldToReflectionType = (f: Field): string => {
        const fieldName = f.name.text;
        if (recordType === "struct") {
          return `struct_field<type, skirout::get_${fieldName}<>>`;
        } else if (f.type) {
          return `enum_wrapper_variant<type, skirout::reflection::${fieldName}_variant>`;
        } else {
          return `skir::reflection::enum_const_variant<skirout::k_${fieldName.toLowerCase()}>`;
        }
      };
      const reflectionTypes = fields
        .map(fieldToReflectionType)
        .concat(
          recordType === "enum"
            ? ["skir::reflection::enum_const_variant<skirout::k_unknown>"]
            : [],
        )
        .join(",\n      ");
      header.internalMain.push(
        `  using ${tupleName} = std::tuple<\n      ${reflectionTypes}>;`,
      );
    } else {
      header.internalMain.push(`  using ${tupleName} = std::tuple<>;`);
    }
    header.internalMain.push("");
    header.internalMain.push("  static bool IsDefault(const type&);");
    header.internalMain.push("  static void Append(const type&, DenseJson&);");
    header.internalMain.push(
      "  static void Append(const type&, ReadableJson&);",
    );
    header.internalMain.push(
      "  static void Append(const type&, DebugString&);",
    );
    header.internalMain.push("  static void Append(const type&, ByteSink&);");
    header.internalMain.push("  static void Parse(JsonTokenizer&, type&);");
    header.internalMain.push("  static void Parse(ByteSource&, type&);");
    header.internalMain.push(
      "  static skir::reflection::Type GetType(skir_type<type>);",
    );
    header.internalMain.push("  static void RegisterRecords(");
    header.internalMain.push("      skir_type<type>,");
    header.internalMain.push("      skir::reflection::RecordRegistry&);");
    header.internalMain.push(
      `  static constexpr bool IsStruct() { return ${
        recordType === "struct"
      }; }`,
    );
    header.internalMain.push(
      `  static constexpr bool IsEnum() { return ${recordType === "enum"}; }`,
    );
    header.internalMain.push("};");
    header.internalMain.push("");
    header.internal.push(
      `inline ::skir_internal::${this.namespace}::${adapterName} GetAdapter(`,
    );
    header.internal.push(`    ::skir_internal::skir_type<${qualifiedName}>);`);
    header.internal.push("");
  }

  private writeCodeForConstantVariant(variant: EnumVariant): void {
    if (!this.addskiroutSymbol(variant.structType)) return;
    const { skirout } = this.header;
    skirout.push(`#ifndef skirout_${variant.structType}`);
    skirout.push(`#define skirout_${variant.structType}`);
    skirout.push(`struct ${variant.structType} {`);
    skirout.push(
      `  static constexpr absl::string_view kVariantName = "${variant.variantName}";`,
    );
    skirout.push("};");
    skirout.push("");
    skirout.push(
      `constexpr auto ${variant.identifier} = ${variant.structType}();`,
    );
    skirout.push("#endif");
    skirout.push("");
  }

  private writeCodeForWrapperVariant(variant: EnumVariant): void {
    const { variantName, structType } = variant;
    if (!this.addskiroutSymbol(structType)) return;
    const variantType = `${variantName}_variant`;
    {
      const { skirout } = this.header;
      skirout.push(`#ifndef skirout_${structType}`);
      skirout.push(`#define skirout_${structType}`);
      skirout.push("template <typename T>");
      skirout.push(`struct ${structType};`);
      skirout.push("");
      skirout.push("namespace reflection {");
      skirout.push(`struct ${variantType} {`);
      skirout.push(
        `  static constexpr absl::string_view kVariantName = "${variantName}";`,
      );
      skirout.push("");
      skirout.push("  template <typename T>");
      skirout.push(`  static ${structType}<T> wrap(T input) {`);
      skirout.push(`    return ${structType}(std::move(input));`);
      skirout.push("  }");
      skirout.push("");
      skirout.push("  template <typename Enum>");
      skirout.push("  static auto* get_or_null(Enum& e) {");
      skirout.push(
        `    return e.is_${variantName}() ? &e.as_${variantName}() : nullptr;`,
      );
      skirout.push("  }");
      skirout.push("};");
      skirout.push("}  // namespace reflection");
      skirout.push("");
      skirout.push("template <typename T>");
      skirout.push(`struct ${structType} {`);
      skirout.push("  using value_type = T;");
      skirout.push(
        `  using variant_type = ::skirout::reflection::${variantType};`,
      );
      skirout.push("");
      skirout.push("  T value{};");
      skirout.push("");
      skirout.push(`  ${structType}() = default;`);
      skirout.push(
        `  explicit ${structType}(T value): value(std::move(value)) {}`,
      );
      skirout.push("};");
      skirout.push("#endif");
      skirout.push("");
    }
    {
      const { skirout } = this.testingHeader;
      skirout.push(`#ifndef TESTING_skirout_${structType}`);
      skirout.push(`#define TESTING_skirout_${structType}`);
      skirout.push("template <typename ValueMatcher = decltype(_)>");
      const functionName = "Is" + convertCase(variantName, "UpperCamel");
      skirout.push(`auto ${functionName}(ValueMatcher matcher = _) {`);
      skirout.push("  using ::testing::skir_internal::EnumValueIsMatcher;");
      skirout.push(`  using Variant = ::skirout::reflection::${variantType};`);
      skirout.push(
        "  return EnumValueIsMatcher<Variant, ValueMatcher>(std::move(matcher));",
      );
      skirout.push("}");
      skirout.push("#endif");
      skirout.push("");
    }
  }

  private writeCodeForMethod(method: Method): void {
    const { typeSpeller } = this;
    const { mainMiddle } = this.header;
    const methodName = method.name.text;
    const requestType = typeSpeller.getCcType(method.requestType!);
    const responseType = typeSpeller.getCcType(method.responseType!);
    const doc = method.doc.text;
    mainMiddle.push(...commentify(docToCommentText(method.doc)));
    mainMiddle.push(`struct ${methodName} {`);
    mainMiddle.push(`  using request_type = ${requestType};`);
    mainMiddle.push(`  using response_type = ${responseType};`);
    mainMiddle.push(
      `  static constexpr absl::string_view kMethodName = "${methodName}";`,
    );
    mainMiddle.push(`  static constexpr uint32_t kNumber = ${method.number};`);
    mainMiddle.push(
      `  static constexpr absl::string_view kDoc = ${toCStringLiteral(doc)};`,
    );
    mainMiddle.push("};");
    mainMiddle.push("");
  }

  private writeCodeForConstant(constant: Constant): void {
    const { header, source, typeSpeller } = this;
    const name = `k_${constant.name.text.toLowerCase()}`;
    const type = typeSpeller.getCcType(constant.type!);
    const ccStringLiteral = toCStringLiteral(
      JSON.stringify(constant.valueAsDenseJson),
    );
    header.mainMiddle.push(...commentify(docToCommentText(constant.doc)));
    header.mainMiddle.push(`const ${type}& ${name}();`);
    header.mainMiddle.push("");
    source.mainMiddle.push(`const ${type}& ${name}() {`);
    source.mainMiddle.push(`  static const auto* kResult = new ${type}(`);
    source.mainMiddle.push(`      ::skir::Parse<${type}>(`);
    source.mainMiddle.push(`          ${ccStringLiteral})`);
    source.mainMiddle.push("          .value());");
    source.mainMiddle.push("  return *kResult;");
    source.mainMiddle.push("}");
    source.mainMiddle.push("");
  }

  private writeIncludes(): void {
    const { header, source, testingHeader } = this;
    {
      const headerPath =
        "skirout/" + this.inModule.path.replace(/\.skir$/, ".h");
      source.includes.push(`#include "${headerPath}"`);
      testingHeader.includes.push(`#include "${headerPath}"`);
    }
    for (const h of [...this.includes].sort()) {
      header.includes.push(`#include ${h}`);
      testingHeader.includes.push(
        `#include ${h.replace(/\.h"$/, '.testing.h"')}`,
      );
    }
  }

  private addskiroutSymbol(symbol: string): boolean {
    if (this.seenskiroutSymbols.has(symbol)) return false;
    this.seenskiroutSymbols.add(symbol);
    return true;
  }

  private readonly includes = new Set<string>();
  private readonly typeSpeller: TypeSpeller;
  private readonly reorderedRecords: readonly RecordLocation[];
  private readonly namespace: string;
  private readonly seenskiroutSymbols = new Set<string>();

  readonly header: FileContents = new FileContents(".h");
  readonly source: FileContents = new FileContents(".cc");
  readonly testingHeader: FileContents = new FileContents(".testing.h");
}

function commentify(
  textOrLines: string | readonly string[],
  indent: "" | "  " | "    " = "",
): readonly string[] {
  const text = (
    typeof textOrLines === "string" ? textOrLines : textOrLines.join("\n")
  )
    .replace(/^\s*\n+/g, "")
    .replace(/\n+\s*$/g, "")
    .replace(/\n{3,}/g, "\n\n");

  if (text.length <= 0) {
    return [];
  }

  return text.split("\n").map((line) => `${indent}// ${line}`);
}

function docToCommentText(doc: Doc): string {
  return doc.pieces
    .map((p) => {
      switch (p.kind) {
        case "text":
          return p.text;
        case "reference":
          return `'${p.referenceRange.text.slice(1, -1)}'`;
      }
    })
    .join("");
}

class FileContents {
  constructor(readonly extension: ".h" | ".cc" | ".testing.h") {}

  namespace: string = "";

  readonly includes: string[] = [];
  /** Group within the ::skirout namespace. */
  readonly skirout: string[] = [];
  /** First group within the ::skirout_my_module namespace. */
  readonly mainTop: string[] = [];
  /** Second group within the ::skirout_my_module namespace. */
  readonly mainMiddle: string[] = [];
  /** Third group within the ::skirout_my_module namespace. */
  readonly mainBottom: string[] = [];
  /** Group within the anonymous namespace. Only in the .cc. */
  readonly anonymous: string[] = [];
  /** Group within the ::skir_internal namespace. */
  readonly internal: string[] = [];
  /**
   * First group within the ::skir_internal_my_module namespace. Only in the
   * .h.
   */
  readonly internalMainTop: string[] = [];
  /** Group within the ::skir_internal::my::module namespace. */
  readonly internalMain: string[] = [];
}

function fileContentsToCode(fileContents: FileContents): string {
  const { extension, namespace } = fileContents;
  const lines = [
    "//  ______                        _               _  _  _",
    "//  |  _  \\                      | |             | |(_)| |",
    "//  | | | |  ___    _ __    ___  | |_    ___   __| | _ | |_",
    "//  | | | | / _ \\  | '_ \\  / _ \\ | __|  / _ \\ / _` || || __|",
    "//  | |/ / | (_) | | | | || (_) || |_  |  __/| (_| || || |_ ",
    "//  |___/   \\___/  |_| |_| \\___/  \\__|  \\___| \\__,_||_| \\__|",
    "//",
    "// Generated by skir_cc_gen",
    "// Home: https://github.com/gepheum/skir-cc-gen",
    "",
  ];
  if (extension === ".h" || extension === ".testing.h") {
    const includeGuard =
      `${namespace}${extension.replace(/\./g, "_")}`.toUpperCase();
    lines.push(`#ifndef ${includeGuard}`);
    lines.push(`#define ${includeGuard}`);
    lines.push("");
  }
  fileContents.includes.forEach((l) => lines.push(l));
  lines.push("");
  if (extension === ".h") {
    lines.push("namespace skir_internal {");
    lines.push(`namespace ${namespace} {`);
    fileContents.internalMainTop.forEach((l) => lines.push(l));
    lines.push(`}  // namespace ${namespace}`);
    lines.push("}  // namespace skir_internal");
    lines.push("");
  } else if (extension === ".cc") {
    lines.push("namespace {");
    lines.push("");
    fileContents.anonymous.forEach((l) => lines.push(l));
    lines.push("");
    lines.push("}  // namespace");
    lines.push("");
  }
  if (extension === ".testing.h") {
    lines.push("namespace testing {");
  }
  lines.push("namespace skirout {");
  fileContents.skirout.forEach((l) => lines.push(l));
  lines.push("}  // namespace skirout");
  if (extension === ".h" || extension === ".cc") {
    lines.push("");
    lines.push(`namespace ${namespace} {`);
    fileContents.mainTop.forEach((l) => lines.push(l));
    lines.push("");
    fileContents.mainMiddle.forEach((l) => lines.push(l));
    lines.push("");
    fileContents.mainBottom.forEach((l) => lines.push(l));
    lines.push("");
    lines.push(`}  // namespace ${namespace}`);
    lines.push("namespace skir_internal {");
    lines.push(`namespace ${namespace} {`);
    lines.push("");
    fileContents.internalMain.forEach((l) => lines.push(l));
    lines.push("");
    lines.push(`}  // namespace ${namespace}`);
    lines.push("");
    fileContents.internal.forEach((l) => lines.push(l));
    lines.push("");
    lines.push("}  // namespace skir_internal");
    lines.push("");
  } else {
    lines.push("}  // namespace testing");
    lines.push("");
  }
  if (extension === ".h" || extension === ".testing.h") {
    lines.push("#endif");
  }
  return (
    lines
      .map((l) => `${l}\n`)
      .join("")
      // Remove empty line following "public" or "private".
      .replace(/((public:|private:)\n)\n+/g, "$1")
      // Remove empty line preceding a closed curly bracket.
      .replace(/\n(\n *\})/g, "$1")
      // Coalesce consecutive empty lines.
      .replace(/\n\n\n+/g, "\n\n")
      .replace(/\n\n$/g, "\n")
  );
}

export const GENERATOR = new CcCodeGenerator();

function maybeEscapeLowerCaseName(name: string): string {
  return CC_KEYWORDS.has(name) ? `${name}_` : name;
}

function numberToCharLiterals(n: number): string {
  const decimal = `${n}`;
  let result = "";
  for (let i = 0; i < decimal.length; ++i) {
    if (i !== 0) {
      result += ", ";
    }
    result += `'${decimal[i]}'`;
  }
  return result;
}

function bytesToIntLiterals(bytes: readonly number[]): string {
  return bytes.map((b) => `${b}`).join(", ");
}

function getRecordId(record: RecordLocation): string {
  const qualifiedName = record.recordAncestors
    .map((r) => r.name.text)
    .join(".");
  return `${record.modulePath}:${qualifiedName}`;
}

function toCStringLiteral(input: string): string {
  // Mapping of special characters to their C++ escape sequences
  const escapeMap: Record<string, string> = {
    '"': '\\"',
    "\\": "\\\\",
    "\b": "\\b",
    "\f": "\\f",
    "\n": "\\n",
    "\r": "\\r",
    "\t": "\\t",
    "\v": "\\v",
  };
  const escaped = input.replace(
    /["\\\b\f\n\r\t\v]/g,
    (match) => escapeMap[match] ?? match,
  );
  return `"${escaped}"`;
}
