# skir-swift-example

Example project for [Skir](https://skir.build)-generated Swift code.

## Running

### Snippets

View code examples showing how to use the generated data types:

```sh
swift run Snippets
```

### Service demo

Start the service (in one terminal):

```sh
swift run StartService
```

Send requests to the service (in a second terminal):

```sh
swift run CallService
```

The service listens on `http://localhost:8787/myapi`. You can also open that
URL in a browser to explore it with [Skir Studio](https://skir.build/studio).

## Regenerating the Swift code

The generated Swift code in `skirout/` is committed for convenience, but you
can regenerate it at any time:

```sh
npx skir gen
```

## License

MIT
