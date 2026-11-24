#!/bin/bash

set -e

npx skir format
npx skir gen
dotnet run --project CsharpExample.csproj
