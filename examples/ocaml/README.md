# Skir OCaml example

Example showing how to use Skir's [OCaml code generator](https://skir.build/docs/ocaml) in a Dune project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-ocaml-example.git

cd skir-ocaml-example

# Install the Skir OCaml client library via opam
opam pin add skir_client https://github.com/gepheum/skir-ocaml-client.git -y

# Run Skir-to-OCaml codegen
npx skir gen

# Build and run snippets
dune exec ./snippets.exe
```

### Start a SkirRPC service

From one process, run:
```shell
dune exec ./start_service.exe
```

From another process, run:
```shell
dune exec ./call_service.exe
```
