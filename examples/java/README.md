# Skir Java example

Example showing how to use skir's [Java code generator](https://skir.build/docs/java) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-java-example.git

cd skir-java-example

# Run Skir-to-Java codegen
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
npm run run:call-service
```
