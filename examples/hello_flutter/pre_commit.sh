#!/bin/bash
set -e

# Run Skir codegen to keep generated files up to date
bunx skir gen

# ─── Backend ────────────────────────────────────────────────────────────────
cd backend
bun install
bun run lint:fix
bun run lint
bun run format
bun run typecheck
cd ..

# ─── Frontend ───────────────────────────────────────────────────────────────
cd frontend
dart pub get
dart format lib/*.dart
dart analyze
cd ..
