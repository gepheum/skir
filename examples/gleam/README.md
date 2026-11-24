# Skir Gleam Example

Example showing how to use Skir's Gleam code generator in a project.

## Build and run the example

```shell
# Run Skir-to-Gleam codegen
npx skir gen

# Run snippets showing generated types and serializers
gleam run -m snippets
```

### Start a SkirRPC service

From one process, run:

```shell
gleam run -m start_service
```

From another process, run:

```shell
gleam run -m call_service
```
