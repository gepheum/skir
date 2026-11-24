export function snake(value: string): string {
  return value
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/[-.]+/g, "_")
    .toLowerCase();
}

export function pascal(value: string): string {
  const result = snake(value)
    .split("_")
    .filter(Boolean)
    .map((s) => s[0]!.toUpperCase() + s.slice(1))
    .join("");
  if (!/^[A-Z][A-Za-z0-9]*$/.test(result))
    throw new Error(`Invalid module component: ${value}`);
  return result;
}

export function identifier(value: string): string {
  const name = snake(value);
  if (!/^[a-z_][a-z0-9_]*$/.test(name))
    throw new Error(`Invalid identifier: ${value}`);
  return name;
}

export function string(value: string): string {
  // JSON escaping is almost Elixir escaping, except Elixir interpolates #{...}.
  return JSON.stringify(value).replace(/#\{/g, "\\#{");
}

export function atom(value: string): string {
  return /^[a-z_][a-z0-9_]*$/.test(value) ? `:${value}` : `:${string(value)}`;
}

export interface ModuleInfo {
  readonly name: string;
  readonly path: string;
}

export function moduleInfo(path: string, namespace: string): ModuleInfo {
  if (
    typeof path !== "string" ||
    !path.endsWith(".skir") ||
    path.startsWith("/") ||
    path.includes("\\")
  ) {
    throw new Error(`Invalid schema path: ${path}`);
  }
  const external = path.startsWith("@");
  if (external && !/^@[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\/.+\.skir$/.test(path)) {
    throw new Error(`Invalid schema path: ${path}`);
  }
  const parts = path.replace(/^@/, "external/").slice(0, -5).split("/");
  if (
    parts.some(
      (p) => !p || p === "." || p === ".." || !/^[A-Za-z0-9_.-]+$/.test(p),
    )
  ) {
    throw new Error(`Invalid schema path: ${path}`);
  }
  const names = parts.map((part, index) =>
    pascal(
      external && index < 3 && /^[_.-]*(?:\d|$)/.test(part) ? `n${part}` : part,
    ),
  );
  names[names.length - 1] += "Skir";
  const paths = parts.map(snake);
  paths[paths.length - 1] += "_skir.ex";
  return { name: `${namespace}.${names.join(".")}`, path: paths.join("/") };
}

export function literal(value: unknown): string {
  if (value === null) return "nil";
  if (typeof value === "boolean") return String(value);
  if (typeof value === "string") return string(value);
  if (typeof value === "number" && Number.isFinite(value)) {
    if (Object.is(value, -0)) return "-0.0";
    if (Number.isInteger(value)) return BigInt(value).toString();
    return String(value).replace(/^(-?\d+)e/, "$1.0e");
  }
  if (Array.isArray(value)) return `[${value.map(literal).join(", ")}]`;
  throw new Error("Invalid compiler dense-JSON constant");
}
