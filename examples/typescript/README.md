# Skir TypeScript example

Example showing how to use skir's [TypeScript code generator](https://github.com/gepheum/skir-typescript-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-typescript-example.git

cd skir-typescript-example

# Install all dependencies, which include the skir compiler and the skir
# typescript code generator
npm i

# The build step includes both skir codegen and TypeScript to Javascript
# transpilation
npm run build

# Starts an HTTP server on http://localhost:8787/
npm run server
```

## Call a SkirRPC service from the browser

While the server is running, run:

```shell
npm run bundle
```

Open `static/index.html` in your browser.
