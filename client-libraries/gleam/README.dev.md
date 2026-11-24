# Publishing skir_client to Hex.pm

This package is published to the Gleam package registry (Hex.pm).

## Prerequisites

1. Install Gleam and verify `gleam --version`.
2. Create a Hex.pm account: https://hex.pm
3. Authenticate locally:

```sh
gleam hex authenticate
```

## Release process

1. Update version in `gleam.toml`.
2. Run local checks:

```sh
./pre_commit.sh
```

3. Publish:

```sh
gleam publish
```

## CI/CD deploy workflow

The GitHub deploy workflow in `.github/workflows/deploy.yml` can publish automatically.

1. Add repository secret `HEXPM_API_KEY` with a Hex API key.
2. Trigger the workflow manually or create a GitHub release.

To create a key on Hex.pm, use Account settings -> API Keys and grant publish permissions.
