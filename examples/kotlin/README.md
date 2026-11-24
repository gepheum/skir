# Skir Kotlin example

Example showing how to use skir's [Kotlin code generator](https://github.com/gepheum/skir-kotlin-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-kotlin-example.git

cd skir-kotlin-example

# Run Skir-to-Kotlin codegen
npx skir gen

./gradlew build
./gradlew run
```

### Start a SkirRPC service

From one process, run:
```shell
./gradlew run -PmainClass=examples.startservice.StartServiceKt
```

From another process, run:
```shell
./gradlew run -PmainClass=examples.callservice.CallServiceKt
```
