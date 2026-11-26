# Skir Scala example

Example showing how to use skir's [Scala code generator](https://skir.build/docs/scala) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-scala-example.git

cd skir-scala-example

# Run Skir-to-Scala codegen
npx skir gen

./gradlew build
./gradlew run
```

### Start a SkirRPC service

From one process, run:
```shell
./gradlew run -PmainClass=examples.StartService
```

From another process, run:
```shell
./gradlew run -PmainClass=examples.CallService
```
