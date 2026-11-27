# Skir F# example

Example showing how to use Skir's [F# code generator](https://skir.build/docs/fsharp) in a .NET 10 F# project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-fsharp-example.git

cd skir-fsharp-example

# Run Skir-to-F# codegen
npx skir gen

# Build and run snippets
dotnet run --project FsharpExample.fsproj
```

### Start a SkirRPC service

From one process, run:
```shell
dotnet run --project FsharpExample.fsproj -- start-service
```

From another process, run:
```shell
dotnet run --project FsharpExample.fsproj -- call-service
```
