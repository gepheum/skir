<div align="center">
  <h1>Skir</h1>
  <p><strong>Like Protocol Buffer, but better.</strong></p>

  [![npm](https://img.shields.io/npm/v/skir?style=flat-square)](https://www.npmjs.com/package/skir)
  [![build](https://github.com/gepheum/skir/workflows/Build/badge.svg?style=flat-square)](https://github.com/gepheum/skir/actions)
</div>

<br />

**Skir** is a universal language for representing data types, constants, and RPC interfaces. Define your schema once in a `.skir` file and generate idiomatic, type-safe code for TypeScript, Python, Java, C++, and more.

## ✨ Features

- 🧙‍♂️ **End-to-end type safety** - Share types between your backend, frontend, and microservices without manual sync.
- 📦 **Universal serialization** - Zero-config serialization to JSON for debuggability or compact binary for performance.
- 🚀 **Idiomatic code gen** - Generates code that feels native to each language.
- 🔄 **Schema evolution** - Safe, backward-compatible schema changes with built-in compatibility checks.
- 🔌 **RPC definitions** - Define service interfaces and methods alongside your data.
- 🌍 **Multi-language** - First-class support for TS, Python, C++, Java, Kotlin, and Dart.

## ⚡ Quick example

Skir uses a clean, intuitive syntax to define your data structures.

```d
// shapes.skir

struct Point {
  x: int32;
  y: int32;
  label: string;
}

struct Shape {
  points: [Point];
  /// A short string describing this shape.
  label: string;
}

const TOP_RIGHT_CORNER: Point = {
  x = 600,
  y = 400,
  label = "top-right corner",
};

/// Returns true if no part of the shape's boundary curves inward.
method IsConvex(Shape): bool = 12345;
```

The compiler transforms this into type-safe code for your project:

```python
# my_project.py
from skirout.shapes_skir import Point

point = Point(x=3, y=4, label="P")

# Automatic serialization to JSON/Binary
json_data = Point.serializer.to_json(point)
restored = Point.serializer.from_json(json_data)

assert(restored == point)
```

## ❓ Why Skir?

Skir solves one of software engineering's thorniest problems: **keeping data contracts in sync**.

Instead of manually keeping TypeScript interfaces, Python classes, and SQL schemas in sync, Skir gives you a **Single source of truth**. This eliminates entire classes of runtime bugs:
*   No more mismatched request/response shapes.
*   No more surprises when deserializing data from older versions.
*   No more manual glue code.

## 📦 Supported languages

| Language | Documentation | Example |
| :--- | :--- | :--- |
| 🟦 **TypeScript** | [Documentation](https://github.com/gepheum/skir-typescript-gen) | [Example](https://github.com/gepheum/skir-typescript-example) |
| 🐍 **Python** | [Documentation](https://github.com/gepheum/skir-python-gen) | [Example](https://github.com/gepheum/skir-python-example) |
| ⚡ **C++** | [Documentation](https://github.com/gepheum/skir-cc-gen) | [Example](https://github.com/gepheum/skir-cc-example) |
| ☕ **Java** | [Documentation](https://github.com/gepheum/skir-java-gen) | [Example](https://github.com/gepheum/skir-java-example) |
| 💜 **Kotlin** | [Documentation](https://github.com/gepheum/skir-kotlin-gen) | [Example](https://github.com/gepheum/skir-kotlin-example) |
| 🎯 **Dart** | [Documentation](https://github.com/gepheum/skir-dart-gen) | [Example](https://github.com/gepheum/skir-dart-example) |

## 📚 Documentation

- [Getting started: setup & workflow](docs/setup.md)
- [Language reference](docs/language-reference.md)
- [Serialization formats](docs/serialization.md)
- [Schema evolution & compatibility](docs/compatibility.md)
- [Typesafe RPC interfaces](docs/services.md)
- [External dependencies](docs/dependencies.md)
- [Comparisons](docs/comparisons.md)
