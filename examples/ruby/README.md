# Skir Ruby example

Example showing how to use skir's [Ruby code generator](https://skir.build/docs/ruby) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-ruby-example.git

cd skir-ruby-example

# Install dependencies
bundle install

# Run Skir-to-Ruby codegen
npx skir gen

# Run Sorbet type checker
bundle exec srb tc

# Run snippets
bundle exec ruby snippets.rb
```

### Start a SkirRPC service

From one process, run:
```shell
bundle exec ruby start_service.rb
```

From another process, run:
```shell
bundle exec ruby call_service.rb
```
