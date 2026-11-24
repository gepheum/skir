import { json } from "@codemirror/lang-json";
import { EditorState } from "@codemirror/state";
import { minimalSetup } from "codemirror";
import { Json, parseTypeDescriptorFromJson, TypeDescriptor } from "skir-client";
import { createEditorState, TypeDefinition } from "skir-codemirror-plugin";
import { whiteEditorTheme, whiteEditorThemeExtension } from "./editor-theme";

export interface InputValue {
  readonly text: string;
  readonly parsed:
    | {
        readonly kind: "not-set";
      }
    | {
        readonly kind: "json";
        readonly value: Json;
      }
    | {
        readonly kind: "bytes";
        readonly value: ArrayBuffer;
      }
    | {
        readonly kind: "parse-error";
        readonly error: string;
      };
}

export interface InputSchema {
  readonly text: string;
  readonly typeDescriptor:
    | {
        readonly kind: "ok";
        readonly value: TypeDescriptor;
      }
    | {
        readonly kind: "not-set";
      }
    | {
        readonly kind: "error";
        readonly error: string;
      };
}

export interface Result {
  readonly kind: "ok";
  readonly readableJsonEditorState: EditorState;
  readonly denseJsonEditorState: EditorState;
  readonly base16EditorState: EditorState;
  readonly base64EditorState: EditorState;
}

export type ResultOrError =
  | {
      readonly kind: "schema-not-set";
    }
  | {
      readonly kind: "schema-error";
      readonly error: string;
    }
  | {
      readonly kind: "value-not-set";
    }
  | {
      readonly kind: "value-parse-error";
      readonly error: string;
    }
  | {
      readonly kind: "schema-value-match-error";
      readonly error: string;
    }
  | Result;

export interface AppState {
  readonly input: InputValue;
  readonly schema: InputSchema;
  readonly result: ResultOrError;
}

export function updateAppState(
  valueText: string,
  schemaText: string,
  previousState: AppState,
): AppState {
  const inputValue =
    valueText === previousState.input.text
      ? previousState.input
      : makeInputValue(valueText);
  const inputSchema =
    schemaText === previousState.schema.text
      ? previousState.schema
      : makeInputSchema(schemaText);
  return inputValue === previousState.input &&
    inputSchema === previousState.schema
    ? previousState
    : {
        input: inputValue,
        schema: inputSchema,
        result: computeResult(inputValue, inputSchema),
      };
}

export function makeZeroState(): AppState {
  const inputValue = makeInputValue("");
  const inputSchema = makeInputSchema("");
  return {
    input: inputValue,
    schema: inputSchema,
    result: computeResult(inputValue, inputSchema),
  };
}

function makeInputValue(text: string): InputValue {
  if (text === "") {
    return { text, parsed: { kind: "not-set" } };
  }
  let format: "json" | "base16" | "base64";
  // The binary representation of a Skir value always starts with "skir" so we
  // can check for this prefix in base16 and base64.
  if (/^736[Bb]6972/.test(text)) {
    format = "base16";
  } else if (text.startsWith("c2tpc")) {
    format = "base64";
  } else {
    format = "json";
  }
  let parsed: InputValue["parsed"];
  try {
    if (format === "json") {
      const value = JSON.parse(text);
      parsed = { kind: "json", value };
    } else if (format === "base16") {
      const bytes = new Uint8Array(
        text.match(/.{1,2}/g)?.map((byte) => parseInt(byte, 16)) ?? [],
      );
      parsed = { kind: "bytes", value: bytes.buffer };
    } else if (format === "base64") {
      const binaryString = atob(text);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      parsed = { kind: "bytes", value: bytes.buffer };
    } else {
      parsed = { kind: "not-set" };
    }
  } catch (e) {
    parsed = {
      kind: "parse-error",
      error: String(e),
    };
  }
  return { text, parsed };
}

function makeInputSchema(text: string): InputSchema {
  if (text === "") {
    return { text, typeDescriptor: { kind: "not-set" } };
  }
  try {
    const value = JSON.parse(text);
    const typeDescriptor = parseTypeDescriptorFromJson(value);
    return { text, typeDescriptor: { kind: "ok", value: typeDescriptor } };
  } catch (e) {
    return {
      text,
      typeDescriptor: {
        kind: "error",
        error: String(e),
      },
    };
  }
}

function computeResult(input: InputValue, schema: InputSchema): ResultOrError {
  const { typeDescriptor } = schema;
  if (typeDescriptor.kind === "not-set") {
    return { kind: "schema-not-set" };
  } else if (typeDescriptor.kind === "error") {
    return { kind: "schema-error", error: typeDescriptor.error };
  }

  if (input.parsed.kind === "not-set") {
    return { kind: "value-not-set" };
  } else if (input.parsed.kind === "parse-error") {
    return { kind: "value-parse-error", error: input.parsed.error };
  }

  let denseJson: Json;
  let readableJson: Json;
  let bytes: ArrayBuffer;
  try {
    denseJson = typeDescriptor.value.transform(input.parsed.value, "dense");
    readableJson = typeDescriptor.value.transform(
      input.parsed.value,
      "readable",
    );
    if (input.parsed.kind === "json") {
      bytes = typeDescriptor.value.transform(input.parsed.value, "bytes");
    } else {
      bytes = input.parsed.value;
    }
  } catch (e) {
    return { kind: "schema-value-match-error", error: String(e) };
  }

  return {
    kind: "ok",
    readableJsonEditorState: createEditorState({
      json: readableJson,
      schema: typeDescriptor.value.asJson() as TypeDefinition,
      readOnly: true,
      theme: whiteEditorTheme,
    }),
    denseJsonEditorState: EditorState.create({
      doc: JSON.stringify(denseJson),
      extensions: [minimalSetup, whiteEditorThemeExtension, json()],
    }),
    base16EditorState: EditorState.create({
      doc: Array.from(new Uint8Array(bytes))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join(""),
      extensions: [minimalSetup, whiteEditorThemeExtension],
    }),
    base64EditorState: EditorState.create({
      doc: btoa(String.fromCharCode(...new Uint8Array(bytes))),
      extensions: [minimalSetup, whiteEditorThemeExtension],
    }),
  };
}
