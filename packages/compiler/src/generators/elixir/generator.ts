import type {
  CodeGenerator,
  Field,
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import {
  atom,
  identifier,
  literal,
  moduleInfo,
  type ModuleInfo,
  pascal,
  string,
} from "./naming.js";

const PRIMITIVES = new Set([
  "bool",
  "int32",
  "int64",
  "hash64",
  "float32",
  "float64",
  "timestamp",
  "string",
  "bytes",
]);
const INTERNAL_FIELDS = new Set(["__struct__", "__skir_unknown_fields__"]);
const NAMESPACE = /^[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/;

export interface ElixirConfig {
  readonly namespace?: string | undefined;
}

interface ElixirRecordLocation extends RecordLocation {
  readonly elixirName: string;
}

export function generateCode(
  input: CodeGenerator.Input<ElixirConfig>,
): CodeGenerator.Output {
  const config = input.config ?? {};
  for (const key of Object.keys(config)) {
    if (key !== "namespace")
      throw new Error(`Unknown generator config: ${key}`);
  }
  const namespace = config.namespace ?? "Skir.Generated";
  if (typeof namespace !== "string" || !NAMESPACE.test(namespace))
    throw new Error("Invalid Elixir namespace");
  if (!(input.recordMap instanceof Map))
    throw new Error("Expected a resolved recordMap");
  const modules = [...input.modules].sort((a, b) =>
    a.path < b.path ? -1 : a.path > b.path ? 1 : 0,
  );
  const locations = new Map<RecordKey, ElixirRecordLocation>();
  const moduleNames = new Map<string, ModuleInfo>();
  const paths = new Set<string>();
  const names = new Set<string>();
  for (const mod of modules) {
    const info = moduleInfo(mod.path, namespace);
    claim(paths, info.path, "output path");
    claim(names, info.name, "module");
    moduleNames.set(mod.path, info);
    for (const loc of mod.records) {
      if (loc.modulePath !== mod.path)
        throw new Error(`Record/module path mismatch: ${loc.record.key}`);
      if (!loc.recordAncestors.length)
        throw new Error("Record ancestor chain is empty");
      const name = `${info.name}.${loc.recordAncestors.map((r) => pascal(r.name.text)).join(".")}`;
      claim(names, name, "module");
      if (locations.has(loc.record.key))
        throw new Error(`Duplicate record key: ${loc.record.key}`);
      locations.set(loc.record.key, { ...loc, elixirName: name });
    }
  }
  const lookup = (key: RecordKey): ElixirRecordLocation => {
    const loc = locations.get(key);
    if (!loc || !input.recordMap.has(key))
      throw new Error(`Unresolved or missing record: ${key}`);
    return loc;
  };
  const type = (t: ResolvedType | undefined): string => {
    if (!t) throw new Error("Unresolved field or declaration type");
    switch (t.kind) {
      case "primitive":
        if (!PRIMITIVES.has(t.primitive))
          throw new Error(`Unsupported primitive: ${t.primitive}`);
        return `:${t.primitive}`;
      case "record":
        return `{:record, ${lookup(t.key).elixirName}}`;
      case "optional":
        return `{:optional, ${type(t.other)}}`;
      case "array": {
        const keyExtractor =
          t.key?.path?.map((p) => p.name.text).join(".") || "";
        return keyExtractor
          ? `{:array, ${type(t.item)}, ${string(keyExtractor)}}`
          : `{:array, ${type(t.item)}}`;
      }
      default: {
        const _exhaustive: never = t;
        throw new Error(
          `Unsupported resolved type kind: ${(_exhaustive as { kind: string }).kind}`,
        );
      }
    }
  };
  const spec = (t: ResolvedType | undefined): string => {
    type(t); // Validate every referenced type even when spelling a simple spec.
    if (!t) throw new Error("Cannot spell type");
    switch (t.kind) {
      case "primitive":
        switch (t.primitive) {
          case "bool":
            return "boolean()";
          case "int32":
          case "int64":
          case "hash64":
          case "timestamp":
            return "integer()";
          case "float32":
          case "float64":
            return "Skir.float_value()";
          case "string":
            return "String.t()";
          case "bytes":
            return "binary()";
        }
        break;
      case "array":
        return `[${spec(t.item)}]`;
      case "optional":
        return `nil | ${spec(t.other)}`;
      case "record": {
        const loc = lookup(t.key);
        return loc.record.recordType === "enum"
          ? `${loc.elixirName}.t()`
          : `${loc.elixirName}.t() | :skir_default`;
      }
    }
    throw new Error("Cannot spell type");
  };
  let defaultBudget = 0;
  const defaultExpr = (
    t: ResolvedType | undefined,
    seen: ReadonlySet<RecordKey>,
  ): string => {
    if (++defaultBudget > 100000)
      throw new Error(
        "Expanded defaults are too large; introduce optional fields to bound the schema",
      );
    type(t);
    if (!t) throw new Error("Unresolved field or declaration type");
    switch (t.kind) {
      case "optional":
        return "nil";
      case "array":
        return "[]";
      case "primitive":
        switch (t.primitive) {
          case "bool":
            return "false";
          case "string":
            return '""';
          case "bytes":
            return "<<>>";
          case "float32":
          case "float64":
            return "0.0";
          default:
            return "0";
        }
      case "record": {
        const loc = lookup(t.key);
        if (loc.record.recordType === "enum") return ":unknown";
        if (seen.has(t.key)) return ":skir_default";
        const next = new Set(seen);
        next.add(t.key);
        const fields = orderedFields(loc).map(
          (f) =>
            `${atom(identifier(f.name.text))} => ${defaultExpr(f.type, next)}`,
        );
        return `%{${[`:__struct__ => ${loc.elixirName}`, ...fields, ":__skir_unknown_fields__ => %{}"].join(", ")}}`;
      }
    }
  };

  function orderedFields(loc: ElixirRecordLocation): Field[] {
    return [...loc.record.fields].sort((a, b) => a.number - b.number);
  }
  function validateRecord(loc: ElixirRecordLocation): void {
    const r = loc.record;
    if (!["struct", "enum"].includes(r.recordType))
      throw new Error(`Unknown record kind: ${r.recordType}`);
    const fieldNames = new Set<string>();
    const fieldNumbers = new Set<number>();
    for (const f of r.fields) {
      const n = identifier(f.name.text);
      if (
        INTERNAL_FIELDS.has(n) ||
        (r.recordType === "enum" && n === "unknown")
      )
        throw new Error(`Reserved name: ${n}`);
      claim(fieldNames, n, "field name");
      if (
        !Number.isSafeInteger(f.number) ||
        f.number < (r.recordType === "enum" ? 1 : 0) ||
        f.number > 0x7fffffff
      ) {
        throw new Error(`Invalid field number: ${f.number}`);
      }
      claim(fieldNumbers, f.number, "field number");
      if (f.type) type(f.type);
      else if (r.recordType === "struct")
        throw new Error(`Unresolved field type: ${r.key}.${f.name.text}`);
    }
    const removed = new Set<number>();
    for (const number of r.removedNumbers) {
      if (
        !Number.isSafeInteger(number) ||
        number < (r.recordType === "enum" ? 1 : 0) ||
        number > 0x7fffffff ||
        fieldNumbers.has(number)
      ) {
        throw new Error(`Invalid removed field number: ${number}`);
      }
      claim(removed, number, "removed field number");
    }
    const expectedSlots =
      r.recordType === "struct"
        ? Math.max(-1, ...fieldNumbers, ...removed) + 1
        : 0;
    if (r.numSlotsInclRemovedNumbers !== expectedSlots)
      throw new Error(`Invalid slot count for ${r.key}`);
  }
  for (const loc of locations.values()) validateRecord(loc);

  function recordCode(loc: ElixirRecordLocation): string {
    const r = loc.record;
    const fields = orderedFields(loc);
    const lines = [
      `defmodule ${loc.elixirName} do`,
      `  @moduledoc ${string(r.doc?.text || `Generated from ${loc.modulePath}:${r.name.text}`)}`,
    ];
    if (r.recordType === "struct") {
      const defs = fields.map((f) => {
        defaultBudget = 0;
        return `{${atom(identifier(f.name.text))}, ${defaultExpr(f.type, new Set([r.key]))}}`;
      });
      lines.push(
        `  defstruct [${[...defs, "{:__skir_unknown_fields__, %{}}"].join(", ")}]`,
      );
      lines.push(
        `  @type t :: %__MODULE__{${[...fields.map((f) => `${atom(identifier(f.name.text))} => (${spec(f.type)})`), ":__skir_unknown_fields__ => map()"].join(", ")}}`,
      );
      lines.push(
        "  @spec new(map() | keyword()) :: t()",
        "  def new(attrs \\\\ %{}), do: struct!(__MODULE__, attrs)",
        "  @spec default() :: t()",
        "  def default(), do: %__MODULE__{}",
      );
    } else {
      const variants = fields.map((f) =>
        f.type
          ? `{${atom(identifier(f.name.text))}, (${spec(f.type)})}`
          : atom(identifier(f.name.text)),
      );
      lines.push(
        `  @type t :: ${[":unknown", "{:unknown, Skir.Unknown.t()}", ...variants].join(" | ")}`,
      );
      lines.push("  @spec default() :: t()", "  def default(), do: :unknown");
    }
    const reflectionId = `${loc.modulePath}:${loc.recordAncestors.map((r) => r.name.text).join(".")}`;
    lines.push(
      "  @doc false",
      "  def schema() do",
      `    %{kind: :${r.recordType}, module: __MODULE__, key: ${string(reflectionId)}, doc: ${string(r.doc?.text || "")},`,
    );
    lines.push(
      `      slots: ${r.numSlotsInclRemovedNumbers}, removed: ${literal([...r.removedNumbers].sort((a, b) => a - b))},`,
    );
    const entries = fields.map((f) => {
      const path =
        f.type?.kind === "array" && f.type.key
          ? f.type.key.path.map((p) => atom(identifier(p.name.text))).join(", ")
          : "";
      return `%{name: ${atom(identifier(f.name.text))}, json_name: ${string(f.name.text)}, number: ${f.number}, doc: ${string(f.doc?.text || "")}, type: ${f.type ? type(f.type) : "nil"}, key_path: [${path}]}`;
    });
    lines.push(`      fields: [${entries.join(",\n        ")}]}`, "  end");
    lines.push(
      "  @spec type() :: Skir.type()",
      "  def type(), do: {:record, __MODULE__}",
    );
    for (const name of [
      "to_json",
      "from_json",
      "encode_json",
      "decode_json",
      "encode",
      "decode",
    ]) {
      for (const bang of ["", "!"]) {
        const returnType = bang
          ? name.startsWith("encode")
            ? "binary()"
            : "term()"
          : "{:ok, term()} | {:error, Skir.Error.t()}";
        lines.push(
          `  @spec ${name}${bang}(term(), keyword()) :: ${returnType}`,
          `  def ${name}${bang}(value, opts \\\\ []), do: Skir.${name}${bang}(type(), value, opts)`,
        );
      }
    }
    for (const f of fields) {
      if (f.type?.kind !== "array" || !f.type.key) continue;
      const name = identifier(f.name.text);
      const path = f.type.key.path
        .map((p) => atom(identifier(p.name.text)))
        .join(", ");
      lines.push(
        `  @doc "Build an index for ${name}; duplicate keys raise ArgumentError."`,
        `  def index_${name}(value), do: Skir.index_by(Map.fetch!(value, ${atom(name)}), [${path}])`,
      );
    }
    lines.push("end", "");
    return lines.join("\n");
  }
  function moduleCode(mod: Module, info: ModuleInfo): string {
    const lines = ["# Generated by skir-elixir-gen. DO NOT EDIT.", ""];
    for (const loc of [...mod.records].sort((a, b) =>
      lookup(a.record.key).elixirName.localeCompare(
        lookup(b.record.key).elixirName,
        "en",
      ),
    )) {
      lines.push(recordCode(lookup(loc.record.key)));
    }
    lines.push(
      `defmodule ${info.name} do`,
      '  @moduledoc "Constants and method descriptors for this Skir source file."',
    );
    const functions = new Set<string>();
    for (const c of mod.constants) {
      if (!c.type || c.valueAsDenseJson === undefined)
        throw new Error(`Unresolved constant: ${c.name.text}`);
      const n = `${identifier(c.name.text)}_const`;
      claim(functions, n, "function name");
      lines.push(
        `  @doc ${string(c.doc?.text || c.name.text)}`,
        `  @spec ${n}() :: ${spec(c.type)}`,
        `  def ${n}(), do: Skir.from_json!(${type(c.type)}, ${literal(c.valueAsDenseJson)})`,
      );
    }
    const methodFns: string[] = [];
    for (const m of mod.methods) {
      const base = identifier(m.name.text);
      const n = `${base}_method`;
      claim(functions, n, "function name");
      const add = `add_${base}`;
      claim(functions, add, "function name");
      const handlerType = `${base}_handler`;
      claim(functions, base, "function name");
      if (
        !Number.isSafeInteger(m.number) ||
        m.number < 0 ||
        m.number > 0xffffffff
      )
        throw new Error(`Invalid method number: ${m.number}`);
      methodFns.push(n);
      lines.push(
        `  @doc ${string(m.doc?.text || m.name.text)}`,
        `  @spec ${n}() :: Skir.Method.t()`,
        `  def ${n}(), do: %Skir.Method{name: ${string(m.name.text)}, number: ${m.number}, doc: ${string(m.doc?.text || "")}, request: ${type(m.requestType)}, response: ${type(m.responseType)}}`,
        `  @doc "Register a handler for ${m.name.text} on a Skir.RPC.Service."`,
        `  @type ${handlerType} :: (${spec(m.requestType)}, term() -> {:ok, ${spec(m.responseType)}} | {:error, Skir.RPC.ServiceError.t() | Skir.RPC.UnknownError.t()})`,
        `  @spec ${add}(Skir.RPC.Service.t(), ${handlerType}()) :: Skir.RPC.Service.t()`,
        `  def ${add}(service, handler), do: Skir.RPC.Service.add_method(service, ${n}(), handler)`,
        `  @doc "Invoke ${m.name.text} through a Skir.RPC.ServiceClient."`,
        `  @spec ${base}(Skir.RPC.ServiceClient.t(), ${spec(m.requestType)}, keyword()) :: {:ok, ${spec(m.responseType)}} | {:error, Skir.RPC.RpcError.t()}`,
        `  def ${base}(client, request, opts \\\\ []), do: Skir.RPC.ServiceClient.invoke(client, ${n}(), request, opts)`,
        `  @doc "Invoke ${m.name.text}; raise Skir.RPC.RpcError on failure."`,
        `  @spec ${base}!(Skir.RPC.ServiceClient.t(), ${spec(m.requestType)}, keyword()) :: ${spec(m.responseType)}`,
        `  def ${base}!(client, request, opts \\\\ []), do: Skir.RPC.ServiceClient.invoke!(client, ${n}(), request, opts)`,
      );
    }
    if (methodFns.length) {
      claim(functions, "methods", "function name");
      lines.push(
        '  @doc "All SkirRPC methods declared in this source file."',
        "  @spec methods() :: [Skir.Method.t()]",
        `  def methods(), do: [${methodFns.map((n) => `${n}()`).join(", ")}]`,
      );
    }
    lines.push("end", "");
    return lines.join("\n");
  }
  return {
    files: modules
      .filter((m) => m.records.length || m.constants.length || m.methods.length)
      .map((m) => ({
        path: moduleNames.get(m.path)!.path,
        code: moduleCode(m, moduleNames.get(m.path)!),
      })),
  };
}

function claim<T>(set: Set<T>, value: T, kind: string): void {
  if (set.has(value)) throw new Error(`${kind} collision: ${String(value)}`);
  set.add(value);
}
