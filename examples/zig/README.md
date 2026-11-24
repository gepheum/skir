# Skir Zig example

Example showing how to use skir's [Zig code generator](https://github.com/gepheum/skir-zig-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-zig-example.git

cd skir-zig-example

# Run Skir-to-Zig codegen
npx skir gen

zig build run
```

### Start a SkirRPC service

From one process, run:

```shell
zig build run-start-service
```

From another process, run:

```shell
zig build run-call-service
```
