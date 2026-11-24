# Skir Dart example

Example showing how to use skir's [Dart code generator](https://github.com/gepheum/skir-dart-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-dart-example.git

cd skir-dart-example

# Retrieve dependencies
dart pub get

# Run Skir-to-Dart code generation
npx skir gen

dart run bin/snippets.dart
```

### Start a SkirRPC service

From one process, run:
```shell
dart run bin/start_service.dart
```

From another process, run:
```shell
dart run bin/call_service.dart
```
