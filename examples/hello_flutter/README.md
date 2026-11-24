# Hello Flutter + Skir

A minimal Hello World example showing a Flutter mobile app communicating with a
Bun backend via [SkirRPC](https://skir.build).

```
skir-src/        # Skir schema definitions
backend/         # Bun + TypeScript HTTP server
frontend/        # Flutter mobile app
```

## Prerequisites

- [Bun](https://bun.sh) ≥ 1.0
- [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.0 (with Dart ≥ 3.0)

## Getting started

### 1. Generate code from the schema

```sh
bunx skir gen
```

This reads `skir.yml` and generates TypeScript into `backend/skirout/` and Dart
into `frontend/lib/skirout/`. Re-run whenever you change a `.skir` file.

### 2. Start the backend

```sh
cd backend
bun install
bun run start
```

The server listens on <http://localhost:8080>. Open
<http://localhost:8080/api?studio> in your browser to explore the API
interactively with the Skir Studio.

### 3. Run the Flutter app

```sh
cd frontend
flutter pub get
flutter run
```

> **Android emulator**: the app connects to `http://localhost:8080/api` by
> default, which works for iOS simulators. For Android emulators, replace
> `localhost` with `10.0.2.2` in `frontend/lib/main.dart`.

## Pre-commit hook

To install a Git pre-commit hook that runs codegen, linting, and type-checking
automatically before every commit:

```sh
bash pre_commit_setup.sh
```

To run the checks manually:

```sh
bash pre_commit.sh
```

## Project layout

| Path | Description |
|---|---|
| `skir-src/greet.skir` | Skir schema — defines the `Greet` RPC method |
| `skir.yml` | Skir codegen configuration |
| `backend/src/server.ts` | Bun HTTP server exposing the `Greet` method |
| `frontend/lib/main.dart` | Flutter UI that calls `Greet` and displays the response |
| `pre_commit.sh` | Linting / type-checking script |
| `pre_commit_setup.sh` | Installs `pre_commit.sh` as a Git pre-commit hook |
