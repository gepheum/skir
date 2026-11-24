# Development and Release Guide (MoonBit)

This package is published to MoonBit's package registry (Mooncakes).

## Prerequisites

- Install MoonBit toolchain (`moon` command available)
- Create a Mooncakes account (if needed):

```bash
moon register
```

- Log in locally:

```bash
moon login
moon whoami
```

## Local validation before release

From this directory:

```bash
moon fmt --check
moon check
moon test
moon package
```

## Release process

1. Bump the version in `moon.mod`.
2. Commit and push your changes.
3. Publish the module:

```bash
moon publish
```
