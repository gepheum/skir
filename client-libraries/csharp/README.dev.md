# Publishing skir_client to NuGet

This package is published to NuGet.org.

## Prerequisites

1. Install .NET 10 SDK and verify with `dotnet --version`.
2. Create a NuGet.org account: https://www.nuget.org
3. Create an API key with push permissions: https://www.nuget.org/account/apikeys

## Release process

1. Update the version in `SkirClient.csproj` (`<Version>`).
2. Run local checks:

```sh
./pre_commit.sh
```

3. Build a release package:

```sh
dotnet pack SkirClient.csproj -c Release -o artifacts
```

4. Publish to NuGet:

```sh
dotnet nuget push artifacts/*.nupkg \
  --api-key <NUGET_API_KEY> \
  --source https://api.nuget.org/v3/index.json \
  --skip-duplicate
```

## CI/CD deploy workflow

The release workflow is in `.github/workflows/deploy.yml`.

1. Add repository secret `NUGET_API_KEY`.
2. Create a GitHub release.
3. The workflow builds, packs, and publishes the package automatically.
