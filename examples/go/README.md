# Skir Go example

Example showing how to use skir's [Go code generator](https://github.com/gepheum/skir-go-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-go-example.git

cd skir-go-example

# Run Skir-to-Go codegen
npx skir gen

go run .
```

### Start a SkirRPC service

From one process, run:
```shell
npx skir gen  # if you haven't already
go run ./cmd/start-service
```

From another process, run:
```shell
go run ./cmd/call-service
```
# skir-go-example
