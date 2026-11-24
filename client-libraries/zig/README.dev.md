# Publishing skir_client to the Zig Package Manager

Zig does not have a central hosted registry (like crates.io or Hex.pm).
Packages are distributed as **GitHub releases** and referenced by URL + hash
in consumers' `build.zig.zon`. The steps below describe the full release flow.

## Prerequisites

- Zig 0.15.0 or later installed locally (`zig version`)
- Push access to the `gepheum/skir` GitHub repository (or your fork)
- The GitHub Actions workflows in `.github/workflows/` already handle CI and
  release creation automatically once you push a tag

## Release process

### 1. Update the version

Edit `build.zig.zon` and increment `.version`:

```zig
.version = "0.2.0",
```

### 2. Run local checks

```sh
./pre_commit.sh
```

This verifies formatting and runs tests in both `Debug` and `ReleaseSafe` modes.

### 3. Commit and tag

```sh
git add build.zig.zon
git commit -m "chore: release v0.2.0"
git tag v0.2.0
git push origin main --tags
```

Pushing the tag triggers the `deploy.yml` workflow which:
- Re-runs the tests
- Creates a GitHub Release with auto-generated release notes

### 4. Obtain the package hash (for the release notes / consumers)

After the release is published, fetch the hash so consumers can paste it into
their `build.zig.zon`:

```sh
zig fetch https://github.com/gepheum/skir/archive/refs/tags/v0.2.0.tar.gz
```

This prints a `.hash` value. Include it in the release description so users
can reference the package without running `zig fetch` themselves.

## How consumers add this package

In their project's `build.zig.zon`:

```zig
.dependencies = .{
    .skir_client = .{
        .url = "https://github.com/gepheum/skir/archive/refs/tags/v0.2.0.tar.gz",
        .hash = "<hash printed by zig fetch>",
    },
},
```

And in their `build.zig`:

```zig
const skir_client = b.dependency("skir_client", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("skir_client", skir_client.module("skir_client"));
```

## Optional: list on zigpm.dev

The community index at <https://zigpm.dev> lets users discover Zig packages.
To list `skir_client`:

1. Go to <https://zigpm.dev/submit> (or follow the instructions on the site).
2. Provide the GitHub repository URL.
3. The index will track future releases automatically.
