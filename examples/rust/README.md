# Skir Rust example

Example showing how to use skir's [Rust code generator](https://github.com/gepheum/skir-rust-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-rust-example.git

cd skir-rust-example

# Run Skir-to-Rust codegen
npx skir gen

cargo run --bin snippets
```

### Start a SkirRPC service

From one process, run:
```shell
npx skir gen  # if you haven't already
cargo run --bin start-service
```

From another process, run:
```shell
cargo run --bin call-service
```
