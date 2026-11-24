# skir_client

`skir_client` is the shared runtime/client library used by
Skir-generated Zig clients.

[skir.build/](https://skir.build/)

## Installation

Add `skir_client` as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .skir_client = .{
        .url = "https://github.com/gepheum/skir-zig-client/archive/refs/heads/main.tar.gz",
        .hash = "<hash printed by zig fetch>",
    },
},
```

Then fetch the archive once to get the hash:

```sh
zig fetch https://github.com/gepheum/skir-zig-client/archive/refs/heads/main.tar.gz
```

## Development

```sh
./pre_commit.sh
```

This runs formatting, compilation, and tests.
