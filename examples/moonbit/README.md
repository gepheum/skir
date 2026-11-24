# Skir MoonBit example

Example showing how to use skir's [MoonBit code generator](https://github.com/gepheum/skir-moonbit-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-moonbit-example.git

cd skir-moonbit-example

# Run Skir-to-MoonBit codegen
npx skir gen

# Run snippet checks
moon test src --target native --filter snippets
```

### Start a SkirRPC service

From one process, run:

```shell
moon run src --target native
```

From another process, run:

```shell
moon test src --target native --filter "call service"
```
