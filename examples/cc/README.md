# Skir C++ example

Example showing how to use skir's [C++ code generator](https://github.com/gepheum/skir-cc-gen) in a project.

## Build and run the example

### Prerequisites

- **Node.js** - for running the Skir code generator
- **CMake 3.20+** - for building the C++ code
- A **C++17 compatible compiler** (GCC, Clang, or MSVC)

If you use Homebrew on macOS:

```shell
brew install cmake node
```

### Download this repository

```shell
git clone https://github.com/gepheum/skir-cc-example.git
cd skir-cc-example
```

### Run Skir-to-C++ code generation

Generate the C++ code from Skir definitions:

```shell
npx skir gen
```

The Skir compiler looks for a `skir.yml` file in the current directory.
This file contains the following information:

*    `srcDir`: path to the directory containing all the .skir files
*    `generators`: code generators to run; each generator targets one programming language

The compiler creates a `skirout` directory containing all the generated code.

Alternatively, you can run the compiler with watch mode on: `npx skir gen -w`.
While the process is running, every modification to a .skir file in the source
directory will trigger code generation. 
The process won't stop until you terminate it.

### Build with CMake

CMake automatically fetches and builds all dependencies (Abseil, cpp-httplib, GoogleTest, and skir-client).

#### Configure and build

```shell
mkdir build
cd build
cmake ..
cmake --build .
```

Or with parallel jobs for faster builds:

```shell
cmake --build . -j$(nproc)  # Linux/macOS
cmake --build . -j8          # or specify number of cores
```

#### Run the executables

```shell
# Run the example program
./example

# Run tests
ctest --output-on-failure

# Start a SkirRPC service
./service_start

# Send RPCs to the SkirRPC service (run in a different terminal)
./service_client
```

#### Build options

- `BUILD_TESTING` (default: ON) - Build the test suite

To disable tests:
```shell
cmake -DBUILD_TESTING=OFF ..
```

For release builds with optimizations:
```shell
cmake -DCMAKE_BUILD_TYPE=Release ..
```

## IDE support

### VSCode with CMake

CMake generates a `compile_commands.json` file automatically, which provides excellent IDE integration.

If your C++ compiler is clang (recommended), install the `clangd` extension and disable Microsoft's C/C++ extension.

The `compile_commands.json` file provides:

*   Code completion
*   Compile errors and warnings
*   Go-to-definition and cross references
*   Hover information and inlay hints
*   Include management
*   Code formatting
*   Simple refactorings
